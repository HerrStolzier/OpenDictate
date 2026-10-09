import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parents[1] / "design-tokens.py"
SPEC = importlib.util.spec_from_file_location("design_tokens", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class DesignTokensTests(unittest.TestCase):
    def test_generated_files_are_current(self):
        self.assertEqual(MODULE.main(["--check"]), 0)

    def test_source_gives_every_colour_every_theme(self):
        tokens = MODULE.load()
        ids = sorted(MODULE.themes(tokens))
        for token in tokens["color"]["tokens"]:
            if isinstance(token["value"], dict):
                self.assertEqual(sorted(token["value"]), ids, token["name"])

    def test_alias_resolves_to_target(self):
        colours = dict(MODULE.resolve_colors(MODULE.load()))
        self.assertEqual(colours["focus-ring"], colours["signal"])

    def test_rejects_missing_theme_and_duplicates(self):
        themes = [{"id": "a"}, {"id": "b"}]
        for entries in (
            [{"name": "x", "value": {"a": "#112233"}}],
            [{"name": "x", "value": "#112233"}],
            [{"name": "x", "value": {"a": "#112233", "b": "#112233"}}] * 2,
        ):
            with self.assertRaises(ValueError):
                MODULE.resolve_colors({"color": {"themes": themes, "tokens": entries}})

    def test_rejects_unknown_alias_and_bad_hex(self):
        for value in ("{missing}", "red", "#12345"):
            tokens = {"color": {"themes": [{"id": "a"}], "tokens": [{"name": "x", "value": value}]}}
            with self.assertRaises(ValueError):
                MODULE.resolve_colors(tokens)

    def test_rejects_alias_cycle(self):
        tokens = {
            "color": {
                "themes": [{"id": "a"}],
                "tokens": [{"name": "x", "value": "{y}"}, {"name": "y", "value": "{x}"}],
            }
        }
        with self.assertRaises(ValueError):
            MODULE.resolve_colors(tokens)

    def test_swift_lengths(self):
        self.assertEqual(MODULE.swift_number("18px"), "18.0")
        self.assertEqual(MODULE.swift_number("22.5%"), "0.225")
        with self.assertRaises(ValueError):
            MODULE.swift_number("0.02em")


if __name__ == "__main__":
    unittest.main()
