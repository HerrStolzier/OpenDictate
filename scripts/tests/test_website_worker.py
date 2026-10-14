import importlib.util
import re
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

    def test_served_types_match_worker_kinds(self):
        source = MODULE.WORKER.read_text()
        block = re.search(r"^const KINDS = \{\n((?:.*\n)*?)\};$", source, re.M)
        assert block
        kinds = set(re.findall(r"^  (\w+):", block.group(1), re.M))
        self.assertEqual(kinds, MODULE.SERVED_TYPES)

    def test_worker_matches_pinned_commit(self):
        commit = MODULE.COMMIT_LINE.search(MODULE.WORKER.read_text()).group(1)
        shallow = MODULE.git("rev-parse", "--is-shallow-repository").decode().strip() == "true"
        if shallow:
            present = subprocess.run(
                ["git", "cat-file", "-e", f"{commit}^{{commit}}"], cwd=MODULE.ROOT, capture_output=True
            )
            if present.returncode != 0:
                self.skipTest(f"pinned commit {commit} is not in this shallow clone")
        else:
            # With full history the pin must be part of HEAD, e.g. on main after a squash merge.
            reachable = subprocess.run(
                ["git", "merge-base", "--is-ancestor", commit, "HEAD"], cwd=MODULE.ROOT, capture_output=True
            )
            self.assertEqual(reachable.returncode, 0, f"pinned commit {commit} is not in the history of HEAD")
        self.assertEqual(MODULE.main(["--check"]), 0)


if __name__ == "__main__":
    unittest.main()
