#!/usr/bin/env bash
set -euo pipefail
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TASK_WORK="${FLUXDROP_WINDOWS_OCR_WORK:-$TASK_ROOT/build/windows-ocr-work}"
TASK_OUT="${FLUXDROP_WINDOWS_OCR_OUTPUT:-$TASK_ROOT/build/windows-ocr}"
mkdir -p "$TASK_WORK" "$TASK_OUT/sources" "$TASK_OUT/tessdata"
cd "$TASK_WORK"
fetch() { curl -fL --retry 3 --proto '=https' "$2" -o "$1"; printf '%s  %s\n' "$3" "$1" | sha256sum -c -; tar -xf "$1"; }
fetch tesseract-5.5.3.tar.gz https://codeload.github.com/tesseract-ocr/tesseract/tar.gz/refs/tags/5.5.3 9218e62793116d42a9f6d14cd9348518b27f382096eea3d0f2d1a24616bb5884
fetch leptonica-1.87.0.tar.gz https://codeload.github.com/DanBloomberg/leptonica/tar.gz/refs/tags/1.87.0 fa2b40c5caea96d1bb93a97486262aed8731b69ce25a84a6bf5d25323e33f631
# Upstream uses MSVC casing; MinGW import libraries on Linux are case-sensitive.
sed -i 's/Ws2_32/ws2_32/g' tesseract-5.5.3/CMakeLists.txt
PREFIX="$TASK_WORK/install"
CROSS=(-DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_PROCESSOR=x86_64 -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc-posix -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++-posix -DCMAKE_RC_COMPILER=x86_64-w64-mingw32-windres -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_EXE_LINKER_FLAGS=-static)
cmake -S leptonica-1.87.0 -B lep-build "${CROSS[@]}" -DBUILD_PROG=OFF -DSW_BUILD=OFF -DENABLE_GIF=OFF -DENABLE_ZLIB=OFF -DENABLE_LIBPNG=OFF -DENABLE_JPEG=OFF -DENABLE_TIFF=OFF -DENABLE_LIBWEBP=OFF -DENABLE_OPENJPEG=OFF -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build lep-build -j4
cmake --install lep-build
cmake -S tesseract-5.5.3 -B tess-build "${CROSS[@]}" -DCMAKE_PREFIX_PATH="$PREFIX" -DLEPT_TIFF_RESULT=1 -DDISABLED_LEGACY_ENGINE=ON -DBUILD_TRAINING_TOOLS=OFF -DBUILD_TESTS=OFF -DDISABLE_ARCHIVE=ON -DDISABLE_CURL=ON -DOPENMP_BUILD=OFF -DGRAPHICS_DISABLED=ON -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build tess-build -j4
cp tess-build/bin/tesseract.exe "$TASK_OUT/"
x86_64-w64-mingw32-strip "$TASK_OUT/tesseract.exe"
MODEL_COMMIT=87416418657359cb625c412a48b6e1d6d41c29bd
for model in eng spa; do curl -fL --retry 3 --proto '=https' "https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/$MODEL_COMMIT/$model.traineddata" -o "$TASK_OUT/tessdata/$model.traineddata"; done
curl -fL --proto '=https' "https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/$MODEL_COMMIT/LICENSE" -o "$TASK_OUT/tessdata/LICENSE"
cp tesseract-5.5.3/LICENSE "$TASK_OUT/Tesseract-LICENSE.txt"
cp leptonica-1.87.0/leptonica-license.txt "$TASK_OUT/Leptonica-LICENSE.txt"
cp "$TASK_WORK/"*.tar.gz "$TASK_OUT/sources/"
cp "$SCRIPT_PATH" "$TASK_OUT/sources/"
printf '%s\n' 'Tesseract 5.5.3 Apache-2.0; Leptonica 1.87.0 BSD; BMP input only, no network/archive.' "tessdata_fast eng/spa Apache-2.0, commit $MODEL_COMMIT" > "$TASK_OUT/ocr-build.txt"
x86_64-w64-mingw32-objdump -p "$TASK_OUT/tesseract.exe" | sed -n '/DLL Name:/p' > "$TASK_OUT/ocr-linkage.txt"
