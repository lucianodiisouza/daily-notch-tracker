#!/usr/bin/env bash
#
# Completely remove DailyNotch from this Mac: the running process, built
# products, saved data, preferences, and any installed copy. Source code in
# this repo is NOT touched.
#
# Usage: ./scripts/wipe.sh [-y]   (-y skips the confirmation prompt)
#
set -euo pipefail

BUNDLE_ID="com.dailynotch.app"
APP_NAME="DailyNotch"

if [[ "${1:-}" != "-y" ]]; then
  read -r -p "This will delete $APP_NAME's app, data, and preferences. Continue? [y/N] " ans
  [[ "$ans" == "y" || "$ans" == "Y" ]] || { echo "Aborted."; exit 0; }
fi

echo "→ Quitting $APP_NAME…"
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 0.5

echo "→ Removing built products from DerivedData…"
find "$HOME/Library/Developer/Xcode/DerivedData" -maxdepth 1 -type d \
  -name "${APP_NAME}-*" -exec rm -rf {} + 2>/dev/null || true

echo "→ Removing installed copies…"
rm -rf "/Applications/${APP_NAME}.app" 2>/dev/null || true
rm -rf "$HOME/Applications/${APP_NAME}.app" 2>/dev/null || true

echo "→ Removing saved data (Application Support)…"
rm -rf "$HOME/Library/Application Support/${APP_NAME}" 2>/dev/null || true

echo "→ Removing preferences / UserDefaults…"
defaults delete "$BUNDLE_ID" 2>/dev/null || true
rm -f "$HOME/Library/Preferences/${BUNDLE_ID}.plist" 2>/dev/null || true

echo "→ Removing caches & saved application state…"
rm -rf "$HOME/Library/Caches/${BUNDLE_ID}" 2>/dev/null || true
rm -rf "$HOME/Library/Saved Application State/${BUNDLE_ID}.savedState" 2>/dev/null || true

echo "→ Unregistering from Launch Services…"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
[[ -x "$LSREGISTER" ]] && "$LSREGISTER" -kill -r -domain local -domain user 2>/dev/null || true

echo "✓ $APP_NAME wiped from this Mac."
