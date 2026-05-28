#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${OPENAI_API_KEY:-}" ]]; then
  key="$OPENAI_API_KEY"
else
  read -r -s -p "OpenAI API key: " key
  printf "\n"
fi

if [[ -z "$key" ]]; then
  echo "No API key provided." >&2
  exit 1
fi

security add-generic-password \
  -a OPENAI_API_KEY \
  -s OpenDictate \
  -w "$key" \
  -U

echo "Stored OPENAI_API_KEY in the macOS Keychain service 'OpenDictate'."
