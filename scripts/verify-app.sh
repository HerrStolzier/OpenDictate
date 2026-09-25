#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
MODE="development"
EXPECTED_TEAM_ID=""
APP=""

usage() {
  echo "Usage: $0 [--release --team-id TEAM_ID] [OpenDictate.app]" >&2
  exit 2
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --release)
      MODE="release"
      shift
      ;;
    --team-id)
      [[ "$#" -ge 2 ]] || usage
      EXPECTED_TEAM_ID="$2"
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    -*)
      usage
      ;;
    *)
      [[ -z "$APP" ]] || usage
      APP="$1"
      shift
      ;;
  esac
done

APP="${APP:-$ROOT/.build/OpenDictate.app}"
HELPER="$APP/Contents/Helpers/OpenDictateKeychainHelper"
VERIFY_TEMP="$(mktemp -d)"
ENTITLEMENTS="$VERIFY_TEMP/entitlements.plist"
trap 'rm -rf "$VERIFY_TEMP"' EXIT

if [[ "$MODE" == "release" ]]; then
  [[ "$EXPECTED_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || {
    echo "Release verification requires --team-id with a 10-character Developer ID team." >&2
    exit 2
  }
elif [[ -n "$EXPECTED_TEAM_ID" ]]; then
  echo "--team-id can only be used with --release." >&2
  exit 2
fi

plutil -lint "$APP/Contents/Info.plist"
if [[ ! -f "$HELPER" ]]; then
  echo "Signed app is missing its Keychain helper." >&2
  exit 1
fi
codesign --verify --deep --strict "$APP"
codesign --verify --strict "$HELPER"
HELPER_DETAILS="$(codesign -d --verbose=4 "$HELPER" 2>&1)"
if ! printf '%s\n' "$HELPER_DETAILS" | grep -Fx 'Identifier=OpenDictateKeychainHelper' >/dev/null; then
  echo "Signed app has an unexpected Keychain helper identity." >&2
  exit 1
fi

APP_DETAILS="$(codesign -d --verbose=4 "$APP" 2>&1)"
if ! printf '%s\n' "$APP_DETAILS" | grep 'flags=.*runtime' >/dev/null; then
  echo "Signed app is missing Hardened Runtime." >&2
  exit 1
fi

field_value() {
  local details="$1"
  local field="$2"
  printf '%s\n' "$details" | awk -v field="$field" '
    index($0, field "=") == 1 {
      print substr($0, length(field) + 2)
      exit
    }'
}

if [[ "$MODE" == "release" ]]; then
  APP_TEAM="$(field_value "$APP_DETAILS" TeamIdentifier)"
  HELPER_TEAM="$(field_value "$HELPER_DETAILS" TeamIdentifier)"
  APP_TIMESTAMP="$(field_value "$APP_DETAILS" Timestamp)"
  HELPER_TIMESTAMP="$(field_value "$HELPER_DETAILS" Timestamp)"

  for details in "$APP_DETAILS" "$HELPER_DETAILS"; do
    if printf '%s\n' "$details" | grep -Fx 'Signature=adhoc' >/dev/null; then
      echo "Release verification rejects ad-hoc signatures." >&2
      exit 1
    fi
    if ! printf '%s\n' "$details" | grep 'flags=.*runtime' >/dev/null; then
      echo "Signed app and Keychain helper must both use Hardened Runtime." >&2
      exit 1
    fi
  done

  [[ "$APP_TEAM" == "$EXPECTED_TEAM_ID" && "$HELPER_TEAM" == "$EXPECTED_TEAM_ID" ]] || {
    echo "App and Keychain helper must be signed by the requested Developer ID team." >&2
    exit 1
  }
  DEVELOPER_ID_REQUIREMENT="anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = $EXPECTED_TEAM_ID"
  if ! codesign --verify --strict --test-requirement "$DEVELOPER_ID_REQUIREMENT" "$APP" >/dev/null 2>&1 || \
    ! codesign --verify --strict --test-requirement "$DEVELOPER_ID_REQUIREMENT" "$HELPER" >/dev/null 2>&1; then
    echo "App and Keychain helper must satisfy Apple's Developer ID Application certificate requirement." >&2
    exit 1
  fi
  APP_CERT_PREFIX="$VERIFY_TEMP/app-cert-"
  HELPER_CERT_PREFIX="$VERIFY_TEMP/helper-cert-"
  codesign --display --extract-certificates "$APP_CERT_PREFIX" "$APP" >/dev/null 2>&1
  codesign --display --extract-certificates "$HELPER_CERT_PREFIX" "$HELPER" >/dev/null 2>&1
  [[ -s "${APP_CERT_PREFIX}0" && -s "${HELPER_CERT_PREFIX}0" ]] || {
    echo "Could not extract the app and Keychain helper signing certificates." >&2
    exit 1
  }
  if ! cmp -s "${APP_CERT_PREFIX}0" "${HELPER_CERT_PREFIX}0"; then
    echo "App and Keychain helper use different Developer ID certificates." >&2
    exit 1
  fi
  [[ -n "$APP_TIMESTAMP" && "$APP_TIMESTAMP" != "none" && -n "$HELPER_TIMESTAMP" && "$HELPER_TIMESTAMP" != "none" ]] || {
    echo "App and Keychain helper must have secure signing timestamps." >&2
    exit 1
  }

  APP_ARCHITECTURES="$(lipo -archs "$APP/Contents/MacOS/OpenDictate")"
  HELPER_ARCHITECTURES="$(lipo -archs "$HELPER")"
  [[ "$APP_ARCHITECTURES" == "arm64" && "$HELPER_ARCHITECTURES" == "arm64" ]] || {
    echo "Release app and Keychain helper must contain only arm64." >&2
    exit 1
  }
fi

codesign -d --entitlements - --xml "$APP" > "$ENTITLEMENTS"
if [[ "$(plutil -extract 'com\.apple\.security\.device\.audio-input' raw -expect bool "$ENTITLEMENTS" 2>/dev/null)" != "true" ]]; then
  echo "Signed app is missing the required audio-input entitlement." >&2
  exit 1
fi

if [[ "$MODE" == "release" ]]; then
  echo "Verified Developer ID team, matching app/helper signatures, timestamps, arm64, Hardened Runtime and microphone entitlement."
else
  echo "Verified signature, Keychain helper, Hardened Runtime and microphone entitlement."
fi
