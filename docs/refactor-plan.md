# OpenDictate Refactor Plan

> **Purpose:** Turn the 1240-line single-file prototype into a maintainable package without changing what the app does.
> **Scope:** `Sources/OpenDictate/main.swift`, `Package.swift`, `scripts/build-app.sh`.
> **Status:** 2026-07-29. Stages 1 and 2 done. Stage 3 open.

## Where we are

The app works and the internal structure is already reasonable: `Config`, `AppLog`,
`AudioInput`, `AppDelegate`, `HotKeyManager`, `AudioRecorder`, `AudioPreprocessor`,
`OpenAITranscriber`, `PasteboardInserter`, `OpenDictateError`, `KeychainAPIKeyStore`.
Those are real seams. They just all live in one file and are all `private`.

So this is mostly a *file split plus three behavioural fixes*, not a rewrite.

## What actually hurts

| # | Problem | Evidence | Impact |
|---|---------|----------|--------|
| 1 | Everything in one file, everything `private` | `Sources/OpenDictate/main.swift` (1240 lines) | Nothing is unit-testable, nothing is reusable |
| 2 | No test target | `Package.swift` has one executable target only | Every change is verified by hand |
| 3 | A failed upload destroys the recording | `stopAndTranscribe()` `defer` block deletes the audio on every path, incl. network failure (main.swift:298-303) | Speak 90 s, lose Wi-Fi, audio gone |
| 4 | Settings are read once at process start | `Config` uses `static let` over `ProcessInfo` (main.swift:9-20) | Changing model or language needs an app restart and a terminal |
| 5 | `AppDelegate` is a god object | ~400 lines: menu bar, permissions, alerts, orchestration, hotkey wiring | Hard to change one thing without touching everything |
| 6 | Hotkey is hardcoded | `kVK_Space` + `optionKey|shiftKey` (main.swift:147) | Collides with other apps, no way out for the user |

## Guardrails

- **No behaviour change in stages 1 and 2.** Same hotkey, same flow, same menu.
- Ship each stage as its own commit. Build and hand-test dictation after each.
- Keep `Package.swift` on SwiftPM. No Xcode project, no new dependencies.
- The app must keep its stable signing identity, or macOS drops the Accessibility
  grant. See `docs/accessibility-signing.md` before touching `scripts/build-app.sh`.

## Stage 1: split the file (DONE)

Shipped as two commits so the risky half is reviewable on its own:

- **1a** pure file split, proven lossless line by line.
- **1b** `AppDelegate` 409 -> 243 lines, with `MenuBarController`,
  `AlertPresenter`, `ApplicationMenu` and `SystemSettings` extracted.

Deviation from the layout below: `@main` has to sit on the type that owns
`static func main()`, so there is no separate `OpenDictateApp.swift`.
`ApplicationMenu.swift` and `System/SystemSettings.swift` were added instead.

Verified: `swift build` clean, app bundle signs with the stable identity,
launches from `/Applications`, registers the hotkey. A full spoken dictation
round trip was **not** tested, that needs a human at the microphone.

### Planned layout

Move each existing type into its own file. Change `private` to `internal` only where
the split forces it. Nothing else.

```text
Sources/OpenDictate/
  App/
    OpenDictateApp.swift        // @main, static main(), NSApplication setup
    AppDelegate.swift           // lifecycle + orchestration only
    MenuBarController.swift     // status item, menu, status text, tooltips
    AlertPresenter.swift        // showAlert, accessibility alert, bluetooth warning
    APIKeyInputView.swift       // as-is
  Audio/
    AudioRecorder.swift
    AudioPreprocessor.swift     // largest single unit, ~195 lines
    AudioInput.swift
    PreparedAudio.swift         // PreparedAudio, AudioAnalysis, ExportSessionBox
  Transcription/
    OpenAITranscriber.swift
    OpenAIAPIErrorMessage.swift
    TranscriptionModel.swift    // new: named cases instead of raw strings
  System/
    HotKeyManager.swift
    PasteboardInserter.swift
    KeychainAPIKeyStore.swift
  Support/
    Config.swift
    AppLog.swift
    OpenDictateError.swift
    Extensions.swift            // TimeInterval, Float, Data helpers
```

