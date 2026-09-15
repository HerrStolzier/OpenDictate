# Checks

## Required after source changes

```bash
swift format lint --configuration .swift-format --recursive Sources Tests Package.swift
swift test -Xswiftc -warnings-as-errors
bash -n scripts/build-app.sh
bash -n scripts/verify-app.sh
bash -n scripts/store-api-key.sh
git diff --check
```

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
- `swift format lint --configuration .swift-format --recursive Sources Tests Package.swift`: project formatting.
- `./scripts/build-app.sh`: release bundle, Plist, signature and Hardened Runtime verification. Does not launch/install it.
- `git diff --check` and `bash -n scripts/build-app.sh` before handoff.
- Real microphone, hotkeys, direct target-field insertion, clipboard fallback and VoiceOver require attended native-app acceptance; an accessibility tree alone is not a VoiceOver listening test.
- After changing the insertion mechanism, recheck one native text control and one actually used browser or Electron control. A successful historical `Cmd+V` test does not validate direct `AXSelectedText` insertion.
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

## Brave insertion candidate

The Unicode event tests construct events without posting them. They check exact
UTF-16 preservation, modifier-free events, failure, cancellation and stopping
remaining chunks after a focus change. They do not prove browser editing.
Before accepting the candidate, check actual plain text, contenteditable and
iframe fields in a local Brave fixture, including text longer than 20 UTF-16
units, a selection, accents/emoji and a switch away. Distinguish this synthetic
system-delivery check from microphone-to-editor acceptance in the installed app.
Never use a private mail draft as an automated fixture.
