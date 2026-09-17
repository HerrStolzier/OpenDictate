# OpenDictate

Project orientation: [product and scope](PROJECT.md), [current handoff and open
acceptance](docs/remaining-acceptance.md), [project rules](AGENTS.md),
[recorded approvals](APPROVALS.md), [compatibility plan](docs/compatibility-matrix.md),
and [verification](CHECKS.md).

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

The menu bar button opens a compact native AppKit dictation panel. Its Settings
button opens a compact native window with microphone, shortcut, language and
automatic insertion. “Erweitert” reveals model, API key and vocabulary. Saved
recordings and Help have their own secondary pages. Recording/cancel/copy/clear
and quit actions are available from “Weitere Aktionen” in the recording panel.
Opening settings hides the recording panel so it cannot cover the controls.
Reactivating the app keeps an already open settings page in front.
Closing either window only hides it; the app and global shortcut remain active.
Click the menu bar icon to reopen the panel. Only “Beenden” quits the app. A submitted Accessibility insertion is shown as an unconfirmed
delivery, never as verified insertion. The neutral heading is “Diktat verarbeitet.”
and the detail explains that automatic insertion was triggered and asks the user
to check the target program. Text remains selectable in the panel.

The recording button returns focus to the most recently used application. Stopping
through the panel returns only to that same target if no other application was
selected meanwhile. Automatic status updates never take focus. Choose the target
text field before starting; the global shortcut remains available.

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

You can also start the app first and choose `API-Schlüssel einrichten …` from the menu bar item. The app stores the key in the macOS Keychain either way. The helper requires the built app, creates only a new item and restricts it to that bundle. It intentionally fails if an item already exists. If an older helper created the item, do not rerun the helper: save the key once through the in-app dialog to recreate it under the app's access policy. The helper asks for the key itself, so do not put an API key in a shell command or environment variable. The API key field supports normal macOS edit shortcuts such as paste, copy, and select-all. Use `API-Schlüssel anzeigen` in the dialog to keep the key visible until you uncheck it again.

Press `Option+Shift+Space` once to start recording, then press it again to stop, transcribe, and insert.

## Settings

The panel’s Settings window groups the four everyday options first. Advanced
options are collapsed initially; saved recordings and Help open secondary pages.
Changes apply to the next dictation, no restart needed.

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

Automatic insertion captures the target application, window, text element,
web document (when available) and selection when dictation starts. It only
delivers while that original target remains focused and its initial selection
range, when exposed, is unchanged. Protected, disabled and non-writable controls use the manual
fallback. Switching to another application during a dictation invalidates its
automatic target, even if you later return.

Insertion sends the transcript directly to the captured Accessibility text
element. Brave, Safari and Obsidian web editors use process-scoped Unicode keyboard events
instead because these editors can accept the Accessibility setter without
inserting text. This path rechecks the foreground application and focused field
between text chunks; it never sends a paste shortcut or consumes the clipboard.
Safari receives line breaks separately so text following a newline is not lost;
a CRLF pair remains one line break. Brave binds line breaks to preceding text
and keeps complete graphemes together within each event. Text that cannot fit
this rule (for example a leading line break or an unusually long grapheme)
uses the full clipboard fallback before sending any event. Obsidian retains
grouped text. These policies do not establish compatibility with every editor.
Candidate-specific acceptance is tracked in
[remaining acceptance](docs/remaining-acceptance.md). The transcript
also remains on the general clipboard until it is overwritten, preserving
manual paste when Accessibility, target identity or direct insertion fails.
Some custom, browser or Electron text controls may not expose a settable
Accessibility selection; those controls receive the clipboard-only fallback.

The recording panel shows elapsed time, the input level and the final countdown
to its automatic stop. The custom shortcut dialog supports Tab/Shift+Tab,
Escape and Return without requiring macOS full keyboard access.

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
