#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl gnused nix-prefetch common-updater-scripts node2nix jq
set -euo pipefail

root="$(dirname "$(readlink -f "$0")")"
driver_file="$root/playwright-driver/default.nix"
playwright_test="$root/playwright-test"

version=$(curl ${GITHUB_TOKEN:+" -u \":$GITHUB_TOKEN\""} -s https://api.github.com/repos/microsoft/playwright/releases/latest | jq -r '.tag_name | sub("^v"; "")')

fetch_driver_arch() {
  nix-prefetch-url "https://cdn.playwright.dev/builds/driver/playwright-${version}-${1}.zip"
}

replace_sha() {
  sed -i "s|$1 = \".\{44,52\}\"|$1 = \"$2\"|" "$driver_file"
}

# Replace SHAs for the driver downloads
replace_sha "x86_64-linux" "$(fetch_driver_arch "linux")"
replace_sha "x86_64-darwin" "$(fetch_driver_arch "mac")"
replace_sha "aarch64-linux" "$(fetch_driver_arch "linux-arm64")"
replace_sha "aarch64-darwin" "$(fetch_driver_arch "mac-arm64")"

# Update the version stamps
sed -i "s/version =\s*\"[^\$]*\"/version = \"$version\"/" "$driver_file"
sed -i "s/\"@playwright\/test\": \"[^\$]*\"/\"@playwright\/test\": \"$version\"/" "$playwright_test/node-packages.json"
echo "$version" > "$root/version.txt"

# Check if files have changed
if git diff --exit-code; then
  echo "No changes"
  exit 0
fi

# Update the node-packages.json
(cd "$playwright_test"; node2nix -i node-packages.json)
