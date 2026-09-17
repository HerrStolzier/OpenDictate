import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parents[1] / "evaluate-transcripts.py"
SPEC = importlib.util.spec_from_file_location("evaluate_transcripts", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class EvaluateTranscriptsTests(unittest.TestCase):
    def test_edit_counts_and_unicode(self):
        report = MODULE.evaluate({"cases": [
            {"id": "sub", "reference": "eins zwei", "hypothesis": "eins drei"},
            {"id": "del", "reference": "eins zwei", "hypothesis": "eins"},
            {"id": "ins", "reference": "eins", "hypothesis": "eins extra"},
            {"id": "unicode", "reference": "Grüße Café sieben", "hypothesis": "GRÜSSE Cafe\u0301 sieben",
             "expected_terms": ["Café"], "expected_names": ["Grüße"], "expected_numbers": ["sieben"]},
        ]})
        self.assertEqual(report["aggregate"]["substitutions"], 1)
        self.assertEqual(report["aggregate"]["deletions"], 1)
        self.assertEqual(report["aggregate"]["insertions"], 1)
        self.assertEqual(report["cases"][3]["wer"], 0)
        self.assertEqual(report["aggregate"]["expected_names"]["missing"], 0)

    def test_missing_measurement_differs_from_zero(self):
        report = MODULE.evaluate({"cases": [
            {"id": "measured", "reference": "ok", "hypothesis": "ok", "correction_time_seconds": 0},
            {"id": "missing", "reference": "ok", "hypothesis": "ok"},
        ]})
        self.assertEqual(report["aggregate"]["measurements"]["correction_time_seconds"],
                         {"reported_cases": 1, "missing_cases": 1, "mean": 0.0})

    def test_rejects_invalid_measurement(self):
        with self.assertRaisesRegex(ValueError, "finite non-negative"):
            MODULE.evaluate({"cases": [
                {"id": "bad", "reference": "ok", "hypothesis": "ok", "correction_time_seconds": -1}
            ]})

        for value in (float("nan"), float("inf"), float("-inf")):
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, "finite non-negative"):
                MODULE.evaluate({"cases": [
                    {"id": "bad", "reference": "ok", "hypothesis": "ok", "correction_time_seconds": value}
                ]})

    def test_rejects_expected_value_without_word_tokens(self):
        with self.assertRaisesRegex(ValueError, "contains no word tokens"):
            MODULE.evaluate({"cases": [
                {"id": "bad", "reference": "ok", "hypothesis": "ok", "expected_terms": ["…?!"]}
            ]})

    def test_cli_rejects_nonfinite_json_and_never_overwrites(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            corpus = root / "corpus.json"
            corpus.write_text('{"cases":[{"id":"bad","reference":"ok","hypothesis":"ok","correction_time_seconds":NaN}]}', encoding="utf-8")
            result = subprocess.run([sys.executable, str(SCRIPT), str(corpus)], capture_output=True, text=True, check=False)
            self.assertEqual(result.returncode, 2)
            self.assertIn("non-finite JSON number", result.stderr)

            valid = json.dumps({"cases": [{"id": "ok", "reference": "ok", "hypothesis": "ok"}]})
            corpus.write_text(valid, encoding="utf-8")
            report = root / "report.json"
            report.write_text("keep me", encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(SCRIPT), str(corpus), "--output", str(report)],
                capture_output=True, text=True, check=False,
            )
            self.assertEqual(result.returncode, 2)
            self.assertEqual(report.read_text(encoding="utf-8"), "keep me")
            self.assertEqual(corpus.read_text(encoding="utf-8"), valid)

            result = subprocess.run(
                [sys.executable, str(SCRIPT), str(corpus), "--output", str(corpus)],
                capture_output=True, text=True, check=False,
            )
            self.assertEqual(result.returncode, 2)
            self.assertEqual(corpus.read_text(encoding="utf-8"), valid)


if __name__ == "__main__":
    unittest.main()
