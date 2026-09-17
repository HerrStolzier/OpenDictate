#!/usr/bin/env bash
set -euo pipefail

# Exercise the real verifier on disposable copies. Never launch the app, use a
# signing identity, or change the source bundle, Keychain, or TCC permissions.
export LC_ALL=C
umask 077

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERIFIER="$PROJECT_ROOT/scripts/verify-app.sh"
AUDIO_KEY='com\.apple\.security\.device\.audio-input'

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ $# -le 1 ]] || fail "Usage: $0 [OpenDictate.app]"
[[ "$(uname -s)" == "Darwin" ]] || fail "Bundle verification regressions require macOS."
BUNDLE_SOURCE="${1:-$PROJECT_ROOT/.build/OpenDictate.app}"
[[ -d "$BUNDLE_SOURCE" ]] || fail "Build the app before running bundle regressions."
BUNDLE_SOURCE="$(cd "$BUNDLE_SOURCE" && pwd -P)"
[[ -f "$BUNDLE_SOURCE/Contents/Info.plist" ]] || fail "Source bundle has no Info.plist."

# The current SwiftPM bundle has no symlinks. Refuse linked content so fixture
# signing and tampering cannot follow a link back into the source or elsewhere.
[[ -z "$(find "$BUNDLE_SOURCE" -type l -print -quit)" ]] || fail "Source bundle contains symlinks."

BUNDLE_TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/opendictate-verify-tests.XXXXXX")"
readonly BUNDLE_SOURCE BUNDLE_TEST_DIR

source_manifest() {
  (
    cd "$BUNDLE_SOURCE"
    find . -type f -exec shasum -a 256 {} + | sort
    find . -exec stat -f '%N|%Sp' {} + | sort
  )
}

cleanup() {
  local exit_status=$?
  trap - EXIT
  if [[ -f "$BUNDLE_TEST_DIR/source-before.txt" ]]; then
    if ! source_manifest > "$BUNDLE_TEST_DIR/source-after.txt"; then
      printf 'FAIL: could not verify that the source bundle is unchanged.\n' >&2
      exit_status=1
    elif ! cmp -s "$BUNDLE_TEST_DIR/source-before.txt" "$BUNDLE_TEST_DIR/source-after.txt"; then
      printf 'FAIL: source bundle content or permissions changed.\n' >&2
      exit_status=1
    fi
  fi
  rm -rf "$BUNDLE_TEST_DIR"
  if [[ "$exit_status" -eq 0 ]]; then
    printf 'PASS: source bundle content and permissions unchanged.\n'
    printf 'Bundle verifier regressions passed (1 accepted, 6 rejected).\n'
  fi
  exit "$exit_status"
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

source_manifest > "$BUNDLE_TEST_DIR/source-before.txt"

write_entitlements() {
  local destination="$1"
  local value
  case "$2" in
    true) value='<true/>' ;;
    false) value='<false/>' ;;
    string) value='<string>true</string>' ;;
    missing) value='' ;;
    *) fail "Unknown entitlement fixture: $2" ;;
  esac
  cat > "$destination" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
PLIST
  if [[ -n "$value" ]]; then
    printf '  <key>com.apple.security.device.audio-input</key>\n  %s\n' "$value" >> "$destination"
  fi
  printf '</dict>\n</plist>\n' >> "$destination"
  plutil -lint "$destination" >/dev/null
}

make_fixture() {
  local fixture="$1"
  local name="${fixture##*/}"
  local entitlements="$BUNDLE_TEST_DIR/$name.input.plist"
  ditto "$BUNDLE_SOURCE" "$fixture"
  mkdir -p "$fixture/Contents/Resources"
  printf 'Sealed verifier regression fixture.\n' > "$fixture/Contents/Resources/verifier-probe.txt"
  write_entitlements "$entitlements" "$2"
  # Explicitly remove the previous signature so neither flags nor entitlements
  # can survive re-signing through metadata preservation defaults.
  codesign --remove-signature "$fixture"
  codesign --force --sign - --timestamp=none --options "$3" --entitlements "$entitlements" "$fixture"
  plutil -lint "$fixture/Contents/Info.plist" >/dev/null
  codesign -d --verbose=4 "$fixture" > "$BUNDLE_TEST_DIR/$name.signing.txt" 2>&1
  grep -Fx 'Signature=adhoc' "$BUNDLE_TEST_DIR/$name.signing.txt" >/dev/null \
    || fail "$name is not ad-hoc signed."
}

assert_runtime() {
  local fixture="$1"
  local details="$BUNDLE_TEST_DIR/${fixture##*/}.signing.txt"
  codesign -d --verbose=4 "$fixture" > "$details" 2>&1
  if grep -E '^CodeDirectory .*flags=.*[,(]runtime[,)]' "$details" >/dev/null; then
    [[ "$2" == "present" ]] || fail "${fixture##*/} unexpectedly retains Hardened Runtime."
  else
    [[ "$2" == "absent" ]] || fail "${fixture##*/} unexpectedly lacks Hardened Runtime."
  fi
}

