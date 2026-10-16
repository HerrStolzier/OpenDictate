import importlib.util
import json
import re
import unittest
from unittest import mock

from pathlib import Path

SCRIPT = Path(__file__).parents[1] / "website-i18n.py"
SPEC = importlib.util.spec_from_file_location("website_i18n", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class WebsiteI18nTests(unittest.TestCase):
    def test_generated_files_are_current(self):
        self.assertEqual(MODULE.main(["--check"]), 0)

    def test_product_name_comes_only_from_site_json(self):
        real = MODULE.load

        def renamed(name):
            data = real(name)
            if name == "site.json":
                data = {**data, "name": "Testname", "wordmark": "testname"}
            return data

        with mock.patch.object(MODULE, "load", renamed):
            built = MODULE.build()
        for path, body in built.items():
            # The repository and its download links keep their own name.
            rest = re.sub(r"github\.com/HerrStolzier/OpenDictate", "", body)
            self.assertNotIn("OpenDictate", rest, path.name)
            self.assertNotIn("opendictate<", rest, path.name)
        self.assertIn("Testname", built[MODULE.WEBSITE / "en" / "index.html"])

    def test_every_page_links_all_languages(self):
        site = MODULE.load("site.json")
        built = MODULE.build()
        index = built[MODULE.WEBSITE / "index.html"]
        for lang in site["languages"]:
            self.assertIn(f'hreflang="{lang["code"]}"', index)
        self.assertIn('hreflang="x-default"', index)

    def test_language_menu_name_starts_with_visible_code(self):
        built = MODULE.build()
        for path, body in built.items():
            if path.suffix != ".html":
                continue
            summary = re.search(r'<summary aria-label="([^"]+)">([A-Z]{2})</summary>', body)
            self.assertIsNotNone(summary, path.name)
            self.assertTrue(summary.group(1).startswith(summary.group(2) + ", "), path.name)

    def test_home_player_chapters_carry_page_language_captions(self):
        built = MODULE.build()
        for code, path in (("de", MODULE.WEBSITE / "index.html"), ("fr", MODULE.WEBSITE / "fr" / "index.html")):
            captions = re.findall(r'data-captions="([^"]+)"', built[path])
            self.assertEqual(len(captions), 5, code)
            for src in captions:
                self.assertTrue((MODULE.WEBSITE / src.lstrip("/")).exists(), src)
                self.assertEqual(src.endswith(f".{code}.vtt"), code != "de", src)

    def test_subtitles_keep_german_cue_times(self):
        built = MODULE.build()
        german = (MODULE.WEBSITE / "videos" / "blink-01-so-diktierst-du.vtt").read_text()
        english = built[MODULE.WEBSITE / "videos" / "blink-01-so-diktierst-du.en.vtt"]
        times = re.compile(r"^\d\d:\d\d:\d\d\.\d{3} --> .+$", re.M)
        self.assertEqual(times.findall(german), times.findall(english))

    def test_missing_text_fails(self):
        real = MODULE.load

        def broken(name):
            data = real(name)
            if name == "en.json":
                data = {key: value for key, value in data.items() if key != "title"}
            return data

        with mock.patch.object(MODULE, "load", broken), self.assertRaises(ValueError):
            MODULE.build()

    def test_renamed_page_counts_as_stale(self):
        expected = MODULE.build()
        orphan = MODULE.WEBSITE / "en" / "renamed-test-page.html"
        orphan.write_text("old")
        try:
            self.assertIn(orphan, MODULE.stale(expected))
            self.assertEqual(MODULE.main(["--check"]), 1)
        finally:
            orphan.unlink()

    def test_renamed_root_page_counts_as_stale(self):
        expected = MODULE.build()
        orphan = MODULE.WEBSITE / "renamed-test-page.html"
        orphan.write_text("old")
        try:
            self.assertIn(orphan, MODULE.stale(expected))
        finally:
            orphan.unlink()

    def test_straight_quotes_in_plain_text_fail(self):
        real = MODULE.load

        def quoted(name):
            data = real(name)
            if name == "en.json":
                data = {**data, "title": 'A "quoted" title'}
            return data

        with mock.patch.object(MODULE, "load", quoted), self.assertRaises(ValueError):
            MODULE.build()

    def test_json_filter_escapes_quotes(self):
        site = MODULE.load("site.json")
        texts = {"de": {"x": 'Ein "Zitat"'}}
        page = MODULE.Page(site, texts, site["languages"][0], "index")
        self.assertEqual(json.loads('"' + page.resolve("{{x|json}}") + '"'), 'Ein "Zitat"')


if __name__ == "__main__":
    unittest.main()
