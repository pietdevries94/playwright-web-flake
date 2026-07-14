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
          filename = "playwright-1.41.2-py3-none-manylinux1_x86_64.whl";
          url = "https://files.pythonhosted.org/packages/98/aa/485efb664d9808715d1a130b6bc33aac12d2156a40310bdc385811d95048/playwright-1.41.2-py3-none-manylinux1_x86_64.whl";
          hash = "sha256-S/IU2BIJLPW5uWSLqEYRqjXihoVRmRE0Kn2jowMfntY=";
        };

        aarch64-linux = {
          filename = "playwright-1.41.2-py3-none-manylinux_2_17_aarch64.manylinux2014_aarch64.whl";
          url = "https://files.pythonhosted.org/packages/b4/5d/ad30302ef903a4c9ce58c1853ca659fb06ae9b2f13a0470fecb931276e4c/playwright-1.41.2-py3-none-manylinux_2_17_aarch64.manylinux2014_aarch64.whl";
          hash = "sha256-6qF6tEYixEfeJu2PfZmRJxlWjY28Op2w4H8K4Uh3Cdk=";
        };

        x86_64-darwin = {
          filename = "playwright-1.41.2-py3-none-macosx_10_13_x86_64.whl";
          url = "https://files.pythonhosted.org/packages/83/f9/81843bb9483332c4dee3b3aa0aef9b4269d1abd49cfffd1fde1700748b6e/playwright-1.41.2-py3-none-macosx_10_13_x86_64.whl";
          hash = "sha256-z2gzWl36QDj6eXpLoBBfruAJTruzclR9eif+7FsjxnI=";
        };

        aarch64-darwin = {
          filename = "playwright-1.41.2-py3-none-macosx_11_0_arm64.whl";
          url = "https://files.pythonhosted.org/packages/e4/40/f69d23fbd8d4c59b9b05578ad2b33745ee34ad33b64133b4a2659cfae071/playwright-1.41.2-py3-none-macosx_11_0_arm64.whl";
          hash = "sha256-Qx46BfjJkUeZXis+hHXQeBh0UpT9mfFRC2F1bnO9z2g=";
        };
      }.${system} or throwSystem;
    in
    {
      pname = "playwright-driver";
      # run ./pkgs/development/python-modules/playwright/update.sh to update
      version = "1.41.2";

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
