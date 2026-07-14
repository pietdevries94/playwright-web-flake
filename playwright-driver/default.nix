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
          filename = "playwright-1.51.0-py3-none-manylinux1_x86_64.whl";
          url = "https://files.pythonhosted.org/packages/7a/fd/bc60798803414ecab66456208eeff4308344d0c055ca0d294d2cdd692b60/playwright-1.51.0-py3-none-manylinux1_x86_64.whl";
          hash = "sha256-1cn2e8bvSQlGGJkceKFGbFusXtCRV2YNeLhRC3f5J0Y=";
        };

        aarch64-linux = {
          filename = "playwright-1.51.0-py3-none-manylinux_2_17_aarch64.manylinux2014_aarch64.whl";
          url = "https://files.pythonhosted.org/packages/0d/14/13db550d7b892aefe80f8581c6557a17cbfc2e084383cd09d25fdd488f6e/playwright-1.51.0-py3-none-manylinux_2_17_aarch64.manylinux2014_aarch64.whl";
          hash = "sha256-gU5OwqGg1vYiHwdWIsBrMc6yvcbWIiWM/v7ZAMAVaa4=";
        };

        x86_64-darwin = {
          filename = "playwright-1.51.0-py3-none-macosx_10_13_x86_64.whl";
          url = "https://files.pythonhosted.org/packages/1b/e9/db98b5a8a41b3691be52dcc9b9d11b5db01bfc9b835e8e3ffe387b5c9266/playwright-1.51.0-py3-none-macosx_10_13_x86_64.whl";
          hash = "sha256-vKqj1dc72mWb+5/yooi1HoWpG9ie2obq+BhlUJc+QWo=";
        };

        aarch64-darwin = {
          filename = "playwright-1.51.0-py3-none-macosx_11_0_arm64.whl";
          url = "https://files.pythonhosted.org/packages/32/4a/5f2ff6866bdf88e86147930b0be86b227f3691f4eb01daad5198302a8cbe/playwright-1.51.0-py3-none-macosx_11_0_arm64.whl";
          hash = "sha256-Lgrm60QpeyRzjhptnFgMpCQ7TiG35lz5NqcUksCN0NQ=";
        };
      }.${system} or throwSystem;
    in
    {
      pname = "playwright-driver";
      # run ./pkgs/development/python-modules/playwright/update.sh to update
      version = "1.51.0";

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
