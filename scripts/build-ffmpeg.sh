#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${FLUXDROP_ENGINE_WORK:-/private/tmp/fluxdrop-engines}"
VERSION=9.0.2
mkdir -p "$WORK" "$ROOT/build/engines"
SOURCE="$WORK/ffmpeg-$VERSION.tar.xz"
if [ ! -f "$SOURCE" ]; then curl -fL --proto '=https' "https://ffmpeg.org/releases/ffmpeg-$VERSION.tar.xz" -o "$SOURCE"; fi
printf '%s  %s\n' '8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e' "$SOURCE" | shasum -a 256 -c -
tar -xf "$SOURCE" -C "$WORK"
cd "$WORK/ffmpeg-$VERSION"
./configure --prefix="$WORK/install" --disable-autodetect --disable-gpl --disable-nonfree --disable-network --disable-doc --disable-debug --disable-ffplay --enable-videotoolbox --enable-audiotoolbox --enable-zlib --extra-cflags='-mmacosx-version-min=14.0' --extra-ldflags='-mmacosx-version-min=14.0' > "$WORK/configure.log" 2>&1
make -j4 > "$WORK/build.log" 2>&1
make install > "$WORK/install.log" 2>&1
cp "$WORK/install/bin/ffmpeg" "$WORK/install/bin/ffprobe" "$ROOT/build/engines/"
cp COPYING.LGPLv2.1 LICENSE.md "$SOURCE" "$ROOT/build/engines/"
"$WORK/install/bin/ffmpeg" -version > "$ROOT/build/engines/version.txt"
"$WORK/install/bin/ffmpeg" -buildconf > "$ROOT/build/engines/buildconf.txt" 2>&1
"$WORK/install/bin/ffmpeg" -L > "$ROOT/build/engines/license.txt" 2>&1
