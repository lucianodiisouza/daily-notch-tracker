#!/usr/bin/env bash
#
# Build DailyNotch (Debug) and launch it.
# Usage: ./scripts/run.sh [release]
#
set -euo pipefail

CONFIG="Debug"
[[ "${1:-}" == "release" ]] && CONFIG="Release"

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="${PROJECT_DIR}/DailyNotch.xcodeproj"
SCHEME="DailyNotch"

echo "-> Building DailyNotch (${CONFIG})..."
xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIG}" \
  -destination 'platform=macOS' \
  build

# Ask xcodebuild where it put the product instead of guessing the DerivedData path.
BUILD_DIR="$(xcodebuild -project "${PROJECT}" -scheme "${SCHEME}" -configuration "${CONFIG}" \
  -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR =/{print $2; exit}')"
APP="${BUILD_DIR}/DailyNotch.app"

if [[ ! -d "${APP}" ]]; then
  echo "ERROR: Could not find built app at: ${APP}" >&2
  exit 1
fi

echo "-> Relaunching..."
pkill -x DailyNotch 2>/dev/null || true
sleep 0.5
open "${APP}"
echo "OK: Running ${APP}"
echo "   (menu-bar hourglass to open Tasks; hover the notch to expand)"
