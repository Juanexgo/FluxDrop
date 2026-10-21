#!/usr/bin/env bash
# Build LGPL-only Windows x64 engines on Ubuntu with the distro MinGW toolchain.
set -euo pipefail
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TASK_WORK="${FLUXDROP_WINDOWS_ENGINE_WORK:-$ROOT/build/windows-engines-work}"
TASK_OUT="${FLUXDROP_WINDOWS_ENGINE_OUTPUT:-$ROOT/build/windows-engines}"
mkdir -p "$TASK_WORK" "$TASK_OUT/sources"
cd "$TASK_WORK"
fetch() { curl -fL --retry 3 --proto '=https' "$2" -o "$1"; printf '%s  %s\n' "$3" "$1" | sha256sum -c -; tar -xf "$1"; }
fetch ffmpeg-9.0.2.tar.xz https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz 8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e
fetch lame-4.0.tar.gz https://downloads.sourceforge.net/project/lame/lame/4.0/lame-4.0.tar.gz 3df5124d5ad3a98312ffd7ba6a9b36230e4f8a3e66d3ce0f425e336c32d216eb
fetch opus-1.6.1.tar.gz https://downloads.xiph.org/releases/opus/opus-1.6.1.tar.gz 6ffcb593207be92584df15b32466ed64bbec99109f007c82205f0194572411a1
PREFIX="$TASK_WORK/install"
(cd lame-4.0 && ./configure --host=x86_64-w64-mingw32 --prefix="$PREFIX" --disable-shared --enable-static --disable-frontend --disable-decoder && make -j4 && make install)
(cd opus-1.6.1 && ./configure --host=x86_64-w64-mingw32 --prefix="$PREFIX" --disable-shared --enable-static --disable-doc --disable-extra-programs --disable-rtcd && make -j4 && make install)
fetch libwebp-1.6.0.tar.gz https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.6.0.tar.gz e4ab7009bf0629fd11982d4c2aa83964cf244cffba7347ecd39019a9e38c4564
WEBP="$TASK_WORK/libwebp-1.6.0"
cmake -S "$WEBP" -B webp-build -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF -DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_WEBPMUX=OFF -DWEBP_BUILD_EXTRAS=OFF
cmake --build webp-build -j4
cmake --install webp-build
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig" PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
cd ffmpeg-9.0.2
./configure --target-os=mingw32 --arch=x86_64 --cross-prefix=x86_64-w64-mingw32- --enable-cross-compile --disable-autodetect --disable-gpl --disable-nonfree --disable-network --disable-doc --disable-debug --disable-ffplay --disable-x86asm --enable-libmp3lame --enable-libopus --enable-libwebp --pkg-config=pkg-config --pkg-config-flags=--static --extra-cflags="-I$PREFIX/include" --extra-ldflags="-static -L$PREFIX/lib" --extra-libs='-lstdc++ -lwinpthread'
make -j4
cp ffmpeg.exe ffprobe.exe "$TASK_OUT/"
cp COPYING.LGPLv2.1 LICENSE.md "$TASK_OUT/"
cp ffbuild/config.mak "$TASK_OUT/buildconf.txt"
cp "$TASK_WORK/"*.tar.* "$TASK_OUT/sources/"
cp "$TASK_WORK/lame-4.0/COPYING" "$TASK_OUT/LAME-COPYING.txt"
cp "$TASK_WORK/lame-4.0/LICENSE" "$TASK_OUT/LAME-LICENSE.txt"
cp "$TASK_WORK/opus-1.6.1/COPYING" "$TASK_OUT/Opus-COPYING.txt"
cp "$WEBP/COPYING" "$TASK_OUT/WebP-COPYING.txt"
tar -czf "$TASK_OUT/sources/libwebp-vendored.tar.gz" -C "$WEBP" .
cp "$SCRIPT_PATH" "$TASK_OUT/sources/"
