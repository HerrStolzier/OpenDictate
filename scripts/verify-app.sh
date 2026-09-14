#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/.build/OpenDictate.app}"
ENTITLEMENTS="$(mktemp)"
trap 'rm -f "$ENTITLEMENTS"' EXIT

plutil -lint "$APP/Contents/Info.plist"
codesign --verify --deep --strict "$APP"
if ! codesign -d --verbose=4 "$APP" 2>&1 | grep 'flags=.*runtime' >/dev/null; then
  echo "Signed app is missing Hardened Runtime." >&2
  exit 1
fi
codesign -d --entitlements - --xml "$APP" > "$ENTITLEMENTS"
if [[ "$(plutil -extract 'com\.apple\.security\.device\.audio-input' raw -expect bool "$ENTITLEMENTS" 2>/dev/null)" != "true" ]]; then
  echo "Signed app is missing the required audio-input entitlement." >&2
  exit 1
fi
echo "Verified signature, Hardened Runtime and microphone entitlement."
