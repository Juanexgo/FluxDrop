#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${FLUXDROP_TEST_SOURCE:-/private/tmp/fluxdrop-test-source}"
ENGINE="${FLUXDROP_ENGINE_SOURCE:-$ROOT/build/engines}"
mkdir -p "$SOURCE" /private/tmp/fluxdrop-test-engines
rsync -a --delete --exclude .build "$ROOT/apps/macos/" "$SOURCE/"
rsync -a "$ENGINE/ffmpeg" "$ENGINE/ffprobe" /private/tmp/fluxdrop-test-engines/
FLUXDROP_TEST_TOOLS=/private/tmp/fluxdrop-test-engines swift test -c "${CONFIGURATION:-debug}" --package-path "$SOURCE" --scratch-path "${FLUXDROP_TEST_SCRATCH:-/private/tmp/fluxdrop-test-build}"
