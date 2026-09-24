# Test signal audit · 24 September 2026

This audit applies to the tests at `118cb49` and the installed-app evidence
linked from [`remaining-acceptance.md`](remaining-acceptance.md). A successful
dictation into TextEdit proves the observed microphone → provider → paste path
for that build. It does not exercise every model, corrupted preference,
failure, cancellation, or concurrent callback. Synthetic and historical
acceptance runs have their stated candidate and fixture limits.

## Failure cases that still need isolated coverage

- Audio is silent, too short, trimmed incorrectly, or deleted before a usable
  authenticated recovery copy exists; expiry, filename, file type, symlink, or
  authentication mistakes expose or lose recordings.
- A provider error leaks raw data, a malformed success is pasted, a request has
  the wrong language or multipart shape, or a retry overlaps another upload.
- A stale permission, Keychain, recording, paste, or quit callback changes a
  newer session; a foreground-app or clipboard change sends text to the wrong
  place; an unconfirmed paste is reported as certain.
- Invalid shortcuts or partial preferences register an unintended key; a
  failed hotkey replacement loses the working registration.
- Logs expose private details or truncate records; transcript evaluation and
  process measurements overwrite input or misinterpret numeric values.
- On Linux, a damaged or unauthenticated recovery file is retried, a failed
  copy deletes the only original, settings retain a secret, or IPC/state and
  Secret Service errors allow an unsafe transition.

The retained Core and System tests cover these paths through boundary inputs,
real temporary files, injected service failures, controlled callback order,
native registration where opted in, and HTTP stubs. The Python tests cover
Unicode/edit distance, missing or invalid measurements, CPU time formats and
output collisions. The remaining Rust tests cover Linux policy, recovery,
settings, IPC, file paths, WAV preparation, and local HTTP behavior. The
opt-in live transcription check and resource benchmark are distinct evidence
tools, not ordinary unit tests; neither is enabled by the offline suite.

## Removed tests

| Test function(s) | Why it adds no independent failure signal |
| --- | --- |
| `FormattingTests.formattedSeconds` | Exact UI duration use is checked by `OpenDictateErrorTests.tooShortMessage`; the extra cases only repeat decimal formatting. |
| `FormattingTests.formattedDb` | Checks rounded log text, while `AudioLevelsTests` and `AudioPipelineTests` exercise the actual signal threshold and recording decision. |
| `FormattingTests.appendString` | Tests a thin standard-library UTF-8 append wrapper in isolation; the request test inspects multipart assembly, although it does not specifically cover non-ASCII text. |
| `SettingsTests.modelDefault`, `SettingsTests.shortcutDefault` | Assert the same named constants as their defaults; visible installed-app setup and physical-hotkey acceptance are the right checks for the chosen defaults. The Build 7 hotkey result remains open. |
| `HotKeyShortcutTests.presets`, `HotKeyShortcutTests.presetsHaveNames` | Mirror the static menu array and label fields; compact settings acceptance inspects the actual menu. |
| `HotKeyShortcutTests.lookupSucceeds`, `HotKeyShortcutTests.lookupFails` | The settings round-trip and unknown stored-shortcut fallback exercise both lookup outcomes through the consumer. |
| `HotKeyShortcutTests.carbonCrossCheck` | Supplies handwritten numbers to a handwritten comparison. The app compares against actual SDK constants at startup, and native hotkey checks cover registration. |
| `SettingsTests.languageRoundTrip` | The `UserDefaultsStoreTests.settingsPersistAndRemoveThroughTheAdapter` test exercises the setting's write and read through a real defaults suite. |
| `TranscriptionModelTests.defaultModel` | Duplicates a named constant/default choice, with no additional request behavior. |
| `TranscriptionModelTests.prices` | Repeats locally hard-coded rates, so it cannot detect provider price changes or actual billing. |
| `RecordingRetentionTests.emptyFolder`, `RecordingRetentionTests.singleEntry` | Repeat empty/singleton outcomes implicit in real recovery-store tests plus under-limit and newest-candidate cases. |
| `RecordingRetentionTests.dropsOldest`, `RecordingRetentionTests.futureTimestampIsKept` | `orderIndependent` checks the same seven values and two oldest results after shuffling; `underLimit` checks five entries created after `now`. |
| `RecordingRetentionTests.keepNone` | Only tests an explicit zero limit that production never calls; real count and age boundaries remain covered. |
| `TrimPlannerTests.rejectsTooShort` | Uses the same input as `errorCarriesDurations`, which also asserts the specific error and durations. |
| `DictationFlowTests.sentPasteIsReportedAsUnconfirmed` | The `.submitted` case in `insertionEvidenceReachesStatusWithoutChangingClipboardRecoveryPolicy` uses the same start/stop path and asserts the outcome and paste count, plus transcript and recovery behavior. |
| Linux `main::tests::usage_lists_toggle` | Checks substrings in a static help string, without invoking the CLI. |
| Linux `record::tests::max_recording_matches_macos_cap` | Mirrors a single constant; it does not test actual stopping at the cap. |

All other tests are retained because they exercise a user-visible or data
integrity failure path absent from the current installed-app E2E evidence, or
are themselves opt-in integration/performance checks. In particular, keep
language auto-detection and environment precedence, distinct shortcut pairs,
model rejection, recovery retention ordering, and the Linux no-clipboard
deletion policy. Reassess this audit when an E2E case proves one of those paths.

## Verification

Removed 22 test functions: 20 Swift and two Rust. Production code, E2E
fixtures, and installed apps are unchanged. The Swift suite with 138 test
functions (50 Core and 88 System) passed, with four opt-in live, native hotkey,
and benchmark tests skipped. All eight Python tests passed. Strict Swift formatting, the six shell
syntax checks from `CHECKS.md`, and `git diff --check` passed.

Linux execution is unverified: Cargo and rustfmt are unavailable on this Mac,
and the configured Linux SSH host timed out. The Rust diff only deletes two
complete test functions inside existing `#[cfg(test)]` modules. It does not
change imports, production code, or dependencies. The earlier 25-test Linux
report remains historical evidence; it is not a run of the remaining 23 tests.
