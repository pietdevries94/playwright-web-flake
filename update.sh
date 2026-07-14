#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl gnused nix-prefetch common-updater-scripts node2nix jq
set -euo pipefail

root="$(dirname "$(readlink -f "$0")")"
driver_file="$root/playwright-driver/default.nix"
playwright_test="$root/playwright-test"

if (( $# > 1 )); then
  echo "usage: $0 [version]" >&2
  exit 2
fi

if (( $# == 1 )); then
  version="${1#v}"
else
  version="$(
    curl ${GITHUB_TOKEN:+"-u :$GITHUB_TOKEN"} \
      --fail \
      --silent \
      --show-error \
      https://api.github.com/repos/microsoft/playwright/releases/latest |
      jq -er '.tag_name | sub("^v"; "")'
  )"
fi

pypi_json="$(
  curl \
    --fail \
    --silent \
    --show-error \
    "https://pypi.org/pypi/playwright/${version}/json"
)"

wheel_info() {
  local system="$1"
  local filename_regex

  case "$system" in
    x86_64-linux)
      filename_regex='manylinux[^/]*_x86_64\.whl$'
      ;;
    aarch64-linux)
      filename_regex='manylinux[^/]*_aarch64\.whl$'
      ;;
    x86_64-darwin)
      filename_regex='macosx_[^/]*_x86_64\.whl$'
      ;;
    aarch64-darwin)
      filename_regex='macosx_[^/]*_arm64\.whl$'
      ;;
    *)
      echo "unsupported system: $system" >&2
      return 1
      ;;
  esac

  jq -ec \
    --arg regex "$filename_regex" \
    '
      [
        .urls[]
        | select(.packagetype == "bdist_wheel")
        | select(.filename | test($regex))
        | {
            filename,
            url
          }
      ]
      | if length == 1 then
          .[0]
        elif length == 0 then
          error("no matching wheel")
        else
          error("multiple matching wheels: \(.)")
        end
    ' <<<"$pypi_json"
}

replace_wheel() {
  local system="$1"
  local info filename url hash

  info="$(wheel_info "$system")"
  filename="$(jq -r '.filename' <<<"$info")"
  url="$(jq -r '.url' <<<"$info")"

  hash="$(
    nix-prefetch-url "$url" |
      xargs nix hash to-sri --type sha256
  )"

  echo "$system:"
  echo "  filename: $filename"
  echo "  URL:      $url"
  echo "  hash:     $hash"

  SYSTEM="$system" \
  FILENAME="$filename" \
  URL="$url" \
  HASH="$hash" \
    perl -0pi -e '
      my $system = quotemeta($ENV{"SYSTEM"});

      my $count = s{
        (^ \s* $system \s* = \s* \{)
        (.*?)
        (^ \s* \};)
      }{
        my ($start, $body, $end) = ($1, $2, $3);

        my $filename_count = $body =~ s{
          ^([ \t]*)filename[ \t]*=[ \t]*"[^"]*";[ \t]*$
        }{
          $1 . qq{filename = "$ENV{FILENAME}";}
        }gmex;

        my $url_count = $body =~ s{
          ^([ \t]*)url[ \t]*=[ \t]*"[^"]*";[ \t]*$
        }{
          $1 . qq{url = "$ENV{URL}";}
        }gmex;

        my $hash_count = $body =~ s{
          ^([ \t]*)hash[ \t]*=[ \t]*"[^"]*";[ \t]*$
        }{
          $1 . qq{hash = "$ENV{HASH}";}
        }gmex;

        die "missing filename for $ENV{SYSTEM}\n"
          unless $filename_count == 1;

        die "missing URL for $ENV{SYSTEM}\n"
          unless $url_count == 1;

        die "missing hash for $ENV{SYSTEM}\n"
          unless $hash_count == 1;

        "$start$body$end";
      }gmsex;

      die "could not find exactly one wheel block for $ENV{SYSTEM}\n"
        unless $count == 1;
    ' "$driver_file"
}

replace_wheel x86_64-linux
replace_wheel x86_64-darwin
replace_wheel aarch64-linux
replace_wheel aarch64-darwin

# Update version stamps.
sed -Ei \
  "s/version = \"[^\"]+\";/version = \"$version\";/" \
  "$driver_file"

sed -Ei \
  "s|(\"@playwright/test\"[[:space:]]*:[[:space:]]*\")[^\"]+\"|\1$version\"|" \
  "$playwright_test/node-packages.json"

printf '%s\n' "$version" >"$root/version.txt"

# Check whether the source inputs changed before running node2nix.
if git diff --exit-code -- \
  "$driver_file" \
  "$playwright_test/node-packages.json" \
  "$root/version.txt"
then
  echo "No changes"
  echo "updated=false" >"$root/updated.txt"
  exit 0
fi

(
  cd "$playwright_test"
  node2nix -i node-packages.json
)

echo "updated=true" >"$root/updated.txt"
