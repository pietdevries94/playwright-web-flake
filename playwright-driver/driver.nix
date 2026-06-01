{
  lib,
  buildNpmPackage,
  stdenv,
  jq,
  nodejs,
  fetchFromGitHub,
  linkFarm,
  callPackage,
  makeFontsConf,
  makeWrapper,
  cacert,
  versions,
}:
let
  inherit (stdenv.hostPlatform) system;

  throwSystem = throw "Unsupported system: ${system}";
  suffix =
    {
      x86_64-linux = "linux";
      aarch64-linux = "linux-arm64";
      x86_64-darwin = "mac";
      aarch64-darwin = "mac-arm64";
    }
    .${system} or throwSystem;

  inherit (versions.driver) version;

  src = fetchFromGitHub {
    owner = "Microsoft";
    repo = "playwright";
    rev = "v${version}";
    inherit (versions.driver) hash;
  };

  hasBundle =
    hashPath:
    versions.driver.npmDepsHashes ? ${hashPath} && versions.driver.npmDepsHashes.${hashPath} != "";

  mkBundle =
    {
      pname,
      sourceRoot,
      hashPath,
      bundleDir,
    }:
    let
      drv = buildNpmPackage {
        inherit pname version src sourceRoot;
        npmDepsHash = versions.driver.npmDepsHashes.${hashPath};
        dontNpmBuild = true;
        installPhase = ''
          cp -r . "$out"
        '';
      };
    in
    if hasBundle hashPath then
      {
        inherit drv;
        symlink = ''
          if [ -d ${bundleDir} ]; then
            chmod +w ${bundleDir}
            ln -s ${drv}/node_modules ${bundleDir}/node_modules
          fi
        '';
      }
    else
      {
        drv = null;
        symlink = "";
      };

  bundles = {
    babel = mkBundle {
      pname = "babel-bundle";
      sourceRoot = "${src.name}/packages/playwright/bundles/babel";
      hashPath = "/packages/playwright/bundles/babel";
      bundleDir = "packages/playwright/bundles/babel";
    };
    expect = mkBundle {
      pname = "expect-bundle";
      sourceRoot = "${src.name}/packages/playwright/bundles/expect";
      hashPath = "/packages/playwright/bundles/expect";
      bundleDir = "packages/playwright/bundles/expect";
    };
    utils = mkBundle {
      pname = "utils-bundle";
      sourceRoot = "${src.name}/packages/playwright/bundles/utils";
      hashPath = "/packages/playwright/bundles/utils";
      bundleDir = "packages/playwright/bundles/utils";
    };
    utils-core = mkBundle {
      pname = "utils-bundle-core";
      sourceRoot = "${src.name}/packages/playwright-core/bundles/utils";
      hashPath = "/packages/playwright-core/bundles/utils";
      bundleDir = "packages/playwright-core/bundles/utils";
    };
    zip = mkBundle {
      pname = "zip-bundle";
      sourceRoot = "${src.name}/packages/playwright-core/bundles/zip";
      hashPath = "/packages/playwright-core/bundles/zip";
      bundleDir = "packages/playwright-core/bundles/zip";
    };
  };

  playwright = buildNpmPackage {
    pname = "playwright";
    inherit version src;

    sourceRoot = "${src.name}";
    npmDepsHash = versions.driver.npmDepsHashes."";

    nativeBuildInputs = [
      cacert
      jq
    ];

    ELECTRON_SKIP_BINARY_DOWNLOAD = true;

    postPatch = ''
      [ -f utils/build/build.js ] && sed -i '/\/\/ Update test runner./,/^\s*$/{d}' utils/build/build.js || true
      [ -f utils/build/build.js ] && sed -i '/^\/\/ Update bundles\./,/^[[:space:]]*}$/d' utils/build/build.js || true
      [ -f ./utils/generate_third_party_notice.js ] && sed -i '/execSync/d' ./utils/generate_third_party_notice.js || true
      ${bundles.babel.symlink}
      ${bundles.expect.symlink}
      ${bundles.utils.symlink}
      ${bundles.utils-core.symlink}
      ${bundles.zip.symlink}
    '';

    installPhase = ''
      runHook preInstall

      shopt -s extglob

      mkdir -p "$out/lib/node_modules/playwright"
      cp -r packages/playwright/!(bundles|src|node_modules|.*) "$out/lib/node_modules/playwright"

      # for not supported platforms (such as NixOS) playwright assumes that it runs on ubuntu-20.04
      # that forces it to use overridden webkit revision
      # let's remove that override to make it use latest revision provided in Nixpkgs
      # https://github.com/microsoft/playwright/blob/baeb065e9ea84502f347129a0b896a85d2a8dada/packages/playwright-core/src/server/utils/hostPlatform.ts#L111
      jq '(.browsers[] | select(.name == "webkit") | .revisionOverrides) |= del(."ubuntu20.04-x64", ."ubuntu20.04-arm64")' \
        packages/playwright-core/browsers.json > browser.json.tmp && mv browser.json.tmp packages/playwright-core/browsers.json
      mkdir -p "$out/lib/node_modules/playwright-core"
      cp -r packages/playwright-core/!(bundles|src|bin|.*) "$out/lib/node_modules/playwright-core"

      mkdir -p "$out/lib/node_modules/@playwright/test"
      cp -r packages/playwright-test/* "$out/lib/node_modules/@playwright/test"

      runHook postInstall
    '';

    meta = {
      description = "Framework for Web Testing and Automation";
      homepage = "https://playwright.dev";
      license = lib.licenses.asl20;
      maintainers = with lib.maintainers; [
        kalekseev
        marie
      ];
      inherit (nodejs.meta) platforms;
    };
  };

  playwright-core = stdenv.mkDerivation (_: {
    pname = "playwright-core";
    inherit (playwright) version src meta;

    installPhase = ''
      runHook preInstall

      cp -r ${playwright}/lib/node_modules/playwright-core "$out"

      runHook postInstall
    '';

    passthru = {
      browsersJSON = (lib.importJSON ./browsers.json).browsers;
      browsers = browsers { };
      browsers-chromium = browsers {
        withFirefox = false;
        withWebkit = false;
        withChromiumHeadlessShell = false;
      };
      inherit components;
    };
  });

  playwright-test = stdenv.mkDerivation (_: {
    pname = "playwright-test";
    inherit (playwright) version src;

    nativeBuildInputs = [ makeWrapper ];
    installPhase = ''
      runHook preInstall

      shopt -s extglob
      mkdir -p $out/bin
      cp -r ${playwright}/* $out

      makeWrapper "${nodejs}/bin/node" "$out/bin/playwright" \
        --add-flags "$out/lib/node_modules/@playwright/test/cli.js" \
        --prefix NODE_PATH : ${placeholder "out"}/lib/node_modules \
        --set-default PLAYWRIGHT_BROWSERS_PATH "${playwright-core.passthru.browsers}"

      runHook postInstall
    '';

    meta = playwright.meta // {
      mainProgram = "playwright";
    };
  });

  components = {
    chromium = callPackage ./chromium.nix {
      inherit suffix system throwSystem;
      inherit (playwright-core.passthru.browsersJSON.chromium) revision browserVersion;
      hashes = versions.browsers.chromium;
      fontconfig_file = makeFontsConf {
        fontDirectories = [ ];
      };
    };
    chromium-headless-shell = callPackage ./chromium-headless-shell.nix {
      inherit suffix system throwSystem;
      inherit (playwright-core.passthru.browsersJSON.chromium) revision browserVersion;
      hashes = versions.browsers."chromium-headless-shell";
    };
    firefox = callPackage ./firefox.nix {
      inherit suffix system throwSystem;
      inherit (playwright-core.passthru.browsersJSON.firefox) revision;
      hashes = versions.browsers.firefox;
    };
    webkit = callPackage ./webkit.nix {
      inherit suffix system throwSystem;
      inherit (playwright-core.passthru.browsersJSON.webkit) revision revisionOverrides;
      hashes = versions.browsers.webkit;
    };
    ffmpeg = callPackage ./ffmpeg.nix {
      inherit suffix system throwSystem;
      inherit (playwright-core.passthru.browsersJSON.ffmpeg) revision revisionOverrides;
      hashes = versions.browsers.ffmpeg;
    };
  };

  browsers = lib.makeOverridable (
    {
      withChromium ? true,
      withFirefox ? true,
      withWebkit ? true, # may require `export PLAYWRIGHT_HOST_PLATFORM_OVERRIDE="ubuntu-24.04"`
      withFfmpeg ? true,
      withChromiumHeadlessShell ? true,
    }:
    let
      browsers =
        lib.optionals withChromium [ "chromium" ]
        ++ lib.optionals withChromiumHeadlessShell [ "chromium-headless-shell" ]
        ++ lib.optionals withFirefox [ "firefox" ]
        ++ lib.optionals withWebkit [ "webkit" ]
        ++ lib.optionals withFfmpeg [ "ffmpeg" ];
    in
    linkFarm "playwright-browsers" (
      lib.listToAttrs (
        map (
          name:
          let
            revName = if name == "chromium-headless-shell" then "chromium" else name;
            value = playwright-core.passthru.browsersJSON.${revName};
          in
          lib.nameValuePair
            # TODO check platform for revisionOverrides
            "${lib.replaceStrings [ "-" ] [ "_" ] name}-${value.revision}"
            components.${name}
        ) browsers
      )
    )
  );
in
{
  inherit playwright-core;
  inherit playwright-test;
}
