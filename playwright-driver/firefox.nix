{
  lib,
  stdenv,
  fetchzip,
  firefox-bin,
  suffix,
  revision,
  system,
  throwSystem,
}:
let
  firefox-linux = stdenv.mkDerivation {
    name = "playwright-firefox";
    src = fetchzip {
      url = "https://cdn.playwright.dev/builds/firefox/${revision}/firefox-${
        "ubuntu-22.04" + (lib.removePrefix "linux" suffix)
      }.zip";
      hash =
        {
          x86_64-linux = "sha256-ET3JUpCvA+0zFIYFadh2l1MxRug54V8CY1eax/f+ZDI=";
          aarch64-linux = "sha256-FdWY9mn9tBwqcmWNgEQ9GRZXXUsOZDr5UkfmSmafUek=";
        }
        .${system} or throwSystem;
    };

    inherit (firefox-bin.unwrapped)
      nativeBuildInputs
      buildInputs
      runtimeDependencies
      appendRunpaths
      patchelfFlags
      ;

    buildPhase = ''
      mkdir -p $out/firefox
      cp -R . $out/firefox
    '';
  };
  firefox-darwin = fetchzip {
    url = "https://cdn.playwright.dev/builds/firefox/${revision}/firefox-${suffix}.zip";
    stripRoot = false;
    hash =
      {
        x86_64-darwin = "sha256-eXS88URYKAbFP6/3pukb2qgrdqVBOR99VGyqKPFZ2Tw=";
        aarch64-darwin = "sha256-lVNFp20v+zBC3Up9ElhWh8C8ptEUqCHEsfQiuPp3lVM=";
      }
      .${system} or throwSystem;
  };
in
{
  x86_64-linux = firefox-linux;
  aarch64-linux = firefox-linux;
  x86_64-darwin = firefox-darwin;
  aarch64-darwin = firefox-darwin;
}
.${system} or throwSystem
