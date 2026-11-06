{
  fetchzip,
  revision,
  browserVersion,
  suffix,
  system,
  throwSystem,
  stdenv,
  autoPatchelfHook,
  patchelfUnstable,

  alsa-lib,
  at-spi2-atk,
  expat,
  glib,
  libXcomposite,
  libXdamage,
  libXfixes,
  libXrandr,
  libgbm,
  libgcc,
  libxkbcommon,
  nspr,
  nss,
  ...
}:
let
  linux = stdenv.mkDerivation {
    name = "playwright-chromium-headless-shell";
    src = fetchzip {
      url =
        {
          x86_64-linux = "https://cdn.playwright.dev/builds/cft/${browserVersion}/linux64/chrome-headless-shell-linux64.zip";
          aarch64-linux = "https://cdn.playwright.dev/builds/cft/${browserVersion}/linux-arm64/chrome-headless-shell-linux-arm64.zip";
        }
        .${system} or throwSystem;
      stripRoot = false;
      hash =
        {
          x86_64-linux = "sha256-CJB0HhSaPLj84F9wPn633mn4JzR6IyJcW4QK21YSMnY=";
          aarch64-linux = "sha256-SqW6vOF+X7XbWVAdmezjL1xPufEF6B69IoDKiB8lql4=";
        }
        .${system} or throwSystem;
    };

    nativeBuildInputs = [
      autoPatchelfHook
      patchelfUnstable
    ];

    buildInputs = [
      alsa-lib
      at-spi2-atk
      expat
      glib
      libXcomposite
      libXdamage
      libXfixes
      libXrandr
      libgbm
      libgcc
      libxkbcommon
      nspr
      nss
    ];

    buildPhase = ''
      cp -R . $out
    '';
  };

  darwin = fetchzip {
    url =
      {
        x86_64-darwin = "https://cdn.playwright.dev/builds/cft/${browserVersion}/mac-x64/chrome-headless-shell-mac-x64.zip";
        aarch64-darwin = "https://cdn.playwright.dev/builds/cft/${browserVersion}/mac-arm64/chrome-headless-shell-mac-arm64.zip";
      }
      .${system} or throwSystem;
    stripRoot = false;
    hash =
      {
        x86_64-darwin = "sha256-w9662QRm8yFMHVSlQKsnqHOfyQZ/x+LFPeC/bIeuDYM=";
        aarch64-darwin = "sha256-du/uCxVK8RTqRC+m5rqiVC8J0rX5EZj9YGHAyo7L0Ik=";
      }
      .${system} or throwSystem;
  };
in
{
  x86_64-linux = linux;
  aarch64-linux = linux;
  x86_64-darwin = darwin;
  aarch64-darwin = darwin;
}
.${system} or throwSystem
