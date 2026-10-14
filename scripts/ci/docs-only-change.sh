#!/usr/bin/env bash
# Prints `docs_only=true` when every path changed between BASE and HEAD is
# documentation (`*.md`, `docs/**`, static content under `website/`),
# otherwise `docs_only=false`. Under `website/` only pages, styles, text,
# subtitles, images, videos and fonts count; scripts such as `worker.js`,
# configuration such as `wrangler.toml` and any other type run the full checks.
# Any missing argument, failed diff or empty change set counts as a code change.
set -euo pipefail

base="${1:-}"
head="${2:-}"

if [[ -z "$base" || -z "$head" ]]; then
  echo 'docs_only=false'
  exit 0
fi

if ! changed="$(git diff --name-only --no-renames "$base" "$head")"; then
  echo 'docs_only=false'
  exit 0
fi

if [[ -z "$changed" ]]; then
  echo 'docs_only=false'
  exit 0
fi

while IFS= read -r path; do
  case "$path" in
    *.md | docs/*) ;;
    website/*.html | website/*.css | website/*.txt | website/*.vtt | website/*.xml) ;;
    website/*.svg | website/*.png | website/*.jpg | website/*.jpeg | website/*.webp) ;;
    website/*.mp4 | website/*.woff2) ;;
    *)
      echo 'docs_only=false'
      exit 0
      ;;
  esac
done <<<"$changed"

echo 'docs_only=true'
