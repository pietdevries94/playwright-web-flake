{
  lib,
  fetchzip,
  suffix,
  revision,
  revisionOverrides ? {},
  system,
  throwSystem,
}:
let
  # Determine the revision override key based on platform
  revisionOverrideKey =
    if system == "x86_64-darwin" then
      "mac12"
    else if system == "aarch64-darwin" then
      "mac12-arm64"
    else
      null;

  # Use revision override if available, otherwise fall back to base revision
  revision' =
    if revisionOverrideKey != null && revisionOverrides ? ${revisionOverrideKey} then
      revisionOverrides.${revisionOverrideKey}
    else
      revision;
in
fetchzip {
  url = "https://cdn.playwright.dev/builds/ffmpeg/${revision'}/ffmpeg-${suffix}.zip";
  stripRoot = false;
  hash =
    {
      x86_64-linux = "sha256-5+WbgtmcKkTaSurejqzkkglNI/0dW7ePxbltOeCiakI=";
      aarch64-linux = "sha256-OTpALfzK0fIjWHaywNVGWwwAaRncYElcV//En3/oOVI=";
      x86_64-darwin = "sha256-YrYHglfjAgn3UI1HlRfI+zr3ZS2vheGnbevdhFPOfwE=";
      aarch64-darwin = "sha256-runukRDgLHIcOLqR/O8Kd3N7q73hXUc1YAPsdj3uqvs=";
    }
    .${system} or throwSystem;
}
