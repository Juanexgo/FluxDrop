#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${FLUXDROP_ENGINE_WORK:-/private/tmp/fluxdrop-engines}"
VERSION=9.0.2
ENGINE_OUT="${FLUXDROP_ENGINE_OUTPUT:-$ROOT/build/engines}"
CODECS="${FLUXDROP_CODEC_WORK:-/private/tmp/fluxdrop-codecs}"
mkdir -p "$WORK" "$ENGINE_OUT" "$CODECS"
command -v pkg-config >/dev/null || { echo 'Build dependency: install pkg-config (not required by the installed app).' >&2; exit 1; }
fetch_source() {
  if [ ! -f "$CODECS/$1" ]; then curl -fL --proto '=https' "$2" -o "$CODECS/$1"; fi
  printf '%s  %s\n' "$3" "$CODECS/$1" | shasum -a 256 -c -
  tar -xf "$CODECS/$1" -C "$CODECS"
}
fetch_source lame-4.0.tar.gz https://downloads.sourceforge.net/project/lame/lame/4.0/lame-4.0.tar.gz 3df5124d5ad3a98312ffd7ba6a9b36230e4f8a3e66d3ce0f425e336c32d216eb
fetch_source opus-1.6.1.tar.gz https://downloads.xiph.org/releases/opus/opus-1.6.1.tar.gz 6ffcb593207be92584df15b32466ed64bbec99109f007c82205f0194572411a1
(cd "$CODECS/lame-4.0" && CFLAGS='-O2 -mmacosx-version-min=14.0' ./configure --prefix="$CODECS/install" --disable-shared --enable-static --disable-frontend --disable-decoder > "$CODECS/lame-configure.log" 2>&1 && make -j4 > "$CODECS/lame-build.log" 2>&1 && make install > "$CODECS/lame-install.log" 2>&1)
(cd "$CODECS/opus-1.6.1" && CFLAGS='-O2 -mmacosx-version-min=14.0' ./configure --prefix="$CODECS/install" --disable-shared --enable-static --disable-doc --disable-extra-programs > "$CODECS/opus-configure.log" 2>&1 && make -j4 > "$CODECS/opus-build.log" 2>&1 && make install > "$CODECS/opus-install.log" 2>&1)
export PKG_CONFIG_PATH="$CODECS/install/lib/pkgconfig"
SOURCE="$WORK/ffmpeg-$VERSION.tar.xz"
if [ ! -f "$SOURCE" ]; then curl -fL --proto '=https' "https://ffmpeg.org/releases/ffmpeg-$VERSION.tar.xz" -o "$SOURCE"; fi
printf '%s  %s\n' '8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e' "$SOURCE" | shasum -a 256 -c -
tar -xf "$SOURCE" -C "$WORK"
cd "$WORK/ffmpeg-$VERSION"
./configure --prefix="$WORK/install" --disable-autodetect --disable-gpl --disable-nonfree --disable-network --disable-doc --disable-debug --disable-ffplay --enable-videotoolbox --enable-audiotoolbox --enable-zlib --enable-libmp3lame --enable-libopus --pkg-config-flags=--static --extra-cflags="-mmacosx-version-min=14.0 -I$CODECS/install/include" --extra-ldflags="-mmacosx-version-min=14.0 -L$CODECS/install/lib" > "$WORK/configure.log" 2>&1
make -j4 > "$WORK/build.log" 2>&1
for tool in ffmpeg ffprobe; do
  cp -c "$tool" "$ENGINE_OUT/.$tool.$$"
  mv -f "$ENGINE_OUT/.$tool.$$" "$ENGINE_OUT/$tool"
done
cp COPYING.LGPLv2.1 LICENSE.md "$SOURCE" "$ENGINE_OUT/"
"$ENGINE_OUT/ffmpeg" -version > "$ENGINE_OUT/version.txt"
"$ENGINE_OUT/ffmpeg" -buildconf > "$ENGINE_OUT/buildconf.txt" 2>&1
"$ENGINE_OUT/ffmpeg" -L > "$ENGINE_OUT/license.txt" 2>&1

cp "$CODECS/"*.tar.gz "$ENGINE_OUT/"
cp "$CODECS/lame-4.0/COPYING" "$ENGINE_OUT/LAME-COPYING.txt"
cp "$CODECS/lame-4.0/LICENSE" "$ENGINE_OUT/LAME-LICENSE.txt"
cp "$CODECS/opus-1.6.1/COPYING" "$ENGINE_OUT/Opus-COPYING.txt"
printf '%s\n' 'LAME 4.0 static library only, frontend and decoder disabled; LGPL 2 or later.' 'Opus 1.6.1 static, docs and extra programs disabled; upstream BSD and patent notices in Opus-COPYING.txt.' 'Source archives and build script included; no source modifications.' > "$ENGINE_OUT/audio-codecs.txt"
otool -L "$ENGINE_OUT/ffmpeg" "$ENGINE_OUT/ffprobe" > "$ENGINE_OUT/linkage.txt"
# Release temporary compiler objects; sources and pinned archives remain available.
make clean > "$WORK/clean.log" 2>&1
