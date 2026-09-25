#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
APP="$ROOT/.build/OpenDictate.app"
EXECUTABLE=""
HELPER_EXECUTABLE=""
ICON_SOURCE="$ROOT/Assets/OpenDictateIcon.png"
ICONSET="$ROOT/.build/OpenDictate.iconset"

cd "$ROOT"
VERSION="$(cat "$ROOT/VERSION")"
BUILD_MODE="${OPENDICTATE_BUILD_MODE:-development}"
BUILD_NUMBER="${OPENDICTATE_BUILD_NUMBER:-1}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid VERSION" >&2; exit 1; }
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo "Invalid build number" >&2; exit 1; }
case "$BUILD_MODE" in
  development|release) ;;
  *) echo "OPENDICTATE_BUILD_MODE must be 'development' or 'release'." >&2; exit 1 ;;
esac
SOURCE_REVISION="${OPENDICTATE_SOURCE_REVISION:-}"
SOURCE_STATE="unversioned"
if [[ -n "$SOURCE_REVISION" && ! "$SOURCE_REVISION" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Source revision must be a full lowercase Git commit hash." >&2
  exit 1
fi
GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ "$GIT_ROOT" == "$ROOT" ]]; then
  CHECKOUT_REVISION="$(git rev-parse --verify 'HEAD^{commit}')"
  if [[ -n "$SOURCE_REVISION" && "$SOURCE_REVISION" != "$CHECKOUT_REVISION" ]]; then
    echo "Source revision override does not match the checked-out commit." >&2
    exit 1
  fi
  SOURCE_REVISION="$CHECKOUT_REVISION"
  SOURCE_STATE="clean"
  CHECKOUT_STATUS="$(git status --porcelain --untracked-files=normal)"
  if [[ -n "$CHECKOUT_STATUS" ]]; then SOURCE_STATE="dirty"; fi
elif [[ -n "$SOURCE_REVISION" ]]; then
  SOURCE_STATE="unverified"
else
  SOURCE_REVISION="unknown"
fi
EXPECTED_TEAM_ID=""
if [[ "$BUILD_MODE" == "release" ]]; then
  [[ "$GIT_ROOT" == "$ROOT" ]] || {
    echo "Release builds require this project's Git checkout." >&2
    exit 1
  }
  [[ -z "$CHECKOUT_STATUS" ]] || {
    echo "Release builds require a clean checkout, including untracked files." >&2
    exit 1
  }
  [[ -n "${OPENDICTATE_BUILD_NUMBER:-}" ]] || {
    echo "Set OPENDICTATE_BUILD_NUMBER explicitly for a release build." >&2
    exit 1
  }
  if [[ -n "$SOURCE_REVISION" && "$SOURCE_REVISION" != "$CHECKOUT_REVISION" ]]; then
    echo "Release source revision must match the checked-out commit." >&2
    exit 1
  fi
  SIGN_IDENTITY="${OPENDICTATE_SIGN_IDENTITY:-}"
  [[ -n "$SIGN_IDENTITY" ]] || {
    echo "Release builds require OPENDICTATE_SIGN_IDENTITY naming a valid Developer ID Application identity." >&2
    exit 1
  }
  if [[ "$SIGN_IDENTITY" =~ ^Developer\ ID\ Application:\ .+\ \(([A-Z0-9]{10})\)$ ]]; then
    EXPECTED_TEAM_ID="${BASH_REMATCH[1]}"
  else
    echo "Release identity must be 'Developer ID Application: Name (TEAMID)'." >&2
    exit 1
  fi
  if ! security find-identity -v -p codesigning 2>/dev/null | awk -v identity="$SIGN_IDENTITY" '
    index($0, "\"" identity "\"") { found = 1 }
    END { exit !found }'; then
    echo "No valid Developer ID Application identity matches OPENDICTATE_SIGN_IDENTITY." >&2
    exit 1
  fi
  echo "Building clean arm64 release for team $EXPECTED_TEAM_ID."
  BUILD_ARGUMENTS=(-c release --triple arm64-apple-macosx14.0)
  swift build "${BUILD_ARGUMENTS[@]}"
else
  BUILD_ARGUMENTS=(-c release)
  swift build "${BUILD_ARGUMENTS[@]}"
fi
PRODUCT_BIN_PATH="$(swift build --show-bin-path "${BUILD_ARGUMENTS[@]}")"
EXECUTABLE="$PRODUCT_BIN_PATH/OpenDictate"
HELPER_EXECUTABLE="$PRODUCT_BIN_PATH/OpenDictateKeychainHelper"
[[ -x "$EXECUTABLE" && -x "$HELPER_EXECUTABLE" ]] || {
  echo "SwiftPM did not produce both expected executables in $PRODUCT_BIN_PATH." >&2
  exit 1
}
if [[ "$GIT_ROOT" == "$ROOT" ]]; then
  [[ "$(git rev-parse --verify 'HEAD^{commit}')" == "$SOURCE_REVISION" ]] || {
    echo "Checkout changed during the build; build again from the intended commit." >&2
    exit 1
  }
  CHECKOUT_STATUS="$(git status --porcelain --untracked-files=normal)"
  if [[ -n "$CHECKOUT_STATUS" ]]; then SOURCE_STATE="dirty"; fi
