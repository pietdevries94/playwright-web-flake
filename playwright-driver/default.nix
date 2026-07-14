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
          filename = "playwright-1.52.0-py3-none-manylinux1_x86_64.whl";
          url = "https://files.pythonhosted.org/packages/73/c6/8e27af9798f81465b299741ef57064c6ec1a31128ed297406469907dc5a4/playwright-1.52.0-py3-none-manylinux1_x86_64.whl";
          hash = "sha256-0BASTSSjIeBImowNOKOXGnynZWvs6nZWyTdr/qf5FtQ=";
        };

        aarch64-linux = {
          filename = "playwright-1.52.0-py3-none-manylinux_2_17_aarch64.manylinux2014_aarch64.whl";
          url = "https://files.pythonhosted.org/packages/4e/e9/0661d343ed55860bcfb8934ce10e9597fc953358773ece507b22b0f35c57/playwright-1.52.0-py3-none-manylinux_2_17_aarch64.manylinux2014_aarch64.whl";
          hash = "sha256-QXPkU8QxgKzGD9d//h6+6NDvv9mYbAMmcAe5w4RUFa8=";
        };

        x86_64-darwin = {
          filename = "playwright-1.52.0-py3-none-macosx_10_13_x86_64.whl";
          url = "https://files.pythonhosted.org/packages/1e/62/a20240605485ca99365a8b72ed95e0b4c5739a13fb986353f72d8d3f1d27/playwright-1.52.0-py3-none-macosx_10_13_x86_64.whl";
          hash = "sha256-GbLLnUeUBiAIpjWpm9E1sD67eC1GD5ZTSpHLWD9UlRI=";
        };

        aarch64-darwin = {
          filename = "playwright-1.52.0-py3-none-macosx_11_0_arm64.whl";
          url = "https://files.pythonhosted.org/packages/dc/23/57ff081663b3061a2a3f0e111713046f705da2595f2f384488a76e4db732/playwright-1.52.0-py3-none-macosx_11_0_arm64.whl";
          hash = "sha256-B5fAR5y9yZYHQSo8SGo6Lsndx3rEYSWf0oeMl1vLuUo=";
        };
      }.${system} or throwSystem;
    in
    {
      pname = "playwright-driver";
      # run ./pkgs/development/python-modules/playwright/update.sh to update
      version = "1.52.0";

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
