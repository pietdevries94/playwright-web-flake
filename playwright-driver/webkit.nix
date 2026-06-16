{
  lib,
  stdenv,
  fetchzip,
  fetchFromGitHub,
  makeWrapper,
  autoPatchelfHook,
  patchelfUnstable,
  brotli,
  at-spi2-atk,
  cairo,
  flite,
  fontconfig,
  freetype,
  glib,
  glib-networking,
  gst_all_1,
  harfbuzz,
  harfbuzzFull,
  hyphen,
  icu70,
  lcms,
  libavif,
  libdrm,
  libepoxy,
  libevent,
  libgcc,
  libgcrypt,
  libgpg-error,
  libjpeg8,
  libopus,
  libpng,
  libsoup_3,
  libtasn1,
  enchant,
  libbacktrace,
  libwebp,
  libwpe,
  libwpe-fdo,
  libxkbcommon,
  libxml2,
  libxslt,
  libgbm,
  sqlite,
  systemdLibs,
  wayland-scanner,
  woff2,
  zlib,
  suffix,
  revision,
  revisionOverrides ? { },
  hashes,
  system,
  throwSystem,
}:
let
  # Determine the revision override key based on platform
  revisionOverrideKey =
    if system == "x86_64-darwin" then
      "mac14"
    else if system == "aarch64-darwin" then
      "mac14-arm64"
    else
      null;

  # Use revision override if available, otherwise fall back to base revision
  revision' =
    if revisionOverrideKey != null && revisionOverrides ? ${revisionOverrideKey} then
      revisionOverrides.${revisionOverrideKey}
    else
      revision;

  suffix' =
    if lib.hasPrefix "linux" suffix then
      "ubuntu-22.04" + (lib.removePrefix "linux" suffix)
    else if lib.hasPrefix "mac" suffix then
      "mac-14" + (lib.removePrefix "mac" suffix)
    else
      suffix;
  libavif' = libavif.overrideAttrs (
    finalAttrs: _: {
      version = "0.9.3";
      src = fetchFromGitHub {
        owner = "AOMediaCodec";
        repo = finalAttrs.pname;
        rev = "v${finalAttrs.version}";
        hash = "sha256-ME/mkaHhFeHajTbc7zhg9vtf/8XgkgSRu9I/mlQXnds=";
      };
      postPatch = "";
      patches = [ ];
    }
  );

  webkit-linux = stdenv.mkDerivation {
    name = "playwright-webkit";
    src = fetchzip {
      url = "https://cdn.playwright.dev/builds/webkit/${revision'}/webkit-${suffix'}.zip";
      stripRoot = false;
      hash = hashes.${system} or throwSystem;
    };

    nativeBuildInputs = [
      autoPatchelfHook
      patchelfUnstable
      makeWrapper
    ];
    buildInputs = [
      at-spi2-atk
      cairo
      flite
      fontconfig.lib
      freetype
      glib
      brotli
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-base
      gst_all_1.gstreamer
      harfbuzz
      harfbuzzFull
      hyphen
      icu70
      enchant
      lcms
      libavif'
      libdrm
      libepoxy
      libevent
      libgcc.lib
      libgcrypt
      libgpg-error
      libjpeg8
      libopus
      libpng
      libsoup_3
      libtasn1
      libwebp
      libwpe
      libwpe-fdo
      libbacktrace
      libxml2
      libxslt
      libgbm
      sqlite
      systemdLibs
      wayland-scanner
      woff2.lib
      libxkbcommon
      zlib
    ];

    patchelfFlags = [ "--no-clobber-old-sections" ];
    buildPhase = ''
      cp -R . $out

      # remove unused gtk browser
      rm -rf $out/minibrowser-gtk
      # remove most bundled libs but keep libjxl (not available from nixpkgs at compatible SONAME)
      for f in "$out"/minibrowser-wpe/sys/lib/*.so*; do
        base=$(basename "$f")
        case "$base" in
          libjxl*) : ;;
          *) rm -f "$f" ;;
        esac
      done
      rmdir "$out"/minibrowser-wpe/sys/lib 2>/dev/null || true
      rmdir "$out"/minibrowser-wpe/sys 2>/dev/null || true

      # TODO: still fails on ubuntu trying to find libEGL_mesa.so.0
      wrapProgram $out/minibrowser-wpe/bin/MiniBrowser \
        --prefix GIO_EXTRA_MODULES ":" "${glib-networking}/lib/gio/modules/" \
        --prefix LD_LIBRARY_PATH ":" $out/minibrowser-wpe/lib

    '';

    preFixup = ''
      # Fix libxml2 breakage. See https://github.com/NixOS/nixpkgs/pull/396195#issuecomment-2881757108
      mkdir -p "$out/lib"
      ln -s "${lib.getLib libxml2}/lib/libxml2.so" "$out/lib/libxml2.so.2"
    '';
  };
  webkit-darwin = fetchzip {
    url = "https://cdn.playwright.dev/builds/webkit/${revision'}/webkit-${suffix'}.zip";
    stripRoot = false;
    hash = hashes.${system} or throwSystem;
  };
in
{
  x86_64-linux = webkit-linux;
  aarch64-linux = webkit-linux;
  x86_64-darwin = webkit-darwin;
  aarch64-darwin = webkit-darwin;
}
.${system} or throwSystem
