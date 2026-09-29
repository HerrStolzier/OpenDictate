#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if [[ ! -e .git ]]; then
  echo 'Run the secret scan from a Git checkout.' >&2
  exit 1
fi

gitleaks_version='8.30.1'
gitleaks_sha=''
case "$(uname -s)/$(uname -m)" in
  Darwin/arm64) gitleaks_os='darwin'; gitleaks_arch='arm64'; gitleaks_sha='b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5' ;;
  Darwin/x86_64) gitleaks_os='darwin'; gitleaks_arch='x64'; gitleaks_sha='dfe101a4db2255fc85120ac7f3d25e4342c3c20cf749f2c20a18081af1952709' ;;
  Linux/aarch64) gitleaks_os='linux'; gitleaks_arch='arm64'; gitleaks_sha='e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080' ;;
  Linux/x86_64) gitleaks_os='linux'; gitleaks_arch='x64'; gitleaks_sha='551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb' ;;
  *) echo "Unsupported gitleaks host: $(uname -s)/$(uname -m)." >&2; exit 1 ;;
esac

if ! command -v curl >/dev/null || ! command -v tar >/dev/null || ! command -v python3 >/dev/null; then
  echo 'curl, tar and Python 3 are required to fetch and clean up the pinned temporary Gitleaks binary.' >&2
  exit 1
fi

tool_dir="$(mktemp -d "${TMPDIR:-/tmp}/opendictate-gitleaks.XXXXXX")"
cleanup() { python3 -c 'import shutil, sys; shutil.rmtree(sys.argv[1])' "$tool_dir"; }
trap cleanup EXIT

asset="gitleaks_${gitleaks_version}_${gitleaks_os}_${gitleaks_arch}.tar.gz"
archive="$tool_dir/$asset"
url="https://github.com/gitleaks/gitleaks/releases/download/v${gitleaks_version}/${asset}"
curl --fail --silent --show-error --location "$url" --output "$archive"
if command -v shasum >/dev/null; then
  printf '%s  %s\n' "$gitleaks_sha" "$archive" | shasum -a 256 --check --status
else
  printf '%s  %s\n' "$gitleaks_sha" "$archive" | sha256sum --check --status
fi
tar -xzf "$archive" -C "$tool_dir" gitleaks
gitleaks_bin="$tool_dir/gitleaks"

base="${1:-${SCAN_BASE:-}}"
head="${2:-${SCAN_HEAD:-}}"
if [[ "$base" =~ ^0{40}$ ]]; then base=''; fi
if [[ "$head" =~ ^0{40}$ ]]; then head=''; fi
if [[ -z "$head" ]]; then head="$(git rev-parse --verify HEAD^{commit})"; fi
head="$(git rev-parse --verify "${head}^{commit}")"
if [[ -n "$base" ]]; then
  base="$(git rev-parse --verify "${base}^{commit}")"
fi

if [[ -n "$base" && "$base" == "$head" ]]; then
  echo 'Secret-scan base and head resolve to the same commit; refusing an empty range.' >&2
  exit 1
fi
if [[ -n "$base" ]]; then
  log_opts="${base}..${head} --diff-merges=first-parent"
else
  log_opts="${head} --diff-merges=first-parent"
fi

# Gitleaks scans commit patches locally; it never validates or contacts providers.
# Redact the temporary JSON report, then print only safe finding metadata.
report_path="$tool_dir/findings.json"
unset GITLEAKS_CONFIG GITLEAKS_CONFIG_TOML
if "$gitleaks_bin" git \
  --gitleaks-ignore-path="$ROOT/.gitleaksignore" \
  --log-opts="$log_opts" \
  --report-format=json \
  --report-path="$report_path" \
  --redact=100 \
  --no-banner \
  --no-color \
  --log-level=error \
  --timeout=300 \
  "$ROOT"; then
  scan_status=0
else
  scan_status=$?
fi

if [[ ! -s "$report_path" ]]; then
  echo "Gitleaks exited with status $scan_status without a redacted report." >&2
  if [[ "$scan_status" -eq 0 ]]; then exit 1; fi
  exit "$scan_status"
fi

if ! python3 - "$report_path" <<'PY'
import json
import sys
from pathlib import Path

report = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if not isinstance(report, list):
    raise SystemExit("Gitleaks produced an unexpected report format.")
if not report:
    print("Gitleaks scan completed with no new findings.")
for finding in report:
    metadata = {
        key: finding.get(key)
        for key in ("RuleID", "File", "StartLine", "EndLine", "Commit", "Fingerprint")
    }
    print(json.dumps(metadata, sort_keys=True, ensure_ascii=True))
PY
then
  echo 'Could not parse the redacted Gitleaks report.' >&2
  exit 1
fi

exit "$scan_status"
