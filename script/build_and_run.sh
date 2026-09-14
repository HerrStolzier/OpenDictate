#!/usr/bin/env bash
# Daily app entrypoint; preview and fixture builds require explicit flags.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
MODE="${1:---daily}"
case "$MODE" in
  --daily|--preview|--verify|--focus-fixture|--processing-focus-preview) ;;
  *) echo "Usage: $0 [--daily|--preview|--verify|--focus-fixture|--processing-focus-preview]" >&2; exit 2 ;;
esac
if [[ "$MODE" == "--daily" ]]; then
  DAILY_APP="$HOME/Applications/OpenDictate.app"
  [[ -d "$DAILY_APP" ]] || { echo "OpenDictate fehlt unter $DAILY_APP" >&2; exit 1; }
  codesign --verify --deep --strict "$DAILY_APP"
  # Reuse the existing instance; never start a second dictation process.
  for app_pid in $(pgrep -x 'OpenDictate|OpenDictatePreview|OpenDictateFocusFixture' || true); do
    running_path="$(ps -p "$app_pid" -o comm=)"
    [[ "$running_path" == "$DAILY_APP/Contents/MacOS/OpenDictate" ]] || {
      echo "Eine andere OpenDictate-Fassung läuft bereits. Bitte diese zuerst beenden." >&2
      exit 1
    }
  done
  /usr/bin/open "$DAILY_APP" --args --show-window
  exit 0
fi
APP_NAME="OpenDictatePreview"
BUNDLE_ID="local.opendictate.designpreview"
RUN_ARGUMENT="--design-preview"
if [[ "$MODE" == "--focus-fixture" ]]; then
  APP_NAME="OpenDictateFocusFixture"
  BUNDLE_ID="local.opendictate.focusfixture"
  RUN_ARGUMENT="--focus-fixture"
fi
if [[ "$MODE" == "--processing-focus-preview" ]]; then
  RUN_ARGUMENT="--processing-focus-preview"
fi
if pgrep -x OpenDictate >/dev/null || pgrep -x "$APP_NAME" >/dev/null; then
  echo "OpenDictate oder diese Vorschau läuft bereits. Vor dem Test regulär beenden." >&2
  exit 1
fi
swift build --build-system native -Xswiftc -warnings-as-errors
BIN="$(swift build --build-system native --show-bin-path)/OpenDictate"
APP="$ROOT/.build/$APP_NAME.app"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$APP_NAME</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleName</key><string>$APP_NAME</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
plutil -lint "$APP/Contents/Info.plist"
xattr -cr "$APP"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
/usr/bin/open -n "$APP" --args "$RUN_ARGUMENT"
if [[ "$MODE" == "--verify" ]]; then
  sleep 1
  pgrep -x OpenDictatePreview >/dev/null
fi
