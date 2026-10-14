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

if ! command -v curl >/dev/null || ! command -v tar >/dev/null || ! command -v python3 >/dev/null; then
  echo 'curl, tar and Python 3 with venv (python3-venv on Debian/Ubuntu) are required to fetch the pinned temporary actionlint and zizmor.' >&2
  exit 1
fi
tool_dir="$(mktemp -d "${TMPDIR:-/tmp}/opendictate-workflow-lint.XXXXXX")"
cleanup() { python3 -c 'import shutil, sys; shutil.rmtree(sys.argv[1])' "$tool_dir"; }
trap cleanup EXIT

if command -v actionlint >/dev/null; then
  actionlint_bin="$(command -v actionlint)"
  if ! "$actionlint_bin" -version | grep -Fq "${actionlint_version}"; then
    echo "actionlint ${actionlint_version} is required for a reproducible check." >&2
    exit 1
  fi
else
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

# zizmor audits the workflows for security problems such as template
# injection, broad permissions and dangerous triggers. The wheel is pinned by
# version and SHA-256 (macOS and glibc Linux, arm64 and x86_64) and installed
# into a temporary virtual environment; --offline skips audits that call GitHub.
zizmor_version='1.30.1'
zizmor_hashes=(
  17fda74e15fe41a6aa354ea4cf71fc7ff3cd025cda6584bb6d7466b3f1d00fe6 # macosx_10_12_x86_64
  f9eb092f089e35fa9fb3b70aeec0a19eca7dacf2ab161f1d50b18351895f085c # macosx_11_0_arm64
  92906f448365672ebb657fb50d36f997290a3aaba8cac723214741ea9054845d # manylinux_2_24_aarch64
  eee12266b793cb87ad4a7e3af2e72404f8a63e3de5eb099b80bf7b1cfd232a8e # manylinux_2_28_x86_64
)
{
  printf 'zizmor==%s' "$zizmor_version"
  printf ' --hash=sha256:%s' "${zizmor_hashes[@]}"
  printf '\n'
} > "$tool_dir/zizmor-requirements.txt"
python3 -m venv "$tool_dir/zizmor-venv"
"$tool_dir/zizmor-venv/bin/python" -m pip install --quiet --disable-pip-version-check \
  --require-hashes --only-binary=:all: --no-deps -r "$tool_dir/zizmor-requirements.txt"
"$tool_dir/zizmor-venv/bin/zizmor" --offline --no-progress --config .github/zizmor.yml .github/workflows
