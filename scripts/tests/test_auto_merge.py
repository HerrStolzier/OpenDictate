import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parents[2] / ".github" / "scripts" / "auto_merge.py"
SPEC = importlib.util.spec_from_file_location("auto_merge", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

OWNER = "owner"
REPO = {"full_name": "owner/repo"}
PR = {"state": "open", "draft": False, "user": {"login": OWNER}, "mergeable": True,
      "head": {"repo": REPO}, "base": {"repo": REPO, "ref": "main"}}
GREEN = [{"id": 1, "name": "test", "status": "completed", "conclusion": "success", "check_suite": {"id": 1}}]


def evaluate(files):
    commits = [{"sha": "a" * 40, "message": "x\n\nReviewed-by: critic", "parents": ["b" * 40], "files": files}]
    return MODULE.evaluate(PR, OWNER, "main", commits, files, GREEN, {"state": "success", "total_count": 0}, 0)


class GuardedTests(unittest.TestCase):
    def test_rules_and_checks_are_guarded(self):
        for path in (
            ".github/workflows/checks.yml",
            ".github/scripts/auto_merge.py",
            ".github/dependabot.yml",
            "scripts/ci/scan-secrets.sh",
            ".claude/hooks/review-gate.py",
            ".claude/settings.json",
            "CLAUDE.md",
            "AGENTS.md",
            ".gitleaksignore",
            ".gitattributes",
        ):
            with self.subTest(path=path):
                self.assertTrue(MODULE.guarded(path))

    def test_ordinary_paths_are_not_guarded(self):
        for path in (
            "Sources/OpenDictate/AppDelegate.swift",
            "scripts/build-app.sh",
            "scripts/tests/test_auto_merge.py",
            "docs/CLAUDE.md",
            "linux/AGENTS.md",
            "README.md",
            ".gitignore",
            "github/workflows/x.yml",
        ):
            with self.subTest(path=path):
                self.assertFalse(MODULE.guarded(path))

    def test_guarded_change_blocks_merge(self):
        self.assertEqual(evaluate(["scripts/ci/docs-only-change.sh"]), ("block", "workflow"))
        self.assertEqual(evaluate([".gitleaksignore"]), ("block", "workflow"))

    def test_ordinary_change_merges(self):
        self.assertEqual(evaluate(["Sources/OpenDictate/AppDelegate.swift"]), ("merge", "alles grün"))


if __name__ == "__main__":
    unittest.main()
