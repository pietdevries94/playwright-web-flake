# Playwright Web Flake

This nix flake provides a way to install [Playwright](https://playwright.dev/) and its browsers in a nixos system.
It does not contain playwright-python, because for my personal use I don't need it and it sometimes lags behind the latest version of playwright.

## Usage

### nix shell

```sh
nix shell github:pietdevries94/playwright-web-flake#playwright-test
which playwright && playwright --version && playwright open nixos.org
```

### In a flake

```nix
{
  description = "Playwright development environment";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.playwright.url = "github:pietdevries94/playwright-web-flake"; # To set a custom version: "github:pietdevries94/playwright-web-flake/1.37.1"

  outputs =
    { self
    , flake-utils
    , nixpkgs
    , playwright
    }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      overlay = final: prev: {
        inherit (playwright.packages.${system}) playwright-test playwright-driver;
      };
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ overlay ];
      };
    in
    {
      devShells = {
        default = pkgs.mkShell {
          packages = [
            pkgs.playwright-test
          ];
          shellHook = ''
            export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
            export PLAYWRIGHT_BROWSERS_PATH="${pkgs.playwright-driver.browsers}"
          '';
        };
      };
    });
}
```

1. Create a flake.nix.
1. Enter the development environment with `nix develop`.

## Versioning

The update workflow tags the commit with the version of playwright that is installed. This version can be used to checkout the commit that installed that version of playwright, to match your environment.
