# Checks

## Required after source changes

```bash
swift format lint --strict --configuration .swift-format --recursive Sources Tests Package.swift
swift test -Xswiftc -warnings-as-errors
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts/tests -p 'test_*.py' -v
bash -n scripts/build-app.sh
bash -n scripts/verify-app.sh
bash -n scripts/store-api-key.sh
bash -n script/build_and_run.sh
bash -n scripts/package-ci-app.sh
bash -n scripts/tests/test-verify-app.sh
git diff --check
```

CI uses the same strict formatting, warnings-as-errors tests and six shell
syntax checks. It records the macOS, architecture, Swift and formatter versions
so runner updates are visible without changing the selected toolchain. Its
whitespace check compares the checked-out commit with its first parent
(`git diff --check HEAD^ HEAD`); on pull requests this covers the merge diff
against the base branch. Local `git diff --check` checks uncommitted edits.

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

After bundle or packaging changes, run the controlled failure fixtures against
the built app:

```bash
bash scripts/tests/test-verify-app.sh .build/OpenDictate.app
```

The fixtures use temporary copies and ad-hoc signing. They verify rejection of
missing, false and wrongly typed audio-input entitlements, missing Hardened
Runtime and broken signatures. The original bundle must remain unchanged. The
tests do not launch the app, access a microphone or change a user's signing
identity, Keychain or permissions. CI runs them before packaging its development
archive and verifies the archive again after extraction.

Documentation-only changes: run `git diff --check`, verify changed local links
and review ownership, conflicting rules and evidence scope. Include new files
in that review. Do not rerun app tests solely for prose changes.

Linux changes (`linux/`): run these on a Linux host. They are not part of
the macOS Swift CI workflow.

```bash
cargo fmt --manifest-path linux/Cargo.toml -- --check
cargo test --manifest-path linux/Cargo.toml
cargo clippy --manifest-path linux/Cargo.toml --all-targets -- -D warnings
cargo build --release --manifest-path linux/Cargo.toml
git diff --check
```

Do not add this crate to `.github/workflows/checks.yml`. Live microphone,
Secret Service writes, OpenAI requests and Wayland clipboard checks require
separate attended verification and are not default tests. The transcription
tests may use loopback stub HTTP only. Never pass an API key as a command
argument or environment variable.

## Meaning of checks

- `swift test -Xswiftc -warnings-as-errors`: offline logic, lifecycle, HTTP stubs, recovery, logging and synthetic audio-file tests, with compiler warnings treated as failures. Optional benchmark and live API test are skipped by default.
- `python3 -m unittest discover ...`: offline regression tests for the transcript evaluator and process sampler, including output-file preservation.
- `swift format lint --strict --configuration .swift-format --recursive Sources Tests Package.swift`: project formatting; lint warnings cause a failed check.
- `./scripts/build-app.sh`: release bundle, Plist, signature and Hardened Runtime verification. Does not launch/install it.
- `git diff --check` and `bash -n` for all six scripts listed above before handoff.
- Real microphone, hotkeys, direct target-field insertion, clipboard fallback and VoiceOver require attended native-app acceptance; an accessibility tree alone is not a VoiceOver listening test.
- After changing the insertion mechanism, recheck the affected categories and
  scenarios in `docs/compatibility-matrix.md`. Historical checks validate only
  their installed candidate.
- The lifecycle tests use controlled callbacks and a fake recorder/transcriber to
  exercise cancellation, delayed permission results and quit/drain ordering. They
  do not execute native permission dialogs or prove microphone/device behavior.
- The API-key tests inject Keychain results without accessing the real Keychain.
  For a legacy API-key item, save the key through the in-app dialog and inspect
  or test the new item's ACL separately. If legacy cleanup reports a warning,
  saving again retries it; never use a real credential in automated checks.

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
Start with both windows closed and dictate through the physical hotkey. The
panel must stay hidden during recording, processing, completion and failure;
the status bar still shows progress. Open the panel deliberately, close it
during recording, and verify that later updates do not reopen it. Permission
and setup failures must remain available when the user opens the panel later.
Check application capture before a Keychain dialog and before explicit panel
focus return. A later focus switch may redirect Paste within that application.
The real acceptance path is microphone recording, provider transcription and
automatic insertion into a fresh target document, without manual paste.
Close and discard test documents afterward; preserve pre-existing user content.

