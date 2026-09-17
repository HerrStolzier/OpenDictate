# OpenDictate

Native dictation for macOS 14 and newer: press a shortcut, speak, then work with
text in your chosen application. OpenDictate uses your own OpenAI API key.
Audio is sent to OpenAI over HTTPS; transcription incurs separate API charges.

## First dictation

You need a Mac, internet access and an OpenAI API key. A public signed and
notarized download is not available yet. GitHub CI also retains explicitly
labelled [development archives](docs/development.md#ci-development-archives)
for later testing. To build from source, use Swift 6 on macOS:

```bash
./scripts/build-app.sh
open .build/OpenDictate.app
```

1. Open the menu bar panel. If a key is missing, choose **API-Schlüssel einrichten**
   to open the Keychain-backed dialog directly. Saving a key does not start a
   recording or make a paid request.
2. Choose your microphone and language in **Einstellungen**. Allow microphone
   access when recording. Automatic insertion additionally needs macOS
   Accessibility access; clipboard-only use does not need that permission.
3. Select the destination text field. Press **Option+Shift+Space** to record,
   speak, then press it again to stop. The maximum recording length is 90 seconds.
4. Check the destination. The complete transcript also remains available in the
   panel and on the clipboard. If input was interrupted, part may already be in
   the destination: inspect it before pasting the full transcript manually.

The API key is stored in the macOS Keychain. Never put it in a command, environment
variable, checked-in file or log. A missing, invalid or inaccessible key receives
an actionable message; the key dialog supports normal macOS editing shortcuts.
See [privacy and retention](PRIVACY.md) and the
[current evidence and limitations](docs/remaining-acceptance.md).

## Daily use

The menu bar button opens the dictation panel. Settings, saved recordings and
Help use a separate compact window. **Weitere Aktionen** contains cancel, copy,
clear and quit actions. Closing either window hides it; **Beenden** exits the app.
Recording, processing, results, setup reminders and errors never open the panel
automatically. The menu bar continues to show recording time and status. Open
the panel explicitly when you want to inspect a result or change settings;
closing it keeps it hidden through the rest of the dictation. Version and build
are shown in Settings; **Hilfe** and **Über OpenDictate …** also show the source
revision when embedded in that build. Older bundles without that information
show it as unknown.

Choose the target field before starting. Its identity is captured at the start
action, before a Keychain dialog, permission wait or panel focus change. An
explicit panel recording action can
return focus to the most recently used application; passive status updates never
activate another application. Switching external applications invalidates the
captured automatic target, even if you later return.

Automatic input is always reported as unconfirmed. A rejected preflight, an
attempt with an uncertain result, an interrupted multi-part submission and a
complete submission have distinct feedback. Already submitted text cannot be
safely rolled back. The full transcript stays available after interruption; no
automatic retry or second insertion method is used to guess the missing text.

A failed transcription keeps a recoverable recording where possible. Retrying
asks for confirmation and copies the result without automatically inserting it.

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

The menu bar shows recording time and a countdown in the last ten seconds.
Cancellation before a non-empty transcript reaches the clipboard keeps the audio.
Once the full transcript is copied, it remains available even if insertion is
cancelled, and the audio can be removed. The separate discard action removes an
active recording. The recorder also enforces the 90-second cap natively.

## If a transcription fails

A failed upload no longer throws the recording away. It keeps a recovery copy in
`~/Library/Application Support/OpenDictate/failed/`, and `Letzte Aufnahme wiederholen` in
the menu uploads it again. Recordings are authenticated with a device-local
Keychain secret before retry. Managed recovery files are limited to five and
expire after 24 hours. Pruning runs at launch, after every keep and periodically
while the app is open; expired recordings cannot be retried. Files can remain on
disk while the app is closed. Temporary originals preserved after a failed
recovery write and historical crash leftovers are outside that managed store;
see [PRIVACY.md](PRIVACY.md#last-transcript-and-temporary-originals). A retry deletes
the file only after a non-empty transcript has reached the clipboard. Clipboard
failures preserve the audio on disk and the last transcript in memory. Use
`Gespeicherte Aufnahmen löschen …` to delete the app's managed retained or legacy
recordings. Temporary originals are outside that action.

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
- Accessibility access when automatic insertion is enabled. It is not requested
  at launch for clipboard-only use.

Automatic insertion captures the target application, window, text element,
web document (when available) and selection when dictation starts. It only
delivers while that original target remains focused. Before the first insertion,
the initial selection range, when exposed, must be unchanged. Selection is not
compared with that original range after each Unicode chunk because input itself
moves the caret. Manual caret changes inside the same field during chunked input
remain an open interaction case. Protected, disabled and non-writable controls use the manual
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

Run `swift test -Xswiftc -warnings-as-errors` for pure logic, lifecycle, HTTP stubs,
recovery, logging and synthetic audio-file tests. No microphone or OpenAI calls
are part of these tests. `./scripts/build-app.sh` builds and verifies the bundle;
`VERSION` controls the marketing version, and `OPENDICTATE_BUILD_NUMBER` can set
the numeric build number (default 1). CI runs tests and an ad-hoc bundle build on
macOS, then uploads a verified development archive. It does not install an app
or publish a notarized product release.

See [CHECKS.md](CHECKS.md), [docs/performance-decisions.md](docs/performance-decisions.md), [docs/audio-quality-fixtures.md](docs/audio-quality-fixtures.md) and [docs/remaining-acceptance.md](docs/remaining-acceptance.md). Live microphone, target-app, VoiceOver and paid API checks remain separate. Streaming and hold-to-talk are not enabled.

## Development and project context

Local launchers, isolated previews and API-key setup for older installations are described
in [development workflows](docs/development.md). Product scope lives in
[PROJECT.md](PROJECT.md); repository rules and evidenced authorizations live in
[AGENTS.md](AGENTS.md) and [APPROVALS.md](APPROVALS.md). The
[compatibility matrix](docs/compatibility-matrix.md) defines the broader testing
goal, and [CHECKS.md](CHECKS.md) provides reproducible verification commands.

The architecture was inspired by VoiceScribe; attribution is preserved in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
