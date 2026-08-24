#!/bin/bash
# Assembles build/macOSDefaultApps.app from the swiftpm release build.
# Usage: scripts/package-app.sh [version]   (default 0.1.0)
# Signing is ad-hoc; proper signing/notarization comes with release CI.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-0.1.0}"
ARCHS=(--arch arm64 --arch x86_64)

swift build -c release "${ARCHS[@]}" --product macOSDefaultApps
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)"

APP="build/macOSDefaultApps.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN/macOSDefaultApps" "$APP/Contents/MacOS/"
# every swiftpm resource bundle (core catalog, app localizations, …)
cp -R "$BIN"/*.bundle "$APP/Contents/Resources/"
cp assets/AppIcon.icns "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>macOSDefaultApps</string>
	<key>CFBundleIdentifier</key><string>dev.klabast.macOSDefaultApps</string>
	<key>CFBundleName</key><string>macOSDefaultApps</string>
	<key>CFBundleDisplayName</key><string>Default Apps</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>${VERSION}</string>
	<key>CFBundleVersion</key><string>${VERSION}</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>LSMinimumSystemVersion</key><string>15.0</string>
	<key>NSHighResolutionCapable</key><true/>
	<key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
</dict>
</plist>
PLIST

codesign --force -s - "$APP"
echo "built $APP"
