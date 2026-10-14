#!/usr/bin/env python3
"""Regenerate the Rust crate list of the Linux binary in THIRD_PARTY_NOTICES.md.

The list holds every crate linked into the binary: the normal dependency graph
of linux/Cargo.toml for the Linux targets, without dev, build and proc-macro
dependencies, grouped by the license expression each crate declares. It reads
Cargo.lock through `cargo tree --locked` and never changes it.

Run without arguments to rewrite the section, or with --check to fail when it
is out of date. Pass --offline when the crates are already in Cargo's cache.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "linux" / "Cargo.toml"
NOTICES = ROOT / "THIRD_PARTY_NOTICES.md"
TARGETS = ("x86_64-unknown-linux-gnu", "aarch64-unknown-linux-gnu")
BEGIN = "<!-- third-party-rust:begin -->"
END = "<!-- third-party-rust:end -->"
SEPARATOR = "\t"


def crates(offline: bool) -> list[tuple[str, str, str]]:
    """Returns (name, version, license) for every third-party crate."""
    command = ["cargo", "tree", "--manifest-path", str(MANIFEST), "--locked", "-e", "normal,no-proc-macro",
               "--prefix", "none", "--format", f"{{p}}{SEPARATOR}{{l}}"]
    for target in TARGETS:
        command += ["--target", target]
    if offline:
        command.append("--offline")
    output = subprocess.run(command, check=True, capture_output=True, text=True).stdout
    return parse(output)


def parse(output: str) -> list[tuple[str, str, str]]:
    found = set()
    for line in output.splitlines():
        package, _, license_expression = line.removesuffix(" (*)").partition(SEPARATOR)
        fields = package.split(" ")
        if len(fields) != 2:
            continue  # the Linux crate itself prints its local path after the version
        found.add((fields[0], fields[1].removeprefix("v"), license_expression.strip() or "unknown"))
    return sorted(found)


def render(entries: list[tuple[str, str, str]]) -> str:
    by_license: dict[str, list[str]] = defaultdict(list)
    for name, version, license_expression in entries:
        by_license[license_expression].append(f"{name} {version}")
    lines = [BEGIN]
    for license_expression in sorted(by_license):
        lines += ["", f"- **{license_expression}:** " + ", ".join(by_license[license_expression])]
    lines += ["", END]
    return "\n".join(lines)


def replace_section(text: str, section: str) -> str:
    start, end = text.find(BEGIN), text.find(END)
    if start < 0 or end < start:
        raise ValueError(f"{NOTICES.name} has no {BEGIN} … {END} section")
    return text[:start] + section + text[end + len(END):]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="fail when the section is out of date")
    parser.add_argument("--offline", action="store_true", help="pass --offline to cargo")
    args = parser.parse_args()
    current = NOTICES.read_text(encoding="utf-8")
    updated = replace_section(current, render(crates(args.offline)))
    if args.check:
        if updated != current:
            print(f"{NOTICES.name} is out of date; run scripts/third-party-rust.py", file=sys.stderr)
            return 1
        return 0
    NOTICES.write_text(updated, encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
