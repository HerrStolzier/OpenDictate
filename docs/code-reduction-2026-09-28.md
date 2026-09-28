# Code reduction verification · 28 September 2026

## Contract fixed before implementation

User request: attempt a 10–25% code reduction while preserving behavior,
security and data integrity. The user explicitly clarified that the allowed
coverage loss is **at most 2% relative**, not two percentage points.

Baseline: `5b95535b8f80d1cc868318594860f64566294386`.
Count all tracked `Sources/**/*.swift` and `linux/src/**/*.rs` files:
46 Swift files / 5,643 physical lines and 13 Rust files / 2,366 lines,
**8,009 lines in total**. The fixed file boundary includes debug fixtures and
inline Rust tests; those remain part of the inventory, but deleting tests,
fixtures, comments or whitespace is not credited as substantive simplification.
New production helpers must be included even if placed outside those folders.
The lower target requires a net reduction of at least **801 lines**.
Documentation, standalone tests, generated output and the separate Windows
checkout are outside this reduction numerator. Windows remains audit-only.
Linux remains unchanged unless its own verification scope is explicitly added.

Retain the 109 existing Swift test declarations, including four opt-in checks.
Do not remove tests, weaken assertions, add coverage-only calls, or change
formatting to meet a quota. Run no source edits concurrently with a measurement.
The exact before/after source and test hashes accompany the local evidence.

## Failure cases to preserve

Before implementation, record the relevant existing contracts:

- Recording start or retry must not survive a cancelled preparation, a stale
  permission callback, a modal setup cancellation or application termination.
- A failed helper/credential read must not start recording or expose credentials;
  a stored replacement must not erase the only working legacy credential first.
- Failed, cancelled, empty or undelivered transcription must retain recoverable
  audio. Retry must authenticate exactly the uploaded bytes and check expiry.
- Shortcut replacement failure must preserve the old registration and preference.
- Menu, settings and panel actions must retain their enabled state, selection,
  keyboard focus and accessible labels, including while a menu is open.
- Paste must retain the current documented original-app activation, foreground
  and clipboard checks; a submitted command is not confirmed text insertion.
- Fixture cleanup must not overwrite clipboard content changed by the user.
- Versioned helper protocol, signing checks and release artifacts must remain
  compatible; existing Build 8 is not rebuilt or replaced by this refactor.

These are protected by existing tests and targeted visible acceptance where
available. No new unit tests are written after their implementation. A coverage
percentage alone does not prove these contracts or installed-app behavior.

## Fresh baseline

Host: macOS 27 arm64, Swift 6.4, Apple LLVM 21.0.0. Existing installed Swift
Testing plugin used; no toolchain installation or configuration change.

```sh
swift test --scratch-path /Users/basti/.codex/artifacts/opendictate/code-reduction-20260928/baseline-build \
  --enable-code-coverage -Xswiftc -warnings-as-errors \
  -Xswiftc -plugin-path \
  -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
```

Exit 0. Both test products passed (80 System and 29 Core declarations;
four retained opt-in cases disabled). Exported coverage includes both test
binaries, the app and the Keychain helper with the merged `default.profdata`;
it does not use SwiftPM's potentially partial per-product JSON.

| Module | Covered / instrumented lines | Coverage |
| --- | ---: | ---: |
| All Swift production sources | 1,735 / 5,175 | 33.5265700483% |
| OpenDictate | 1,426 / 4,720 | 30.2118644068% |
| OpenDictateCore | 309 / 360 | 85.8333333333% |
| Keychain helper | 0 / 95 | 0% |

Candidate gate: `candidate_coverage / baseline_coverage >= 0.98`, therefore
**at least 32.8560386473% aggregate line coverage**. Coverage denominators may
change when code is removed; report counts, module totals and changed uncovered
paths as well as percentages. Removing untested code can raise the percentage
without adding confidence. Rust has no measured coverage baseline in this run;
unchanged Rust bytes are checked separately, and no Rust coverage claim is made.

Local durable evidence directory:
`/Users/basti/.codex/artifacts/opendictate/code-reduction-20260928/`.
It contains `baseline-inventory.json`, `baseline-tests.log`,
`baseline-coverage-raw.json`, `baseline-coverage.json` and the isolated build.
Source hashes match the earlier retained coverage measurement; the new run
independently reproduced its aggregate. No installed app was replaced or launched.

## Candidate and final acceptance

Pending implementation and independent review. No reduction or successful
post-change coverage result is claimed yet. The central task status belongs in
[ROADMAP.md](../ROADMAP.md); broader findings are in the
[project audit](project-audit-2026-09-28.md).
