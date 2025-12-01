# Playwright Web Flake

This nix flake provides a way to install [Playwright](https://playwright.dev/) and its browsers in a nixOS system.
It does not contain playwright-python, because for my personal use I don't need it and it sometimes lags behind the latest version of playwright.

## Usage

> [!IMPORTANT]  
> All versions up to 1.57.0 were published earlier with a now deprecated CDN url. These versions still work, but on 1 december 2025 all tags were retagged to use the new CDN url. If you used this flake before that date, please run `nix flake update` to get the updated version of whichever version of Playwright you were using.

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
