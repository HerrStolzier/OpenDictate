import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class SharedPricingTests(unittest.TestCase):
    def test_transcription_estimates_match_swift_model_identifiers(self):
        source = (ROOT / 'Sources/OpenDictateCore/TranscriptionModel.swift').read_text()
        names = dict(re.findall(r'public static let (\w+) = TranscriptionModel\(rawValue: "([^"]+)"\)', source))
        prices = {names[name]: float(value) for name, value in re.findall(r'case \.(\w+): return ([0-9.]+)', source)}
        table = json.loads((ROOT / 'fixtures/pricing/prices.json').read_text())
        self.assertEqual(table['transcription'], prices)
        self.assertEqual(table['currency'], 'USD')
        self.assertRegex(table['date'], r'^\d{4}-\d{2}-\d{2}$')
        self.assertTrue(table['source'].startswith('https://developers.openai.com/'))


if __name__ == '__main__':
    unittest.main()
