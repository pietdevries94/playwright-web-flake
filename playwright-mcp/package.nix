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
    mkdir -p "$root/node_modules/@playwright"
    mkdir -p "$root/node_modules/.bin"
    ln -s "$root/packages/playwright-mcp" "$root/node_modules/@playwright/mcp"
    ln -s "$root/packages/playwright-mcp/cli.js" "$root/node_modules/.bin/playwright-mcp"

    # Fix symlinks in playwright-mcp-internal if it exists
    local internal="$out/lib/node_modules/playwright-mcp-internal"
    if [ -d "$internal" ]; then
      rm -f "$internal/node_modules/@playwright/mcp"
      rm -f "$internal/node_modules/.bin/playwright-mcp"
      mkdir -p "$internal/node_modules/@playwright"
      mkdir -p "$internal/node_modules/.bin"
      ln -s "$root/packages/playwright-mcp" "$internal/node_modules/@playwright/mcp"
      ln -s "$root/packages/playwright-mcp/cli.js" "$internal/node_modules/.bin/playwright-mcp"
    fi

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
