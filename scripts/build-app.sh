#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
APP="$ROOT/.build/OpenDictate.app"
EXECUTABLE="$ROOT/.build/release/OpenDictate"
ICON_SOURCE="$ROOT/Assets/OpenDictateIcon.png"
ICONSET="$ROOT/.build/OpenDictate.iconset"

cd "$ROOT"
VERSION="$(cat "$ROOT/VERSION")"
BUILD_NUMBER="${OPENDICTATE_BUILD_NUMBER:-1}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid VERSION" >&2; exit 1; }
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo "Invalid build number" >&2; exit 1; }
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
swift build -c release
if [[ "$GIT_ROOT" == "$ROOT" ]]; then
  [[ "$(git rev-parse --verify 'HEAD^{commit}')" == "$SOURCE_REVISION" ]] || {
    echo "Checkout changed during the build; build again from the intended commit." >&2
    exit 1
  }
  CHECKOUT_STATUS="$(git status --porcelain --untracked-files=normal)"
  if [[ -n "$CHECKOUT_STATUS" ]]; then SOURCE_STATE="dirty"; fi
fi
echo "Source revision: $SOURCE_REVISION ($SOURCE_STATE)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$EXECUTABLE" "$APP/Contents/MacOS/OpenDictate"
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

# Sign with a stable code-signing identity so macOS keeps the Accessibility
# (TCC) grant across rebuilds. Ad-hoc signatures change their code hash on every
# build, which silently invalidates the Accessibility permission. Override the
# identity with OPENDICTATE_SIGN_IDENTITY; falls back to ad-hoc if it is missing.
# Note: the self-signed identity is intentionally untrusted (it only exists to
# keep the signing identity stable for TCC), so it appears under "Matching identities"
# but not under "Valid identities only" — match the former, without -v.
SIGN_IDENTITY="${OPENDICTATE_SIGN_IDENTITY:-OpenDictate Self-Signed}"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "Signing ad hoc."
  SIGN_ARGS=(--force --deep --options runtime --sign -)
elif security find-identity -p codesigning 2>/dev/null | grep -qF "\"$SIGN_IDENTITY\""; then
  echo "Signing with identity: $SIGN_IDENTITY"
  SIGN_ARGS=(--force --deep --options runtime --sign "$SIGN_IDENTITY")
else
  echo "WARNING: code-signing identity '$SIGN_IDENTITY' not found; falling back to ad-hoc."
  echo "         The Accessibility permission will need to be re-granted after each build."
  echo "         See docs/accessibility-signing.md to create the stable identity."
  SIGN_ARGS=(--force --deep --options runtime --sign -)
fi

SIGN_ARGS+=(--entitlements "$ROOT/Assets/OpenDictate.entitlements")

clear_xattrs
if ! codesign "${SIGN_ARGS[@]}" "$APP" 2>/dev/null; then
  clear_xattrs
  codesign "${SIGN_ARGS[@]}" "$APP"
fi

clear_xattrs
"$ROOT/scripts/verify-app.sh" "$APP"
echo "$APP"
