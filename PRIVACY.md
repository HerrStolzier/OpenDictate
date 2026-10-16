# Privacy

**In short**

- OpenDictate records only while you dictate.
- Your recording goes straight from your computer to OpenAI, or to your own
  server if you set one up, using your own key. With a server on your own
  computer, nothing leaves it. The project never sees your audio or text.
- With translation on, the recognised text is sent a second time, for the
  translation, unless your device translates it itself ("Auf dem Mac" on
  macOS 26 or later, "Auf dem iPhone" on iOS 26 or later).
- Your key stays in the system keychain. There is no tracking and no
  analytics, and the log never contains your text, your audio or your key.
- A recording that failed is kept so you can send it again: the five newest,
  for up to 24 hours. After that it can no longer be sent and is removed the
  next time the app tidies up. A copy can stay longer in rare cases, for
  example after a crash; [Failed recordings](#failed-recordings) explains when.

The rest of this page is the detailed reference. It describes the macOS app
first; the [Linux CLI](#linux-cli), the [iPhone app](#iphone-app) and
[support requests](#support-requests) have their own sections. The Windows
beta app is not released yet; its notes are in
[windows/RELEASE-PLAN.md](windows/RELEASE-PLAN.md).

OpenDictate records microphone audio only while a dictation is active. It does
not include telemetry or analytics.

## Data sent to OpenAI or your own server

For each non-empty dictation, OpenDictate sends the prepared audio over HTTPS to
OpenAI's `/v1/audio/transcriptions` endpoint. The request also contains the
selected model, the optional language, and the optional vocabulary prompt. The
returned transcript is handled locally. If a translation target language is
set, the transcript text is then sent over HTTPS to OpenAI's
`/v1/chat/completions` endpoint together with the target language and the
translation model, and only the translation is copied and pasted. OpenAI's own
data handling terms apply to these transfers.

With **Übersetzen mit: Auf dem Mac** (macOS 26 or later), Apple's on-device
translation (`TranslationSession`) translates the transcript instead, and the
text is not sent anywhere for the translation. The app takes the source
language from the dictation language setting, or with Auto recognises it in the
text on the Mac. The languages come from Apple once, through System Settings.
Apple
[says](https://developer.apple.com/documentation/translation/translationsession)
it may collect usage and performance metrics with the app's bundle ID and the
language pair, never the original or translated text. The recording itself
still goes to the chosen service for transcription.

With **Eigener Server** (or `OPENAI_BASE_URL`), the same requests go to the
configured address instead of OpenAI, and that server's own terms apply. A
server on this Mac (loopback address) receives no API key, and OpenDictate sends
audio and text only to this Mac; what that local server does with them is up to
its own configuration. Any other server must use HTTPS and receives the saved
API key. HTTP redirects are not followed, so requests go only to the configured address.
An address that is not allowed stops the dictation; it never falls back to
OpenAI. **Dienst** chooses between OpenAI and a saved server; the app never
switches by itself. When the own server does not take a dictation, a recording
goes to OpenAI only after the user picks **Mit OpenAI senden** and confirms it,
and only that one recording. The log records only the server's host name,
never the path or key.

Because every server outside this Mac receives the saved API key along with
the audio and text, use only servers you trust. The server address is an
ordinary app setting in the user's preferences (`UserDefaults`), not in the
Keychain: any program running under your user account could change it, for
example with `defaults write`, and send later dictations and the key
elsewhere.

The OpenAI API key is stored as a generic password in the macOS Keychain under
service `OpenDictate` and account `OPENAI_API_KEY_APP`. OpenDictate does not support
supplying the key through a command-line argument or environment variable.
The app reads the older `OPENAI_API_KEY` account only when the new account is
confirmed absent. When it finds a key only there, the first successful read
also tries to move it to the new entry in the same way as a save; if that move
fails, the key stays usable from the older entry. Access errors or unusable data in the new account do not cause
a fallback to an older key. On an explicit save, the app creates its own new
entry or updates that entry's value, then removes the older account only after
the new value has been stored successfully. It does not delete the active entry
before attempting replacement. If removal of the older entry fails, the app
reports that the new key was saved but cleanup remains pending; both entries can
then remain in the Keychain until a later successful cleanup.

The signed Keychain helper handles these operations for the installed app. The
app copies the helper once from its bundle to
`~/Library/Application Support/OpenDictate/KeychainHelper-v1` and verifies its
signature before each launch. The app also checks the running helper's signing
identity before sending a request. The helper accepts requests only from the
signed OpenDictate app with the same signing certificate. Keychain data travels
between the app and helper through private process pipes, never through command
arguments, environment variables or a file. The installed helper stays
unchanged across ordinary app updates, so an existing item can continue to
trust the same executable after a one-time macOS approval. Replacing the helper
or signing certificate may require another approval. The API and recovery keys
are separate Keychain items and may each require approval. Newly saved entries
use the helper's default Keychain access policy. The retired `store-api-key.sh`
script only directs users to the app dialog and performs no Keychain operation.

## Clipboard and automatic insertion

The transcript is written as plain text to the macOS general clipboard. Any
local application with clipboard access may be able to read it. Control
characters and invisible text-direction marks are removed from the provider's
answer before it is copied; line breaks and tabs stay. Unicode line and
paragraph separators (U+2028, U+2029) become ordinary line breaks, so the
terminal rule below applies to them too.

OpenDictate leaves the transcript on the general clipboard until another write
replaces it; it does not restore the previous clipboard contents, because the
clipboard is also the fallback when automatic insertion is off or cannot be
verified. The item carries the `org.nspasteboard.ConcealedType` and
`org.nspasteboard.AutoGeneratedType` markers, so clipboard managers that honour
them keep no copy; other managers may retain their own copy, which OpenDictate
cannot remove. With Handoff on, macOS Universal Clipboard can make the
transcript available to your other Apple devices nearby, like anything else
you copy; turn Handoff off in System Settings if you do not want that. For automatic insertion, OpenDictate remembers the application
that was in front when dictation started, activates it after transcription and
sends Command-V. It checks that Accessibility permission is available, that the
application is then frontmost and that the clipboard still contains the full
transcript. It does not inspect the destination's text or title. A different
field or window in the original application may receive Paste after a focus
change; the app cannot confirm that the target accepted the command. Text with
a line break is not pasted automatically into known terminal applications
(Terminal, iTerm2, Alacritty, kitty, Ghostty, Warp, Hyper, WezTerm, Tabby, Xcode's terminal), because a
line break would run the dictated line as a command; the text stays on the
clipboard. A single line is pasted there as elsewhere. OpenDictate does not
identify protected, read-only or password controls before Paste. Retries copy their text
but do not automatically paste it.

The recording panel opens only through an explicit user action. Recording,
results, errors and setup reminders update the menu bar and existing panel
contents without showing a hidden panel or activating OpenDictate.
The small dictation indicator (at the notch, floating below the menu bar or in
the menu bar, or off) appears without taking focus or activating OpenDictate.
It shows only the state word, the recording time and an error reason, never
the transcript. To choose the screen, the app reads the window list of other
applications (process, window layer and frame) on the Mac; nothing from it is
stored or sent.
The original application is captured before Keychain access, permission waits
or an explicit panel action's focus return.

An explicit recording-panel action may return focus to the most recently used
application. Stopping through the panel returns only if that application is still
the most recently selected external app. Passive updates never return focus.
Automatic insertion reactivates the application captured when recording started.
Retries require explicit confirmation, copy their
result, and never automatically insert. Otherwise only the clipboard
is updated. Automatic insertion can also be disabled in the menu. Accessibility
identity checks cannot atomically lock another application's focus or prove that
it actually applied an accepted insertion command. The UI therefore asks the
user to check the target, and preserves the manual text recovery path.

## Single-key shortcut

When Fn/Globe or the right Option key is the shortcut, OpenDictate observes
keyboard modifier changes, key presses and mouse clicks in all applications
through macOS event monitors. It only checks whether the chosen key was pressed
on its own; it does not read, store, log or send which keys were typed, and the
events still reach the frontmost application unchanged. The log records only
which shortcut is active, when a hold was interrupted and when the permission
arrived. Key combinations use the system hotkey registration
and are not observed this way.

To preselect a key in the first-launch shortcut question, OpenDictate reads the
vendor and product IDs of connected keyboards from the macOS I/O Registry. It
does not open the devices, read their names or send these IDs anywhere; the log
records only the IDs and the resulting recommendation.

## Failed recordings

When transcription fails, OpenDictate keeps a recovery copy under
`~/Library/Application Support/OpenDictate/failed/`. The directory is restricted
to the current user, recordings and authentication files use owner-only modes,
and retry accepts only recordings authenticated with a device-local Keychain
secret. OpenDictate applies the five-file and 24-hour limits to all recognized
recording files, including legacy files or files whose authentication tag cannot
be verified. It also deletes a recording after a non-empty retry transcript reaches the clipboard, or when the
user explicitly deletes it. Expiry is checked before retry. Pruning runs at launch, after a keep, and
periodically while the app is open. There is no separate background deletion
service while the app is closed, so an expired file can remain on disk until
the next pruning pass. If macOS denies deletion, it can remain longer; the app
logs the failure and retains its authentication file when audio remains.
Expiry still prevents retry. The limits describe the managed recovery directory;
preserved temporary originals and crash leftovers are described below. Short/quiet recordings are retained for deliberate manual retry; a heuristic skip does not upload them automatically.

Recordings created by an older version have no authentication tag and are not
eligible for upload. They remain available to the explicit delete action.

## Local log

`~/Library/Logs/OpenDictate.log` contains operational metadata such as times,
bundle version, build and source identity, bundle and audio paths, selected model,
translation setting, input-device and application names,
durations, levels, status, and error descriptions. It does not intentionally log
API keys, transcript text, or audio contents. Logging is serialized and rotated at approximately 1 MiB, keeping one previous file. The log and its previous file are readable only by the current user (permissions 0600): the active log is restricted on every write, the previous file on the first write after launch and after every rotation. No timed log expiry is implemented.

## Last transcript and temporary originals

The most recent non-empty transcript is also held in memory until replaced, cleared from the menu or the app exits. No persistent text history is created. Temporary recording files are restricted to the current user (permissions 0600); the original recording is created with these permissions before audio is written. If restricting fails, the app logs it. If a recovery-store write fails, the original temporary audio is deliberately not deleted and its path is shown in the error status. An original that is empty (zero bytes, the microphone delivered no audio) holds nothing to resend; the app says the recording was empty and leaves the file where it is, like an original after a failed recovery write. Such originals and crash leftovers (`opendictate-*.m4a` and `opendictate-trimmed-*.m4a` in the app's temporary folder) follow the same 24-hour limit as kept recordings: at each launch the app deletes the ones that are at least 24 hours old, and never a younger one, because it may be the only surviving copy.

## Linux CLI

The Linux CLI is a public beta since 11 October 2026 (pre-release
`linux-v0.1.0-beta.1`) and is installed as an Arch package built from source.
On an explicit toggle it records the ALSA default input (with PipeWire
through pipewire-alsa) as an owner-only WAV. Recordings below one second or
without a 50-ms window above −45 dBFS are not uploaded; they are kept like
other recordings, but marked, so plain `retry` passes them over and only
`retry --skipped` sends the last of them. Other recordings are sent over HTTPS
to OpenAI's `/v1/audio/transcriptions` endpoint with the selected model and
optional language. If a translation target language is set, the transcript text is then
sent over HTTPS to OpenAI's `/v1/chat/completions` endpoint with the selected
translation model, and only the translation is written to the clipboard. The
returned text is written to the Wayland clipboard (`wl-copy`). Unless
`settings insert off` is set, the CLI then reads the clipboard back
(`wl-paste`, in memory only) and, if it still holds that text and the Hyprland
window captured at recording start is still frontmost, sends that window a
paste shortcut via `hyprctl`. Control characters and invisible text-direction
marks are removed from the returned text first. Text with a line break is not
pasted into known terminals; it stays in the clipboard. Retry never pastes
automatically. A clipboard history manager on Wayland (such as cliphist or
clipman) keeps its own copy of every text copied via `wl-copy`; OpenDictate
cannot prevent or remove that copy. The optional
bar module (Omarchy shell or Waybar) prints only the state and translation setting, never text.

With a custom server (`settings server`, or `OPENAI_BASE_URL` when no address
is stored), the recording and, with translation on, the transcript go to that
server's `/audio/transcriptions` and `/chat/completions` instead of OpenAI;
nothing goes to OpenAI then. Plain `http://` is accepted only for loopback
addresses (`localhost`, `127.0.0.1`, `[::1]`), which never receive the API key.
Any other custom server is reached over HTTPS and receives the stored API key
as a bearer token, even when that key was created for OpenAI. `OPENAI_BASE_URL` set in
the session therefore redirects the audio, the transcript and, for a
non-loopback HTTPS address, the API key to that host. A loopback server is
only private on a single-user machine: another local user could bind the port
first and would receive the audio and text. Addresses with credentials, a query or a fragment are
rejected. `opendictate setup` checks a key or server once by requesting the
server's model list (`/models`), which sends no audio or text.

`opendictate setup` and `opendictate shortcut set` can add one bind line for
`opendictate toggle` to the user's Hyprland config after a backup copy of the
file; nothing else in the config is read for other purposes or changed. The
three newest backup copies next to the file are kept, older ones are removed.

Secret Service items use attributes `service=opendictate` and `key=api-key` or
`recording-auth`. The API key is accepted only on stdin. A probe item can be
written, read and deleted to test the service. There is no file, environment or
argument fallback. Settings contain only transcription model, language, optional and last target
language, translation model, the auto-insert switch and an optional custom
server address, and are stored under
`$XDG_CONFIG_HOME/opendictate/`.

Pending and recovery audio live under `$XDG_STATE_HOME/opendictate/` (typically
`~/.local/state/opendictate/`). Directories use owner-only mode. A recovery copy
is authenticated with HMAC-SHA256 using a device-local Secret Service value and
binds the file name, creation time and exact bytes. Retry uploads only bytes that
authenticate at access time. Managed authenticated recovery is limited to five
files and 24 hours; unknown or modified files are not uploaded automatically.
An original that stays in the pending folder because its recovery copy could
not be made is never uploaded automatically and is removed at the first
recording start after it is 24 hours old.
Audio is removed only after a non-empty transcript, or its non-empty
translation when a target language is set, reaches the clipboard. With
auto-insert on, audio is kept for retry if the clipboard no longer holds
exactly that text before the paste. If the microphone fails during a
recording, the audio captured until then is kept for retry the same way. Marked
short or silent recordings count toward the same five newest. Kept recordings
past the limits are also removed after any later dictation, not only at the
next failure or retry.
The mark is part of the authenticated proof.

The operations log under `$XDG_STATE_HOME/opendictate/operations.log` records
bounded events, durations, the captured window class and, with a custom server,
that server's host name (never its path). It must not contain API
keys, transcript text, window titles or audio contents. The log is owner-only
(`0600`); above 1 MiB it is renamed to `operations.log.1`, replacing the
previous one, so at most two log files exist. Live Linux transcription
and translation requests were exercised on one attended test system on
5 October 2026; the Linux beta published on 11 October 2026 is not a finished
product.

## Windows provider core

### Explicit Windows vocabulary

The platform-neutral Windows provider settings persist an explicit vocabulary
list (64 entries and 800 UTF-8 bytes including separators). A non-empty list
is sent as the `prompt` field to the selected transcription service, including
a custom server. It is not logged or learned automatically. The Windows app
has no vocabulary editor yet; this change adds persistence and transport in
the platform-neutral core/provider only.

## iPhone app

The iPhone app in [ios/](ios/README.md) is written but not released yet. It
records only between the start of a dictation (the shortcut "Dictate", for
example from Back Tap or the Action button, or the button in the app) and its
end (the shortcut again, the stop button of the Live Activity, a call or Siri
taking the microphone, or the 90-second limit). iOS shows its orange
microphone indicator during that time, and the Live Activity on the Lock
Screen and in the Dynamic Island shows that a recording is running.

- **Requests:** the same as on the Mac: the audio goes over HTTPS to OpenAI's
  `/v1/audio/transcriptions` endpoint with the model, and with a translation
  target the transcript goes to `/v1/chat/completions`. With a custom server
  ("Eigener Server") the requests go to that address instead; only `https://`
  is accepted, or `http://` for a server on the iPhone itself, which gets no
  API key. Any other server receives the stored API key, so use only servers
  you trust. Redirects are not followed. The chosen service may keep audio and
  text for a while under its own terms (OpenAI, for example, for abuse
  monitoring) and can link them to the account behind the API key; the app's
  privacy manifest therefore declares both as collected for app functionality
  and linked to the user, not used for tracking.
  Once per launch and address, while the app is open, it sends a `GET`
  without key or audio to the custom server's `/models` address, so iOS can
  ask for local network access for a server in the home network.
- **Recognition on the iPhone:** with "Erkennung: Auf dem iPhone" (iOS 26 or
  later) Apple's on-device speech recognition (`SpeechTranscriber`) writes
  the text, and the audio is not sent anywhere. For that the app writes the
  checked recording to a temporary file in its own container and deletes it
  afterwards; a copy left because iOS ended the app is deleted at the
  next start or recognition. The language model is downloaded once from
  Apple when you tap "Sprache laden"; iOS manages and shares it with other
  apps.
- **Parakeet (trial):** with "Erkennung: Parakeet" NVIDIA's Parakeet TDT
  0.6B v3 model writes the text on the iPhone through the FluidAudio library,
  and the audio is not sent anywhere. The app writes the checked recording to
  a temporary file in its own container for that and deletes it afterwards;
  a copy left because iOS ended the app is deleted at the next start or
  recognition. The model (about 500 MB) is downloaded once from Hugging Face
  (huggingface.co) when you tap "Modell laden" or "Modell neu laden"; like
  any web request, that tells Hugging Face the iPhone's IP address, the
  requested files and the usual request details such as the iOS version,
  never a recording or text. The model stays in the app's container,
  excluded from backups, until the app is deleted. A dictation never
  downloads it.
- **Translation on the iPhone:** with "Übersetzen mit: Auf dem iPhone" (iOS 26
  or later) Apple's on-device translation (`TranslationSession`) translates
  the text, and the text is not sent anywhere. The app recognizes the text's
  language on the device first. The languages are downloaded once from Apple
  when you tap "Sprachen laden". Apple
  [says](https://developer.apple.com/documentation/translation/translationsession)
  it may collect usage and performance metrics with the app's bundle ID and
  the language pair, never the original or translated text. With recognition
  and translation both on the iPhone (Apple's recognition or Parakeet), a
  dictation sends nothing and needs no API key.
- **API key:** stored only in the iPhone's Keychain with "this device only"
  and readable after the first unlock, so a dictation from the Lock Screen
  works. It is not part of backups and never leaves the device except in the
  request header to the configured service.
- **Clipboard:** the finished text (or its translation) is written to the
  general clipboard marked "local only", so iOS does not share it with your
  other devices through Universal Clipboard, and with an expiry: iOS removes
  it from the clipboard after ten minutes. "Copy again" copies it once more
  while the app runs. Control characters and invisible
  text-direction marks are removed from the service's answer first. The app
  does not read the clipboard. While the app is in the background, iOS
  refuses it the clipboard; there the shortcut's own "Copy to Clipboard" step
  copies the text the app returns to it, and that step's "Local Only" option
  decides whether Universal Clipboard shares it; that copy has no expiry.
- **Last text:** kept only in memory while the app runs, for "Copy again";
  it is gone when iOS ends the app.
- **Failed recordings:** a recording whose text did not reach the clipboard
  stays in the app's own container. That includes a text the app returned to
  the shortcut while iOS refused it the clipboard, because the app cannot
  tell whether the shortcut copied it. Kept recordings stay under the same
  rule as on the Mac: at most the five newest, none older than 24 hours,
  checked whenever the list is read. The folder is excluded from backups. As
  on the Mac, each kept recording gets an authentication tag (HMAC-SHA256 with a key in the
  Keychain); "Send again" offers only recordings with a valid tag and uploads
  exactly the bytes it checked. A recording shorter than one second is kept
  without a tag, because it is too short to send, and expires under the same
  rule. A recording with nothing louder than room noise is not sent; it is
  kept with a tag, so "Send again" can still send it on purpose, as on the
  Mac. A recording cut off because iOS ended the app during it is
  kept at the next start without a tag, so it is never sent again, and
  expires under the same rule.
- **No log, no telemetry:** the iPhone app writes no log file and sends
  nothing else anywhere.

## Support requests

This section covers all platforms. Support has been live since 11 October
2026: e-mail to support@opendictate.app or the contact form at
https://support.opendictate.app/kontakt. The privacy policy at
https://support.opendictate.app/datenschutz names the same details with the
legal bases.

OpenDictate sends nothing to support on its own: no logs, diagnostics or
recordings. A request contains only what you type into the contact form or
write in an e-mail to the support address. The form can also carry a short
report for "Fehler melden" (app version, system, last error and a log excerpt,
never text, audio or the key; see [Fehler melden](docs/fehler-melden.md)). An
app only opens the form with it in your browser. The report sits after the
`#` in the address, which browsers never send to a server, so it reaches
support only when you send the form; until then you see it, can edit or delete
it. No app offers this yet. Do not include your OpenAI API key; values that look like one (`sk-…`) are
removed from the subject, name, message and report before the request is
stored.

Requests are handled by a small support service on Cloudflare Workers,
operated by the developer. It stores the e-mail address, the optional name,
subject, message, chosen topic, processing state, replies and internal notes
in a Cloudflare D1 database restricted to the EU jurisdiction. The support
service does not store attachments. Mail to the support address passes through
Cloudflare Email Routing, and replies are sent from the support service through
Cloudflare Email Service. Requests are not copied to another mailbox; the
developer only gets a notice with the ticket number, without its content.

The support service keeps no logs at Cloudflare. When a step fails, for
example storing a request, the developer gets a short mail naming the step and
the kind of error, without the content of the request, mail addresses or IP
addresses.

Against spam, the form uses a hidden field, an origin check, a size limit and
daily limits; new requests by mail have a daily limit too. For the per-sender
limits the IP address or mail address is kept only as a hash combined with a
secret value and the date, and deleted the following day. If Cloudflare Turnstile is enabled,
Cloudflare checks the browser before the request is accepted.

An optional assistant can sort a request and draft a reply. It is off unless
the developer enables it. When enabled, it sends the subject and messages, not
the stored address field, to the OpenAI API with storage of the request turned
off (`store: false`); addresses inside quoted text or signatures are part of
the message. Its result is stored with the request and deleted with it. The
assistant never sends anything. Every reply is written or
checked by the developer. Independently of the assistant, a fixed keyword
check marks requests that mention privacy, security, payments, data loss,
legal matters or anger for personal handling.

Closed requests are deleted automatically 180 days after they were closed;
open requests are kept until they are closed.
On request, a ticket and all its messages, replies included, are deleted at
once.

### Explicit Linux vocabulary

Linux keeps an explicitly managed list of up to 64 entries (800 UTF-8 bytes
including separators) in its owner-only settings file. Every transcription
sends this list as the optional `prompt` field to the selected service,
including a custom server. It is never logged or learned automatically;
`opendictate vocabulary clear` removes it locally. Existing retained recordings
use the vocabulary selected at retry time.
