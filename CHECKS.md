# Checks

## Required after source changes

```bash
swift format lint --configuration .swift-format --recursive Sources Tests Package.swift
swift test -Xswiftc -warnings-as-errors
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts/tests -p 'test_*.py' -v
bash -n scripts/build-app.sh
bash -n scripts/verify-app.sh
bash -n scripts/store-api-key.sh
git diff --check
```

On the macOS 27 / Swift 6.4 Command Line Tools host, the default build may fail
to discover `TestingMacros`. The verified local workaround uses the installed
plugin explicitly (no SDK installation or system setting change):

```bash
swift test --scratch-path /tmp/opendictate-swift-plugin-final \
  -Xswiftc -warnings-as-errors -Xswiftc -plugin-path \
  -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
```

Use this only when that directory exists and the failure is the missing plugin;
an unrelated compiler failure still needs investigation.

For release or packaging changes, additionally run `./scripts/build-app.sh` and
verify the generated Plist and signature. A build does not prove microphone,
target-field delivery, VoiceOver, installation or publication.
The build calls `scripts/verify-app.sh`, which checks the final signed bundle's
Hardened Runtime flag and boolean `com.apple.security.device.audio-input`
entitlement. Run `./scripts/verify-app.sh /path/to/OpenDictate.app` to repeat
these checks without rebuilding or launching. A missing or false entitlement
must fail verification, even when the signature itself is valid.

Documentation-only changes: run `git diff --check`, verify changed local links
and review ownership, conflicting rules and evidence scope. Include new files
in that review. Do not rerun app tests solely for prose changes.

## Meaning of checks

- `swift test`: offline logic, lifecycle, HTTP stubs, recovery, logging and synthetic audio-file tests. Optional benchmark and live API test are skipped by default.
- `python3 -m unittest discover ...`: offline regression tests for the transcript evaluator and process sampler, including output-file preservation.
- `swift format lint --configuration .swift-format --recursive Sources Tests Package.swift`: project formatting.
- `./scripts/build-app.sh`: release bundle, Plist, signature and Hardened Runtime verification. Does not launch/install it.
- `git diff --check` and `bash -n scripts/build-app.sh` before handoff.
- Real microphone, hotkeys, direct target-field insertion, clipboard fallback and VoiceOver require attended native-app acceptance; an accessibility tree alone is not a VoiceOver listening test.
- After changing the insertion mechanism, recheck the affected categories and
  scenarios in `docs/compatibility-matrix.md`. A successful historical `Cmd+V`
  test does not validate direct `AXSelectedText` or Unicode-event insertion.
- For a legacy API-key item, save the key once through the in-app dialog and inspect or test its resulting ACL separately; never use a real credential in automated checks.

## Explicit live API check

Only after authorization for the existing OpenAI account and the specific fixture. Place a short, non-sensitive `reference.m4a` in an explicitly chosen test directory. The current fixture text is: "Dies ist ein kurzer Test. Bitte schreibe die Zahl sieben und das Wort Apfel."

```
OPENDICTATE_LIVE_API=1 OPENDICTATE_LIVE_TEST_DIRECTORY=/path/to/test-directory swift test --filter LiveTranscriptionTests
```

One request uses `gpt-transcribe` by default, German language and JSON output. Set `OPENDICTATE_LIVE_TEST_MODEL=gpt-4o-mini-transcribe` to check the other offered model separately. Only these two model identifiers are accepted. The existing Keychain key remains in memory; no credentials appear in arguments or evidence. `api-result-<model>.json` contains timing, input size and the test transcript. Synthesized speech is not evidence of human microphone quality. No retries are automatic.

## Offline resource benchmark

No microphone, network or Keychain access. Synthetic recovery files are created and removed only in a unique temporary directory. Run in release mode, with an absolute output path in an existing directory:

```bash
OPENDICTATE_RESOURCE_BENCHMARK=1 OPENDICTATE_RESOURCE_BENCHMARK_OUTPUT=/path/to/recovery.csv swift test -c release --filter ResourceBenchmarkTests
```

The CSV records cleanup wall time, process CPU time and cumulative process peak RSS for empty, normal-size and maximum-size recovery fixtures. Exclude iteration 0 when comparing warm medians. Peak RSS includes fixture generation and runner allocations; it is not a measurement of app RAM saved. Results and remaining gaps: `docs/resource-performance-2026-09-08.md`.

For an explicitly selected running process, sample current RSS and cumulative
CPU-time deltas over 60–300 seconds:

```bash
./scripts/measure-process.py --pid "$PID" --executable /exact/path/to/OpenDictate --duration 60 --interval 1 --output /absolute/path/to/new-result.json
```

The sampler requires the exact PID and executable path, refuses to overwrite
the output, and stops if the process exits or its start time/path changes. Its
CPU percentage is cumulative process CPU-time delta divided by elapsed wall
time, not the averaged `%CPU` shown by `ps`. RSS is sampled current resident
memory: it can miss peaks between samples and cannot recover a historical peak.
The script does not measure energy.

