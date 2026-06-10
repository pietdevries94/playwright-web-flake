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
          x86_64-linux = "sha256-Nr0/uczFTBTqvRPR0c/wflIqG5relgKfC9XsMOdE9iE=";
          aarch64-linux = "sha256-veEBmsivFDrG1bArQ780+gMbsoT1Zv4VLcIPpgn4M/I=";
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
        x86_64-darwin = "sha256-GEomMUuaIjhBEuWF/HyMohseJtwKOn5MCgh6kIB9ZeE=";
        aarch64-darwin = "sha256-7laJtPAiy6pYAxCNBxRYk+FmriXemmLW8UYteEdVrd0=";
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
