# Audio quality and latency evidence

The `AudioPipelineTests` generate synthetic tones and silence locally. They verify window boundaries, low levels, playable exports and reproducible phase timings. They contain no microphone recordings and make no provider calls. They do not measure speech-recognition accuracy, word error rate (WER), accents, proper nouns or user correction effort.

## Reproduce

Run `swift test` for ordinary checks. For measurements use a release build:

```sh
OPENDICTATE_BENCHMARK=1 OPENDICTATE_BENCHMARK_OUTPUT=/tmp/opendictate-audio.csv swift test -c release --filter AudioPipelineTests
```

On constrained agent hosts the macOS AAC codecs may require permission to run outside the agent sandbox. Do not treat codec unavailability as a passed or skipped audio test. The current tests use seven measurements of a synthetic 90-second mono 24 kHz / 48 kbit/s AAC file. Compare the same machine, power conditions, build and fixture. Exclude the first measurement when comparing warm medians, and keep raw data.

## Real speech corpus still required

A representative local corpus should include at least: short German words, quiet German sentences, sentence beginnings/endings, numbers and dates, personal and product names, English, German/English switches, background noise and microphone variants. Each case needs a consented audio file, exact reference transcript, duration, microphone, language and expected terms. Store these separately from the public repo unless explicitly licensed for distribution.

For each candidate report WER, number/name errors, unwanted added terms, correction time, time to first visible text and stop-to-final-text latency. Live uploads require explicit authorization; do not upload local recordings automatically during tests or CI. Model/keyword/streaming changes remain unproven for real speech until this evaluation is performed.

## Offline transcript evaluation

`scripts/evaluate-transcripts.py` calculates reproducible transcript metrics from
explicitly supplied references and results. It uses only the Python standard
library, reads no audio, makes no provider request and does not validate where a
transcript came from. Keep consented audio and private corpus data outside this
repository; commit neither them nor reports containing personal text.

The input is UTF-8 JSON. Each case needs a unique `id`, `reference` and
`hypothesis`. Optional `expected_terms`, `expected_names` and `expected_numbers`
are arrays of exact word sequences checked after Unicode normalization and
case-folding. An expected value consisting only of punctuation or symbols is
rejected because it has no comparable word token. Optional
`correction_time_seconds`, `time_to_first_text_seconds` and
`stop_to_final_text_seconds` are finite, non-negative numbers. Omit them or use
`null` when they were not measured; zero means a real measured zero. Non-standard
JSON values such as `NaN` and `Infinity` are rejected.

```json
{
  "cases": [
    {
      "id": "consented-case-01",
      "reference": "Treffen mit Müller am siebten Mai",
      "hypothesis": "Treffen mit Müller am siebten Mai",
      "expected_names": ["Müller"],
      "expected_numbers": ["siebten Mai"],
      "correction_time_seconds": 0,
      "time_to_first_text_seconds": null,
      "stop_to_final_text_seconds": 1.4
    }
  ]
}
```

Run it locally and keep input and report with the separately authorized corpus
evidence:

```sh
python3 scripts/evaluate-transcripts.py /path/to/consented-results.json \
  --output /path/to/evaluation-report.json
python3 -m unittest discover -s scripts/tests -p 'test_*.py'
```

`--output` refuses to replace any existing file, including the input corpus.
Choose a new report path or deliberately remove/archive an obsolete report
before rerunning the command. Without `--output`, the report is printed to
standard output.

The report includes substitution, deletion and insertion counts, per-case WER
and corpus WER (`total errors / total reference words`). It also reports missing
expected terms/names/numbers and coverage plus means for the optional timing and
correction fields. WER tokenization is punctuation-insensitive and uses Unicode
NFKC plus case-folding; it is a declared comparison policy, not a linguistic
judgment. An empty reference has no defined per-case WER. Missing timing values
remain distinct from measured zero values.

Inserted words are counted as WER insertions. Whether an inserted word is an
unwanted added term still requires review against the exact reference and the
recorded speech; this offline tool cannot infer speaker intent. Likewise, it
does not prove microphone quality, provider behavior, accent coverage or live
latency. Its provenance field explicitly labels results as supplied-transcript
evaluation rather than provider verification. Do not invent missing human
measurements to complete a report.