fi
echo "Source revision: $SOURCE_REVISION ($SOURCE_STATE)"

if [[ "$BUILD_MODE" == "release" ]]; then
  for binary in "$EXECUTABLE" "$HELPER_EXECUTABLE"; do
    [[ "$(lipo -archs "$binary")" == "arm64" ]] || {
      echo "Release executable must contain only arm64: $binary" >&2
      exit 1
    }
  done
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Helpers"
cp "$EXECUTABLE" "$APP/Contents/MacOS/OpenDictate"
cp "$HELPER_EXECUTABLE" "$APP/Contents/Helpers/OpenDictateKeychainHelper"
cp "$ICON_SOURCE" "$APP/Contents/Resources/OpenDictateIcon.png"

rm -rf "$ICONSET"
mkdir -p "$ICONSET"
sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/OpenDictate.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>OpenDictate</string>
  <key>CFBundleExecutable</key>
  <string>OpenDictate</string>
  <key>CFBundleIdentifier</key>
  <string>local.opendictate.app</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>OpenDictate</string>
  <key>CFBundleIconFile</key>
  <string>OpenDictate.icns</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>OpenDictateSourceRevision</key>
  <string>$SOURCE_REVISION</string>
  <key>OpenDictateSourceState</key>
  <string>$SOURCE_STATE</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSMicrophoneUsageDescription</key>
  <string>OpenDictate records your voice so it can transcribe dictation and paste it into the active app.</string>
</dict>
</plist>
PLIST
plutil -lint "$APP/Contents/Info.plist"

# Strip extended attributes before signing. When the checkout lives in an
# iCloud-synced folder (Desktop/Documents), the file provider keeps re-adding
# com.apple.FinderInfo / com.apple.provenance, which codesign rejects as
# "detritus" — so clear thoroughly and retry once if it races back in.
clear_xattrs() {
  xattr -cr "$APP" 2>/dev/null || true
  find "$APP" -exec xattr -c {} \; 2>/dev/null || true
}

if [[ "$BUILD_MODE" == "release" ]]; then
  echo "Signing app and helper with Developer ID team $EXPECTED_TEAM_ID."
  SIGN_ARGS=(--force --timestamp --options runtime --sign "$SIGN_IDENTITY")
  HELPER_SIGN_ARGS=(--force --timestamp --options runtime --sign "$SIGN_IDENTITY")
elif [[ "${OPENDICTATE_SIGN_IDENTITY:-OpenDictate Self-Signed}" == "-" ]]; then
  echo "Signing development build ad hoc."
  SIGN_ARGS=(--force --options runtime --sign -)
  HELPER_SIGN_ARGS=(--force --options runtime --sign -)
  SIGN_IDENTITY="-"
elif security find-identity -p codesigning 2>/dev/null | grep -qF "\"${OPENDICTATE_SIGN_IDENTITY:-OpenDictate Self-Signed}\""; then
  SIGN_IDENTITY="${OPENDICTATE_SIGN_IDENTITY:-OpenDictate Self-Signed}"
  echo "Signing development build with identity: $SIGN_IDENTITY"
  SIGN_ARGS=(--force --options runtime --sign "$SIGN_IDENTITY")
  HELPER_SIGN_ARGS=(--force --options runtime --sign "$SIGN_IDENTITY")
else
  SIGN_IDENTITY="${OPENDICTATE_SIGN_IDENTITY:-OpenDictate Self-Signed}"
  echo "WARNING: development identity '$SIGN_IDENTITY' not found; falling back to ad-hoc."
  echo "         The Accessibility permission will need to be re-granted after each build."
  echo "         See docs/accessibility-signing.md to create the stable identity."
  SIGN_ARGS=(--force --options runtime --sign -)
  HELPER_SIGN_ARGS=(--force --options runtime --sign -)
fi

SIGN_ARGS+=(--entitlements "$ROOT/Assets/OpenDictate.entitlements")
HELPER_SIGN_ARGS+=(--identifier OpenDictateKeychainHelper)

clear_xattrs
codesign "${HELPER_SIGN_ARGS[@]}" "$APP/Contents/Helpers/OpenDictateKeychainHelper"
if ! codesign "${SIGN_ARGS[@]}" "$APP" 2>/dev/null; then
  clear_xattrs
  codesign "${SIGN_ARGS[@]}" "$APP"
fi

clear_xattrs
if [[ "$BUILD_MODE" == "release" ]]; then
  "$ROOT/scripts/verify-app.sh" --release --team-id "$EXPECTED_TEAM_ID" "$APP"
else
  "$ROOT/scripts/verify-app.sh" "$APP"
fi
echo "$APP"
