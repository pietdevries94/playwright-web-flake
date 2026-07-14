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
          filename = "playwright-1.54.0-py3-none-manylinux1_x86_64.whl";
          url = "https://files.pythonhosted.org/packages/34/a9/45084fd23b6206f954198296ce39b0acf50debfdf3ec83a593e4d73c9c8a/playwright-1.54.0-py3-none-manylinux1_x86_64.whl";
          hash = "sha256-CZGfRcx0xkr7VDJkbX/vDRn/9QmQyGLLjZsFdwk/QMw=";
        };

        aarch64-linux = {
          filename = "playwright-1.54.0-py3-none-manylinux_2_17_aarch64.manylinux2014_aarch64.whl";
          url = "https://files.pythonhosted.org/packages/02/d4/6a692f4c6db223adc50a6e53af405b45308db39270957a6afebddaa80ea2/playwright-1.54.0-py3-none-manylinux_2_17_aarch64.manylinux2014_aarch64.whl";
          hash = "sha256-E64gbFVzfo4+rlH7OF1hwDEu7vMVNWQ7tiMnQbQbb9w=";
        };

        x86_64-darwin = {
          filename = "playwright-1.54.0-py3-none-macosx_10_13_x86_64.whl";
          url = "https://files.pythonhosted.org/packages/f3/09/33d5bfe393a582d8dac72165a9e88b274143c9df411b65ece1cc13f42988/playwright-1.54.0-py3-none-macosx_10_13_x86_64.whl";
          hash = "sha256-vzuEWvdENw8b0ihsKpU29HTMiojcmVty6ppb5xTJp30=";
        };

        aarch64-darwin = {
          filename = "playwright-1.54.0-py3-none-macosx_11_0_arm64.whl";
          url = "https://files.pythonhosted.org/packages/e1/7b/51882dc584f7aa59f446f2bb34e33c0e5f015de4e31949e5b7c2c10e54f0/playwright-1.54.0-py3-none-macosx_11_0_arm64.whl";
          hash = "sha256-eAkos8ogd66pBBSzflTt0MS7tX0ar8QveqCz/SwvrAI=";
        };
      }.${system} or throwSystem;
    in
    {
      pname = "playwright-driver";
      # run ./pkgs/development/python-modules/playwright/update.sh to update
      version = "1.54.0";

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
