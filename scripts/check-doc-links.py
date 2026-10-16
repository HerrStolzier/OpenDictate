#!/usr/bin/env python3
"""Check repository Markdown file links and GitHub heading anchors offline."""

from __future__ import annotations

import argparse
import html
import os
import re
import sys
import unicodedata
from pathlib import Path
from urllib.parse import unquote, urlsplit

IGNORED_DIRECTORIES = {".git", ".build", ".swiftpm", "target", "node_modules", "bin", "obj", "__pycache__", ".venv"}
# Historical links describe old candidates; only current documents gate this check.
# File existence is still checked in historical documents.
HISTORICAL_DIRECTORIES = {"docs/archive", "docs/release-plans/evidence"}
INLINE_LINK = re.compile(r"!?\[[^\]]*\]\s*\(\s*(<[^>\n]+>|(?:[^\s()\\]|\\.|\([^()]*\))*)(?:\s+['\"][^\n]*['\"])?\s*\)")
REFERENCE = re.compile(r"^ {0,3}\[([^\]]+)\]:[ \t]*(?:\n[ \t]*)?(<[^>]+>|\S+)", re.M)


def prose_lines(text: str):
    fence_character, fence_length = "", 0
    fence_container = (0, 0)
    list_indents: list[int] = []
    for number, line in enumerate(text.splitlines(), 1):
        # Quote and list prefixes are containers, not part of their content.
        root_code = fence_character and fence_container == (0, 0)
        quote = re.match(r"^(?: {0,3}>[ \t]?)+", line) if not root_code else None
        quote_depth = quote[0].count(">") if quote else 0
        if not root_code:
            line = re.sub(r"^(?: {0,3}>[ \t]?)+", "", line)
        indentation = len(line) - len(line.lstrip(" "))
        if fence_character and (quote_depth != fence_container[0] or line.strip() and indentation < fence_container[1]):
            fence_character = ""
        if line.strip():
            while list_indents and indentation < list_indents[-1]:
                list_indents.pop()
        item = re.match(r"^( *)(?:[-+*]|\d+[.)])([ \t]+)", line)
        if item:
            list_indents.append(item.end())
            line = line[item.end():]
        elif list_indents and indentation >= list_indents[-1]:
            line = line[list_indents[-1]:]
        fence = re.match(r"^ {0,3}(`{3,}|~{3,})", line)
        if fence:
            marker = fence[1]
            if not fence_character:
                fence_character, fence_length = marker[0], len(marker)
                fence_container = (quote_depth, list_indents[-1] if list_indents else 0)
            elif marker[0] == fence_character and len(marker) >= fence_length and not line[fence.end():].strip():
                fence_character = ""
            yield number, ""
        elif fence_character or line.startswith(("    ", "\t")):
            yield number, ""
        else:
            # Keep text inside inline code in headings for GitHub's slugs.
            yield number, line


def slug(text: str) -> str:
    text = html.unescape(re.sub(r"<[^>]*>", "", text)).lower()
    text = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = "".join(part if part.startswith("`") else re.sub(r"(?<!\w)(_+)(.+?)\1(?!\w)", r"\2", part)
                   for part in re.split(r"(`+[^`]*`+)", text))
    return "".join(c for c in text if c in "-_ " or unicodedata.category(c)[0] in "LNM").replace(" ", "-")


def anchors(text: str) -> set[str]:
    found: set[str] = set()
    previous = ""
    for _, line in prose_lines(text):
        for explicit in re.findall(r'<(?:a|h[1-6])\b[^>]*\b(?:id|name)=["\']([^"\']+)', line, re.I):
            found.add(html.unescape(explicit))
        heading = re.match(r"^ {0,3}#{1,6}\s+(.+?)\s*#*\s*$", line)
        title = heading[1] if heading else previous if re.fullmatch(r" {0,3}(?:=+|-+)\s*", line) and previous else None
        if title is not None:
            base = slug(title)
            candidate, suffix = base, 0
            while candidate in found:
                suffix += 1
                candidate = f"{base}-{suffix}"
            found.add(candidate)
        previous = line.strip()
    return found


def links(text: str):
    prose = "\n".join(line for _, line in prose_lines(text))
    # Preserve newlines so diagnostics still point to the original source.
    prose = "\n\n".join(re.sub(r"(`+).*?\1", lambda match: "\n" * match[0].count("\n"), paragraph, flags=re.S)
                         for paragraph in re.split(r"\n[ \t]*\n", prose))
    matches = [(match.start(), match[2].strip("<>")) for match in REFERENCE.finditer(prose)]
    matches += [(match.start(), match[1].strip("<>")) for match in INLINE_LINK.finditer(prose)]
    for offset, destination in sorted(matches):
        yield prose.count("\n", 0, offset) + 1, destination


def markdown_files(root: Path):
    for directory, children, filenames in os.walk(root):
        children[:] = sorted(child for child in children if child not in IGNORED_DIRECTORIES and not Path(directory, child).is_symlink())
        for name in sorted(filenames):
            if name.lower().endswith(".md"):
                yield Path(directory, name)


def check(root: Path) -> list[str]:
    root = root.resolve()
    if not root.is_dir():
        raise ValueError("repository root is not a directory")
    failures = []
    anchor_cache: dict[Path, set[str]] = {}
    for source in markdown_files(root):
        relative = source.relative_to(root).as_posix()
        historical = any(relative.startswith(directory + "/") for directory in HISTORICAL_DIRECTORIES) or bool(re.search(r"\d{4}-\d{2}-\d{2}", source.name))
        for number, destination in links(source.read_text(encoding="utf-8")):
            destination = re.sub(r"\\([() ])", r"\1", html.unescape(destination))
            parsed = urlsplit(destination)
            if parsed.scheme or parsed.netloc:
                continue
            path = unquote(parsed.path)
            target = (root / path.lstrip("/") if path.startswith("/") else source.parent / path).resolve() if path else source
            reason = None
            if not target.exists():
                reason = "Ziel fehlt"
            elif parsed.fragment and target.is_file() and target.suffix.lower() == ".md" and not historical:
                if target not in anchor_cache:
                    anchor_cache[target] = anchors(target.read_text(encoding="utf-8"))
                if unquote(parsed.fragment) not in anchor_cache[target]:
                    reason = "Überschriftenanker fehlt"
            if reason:
                failures.append(f"{relative}:{number}: {destination} → {reason}")
    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    try:
        failures = check(args.root)
    except (OSError, ValueError) as error:
        print(f"Linkprüfung fehlgeschlagen: {error}", file=sys.stderr)
        return 1
    print("\n".join(failures) if failures else "Alle lokalen Markdown-Links sind gültig.")
    return int(bool(failures))


if __name__ == "__main__":
    raise SystemExit(main())
