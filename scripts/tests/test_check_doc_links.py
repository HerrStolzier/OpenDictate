"""Protect local file/anchor validation using small, independent document trees."""

import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parents[1] / "check-doc-links.py"
SPEC = importlib.util.spec_from_file_location("check_doc_links", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class DocLinksTests(unittest.TestCase):
    def test_code_spans_stop_at_paragraphs_and_fences_at_container_end(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'README.md').write_text('''# `_private_method_`
[valid](#_private_method_)
A lone ` backtick.

[bad](missing.md)

Another lone ` backtick.

> ```md
> example

[bad](outside-quote.md)
''')
            self.assertEqual(MODULE.check(root), [
                'README.md:5: missing.md → Ziel fehlt',
                'README.md:12: outside-quote.md → Ziel fehlt',
            ])
            (root / 'README.md').write_text('A lone ` backtick.\n  \n[bad](missing.md)\n  \nAnother lone ` backtick.\n\n```\n> [literal](missing.md)\n```\n')
            self.assertEqual(MODULE.check(root), ['README.md:3: missing.md → Ziel fehlt'])
            (root / 'README.md').write_text('```\n- ```\n[example](missing.md)\n```\n')
            self.assertEqual(MODULE.check(root), [])

    def test_multiline_links_list_content_and_quoted_fences(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'README.md').write_text('''# _Start_
[valid](#start)
[bad](
missing.md
)
- Item

    [bad](list-missing.md)
> ```md
> [ignored](quoted-code.md)
> ```
''')
            errors = MODULE.check(root)
            self.assertEqual(errors, [
                'README.md:3: missing.md → Ziel fehlt',
                'README.md:8: list-missing.md → Ziel fehlt',
            ])
        self.assertEqual(MODULE.slug('_Start_ with snake_case'), 'start-with-snake_case')

    def test_github_slugs_unicode_duplicates_and_explicit_anchors(self):
        self.assertEqual(MODULE.anchors('# Grüße: `du`!\n# Grüße: `du`!\n# A\n# A\n# A-1\n<a id="custom"></a>\nTitel\n====='),
                         {"grüße-du", "grüße-du-1", "a", "a-1", "a-1-1", "custom", "titel"})

    def test_files_anchors_reference_links_and_ignored_code(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'Ziel ü.md').write_text('# Grüße!\n# Grüße!\n', encoding='utf-8')
            (root / 'folder').mkdir()
            (root / 'README.md').write_text('''# Start
[ok](<Ziel ü.md#grüße-1>) [encoded](Ziel%20%C3%BC.md#gr%C3%BC%C3%9Fe)
[folder](folder/) [self](#start) [web](https://example.invalid/missing)
[broken](absent.md) [bad anchor](Ziel%20ü.md#absent)
[ref]: absent-reference.md
`[ignored](inline.md)`
~~~markdown
[ignored](fenced.md)
~~~
    [ignored](indented.md)
''', encoding='utf-8')
            errors = MODULE.check(root)
            self.assertEqual(len(errors), 3, errors)
            self.assertTrue(any('README.md:4: absent.md → Ziel fehlt' in x for x in errors))
            self.assertTrue(any('Überschriftenanker fehlt' in x for x in errors))
            self.assertTrue(any('absent-reference.md' in x for x in errors))

    def test_cli_exit_code_excluded_build_and_historical_anchors(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / '.build').mkdir()
            (root / '.build' / 'README.md').write_text('[ignored](missing)')
            (root / 'README.md').write_text('# New\n')
            (root / 'old-2026-10-01.md').write_text('[old heading](README.md#old)')
            run = lambda: subprocess.run([sys.executable, str(SCRIPT), '--root', directory], text=True, capture_output=True)
            self.assertEqual(run().returncode, 0)
            (root / 'README.md').write_text('[bad](missing.md)')
            result = run()
            self.assertEqual(result.returncode, 1)
            self.assertIn('README.md:1: missing.md', result.stdout)


if __name__ == '__main__':
    unittest.main()
