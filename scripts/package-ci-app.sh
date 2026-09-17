#!/usr/bin/env bash
# Package one verified ad-hoc development bundle; never install or launch it.
set -euo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
APP="${1:-$ROOT/.build/OpenDictate.app}"
OUTPUT="${2:-$ROOT/.build/ci-artifact}"
[[ "$#" -le 2 ]] || { echo "Usage: $0 [OpenDictate.app [new-output-directory]]" >&2; exit 2; }
[[ "$(uname -s)" == "Darwin" ]] || { echo "Packaging requires macOS." >&2; exit 1; }
[[ -d "$APP" && "$(basename "$APP")" == "OpenDictate.app" ]] || {
  echo "Expected an existing OpenDictate.app bundle." >&2
  exit 1
}
[[ ! -e "$OUTPUT" && ! -L "$OUTPUT" ]] || { echo "Output already exists: $OUTPUT" >&2; exit 1; }
APP="$(cd "$APP" && pwd -P)"
OUTPUT_PARENT="$(cd "$(dirname "$OUTPUT")" && pwd -P)"
OUTPUT="$OUTPUT_PARENT/$(basename "$OUTPUT")"

cd "$ROOT"
[[ "$(git rev-parse --show-toplevel)" == "$ROOT" ]] || {
  echo "CI packaging requires this project's Git checkout." >&2
  exit 1
}
CHECKOUT_REVISION="$(git rev-parse --verify 'HEAD^{commit}')"
CHECKOUT_STATUS="$(git status --porcelain --untracked-files=normal)"
[[ -z "$CHECKOUT_STATUS" ]] || {
  echo "CI packaging requires a clean checkout, including untracked files." >&2
  exit 1
}
"$ROOT/scripts/verify-app.sh" "$APP"
SIGNATURE="$(codesign -d --verbose=4 "$APP" 2>&1)"
if ! printf '%s\n' "$SIGNATURE" | grep -qx 'Signature=adhoc'; then
  echo "CI artifacts must use an ad-hoc development signature." >&2
  exit 1
fi

PLIST="$APP/Contents/Info.plist"
SOURCE_REVISION="$(plutil -extract OpenDictateSourceRevision raw -expect string -o - "$PLIST")"
SOURCE_STATE="$(plutil -extract OpenDictateSourceState raw -expect string -o - "$PLIST")"
VERSION="$(plutil -extract CFBundleShortVersionString raw -expect string -o - "$PLIST")"
BUILD_NUMBER="$(plutil -extract CFBundleVersion raw -expect string -o - "$PLIST")"
BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw -expect string -o - "$PLIST")"
EXECUTABLE_NAME="$(plutil -extract CFBundleExecutable raw -expect string -o - "$PLIST")"
[[ "$SOURCE_STATE" == "clean" && "$SOURCE_REVISION" == "$CHECKOUT_REVISION" ]] || {
  echo "Bundle must identify the current clean checked-out commit." >&2
  exit 1
}
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$VERSION" == "$(cat VERSION)" ]] || {
  echo "Bundle version does not match VERSION." >&2
  exit 1
}
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo "Invalid bundle build number." >&2; exit 1; }
if [[ -n "${OPENDICTATE_BUILD_NUMBER:-}" && "$BUILD_NUMBER" != "$OPENDICTATE_BUILD_NUMBER" ]]; then
  echo "Bundle build number does not match the requested build." >&2
  exit 1
fi
[[ "$BUNDLE_ID" == "local.opendictate.app" && "$EXECUTABLE_NAME" == "OpenDictate" ]] || {
  echo "Unexpected bundle identity or executable." >&2
  exit 1
}
BINARY="$APP/Contents/MacOS/OpenDictate"
[[ -x "$BINARY" ]] || { echo "App executable is not executable." >&2; exit 1; }
BINARY_MODE="$(stat -f '%Lp' "$BINARY")"
ARCHITECTURES="$(lipo -archs "$BINARY")"
[[ "$ARCHITECTURES" =~ ^[a-zA-Z0-9_]+(\ [a-zA-Z0-9_]+)*$ ]] || {
  echo "Unexpected executable architectures." >&2
  exit 1
}
BINARY_HASH="$(shasum -a 256 "$BINARY" | awk '{print $1}')"
ZIP_NAME="OpenDictate-dev-$VERSION-build-$BUILD_NUMBER-${ARCHITECTURES// /-}-$SOURCE_REVISION.zip"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/opendictate-package.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir "$WORK/files" "$WORK/extracted"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$WORK/files/$ZIP_NAME"
ditto -x -k "$WORK/files/$ZIP_NAME" "$WORK/extracted"
EXTRACTED_APP="$WORK/extracted/OpenDictate.app"
"$ROOT/scripts/verify-app.sh" "$EXTRACTED_APP"
[[ -x "$EXTRACTED_APP/Contents/MacOS/OpenDictate" ]] || {
  echo "ZIP round trip lost the executable permission." >&2
  exit 1
}
EXTRACTED_HASH="$(shasum -a 256 "$EXTRACTED_APP/Contents/MacOS/OpenDictate" | awk '{print $1}')"
[[ "$EXTRACTED_HASH" == "$BINARY_HASH" ]] || { echo "ZIP round trip changed the executable." >&2; exit 1; }
EXTRACTED_MODE="$(stat -f '%Lp' "$EXTRACTED_APP/Contents/MacOS/OpenDictate")"
[[ "$EXTRACTED_MODE" == "$BINARY_MODE" ]] || { echo "ZIP round trip changed the executable's permissions." >&2; exit 1; }
cmp "$PLIST" "$EXTRACTED_APP/Contents/Info.plist"
CHECKOUT_STATUS="$(git status --porcelain --untracked-files=normal)"
[[ "$(git rev-parse --verify 'HEAD^{commit}')" == "$SOURCE_REVISION" && -z "$CHECKOUT_STATUS" ]] || {
  echo "Checkout changed during packaging." >&2
  exit 1
}

