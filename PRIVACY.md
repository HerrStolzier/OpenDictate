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
local application with clipboard access may be able to read it.

OpenDictate leaves the transcript on the general clipboard until another write
replaces it. Clipboard managers may retain their own copy; OpenDictate cannot
remove that copy. For automatic insertion, OpenDictate remembers the application
that was in front when dictation started, activates it after transcription and
sends Command-V. It checks that Accessibility permission is available, that the
application is then frontmost and that the clipboard still contains the full
transcript. It does not inspect the destination's text or title. A different
field or window in the original application may receive Paste after a focus
change; the app cannot confirm that the target accepted the command. Paste in a
terminal may insert line breaks or executable commands. OpenDictate does not
identify protected, read-only or password controls before Paste. Retries copy their text
but do not automatically paste it.

The recording panel opens only through an explicit user action. Recording,
results, errors and setup reminders update the menu bar and existing panel
contents without showing a hidden window or activating OpenDictate.
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
input-device and application names,
durations, levels, status, and error descriptions. It does not intentionally log
API keys, transcript text, or audio contents. Logging is serialized and rotated at approximately 1 MiB, keeping one previous file. No timed log expiry is implemented.

## Last transcript and temporary originals

The most recent non-empty transcript is also held in memory until replaced, cleared from the menu or the app exits. No persistent text history is created. If a recovery-store write fails, the original temporary audio is deliberately not deleted and its path is shown in the error status. Historical crash leftovers are not swept automatically because they may contain the only surviving recording.

## Linux Clipboard-MVP core (not product scope)

The in-repo Linux CLI is not yet the macOS product or a published Linux product.
On an explicit toggle it records the default PipeWire/Pulse input as an
owner-only WAV. Recordings below one second or without a 50-ms window above
−45 dBFS are not uploaded. Other recordings are sent over HTTPS to OpenAI's
`/v1/audio/transcriptions` endpoint with the selected model and optional
language. The returned transcript is written to the Wayland clipboard
(`wl-copy`); there is no automatic target-app insertion.

Secret Service items use attributes `service=opendictate` and `key=api-key` or
`recording-auth`. The API key is accepted only on stdin. A probe item can be
written, read and deleted to test the service. There is no file, environment or
argument fallback. Settings contain only model and language and are stored under
`$XDG_CONFIG_HOME/opendictate/`.

Pending and recovery audio live under `$XDG_STATE_HOME/opendictate/` (typically
`~/.local/state/opendictate/`). Directories use owner-only mode. A recovery copy
is authenticated with HMAC-SHA256 using a device-local Secret Service value and
binds the file name, creation time and exact bytes. Retry uploads only bytes that
authenticate at access time. Managed authenticated recovery is limited to five
files and 24 hours; unknown or modified files are not uploaded automatically.
Audio is removed only after a non-empty transcript reaches the clipboard.

The operations log under `$XDG_STATE_HOME/opendictate/operations.log` records
bounded events, durations and the captured window class. It must not contain API
keys, transcript text, window titles or audio contents. The Phase-1 core has
offline loopback HTTP evidence only; no live Linux provider request is claimed.
