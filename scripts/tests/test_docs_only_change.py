import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parents[1] / "ci" / "docs-only-change.sh"


class DocsOnlyChangeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self.tmp.name)
        self.git("init", "-q")
        (self.repo / "README.md").write_text("start\n")
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "base")

    def tearDown(self):
        self.tmp.cleanup()

    def git(self, *args):
        subprocess.run(
            ["git", "-c", "user.name=t", "-c", "user.email=t@example.invalid", "-c", "commit.gpgsign=false", *args],
            cwd=self.repo, check=True, capture_output=True)

    def docs_only(self, *paths):
        for path in paths:
            target = self.repo / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(f"{path}\n")
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "change")
        result = subprocess.run(["bash", str(SCRIPT), "HEAD^1", "HEAD"], cwd=self.repo, check=True,
                                capture_output=True, text=True)
        return result.stdout.strip()

    def test_documentation_and_static_website_files_are_docs(self):
        self.assertEqual(self.docs_only(
            "PRIVACY.md", "docs/plan.json", "website/index.html", "website/style.css",
            "website/robots.txt", "website/sitemap.xml", "website/videos/a.vtt", "website/videos/a.mp4",
            "website/img/a.webp", "website/fonts/a.woff2", "website/README.md"), "docs_only=true")

    def test_website_code_and_configuration_run_full_checks(self):
        for path in ("website/worker.js", "website/site.js", "website/wrangler.toml", "website/tool.py",
                     "website/sub/x.mjs", "website/package.json"):
            with self.subTest(path=path):
                self.assertEqual(self.docs_only(path), "docs_only=false")

    def test_source_change_runs_full_checks(self):
        self.assertEqual(self.docs_only("docs/a.md", "Sources/a.swift"), "docs_only=false")

    def test_missing_arguments_run_full_checks(self):
        result = subprocess.run(["bash", str(SCRIPT)], cwd=self.repo, check=True, capture_output=True, text=True)
        self.assertEqual(result.stdout.strip(), "docs_only=false")


if __name__ == "__main__":
    unittest.main()
