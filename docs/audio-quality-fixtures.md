# Audio quality and latency evidence

The `AudioPipelineTests` generate synthetic tones and silence locally. They verify window boundaries, low levels, playable exports and reproducible phase timings. They contain no microphone recordings and make no provider calls. They do not measure speech-recognition accuracy, word error rate (WER), accents, proper nouns or user correction effort.

## Reproduce

Run `swift test -Xswiftc -warnings-as-errors` for ordinary checks. For measurements use a release build:

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

## Prepared first human pilot

Status: prepared, not executed. Start with these twelve short cases on one
identified candidate and a fixed model. Speak through the real microphone and
use the physical shortcut for start/stop. Use disposable documents and fictional
content. These written prompts are not human recordings or measured results.
Audio and completed private reports remain outside the public repository.

| Case | Task | Check deliberately |
|---|---|---|
| H01 | Dictate a short greeting and a two-sentence message | Normal speaking pace and sentence boundaries |
| H02 | Dictate a short note into the middle of an existing sentence | Preserve surrounding text |
| H03 | Replace a selected phrase with a dictated correction | Replace only the selection |
| H04 | Say “Der Termin ist am siebten Mai um vierzehn Uhr dreißig.” | Date and time; record equivalent numeric formatting separately |
| H05 | Say “Bitte lege zwölf Schrauben und drei Muttern bereit.” | Numbers and their intended meaning |
| H06 | Say “Müller und Schuster prüfen OpenDictate.” | Fictional names and the product name |
| H07 | Dictate a short list over several sentences | Punctuation and editing effort |
| H08 | Say a short sentence quietly at a normal microphone distance | Retention/manual retry if the heuristic skips it |
| H09 | Speak a sentence with a natural hesitation or self-correction | Whether the resulting text reflects the intended message |
| H10 | Dictate one short English message with automatic language selection | Language handling |
| H11 | Dictate a German sentence containing “Pull Request” and “Code Review” | Language switch and technical terms |
| H12 | Formulate a new two- or three-sentence note without reading a script | Natural speech and total correction effort |

Select representative native, Safari, Brave and Electron fields from the
[compatibility matrix](compatibility-matrix.md); the pilot is early feedback,
not a replacement for product-wide coverage. First complete a focused visible
normal/partial-input check for the candidate. Existing `--matrix-fixture` tools
can isolate input without using the microphone or provider. Actual initial key
setup additionally needs a deliberately prepared fresh user/device state.

For each case record: candidate source/executable identity, macOS/app versions,
model/language, microphone, case ID, actual spoken reference, returned transcript,
visible target result, any manual fallback, stop-to-complete-text time, correction
time and total time from recording start to usable text. Record missing values
as missing. For a few comparable tasks, record manual typing time as an
orientation baseline. Use the evaluator above for supplied reference/transcript
metrics; inspect meaning and target-field correctness separately.

Fix the request count and total audio-duration limit before executing the pilot;
there are no automatic retries. Historical microphone/provider budgets are
already consumed and are not reused. The outcomes are individual observations
and a prioritized list of causes, not a population success rate or model ranking.
If text reaches an unintended target, existing text is damaged or the only copy
is lost, pause that automatic path and investigate before expanding the pilot.

## Bounded integration follow-up

A first round contains one deliberately prepared observation for each of the
following cases; repeat only to investigate a concrete result within the agreed
attempt limit. Capture before/after target state and the actual focus transition.
A transition that never occurred is an invalid attempt, not a pass or a product
failure.

- Change app during recording and during processing, including return to the
  original app. Check the full manual transcript and both possible destinations.
- Change field/tab/window during delayed processing; interrupt between Unicode
  chunks and check both the partial-input message and complete copyable text.
- Move the caret or select text inside the same field between chunks. This is an
  unresolved interaction case; input's own caret movement currently prevents
  comparing every chunk with the original selection.
- Cancel or quit during recording and during upload; inspect recovery and text
  according to the existing cleanup rules, including explicit discard separately.
