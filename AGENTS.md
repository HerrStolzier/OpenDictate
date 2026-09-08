# OpenDictate repository practices

## Scope and architecture

- Keep the project SwiftPM-first and compatible with macOS 14 or newer.
- Keep `OpenDictateCore` free of AppKit, AVFoundation, networking, Keychain access, and process-wide globals.
- `AppDelegate` wires lifecycle, hardware, services, and UI. Put state and recovery decisions in `DictationFlow`, menu rendering in `MenuBarController`, background recording metadata in `RecordingLibrary`, and HTTP request construction in `OpenAITranscriber`.
- Prefer a small named type or helper when it removes duplicated policy. Do not add a dependency for behavior the standard macOS or Swift APIs already provide clearly.

## Behavioral invariants

- Never delete the only surviving audio after a failed, cancelled, empty, or undelivered transcription. Preserve the original if the authenticated recovery copy cannot be created.
- Retry only authenticated recordings, upload the bytes that were authenticated, enforce expiry at access time, and never upload legacy or heuristic-skipped audio automatically.
- Keep recording, processing, delivery, cancellation, and retry mutually consistent through `DictationState`. Do not start overlapping provider requests.
- Auto-paste may target only the application captured for that dictation and only while it is still the frontmost application. Clipboard-only fallback must remain available.
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

Run after source changes:

```bash
swift format lint --configuration .swift-format --recursive Sources Tests Package.swift
swift test -Xswiftc -warnings-as-errors
bash -n scripts/build-app.sh
bash -n scripts/store-api-key.sh
```

For release- or packaging-related changes, also run `./scripts/build-app.sh` and verify the generated Plist and signature. A build does not prove microphone, Accessibility, target-field paste, VoiceOver, signing identity persistence, installation, or publication.

Tests must remain offline and deterministic by default. Live microphone tests, provider requests, app launch/install, Keychain changes, TCC reset, signing-identity changes, commit, push, and publication each require the corresponding explicit authorization. Never turn a synthetic fixture or one successful dictation into a general speech-quality claim.

## Documentation ownership

- `README.md`: current product behavior and setup.
- `PRIVACY.md`: complete current data flow and retention behavior.
- `CHECKS.md`: reproducible verification commands and explicit live-test gates.
- `docs/remaining-acceptance.md`: behavior that is not yet evidenced.
- Dated acceptance files: historical evidence for that exact candidate only.

Update these documents in the same change whenever their claimed behavior changes.
