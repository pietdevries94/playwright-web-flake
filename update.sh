#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl gnused common-updater-scripts jq prefetch-npm-deps unzip nix-prefetch nix-prefetch-github
# shellcheck shell=bash
set -euo pipefail
set -x

root="$(dirname "$(readlink -f "$0")")"
repo_root="$(git -C "$root" rev-parse --show-toplevel)"
cd "$repo_root"

github_api_curl_args=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
    github_api_curl_args=(-u ":$GITHUB_TOKEN")
fi

playwright_browsers_file="$root/playwright-driver/browsers.json"
playwright_driver_file="$root/playwright-driver/driver.nix"
playwright_mcp_file="$root/playwright-mcp/package.nix"
playwright_raw_repo_url="https://raw.githubusercontent.com/microsoft/playwright"
driver_version=$(curl ${GITHUB_TOKEN:+" -u \":$GITHUB_TOKEN\""} -s https://api.github.com/repos/microsoft/playwright/releases/latest | jq -r '.tag_name | sub("^v"; "")')
mcp_version=$(curl ${GITHUB_TOKEN:+" -u \":$GITHUB_TOKEN\""} -s https://api.github.com/repos/microsoft/playwright-mcp/releases/latest | jq -r '.tag_name | sub("^v"; "")')
browser_names=(chromium chromium-headless-shell firefox webkit ffmpeg)
browser_platforms=(linux darwin)

github_api_get() {
    curl "${github_api_curl_args[@]}" -fsSL "$1"
}

major_minor() {
    echo "${1%.*}"
}

sed -i "s|version =\s*\"[^\$]*\"|version = \"$driver_version\"|" "$playwright_driver_file"
driver_new_hash=$(nix-prefetch-github --rev "v$driver_version" "Microsoft" "playwright" | jq -r '.hash')
sed -i "s|hash =\s*\"[^\$]*\"|hash = \"$driver_new_hash\"|" "$playwright_driver_file"

temp_dir=$(mktemp -d)
mcp_temp_dir=""
cleanup() { rm -rf "$temp_dir" "$mcp_temp_dir"; }
trap cleanup EXIT

# update binaries of browsers, used by playwright.
replace_sha() {
    local target_file="$1"
    local attr_name="$2"
    local new_hash="$3"

    sed -i "s|$attr_name = \".\{44,52\}\"|$attr_name = \"$new_hash\"|" "$target_file"
}

prefetch_browser() {
    local url="$1"
    local strip_root="$2"

    # nix-prefetch is used to obtain sha with `stripRoot = false`
    # doesn't work on macOS https://github.com/msteen/nix-prefetch/issues/53
    nix-prefetch --option extra-experimental-features flakes -q "{ stdenv, fetchzip }: stdenv.mkDerivation { name=\"browser\"; src = fetchzip { url = \"$url\"; stripRoot = $strip_root; }; }"
}

get_revision() {
    local name="$1"
    local platform="$2"
    local arch="$3"
    local base_revision="$4"
    local override_key=""

    # Determine the revision override key based on platform and arch
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

    # Check for revision override
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

    # Chromium and chromium-headless-shell use Chrome for Testing artifacts on
    # Linux/macOS on x86_64 and aarch64-darwin.
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

    # Webkit on darwin uses a different CDN path
    if [ "$name" = "webkit" ] && [ "$platform" = "darwin" ]; then
        echo "https://cdn.playwright.dev/builds/${buildname}/${revision}/${name}-${suffix}.zip"
        return
    fi

    echo "https://cdn.playwright.dev/dbazure/download/playwright/builds/${buildname}/${revision}/${name}-${suffix}.zip"
}

update_browser() {
    local name="$1"
    local platform="$2"
    local stripRoot="false"
    local suffix
    local aarch64_suffix
    local buildname
    local revision
    local browser_version
    local x86_64_url
    local aarch64_url

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

    # Get platform-specific revisions (handles revisionOverrides)
    local x86_64_revision
    local aarch64_revision
    x86_64_revision="$(get_revision "$name" "$platform" "x86_64" "$base_revision")"
    aarch64_revision="$(get_revision "$name" "$platform" "aarch64" "$base_revision")"

    x86_64_url="$(browser_download_url "$name" "$buildname" "$platform" "x86_64" "$x86_64_revision" "$browser_version" "$suffix")"
    aarch64_url="$(browser_download_url "$name" "$buildname" "$platform" "aarch64" "$aarch64_revision" "$browser_version" "$aarch64_suffix")"
    replace_sha "$root/playwright-driver/$name.nix" "x86_64-$platform" \
        "$(prefetch_browser "$x86_64_url" "$stripRoot")"
    replace_sha "$root/playwright-driver/$name.nix" "aarch64-$platform" \
        "$(prefetch_browser "$aarch64_url" "$stripRoot")"
}

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

for platform in "${browser_platforms[@]}"; do
    for browser in "${browser_names[@]}"; do
        update_browser "$browser" "$platform"
    done
done

# Update package-lock.json files for all npm deps that are built in playwright

# Download `package-lock.json` for a given sourceRoot path and update its hash.
update_hash() {
    local source_root_path="$1"
    local download_url
    local lock_file
    local new_hash
    local source_root_pattern

    download_url="${playwright_raw_repo_url}/v${driver_version}${source_root_path}/package-lock.json"
    lock_file="${temp_dir}/$(echo "$source_root_path" | tr '/.' '__').package-lock.json"
    curl -fsSL -o "$lock_file" "$download_url"
    new_hash=$(prefetch-npm-deps "$lock_file")

    source_root_pattern=$(printf '%s\n' "$source_root_path" | sed 's/[][\\/.*^$+?(){}|]/\\&/g')
    sed -E -i "/sourceRoot = \"\\\$\\{src.name\\}${source_root_pattern}\";/,/npmDepsHash = / s#npmDepsHash = \"[^\"]*\";#npmDepsHash = \"${new_hash}\";#" "$playwright_driver_file"
}

while IFS= read -r source_root_path; do
    update_hash "$source_root_path"
done < <(
    # shellcheck disable=SC2016
    sed -n 's#^[[:space:]]*sourceRoot = "${src.name}\(.*\)";.*$#\1#p' "$playwright_driver_file"
)

# Update playwright-mcp
echo "Updating playwright-mcp to v${mcp_version}..."
sed -i "s|version = \"[^\"]*\"|version = \"${mcp_version}\"|" "$playwright_mcp_file"
mcp_new_hash=$(nix-prefetch-github --rev "v${mcp_version}" "Microsoft" "playwright-mcp" | jq -r '.hash')
sed -i "s|hash = \"[^\"]*\"|hash = \"${mcp_new_hash}\"|" "$playwright_mcp_file"

# Update playwright-mcp npmDepsHash
mcp_temp_dir=$(mktemp -d)
mcp_lock_url="https://raw.githubusercontent.com/microsoft/playwright-mcp/v${mcp_version}/package-lock.json"
curl -fsSL -o "$mcp_temp_dir/package-lock.json" "$mcp_lock_url"
mcp_npm_hash=$(prefetch-npm-deps "$mcp_temp_dir/package-lock.json")
sed -i "s|npmDepsHash = \"[^\"]*\"|npmDepsHash = \"${mcp_npm_hash}\"|" "$playwright_mcp_file"
echo "playwright-mcp updated to v${mcp_version}"
