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
          aarch64-linux = "https://cdn.playwright.dev/builds/chromium/${revision}/chromium-headless-shell-${suffix}.zip";
        }
        .${system} or throwSystem;
      stripRoot = false;
      hash =
        {
          x86_64-linux = "sha256-/xskLzTc9tTZmu1lwkMpjV3QV7XjP92D/7zRcFuVWT8=";
          aarch64-linux = "sha256-jckH5+eGJ4BhH1NAa5LIgf3/salKLAHW9XUOo5gob4c=";
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
      libgcc.lib
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
        x86_64-darwin = "sha256-bgU7lZhp9XUFfGu58pFdZyhXho3Jiy4MjljR+yk0M1c=";
        aarch64-darwin = "sha256-45DjMIu0t7IEYdXOmIqpV/1/MKdEfx/8T7DWagh6Zhc=";
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
