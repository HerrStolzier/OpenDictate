# Swift test reduction and coverage comparison

Baseline: `7309c02bdf83a93ab94890b4770dc07f7f8a9178`, clean checkout.
Scope: the macOS Swift suite, 137 test declarations, including four retained
opt-in tests. Parameterized cases are not counted as extra declarations.
The 20% target rounds up to 28 actual removals (20.44%), leaving 109.
Python, Linux and shell checks are outside this reduction denominator.

## Measurement contract

Compare production code only, with the same macOS 27.0 arm64 host, Swift 6.4,
Apple LLVM 21.0.0, compiler flags and opt-in exclusions. No live microphone,
provider, Keychain access or installed-app launch is part of the measurement.
Keep production source hashes and coverage denominators unchanged. Count all
instrumented files under `Sources/`, including untested app and helper code;
exclude tests, generated runners and dependencies. The enum-only
`Sources/OpenDictateCore/InsertionSubmission.swift` has no instrumented code.

The primary gate is at most two percentage points of lost line coverage.
Also report relative loss, region and function coverage, and module totals.
Coverage shows execution, not assertion quality or end-to-end acceptance.
Deletion decisions additionally need the per-test contract register.

## Reproduction

Use separate clean checkouts for the baseline and candidate. Run the following
in each checkout and retain the exit code and complete local log:

```sh
swift test --enable-code-coverage -Xswiftc -warnings-as-errors \
  -Xswiftc -plugin-path \
  -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
```

The plugin option is the existing host workaround from `CHECKS.md`. No opt-in
test environment variables are set. On this toolchain, SwiftPM writes
`OpenDictate.json` for only the last test binary. Do not use that partial JSON
as the project coverage baseline. Export both test binaries and both products
against the merged profile instead:

```sh
xcrun llvm-cov export \
  .build/out/Products/Debug/OpenDictateSystemTests.xctest/Contents/MacOS/OpenDictateSystemTests \
  -object .build/out/Products/Debug/OpenDictateCoreTests.xctest/Contents/MacOS/OpenDictateCoreTests \
  -object .build/out/Products/Debug/OpenDictate \
  -object .build/out/Products/Debug/OpenDictateKeychainHelper \
  -instr-profile .build/out/Products/Debug/codecov/default.profdata \
  > /tmp/opendictate-coverage-export.json
```

For each exported production file, retain `summary.lines`, `summary.regions`
and `summary.functions`. Compute each aggregate as `100 * sum(covered) /
sum(count)`; do not average file percentages. Normalize only the checkout
prefix, then compare identical relative file sets and denominators.
The committed JSON summaries retain per-file counts and source SHA-256 values;
the text logs retain baseline/candidate suite outcomes and opt-in skips.

Baseline: 1,754 / 5,175 production lines (33.893720%), 678 / 2,094 regions
(32.378223%), and 227 / 759 functions (29.907773%).

The separate Luna Max critic independently re-exported the baseline from the
four binaries and profile and reproduced every aggregate. It confirmed 137
declarations and four opt-in skips. The profile reports no branch coverage;
region counts must not be described as branch coverage. The enum-only file
and the low overall coverage remain explicit limits. Baseline arithmetic alone
does not approve any deletion.

## Final verification

A preliminary exclusion run and the final run after deleting the 28 tests
both passed with identical production coverage. The final suite contains 109
declarations (80 System, 29 Core; four opt-in skips). All production source
hashes, file sets and coverage denominators remained identical.

| Production metric | Baseline | Final | Percentage-point change | Relative loss |
| --- | ---: | ---: | ---: | ---: |
| Lines | 1,754 / 5,175 = 33.893720% | 1,735 / 5,175 = 33.526570% | -0.367150 | 1.083238% |
| Regions | 678 / 2,094 = 32.378223% | 663 / 2,094 = 31.661891% | -0.716332 | 2.212389% |
| Functions | 227 / 759 = 29.907773% | 223 / 759 = 29.380764% | -0.527009 | 1.762115% |

All 19 uncovered additional lines belong to Core: `AudioLevels.swift` (1),
`Formatting.swift` (3), `HotKeyShortcut.swift` (5), `OpenAIAPIError.swift` (1),
`OpenDictateError.swift` (4), and `Settings.swift` (5). Core line coverage falls
from 328/360 (91.111111%) to 309/360 (85.833333%), a 5.277778-point reduction.
App coverage stays 1,426/4,720 (30.211864%); the helper remains 0/95.
The aggregate gate passes; it is not a per-module two-point guarantee.

Line coverage also passes a stricter interpretation of the user's 2% limit:
the relative loss is 1.083238%. Regions lose 2.212389% relatively, although
their percentage-point loss remains below two. Neither regions nor functions
are substituted for the stated line-coverage gate.

## Signal preservation and independent review

The final choice retains `padsBothSides` and `spansFirstToLast`: the synthetic
single-tone export check does not independently protect exact padding or
speech separated by pauses. Lower-priority empty environment model/prompt
checks were removed instead. Three existing retained tests were challenged
in an isolated copy of the baseline, with failure cases recorded before
execution in [control-scenarios.json](control-scenarios.json):

| Intentional fault | Retained test | Result |
| --- | --- | --- |
| Remove end padding | `padsBothSides` | Expected assertion failure, exit 1 |
| Replace first speech time with each later loud window | `spansFirstToLast` | Expected assertion failure, exit 1 |
| Start recording during successful setup completion | `setupUpdatesKeepTheirActionAvailableWithoutOpeningOrRecording` | Expected assertion failure, exit 1 |

All three passed after restoring the original sources (exit 0). Source hashes
were checked against the baseline and the temporary copy was removed. These
are offline negative controls, not live E2E. Evidence: [results](control-results.json)
and [sanitized assertion output](control-evidence.txt).

A separate Luna Max worktree critic inspected the deletion proposal and the
corrected audio selection. Its setup auto-start concern was withdrawn after
checking the surviving panel test's explicit `recordings == 0` assertion.
No further material safety/data-integrity finding remained in that review.
The removed successful-setup test also checked a subsequent deliberate Start
click; that exact automatic assertion is lost. The retained panel test still
checks setup does not start recording. The existing Build-7 live button run
is historical evidence for identical panel source, not a new E2E run here.

The complete local offline suite, eight Python tests, strict Swift formatting,
six shell syntax checks and `git diff --check` passed. No new tests were added,
no existing test cases were merely grouped, and production code is unchanged.
The ten changed test files lose 263 lines. The four opt-in checks remain skipped.
Linux tests and real microphone/provider/permission/VoiceOver checks were not
rerun because those paths and their sources were unchanged.
