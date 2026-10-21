#!/bin/bash
set -euo pipefail
: "${DEVELOPER_ID:?Set the exact Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set the Keychain notarytool profile name}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${FLUXDROP_APP_OUTPUT:-/private/tmp/fluxdrop-package/FluxDrop.app}"
OUT="${FLUXDROP_RELEASE_OUTPUT:-$ROOT/build/releases}"
mkdir -p "$OUT"
for helper in ffmpeg ffprobe; do codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" "$APP/Contents/Helpers/$helper"; done
codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
ditto -c -k --keepParent --norsrc "$APP" "$OUT/FluxDrop-notary.zip"
xcrun notarytool submit "$OUT/FluxDrop-notary.zip" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > "$OUT/app-notary.json"
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["status"] == "Accepted"' "$OUT/app-notary.json"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"
"$ROOT/scripts/package-dmg.sh"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
DMG="$OUT/FluxDrop-$VERSION-arm64.dmg"
codesign --force --timestamp --sign "$DEVELOPER_ID" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > "$OUT/dmg-notary.json"
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["status"] == "Accepted"' "$OUT/dmg-notary.json"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
shasum -a 256 "$DMG" > "$DMG.sha256"
python3 - "$DMG" "$OUT/dmg-notary.json" "$OUT/notarization-proof.json" <<'PY'
import sys,json,hashlib
with open(sys.argv[1],'rb') as f: digest=hashlib.file_digest(f,'sha256').hexdigest()
report=json.load(open(sys.argv[2])); report['sha256']=digest
json.dump(report,open(sys.argv[3],'w'),indent=2)
PY
