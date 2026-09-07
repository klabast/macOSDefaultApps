#!/bin/bash
# Submits a signed build/macOSDefaultApps.app to the notary service and staples it.
# Credentials, either:
#   NOTARY_PROFILE=<name>                         (local, via notarytool store-credentials)
#   ASC_KEY_ID + ASC_ISSUER_ID + ASC_KEY_PATH     (ci, App Store Connect api key)
set -euo pipefail
cd "$(dirname "$0")/.."

APP="${1:-build/macOSDefaultApps.app}"
ZIP="build/notarize.zip"

if [ -n "${NOTARY_PROFILE:-}" ]; then
	creds=(--keychain-profile "$NOTARY_PROFILE")
elif [ -n "${ASC_KEY_ID:-}" ]; then
	creds=(--key "$ASC_KEY_PATH" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID")
else
	echo "no notary credentials: set NOTARY_PROFILE or ASC_KEY_ID/ASC_ISSUER_ID/ASC_KEY_PATH" >&2
	exit 1
fi

codesign --verify --strict "$APP"

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

xcrun notarytool submit "$ZIP" "${creds[@]}" --wait
xcrun stapler staple "$APP"
rm -f "$ZIP"

# what gatekeeper will say on a freshly downloaded copy
spctl --assess --type execute --verbose=4 "$APP"
echo "notarized + stapled $APP"
