{
  fetchzip,
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
  hash = hashes.${system} or throwSystem;
}
