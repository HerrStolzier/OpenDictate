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


BLOB = "1" * 40
FP = MODULE.fingerprint([("Sources/OpenDictate/AppDelegate.swift", BLOB)])
STAMP = f"Verified-by: pruefer patch={FP} fehler=1/1"


def evaluate(files, message=f"x\n\n{STAMP}", patch=None):
    commits = [{"sha": "a" * 40, "message": message, "parents": ["b" * 40], "files": files, "patch": patch}]
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


class VerifiedByTests(unittest.TestCase):
    CODE = ["Sources/OpenDictate/AppDelegate.swift"]

    def test_code_commit_without_the_line_blocks(self):
        # Wenn ein Code-Commit keine Zeile Verified-by hat, dann wartet der Merge auf eine Prüfung.
        self.assertEqual(evaluate(self.CODE, message="x"), ("block", "review:aaaaaaa"))

    def test_old_reviewed_by_line_no_longer_counts(self):
        self.assertEqual(evaluate(self.CODE, message="x\n\nReviewed-by: critic"), ("block", "review:aaaaaaa"))

    def test_stamp_must_match_the_change(self):
        self.assertEqual(evaluate(self.CODE, patch=FP)[0], "merge")
        self.assertEqual(evaluate(self.CODE, patch="ffffffffffff"), ("block", "review:aaaaaaa(veraltet)"))

    def test_latest_stamp_line_counts(self):
        stale = "Verified-by: pruefer patch=ffffffffffff fehler=1/1"
        self.assertEqual(evaluate(self.CODE, message=f"x\n\n{stale}\n{STAMP}", patch=FP)[0], "merge")
        self.assertEqual(evaluate(self.CODE, message=f"x\n\n{STAMP}\n{stale}", patch=FP),
                         ("block", "review:aaaaaaa(veraltet)"))

    def test_text_only_commit_needs_no_line(self):
        self.assertEqual(evaluate(["README.md"], message="x"), ("merge", "alles grün"))


if __name__ == "__main__":
    unittest.main()