python3 - "$EXTRACTED_APP/Contents/Info.plist" "$WORK/files" "$ZIP_NAME" "$ARCHITECTURES" "$BINARY_HASH" "$BINARY_MODE" <<'PY'
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import sys

plist_path, output_path, zip_name, architectures, binary_hash, binary_mode = sys.argv[1:]
with open(plist_path, 'rb') as handle:
    info = plistlib.load(handle)
output = Path(output_path)
archive_hash = hashlib.sha256((output / zip_name).read_bytes()).hexdigest()
run = {}
for field, variable in (('id', 'GITHUB_RUN_ID'), ('number', 'GITHUB_RUN_NUMBER'), ('attempt', 'GITHUB_RUN_ATTEMPT')):
    value = os.environ.get(variable)
    if value:
        if not re.fullmatch(r'[0-9]+', value):
            raise SystemExit(f'Invalid {variable}')
        run[field] = value
repository = os.environ.get('GITHUB_REPOSITORY')
if repository and re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository) and 'id' in run:
    run['url'] = f'https://github.com/{repository}/actions/runs/{run["id"]}'
manifest = {
    'schema_version': 1,
    'kind': 'macOS development build',
    'packaged_at_utc': datetime.now(timezone.utc).isoformat(),
    'source_revision': info['OpenDictateSourceRevision'],
    'source_state': info['OpenDictateSourceState'],
    'source_revision_meaning': 'Actual checked-out Git commit; a pull-request build may use a synthetic merge commit.',
    'application': {
        'bundle_identifier': info['CFBundleIdentifier'],
        'version': info['CFBundleShortVersionString'],
        'build_number': info['CFBundleVersion'],
        'minimum_macos_declared': info['LSMinimumSystemVersion'],
        'architectures': architectures.split(),
        'executable_sha256': binary_hash,
        'executable_mode': binary_mode,
    },
    'archive': {'filename': zip_name, 'sha256': archive_hash},
    'signing': {'kind': 'ad-hoc', 'hardened_runtime': True, 'microphone_entitlement': True, 'notarized': False},
    'verification': {'extracted_signature_and_entitlements': True, 'executable_hash_and_permission_preserved': True},
    'github_run': run or None,
}
(output / 'manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n', encoding='utf-8')
readme = f'''OpenDictate CI development build

Source commit: {info['OpenDictateSourceRevision']} (clean checkout)
App version: {info['CFBundleShortVersionString']}; build: {info['CFBundleVersion']}
App architectures: {architectures}

The app ZIP preserves the bundle's executable permissions. Its extracted copy
passed signature, Hardened Runtime and microphone-entitlement checks; the
executable hash matched. The source commit is the actual checkout, which can be
a synthetic merge commit for a pull request. See manifest.json for run details.

This is an ad-hoc signed development build, not a notarized public release.
It keeps the product bundle identifier local.opendictate.app. Downloading does
not replace an installed daily build; macOS Gatekeeper may block opening it.
An ad-hoc signature cannot inherit an existing build's Accessibility/TCC or
Keychain access identity. Keep this candidate for a deliberate later Mac test.
Packaging did not install or launch the app. Microphone, Accessibility, target
insertion and human speech quality were not tested by this packaging check.

After extracting GitHub's outer artifact ZIP, check the enclosed files with:
    shasum -a 256 -c SHA256SUMS
SHA256SUMS covers the inner app ZIP, manifest.json and this README.txt, not the
outer ZIP supplied by GitHub. Select the app ZIP when preparing a later Mac test.
'''
(output / 'README.txt').write_text(readme, encoding='utf-8')
PY
(
  cd "$WORK/files"
  shasum -a 256 "$ZIP_NAME" manifest.json README.txt > SHA256SUMS
)
mkdir "$OUTPUT"
cp "$WORK/files/$ZIP_NAME" "$WORK/files/manifest.json" "$WORK/files/SHA256SUMS" "$WORK/files/README.txt" "$OUTPUT/"
echo "Verified development artifact: $OUTPUT"
