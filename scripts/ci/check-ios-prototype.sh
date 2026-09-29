#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PROJECT="ios/OpenDictateKeyboardDemo.xcodeproj"
SCHEME="OpenDictateKeyboardDemo"
if [[ ! -d "$PROJECT" ]]; then
  echo "SKIP: $PROJECT is absent from this ref; no iOS build was performed."
  exit 0
fi
if [[ ! -f "$PROJECT/xcshareddata/xcschemes/$SCHEME.xcscheme" ]]; then
  echo "The iOS project exists but its shared $SCHEME scheme is missing." >&2
  exit 1
fi
if ! command -v xcodebuild >/dev/null || ! command -v swift >/dev/null; then
  echo "xcodebuild and Swift are required when the iOS project exists." >&2
  exit 1
fi

xcodebuild -version
swift format lint --strict --configuration .swift-format --recursive ios/Sources

derived_data="$(mktemp -d "${TMPDIR:-/tmp}/opendictate-ios-derived.XXXXXX")"
cleanup() {
  python3 -c 'import shutil, sys; shutil.rmtree(sys.argv[1])' "$derived_data"
}
trap cleanup EXIT

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  build
