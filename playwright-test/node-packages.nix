# This file has been generated by node2nix 1.11.1. Do not edit!

{nodeEnv, fetchurl, fetchgit, nix-gitignore, stdenv, lib, globalBuildInputs ? []}:

let
  sources = {
    "playwright-1.45.1" = {
      name = "playwright";
      packageName = "playwright";
      version = "1.45.1";
      src = fetchurl {
        url = "https://registry.npmjs.org/playwright/-/playwright-1.45.1.tgz";
        sha512 = "Hjrgae4kpSQBr98nhCj3IScxVeVUixqj+5oyif8TdIn2opTCPEzqAqNMeK42i3cWDCVu9MI+ZsGWw+gVR4ISBg==";
      };
    };
    "playwright-core-1.45.1" = {
      name = "playwright-core";
      packageName = "playwright-core";
      version = "1.45.1";
      src = fetchurl {
        url = "https://registry.npmjs.org/playwright-core/-/playwright-core-1.45.1.tgz";
        sha512 = "LF4CUUtrUu2TCpDw4mcrAIuYrEjVDfT1cHbJMfwnE2+1b8PZcFzPNgvZCvq2JfQ4aTjRCCHw5EJ2tmr2NSzdPg==";
      };
    };
  };
in
{
  "@playwright/test-1.45.1" = nodeEnv.buildNodePackage {
    name = "_at_playwright_slash_test";
    packageName = "@playwright/test";
    version = "1.45.1";
    src = fetchurl {
      url = "https://registry.npmjs.org/@playwright/test/-/test-1.45.1.tgz";
      sha512 = "Wo1bWTzQvGA7LyKGIZc8nFSTFf2TkthGIFBR+QVNilvwouGzFd4PYukZe3rvf5PSqjHi1+1NyKSDZKcQWETzaA==";
    };
    dependencies = [
      sources."playwright-1.45.1"
      sources."playwright-core-1.45.1"
    ];
    buildInputs = globalBuildInputs;
    meta = {
      description = "A high-level API to automate web browsers";
      homepage = "https://playwright.dev";
      license = "Apache-2.0";
    };
    production = true;
    bypassCache = true;
    reconstructLock = true;
  };
}
