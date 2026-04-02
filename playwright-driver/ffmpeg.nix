{
  fetchzip,
  suffix,
  revision,
  revisionOverrides ? { },
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
      x86_64-linux = "sha256-AWTiui+ccKHxsIaQSgc5gWCJT5gYwIWzAEqSuKgVqZU=";
      aarch64-linux = "sha256-1mOKO2lcnlwLsC6ob//xKnKrCOp94pw8X14uBxCdj0Q=";
      x86_64-darwin = "sha256-ED6noxSDeEUt2DkIQ4gNe/kL+zHVeb2AD5klBk93F88=";
      aarch64-darwin = "sha256-3Adnvb7zvMXKFOhb8uuj5kx0wEIFicmckYx9WLlNNf0=";
    }
    .${system} or throwSystem;
}
