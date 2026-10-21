#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${FLUXDROP_APP_OUTPUT:-/private/tmp/fluxdrop-package/FluxDrop.app}"
OUT="${FLUXDROP_RELEASE_OUTPUT:-$ROOT/build/releases}"
[ -d "$APP" ] || { echo 'Run build-macos.sh first' >&2; exit 1; }
mkdir -p "$OUT"
STAGE="$(mktemp -d /private/tmp/fluxdrop-dmg.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT
ditto --norsrc --noextattr "$APP" "$STAGE/FluxDrop.app"
ln -s /Applications "$STAGE/Applications"
printf '%s\n' 'FluxDrop — drag FluxDrop.app to Applications.' 'Development build unless accompanied by a verified notarization report.' > "$STAGE/Read me.txt"
codesign --verify --deep --strict "$STAGE/FluxDrop.app"
DMG="$OUT/FluxDrop-0.2.0-arm64.dmg"
hdiutil create -ov -volname FluxDrop -srcfolder "$STAGE" -format UDZO "$DMG"
hdiutil verify "$DMG"
shasum -a 256 "$DMG" > "$DMG.sha256"
echo "$DMG"
