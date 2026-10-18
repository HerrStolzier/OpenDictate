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

    def test_blink_stays_green_in_app_themes(self):
        # Nacht and Papier are the themes the apps show; Bernstein is the
        # amber alternative. Papier once made Blink blue and no check noticed.
        colours = dict(MODULE.resolve_colors(MODULE.load()))
        for name in ("signal", "signal-light", "signal-shade", "signal-deep", "signal-ink"):
            for theme in ("nacht", "papier"):
                red, green, blue = (int(colours[name][theme][i : i + 2], 16) for i in (1, 3, 5))
                self.assertGreater(green, max(red, blue), f"{name} in {theme}")

    def test_signal_keeps_its_contrast(self):
        colours = dict(MODULE.resolve_colors(MODULE.load()))

        def luminance(hex_value: str) -> float:
            channels = [int(hex_value[i : i + 2], 16) / 255 for i in (1, 3, 5)]
            linear = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
            return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]

        def ratio(a: str, b: str) -> float:
            high, low = sorted((luminance(a), luminance(b)), reverse=True)
            return (high + 0.05) / (low + 0.05)

        for theme in MODULE.themes(MODULE.load()):
            signal = colours["signal"][theme]
            for surface in ("bg", "surface", "surface-sunken"):
                self.assertGreaterEqual(ratio(signal, colours[surface][theme]), 5, f"signal on {surface} in {theme}")
            self.assertGreaterEqual(ratio(colours["on-signal"][theme], signal), 6.4, f"on-signal in {theme}")

    def test_waybar_example_uses_token_colours(self):
        css = (Path(__file__).parents[2] / "linux" / "waybar.example.css").read_text()
        colours = dict(MODULE.resolve_colors(MODULE.load()))
        for name in ("rec", "signal"):
            self.assertIn(f"@define-color od_{name} {colours[name]['nacht']};", css)
            self.assertIn(colours[name]["papier"], css)

    def test_swift_lengths(self):
        self.assertEqual(MODULE.swift_number("18px"), "18.0")
        self.assertEqual(MODULE.swift_number("22.5%"), "0.225")
        with self.assertRaises(ValueError):
            MODULE.swift_number("0.02em")
        self.assertEqual(MODULE.swift_em("-0.01em"), "-0.01")
        with self.assertRaises(ValueError):
            MODULE.swift_em("1px")


if __name__ == "__main__":
    unittest.main()
