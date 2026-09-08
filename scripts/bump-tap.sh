#!/bin/bash
# Points the homebrew tap at a released version: rewrites the formula url/sha
# and the cask version/sha from the assets attached to that release.
# Usage: scripts/bump-tap.sh <version> <tap-checkout>
# Does not touch git — the caller commits.
set -euo pipefail

VERSION="${1:?usage: bump-tap.sh <version> <tap-checkout>}"
TAP="${2:?usage: bump-tap.sh <version> <tap-checkout>}"
BASE="https://github.com/klabast/macOSDefaultApps/releases/download/v$VERSION"

asset_sha() {
	curl -fsSL "$BASE/$1" | shasum -a 256 | cut -d' ' -f1
}

cli_sha="$(asset_sha "mda-$VERSION-universal.tar.gz")"
app_sha="$(asset_sha "macOSDefaultApps-$VERSION.zip")"

# each of these stanzas appears exactly once per file, anchored at line start
perl -pi -e "s|^  url \".*\"|  url \"$BASE/mda-$VERSION-universal.tar.gz\"|" \
	"$TAP/Formula/mda.rb"
perl -pi -e "s|^  sha256 \".*\"|  sha256 \"$cli_sha\"|" \
	"$TAP/Formula/mda.rb"
perl -pi -e "s|^  version \".*\"|  version \"$VERSION\"|" \
	"$TAP/Casks/macosdefaultapps.rb"
perl -pi -e "s|^  sha256 \".*\"|  sha256 \"$app_sha\"|" \
	"$TAP/Casks/macosdefaultapps.rb"

echo "mda   $VERSION $cli_sha"
echo "cask  $VERSION $app_sha"
