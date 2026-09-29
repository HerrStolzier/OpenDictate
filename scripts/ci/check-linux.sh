#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
rust_toolchain='1.98.1'

if [[ ! -f linux/Cargo.toml || ! -f linux/Cargo.lock ]]; then
  echo "Linux checks require the checked-in Cargo.toml and Cargo.lock." >&2
  exit 1
fi
if ! command -v pkg-config >/dev/null || ! pkg-config --exists alsa; then
  echo "ALSA development files and pkg-config are required (CI installs libasound2-dev)." >&2
  exit 1
fi

rustc "+$rust_toolchain" --version
cargo "+$rust_toolchain" --version
pkg-config --modversion alsa
cargo "+$rust_toolchain" fmt --manifest-path linux/Cargo.toml -- --check
cargo "+$rust_toolchain" test --locked --manifest-path linux/Cargo.toml
cargo "+$rust_toolchain" clippy --locked --manifest-path linux/Cargo.toml --all-targets -- -D warnings
cargo "+$rust_toolchain" build --release --locked --manifest-path linux/Cargo.toml
