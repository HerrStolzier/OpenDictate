# Checks

## Required after source changes

```bash
swift format lint --configuration .swift-format --recursive Sources Tests Package.swift
swift test -Xswiftc -warnings-as-errors
bash -n scripts/build-app.sh
bash -n scripts/store-api-key.sh
git diff --check
```

For release or packaging changes, additionally run `./scripts/build-app.sh` and
verify the generated Plist and signature. A build does not prove microphone,
target-field delivery, VoiceOver, installation or publication.

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
