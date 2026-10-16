# Checks

## Required after source changes

```bash
swift format lint --strict --configuration .swift-format --recursive Sources Tests Package.swift
swift test -Xswiftc -warnings-as-errors
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts/tests -p 'test_*.py' -v
bash -n scripts/build-app.sh
bash -n scripts/verify-app.sh
bash -n scripts/package-release-app.sh
bash -n scripts/store-api-key.sh
bash -n script/build_and_run.sh
bash -n scripts/package-ci-app.sh
bash -n scripts/tests/test-verify-app.sh
git diff --check
```

CI uses strict formatting, warnings-as-errors tests and seven shell syntax checks
on macOS 15. A separate compatibility job selects the oldest Xcode 16 installed
on the macOS 15 runner and runs the offline Swift tests plus an ad-hoc bundle
build and verification. Until October 2026 this job ran natively on macOS 14
with Xcode 16.2; [GitHub retires the macOS-14 runner on 2 November
2026](https://github.com/actions/runner-images/issues/13518), so since 13
October 2026 (Basti's decision) it checks the oldest toolchain instead of the
macOS 14 runtime. Its job name `compatibility-macos-14` stays because branch
protection requires it. From 2 November 2026 no hosted runner covers the macOS 14 runtime;
the compiler still enforces the macOS 14 deployment target, and no CI job can
exercise microphone, permission dialogs, VoiceOver or target-field insertion
without an interactive desktop. CI records the macOS, architecture, Swift and formatter versions so runner
updates are visible without changing the selected toolchain. Its
whitespace check compares the checked-out commit with its first parent
(`git diff --check HEAD^ HEAD`); on pull requests this covers the merge diff
against the base branch. Local `git diff --check` checks uncommitted edits.

Pull requests that change only Markdown files, `docs/**` or static website
content (pages, styles, text, subtitles, images, videos and fonts under
`website/`) skip the Swift, Linux and Windows jobs; `website/worker.js`,
`website/site.js`, `website/wrangler.toml` and any other website file type
count as code. A small `changes` job in each of these workflows runs
`scripts/ci/docs-only-change.sh` against the merge commit's first parent, and
the heavy jobs are skipped by condition. Skipped jobs satisfy the required
checks on `main`. Any other path, an empty diff or a failed detection runs the
full jobs, and pushes to `main` always run them. Repository hygiene always runs
and checks commit whitespace for documentation-only changes too. CodeQL uses
GitHub's default setup outside these workflow files and is not skipped.
The Swift jobs restore `.build` with `actions/cache`, keyed by job, Swift
toolchain and the hashes of `Package.swift`, `Sources/` and `Tests/`; the
bundle script still recreates the app bundle on every run.

The local Mac runs macOS 27 and exposes only the macOS 27 SDK. It cannot
reproduce the macOS 14 runtime either; a passing local build on macOS 27 is no
macOS 14 compatibility evidence.

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
Hardened Runtime flag, boolean `com.apple.security.device.audio-input`
entitlement and signed Keychain helper. Run `./scripts/verify-app.sh /path/to/OpenDictate.app` to repeat
these checks without rebuilding or launching. A missing or false entitlement
must fail verification, even when the signature itself is valid.

After bundle or packaging changes, run the controlled failure fixtures against
the built app:

```bash
bash scripts/tests/test-verify-app.sh .build/OpenDictate.app
```

The fixtures use temporary copies and ad-hoc signing. They verify rejection of
missing, false and wrongly typed audio-input entitlements, missing Hardened
Runtime, a missing Keychain helper and broken signatures. The original bundle must remain unchanged. The
tests do not launch the app, access a microphone or change a user's signing
identity, Keychain or permissions. CI runs them before packaging its development
archive and verifies the archive again after extraction.

## Developer ID release candidate

This path prepares and validates a private release candidate. It does not
authorize a notary upload, installation or app launch. Before the release path
is exercised, check these failure cases:

- Missing or malformed Developer ID identity stops before Swift compilation;
  an invalid or non-Developer-ID identity stops before signing. Release mode
  never falls back to ad-hoc signing.
- A dirty checkout, source-revision mismatch, missing explicit build number or
  non-arm64 build stops before packaging.
- A wrong signing team, different app/helper identities, missing secure
  timestamp, missing Hardened Runtime or missing microphone entitlement fails
  verification.
- An unset notary profile is rejected before submission. A name that is not a
  stored profile is left to notarytool's credential diagnostic; do not create or
  replace profiles as part of this workflow.
- A notary result other than Accepted must not be stapled or packaged. A missing
  or invalid stapled ticket, failed Gatekeeper assessment, changed archive
  contents or existing output directory stops before a release directory is
  produced.

For a later, separately authorized release attempt, first build on a clean,
committed checkout. The identity value is the public signing identity name, not
a password or private key:

```bash
OPENDICTATE_BUILD_MODE=release \
OPENDICTATE_BUILD_NUMBER=42 \
OPENDICTATE_SIGN_IDENTITY='Developer ID Application: Example Team (ABCDE12345)' \
./scripts/build-app.sh
```

The build signs the app and Keychain helper with that identity, uses the
arm64 macOS 14 target, secure timestamps and Hardened Runtime, then checks the
team and microphone entitlement. The bundle output is `.build/OpenDictate.app`;
compiler and generated icon artifacts remain under `.build/`.

Notarization remains a manual step. Keep the named profile in Keychain and use
no password, API key or private-key path in the command or environment. Keep
the temporary ZIP and JSON result outside the repository:

```bash
(
set -euo pipefail
: "${NOTARY_PROFILE:?Set this to the name of an existing notarytool Keychain profile}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/opendictate-notary.XXXXXX")"
printf 'Retain notarization evidence from: %s\n' "$WORK_DIR"
NOTARY_ZIP="$WORK_DIR/OpenDictate-notary.zip"
NOTARY_RESULT="$WORK_DIR/notary-result.json"
ditto -c -k --sequesterRsrc --keepParent .build/OpenDictate.app "$NOTARY_ZIP"
xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" \
  --wait --no-progress --output-format json > "$NOTARY_RESULT"
SUBMISSION_ID="$(plutil -extract id raw -expect string -o - "$NOTARY_RESULT")"
xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$NOTARY_PROFILE" \
  "$WORK_DIR/notary-log.json"
python3 - "$NOTARY_RESULT" <<'PY'
import json
import sys
from pathlib import Path

result = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if result.get("status") != "Accepted":
    raise SystemExit(f"Notary status is {result.get('status')!r}; do not staple or package.")
print(f"Notary accepted submission {result.get('id', '<id missing>')}")
PY
xcrun stapler staple .build/OpenDictate.app
xcrun stapler validate .build/OpenDictate.app
./scripts/package-release-app.sh .build/OpenDictate.app \
  /absolute/path/to/new-release-directory ABCDE12345
)
```

Retain the submission result and notary log with the candidate evidence,
including on failure. Inspect any warnings in the log before distribution.
After retaining the evidence, remove only this temporary working directory.

The final packaging command verifies the signed and stapled bundle, creates the
final ZIP and manifest in a new directory outside the checkout, extracts that
ZIP into a temporary directory, and verifies the extracted signature, ticket,
architecture and Gatekeeper assessment before publishing either output file.
The manifest binds version, build number, clean Git revision, Developer ID team,
architecture and final ZIP SHA-256. Packaging does not install or launch the
app and does not check Keychain ACL migration or microphone behavior. The
release helper is syntax-checked in CI; signing and notarization remain local,
and CI builds only ad-hoc development archives.

Documentation-only changes: run `git diff --check`, verify changed local links
and review ownership, conflicting rules and evidence scope. Include new files
in that review. Do not rerun app tests solely for prose changes.

Linux changes (`linux/`): run these on a Linux host. They are not part of
the macOS Swift CI workflow. CI installs and selects Rust 1.98.1; the local
script disables Rustup auto-install and requires that exact active Rust and
Cargo version. It does not change toolchains. Both use the checked-in lockfile.
With the required toolchain and ALSA headers already available, run the same
entry point as CI:

```bash
bash scripts/ci/check-linux.sh
```

The script runs formatting, locked tests, locked Clippy and a locked release
build. On Ubuntu, CI installs `libasound2-dev` and `pkg-config` first.

After a change to `linux/Cargo.lock`, check the crate list in
`THIRD_PARTY_NOTICES.md` and regenerate it without `--check` if it differs
(it reads the lockfile and never changes it; the Linux CI job runs the check
after its build, offline from the downloaded crates):

```bash
python3 scripts/third-party-rust.py --check --offline
```

For changes to the Arch package (`linux/packaging/arch/PKGBUILD`), run on an
Arch host as a normal user, from that directory:

```bash
makepkg -sf && namcap PKGBUILD opendictate-*.pkg.tar.zst
```

`makepkg` runs the crate tests in `check()` and refuses to build when `pkgver`
differs from the version in `linux/Cargo.toml`. Installing the package
(`makepkg -si` or `pacman -U`) changes the system and belongs to the attended
installation check.

Do not add this crate to `.github/workflows/checks.yml`. Live microphone,
Secret Service writes, OpenAI requests and Wayland clipboard checks require
separate attended verification and are not default tests. The transcription
tests may use loopback stub HTTP only. Never pass an API key as a command
argument or environment variable.

The dated [HTTP-fixture concurrency evidence](docs/linux-ci-fixture-race-2026-09-30.md)
records the isolated test-file repair and its bounded regression checks.

## Windows snapshot checks

The separate [Windows README](windows/README.md) defines the current build
and check scope. On Windows, from the repository root:

```powershell
./windows/scripts/check.ps1
```

This runs 58 core, flow, provider and shortcut checks (the provider checks read
`fixtures/provider/`) and builds the beta app and the Windows protection
checker. It does not execute the 15 protection checks. They use synthetic
files and an isolated dummy Credential Manager entry; run them from a separate
test copy in the signed-in Windows desktop with normal user privileges. Since
16 October 2026 Claude runs them on Basti's PC xmg without a Go (see
`AGENTS.md`):

```powershell
dotnet run --no-restore --project windows/OpenDictate.WindowsChecks -c Release
```

Verify deletion of the dummy credential and owned test files afterwards.
SSH Session 0 is not equivalent to an interactive desktop credential test.
Neither command proves live dictation, installation or public release readiness.

Without a Windows computer, the same 58 checks and the builds run on Linux
with .NET SDK 10.0.401:

```bash
dotnet run --project windows/OpenDictate.Checks -c Release
dotnet build windows/OpenDictate.App -c Release -p:EnableWindowsTargeting=true
dotnet build windows/OpenDictate.WindowsChecks -c Release -p:EnableWindowsTargeting=true
```

NuGet packages are pinned in each project's `packages.lock.json` and come only
from nuget.org (`windows/nuget.config`). Windows CI restores with
`dotnet restore <project> --locked-mode` and fails when a package differs from
the lock file. After changing a package reference, regenerate the lock files
with `dotnet restore windows/OpenDictate.App -p:EnableWindowsTargeting=true`
(likewise for `OpenDictate.Checks` and `OpenDictate.WindowsChecks`) and commit
them; the lock files carry no runtime-specific entries, so Linux and Windows
produce the same files.

After a change to `design/tokens.json`, `scripts/design-tokens.py` also
regenerates `windows/OpenDictate.Core/DesignTokens.cs`; after a change to the
Blink logos or the app icon, `python3 windows/scripts/make-icon.py` rebuilds
the Windows icon.

The Windows workflow uses `windows-2025`, selects the SDK from
`windows/global.json`, and runs only `windows/scripts/check.ps1`. It does not
run the interactive Credential Manager checks.

## iOS app

CI builds the beta app in `ios/OpenDictate.xcodeproj` on every change under
`ios/` (workflow `iOS prototype`, macOS 26 runner, because the app uses iOS 26
APIs). Locally on the Mac, the same formatter check and unsigned simulator
build run with:

```bash
bash scripts/ci/check-ios-prototype.sh
swift format lint --strict --configuration .swift-format --recursive ios/UITests ios/UnitTests
```

The unit tests in `ios/UnitTests` check kept recordings (tag, expiry, five
newest), the silence check, the settings a dictation reads, and the requests it builds. They run
inside the app and change its settings for a moment, so run them only in the
simulator, and signed as Xcode does by default: with
`CODE_SIGNING_ALLOWED=NO` the app has no Keychain, and the tests for kept
recordings skip themselves. The simulator is created once with
`xcrun simctl create "OpenDictate iOS Beta" "iPhone 17"`:

```bash
xcodebuild test -project ios/OpenDictate.xcodeproj -scheme OpenDictateiOS \
  -destination 'platform=iOS Simulator,name=OpenDictate iOS Beta' \
  -only-testing:OpenDictateiOSTests
```

The UI tests in `ios/UITests` drive the app and attach screenshots to the
result bundle (`xcrun xcresulttool` exports them). `testScreens` needs nothing
else and puts back every setting it changes; run it in a simulator before every
install, in the same simulator:

```bash
xcodebuild test -project ios/OpenDictate.xcodeproj -scheme OpenDictateiOS \
  -destination 'platform=iOS Simulator,name=OpenDictate iOS Beta' \
  -only-testing:OpenDictateiOSUITests/OpenDictateUITests/testScreens \
  -resultBundlePath /tmp/opendictate-ui.xcresult
```

The live tests (`testDictationInApp`, `testShortcutPastesIntoNotes`) run on
the iPhone next to the Mac, by cable or over the same Wi-Fi once the iPhone is
paired and unlocked, and are skipped unless `TEST_RUNNER_OD_KEYWORDS`
names words the spoken sentence must produce. While they run, the Mac speaks
the sentence repeatedly, for example
`while true; do say -v Anna "Heute teste ich den Kurzbefehl"; sleep 2; done`,
and the run passes `TEST_RUNNER_OD_KEYWORDS="heute,kurzbefehl"` with
`-destination 'platform=iOS,id=<iPhone>'` and one
`-only-testing:OpenDictateiOSUITests/OpenDictateUITests/<test>` per live test,
so `testScreens` stays in the simulator. The shortcut test uses the
person's own shortcut "Diktieren", started by its name, and Notes; it needs
"Enable UI Automation" in the iPhone's developer settings. If Shortcuts asks
whether the shortcut may hand on its text, the test allows it once only, and it
empties its note again so Notes drops it. A passed live test shows that
a dictation arrives, not how well speech is recognized.

The build proves neither a background start nor a clipboard write. Before a
build goes to the iPhone, the Mac checks it in the simulator with screenshots.
Since 13 October 2026 the device check on Basti's iPhone needs no Go: Claude
installs test builds and runs automated tests there, real dictations included,
following the acceptance list in [docs/ios-konzept.md](docs/ios-konzept.md).
Only Back Tap itself stays a short manual look by Basti. Uploading to
TestFlight is a publication and needs Basti's explicit Go.

## iOS keyboard prototype (superseded)

The September keyboard prototype in `ios/OpenDictateKeyboardDemo.xcodeproj` is
no longer built by CI. To rebuild it by hand, use the command in
[ios/README.md](ios/README.md#offline-simulator-build). The build uses a
generic iOS Simulator destination and does not boot a simulator or prove
keyboard installation or live text insertion. Follow
[ios/PRUEFPLAN.md](ios/PRUEFPLAN.md) for the visible Safari fixture check;
[simulator evidence](docs/ios-keyboard-e2e-2026-09-29.md) and
[physical-device evidence](docs/ios-device-2026-09-30.md) identify their exact scope.

## Workflow and secret checks

Run the same repository-hygiene checks as CI:

```bash
bash scripts/ci/check-workflows.sh
bash scripts/ci/scan-secrets.sh [base-commit] [head-commit]
```

Workflow lint downloads pinned actionlint 1.7.12 to a temporary directory and
checks every external action reference for a full commit SHA. It then installs
zizmor 1.30.1, pinned by SHA-256, into a temporary virtual environment and runs
its offline security audit of the workflows; `.github/zizmor.yml` records the
one accepted finding (Auto-Merge's `workflow_run` trigger) and why. The secret scan
downloads Gitleaks 8.30.1 to a temporary directory, verifies its published
SHA-256, and scans only the selected Git commit range. CI passes the pull
request base SHA and checked-out `github.sha` (the merge result), or the push
before/after SHAs. Merge commits are scanned against their first parent so
changes resolved during a merge are included.
A range scan reads `.gitleaksignore` from the base commit, so a pull request
cannot allow its own findings; Gitleaks scans the Git directory, so neither a
`.gitleaksignore` nor a `.gitleaks.toml` in the checked-out tree takes effect.
With no arguments, the local script scans the full history reachable from
current `HEAD` with the checkout's `.gitleaksignore`. Gitleaks redacts findings in output and does not contact
providers to validate credentials.
The scanner keeps its redacted JSON report in its private temporary directory,
then prints only rule, file, line, commit and fingerprint metadata; it omits
secret content and commit author details. Temporary scanner files are deleted
when the script exits.

The full-history scan allows only 31 exact fingerprints in
`.gitleaksignore`. They cover a Chrome extension manifest public key and
30 SHA-256 source/test-file digests in the dated coverage reports; each digest
was checked against its source blob at the recorded revision. The Chrome
manifest key is public by design and keeps the extension ID stable ([Chrome
manifest key](https://developer.chrome.com/docs/extensions/reference/manifest/key)).
The findings were suppressed by commit, path, rule and line fingerprint, not
by excluding files or directories ([Gitleaks fingerprint ignores](https://github.com/gitleaks/gitleaks#additional-configuration)).
New or changed findings remain visible and fail the scan.

`scripts/website-worker.py` marks `FILES` entries in `website/worker.js` whose
path looks like a secret name (such as `/tokens.css`) with an inline
`// gitleaks:allow`. Their values are SHA-256 prefixes of public website files,
so the pin pull request after a deploy needs no separate ignore-file change.

To allow a new false positive, keep the ignore file and the finding in separate
pull requests, because a range scan reads `.gitleaksignore` from the base
commit:

1. Open the pull request with the finding and take the fingerprint
   (`commit:file:rule:line`) from its failed scan.
2. Add that fingerprint to `.gitleaksignore` in a separate pull request.
   Auto-Merge leaves it to Claude because the file is guarded; Claude merges it.
3. Give the first pull request a new event without rebasing it (a rebase
   changes the commit and so the fingerprint): push a further commit or close
   and reopen it. The new event scans against the new base; a re-run of the
   old run would not, because it keeps the base of its original event. Avoid
   merging `main` into it: the merge commit would report allowed findings
   from `main` again under its own fingerprint.
4. A squash merge creates a new commit on `main`, so its push scan reports the
   finding again under the new commit's fingerprint. Add that one the same way.

A `gitleaks:allow` comment on the line itself still suppresses a finding
without this detour; it is visible in review and should stay the exception.

Dependabot groups weekly updates for the repository's Actions, Cargo, NuGet
(every project under `windows/`) and Swift (the iPhone app's
`Package.resolved` in its Xcode project) dependencies and proposes .NET SDK
updates for `windows/global.json`, with at most three open update pull
requests per ecosystem. Auto-Merge skips these pull requests because Dependabot is
not the repository owner; a Claude session or a manual review handles them
(see [SECURITY.md](SECURITY.md)).

## Shared provider fixtures

`fixtures/provider/` holds the provider contract (`CONTRACT.md`), the success
and error responses and `cases.json` with the expected message per platform.
The Swift tests `TranscriptionRequestTests` and `TranscriptionTransportTests`
read these files, and so do the Linux tests in `transcribe.rs`
(`tests::contract`), and the Windows provider checks in
`windows/OpenDictate.Checks/ProviderChecks.cs`; change the fixtures and the
contract together.

## Meaning of checks

The rationale for the retained and removed isolated tests is recorded in
[`docs/test-signal-audit.md`](docs/test-signal-audit.md).

- `swift test -Xswiftc -warnings-as-errors`: offline logic, lifecycle, HTTP stubs, recovery, logging and synthetic audio-file tests, with compiler warnings treated as failures. Optional benchmark and live API test are skipped by default.
- `python3 -m unittest discover ...`: offline regression tests for the transcript evaluator and process sampler, including output-file preservation, and for the design-token generator (generated files under `design/generated/` and the Swift and C# copies must match `design/tokens.json`), for `scripts/website-worker.py` (the website Worker's file hashes must match its pinned commit), for `scripts/website-i18n.py` (the generated pages, subtitles and sitemap in every language must match `website/i18n/`, and the product name comes only from `website/i18n/site.json`), and for which paths make Auto-Merge (`.github/scripts/auto_merge.py`) leave a pull request to Claude: anything under `.github/`, `scripts/ci/` or `.claude/`, plus `CLAUDE.md`, `AGENTS.md`, `.gitleaksignore` and `.gitattributes`, because a pull request must not merge itself when it changes the checks or rules that judge it. CI clones only two commits, so it skips that pin check; run `python3 scripts/website-worker.py --check` locally before deploying the Worker; a change to `website/worker.js` runs the full jobs, so these Python tests run with it.
- `swift format lint --strict --configuration .swift-format --recursive Sources Tests Package.swift`: project formatting; lint warnings cause a failed check.
- `./scripts/build-app.sh`: release bundle, Plist, signature and Hardened Runtime verification. Does not launch/install it.
- `git diff --check` and `bash -n` for all scripts listed above before handoff.
- Real microphone, hotkeys, direct target-field insertion, clipboard fallback and VoiceOver require attended native-app acceptance; an accessibility tree alone is not a VoiceOver listening test.
- After changing the insertion mechanism, recheck the affected categories and
  scenarios in `docs/compatibility-matrix.md`. Historical checks validate only
  their installed candidate.
- The lifecycle tests use controlled callbacks and a fake recorder/transcriber to
  exercise cancellation, delayed permission results and quit/drain ordering. They
  do not execute native permission dialogs or prove microphone/device behavior.
- The API-key tests inject Keychain results without accessing the real Keychain.
  The installed signed helper is kept unchanged across ordinary app rebuilds.
  Verify the actual legacy API-key and recovery-key reads after their one-time
  macOS approvals, then verify both again after changing only the main app
  build. The offline signed-host ping checks identity and IPC without reading a
  credential; it does not prove the real Keychain ACL. If legacy cleanup reports
  a warning, saving again retries it; never use a real credential in automated
  checks.

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

## Dictation indicator

Offline, `swift test` covers the mapping from window states to indicator
words, the choice of variant per screen (notch, menu bar, floating, off, full
screen), the recording line and countdown, the daily menu order, and, on a Mac
with a screen, that the shown indicator window cannot become key or main. That
test briefly orders a real window above the menu bar; without a screen it is
skipped. `BlinkConformanceTests` runs the design
system's own web component (`design/components/web/bundle.js`) in
JavaScriptCore and compares every pixel run of Blink with the Swift port.

Two debug-only modes need no hotkey, microphone, Keychain or provider:

```bash
swift build
.build/debug/OpenDictate --indicator-snapshots /tmp/indicator   # one PNG per variant and state
.build/debug/OpenDictate --indicator-preview [--style menuBar|floating|off] [--simulate-notch]
```

Run them from the checkout so the brand fonts in `design/fonts` are found; a
built bundle loads them from `Contents/Resources/Fonts`. The preview cycles the
real indicator through every state on the current screen. Snapshots and the
preview are visual checks only. The deciding live test is a real dictation
into another application with the indicator visible: the text must arrive by
Command-V in that application, and OpenDictate must not become the active app
while the indicator appears, changes or closes. Repeat it with the menu bar style ("In der Menüleiste"), with "Aus", over a full-screen app, and on a MacBook with a notch (its sizes in
`IndicatorMetrics` were confirmed with the preview on a 15-inch MacBook Air).

## Compact settings acceptance

Inspect the actual installed settings at compact and larger window sizes. The
four main options must be visible without a large leading blank area. Navigate
with Tab/Shift+Tab and activate “Erweitert”, “Aufnahmen” and “Hilfe” with Space.
Inspect menus/dialog entry points without changing preferences or sending a
recording. Confirm that cancellation, discard, copy and clear remain accessible
from the dictation window's “Weitere Aktionen” (open it with “Letzten Text
ansehen” in the menu). Compare preference and recovery
file integrity before/after; do not delete recordings created by the user.

## Repräsentative Kompatibilitätsabnahme

Before extending the isolated fixtures, account for these failure cases:

- No saved reference must be reported as unavailable, never as a pass or a
  result left over from an earlier field.
- A missing field, out-of-bounds selection, selection outside the chosen field,
  or a changed field choice must be rejected before comparison.
- Compare the entire resulting field so lost or duplicated text before or after
  the insertion is reported.
- Cover multiline separators, supplementary and joined emoji, and a combining
  accent. Mismatches must report raw UTF-16 lengths and the first differing
  offset; contenteditable comparisons must use its visible line breaks.
- A canonical NFC match after a raw mismatch is diagnostic only. It must remain
  an `ABWEICHUNG`, never become `EXAKT`.
- Preparation must modify only the selected controlled fixture field, reset it
  to its known harmless baseline, and set a validated caret or range. It must
  never write the expected probe into that field; result comparison is read-only.
- The preview minimum-width action must resize and show only the actual preview
  panel at its declared `window.minSize.width`, preserving its height and
  position where possible and leaving other app and user windows unchanged.
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
In the HTML fixture, choose a comparison field, reset its known harmless
starting text, set a caret or selection, and save the reference before the
production-fixture action. Preparation modifies only that selected field; it
never inserts the expected probe. The comparator accepts `input`, `textarea`,
the inner `iframe` textarea and the fixture's plain-text `contenteditable`.
For `contenteditable` it reads visible `innerText` line breaks and deliberately
supports only the fixture's single-text-node baseline, not general rich text.
`EXAKT` means the complete resulting string matches in raw UTF-16 units,
including the surrounding text, surrogate pairs, line breaks and trailing
whitespace. The separate NFC diagnostic never changes a raw `ABWEICHUNG` into
`EXAKT`; comparison itself is read-only. It does not check the final caret
position.
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
On the restored Command-V path, text with a line break is not pasted
automatically into known terminals (it stays on the clipboard); a single line
is pasted. Test Terminal only with a harmless single-line phrase and a
disposable, empty shell prompt.

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

## Local Linux packaging (no publication)

```bash
bash -n scripts/package-linux.sh
bash scripts/package-linux.sh --help
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts/tests -p 'test_package_linux.py' -v
```

On a Linux host with the existing pinned toolchain and ALSA dependencies, run
`package-linux.sh --tag linux-v0.1.0-beta.2 --output /absolute/new/directory` from
a clean checkout. The requested version must match Cargo.toml and PKGBUILD;
no tag is created. Run `--verify` on the binary archive. Build a second time
into a different new directory and compare SHA256SUMS before claiming
reproducibility. Refusal tests run offline on macOS too; they do not prove a
Linux release binary or reproducibility. No CI workflow was changed.
