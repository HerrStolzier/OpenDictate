# OpenDictate

Small macOS dictation prototype inspired by the VoiceScribe architecture:

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

```bash
./scripts/store-api-key.sh
open .build/OpenDictate.app
```

You can also start the app first and choose `Set API Key...` from the menu bar item. The app stores the key in the macOS Keychain either way. The API key field supports normal macOS edit shortcuts such as paste, copy, and select-all. Use `Show API key` in the dialog to keep the key visible until you uncheck it again.

Press `Option+Shift+Space` once to start recording, then press it again to stop, transcribe, and paste.

## Cost controls

OpenDictate keeps API usage lean by default:

- skips recordings shorter than 1 second
- auto-stops recordings after 90 seconds
- trims silence from the beginning and end before upload
- records speech-focused mono AAC at 24 kHz / 48 kbps
- defaults to `gpt-4o-mini-transcribe`

Optional environment variables:

- `OPENAI_TRANSCRIBE_MODEL`, default `gpt-4o-mini-transcribe`
- `OPENAI_TRANSCRIBE_LANGUAGE`, for example `de`
- `OPENAI_TRANSCRIBE_PROMPT`, for vocabulary hints

For quick development runs, you can also launch the bundle executable directly with an environment variable:

```bash
OPENAI_API_KEY="sk-..." .build/OpenDictate.app/Contents/MacOS/OpenDictate
```

## Permissions

macOS will ask for:

- Microphone access for recording.
- Accessibility access for simulating `Cmd+V`.

If Accessibility paste is not enabled, OpenDictate still copies the transcript to the clipboard.
