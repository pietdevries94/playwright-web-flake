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
        "ubuntu-24.04" + (lib.removePrefix "linux" suffix)
      }.zip";
      hash =
        {
          x86_64-linux = "sha256-ucbiiO5F8NJAkELa5fkPtmrUEbJ/EgQzJSAEeLpjAqQ=";
          aarch64-linux = "sha256-H2WU+P1XuXrSs2qZwNIkAOP2o5KS76SvALEZ/YuEHSs=";
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
        x86_64-darwin = "sha256-7EPn9yi9nJ1+nsN3PduNMh85A9c7V37ETKSO402JGiM=";
        aarch64-darwin = "sha256-Hb3JLggEQzrNFGrmCQHN4QbGQXCifHL6SYOtQtVLPH4=";
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
