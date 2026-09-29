#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
rust_toolchain='1.98.1'
export RUSTUP_AUTO_INSTALL=0

if [[ ! -f linux/Cargo.toml || ! -f linux/Cargo.lock ]]; then
  echo "Linux checks require the checked-in Cargo.toml and Cargo.lock." >&2
  exit 1
fi
if ! command -v rustc >/dev/null || ! command -v cargo >/dev/null; then
  echo "Rust and Cargo $rust_toolchain must already be installed and selected; this script does not install toolchains." >&2
  exit 1
fi
rustc_version="$(rustc --version)"
cargo_version="$(cargo --version)"
if [[ "$rustc_version" != "rustc $rust_toolchain "* ]]; then
  echo "Rust $rust_toolchain is required; found: $rustc_version" >&2
  exit 1
fi
if [[ "$cargo_version" != "cargo $rust_toolchain "* ]]; then
  echo "Cargo $rust_toolchain is required; found: $cargo_version" >&2
  exit 1
fi
if ! command -v pkg-config >/dev/null || ! pkg-config --exists alsa; then
  echo "ALSA development files and pkg-config are required (CI installs libasound2-dev)." >&2
  exit 1
fi

printf '%s\n' "$rustc_version" "$cargo_version"
pkg-config --modversion alsa
cargo fmt --manifest-path linux/Cargo.toml -- --check
cargo test --locked --manifest-path linux/Cargo.toml
cargo clippy --locked --manifest-path linux/Cargo.toml --all-targets -- -D warnings
cargo build --release --locked --manifest-path linux/Cargo.toml
