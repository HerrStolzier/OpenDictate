#!/usr/bin/env python3
"""Build the website pages in every language from website/i18n/.

`python3 scripts/website-i18n.py` writes the pages of each language listed in
website/i18n/site.json, their subtitles and the sitemap. `--check` fails when a
generated file is missing, out of date or left over from a removed language or a renamed page.

Templates in website/i18n/pages/ use `{{key}}` for a text of the page language,
`{{de.key}}` for the German text, `{{site.key}}` for a value from site.json
(product name, addresses) and `{{@key}}` for values computed per page. Texts may
contain placeholders themselves, so the product name lives only in site.json.
`|json` escapes the result for a JSON string.
"""

import argparse
import html
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEBSITE = ROOT / "website"
SOURCE = WEBSITE / "i18n"
PLACEHOLDER = re.compile(r"\{\{([@\w.]+)(\|json)?\}\}")
VTT_CUE = re.compile(r"^(\d\d:\d\d:\d\d\.\d{3} --> \d\d:\d\d:\d\d\.\d{3})\n(.+?)(?:\n\n|\n?$)", re.M | re.S)
SUBTITLE = re.compile(r"^blink-.+\.([a-z]{2})\.vtt$")


def load(name: str) -> dict:
    return json.loads((SOURCE / name).read_text())


class Page:
    def __init__(self, site: dict, texts: dict, lang: dict, template: str):
        self.site = site
        self.texts = texts
        self.lang = lang
        self.template = template

    @property
    def path(self) -> str:
        return self.path_for(self.lang)

    def path_for(self, lang: dict) -> str:
        home = f"/{lang['dir']}/" if lang["dir"] else "/"
        return home if self.template == "index" else home + lang["guides"]

    def computed(self, key: str) -> str:
        site, lang = self.site, self.lang
        code = lang["code"]
        home = f"/{lang['dir']}/" if lang["dir"] else "/"
        if key == "lang":
            return code
        if key == "label":
            return lang["label"]
        if key == "locale":
            return lang["locale"]
        if key == "home":
            return home
        if key == "guides":
            return home + lang["guides"]
        if key == "url":
            return site["origin"] + self.path
        if key == "vtt":
            return "" if code == "de" else f".{code}"
        if key == "track_default":
            return "" if code == "de" else " default"
        if key == "alternates":
            links = [
                f'<link rel="alternate" hreflang="{other["code"]}" href="{site["origin"]}{self.path_for(other)}">'
                for other in site["languages"]
            ]
            fallback = next(other for other in site["languages"] if other["code"] == site["x_default"])
            links.append(f'<link rel="alternate" hreflang="x-default" href="{site["origin"]}{self.path_for(fallback)}">')
            return "\n".join(links)
        if key == "locale_alternates":
            return "\n".join(
                f'<meta property="og:locale:alternate" content="{other["locale"]}">'
                for other in site["languages"]
                if other is not lang
            )
        if key == "switch":
            items = "\n".join(
                f'<li><a href="{self.path_for(other)}" hreflang="{other["code"]}" lang="{other["code"]}"'
                + (' aria-current="true"' if other is lang else "")
                + f">{other['label']}</a></li>"
                for other in site["languages"]
            )
            label = self.resolve(f"{{{{lang_label}}}}: {lang['label']}")
            return (
                f'<details class="lang">\n<summary aria-label="{html.escape(label)}">{code.upper()}</summary>\n'
                f'<ul class="lang-list">\n{items}\n</ul>\n</details>'
            )
        if key == "text":
            text = {
                "wordmark": site["wordmark"],
                "video": self.text("js_video"),
                "play": self.text("js_play"),
                "pause": self.text("js_pause"),
                "meter": self.text("js_meter"),
                "blink": {
                    state: self.text(f"js_blink_{name}")
                    for state, name in (
                        ("bereit", "ready"),
                        ("hoert", "listening"),
                        ("schreibt", "writing"),
                        ("eingefuegt", "pasted"),
                        ("hoppla", "oops"),
                    )
                },
                "hud": {
                    "bereit": {"word": self.text("hud_ready"), "sub": self.text("hud_ready_sub")},
                    "hoert": {"word": self.text("hud_listening"), "sub": "REC 0:0"},
                    "schreibt": {"word": self.text("hud_writing"), "sub": self.text("hud_writing_sub")},
                    "eingefuegt": {"word": self.text("hud_pasted"), "sub": self.text("hud_pasted_sub")},
                    "hoppla": {"word": self.text("hud_oops"), "sub": self.text("hud_oops_sub")},
                },
            }
            return json.dumps(text, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
        if key == "footer":
            return self.resolve((SOURCE / "pages" / "_footer.html").read_text().rstrip("\n"))
        raise ValueError(f"unknown computed value @{key}")

    def text(self, key: str) -> str:
        return self.resolve(self.lookup(key))

    def lookup(self, key: str) -> str:
        if key.startswith("site."):
            value = self.site.get(key[5:])
        elif key.startswith("de."):
            value = self.texts["de"].get(key[3:])
        else:
            value = self.texts[self.lang["code"]].get(key)
        if not isinstance(value, str):
            raise ValueError(f"{self.lang['code']}: no text for {{{{{key}}}}}")
        return value

    def resolve(self, source: str, depth: int = 0) -> str:
        if depth > 4:
            raise ValueError(f"placeholders nest too deep in {source[:60]!r}")

        def replace(match: re.Match) -> str:
            key, as_json = match.group(1), match.group(2)
            if key.startswith("@"):
                value = self.computed(key[1:])
            else:
                value = self.resolve(self.lookup(key), depth + 1)
            return json.dumps(value, ensure_ascii=False)[1:-1].replace("</", "<\\/") if as_json else value

        return PLACEHOLDER.sub(replace, source)

    def render(self) -> str:
        return self.resolve((SOURCE / "pages" / f"{self.template}.html").read_text())


def subtitles(lang: str, texts: dict) -> dict[Path, str]:
    """Subtitles for `lang` with the cue times of the German tracks."""
    out = {}
    for german in sorted((WEBSITE / "videos").glob("blink-*.vtt")):
        if SUBTITLE.match(german.name):
            continue
        times = [cue.group(1) for cue in VTT_CUE.finditer(german.read_text().split("\n", 2)[2])]
        lines = texts.get("vtt", {}).get(german.stem)
        if not lines or len(lines) != len(times):
            raise ValueError(f"{lang}: vtt {german.stem} needs {len(times)} cues")
        body = "\n\n".join(f"{time}\n{line}" for time, line in zip(times, lines))
        out[german.with_name(f"{german.stem}.{lang}.vtt")] = f"WEBVTT\n\n{body}\n"
    return out


def sitemap(site: dict, pages: list[Page]) -> str:
    entries = []
    for page in pages:
        siblings = [other for other in pages if other.template == page.template]
        links = "".join(
            f'    <xhtml:link rel="alternate" hreflang="{other.lang["code"]}" href="{site["origin"]}{other.path}"/>\n'
            for other in siblings
        )
        entries.append(f"  <url>\n    <loc>{site['origin']}{page.path}</loc>\n{links}  </url>\n")
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n'
        + "".join(entries)
        + "</urlset>\n"
    )


