#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/.build/OpenDictate.app}"
HELPER="$APP/Contents/Helpers/OpenDictateKeychainHelper"
ENTITLEMENTS="$(mktemp)"
trap 'rm -f "$ENTITLEMENTS"' EXIT

plutil -lint "$APP/Contents/Info.plist"
if [[ ! -f "$HELPER" ]]; then
  echo "Signed app is missing its Keychain helper." >&2
  exit 1
fi
codesign --verify --deep --strict "$APP"
codesign --verify --strict "$HELPER"
if ! codesign -d --verbose=4 "$HELPER" 2>&1 | grep -Fx 'Identifier=OpenDictateKeychainHelper' >/dev/null; then
  echo "Signed app has an unexpected Keychain helper identity." >&2
  exit 1
fi
if ! codesign -d --verbose=4 "$APP" 2>&1 | grep 'flags=.*runtime' >/dev/null; then
  echo "Signed app is missing Hardened Runtime." >&2
  exit 1
fi
codesign -d --entitlements - --xml "$APP" > "$ENTITLEMENTS"
if [[ "$(plutil -extract 'com\.apple\.security\.device\.audio-input' raw -expect bool "$ENTITLEMENTS" 2>/dev/null)" != "true" ]]; then
  echo "Signed app is missing the required audio-input entitlement." >&2
  exit 1
fi
echo "Verified signature, Keychain helper, Hardened Runtime and microphone entitlement."
