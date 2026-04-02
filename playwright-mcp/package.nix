{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  playwright-driver,
}:
buildNpmPackage rec {
  pname = "playwright-mcp";
  version = "0.0.70";

  src = fetchFromGitHub {
    owner = "Microsoft";
    repo = "playwright-mcp";
    tag = "v${version}";
    hash = "sha256-dvFFG+/cYy09RjEMDIWncTNCcyaKoKH52qweYq0HHxU=";
  };

  npmDepsHash = "sha256-tyVigQYA/viB8Ycg++SfPF6WEWWulnfuJXZYOBGhhOQ=";
  npmWorkspace = "packages/playwright-mcp";

  postPatch = ''
    substituteInPlace package.json \
      --replace-fail '"packages/*"' '"packages/playwright-mcp"'
  '';

  postInstall = ''
    # Fix workspace symlinks: copy the workspace package into the expected location.
    # The workspace structure requires manual fixup because npm workspaces create
    # symlinks that don't work in the Nix store. We copy the package into place
    # and recreate the symlinks to make the CLI functional.
    local root="$out/lib/node_modules/${pname}"
    rm -f "$root/node_modules/@playwright/mcp"
    rm -f "$root/node_modules/.bin/playwright-mcp"
    mkdir -p "$root/packages"
    cp -r packages/playwright-mcp "$root/packages/"
    ln -s "$root/packages/playwright-mcp" "$root/node_modules/@playwright/mcp"
    ln -s "$root/packages/playwright-mcp/cli.js" "$root/node_modules/.bin/playwright-mcp"

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
