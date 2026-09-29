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

## Candidate result

Reachable integrated candidate: `1f895537e9b36d962eb1425113423da377e95b1b`.
Removed the unreferenced `PanelColors.hex` implementation (five lines) and
corrected two policy comments without changing runtime behavior. The source
inventory changes from **8,009 to 8,004 lines: 5 lines / 0.06243% reduction**.
The requested 10–25% reduction was **not achieved**. Documentation savings
are not included. No source moved elsewhere and no tests were deleted.

The reviewed larger candidates do not justify forcing the quota: credential
sampling changes timing across permission waits; a settings rewrite affects
focus, accessibility and refresh; a shared menu-construction helper offers no
meaningful net saving; Linux paths implement distinct safety contracts.
These are documented opportunities with costs, not implemented reductions.

All existing source checks passed: strict Swift formatting, warnings-as-errors
Swift tests (80 System / 29 Core, four opt-in cases skipped), eight Python
checks, seven shell syntax checks and whitespace checks. A second isolated
Swift run with the same baseline coverage options passed. All 27 Swift test
files and all 13 Rust source files are byte-identical to the fixed baseline.

| Module | Covered / instrumented lines | Candidate coverage |
| --- | ---: | ---: |
| All Swift production sources | 1,735 / 5,170 | 33.5589941973% |
| OpenDictate | 1,426 / 4,715 | 30.2439024390% |
| OpenDictateCore | 309 / 360 | 85.8333333333% |
| Keychain helper | 0 / 95 | 0% |

Relative aggregate change: **+0.0967118%**, therefore no coverage loss and the
2% relative-loss gate passes. The increase comes entirely from removing five
uncovered lines; it does not mean more behavior was exercised. No executable
path was added or changed. Coverage does not establish installed-app E2E.
Fresh Linux and Windows offline evidence is separate in the
[device report](platform-audit-2026-09-28.md); neither platform has a measured
coverage percentage in this run.

Evidence: `candidate-tests.log`, `candidate-coverage-raw.json`,
`candidate-coverage.json`, `candidate-comparison.json` and `candidate-build/`
in the same durable evidence directory. To reproduce the export, use the
following four products with the merged profile for either scratch build:

```sh
xcrun llvm-cov export "$PRODUCTS/OpenDictateSystemTests.xctest/Contents/MacOS/OpenDictateSystemTests" \
  -object "$PRODUCTS/OpenDictateCoreTests.xctest/Contents/MacOS/OpenDictateCoreTests" \
  -object "$PRODUCTS/OpenDictate" -object "$PRODUCTS/OpenDictateKeychainHelper" \
  -instr-profile "$PRODUCTS/codecov/default.profdata"
```

`PRODUCTS` is the scratch build's `out/Products/Debug` directory. Sum the
`summary.lines` covered/count values of unique production `Sources/` files,
including the app and helper files with zero hits; do not average percentages.
Independent review and Git integration remain pending at this measurement.
The central task status belongs in
[ROADMAP.md](../ROADMAP.md); broader findings are in the
[project audit](project-audit-2026-09-28.md).
