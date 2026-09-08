# OpenDictate

Small macOS dictation app inspired by the VoiceScribe architecture:

1. Register a global hotkey.
2. Record microphone audio to a temporary `.m4a`.
3. Transcribe it through OpenAI's `/v1/audio/transcriptions` endpoint.
4. Copy the resulting text and insert it into the previously active app through Accessibility.

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

```bash
./scripts/store-api-key.sh
open .build/OpenDictate.app
```

You can also start the app first and choose `API-Schlüssel einrichten …` from the menu bar item. The app stores the key in the macOS Keychain either way. The helper requires the built app, creates only a new item and restricts it to that bundle. It intentionally fails if an item already exists. If an older helper created the item, do not rerun the helper: save the key once through the in-app dialog to recreate it under the app's access policy. The helper asks for the key itself, so do not put an API key in a shell command or environment variable. The API key field supports normal macOS edit shortcuts such as paste, copy, and select-all. Use `API-Schlüssel anzeigen` in the dialog to keep the key visible until you uncheck it again.

Press `Option+Shift+Space` once to start recording, then press it again to stop, transcribe, and insert.

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
- Accessibility access for inserting the transcript into the focused text control.

Automatic insertion sends the transcript directly to the target's focused
Accessibility text element; it does not consume the clipboard. The transcript
also remains on the general clipboard until it is overwritten, preserving
manual paste when Accessibility, target activation or direct insertion fails.
Some custom, browser or Electron text controls may not expose a settable
Accessibility selection; those controls receive the clipboard-only fallback.

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
