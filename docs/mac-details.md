# OpenDictate for Mac: the details

The [README](../README.md) gets you to your first dictation. This page
describes everything else about the macOS app: the indicator, every setting,
what happens when something fails, your own server, and the permissions.
[PRIVACY.md](../PRIVACY.md) has the complete data flow.

## Your API key

The API key is stored in the macOS Keychain. Never put it in a command, environment
variable, checked-in file or log. If the key is missing or wrong, the app tells you
what to do; the key dialog supports normal macOS editing shortcuts. The dialog
never shows a saved key again: it names it only by its start and last four
characters (such as `sk-…abcd`), and saving with an empty field keeps it. If
the saved key cannot be read right now, the dialog says so, and an empty field
still keeps it.
Keychain reads and writes run in the background, so the menu stays responsive;
if the helper does not answer within 60 seconds, the request fails and you can
try again.
If macOS asks whether **OpenDictateKeychainHelper** may access an existing
Keychain item, verify the request and choose **Always Allow** for that item.
The helper is installed once in OpenDictate's Application Support directory and
kept unchanged across ordinary app updates. The API key and the recovery key
are separate items, so each existing item may need its own initial approval.
The app reads the recovery key when it keeps a recording, once per check of the
list when a recording is new to it (after each launch, every listed one), and
when you resend one. If the key could not be read, the next check asks again.
Enter the Mac password only in the macOS dialog. Do not enable access for all
applications. Replacing the helper or signing identity can require approval
again; the separate code-signing private key must retain its restricted access
([development signing](accessibility-signing.md#create-a-local-development-identity)).
See [privacy and retention](../PRIVACY.md) and the
[current evidence and limitations](remaining-acceptance.md).

## Daily use

While you dictate, a small black indicator at the top of the screen shows one
word and a short line: **Hört zu** with the recording time, **Schreibt** while
the service transcribes or translates, **Eingefügt** after the Paste command
(the app cannot confirm the result, so the line says to check it), **Kopiert**
when the text is only on the clipboard, and **Hoppla** with the reason after an
error. It never activates OpenDictate or takes the focus, so Paste reaches the
application you started in. It closes by itself about two seconds after
**Eingefügt** and four seconds after **Kopiert**; **Hoppla** stays until you
choose **Schließen**, or **Nochmal senden** when the failed recording was kept.
Sending again asks for confirmation first, because it can cost again.

On a MacBook with a notch the indicator grows out of the notch. Without a notch
it floats as a pill just below the middle of the menu bar; an error turns it
into a small card with the reason. **Anzeige** in Settings switches to a
flat pill inside the menu bar, which covers nothing (an error then drops the
card below it), or turns the indicator off (then only
"REC" appears next to the menu bar symbol; an error still shows its card with
the reason). Over a full-screen app without menu bar, the floating pill appears
only while recording, writing or after an error; with the indicator off, only
the error card appears there.
With **Reduce motion** enabled, Blink and the indicator stand still.

The menu bar symbol opens a menu: **Diktat starten** (with your shortcut),
**Letzten Text ansehen**, **Gesicherte Aufnahmen**, **Automatisch einfügen**,
**Übersetzen**, **Einstellungen …** (⌘,), **Hilfe** and
**OpenDictate beenden** (⌘Q). While recording, the first entry stops the
dictation; while processing, it cancels and keeps the recording. Settings,
saved recordings and Help use a separate compact window. Version and build
are shown in Settings; **Hilfe** and **Über OpenDictate …** also show the source
revision when embedded in that build. Older bundles without that information
show it as unknown.

Choose the target application before starting. Its identity is captured at the
start action, before a Keychain dialog, permission wait or window focus change.
An explicit recording action in the dictation window can return focus to the
most recently used application. At delivery, automatic Paste activates the captured application.
It uses whichever control is then focused there.

Automatic input is always reported as unconfirmed. A rejected preflight, an
attempt with an uncertain result and a submitted Paste command have distinct
feedback. A submitted command cannot be safely rolled back. The transcript
stays available on the clipboard; no automatic retry guesses whether Paste worked.

A failed transcription keeps a recoverable recording where possible. Retrying
asks for confirmation and copies the result without automatically inserting it.

## Settings

The Settings window groups the everyday options first. Advanced
options are collapsed initially; saved recordings and Help open secondary pages.
Changes apply to the next dictation, no restart needed.

- **Hotkey** — a single key or a combination. Single keys count only while no
  other key, modifier or mouse button is used, so combinations such as
  Option+L for "@" keep typing:
  - `Fn/Globus halten`: hold to record, release to stop. Set **System Settings ›
    Keyboard › Press 🌐 key to** to **Do Nothing**; otherwise Fn also opens
    Emoji or Apple's Dictation, because OpenDictate only observes the key.
  - `Rechte Wahltaste` (right Option): tap to start or stop, hold to record
    until release.
  - Combinations: `Option+Shift+Space` (default), `Control+Option+D`, `F5`, or a
    custom modified shortcut. Useful when another app already claims one.

  Single keys need Accessibility access, because macOS delivers key events to
  other apps' observers only then. Without it the menu explains the permission
  and keeps the current shortcut. If another key or a mouse click joins a hold
  after recording started, the dictation is cancelled and its audio is kept for
  a manual retry.
- **Dienst** — who writes: OpenAI or your own server. The own server can be
  chosen once it has an address (see below); switching keeps that address and
  applies from the next dictation. Once a server is set up, the menu behind the
  menu bar symbol shows the same choice.
- **Model** (Advanced) — the OpenAI model: `gpt-transcribe` or
  `gpt-4o-mini-transcribe`, with the per-minute price next to each. The
  `gpt-4o-mini-transcribe` price is approximate because OpenAI bills that model
  by tokens, not by minute. While your own server writes, its model is set
  under **Eigener Server** instead.
- **Language** — Auto, German, or English. Auto lets the API detect it.
- **Übersetzen** — off by default. With a target language (for example English),
  the transcript is translated by a text model (`gpt-5.4-mini` by default) and
  only the translation is copied and pasted. If the translation fails or comes
  back empty, nothing is pasted, the original text is not used as a fallback and
  the recording is kept for retry; a retry translates again.
- **Anzeige** — how the indicator appears on screens without a notch:
  floating below the menu bar (default), inside the menu bar, or off.
- **Eigener Server** (Advanced) — use any server that speaks the OpenAI request
  format instead of OpenAI, including a local model on this Mac. See
  [Using your own server](#using-your-own-server).
- **Vokabular und Kontext** — local prompt setting (up to 2,000 characters in the editor), sent with each dictation. A stored value overrides the legacy environment variable.
- **Automatisch einfügen** — disable for clipboard-only delivery. At delivery,
  the app captured when dictation began is brought forward if it is still
  running. Paste uses whichever field is then focused there. If that app cannot
  be verified as frontmost, the transcript remains on the clipboard.
- **Letzten Text ansehen** (menu) — shows the last transcript with a copy action, without another API request. It is kept in RAM only and can be cleared.
- Saved recordings can be retried or deleted individually. Retry is disabled during recording and processing.

The indicator shows recording time and a countdown in the last ten seconds.
Cancellation before a non-empty transcript reaches the clipboard keeps the audio.
Once the full transcript is copied, it remains available even if insertion is
cancelled, and the audio can be removed. The separate discard action removes an
active recording. The recorder also enforces the 90-second cap natively.

## If a transcription fails

A failed upload no longer throws the recording away. It keeps a recovery copy in
`~/Library/Application Support/OpenDictate/failed/`, and `Letzte Aufnahme nochmal senden …` in
the menu uploads it again. A failed translation is handled the same way. Recordings are authenticated with a device-local
Keychain secret before retry. Managed recovery files are limited to five and
expire after 24 hours. Pruning runs at launch, after every keep and periodically
while the app is open; expired recordings cannot be retried. Files can remain on
disk while the app is closed or if macOS denies deletion. In that case the app
logs the failure and retains the authentication file alongside the audio.
Temporary originals preserved after a failed
recovery write and historical crash leftovers are outside that managed store;
see [PRIVACY.md](../PRIVACY.md#last-transcript-and-temporary-originals). A retry deletes
the file only after a non-empty transcript has reached the clipboard. Clipboard
failures preserve the audio on disk and the last transcript in memory. Use
`Gesicherte Aufnahmen löschen …` to delete the app's managed retained or legacy
recordings. Temporary originals are outside that action; at launch the app
deletes the ones that are at least 24 hours old, never younger ones.

Recordings classified as too short or too quiet are retained for a deliberate manual retry. These heuristics do not prove that no speech exists; they never trigger an automatic upload.
An empty recording, where the microphone delivered no audio at all, has nothing to resend: the app says so
and leaves the empty temporary file where it is.

## Cost

You pay OpenAI per minute of speech instead of a flat fee. With the default
`gpt-transcribe` at $0.0045/min, a typical 15-second dictation costs about
0.1 cent; the price of a $5 monthly subscription buys about 18.5 hours of
speech. That is what OpenAI
charged for `gpt-transcribe` from July to October 2026; OpenAI sets the price,
and its price list is what counts. Your cost depends on how long you speak. With a [model on your own Mac](#using-your-own-server) dictation
costs nothing. Translation adds one text-model request per dictation,
which OpenAI bills separately by tokens.

Transcription uses `gpt-transcribe`, OpenAI's current accuracy-focused model.
**Vokabular und Kontext** adds your own vocabulary for names and technical terms.

## Cost controls

To keep your bill small, OpenDictate:

- skips recordings shorter than 1 second
- auto-stops recordings after 90 seconds (deliberate per-dictation limit)
- trims silence from the beginning and end before upload
- records speech-focused mono AAC at 24 kHz / 48 kbps
- uses `gpt-transcribe` by default, OpenAI's most accurate model for this, at $0.0045 a minute

Optional environment variables. A choice made in the menu wins over these, so the
menu is not silently ignored for anyone who exports them:

- `OPENAI_TRANSCRIBE_MODEL`, default `gpt-transcribe`. Set `gpt-4o-mini-transcribe` (approx. $0.003/min, billed by tokens) to trade accuracy for cost. Setting `gpt-live-transcribe` is caught at launch with a warning: it targets the realtime endpoint, not this upload flow. A name with characters other than ASCII letters, digits and `- . _ / :` (as on the iPhone) is caught the same way and is never sent.
- `OPENAI_TRANSCRIBE_LANGUAGE`, for example `de`
- `OPENAI_TRANSCRIBE_PROMPT`, for vocabulary hints. The in-app vocabulary setting overrides this value.
- `OPENAI_BASE_URL`, the server address as in the OpenAI SDKs, for example
  `http://127.0.0.1:8080/v1`. A value saved under **Eigener Server** wins.

## Using your own server

**Einstellungen → Erweitert → Eigener Server** takes a server address and,
optionally, the model names that server uses. Saving a first address selects
the server; editing a saved one keeps the current choice, so fixing the server
while OpenAI writes does not switch back. An empty address removes it and
selects OpenAI. The address is the base
URL including `/v1`; OpenDictate appends `/audio/transcriptions` for dictation
and `/chat/completions` for translation.

**Dienst** switches between OpenAI and the saved server at any time, for
example while the server is not running. The server's address and model names
stay saved, and OpenAI keeps its own model, so neither choice changes the
other. The app never switches on its own: if your server does not take a
dictation, the recording is kept as after any failure, and the indicator
offers **Mit OpenAI senden** instead of **Nochmal senden**. That button sends
this one recording to OpenAI after a confirmation, needs your API key and costs
there; the next dictation goes to your server again. Builds before the choice
existed kept the server's model names in the OpenAI fields; the first start
moves them to the server once.

- **A local model is free.** A server on this Mac (`http://127.0.0.1`,
  `http://localhost` or `http://[::1]`) receives no API key, and none is
  required. OpenDictate sends audio and text only to this Mac. Examples are whisper.cpp's server
  or Speaches for transcription and LM Studio or Ollama for translation, each
  with its own model names.
- **Other servers need `https://`** and receive your saved API key, for
  example a Groq key. Plain `http://` to another computer is rejected, so audio
  and keys never travel unencrypted over a network.
- Redirects are not followed, so audio and text go only to the address you
  entered, never on to another host.
- If the saved or `OPENAI_BASE_URL` address is not allowed, dictation stops
  with a message instead of falling back to OpenAI.
- Some servers, such as whisper.cpp, end every segment at a speaking pause
  with a line break. For a server of your own, OpenDictate joins those breaks
  with a space, so a dictation arrives as running text. OpenAI's text is not
  changed.

OpenAI is the tested provider. A local whisper.cpp server passed a live
dictation on 11 October 2026 ([step-by-step guide](lokales-modell.md));
other servers are a known limit.
Recordings that fail there stay available for retry as usual. The Mac beta has the custom server since Build 12 (`v0.1.0-beta.12`).

## Permissions

macOS will ask for:

- Microphone access for recording.
- Accessibility access when automatic insertion is enabled or a single key
  (Fn/Globe, right Option) starts recording. It is not requested at launch for
  clipboard-only use with a key combination.

Automatic insertion remembers the application in front when dictation starts.
After transcription, OpenDictate puts the text on the general clipboard, brings
that application to the front and sends the ordinary Command-V shortcut. The
application and its currently focused control handle Paste. This also works with
controls that do not expose a writable Accessibility text selection.

If you switch fields or windows while dictating, the text may land in a
different field of the same application. OpenDictate checks that the original application is
frontmost and that the clipboard still holds the transcript before sending the
shortcut, but cannot confirm which control accepted it or whether Paste changed
visible text. Control characters from the provider's answer are removed before
the text is copied. In known terminals (Terminal, iTerm2, Alacritty, kitty,
Ghostty, Warp, Hyper, WezTerm, Tabby, Xcode's terminal) text with a line break is not pasted
automatically, because the line break would run the dictated line as a command;
it stays on the clipboard. A single line is pasted there as elsewhere, and
OpenDictate does not send a separate Return. Use clipboard-only mode for targets
where automatic Paste is unwanted, especially password fields. OpenDictate no
longer inspects whether the focused control is protected or read-only. The transcript remains on the clipboard for
manual recovery; OpenDictate does not put the previous clipboard contents back.
It is marked for clipboard managers as concealed and auto-generated
(nspasteboard.org), and with Handoff on, Universal Clipboard can offer it on
your other Apple devices like anything you copy. Candidate-specific acceptance is tracked in
[remaining acceptance](remaining-acceptance.md).

The indicator shows the elapsed time and counts down the last ten seconds
before the automatic stop; VoiceOver announces each state and the countdown at
ten and five seconds. The custom shortcut dialog supports Tab/Shift+Tab,
Escape and Return without requiring macOS full keyboard access.

See [PRIVACY.md](../PRIVACY.md) for the complete data flow and retention behavior,
[docs/accessibility-signing.md](accessibility-signing.md) for safe local
development signing, and [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) for the
VoiceScribe attribution and license notice.

## Verification

Run `swift test -Xswiftc -warnings-as-errors` for pure logic, lifecycle, HTTP stubs,
recovery, logging and synthetic audio-file tests. No microphone or OpenAI calls
are part of these tests. `./scripts/build-app.sh` builds and verifies the bundle;
`VERSION` controls the marketing version, and `OPENDICTATE_BUILD_NUMBER` can set
the numeric build number (default 1). CI runs tests and an ad-hoc bundle build on
macOS, then uploads a verified development archive. It does not install an app
or publish a notarized product release.

See [CHECKS.md](../CHECKS.md), [docs/performance-decisions.md](performance-decisions.md),
[docs/audio-quality-fixtures.md](audio-quality-fixtures.md),
[docs/remaining-acceptance.md](remaining-acceptance.md) and the
[project roadmap](../ROADMAP.md). Live microphone, target-app, VoiceOver and paid
API checks remain separate. Streaming is not enabled; the roadmap lists it as
a future request, not current app behavior.

## Development and project context

Local launchers, isolated previews and API-key setup for older installations are described
in [development workflows](development.md). Product scope lives in
[PROJECT.md](../PROJECT.md), and the cross-platform feature/platform backlog lives
in [ROADMAP.md](../ROADMAP.md); repository rules live in [AGENTS.md](../AGENTS.md),
and earlier approvals are archived in
[docs/archive/APPROVALS.md](archive/APPROVALS.md). The
[compatibility matrix](compatibility-matrix.md) defines the broader testing
goal, and [CHECKS.md](../CHECKS.md) provides reproducible verification commands.

The architecture was inspired by VoiceScribe; attribution is preserved in
[THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
