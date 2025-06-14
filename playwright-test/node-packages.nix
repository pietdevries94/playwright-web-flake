# This file has been generated by node2nix 1.11.1. Do not edit!

{nodeEnv, fetchurl, fetchgit, nix-gitignore, stdenv, lib, globalBuildInputs ? []}:

let
  sources = {
    "playwright-1.53.0" = {
      name = "playwright";
      packageName = "playwright";
      version = "1.53.0";
      src = fetchurl {
        url = "https://registry.npmjs.org/playwright/-/playwright-1.53.0.tgz";
        sha512 = "ghGNnIEYZC4E+YtclRn4/p6oYbdPiASELBIYkBXfaTVKreQUYbMUYQDwS12a8F0/HtIjr/CkGjtwABeFPGcS4Q==";
      };
    };
    "playwright-core-1.53.0" = {
      name = "playwright-core";
      packageName = "playwright-core";
      version = "1.53.0";
      src = fetchurl {
        url = "https://registry.npmjs.org/playwright-core/-/playwright-core-1.53.0.tgz";
        sha512 = "mGLg8m0pm4+mmtB7M89Xw/GSqoNC+twivl8ITteqvAndachozYe2ZA7srU6uleV1vEdAHYqjq+SV8SNxRRFYBw==";
      };
    };
  };
in
{
  "@playwright/test-1.53.0" = nodeEnv.buildNodePackage {
    name = "_at_playwright_slash_test";
    packageName = "@playwright/test";
    version = "1.53.0";
    src = fetchurl {
      url = "https://registry.npmjs.org/@playwright/test/-/test-1.53.0.tgz";
      sha512 = "15hjKreZDcp7t6TL/7jkAo6Df5STZN09jGiv5dbP9A6vMVncXRqE7/B2SncsyOwrkZRBH2i6/TPOL8BVmm3c7w==";
    };
    dependencies = [
      sources."playwright-1.53.0"
      sources."playwright-core-1.53.0"
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