- Change or unplug an external microphone using a disposable recording.
- Repeat the specific Safari textarea preflight/fallback case with recorded
  window, field and selection conditions. A later success alone leaves its
  earlier unexplained cause open.

Keep results for native AX, Safari, Brave and Obsidian event policies scoped to
the exact tested combinations. Heard VoiceOver and macOS 14 runtime checks remain
separate outstanding checks. Current limitations and the next action belong in
[remaining acceptance](remaining-acceptance.md), with dated evidence linked there.

## Erkennungen auf dem iPhone vergleichen

Der feste, selbst geschriebene Satzkatalog liegt unter
[`scripts/fixtures/german-dictation-sentences.json`](../scripts/fixtures/german-dictation-sentences.json)
(CC0, 36 Sätze in sechs Gruppen). Jede Erkennung bekommt dieselben Sätze.
Die Gruppe „Satzzeichen“ enthält die erwartete Schriftsprache; die sprechende
Person spricht passende Pausen. Gesprochene Befehle wie „Komma“ sind kein
vereinheitlichter Erkennungsvertrag und gehören bei Bedarf in einen eigenen Lauf.

Eine JSON-Lines-Datei enthält einen Durchlauf, höchstens ein Ergebnis je
Erkennung und Satz-ID:

```json
{"engine":"OpenAI","sentence_id":"zahlen-01","hypothesis":"Wir brauchen 3 Äpfel und 12 Eier.","duration_seconds":2.4,"background":true}
```

`duration_seconds` ist eine gemessene, endliche, nicht negative Dauer in
Sekunden vom Aufnahmeende bis zum fertigen Text. `background` beschreibt,
ob die App während der Verarbeitung im Hintergrund war. Gerät, App-Build,
Modell und Messmethode gehören in die begleitende Nachweisnotiz. Wiederholte
Durchläufe werden in getrennten Dateien ausgewertet; doppelte Paare werden
abgelehnt. Leere Hypothesen sind gültig und zählen als ausgelassene Wörter.

```bash
python3 scripts/compare-engines.py /path/to/runs.jsonl --output /path/to/new-comparison.json
```

Das Skript druckt eine Markdown-Tabelle und schreibt auf Wunsch eine neue
JSON-Datei. Vorhandene Dateien werden nicht überschrieben. Die Wortfehlerrate
(WER) wird insgesamt und je Gruppe über die Zahl der Referenzwörter gewichtet.
Wie bei `evaluate-transcripts.py` werden Unicode NFKC, Groß-/Kleinschreibung
und Satzzeichen normalisiert; die Tabelle bewertet deshalb keine Zeichensetzung.
Die zweite WER-Spalte setzt zusätzlich deutsche ganze Zahlwörter von null bis
neunundneunzig mit Ziffern gleich, einschließlich „einundzwanzig“. Die Artikel
„ein“ und „eine“, Dezimalzahlen, Datumsformate und höhere Zahlwörter bleiben
unverändert. Führende Nullen in Ziffernfolgen werden entfernt.
Zusammengesetzte Ziffernformate und Ziffern mit Punkt werden vor der
Satzzeichenentfernung geschützt, auch am Textende. Das ist konservativ:
„3.“ und „drei.“ gelten in dieser Zusatzspalte nicht als gleich. Die rohe WER
bleibt daneben sichtbar und ignoriert Satzzeichen weiterhin.

Median und P90 beziehen sich auf die gemeldeten Dauern; P90 nutzt den
nächsten Rang (`ceil(0.9 * n)`). Fehlende Sätze werden angezeigt und nicht
als erfolgreiche Erkennung oder als Fehler in die WER gerechnet. Nicht
vertretene Gruppen zeigen keine Rate. Erkennungen ohne jeden Lauf kann die
Datei nicht nachweisen. Vergleiche nur vollständig und unter denselben
Bedingungen gemessene Durchläufe.

Die Tests verwenden synthetische Texte. Skript und Katalog nehmen nichts
auf und senden nichts. Es liegen damit noch keine Messwerte vom iPhone und
kein Nachweis allgemeiner Sprachqualität vor.
