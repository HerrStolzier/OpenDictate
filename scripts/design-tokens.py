#!/usr/bin/env python3
"""Generate platform files from design/tokens.json.

design/tokens.json is a verbatim copy of the OpenDictate design system kept in
Claude Design. Every platform derives its values from the generated files
instead of hard-coding colours or sizes:

- design/generated/tokens.css: CSS custom properties (website, web dashboards)
- design/generated/gtk-colors.css: GTK @define-color entries (Waybar, GTK)
- design/generated/DesignTokens.swift: Swift values (macOS, later iOS)

Run without arguments to rewrite the files, or with --check to fail when they
are out of date.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOKENS = ROOT / "design" / "tokens.json"
OUT = ROOT / "design" / "generated"
HEADER = "Generated from design/tokens.json by scripts/design-tokens.py. Do not edit."
HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")
ALIAS = re.compile(r"^\{([A-Za-z0-9][A-Za-z0-9_.-]*)\}$")


def load(path: Path = TOKENS) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def themes(tokens: dict) -> list[str]:
    return [theme["id"] for theme in tokens["color"]["themes"]]


def resolve_colors(tokens: dict) -> list[tuple[str, dict[str, str]]]:
    """Return (name, {theme: #RRGGBB}) with aliases resolved and every theme filled."""
    ids = themes(tokens)
    raw: dict[str, object] = {}
    for token in tokens["color"]["tokens"]:
        if token["name"] in raw:
            raise ValueError(f"duplicate colour token: {token['name']}")
        raw[token["name"]] = token["value"]
    resolved: dict[str, dict[str, str]] = {}

    def resolve(name: str, seen: tuple[str, ...] = ()) -> dict[str, str]:
        if name in resolved:
            return resolved[name]
        if name in seen:
            raise ValueError(f"colour alias cycle: {' -> '.join(seen + (name,))}")
        if name not in raw:
            raise ValueError(f"unknown colour token: {name}")
        value = raw[name]
        if isinstance(value, str):
            match = ALIAS.match(value)
            if match:
                values = dict(resolve(match.group(1), seen + (name,)))
            elif len(ids) == 1:
                values = {ids[0]: value}
            else:
                raise ValueError(f"{name}: a plain value needs per-theme values")
        else:
            values = dict(value)
        if sorted(values) != sorted(ids):
            raise ValueError(f"{name}: themes {sorted(values)} do not match {sorted(ids)}")
        for theme, colour in values.items():
            if not HEX.match(colour):
                raise ValueError(f"{name}/{theme}: expected #RRGGBB, got {colour}")
        resolved[name] = {theme: values[theme].upper() for theme in ids}
        return resolved[name]

    return [(name, resolve(name)) for name in raw]


def length_tokens(tokens: dict) -> list[tuple[str, str]]:
    out = []
    for family in ("spacing", "radius", "pixel"):
        for token in tokens.get(family, {}).get("tokens", []):
            out.append((token["name"], token["value"]))
    return out


def text_styles(tokens: dict) -> list[dict]:
    styles = []
    for group in tokens["type"]["groups"]:
        for style in group["styles"]:
            styles.append({**style, "family": group["family"]})
    return styles


def css(tokens: dict) -> str:
    ids = themes(tokens)
    colours = resolve_colors(tokens)
    lines = [f"/* {HEADER} */", "", "/* Theme switch: set data-theme on <html>; Nacht is the default. */"]
    for index, theme in enumerate(ids):
        selector = f':root, [data-theme="{theme}"]' if index == 0 else f'[data-theme="{theme}"]'
        lines.append(selector + " {")
        lines += [f"  --{name}: {values[theme]};" for name, values in colours]
        for token in tokens.get("shadow", {}).get("tokens", []):
            value = token["value"]
            if isinstance(value, dict) and theme not in value:
                raise ValueError(f"{token['name']}: missing theme {theme}")
            lines.append(f"  --{token['name']}: {value[theme] if isinstance(value, dict) else value};")
        lines += ["}", ""]
    lines.append(":root {")
    for name, stack in tokens["type"]["families"].items():
        lines.append(f"  --font-{name}: {stack};")
    for name, value in length_tokens(tokens):
        lines.append(f"  --{name}: {value};")
    for style in text_styles(tokens):
        prefix = f"  --type-{style['name']}"
        lines.append(f"{prefix}-family: var(--font-{style['family']});")
        lines.append(f"{prefix}-size: {style['fontSize']};")
        lines.append(f"{prefix}-line: {style['lineHeight']};")
        lines.append(f"{prefix}-weight: {style['fontWeight']};")
        if "letterSpacing" in style:
            lines.append(f"{prefix}-tracking: {style['letterSpacing']};")
    lines.append("}")
    return "\n".join(lines) + "\n"


def gtk(tokens: dict) -> str:
    lines = [f"/* {HEADER} */", "/* Names: od_<token>_<theme>, e.g. @od_signal_nacht. */", ""]
    for name, values in resolve_colors(tokens):
        for theme, colour in values.items():
            lines.append(f"@define-color od_{name.replace('-', '_')}_{theme} {colour};")
    return "\n".join(lines) + "\n"


def camel(name: str) -> str:
    head, *rest = re.split(r"[-_.]", name)
    return head + "".join(part[:1].upper() + part[1:] for part in rest)


def swift_number(value: str) -> str:
    match = re.fullmatch(r"(-?\d+(?:\.\d+)?)(px|%)?", str(value))
    if not match:
        raise ValueError(f"unsupported length: {value}")
    number, unit = match.groups()
    if unit == "%":
        return repr(float(number) / 100)
    return repr(float(number))


def swift(tokens: dict) -> str:
    ids = themes(tokens)
    colours = resolve_colors(tokens)
    out = [f"// {HEADER}", "", "public enum DesignTheme: String, CaseIterable, Sendable {"]
    out += [f"  case {theme}" for theme in ids]
    out += ["}", "", "public enum DesignColor: String, CaseIterable, Sendable {"]
    out += [f'  case {camel(name)} = "{name}"' for name, _ in colours]
    out += ["", "  /// sRGB value as 0xRRGGBB.", "  public func rgb(in theme: DesignTheme) -> UInt32 {", "    switch (self, theme) {"]
    for name, values in colours:
        for theme in ids:
            out.append(f"    case (.{camel(name)}, .{theme}):")
            out.append(f"      return 0x{values[theme][1:]}")
    out += ["    }", "  }", "}", ""]
    out += ["/// Lengths in points; `radiusIcon` is a fraction of the icon size.", "public enum DesignMetric {"]
    for name, value in length_tokens(tokens):
        out.append(f"  public static let {camel(name)}: Double = {swift_number(value)}")
    out += ["}", ""]
    out += [
        "public struct DesignTextStyle: Equatable, Sendable {",
        "  public let family: String",
        "  public let size: Double",
        "  public let lineHeight: Double",
        "  public let weight: Int",
        "}",
        "",
        "public enum DesignFont {",
    ]
    for name, stack in tokens["type"]["families"].items():
        primary = stack.split(",")[0].strip().strip('"')
        out.append(f'  public static let {camel(name)} = "{primary}"')
    out.append("")
    for style in text_styles(tokens):
        out.append(
            f"  public static let {camel(style['name'])} = DesignTextStyle("
            f"family: {camel(style['family'])}, size: {swift_number(style['fontSize'])}, "
            f"lineHeight: {swift_number(style['lineHeight'])}, weight: {int(style['fontWeight'])})"
        )
    out.append("}")
    # Emit with the repository's swift-format indentation (4 spaces).
    out = [re.sub(r"^( +)", lambda m: " " * (len(m.group(1)) * 2), line) for line in out]
    return "\n".join(out) + "\n"


def render(tokens: dict) -> dict[str, str]:
    return {
        "tokens.css": css(tokens),
        "gtk-colors.css": gtk(tokens),
        "DesignTokens.swift": swift(tokens),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="fail if generated files are stale")
    args = parser.parse_args(argv)
    files = render(load())
    stale = []
    for name, content in files.items():
        path = OUT / name
        if args.check:
            if not path.exists() or path.read_text(encoding="utf-8") != content:
                stale.append(name)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
    if stale:
        print("stale: " + ", ".join(stale) + " (run scripts/design-tokens.py)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