## Offline transcript evaluation

`scripts/evaluate-transcripts.py` compares reference and hypothesis text that
you explicitly provide in a UTF-8 JSON corpus; it does not record or transcribe
audio and does not use the network. Print the report or write it to a new file:

```bash
./scripts/evaluate-transcripts.py /path/to/corpus.json --output /path/to/new-report.json
```

Use an exact reference transcript for each controlled fixture. Word-error and
expected-term results describe only the supplied pairs; they are not evidence
of microphone or general speech quality.

## Native recording panel

The menu bar opens the daily AppKit panel; Settings opens the existing controls
in a separate window. Check start/stop, cancellation, keyboard navigation and
passive recording/processing/result updates in the installed candidate.
The real acceptance path is microphone recording, provider transcription and
automatic insertion into a fresh target document, without manual paste.
Close and discard test documents afterward; preserve pre-existing user content.

`./script/build_and_run.sh --daily` reuses the installed app. The explicit
`--preview`, `--focus-fixture` and `--processing-focus-preview` modes are synthetic
fixtures, not microphone-to-target acceptance. Historical fixture evidence is in
[the September 13 report](docs/live-acceptance-2026-09-13.md); it does not establish
acceptance of the integrated candidate. Also run `bash -n script/build_and_run.sh`.

## Compact settings acceptance

Inspect the actual installed settings at compact and larger window sizes. The
four main options must be visible without a large leading blank area. Navigate
with Tab/Shift+Tab and activate “Erweitert”, “Aufnahmen” and “Hilfe” with Space.
Inspect menus/dialog entry points without changing preferences or sending a
recording. Confirm that cancellation, discard, copy and clear remain accessible
from the recording panel's “Weitere Aktionen”. Compare preference and recovery
file integrity before/after; do not delete recordings created by the user.

## Repräsentative Kompatibilitätsabnahme

`./script/build_and_run.sh --matrix-host` starts controlled native test fields.
`./script/build_and_run.sh --matrix-fixture` runs the production flow and inserter
with fixed artificial text and a unique test pasteboard. Choose the exact target
app; only its foreground window with an `OpenDictate Matrix` title qualifies.
The fixture has no microphone, provider, Keychain, preference or recovery access.
Its build reuses the existing local signing identity; it does not grant TCC access.
Named debug helper executables select their fixture mode even without CLI flags;
unknown renamed debug executables exit. Verify parameterless relaunches after
changing dispatch, including unchanged recovery and preference inventories.
Use `scripts/fixtures/delivery-matrix.html` for local browser fields. The fixture
also exposes the real shortcut dialog without saving the choice, and synthetic
80/85-second recording states at the panel's minimum width. Its optional
10-second synthetic recording delay captures the target first: switch apps or
windows during that delay and verify that delivery is rejected instead of being
redirected. Close all created tabs, windows and processes afterward and compare
user preferences/recovery files.

The recovery store tests exercise real temporary filesystem writes with a fixed
test key, including failure to create the recovery directory and preserving the
only original on both recording and processing cancellation. They do not test
the user's Keychain or simulate physical microphone removal.

After explicit authorization for temporary native hotkey registration, run:

```bash
OPENDICTATE_NATIVE_HOTKEY_CHECK=1 swift test --filter NativeHotKeyRegistrationTests
```

This uses Control+Option+Command+F18/F19 without sending key presses. It verifies
an actual Carbon registration collision, the original registration surviving,
and both test combinations becoming available again. It changes no preference;
an existing environmental conflict fails the check rather than choosing another
shortcut. This test is skipped by default, including CI.

The Unicode event tests construct events without posting them. They check exact
UTF-16 preservation, modifier-free events, failure, cancellation and stopping
remaining chunks after a focus change. They do not prove browser editing.

Use [the compatibility matrix](docs/compatibility-matrix.md) for product-facing
acceptance. Exercise native fields, browser `input`/`textarea`, `contenteditable`,
an editable iframe and an Electron field with controlled non-sensitive content.
In the HTML fixture, load its reference probe and use the built-in comparator;
an `EXAKT` result means the complete value and selection replacement match in
UTF-16 units, including surrogate pairs, line breaks and trailing whitespace.
For each relevant category check cursor positions, selection replacement,
multiline Unicode and app/window/tab switches during recording, processing and
chunked delivery. Also verify the explicit clipboard fallback for a rejected or
protected target. Never use a private mail draft or account content as a fixture.

Record the installed candidate and visible before/after result. A synthetic
production-inserter run, an attended end-to-end dictation and user confirmation
are distinct evidence. One program does not establish its whole category; the
explicit Brave/Safari/Obsidian paths do not establish other browsers or Electron apps.
