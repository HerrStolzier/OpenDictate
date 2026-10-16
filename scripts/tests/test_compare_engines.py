import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parents[1] / 'compare-engines.py'
SPEC = importlib.util.spec_from_file_location('compare_engines', SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class CompareEnginesTests(unittest.TestCase):
    def setUp(self):
        self.sentences = MODULE.catalogue({'sentences': [
            {'id': 'a', 'group': 'Zahlen', 'reference': 'Drei Äpfel.'},
            {'id': 'b', 'group': 'Alltag', 'reference': 'Grüße aus Köln'},
            {'id': 'c', 'group': 'Alltag', 'reference': 'Guten Tag'},
        ]})

    def run_row(self, engine='Apple', sentence='a', hypothesis='3 Äpfel!', duration=1, background=True):
        return dict(engine=engine, sentence_id=sentence, hypothesis=hypothesis, duration_seconds=duration, background=background)

    def test_weighted_wer_numbers_missing_groups_and_durations(self):
        result = MODULE.compare(self.sentences, [self.run_row(), self.run_row(sentence='b', hypothesis='GRÜSSE aus Bonn', duration=9, background=False), self.run_row(engine='OpenAI', hypothesis='drei Äpfel')])
        apple = result['engines']['Apple']
        self.assertEqual(apple['wer'], 2 / 5)
        self.assertEqual(apple['number_normalized_wer'], 1 / 5)
        self.assertEqual(apple['missing_sentences'], ['c'])
        self.assertEqual(apple['median_seconds'], 5)
        self.assertEqual(apple['p90_seconds'], 9)
        self.assertEqual(apple['background_fraction'], .5)
        self.assertEqual(apple['groups']['Zahlen']['wer'], .5)
        self.assertIsNone(result['engines']['OpenAI']['groups']['Alltag']['wer'])
        self.assertIn('40.0%', MODULE.markdown(result))

    def test_numeric_scope_and_unicode(self):
        self.assertEqual(MODULE.normalized_numbers(MODULE.EVALUATOR.tokens('Einundzwanzig zwölf neunundneunzig ein eine 03')), ['21', '12', '99', 'ein', 'eine', '3'])
        self.assertEqual(MODULE.normalized_numbers(MODULE.EVALUATOR.tokens('dreißig einunddreißig neununddreißig')), ['30', '31', '39'])

    def test_rejects_ambiguous_or_invalid_runs(self):
        for row in [self.run_row(sentence='unknown'), self.run_row(duration=-1), self.run_row(duration=True), self.run_row(duration=float('nan')), self.run_row(background=1), {'engine': 'Apple'}]:
            with self.subTest(row=row), self.assertRaises(ValueError):
                MODULE.compare(self.sentences, [row])
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            MODULE.compare(self.sentences, [self.run_row(), self.run_row()])
        with self.assertRaisesRegex(ValueError, 'no runs'):
            MODULE.compare(self.sentences, [])

    def test_cli_json_output_and_no_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            catalogue = root / 'sentences.json'
            catalogue.write_text(json.dumps({'sentences': list(self.sentences.values())}))
            runs, output = root / 'runs.jsonl', root / 'result.json'
            runs.write_text(json.dumps(self.run_row()) + '\n')
            command = [sys.executable, str(SCRIPT), str(runs), '--catalogue', str(catalogue), '--output', str(output)]
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('| Apple |', result.stdout)
            original = output.read_bytes()
            self.assertEqual(subprocess.run(command, capture_output=True).returncode, 2)
            self.assertEqual(output.read_bytes(), original)


if __name__ == '__main__':
    unittest.main()