def build() -> dict[Path, str]:
    site = load("site.json")
    texts = {lang["code"]: load(f"{lang['code']}.json") for lang in site["languages"]}
    keys = set(texts["de"]) - {"vtt"}
    for code, strings in texts.items():
        missing, extra = keys - set(strings), set(strings) - keys - {"vtt"}
        if missing or extra:
            raise ValueError(f"{code}.json differs from de.json: missing {sorted(missing)}, extra {sorted(extra)}")
    for code, strings in texts.items():
        # Texts also go into HTML attributes; only texts that carry a link may hold quotes.
        quoted = [key for key, value in strings.items() if isinstance(value, str) and '"' in value and "<a " not in value]
        if quoted:
            raise ValueError(f"{code}.json: use typographic quotes in {sorted(quoted)}")
    pages = [Page(site, texts, lang, template) for template in ("index", "anleitungen") for lang in site["languages"]]
    out = {}
    for page in pages:
        file = page.path + "index.html" if page.path.endswith("/") else page.path
        out[WEBSITE / file.lstrip("/")] = page.render()
    for lang in site["languages"]:
        if lang["code"] != "de":
            out.update(subtitles(lang["code"], texts[lang["code"]]))
    out[WEBSITE / "sitemap.xml"] = sitemap(site, pages)
    return out


def stale(expected: dict[Path, str]) -> list[Path]:
    """Generated files that no current language produces any more."""
    found = [path for path in (WEBSITE / "videos").glob("blink-*.vtt") if SUBTITLE.match(path.name)]
    # Every HTML page in the site root comes from a template, also after a renamed German page.
    found += list(WEBSITE.glob("*.html"))
    # Language folders have two-letter names; any file there that no page produces is stale,
    # also after a renamed page inside a language that is still listed.
    found += [path for child in WEBSITE.iterdir() if child.is_dir() and len(child.name) == 2
              for path in child.rglob("*") if path.is_file()]
    return [path for path in found if path not in expected]


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="verify the generated files instead of writing them")
    args = parser.parse_args(argv)
    try:
        expected = build()
    except (ValueError, KeyError, json.JSONDecodeError) as error:
        print(f"website-i18n: {error}", file=sys.stderr)
        return 1
    leftovers = stale(expected)
    if args.check:
        wrong = [path for path, body in expected.items() if not path.exists() or path.read_text() != body]
        for path in wrong + leftovers:
            print(f"website-i18n: {path.relative_to(ROOT)} is out of date", file=sys.stderr)
        if wrong or leftovers:
            print("run `python3 scripts/website-i18n.py`", file=sys.stderr)
            return 1
        return 0
    for path, body in expected.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        if not path.exists() or path.read_text() != body:
            path.write_text(body)
    for path in leftovers:
        path.unlink()
        if path.parent != WEBSITE / "videos" and not any(path.parent.iterdir()):
            path.parent.rmdir()
    print(f"website-i18n: {len(expected)} files up to date")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
