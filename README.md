# OpenDictate

Small macOS dictation app inspired by the VoiceScribe architecture:

1. Register a global hotkey.
2. Record microphone audio to a temporary `.m4a`.
3. Transcribe it through OpenAI's `/v1/audio/transcriptions` endpoint.
4. Copy the resulting text and paste it into the previously active app.

The generated icon source lives at `Assets/OpenDictateIcon.png`. The build script converts it into `OpenDictate.icns` and also uses it for the menu bar item.

## Build

```bash
./scripts/build-app.sh
```

The script writes the app bundle to:

```text
.build/OpenDictate.app
```

## Run

The menu bar button opens a compact native AppKit dictation panel. Its Settings
button opens a separate native window retaining the existing settings, recovery
and diagnostic actions. A submitted paste shortcut is shown as an unconfirmed
delivery, never as verified insertion. The neutral heading is “Diktat verarbeitet.”
and the detail explains that automatic insertion was triggered and asks the user
to check the target program. Text remains selectable in the panel.

Recovery selection now asks for confirmation before resending the selected
recording. Retried text is copied only; retries never automatically paste into
another application.

The local daily launcher `./script/build_and_run.sh --daily` opens the existing
`~/Applications/OpenDictate.app` and reuses its instance. An explicit launch opens
the daily window; reopening the app brings that window forward. It refuses to
start alongside a preview or another dictation build.

For an isolated debug-only design preview, run `./script/build_and_run.sh --preview`.
It launches `OpenDictatePreview.app` with synthetic display states and a separate
bundle identifier, bypassing microphone, hotkeys, Keychain, clipboard and service
initialization. It does not replace the installed app. The preview build uses the existing native SwiftPM engine. The installed Swift
Testing plugin requires an explicit module path for test runs; see `CHECKS.md`.

The separate opt-in `--processing-focus-preview` is an offline integration fixture:
fixed text and delayed processing replace audio/provider work; production flow,
panel, clipboard and paste policy remain real. It waits for a disposable TextEdit
document, then provides 20 seconds to retain or change app focus. It restores the
previous clipboard on normal exit if no later clipboard change occurred. It never
reads credentials or existing recordings. This fixture requires its existing
Accessibility permission to be current; it is not a real dictation test.

```bash
./scripts/store-api-key.sh
open .build/OpenDictate.app
```

You can also start the app first and choose `API-Schlüssel einrichten …` from the menu bar item. The app stores the key in the macOS Keychain either way. The helper asks for the key itself; do not put an API key in a shell command or environment variable. The API key field supports normal macOS edit shortcuts such as paste, copy, and select-all. Use `API-Schlüssel anzeigen` in the dialog to keep the key visible until you uncheck it again.

Press `Option+Shift+Space` once to start recording, then press it again to stop, transcribe, and paste.

## Settings

The menu bar item carries the settings that change often. They apply to the next
dictation, no restart needed.

- **Hotkey** — custom modified shortcuts plus `Option+Shift+Space` (default), `Control+Option+D`, or `F5`. Useful
  when another app already claims the default.
- **Model** — `gpt-transcribe` or `gpt-4o-mini-transcribe`, with the per-minute
  price next to each.
- **Language** — Auto, German, or English. Auto lets the API detect it.
- **Vokabular und Kontext** — local prompt setting (up to 2,000 characters in the editor), sent with each dictation. A stored value overrides the legacy environment variable.
- **Automatisch einfügen** — disable for clipboard-only delivery. Switching foreground applications while a dictation is processing causes a clipboard-only fallback.
- **Letzten Text erneut kopieren** — recovers the last transcript without another API request. It is kept in RAM only and can be cleared.
- Saved recordings can be retried or deleted individually. Retry is disabled during recording and processing.

The menu bar shows recording time and a countdown in the last ten seconds. Cancel keeps the current audio; the separate discard action removes an active recording. The recorder also enforces the 90-second cap natively.

## If a transcription fails

A failed upload no longer throws the recording away. It keeps a recovery copy in
`~/Library/Application Support/OpenDictate/failed/`, and `Letzte Aufnahme wiederholen` in
the menu uploads it again. Recordings are authenticated with a device-local
Keychain secret before retry. At most five are kept, for at most 24 hours; pruning
runs at launch, after every keep and periodically while the app is open; expired recordings cannot be retried. A retry deletes the file only after a non-empty transcript has reached the clipboard. Clipboard failures keep both the audio and the last transcript in memory. Use
`Gespeicherte Aufnahmen löschen …` to delete all retained or legacy recordings.

Recordings classified as too short or too quiet are retained for a deliberate manual retry. These heuristics do not prove that no speech exists; they never trigger an automatic upload.

## Cost controls

OpenDictate keeps API usage lean by default:

- skips recordings shorter than 1 second
- auto-stops recordings after 90 seconds
- trims silence from the beginning and end before upload
- records speech-focused mono AAC at 24 kHz / 48 kbps
- defaults to `gpt-transcribe` ($0.0045/min), the accuracy-focused async model

Optional environment variables. A choice made in the menu wins over these, so the
menu is not silently ignored for anyone who exports them:

- `OPENAI_TRANSCRIBE_MODEL`, default `gpt-transcribe`. Set `gpt-4o-mini-transcribe` ($0.003/min) to trade accuracy for cost. Setting `gpt-live-transcribe` is caught at launch with a warning: it targets the realtime endpoint, not this upload flow.
- `OPENAI_TRANSCRIBE_LANGUAGE`, for example `de`
- `OPENAI_TRANSCRIBE_PROMPT`, for vocabulary hints. The in-app vocabulary setting overrides this value.

## Permissions

macOS will ask for:

- Microphone access for recording.
- Accessibility access for simulating `Cmd+V`.

OpenDictate cannot reliably confirm that the target control accepted `Cmd+V`, so
the transcript remains on the general clipboard until it is overwritten. This
also preserves manual paste when Accessibility or target activation fails.

See [PRIVACY.md](PRIVACY.md) for the complete data flow and retention behavior,
[docs/accessibility-signing.md](docs/accessibility-signing.md) for safe local
development signing, and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for the
VoiceScribe attribution and license notice.

## License

OpenDictate is available under the [MIT License](LICENSE). Third-party notices
remain in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

The local self-signed development build is not a signed and notarized public
binary. See [docs/accessibility-signing.md](docs/accessibility-signing.md) before
distributing binaries.

## Verification

Run `swift test` for pure logic, lifecycle, HTTP stubs, recovery, logging and synthetic audio-file tests. No microphone or OpenAI calls are part of these tests. `./scripts/build-app.sh` builds and verifies the bundle; `VERSION` controls the marketing version, and `OPENDICTATE_BUILD_NUMBER` can set the numeric build number (default 1). CI runs tests and an ad-hoc bundle build on macOS. This does not publish or install an app.

See [CHECKS.md](CHECKS.md), [docs/performance-decisions.md](docs/performance-decisions.md), [docs/audio-quality-fixtures.md](docs/audio-quality-fixtures.md) and [docs/remaining-acceptance.md](docs/remaining-acceptance.md). Live microphone, target-app, VoiceOver and paid API checks remain separate. Streaming and hold-to-talk are not enabled.
