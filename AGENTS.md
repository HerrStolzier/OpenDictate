# OpenDictate repository practices

## Project context and authorized work

- Read `PROJECT.md` for product scope, pricing model and the decision log,
  `ROADMAP.md` for the sole feature/platform backlog (one track per platform),
  and `docs/remaining-acceptance.md` for the evidenced state per platform.
  Verify checkout state before relying on it.
- Every product or planning decision taken with Basti is recorded in the same
  session in the decision log of `PROJECT.md` (date, decision, link) and in the
  project memory. Decisions that stay in chat are lost later.
- Earlier project approvals are archived in `docs/archive/APPROVALS.md` as
  historical context; the archive is no longer maintained and grants nothing.
- Routine commits, pushes to this repository and merges of verified changes
  belong to an authorized implementation task under the governing workspace
  rules. Check deployment effects before push/merge; publication, loss of
  existing work or material scope expansion requires specific authorization.

## Scope and architecture

- Keep the project SwiftPM-first and compatible with macOS 14 or newer.
- Keep `OpenDictateCore` free of AppKit, AVFoundation, networking, Keychain access, and process-wide globals.
- `AppDelegate` wires lifecycle, hardware, services, and UI. Put state and recovery decisions in `DictationFlow`, menu rendering in `MenuBarController`, background recording metadata in `RecordingLibrary`, and HTTP request construction in `OpenAITranscriber`.
- Prefer a small named type or helper when it removes duplicated policy. Do not add a dependency for behavior the standard macOS or Swift APIs already provide clearly.

## Behavioral invariants

- Never delete the only surviving audio after a failed, cancelled, empty, or undelivered transcription. Preserve the original if the authenticated recovery copy cannot be created.
- Retry only authenticated recordings, upload the bytes that were authenticated, enforce expiry at access time, and never upload legacy or heuristic-skipped audio automatically.
- Keep recording, processing, delivery, cancellation, and retry mutually consistent through `DictationState`. Do not start overlapping provider requests.
- Auto-paste may activate only the application captured for that dictation. Before sending Command-V, verify that it is frontmost and that the clipboard still holds the transcript. Clipboard-only fallback must remain available. The focused field is not bound by this legacy path.
- Keep the API key in the macOS Keychain. Never accept it through command arguments, checked-in files, logs, fixtures, or process environment.
- Logs may contain bounded operational metadata, but never API keys, transcripts, or audio contents.
- Replace global hotkeys transactionally: retain the working registration and stored preference if a replacement fails.

## Code and UI conventions

- Use Swift 6 concurrency explicitly. Keep UI and AppKit work on `@MainActor`; isolate blocking file or metadata work away from menu opening.
- Follow `.swift-format`. Keep code and technical comments in English; keep user-facing menu text and routine status text in German.
- Derive UI availability from canonical state and data instead of storing duplicate booleans.
- Remove obsolete APIs and completed task notes instead of keeping commented-out or session-specific code. Preserve dated acceptance reports only when they still identify their exact historical scope.
- Keep the static `website/` dependency-free and keep its product, privacy, pricing, and release claims aligned with `README.md` and `PRIVACY.md`.

## Required verification

Run the source-change checks in `CHECKS.md` after source changes, and its bundle
checks for release or packaging changes. Documentation-only changes need link,
consistency and diff checks, not an unrelated source test suite.

Tests remain offline and deterministic by default. Live tests (microphone,
provider requests, app launch/install, Keychain) run when Basti is at the
device and gives an explicit "Go" in the session. Since 8 October 2026 only
the path every user takes (installation and one dictation) is verified by us;
single-case checks are left to beta users and listed as known limits. There are no counted test blocks,
quotas or advance approval documents. TCC resets, signing-identity changes and
publication still need Basti's explicit decision. Never turn a synthetic
fixture or one successful dictation into a general speech-quality claim.

## Documentation ownership

- `PROJECT.md`: product goal, use cases, pricing model, platforms with
  evidenced scope, limits, and the decision log.
- `ROADMAP.md`: sole current feature/platform to-do list, one track per
  platform plus cross-platform items and a done log. It does not grant
  implementation or publication approval.
- `docs/roadmap-neuordnung-2026-10-08.md`: reasoning behind the current order;
  earlier reorganisation notes are history.
- `docs/remaining-acceptance.md`: evidenced state, open limits and last
  evidence per platform. The former chronological handoff is archived in
  `docs/archive/uebergabe-chronik-bis-2026-10-07.md`.
- `docs/archive/README.md`: index of all dated reports; `docs/archive/APPROVALS.md`
  is the archived approval record up to 2 October 2026 and not maintained.
- `README.md`: current product behavior and setup (macOS); `linux/README.md`
  (English) and `linux/README.de.md` (German) for Linux; change both together.
  Linux CLI messages exist in German and English (`tr!` in `linux/src/i18n.rs`).
- `PRIVACY.md`: complete current data flow and retention behavior.
- `CHECKS.md`: reproducible verification commands and explicit live-test gates.
- `docs/compatibility-matrix.md`: current product-wide text-field and focus
  acceptance plan; programs are representative examples, not blanket support claims.
- `docs/linux-build-plan.md`, `docs/linux-live-translation-plan.md`,
  `docs/windows-plan.md`, `docs/ios-direction.md`: platform-specific
  implementation and acceptance detail linked from the roadmap.
- `docs/release-plans/`: detailed acceptance criteria for the Mac stages; their
  scope was reduced on 8 October 2026 as stated in the roadmap. Dated evidence
  applies only to its recorded candidate.
- Dated acceptance files: historical evidence for that exact candidate only.

Update these documents in the same change whenever their claimed behavior changes.