`./script/build_and_run.sh --daily` reuses the installed app. The explicit
`--preview`, `--focus-fixture` and `--processing-focus-preview` modes are synthetic
fixtures, not microphone-to-target acceptance. Historical fixture evidence is in
[the September 13 report](docs/live-acceptance-2026-09-13.md); it does not establish
acceptance of the integrated candidate.

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
with fixed artificial text and the general clipboard, restored on exit only if
it still contains the fixture's value. Choose the exact target
app; only its foreground window with an `OpenDictate Matrix` title qualifies.
For Safari's local file fixture, the exact `AXURL` of
`scripts/fixtures/delivery-matrix.html` also qualifies when Safari exposes no
window title.
The fixture has no microphone, provider, Keychain, preference or recovery access.
Its build reuses the existing local signing identity; it does not grant TCC access.
The “Nur Ziel prüfen” option reports the actual `NSWorkspace` foreground app and
captured application without starting the synthetic flow, writing the clipboard or
sending text. TextEdit is also selectable; use an owned document whose filename
starts with `OpenDictate Matrix`. Selecting an app in a UI automation tool does
not itself prove that the app became the actual foreground target.
Named debug helper executables select their fixture mode even without CLI flags;
unknown renamed debug executables exit. Verify parameterless relaunches after
changing dispatch, including unchanged recovery and preference inventories.
Use `scripts/fixtures/delivery-matrix.html` for local browser fields. The fixture
also exposes the real shortcut dialog without saving the choice, and synthetic
80/85-second recording states at the panel's minimum width. Its optional
10-second synthetic recording delay captures the application first: switch apps
or windows during that delay and observe where Paste lands after the original
application is reactivated. Close all created tabs, windows and processes and compare
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

`PasteboardInserterTests` verifies application activation, clipboard integrity,
foreground checks and Command-V submission without posting system input. It
does not prove visible insertion in a real editor.

Use [the compatibility matrix](docs/compatibility-matrix.md) for product-facing
acceptance. Exercise native fields, browser `input`/`textarea`, `contenteditable`,
an editable iframe and an Electron field with controlled non-sensitive content.
In the HTML fixture, load its reference probe and use the built-in comparator;
an `EXAKT` result means the complete value and selection replacement match in
UTF-16 units, including surrogate pairs, line breaks and trailing whitespace.
For each relevant category check cursor positions, selection replacement,
multiline Unicode and app/window/tab switches during recording and processing.
Observe whether Paste reaches a different field in the original application.
Never use a private mail draft or account content as a fixture.

Record the installed candidate and visible before/after result. A synthetic
production-inserter run, an attended end-to-end dictation and user confirmation
are distinct evidence. One program does not establish its whole category.

## Apple Terminal

The former Terminal-specific Unicode path has been removed. The installed
`68ef919` candidate passed one shell-line case on that older path; see
[the September 22 report](docs/terminal-focus-acceptance-2026-09-22.md).
The restored Command-V path has no line-break or command filter. Test Terminal
only with a harmless single-line phrase and a disposable, empty shell prompt.

For a separately authorized native dictation check:

1. Record the installed OpenDictate version/build/revision, macOS version and
   Apple Terminal version. Use a disposable local Terminal window with a known,
   empty shell input line and no interactive program or pending command. If the
   input context is unclear, use a new TextEdit document as a control and leave
   the Terminal case open; ordinary printable keys can affect other programs.
2. Inspect the actual focused Terminal window before attempting input. Start with a
   short, harmless single line such as “OpenDictate Probe Apfel 42”. End dictation
   with the recording shortcut; **do not press Return, submit the line or run a
   command**. Compare the displayed input with the retained transcript and note
   whether all text arrived. Do not infer success from a submitted-event count.
3. With the same controlled input context, check what happens after a real
   target switch or when display text is selected. The old rejection behavior
   must not be assumed for the restored Command-V path.
4. Remove only the owned, unsubmitted test input or close the disposable window
   without submitting it. A TextEdit control result or a
   clipboard fallback must not be reported as successful Terminal insertion.

Do not send a multiline or executable test to a live shell. This procedure
does not establish support for iTerm2 or terminals embedded in editors.
