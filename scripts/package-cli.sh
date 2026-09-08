#!/bin/bash
# Assembles build/mda-<version>-universal.tar.gz — the universal mda binary plus
# the swiftpm resource bundle that Bundle.module looks for beside it.
# Usage: scripts/package-cli.sh [version]   (default: Version.current)
# Set SIGN_IDENTITY to a Developer ID; unset means ad-hoc.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-$(sed -n 's/.*current = "\(.*\)".*/\1/p' Sources/DefaultAppsCore/Version.swift)}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
ARCHS=(--arch arm64 --arch x86_64)

swift build -c release "${ARCHS[@]}" --product mda
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)"

STAGE="build/mda-$VERSION-universal"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp "$BIN/mda" "$STAGE/"
cp -R "$BIN/macOSDefaultApps_DefaultAppsCore.bundle" "$STAGE/"

sign_opts=(--force --sign "$SIGN_IDENTITY")
if [ "$SIGN_IDENTITY" != "-" ]; then
	sign_opts+=(--options runtime --timestamp)
fi
codesign "${sign_opts[@]}" "$STAGE/mda"
codesign --verify --strict "$STAGE/mda"

# the staged dir stays: notarization runs on it, and since a bare executable
# cannot be stapled, notarizing does not change the bytes already tarred
tar -czf "$STAGE.tar.gz" -C build "mda-$VERSION-universal"
echo "built $STAGE.tar.gz (identity: $SIGN_IDENTITY)"
