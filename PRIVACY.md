# Privacy

OpenDictate records microphone audio only while a dictation is active. It does
not include telemetry or analytics.

## Data sent to OpenAI

For each non-empty dictation, OpenDictate sends the prepared audio over HTTPS to
OpenAI's `/v1/audio/transcriptions` endpoint. The request also contains the
selected model, the optional language, and the optional vocabulary prompt. The
returned transcript is handled locally. OpenAI's own data handling terms apply
to this transfer.

The OpenAI API key is stored as a generic password in the macOS Keychain under
service `OpenDictate` and account `OPENAI_API_KEY_APP`. OpenDictate does not support
supplying the key through a command-line argument or environment variable.
The app reads the older `OPENAI_API_KEY` account only when the new account is
confirmed absent. Access errors or unusable data in the new account do not cause
a fallback to an older key. On an explicit save, the app creates its own new
entry or updates that entry's value, then removes the older account only after
the new value has been stored successfully. It does not delete the active entry
before attempting replacement. If removal of the older entry fails, the app
reports that the new key was saved but cleanup remains pending; both entries can
then remain in the Keychain until a later successful cleanup.

New entries use the app's default Keychain access policy. Older helper-created
entries may have a different policy; saving through the app migrates them without
copying that policy onto the new entry. The retired `store-api-key.sh` helper only
directs users to the app dialog and performs no Keychain operation.

## Clipboard and automatic insertion

The transcript is written as plain text to the macOS general clipboard. Any
local application with clipboard access may be able to read it.

OpenDictate leaves the transcript on the clipboard until another clipboard write
replaces it, preserving a manual recovery path when automatic insertion is
unavailable or ineffective. Clipboard managers may retain their own copy;
OpenDictate cannot remove that copy. Automatic insertion does not read or paste
from the clipboard: it sends the transcript directly to the Accessibility text
element captured at dictation start. It retains only process, window, element,
web-document identity (when available) and selection range, not the target's
text or title. These references are cleared when the flow becomes idle. An
external application switch invalidates the automatic target. For Brave, Safari and Obsidian web
editors, it instead
sends the exact transcript as Unicode keyboard events addressed to that process.
It checks that the application is still frontmost and the same Accessibility
field, window and web document remain focused before each text chunk. Before
the first insertion, an available selection range must still match the captured
range. It does not activate the target during delivery, read the
field's existing contents, or send a paste shortcut. A focus change or cancellation
stops remaining chunks; already submitted text may have reached the destination
and cannot be rolled back safely. The panel distinguishes interruption from a
preflight that never attempted input and keeps the full transcript available.
A native setter error is treated as an uncertain attempt, not proof that the
target stayed unchanged. All-submitted input remains unconfirmed as well.
Brave's event path keeps line breaks with preceding text and complete graphemes
within the event-size limit. If a transcript cannot satisfy those constraints,
it falls back before posting any event; the original clipboard text is unchanged.

If the focused control does not expose a settable selected-text Accessibility
attribute, automatic insertion stops and the transcript remains available only
through the clipboard. OpenDictate does not fall back to an automatic `Cmd+V`
because that would again consume mutable global clipboard contents.

The recording panel opens only through an explicit user action. Recording,
results, errors and setup reminders update the menu bar and existing panel
contents without showing a hidden window or activating OpenDictate.
The original field is captured before Keychain access, permission waits or
an explicit panel action's focus return; a missing field is not recaptured later.

An explicit recording-panel action may return focus to the most recently used
application. Stopping through the panel returns only if that application is still
the most recently selected external app. Passive updates never return focus.
Automatic insertion targets the field captured when recording started,
provided its application is still frontmost and the target remains valid.
Retries require explicit confirmation, copy their
result, and never automatically insert. Otherwise only the clipboard
is updated. Automatic insertion can also be disabled in the menu. Accessibility
identity checks cannot atomically lock another application's focus or prove that
it actually applied an accepted insertion command. The UI therefore asks the
user to check the target, and preserves the manual text recovery path.

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
the next pruning pass. The limits describe the managed recovery directory;
preserved temporary originals and crash leftovers are described below. Short/quiet recordings are retained for deliberate manual retry; a heuristic skip does not upload them automatically.

Recordings created by an older version have no authentication tag and are not
eligible for upload. They remain available to the explicit delete action.

## Local log

`~/Library/Logs/OpenDictate.log` contains operational metadata such as times,
bundle and audio paths, selected model, input-device and application names,
durations, levels, status, and error descriptions. It does not intentionally log
API keys, transcript text, or audio contents. Logging is serialized and rotated at approximately 1 MiB, keeping one previous file. No timed log expiry is implemented.

## Last transcript and temporary originals

The most recent non-empty transcript is also held in memory until replaced, cleared from the menu or the app exits. No persistent text history is created. If a recovery-store write fails, the original temporary audio is deliberately not deleted and its path is shown in the error status. Historical crash leftovers are not swept automatically because they may contain the only surviving recording.
