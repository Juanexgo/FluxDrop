#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${FLUXDROP_BUILD_SOURCE:-/private/tmp/fluxdrop-build-source}"
SCRATCH="${FLUXDROP_SCRATCH:-/private/tmp/fluxdrop-swift-build}"
ENGINE="${FLUXDROP_ENGINE_SOURCE:-$ROOT/build/engines}"
APP="${FLUXDROP_APP_OUTPUT:-/private/tmp/fluxdrop-package/FluxDrop.app}"
export COPYFILE_DISABLE=1
mkdir -p "$SOURCE" "$APP/Contents/MacOS" "$APP/Contents/Resources"
rsync -a --delete --exclude .build "$ROOT/apps/macos/" "$SOURCE/"
swift build --package-path "$SOURCE" --scratch-path "$SCRATCH" -c "${CONFIGURATION:-release}"
BIN="$(swift build --package-path "$SOURCE" --scratch-path "$SCRATCH" -c "${CONFIGURATION:-release}" --show-bin-path)"
cp "$BIN/FluxDrop" "$APP/Contents/MacOS/FluxDrop"
ditto --norsrc --noextattr "$BIN/FluxDrop_FluxDrop.bundle" "$APP/Contents/Resources/FluxDrop_FluxDrop.bundle"
cp "$ROOT/assets/FluxDrop.icns" "$APP/Contents/Resources/FluxDrop.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>FluxDrop</string>
<key>CFBundleIdentifier</key><string>local.fluxdrop.app</string>
<key>CFBundleName</key><string>FluxDrop</string>
<key>CFBundleIconFile</key><string>FluxDrop.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>es</string></array>
<key>CFBundleDocumentTypes</key><array><dict><key>CFBundleTypeName</key><string>File</string><key>CFBundleTypeRole</key><string>Viewer</string><key>LSHandlerRank</key><string>Alternate</string><key>LSItemContentTypes</key><array><string>public.data</string></array></dict></array>
</dict></plist>
PLIST
if [ -x "$ENGINE/ffmpeg" ] && [ -x "$ENGINE/ffprobe" ]; then
  mkdir -p "$APP/Contents/Helpers" "$APP/Contents/Resources/ThirdParty"
  cp "$ENGINE/ffmpeg" "$ENGINE/ffprobe" "$APP/Contents/Helpers/"
  cp "$ENGINE/"*.txt "$ENGINE/"*.md "$ENGINE/COPYING.LGPLv2.1" "$ENGINE/"*.tar.xz "$APP/Contents/Resources/ThirdParty/"
else
  echo 'Missing bundled engines: run scripts/build-ffmpeg.sh first.' >&2; exit 1
fi
ditto --norsrc --noextattr "$ROOT/third-party" "$APP/Contents/Resources/ThirdParty/notices"
chmod -R u+w "$APP"
xattr -cr "$APP"
codesign --force --sign - "$APP/Contents/Helpers/ffmpeg"
codesign --force --sign - "$APP/Contents/Helpers/ffprobe"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
mkdir -p "$ROOT/build"
if [ "$APP" != "$ROOT/build/FluxDrop.app" ]; then ditto --norsrc --noextattr "$APP" "$ROOT/build/FluxDrop.app"; fi
echo "$APP"
