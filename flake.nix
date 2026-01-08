{
  description = "A flake for playwright";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        packages = {
          playwright-test = (pkgs.callPackage ./playwright-driver/driver.nix { }).playwright-test;
          playwright-driver = (pkgs.callPackage ./playwright-driver/driver.nix { }).playwright-core;
        };

        devShells.default = pkgs.mkShell {
          packages = [
            self.packages.${system}.playwright-test
          ];
          shellHook = ''
            export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
            export PLAYWRIGHT_BROWSERS_PATH="${self.packages.${system}.playwright-driver.browsers}"
          '';
        };
      }
    );
}
