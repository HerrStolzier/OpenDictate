#!/usr/bin/env bash
set -euo pipefail
unset OPENAI_API_KEY

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/.build/OpenDictate.app"
if [[ ! -d "$APP" ]]; then
  echo "Build OpenDictate before storing its API key: ./scripts/build-app.sh" >&2
  exit 1
fi

# Keep -w last: macOS `security` then prompts without putting the secret in
# shell history, this script's environment, or a child process argument. -T
# binds a new item to the built app instead of trusting the generic tool.
/usr/bin/security add-generic-password \
  -a OPENAI_API_KEY \
  -s OpenDictate \
  -T "$APP" \
  -w

echo "Stored OPENAI_API_KEY in the macOS Keychain service 'OpenDictate'."
