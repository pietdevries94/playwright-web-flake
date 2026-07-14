{ lib
, stdenv
, chromium
, ffmpeg
, git
, jq
, nodejs
, fetchFromGitHub
, fetchurl
, makeFontsConf
, makeWrapper
, runCommand
, unzip
, cacert
}:
let
  inherit (stdenv.hostPlatform) system;

  throwSystem = throw "Unsupported system: ${system}";

  driver = stdenv.mkDerivation (finalAttrs:
    let
      wheel = {
        x86_64-linux = {
          filename = "playwright-1.53.0-py3-none-manylinux1_x86_64.whl";
          url = "https://files.pythonhosted.org/packages/92/32/5d871c3753fbee5113eefc511b9e44c0006a27f2301b4c6bffa4346fbd94/playwright-1.53.0-py3-none-manylinux1_x86_64.whl";
          hash = "sha256-2xnLW1jzsVytPiQZ9JEMBT6IkgL8ICRh7hg/FTDR22A=";
        };

        aarch64-linux = {
          filename = "playwright-1.53.0-py3-none-manylinux_2_17_aarch64.manylinux2014_aarch64.whl";
          url = "https://files.pythonhosted.org/packages/dc/6b/9942f86661ff41332f9299db4950623123e60ca71e4fb6e6942fc0212624/playwright-1.53.0-py3-none-manylinux_2_17_aarch64.manylinux2014_aarch64.whl";
          hash = "sha256-knbJyTX8Bi9R9PUQflZCCv1tmlJDSNxDd5PcLjTHQuM=";
        };

        x86_64-darwin = {
          filename = "playwright-1.53.0-py3-none-macosx_10_13_x86_64.whl";
          url = "https://files.pythonhosted.org/packages/f5/e2/2f107be74419280749723bd1197c99351f4b8a0a25e974b9764affb940b2/playwright-1.53.0-py3-none-macosx_10_13_x86_64.whl";
          hash = "sha256-SKGhXOgQ8P/lErYFDemHHqGTtB3TzBu+2HuEMQEkGbo=";
        };

        aarch64-darwin = {
          filename = "playwright-1.53.0-py3-none-macosx_11_0_arm64.whl";
          url = "https://files.pythonhosted.org/packages/ac/d5/e8c57a4f6fd46059fb2d51da2d22b47afc886b42400f06b742cd4a9ba131/playwright-1.53.0-py3-none-macosx_11_0_arm64.whl";
          hash = "sha256-pwH5SYpbh+P5KewBzqMQn73nWCGxnHuku6VPYSe5T3Y=";
        };
      }.${system} or throwSystem;
    in
    {
      pname = "playwright-driver";
      # run ./pkgs/development/python-modules/playwright/update.sh to update
      version = "1.53.0";

      src = fetchurl {
        inherit (wheel) url hash;
      };

      unpackPhase = ''
        runHook preUnpack
        unzip "$src"
        runHook postUnpack
      '';

      sourceRoot = "playwright/driver";

      nativeBuildInputs = [ unzip ];

      postPatch = ''
        # Use Nix's NodeJS instead of the bundled one.
        rm node

        patchShebangs package/bin/*.sh
      '';

      installPhase = ''
        runHook preInstall

        mkdir -p $out/bin
        # playwright.sh doesn't exist anymore, so we write a new one
        cat > $out/bin/playwright <<EOF
#!/bin/sh
if [ -z "\$PLAYWRIGHT_NODEJS_PATH" ]; then
  PLAYWRIGHT_NODEJS_PATH="${nodejs}/bin/node"
fi
"\$PLAYWRIGHT_NODEJS_PATH" "$out/package/cli.js" "\$@"
EOF

        chmod +x $out/bin/playwright

        patchShebangs $out/bin/playwright

        mv package $out/

        runHook postInstall
      '';

      passthru = {
        inherit (wheel) filename;
        browsers = {
          x86_64-linux = browsers-linux { };
          aarch64-linux = browsers-linux { };
          x86_64-darwin = browsers-mac;
          aarch64-darwin = browsers-mac;
        }.${system} or throwSystem;
        browsers-chromium = browsers-linux { };
      };
    });

  browsers-mac = stdenv.mkDerivation {
    pname = "playwright-browsers";
    inherit (driver) version;

    dontUnpack = true;

    nativeBuildInputs = [
      cacert
    ];

    installPhase = ''
      runHook preInstall

      export PLAYWRIGHT_BROWSERS_PATH=$out
      ${driver}/bin/playwright install
      rm -r $out/.links

      runHook postInstall
    '';

    meta.platforms = lib.platforms.darwin;
  };

  browsers-linux = { withChromium ? true }:
    let
      fontconfig = makeFontsConf {
        fontDirectories = [ ];
      };
    in
    runCommand
      ("playwright-browsers"
        + lib.optionalString withChromium "-chromium")
      {
        nativeBuildInputs = [
          makeWrapper
          jq
        ];
      }
      (''
        BROWSERS_JSON=${driver}/package/browsers.json
      '' + lib.optionalString withChromium ''
        CHROMIUM_REVISION=$(jq -r '.browsers[] | select(.name == "chromium").revision' $BROWSERS_JSON)
        mkdir -p $out/chromium-$CHROMIUM_REVISION/chrome-linux

        # See here for the Chrome options:
        # https://github.com/NixOS/nixpkgs/issues/136207#issuecomment-908637738
        makeWrapper ${chromium}/bin/chromium $out/chromium-$CHROMIUM_REVISION/chrome-linux/chrome \
          --set SSL_CERT_FILE /etc/ssl/certs/ca-bundle.crt \
          --set FONTCONFIG_FILE ${fontconfig}

        # We also need to install the headless shell version of Chromium
        CHROMIUM_HEADLESS_SHELL_REVISION=$(jq -r '.browsers[] | select(.name == "chromium-headless-shell").revision' $BROWSERS_JSON)
        mkdir -p $out/chromium-headless-shell-$CHROMIUM_HEADLESS_SHELL_REVISION/chrome-linux

        # See here for the Chrome options:
        # https://github.com/NixOS/nixpkgs/issues/136207#issuecomment-908637738
        makeWrapper ${chromium}/bin/chromium $out/chromium_headless_shell-$CHROMIUM_REVISION/chrome-linux/headless_shell \
          --set SSL_CERT_FILE /etc/ssl/certs/ca-bundle.crt \
          --set FONTCONFIG_FILE ${fontconfig}
      '' + ''
        FFMPEG_REVISION=$(jq -r '.browsers[] | select(.name == "ffmpeg").revision' $BROWSERS_JSON)
        mkdir -p $out/ffmpeg-$FFMPEG_REVISION
        ln -s ${ffmpeg}/bin/ffmpeg $out/ffmpeg-$FFMPEG_REVISION/ffmpeg-linux
      '');
in
driver