**Done when:** `swift build` is clean and dictation still works end to end.

## Stage 2: make the core testable (DONE)

`OpenDictateCore` now holds `Formatting`, `OpenDictateError`, `OpenAIAPIError`,
plus three types extracted from the app: `AudioLevels` / `SpeechRangeAccumulator`
(the silence decision), `TrimPlanner` (the padding and clamping maths) and
`TranscriptionModel`. 34 tests in 7 suites, `swift test` green.

`TranscriptionModel` earns its keep beyond typing: the app now warns at launch
when `OPENAI_TRANSCRIBE_MODEL` names a realtime-only model, instead of failing on
the first dictation. Unknown identifiers still pass through untouched.

**Not done:** step 3, the `TranscribingService` protocol. `OpenAITranscriber` is
40 lines of multipart assembly around one `URLSession` call and reads `Config`
directly. Faking it well means injecting configuration and a `URLProtocol` stub,
which is more machinery than the current risk justifies. Revisit if the upload
path grows retries or streaming.

### Original plan

1. Add a `OpenDictateCore` library target and an `OpenDictateTests` test target.
   `OpenDictate` (executable) depends on `OpenDictateCore`. AppKit-bound code
   (`AppDelegate`, `MenuBarController`, `APIKeyInputView`) stays in the executable.
2. Move into `OpenDictateCore`: `AudioPreprocessor` analysis maths, `OpenDictateError`
   messages, `OpenAIAPIErrorMessage.humanReadableMessage`, the numeric extensions,
   and a new `TranscriptionModel` enum.
3. Put a protocol in front of the network call (`TranscribingService`) so tests can
   inject a fake instead of hitting the API.

First tests to write, in this order:
- silence detection: silent buffer, quiet buffer, loud buffer
- trim maths: audio shorter than the padding must not produce a negative range
- `humanReadableMessage` for 401, 429, 413 and a malformed body
- `TimeInterval.formattedSeconds` boundaries

**Done when:** `swift test` passes and covers the four groups above.

## Stage 3: fix the three real defects

**3a. Keep the audio when transcription fails.** On any error other than
"skipped recording", move the prepared file to
`~/Library/Application Support/OpenDictate/failed/<timestamp>.m4a` instead of
deleting it, and add a `Retry last recording` menu item. Prune that folder to the
last 5 files on launch.

**3b. Make settings live and visible.** Replace `Config`'s `static let` with a
`Settings` type backed by `UserDefaults`, seeded from the env vars for backwards
compatibility. Add a menu submenu:
- Model: `gpt-transcribe` (default) / `gpt-4o-mini-transcribe`
- Language: Auto / German / English
No restart, no terminal.

**3c. Make the hotkey configurable.** Store keycode and modifiers in `Settings`.
A recorder UI is out of scope here; a menu with three presets
(`Option+Shift+Space`, `Control+Option+D`, `F5`) covers the collision case at a
fraction of the effort.

## Explicitly out of scope

- **Live/streaming transcription.** `gpt-live-transcribe` needs
  `v1/realtime/transcription_sessions`, a persistent socket, and partial-result UI.
  That is a feature project, not a refactor, and it costs 0.017 $/min against
  0.0045 $/min. Revisit only if you want text to appear while speaking.
- Local Whisper, multi-language auto-switching, a preferences window, SwiftUI.

## Order and effort

| Stage | Risk | Rough size |
|-------|------|-----------|
| 1 file split | very low | one sitting |
| 2 test target | low | one sitting |
| 3a lose-no-audio | low | small |
| 3b live settings | medium, touches the menu | medium |
| 3c hotkey presets | low | small |

Stage 1 and 2 are worth doing regardless. Stage 3a is the one with actual user
value. 3b and 3c only matter if the app annoys you in daily use.
