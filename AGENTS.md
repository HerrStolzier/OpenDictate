# OpenDictate repository practices

## Project context and authorized work

- Read `PROJECT.md` for product scope and `docs/remaining-acceptance.md` for the
  single current handoff. Verify checkout state before relying on that handoff.
- Consult `APPROVALS.md` for evidenced project approvals; the record does not
  expand the original authorization or override later restrictions.
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

Tests remain offline and deterministic by default. Live microphone tests,
provider requests, app launch/install, Keychain changes, TCC reset, signing-identity
changes and publication require corresponding authorization. Use applicable
existing authorization without broadening it. Never turn a synthetic fixture
or one successful dictation into a general speech-quality claim.

## Documentation ownership

- `PROJECT.md`: product goal, scope, non-goals and grounded decisions.
- `APPROVALS.md`: evidenced project authorization, scope and validity.
- `README.md`: current product behavior and setup.
- `PRIVACY.md`: complete current data flow and retention behavior.
- `CHECKS.md`: reproducible verification commands and explicit live-test gates.
- `docs/compatibility-matrix.md`: current product-wide text-field and focus
  acceptance plan; programs are representative examples, not blanket support claims.
- `docs/remaining-acceptance.md`: single current handoff and behavior not yet evidenced.
- Dated acceptance files: historical evidence for that exact candidate only.

Update these documents in the same change whenever their claimed behavior changes.
