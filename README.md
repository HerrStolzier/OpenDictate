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

1. Open the menu bar panel. If a key is missing, choose **Schlüssel eingeben**
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
If macOS asks whether **OpenDictateKeychainHelper** may access an existing
Keychain item, verify the request and choose **Always Allow** for that item.
The helper is installed once in OpenDictate's Application Support directory and
kept unchanged across ordinary app updates. The API key and the recovery key
are separate items, so each existing item may need its own initial approval.
Enter the Mac password only in the macOS dialog. Do not enable access for all
applications. Replacing the helper or signing identity can require approval
again; the separate code-signing private key must retain its restricted access
([development signing](docs/accessibility-signing.md#create-a-local-development-identity)).
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

Choose the target application before starting. Its identity is captured at the
start action, before a Keychain dialog, permission wait or panel focus change.
An explicit panel recording action can return focus to the most recently used
application. At delivery, automatic Paste activates the captured application.
It uses whichever control is then focused there.

Automatic input is always reported as unconfirmed. A rejected preflight, an
attempt with an uncertain result and a submitted Paste command have distinct
feedback. A submitted command cannot be safely rolled back. The transcript
stays available on the clipboard; no automatic retry guesses whether Paste worked.

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
- **Automatisch einfügen** — disable for clipboard-only delivery. At delivery,
  the app captured when dictation began is brought forward if it is still
  running. Paste uses whichever field is then focused there. If that app cannot
  be verified as frontmost, the transcript remains on the clipboard.
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
disk while the app is closed or if macOS denies deletion. In that case the app
logs the failure and retains the authentication file alongside the audio.
Temporary originals preserved after a failed
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

Automatic insertion remembers the application in front when dictation starts.
After transcription, OpenDictate puts the text on the general clipboard, brings
that application to the front and sends the ordinary Command-V shortcut. The
application and its currently focused control handle Paste. This also works with
controls that do not expose a writable Accessibility text selection.

This restores the early prototype's behavior: a focus or window change during
dictation can cause the transcript to paste into a different control in the
original application. OpenDictate checks that the original application is
frontmost and that the clipboard still holds the transcript before sending the
shortcut, but cannot confirm which control accepted it or whether Paste changed
visible text. In Terminal, Paste may include line breaks or shell commands;
OpenDictate does not send a separate Return. Use clipboard-only mode for targets
where automatic Paste is unwanted, especially password fields. OpenDictate no
longer inspects whether the focused control is protected or read-only. The transcript remains on the clipboard for
manual recovery. Candidate-specific acceptance is tracked in
[remaining acceptance](docs/remaining-acceptance.md).

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
