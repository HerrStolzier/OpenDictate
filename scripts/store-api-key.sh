#!/usr/bin/env bash
set -euo pipefail
unset OPENAI_API_KEY

# Keep -w last: macOS `security` then prompts without putting the secret in
# shell history, this script's environment, or a child process argument.
security add-generic-password \
  -a OPENAI_API_KEY \
  -s OpenDictate \
  -U \
  -w

echo "Stored OPENAI_API_KEY in the macOS Keychain service 'OpenDictate'."
