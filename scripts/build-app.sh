#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/.build/OpenDictate.app"
EXECUTABLE="$ROOT/.build/release/OpenDictate"
ICON_SOURCE="$ROOT/Assets/OpenDictateIcon.png"
ICONSET="$ROOT/.build/OpenDictate.iconset"

cd "$ROOT"
VERSION="$(cat "$ROOT/VERSION")"
BUILD_NUMBER="${OPENDICTATE_BUILD_NUMBER:-1}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid VERSION" >&2; exit 1; }
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo "Invalid build number" >&2; exit 1; }
swift build -c release

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
# keep the code hash stable for TCC), so it appears under "Matching identities"
# but not under "Valid identities only" — match the former, without -v.
SIGN_IDENTITY="${OPENDICTATE_SIGN_IDENTITY:-OpenDictate Self-Signed}"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "Signing ad hoc."
  SIGN_ARGS=(--force --deep --sign -)
elif security find-identity -p codesigning 2>/dev/null | grep -qF "\"$SIGN_IDENTITY\""; then
  echo "Signing with identity: $SIGN_IDENTITY"
  SIGN_ARGS=(--force --deep --sign "$SIGN_IDENTITY")
else
  echo "WARNING: code-signing identity '$SIGN_IDENTITY' not found; falling back to ad-hoc."
  echo "         The Accessibility permission will need to be re-granted after each build."
  echo "         See docs/accessibility-signing.md to create the stable identity."
  SIGN_ARGS=(--force --deep --sign -)
fi

clear_xattrs
if ! codesign "${SIGN_ARGS[@]}" "$APP" 2>/dev/null; then
  clear_xattrs
  codesign "${SIGN_ARGS[@]}" "$APP"
fi

clear_xattrs
codesign --verify --deep --strict "$APP"
echo "$APP"
