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
          x86_64-linux = "sha256-kQCw0nQHHuUIfn8rGVcN7Ip6ZOk5c3Or+GG5RvSica4=";
          aarch64-linux = "sha256-s2IIjSY5t9AtT05dUS0mp4fPlaixND9+Cg0+0S8Kkx8=";
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
        x86_64-darwin = "sha256-kzbLpzzMpBurQHyGaz561A0K46GzgWPP2JSQKRV6C+Y=";
        aarch64-darwin = "sha256-67ekk37uq5ITq9ZvwPTZhhqEgQY17g/3KJ/vnqZz3h0=";
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
