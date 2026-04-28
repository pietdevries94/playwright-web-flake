{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  playwright-driver,
  versions,
}:
buildNpmPackage rec {
  pname = "playwright-mcp";
  inherit (versions.mcp) version;

  src = fetchFromGitHub {
    owner = "Microsoft";
    repo = "playwright-mcp";
    tag = "v${version}";
    inherit (versions.mcp) hash;
  };

  inherit (versions.mcp) npmDepsHash;

  postInstall = ''
    wrapProgram $out/bin/playwright-mcp \
      --set PLAYWRIGHT_BROWSERS_PATH ${playwright-driver.browsers} \
      --set-default PLAYWRIGHT_MCP_BROWSER chromium \
      --run 'if [ -z "$PLAYWRIGHT_MCP_USER_DATA_DIR" ]; then PLAYWRIGHT_MCP_USER_DATA_DIR="$(mktemp -d -t mcp-pw-XXXXXX)"; export PLAYWRIGHT_MCP_USER_DATA_DIR; trap "rm -rf \"$PLAYWRIGHT_MCP_USER_DATA_DIR\"" EXIT; fi'
  '';

  dontNpmBuild = true;

  meta = {
    changelog = "https://github.com/Microsoft/playwright-mcp/releases/tag/v${version}";
    description = "Playwright MCP server";
    homepage = "https://github.com/Microsoft/playwright-mcp";
    license = lib.licenses.asl20;
    mainProgram = "playwright-mcp";
  };
}
