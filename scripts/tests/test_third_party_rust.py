import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parents[1] / "third-party-rust.py"
SPEC = importlib.util.spec_from_file_location("third_party_rust", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

TREE = (
    "opendictate v0.1.0 (/src/linux)\tMIT\n"
    "cpal v0.18.2\tApache-2.0\n"
    "libc v0.2.190\tMIT OR Apache-2.0\n"
    "hex v0.4.3\tMIT OR Apache-2.0\n"
    "libc v0.2.190\tMIT OR Apache-2.0 (*)\n"
)


class ThirdPartyRustTests(unittest.TestCase):
    def test_parse_skips_own_crate_and_duplicates(self):
        self.assertEqual(MODULE.parse(TREE), [
            ("cpal", "0.18.2", "Apache-2.0"),
            ("hex", "0.4.3", "MIT OR Apache-2.0"),
            ("libc", "0.2.190", "MIT OR Apache-2.0"),
        ])

    def test_render_groups_by_license(self):
        section = MODULE.render(MODULE.parse(TREE))
        self.assertIn("- **MIT OR Apache-2.0:** hex 0.4.3, libc 0.2.190", section)
        self.assertTrue(section.startswith(MODULE.BEGIN) and section.endswith(MODULE.END))

    def test_notices_contain_the_section(self):
        text = MODULE.NOTICES.read_text(encoding="utf-8")
        self.assertEqual(MODULE.replace_section(text, MODULE.render([])).count(MODULE.BEGIN), 1)


if __name__ == "__main__":
    unittest.main()
