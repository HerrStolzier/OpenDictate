#!/usr/bin/env bash
# Package an already accepted and stapled Developer ID app; never submit or launch it.
set -euo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
[[ "$#" -eq 3 ]] || {
  echo "Usage: $0 OpenDictate.app /absolute/new-output-directory TEAM_ID" >&2
  exit 2
}
[[ "$(uname -s)" == "Darwin" ]] || {
  echo "Release packaging requires macOS." >&2
  exit 1
}

APP_INPUT="$1"
OUTPUT_INPUT="$2"
EXPECTED_TEAM_ID="$3"
[[ "$EXPECTED_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || {
  echo "Team ID must be a 10-character uppercase Developer ID team." >&2
  exit 2
}

cd "$ROOT"
[[ "$(git rev-parse --show-toplevel)" == "$ROOT" ]] || {
  echo "Release packaging requires this project's Git checkout." >&2
  exit 1
}
CHECKOUT_REVISION="$(git rev-parse --verify 'HEAD^{commit}')"
CHECKOUT_STATUS="$(git status --porcelain --untracked-files=normal)"
[[ -z "$CHECKOUT_STATUS" ]] || {
  echo "Release packaging requires a clean checkout, including untracked files." >&2
  exit 1
}

[[ -d "$APP_INPUT" && "$(basename "$APP_INPUT")" == "OpenDictate.app" ]] || {
  echo "Expected an existing OpenDictate.app bundle." >&2
  exit 1
}
APP="$(cd "$APP_INPUT" && pwd -P)"

OUTPUT_NAME="$(basename "$OUTPUT_INPUT")"
[[ "$OUTPUT_NAME" != "." && "$OUTPUT_NAME" != ".." ]] || {
  echo "Choose a new output directory outside the checkout." >&2
  exit 2
}
OUTPUT_PARENT="$(cd "$(dirname "$OUTPUT_INPUT")" && pwd -P)" || {
  echo "Output parent directory must already exist." >&2
  exit 1
}
OUTPUT="$OUTPUT_PARENT/$OUTPUT_NAME"
case "$OUTPUT/" in
  "$ROOT/"*)
    echo "Release output must be outside the source checkout." >&2
    exit 1
    ;;
esac
[[ ! -e "$OUTPUT" && ! -L "$OUTPUT" ]] || {
  echo "Release output already exists; refusing to overwrite it: $OUTPUT" >&2
  exit 1
}

"$ROOT/scripts/verify-app.sh" --release --team-id "$EXPECTED_TEAM_ID" "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"

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
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || {
  echo "Invalid bundle build number." >&2
  exit 1
}
[[ "$BUNDLE_ID" == "local.opendictate.app" && "$EXECUTABLE_NAME" == "OpenDictate" ]] || {
  echo "Unexpected bundle identity or executable." >&2
  exit 1
}

BINARY="$APP/Contents/MacOS/OpenDictate"
HELPER="$APP/Contents/Helpers/OpenDictateKeychainHelper"
[[ -x "$BINARY" && -x "$HELPER" ]] || {
  echo "Release app or Keychain helper is not executable." >&2
  exit 1
}
[[ "$(lipo -archs "$BINARY")" == "arm64" && "$(lipo -archs "$HELPER")" == "arm64" ]] || {
  echo "Release app and Keychain helper must contain only arm64." >&2
  exit 1
}
BINARY_HASH="$(shasum -a 256 "$BINARY" | awk '{print $1}')"
BINARY_MODE="$(stat -f '%Lp' "$BINARY")"
ZIP_NAME="OpenDictate-$VERSION-build-$BUILD_NUMBER-arm64-$SOURCE_REVISION.zip"

STAGING="$(mktemp -d "$OUTPUT_PARENT/.${OUTPUT_NAME}.staging.XXXXXX")"
cleanup() {
  if [[ -n "$STAGING" && -d "$STAGING" ]]; then
    rm -rf "$STAGING"
  fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir "$STAGING/extracted"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$STAGING/$ZIP_NAME"
ditto -x -k "$STAGING/$ZIP_NAME" "$STAGING/extracted"

EXTRACTED_APP="$STAGING/extracted/OpenDictate.app"
"$ROOT/scripts/verify-app.sh" --release --team-id "$EXPECTED_TEAM_ID" "$EXTRACTED_APP"
xcrun stapler validate "$EXTRACTED_APP"
spctl --assess --type execute --verbose=2 "$EXTRACTED_APP"
cmp "$PLIST" "$EXTRACTED_APP/Contents/Info.plist"

EXTRACTED_HASH="$(shasum -a 256 "$EXTRACTED_APP/Contents/MacOS/OpenDictate" | awk '{print $1}')"
[[ "$EXTRACTED_HASH" == "$BINARY_HASH" ]] || {
  echo "ZIP round trip changed the app executable." >&2
  exit 1
}
EXTRACTED_MODE="$(stat -f '%Lp' "$EXTRACTED_APP/Contents/MacOS/OpenDictate")"
[[ "$EXTRACTED_MODE" == "$BINARY_MODE" ]] || {
  echo "ZIP round trip changed the app executable permissions." >&2
  exit 1
}

CHECKOUT_STATUS="$(git status --porcelain --untracked-files=normal)"
[[ "$(git rev-parse --verify 'HEAD^{commit}')" == "$SOURCE_REVISION" && -z "$CHECKOUT_STATUS" ]] || {
  echo "Checkout changed during release packaging." >&2
  exit 1
}

python3 - "$STAGING" "$ZIP_NAME" "$VERSION" "$BUILD_NUMBER" "$SOURCE_REVISION" "$EXPECTED_TEAM_ID" "$BUNDLE_ID" "$BINARY_HASH" <<'PY'
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import sys

output, zip_name, version, build_number, revision, team, bundle_id, executable_hash = sys.argv[1:]
archive = Path(output) / zip_name
manifest = {
    "schema_version": 1,
    "kind": "private macOS Developer ID release candidate",
    "created_at_utc": datetime.now(timezone.utc).isoformat(),
    "version": version,
    "build_number": build_number,
    "source_revision": revision,
    "source_state": "clean",
    "team_identifier": team,
    "architecture": ["arm64"],
    "bundle_identifier": bundle_id,
    "executable_sha256": executable_hash,
    "archive": {
        "filename": zip_name,
        "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
    },
    "verification": {
        "developer_id_signatures": True,
        "matching_app_and_helper_identity": True,
        "secure_timestamps": True,
        "hardened_runtime": True,
        "microphone_entitlement": True,
        "stapled_ticket": True,
        "gatekeeper_assessment": True,
        "extracted_archive_checked": True,
    },
}
(Path(output) / "manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY

rm -rf "$STAGING/extracted"
CHECKOUT_STATUS="$(git status --porcelain --untracked-files=normal)"
[[ "$(git rev-parse --verify 'HEAD^{commit}')" == "$SOURCE_REVISION" && -z "$CHECKOUT_STATUS" ]] || {
  echo "Checkout changed while writing the release manifest." >&2
  exit 1
}
[[ ! -e "$OUTPUT" && ! -L "$OUTPUT" ]] || {
  echo "Release output appeared during packaging; refusing to overwrite it: $OUTPUT" >&2
  exit 1
}
mv "$STAGING" "$OUTPUT"
STAGING=""
echo "Verified private release candidate: $OUTPUT"
