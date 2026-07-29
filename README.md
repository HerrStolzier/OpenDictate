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

## Settings

The menu bar item carries the settings that change often. They apply to the next
dictation, no restart needed.

- **Hotkey** — `Option+Shift+Space` (default), `Control+Option+D`, or `F5`. Useful
  when another app already claims the default.
- **Model** — `gpt-transcribe` or `gpt-4o-mini-transcribe`, with the per-minute
  price next to each.
- **Language** — Auto, German, or English. Auto lets the API detect it.

## If a transcription fails

A failed upload no longer throws the recording away. It moves to
`~/Library/Application Support/OpenDictate/failed/`, and `Retry Last Recording` in
the menu uploads it again. The five most recent are kept; older ones are pruned at
launch. A successful retry deletes the file.

Recordings that were *skipped* (too short, or no speech detected) are not kept,
because there is nothing in them to transcribe.

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
- `OPENAI_TRANSCRIBE_PROMPT`, for vocabulary hints. Environment only, no menu.

For quick development runs, you can also launch the bundle executable directly with an environment variable:

```bash
OPENAI_API_KEY="sk-..." .build/OpenDictate.app/Contents/MacOS/OpenDictate
```

## Permissions

macOS will ask for:

- Microphone access for recording.
- Accessibility access for simulating `Cmd+V`.

If Accessibility paste is not enabled, OpenDictate still copies the transcript to the clipboard.