assert_entitlement() {
  local fixture="$1"
  local signed_plist="$BUNDLE_TEST_DIR/${fixture##*/}.signed.plist"
  codesign -d --entitlements - --xml "$fixture" > "$signed_plist"
  if [[ "$2" == "missing" ]]; then
    if [[ -s "$signed_plist" ]]; then
      plutil -lint "$signed_plist" >/dev/null
      if plutil -extract "$AUDIO_KEY" xml1 -o - "$signed_plist" >/dev/null 2>&1; then
        fail "${fixture##*/} unexpectedly has an audio-input entitlement."
      fi
    fi
    return
  fi
  plutil -lint "$signed_plist" >/dev/null
  [[ "$(plutil -extract "$AUDIO_KEY" raw -expect "$2" "$signed_plist")" == "$3" ]] \
    || fail "${fixture##*/} does not have the intended signed entitlement type/value."
}

assert_valid_signature() {
  codesign --verify --deep --strict "$1" \
    || fail "${1##*/} must have a valid signature before testing its isolated policy failure."
}

expect_rejection() {
  local fixture="$1"
  local output="$BUNDLE_TEST_DIR/${fixture##*/}.verification.txt"
  if TMPDIR="$BUNDLE_TEST_DIR" "$VERIFIER" "$fixture" > "$output" 2>&1; then
    cat "$output" >&2
    fail "Verifier accepted ${fixture##*/}."
  fi
  if ! grep -F "$2" "$output" >/dev/null; then
    cat "$output" >&2
    fail "${fixture##*/} was rejected for an unexpected reason; expected: $2"
  fi
  printf 'PASS: %s rejected for the intended reason.\n' "${fixture##*/}"
}

VALID="$BUNDLE_TEST_DIR/valid.app"
make_fixture "$VALID" true runtime
assert_valid_signature "$VALID"
assert_runtime "$VALID" present
assert_entitlement "$VALID" bool true
TMPDIR="$BUNDLE_TEST_DIR" "$VERIFIER" "$VALID"
printf 'PASS: valid ad-hoc bundle accepted.\n'

for entitlement in missing false string; do
  fixture="$BUNDLE_TEST_DIR/audio-$entitlement.app"
  make_fixture "$fixture" "$entitlement" runtime
  assert_valid_signature "$fixture"
  assert_runtime "$fixture" present
  case "$entitlement" in
    missing) assert_entitlement "$fixture" missing ;;
    false) assert_entitlement "$fixture" bool false ;;
    string) assert_entitlement "$fixture" string true ;;
  esac
  expect_rejection "$fixture" 'Signed app is missing the required audio-input entitlement.'
done

NO_RUNTIME="$BUNDLE_TEST_DIR/no-runtime.app"
make_fixture "$NO_RUNTIME" true 0
assert_valid_signature "$NO_RUNTIME"
assert_runtime "$NO_RUNTIME" absent
assert_entitlement "$NO_RUNTIME" bool true
expect_rejection "$NO_RUNTIME" 'Signed app is missing Hardened Runtime.'

CORRUPT="$BUNDLE_TEST_DIR/corrupted-signature.app"
make_fixture "$CORRUPT" true runtime
assert_valid_signature "$CORRUPT"
assert_runtime "$CORRUPT" present
assert_entitlement "$CORRUPT" bool true
# Only modify a resource created inside this fixture before signing. This
# breaks the resource seal without introducing an unrelated Mach-O/Plist error.
printf 'Modified after signing.\n' >> "$CORRUPT/Contents/Resources/verifier-probe.txt"
if codesign --verify --deep --strict "$CORRUPT" > "$BUNDLE_TEST_DIR/corrupt-signature.txt" 2>&1; then
  fail "Tampering did not invalidate the fixture's signature."
fi
grep -F 'a sealed resource is missing or invalid' "$BUNDLE_TEST_DIR/corrupt-signature.txt" >/dev/null \
  || fail "Tampered fixture has an unexpected signature failure."
expect_rejection "$CORRUPT" 'a sealed resource is missing or invalid'

UNSIGNED="$BUNDLE_TEST_DIR/unsigned.app"
make_fixture "$UNSIGNED" true runtime
assert_valid_signature "$UNSIGNED"
codesign --remove-signature "$UNSIGNED"
if codesign -d "$UNSIGNED" > "$BUNDLE_TEST_DIR/unsigned-display.txt" 2>&1; then
  fail "Removing the signature left the fixture signed."
fi
grep -F 'code object is not signed at all' "$BUNDLE_TEST_DIR/unsigned-display.txt" >/dev/null \
  || fail "Unsigned fixture has an unexpected inspection failure."
expect_rejection "$UNSIGNED" 'code object is not signed at all'
