# This file has been generated by node2nix 1.11.1. Do not edit!

{nodeEnv, fetchurl, fetchgit, nix-gitignore, stdenv, lib, globalBuildInputs ? []}:

let
  sources = {
    "@types/node-20.4.8" = {
      name = "_at_types_slash_node";
      packageName = "@types/node";
      version = "20.4.8";
      src = fetchurl {
        url = "https://registry.npmjs.org/@types/node/-/node-20.4.8.tgz";
        sha512 = "0mHckf6D2DiIAzh8fM8f3HQCvMKDpK94YQ0DSVkfWTG9BZleYIWudw9cJxX8oCk9bM+vAkDyujDV6dmKHbvQpg==";
      };
    };
    "fsevents-2.3.2" = {
      name = "fsevents";
      packageName = "fsevents";
      version = "2.3.2";
      src = fetchurl {
        url = "https://registry.npmjs.org/fsevents/-/fsevents-2.3.2.tgz";
        sha512 = "xiqMQR4xAeHTuB9uWm+fFRcIOgKBMiOBP+eXiyT7jsgVCq1bkVygt00oASowB7EdtpOHaaPgKt812P9ab+DDKA==";
      };
    };
    "playwright-core-1.36.2" = {
      name = "playwright-core";
      packageName = "playwright-core";
      version = "1.36.2";
      src = fetchurl {
        url = "https://registry.npmjs.org/playwright-core/-/playwright-core-1.36.2.tgz";
        sha512 = "sQYZt31dwkqxOrP7xy2ggDfEzUxM1lodjhsQ3NMMv5uGTRDsLxU0e4xf4wwMkF2gplIxf17QMBCodSFgm6bFVQ==";
      };
    };
  };
in
{
  "@playwright/test-1.36.2" = nodeEnv.buildNodePackage {
    name = "_at_playwright_slash_test";
    packageName = "@playwright/test";
    version = "1.36.2";
    src = fetchurl {
      url = "https://registry.npmjs.org/@playwright/test/-/test-1.36.2.tgz";
      sha512 = "2rVZeyPRjxfPH6J0oGJqE8YxiM1IBRyM8hyrXYK7eSiAqmbNhxwcLa7dZ7fy9Kj26V7FYia5fh9XJRq4Dqme+g==";
    };
    dependencies = [
      sources."@types/node-20.4.8"
      sources."fsevents-2.3.2"
      sources."playwright-core-1.36.2"
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
