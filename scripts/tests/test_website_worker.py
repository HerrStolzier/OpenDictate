import importlib.util
import subprocess
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parents[1] / "website-worker.py"
SPEC = importlib.util.spec_from_file_location("website_worker", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

SAMPLE = '''const COMMIT = "{old}";
const FILES = {{
  "/index.html": "00000000000000000000000000000000",
}};

const HOST = "opendictate.app";
'''


class WebsiteWorkerTests(unittest.TestCase):
    def test_render_replaces_commit_and_files_only(self):
        source = SAMPLE.format(old="a" * 40)
        files = {"/index.html": "1" * 32, "/style.css": "2" * 32}
        rendered = MODULE.render(source, "b" * 40, files)
        self.assertIn(f'const COMMIT = "{"b" * 40}";', rendered)
        self.assertIn(f'  "/style.css": "{"2" * 32}",\n}};', rendered)
        self.assertNotIn("0" * 32, rendered)
        self.assertTrue(rendered.endswith('const HOST = "opendictate.app";\n'))

    def test_render_rejects_source_without_markers(self):
        with self.assertRaises(ValueError):
            MODULE.render("export default {};\n", "b" * 40, {"/index.html": "1" * 32})

    def test_digest_is_sha256_prefix(self):
        self.assertEqual(MODULE.digest(b""), "e3b0c44298fc1c149afbf4c8996fb924")

    def test_worker_matches_pinned_commit(self):
        commit = MODULE.COMMIT_LINE.search(MODULE.WORKER.read_text()).group(1)
        present = subprocess.run(
            ["git", "cat-file", "-e", f"{commit}^{{commit}}"], cwd=MODULE.ROOT, capture_output=True
        )
        if present.returncode != 0:
            self.skipTest(f"pinned commit {commit} is not in this clone's history")
        self.assertEqual(MODULE.main(["--check"]), 0)


if __name__ == "__main__":
    unittest.main()
