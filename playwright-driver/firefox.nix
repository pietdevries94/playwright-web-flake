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
          x86_64-linux = "sha256-ol9Ai8BpstZdfd6v1NDq66BjLTr/5THya0Fk2z1toJg=";
          aarch64-linux = "sha256-G0pcHmjRj5GKsDF7iHdQyGsJCiv4gqaFv2PwGa/t8bw=";
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
        x86_64-darwin = "sha256-nV+oV7Zp2rAWkMWAs//PnWCA0q2jzS5hjr5AEXuEoos=";
        aarch64-darwin = "sha256-Opwa5SbuAaXf2A+qrldHc6BkhRaOzzl0dy7R4vodG5w=";
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
