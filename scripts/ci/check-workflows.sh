#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if [[ ! -d .github/workflows ]] || ! compgen -G '.github/workflows/*.yml' >/dev/null; then
  echo 'No GitHub Actions workflow YAML files were found.' >&2
  exit 1
fi

python3 - .github/workflows/*.yml <<'PY'
from pathlib import Path
import re
import sys

bad = []
for name in sys.argv[1:]:
    path = Path(name)
    for number, line in enumerate(path.read_text().splitlines(), start=1):
        match = re.match(r"^\s*(?:-\s*)?uses:\s*([^\s#]+)", line)
        if match and not match.group(1).startswith("./"):
            reference = match.group(1).rsplit("@", 1)
            if len(reference) != 2 or not re.fullmatch(r"[0-9a-f]{40}", reference[1]):
                bad.append(f"{path}:{number}: external action must use a full 40-character commit SHA")

if bad:
    print("\n".join(bad), file=sys.stderr)
    raise SystemExit(1)
PY

actionlint_version='1.7.12'
actionlint_sha=''
case "$(uname -s)/$(uname -m)" in
  Darwin/arm64) actionlint_os='darwin'; actionlint_arch='arm64'; actionlint_sha='aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f' ;;
  Darwin/x86_64) actionlint_os='darwin'; actionlint_arch='amd64'; actionlint_sha='5b44c3bc2255115c9b69e30efc0fecdf498fdb63c5d58e17084fd5f16324c644' ;;
  Linux/aarch64) actionlint_os='linux'; actionlint_arch='arm64'; actionlint_sha='325e971b6ba9bfa504672e29be93c24981eeb1c07576d730e9f7c8805afff0c6' ;;
  Linux/x86_64) actionlint_os='linux'; actionlint_arch='amd64'; actionlint_sha='8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8' ;;
  *) echo "Unsupported actionlint host: $(uname -s)/$(uname -m)." >&2; exit 1 ;;
esac

if command -v actionlint >/dev/null; then
  actionlint_bin="$(command -v actionlint)"
  if ! "$actionlint_bin" -version | grep -Fq "${actionlint_version}"; then
    echo "actionlint ${actionlint_version} is required for a reproducible check." >&2
    exit 1
  fi
else
  if ! command -v curl >/dev/null || ! command -v tar >/dev/null || ! command -v python3 >/dev/null; then
    echo 'curl, tar and Python 3 are required to fetch the pinned temporary actionlint binary.' >&2
    exit 1
  fi
  tool_dir="$(mktemp -d "${TMPDIR:-/tmp}/opendictate-actionlint.XXXXXX")"
  cleanup() { python3 -c 'import shutil, sys; shutil.rmtree(sys.argv[1])' "$tool_dir"; }
  trap cleanup EXIT
  asset="actionlint_${actionlint_version}_${actionlint_os}_${actionlint_arch}.tar.gz"
  archive="$tool_dir/$asset"
  url="https://github.com/rhysd/actionlint/releases/download/v${actionlint_version}/${asset}"
  curl --fail --silent --show-error --location "$url" --output "$archive"
  if command -v shasum >/dev/null; then
    printf '%s  %s\n' "$actionlint_sha" "$archive" | shasum -a 256 --check --status
  else
    printf '%s  %s\n' "$actionlint_sha" "$archive" | sha256sum --check --status
  fi
  tar -xzf "$archive" -C "$tool_dir" actionlint
  actionlint_bin="$tool_dir/actionlint"
fi

"$actionlint_bin" -color .github/workflows/*.yml
