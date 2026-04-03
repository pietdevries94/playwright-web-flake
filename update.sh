#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq prefetch-npm-deps unzip nix-prefetch nix-prefetch-github
# shellcheck shell=bash
set -euo pipefail
set -x

root="$(dirname "$(readlink -f "$0")")"
repo_root="$(git -C "$root" rev-parse --show-toplevel)"
cd "$repo_root"

versions_file="$root/versions.json"
playwright_browsers_file="$root/playwright-driver/browsers.json"
playwright_raw_repo_url="https://raw.githubusercontent.com/microsoft/playwright"
driver_version=$(curl ${GITHUB_TOKEN:+" -u \":$GITHUB_TOKEN\""} -s https://api.github.com/repos/microsoft/playwright/releases/latest | jq -r '.tag_name | sub("^v"; "")')
mcp_version=$(curl ${GITHUB_TOKEN:+" -u \":$GITHUB_TOKEN\""} -s https://api.github.com/repos/microsoft/playwright-mcp/releases/latest | jq -r '.tag_name | sub("^v"; "")')
browser_names=(chromium chromium-headless-shell firefox webkit ffmpeg)
browser_platforms=(linux darwin)

# Compute driver source hash
driver_new_hash=$(nix-prefetch-github --rev "v$driver_version" "Microsoft" "playwright" | jq -r '.hash')

temp_dir=$(mktemp -d)
mcp_temp_dir=""
cleanup() { rm -rf "$temp_dir" "$mcp_temp_dir"; }
trap cleanup EXIT

prefetch_browser() {
    local url="$1"
    local strip_root="$2"

    nix-prefetch --option extra-experimental-features flakes -q "{ stdenv, fetchzip }: stdenv.mkDerivation { name=\"browser\"; src = fetchzip { url = \"$url\"; stripRoot = $strip_root; }; }"
}

get_revision() {
    local name="$1"
    local platform="$2"
    local arch="$3"
    local base_revision="$4"
    local override_key=""

    if [ "$platform" = "darwin" ]; then
        if [ "$name" = "webkit" ]; then
            if [ "$arch" = "x86_64" ]; then
                override_key="mac14"
            else
                override_key="mac14-arm64"
            fi
        elif [ "$name" = "ffmpeg" ]; then
            if [ "$arch" = "x86_64" ]; then
                override_key="mac12"
            else
                override_key="mac12-arm64"
            fi
        fi
    fi

    if [ -n "$override_key" ]; then
        local override_revision
        override_revision="$(jq -r ".browsers[\"$name\"].revisionOverrides[\"$override_key\"] // empty" "$playwright_browsers_file")"
        if [ -n "$override_revision" ]; then
            echo "$override_revision"
            return
        fi
    fi

    echo "$base_revision"
}

browser_download_url() {
    local name="$1"
    local buildname="$2"
    local platform="$3"
    local arch="$4"
    local revision="$5"
    local browser_version="$6"
    local suffix="$7"
    local artifact
    local cft_platform

    if [ "$name" = "chromium" ] || [ "$name" = "chromium-headless-shell" ]; then
        if [ "$name" = "chromium" ]; then
            artifact="chrome"
        else
            artifact="chrome-headless-shell"
        fi

        if [ "$platform" = "linux" ] && [ "$arch" = "x86_64" ]; then
            echo "https://cdn.playwright.dev/chrome-for-testing-public/${browser_version}/linux64/${artifact}-linux64.zip"
            return
        fi

        if [ "$platform" = "darwin" ]; then
            if [ "$arch" = "x86_64" ]; then
                cft_platform="mac-x64"
            else
                cft_platform="mac-arm64"
            fi
            echo "https://cdn.playwright.dev/chrome-for-testing-public/${browser_version}/${cft_platform}/${artifact}-${cft_platform}.zip"
            return
        fi
    fi

    if [ "$name" = "webkit" ] && [ "$platform" = "darwin" ]; then
        echo "https://cdn.playwright.dev/builds/${buildname}/${revision}/${name}-${suffix}.zip"
        return
    fi

    echo "https://cdn.playwright.dev/dbazure/download/playwright/builds/${buildname}/${revision}/${name}-${suffix}.zip"
}

# Declare associative array for browser hashes
declare -A browser_hashes

update_browser() {
    local name="$1"
    local platform="$2"
    local stripRoot="false"
    local suffix
    local aarch64_suffix
    local buildname
    local browser_version

    if [ "$platform" = "darwin" ]; then
        if [ "$name" = "webkit" ]; then
            suffix="mac-14"
        else
            suffix="mac"
        fi
    else
        if [ "$name" = "ffmpeg" ] || [ "$name" = "chromium-headless-shell" ]; then
            suffix="linux"
        elif [ "$name" = "chromium" ]; then
            stripRoot="true"
            suffix="linux"
        elif [ "$name" = "firefox" ]; then
            stripRoot="true"
            suffix="ubuntu-22.04"
        else
            suffix="ubuntu-22.04"
        fi
    fi
    aarch64_suffix="$suffix-arm64"
    if [ "$name" = "chromium-headless-shell" ]; then
        buildname="chromium"
    else
        buildname="$name"
    fi

    local base_revision
    base_revision="$(jq -r ".browsers[\"$buildname\"].revision" "$playwright_browsers_file")"
    browser_version="$(jq -r ".browsers[\"$buildname\"].browserVersion // empty" "$playwright_browsers_file")"

    local x86_64_revision
    local aarch64_revision
    x86_64_revision="$(get_revision "$name" "$platform" "x86_64" "$base_revision")"
    aarch64_revision="$(get_revision "$name" "$platform" "aarch64" "$base_revision")"

    local x86_64_url
    local aarch64_url
    x86_64_url="$(browser_download_url "$name" "$buildname" "$platform" "x86_64" "$x86_64_revision" "$browser_version" "$suffix")"
    aarch64_url="$(browser_download_url "$name" "$buildname" "$platform" "aarch64" "$aarch64_revision" "$browser_version" "$aarch64_suffix")"

    browser_hashes["${name}.x86_64-${platform}"]="$(prefetch_browser "$x86_64_url" "$stripRoot")"
    browser_hashes["${name}.aarch64-${platform}"]="$(prefetch_browser "$aarch64_url" "$stripRoot")"
}

# Update browsers.json from upstream
curl -fsSL \
    "https://raw.githubusercontent.com/microsoft/playwright/v${driver_version}/packages/playwright-core/browsers.json" \
    | jq '
      .comment = "This file is kept up to date via update.sh"
      | .browsers |= (
        [.[]
          | select(.installByDefault) | del(.installByDefault)]
          | map({(.name): . | del(.name)})
          | add
      )
    ' > "$playwright_browsers_file"

# Compute all browser hashes
for platform in "${browser_platforms[@]}"; do
    for browser in "${browser_names[@]}"; do
        update_browser "$browser" "$platform"
    done
done

# Compute npm dependency hashes for driver bundles
declare -A npm_hashes
npm_source_roots=(
    "/packages/playwright/bundles/babel"
    "/packages/playwright/bundles/expect"
    "/packages/playwright/bundles/utils"
    "/packages/playwright-core/bundles/utils"
    "/packages/playwright-core/bundles/zip"
    ""
)

for source_root_path in "${npm_source_roots[@]}"; do
    if [ -n "$source_root_path" ]; then
        download_url="${playwright_raw_repo_url}/v${driver_version}${source_root_path}/package-lock.json"
    else
        download_url="${playwright_raw_repo_url}/v${driver_version}/package-lock.json"
    fi
    lock_file="${temp_dir}/$(echo "$source_root_path" | tr '/.' '__').package-lock.json"
    curl -fsSL -o "$lock_file" "$download_url"
    # Use safe key by replacing / with _ for associative array
    # Use "root" for empty path since bash doesn't allow empty string keys
    if [ -n "$source_root_path" ]; then
        safe_key=$(echo "$source_root_path" | tr '/' '_')
    else
        safe_key="root"
    fi
    npm_hashes["$safe_key"]=$(prefetch-npm-deps "$lock_file")
done

# Compute MCP hashes
echo "Updating playwright-mcp to v${mcp_version}..."
mcp_new_hash=$(nix-prefetch-github --rev "v${mcp_version}" "Microsoft" "playwright-mcp" | jq -r '.hash')
mcp_temp_dir=$(mktemp -d)
mcp_lock_url="https://raw.githubusercontent.com/microsoft/playwright-mcp/v${mcp_version}/package-lock.json"
curl -fsSL -o "$mcp_temp_dir/package-lock.json" "$mcp_lock_url"
mcp_npm_hash=$(prefetch-npm-deps "$mcp_temp_dir/package-lock.json")

# Build versions.json with all computed values
jq -n \
    --arg driver_version "$driver_version" \
    --arg driver_hash "$driver_new_hash" \
    --arg npm_babel "${npm_hashes["_packages_playwright_bundles_babel"]}" \
    --arg npm_expect "${npm_hashes["_packages_playwright_bundles_expect"]}" \
    --arg npm_utils "${npm_hashes["_packages_playwright_bundles_utils"]}" \
    --arg npm_utils_core "${npm_hashes["_packages_playwright-core_bundles_utils"]}" \
    --arg npm_zip "${npm_hashes["_packages_playwright-core_bundles_zip"]}" \
    --arg npm_root "${npm_hashes["root"]}" \
    --arg chromium_x86_64_linux "${browser_hashes["chromium.x86_64-linux"]}" \
    --arg chromium_aarch64_linux "${browser_hashes["chromium.aarch64-linux"]}" \
    --arg chromium_x86_64_darwin "${browser_hashes["chromium.x86_64-darwin"]}" \
    --arg chromium_aarch64_darwin "${browser_hashes["chromium.aarch64-darwin"]}" \
    --arg chromium_hs_x86_64_linux "${browser_hashes["chromium-headless-shell.x86_64-linux"]}" \
    --arg chromium_hs_aarch64_linux "${browser_hashes["chromium-headless-shell.aarch64-linux"]}" \
    --arg chromium_hs_x86_64_darwin "${browser_hashes["chromium-headless-shell.x86_64-darwin"]}" \
    --arg chromium_hs_aarch64_darwin "${browser_hashes["chromium-headless-shell.aarch64-darwin"]}" \
    --arg firefox_x86_64_linux "${browser_hashes["firefox.x86_64-linux"]}" \
    --arg firefox_aarch64_linux "${browser_hashes["firefox.aarch64-linux"]}" \
    --arg firefox_x86_64_darwin "${browser_hashes["firefox.x86_64-darwin"]}" \
    --arg firefox_aarch64_darwin "${browser_hashes["firefox.aarch64-darwin"]}" \
    --arg webkit_x86_64_linux "${browser_hashes["webkit.x86_64-linux"]}" \
    --arg webkit_aarch64_linux "${browser_hashes["webkit.aarch64-linux"]}" \
    --arg webkit_x86_64_darwin "${browser_hashes["webkit.x86_64-darwin"]}" \
    --arg webkit_aarch64_darwin "${browser_hashes["webkit.aarch64-darwin"]}" \
    --arg ffmpeg_x86_64_linux "${browser_hashes["ffmpeg.x86_64-linux"]}" \
    --arg ffmpeg_aarch64_linux "${browser_hashes["ffmpeg.aarch64-linux"]}" \
    --arg ffmpeg_x86_64_darwin "${browser_hashes["ffmpeg.x86_64-darwin"]}" \
    --arg ffmpeg_aarch64_darwin "${browser_hashes["ffmpeg.aarch64-darwin"]}" \
    --arg mcp_version "$mcp_version" \
    --arg mcp_hash "$mcp_new_hash" \
    --arg mcp_npm_hash "$mcp_npm_hash" \
    '{
      driver: {
        version: $driver_version,
        hash: $driver_hash,
        npmDepsHashes: {
          "/packages/playwright/bundles/babel": $npm_babel,
          "/packages/playwright/bundles/expect": $npm_expect,
          "/packages/playwright/bundles/utils": $npm_utils,
          "/packages/playwright-core/bundles/utils": $npm_utils_core,
          "/packages/playwright-core/bundles/zip": $npm_zip,
          "": $npm_root
        }
      },
      browsers: {
        chromium: {
          "x86_64-linux": $chromium_x86_64_linux,
          "aarch64-linux": $chromium_aarch64_linux,
          "x86_64-darwin": $chromium_x86_64_darwin,
          "aarch64-darwin": $chromium_aarch64_darwin
        },
        "chromium-headless-shell": {
          "x86_64-linux": $chromium_hs_x86_64_linux,
          "aarch64-linux": $chromium_hs_aarch64_linux,
          "x86_64-darwin": $chromium_hs_x86_64_darwin,
          "aarch64-darwin": $chromium_hs_aarch64_darwin
        },
        firefox: {
          "x86_64-linux": $firefox_x86_64_linux,
          "aarch64-linux": $firefox_aarch64_linux,
          "x86_64-darwin": $firefox_x86_64_darwin,
          "aarch64-darwin": $firefox_aarch64_darwin
        },
        webkit: {
          "x86_64-linux": $webkit_x86_64_linux,
          "aarch64-linux": $webkit_aarch64_linux,
          "x86_64-darwin": $webkit_x86_64_darwin,
          "aarch64-darwin": $webkit_aarch64_darwin
        },
        ffmpeg: {
          "x86_64-linux": $ffmpeg_x86_64_linux,
          "aarch64-linux": $ffmpeg_aarch64_linux,
          "x86_64-darwin": $ffmpeg_x86_64_darwin,
          "aarch64-darwin": $ffmpeg_aarch64_darwin
        }
      },
      mcp: {
        version: $mcp_version,
        hash: $mcp_hash,
        npmDepsHash: $mcp_npm_hash
      }
    }' > "$versions_file"

echo "playwright-mcp updated to v${mcp_version}"
echo "All versions written to versions.json"

# Write version for commit message
echo "${driver_version}" > version.txt
