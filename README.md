# Playwright Web Flake

This nix flake provides a way to install [Playwright](https://playwright.dev/) and its browsers in a nixOS system.
It does not contain playwright-python, because for my personal use I don't need it and it sometimes lags behind the latest version of playwright.

## Usage

> [!IMPORTANT]
> All versions up to and including 1.58.1 were previously published with a Playwright driver URL that is no longer available. On 14 July 2026, all affected tags with an exact matching PyPI wheel were retagged to fetch the driver from PyPI instead.
> 
> If you used this flake before that date, run `nix flake update` to get the repaired version of whichever Playwright release you were using.
> 
> <details>
> <summary>Versions that could not be repaired</summary>
> 
> These Playwright versions do not have an exact matching PyPI wheel and therefore still use the unavailable upstream driver URL:
> 
> - `1.36.2`
> - `1.37.1`
> - `1.38.1`
> - `1.40.1`
> - `1.42.1`
> - `1.43.1`
> - `1.44.1`
> - `1.45.2`
> - `1.45.3`
> - `1.46.1`
> - `1.47.1`
> - `1.47.2`
> - `1.48.1`
> - `1.48.2`
> - `1.50.1`
> - `1.51.1`
> - `1.53.1`
> - `1.53.2`
> - `1.54.1`
> - `1.54.2`
> - `1.55.1`
> - `1.56.1`
> - `1.58.1`
>
> If you need any of these, make an issue.
> </details>

See the [`nix shell`](#with-nix-shell) example if all you need is access to the `playwright` binary in the current shell.

If you intend to run a test suite:

- See the [`nix develop`](#with-nix-develop) example if the codebase you're working in does not already have a `flake.nix`, and you don't want to add one.
- If the codebase already uses a flake.nix, adapt it like the flake.nix shown [below](#in-a-flake).

### With `nix shell`

Get access to the `playwright` binary in the current shell.

```sh
nix shell github:pietdevries94/playwright-web-flake#playwright-test

which playwright && playwright --version && playwright open nixos.org
```

### With `nix develop`

Gets access to the `playwright` binary in the current shell and sets some playwright environment variables.

```sh
nix develop github:pietdevries94/playwright-web-flake

which playwright && playwright --version && playwright open nixos.org
```

### In a flake

1. Create a flake.nix with the content shown below.
1. Enter the devshell with `nix develop`.

```nix
{
  description = "Playwright development environment";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.playwright.url = "github:pietdevries94/playwright-web-flake";

  outputs = { self, flake-utils, nixpkgs, playwright }:
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

## Versioning

The update workflow tags the commit with the version of playwright that is installed. This version can be used to checkout the commit that installed that version of playwright, to match your environment.

The list of available versions can be found [here](https://github.com/pietdevries94/playwright-web-flake/tags).

The [flake reference](https://nix.dev/manual/nix/2.24/command-ref/new-cli/nix3-flake.html#examples) can be modified to specify a custom version.

### Example: specify a custom version in a flake

```diff
-inputs.playwright.url = "github:pietdevries94/playwright-web-flake";
+inputs.playwright.url = "github:pietdevries94/playwright-web-flake/1.37.1";
```

### Example: specify a custom version on the command line

```diff
-nix develop github:pietdevries94/playwright-web-flake
+nix develop github:pietdevries94/playwright-web-flake/1.37.1
```

## Also see

- https://primamateria.github.io/blog/playwright-nixos-webdev/
