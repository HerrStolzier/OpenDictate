# OpenDictate

Small macOS dictation prototype inspired by the VoiceScribe architecture:

1. Register a global hotkey.
2. Record microphone audio to a temporary `.m4a`.
3. Transcribe it through OpenAI's `/v1/audio/transcriptions` endpoint.
4. Copy the resulting text and paste it into the previously active app.

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

You can also start the app first and choose `Set API Key...` from the menu bar item. The app stores the key in the macOS Keychain either way.

Press `Option+Shift+Space` once to start recording, then press it again to stop, transcribe, and paste.

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
