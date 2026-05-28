#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/.build/OpenDictate.app"
EXECUTABLE="$ROOT/.build/release/OpenDictate"
ICON_SOURCE="$ROOT/Assets/OpenDictateIcon.png"
ICONSET="$ROOT/.build/OpenDictate.iconset"

cd "$ROOT"
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

cat > "$APP/Contents/Info.plist" <<'PLIST'
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
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSMicrophoneUsageDescription</key>
  <string>OpenDictate records your voice so it can transcribe dictation and paste it into the active app.</string>
</dict>
</plist>
PLIST

xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
xattr -cr "$APP"
echo "$APP"
