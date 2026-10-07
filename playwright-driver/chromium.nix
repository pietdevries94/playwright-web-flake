{
  runCommand,
  makeWrapper,
  fontconfig_file,
  chromium,
  fetchzip,
  revision,
  browserVersion,
  suffix,
  system,
  throwSystem,
  lib,
  alsa-lib,
  at-spi2-atk,
  atk,
  autoPatchelfHook,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gobject-introspection,
  libGL,
  libgbm,
  libgcc,
  libxkbcommon,
  nspr,
  nss,
  pango,
  patchelf,
  pciutils,
  stdenv,
  systemd,
  vulkan-loader,
  libX11,
  libXcomposite,
  libXdamage,
  libXext,
  libXfixes,
  libXrandr,
  libxcb,
  ...
}:
let
  chromeDir =
    {
      x86_64-linux = "chrome-linux64";
      aarch64-linux = "chrome-linux-arm64";
    }
    .${system} or throwSystem;
  chromium-linux = stdenv.mkDerivation {
    name = "playwright-chromium";
    src = fetchzip {
      url =
        {
          x86_64-linux = "https://cdn.playwright.dev/builds/cft/${browserVersion}/linux64/chrome-linux64.zip";
          aarch64-linux = "https://cdn.playwright.dev/builds/cft/${browserVersion}/linux-arm64/chrome-linux-arm64.zip";
        }
        .${system} or throwSystem;
      hash =
        {
          x86_64-linux = "sha256-ORdMu1e4Peolr8rdfvzgeaFhC8RgBipaOsAm7e3ZeqE=";
          aarch64-linux = "sha256-AWXksACJGsDisnp9dAUcukDf/ruMCRCX9kZNNnE0R8Q=";
        }
        .${system} or throwSystem;
    };

    nativeBuildInputs = [
      autoPatchelfHook
      patchelf
      makeWrapper
    ];
    buildInputs = [
      alsa-lib
      at-spi2-atk
      atk
      cairo
      cups
      dbus
      expat
      glib
      gobject-introspection
      libgbm
      libgcc
      libxkbcommon
      nspr
      nss
      pango
      stdenv.cc.cc.lib
      systemd
      libX11
      libXcomposite
      libXdamage
      libXext
      libXfixes
      libXrandr
      libxcb
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/${chromeDir}
      cp -R . $out/${chromeDir}

      wrapProgram $out/${chromeDir}/chrome \
        --set-default SSL_CERT_FILE /etc/ssl/certs/ca-bundle.crt \
        --set-default FONTCONFIG_FILE ${fontconfig_file}

      runHook postInstall
    '';

    appendRunpaths = lib.makeLibraryPath [
      libGL
      vulkan-loader
      pciutils
    ];

    postFixup = ''
      # replace bundled vulkan-loader since we are also already adding our own to RPATH
      rm "$out/chrome-linux64/libvulkan.so.1"
      ln -s -t "$out/chrome-linux64" "${lib.getLib vulkan-loader}/lib/libvulkan.so.1"
    '';
  };
  chromium-darwin = fetchzip {
    url =
      {
        x86_64-darwin = "https://cdn.playwright.dev/builds/cft/${browserVersion}/mac-x64/chrome-mac-x64.zip";
        aarch64-darwin = "https://cdn.playwright.dev/builds/cft/${browserVersion}/mac-arm64/chrome-mac-arm64.zip";
      }
      .${system} or throwSystem;
    stripRoot = false;
    hash =
      {
        x86_64-darwin = "sha256-GeKP0Y80S44gAvHmjszr9d09BE9DH1EYFSHyATzzyv0=";
        aarch64-darwin = "sha256-Zm7aHjwXL0kbucBiNoWxBM6rFdY0UmVIwcr/f8V31G8=";
      }
      .${system} or throwSystem;
  };
in
{
  x86_64-linux = chromium-linux;
  aarch64-linux = chromium-linux;
  x86_64-darwin = chromium-darwin;
  aarch64-darwin = chromium-darwin;
}
.${system} or throwSystem
