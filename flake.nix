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
          inherit ((pkgs.callPackage ./playwright-driver/driver.nix { })) playwright-test;
          playwright-driver = (pkgs.callPackage ./playwright-driver/driver.nix { }).playwright-core;
          playwright-mcp = pkgs.callPackage ./playwright-mcp/package.nix {
            inherit (self.packages.${system}) playwright-driver;
          };
        };

        checks = {
          playwright-test = pkgs.runCommand "check-playwright-test" {
            nativeBuildInputs = [ self.packages.${system}.playwright-test ];
          } ''
            playwright --version | grep "${self.packages.${system}.playwright-test.version}"
            touch $out
          '';
          playwright-driver = pkgs.runCommand "check-playwright-driver" { } ''
            test -d "${self.packages.${system}.playwright-driver.browsers}"
            test $(ls "${self.packages.${system}.playwright-driver.browsers}" | wc -l) -gt 0
            touch $out
          '';
          playwright-mcp = pkgs.runCommand "check-playwright-mcp" {
            nativeBuildInputs = [ self.packages.${system}.playwright-mcp ];
          } ''
            playwright-mcp --help
            touch $out
          '';
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
