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
service `OpenDictate` and account `OPENAI_API_KEY`. OpenDictate does not support
supplying the key through a command-line argument or environment variable.
The optional shell helper restricts a new item to the built OpenDictate bundle.
Saving through the in-app dialog deletes and recreates an existing item under
the app's access policy, including items created by an older helper.

## Clipboard and automatic insertion

The transcript is written as plain text to the macOS general clipboard. Any
local application with clipboard access may be able to read it.

OpenDictate leaves the transcript on the clipboard until another clipboard write
replaces it, preserving a manual recovery path when automatic insertion is
unavailable or ineffective. Clipboard managers may retain their own copy;
OpenDictate cannot remove that copy. Automatic insertion does not read or paste
from the clipboard: it sends the transcript directly to the focused
Accessibility text element in the accepted target process.

If the focused control does not expose a settable selected-text Accessibility
attribute, automatic insertion stops and the transcript remains available only
through the clipboard. OpenDictate does not fall back to an automatic `Cmd+V`
because that would again consume mutable global clipboard contents.

Automatic insertion targets the process that was active when recording started (or
when retry started), provided it is still frontmost. Otherwise only the clipboard
is updated. Automatic insertion can also be disabled in the menu. It cannot prove that the same text field remains
focused inside that process.

## Failed recordings

When transcription fails, OpenDictate keeps a recovery copy under
`~/Library/Application Support/OpenDictate/failed/`. The directory is restricted
to the current user, recordings and authentication files use owner-only modes,
and retry accepts only recordings authenticated with a device-local Keychain
secret. OpenDictate applies the five-file and 24-hour limits to all recognized
recording files, including legacy files or files whose authentication tag cannot
be verified. It also deletes a recording after a non-empty retry transcript reaches the clipboard, or when the
user explicitly deletes it. Expiry is checked before retry and periodic pruning runs while the app is open. Short/quiet recordings are retained for deliberate manual retry; a heuristic skip does not upload them automatically.

Recordings created by an older version have no authentication tag and are not
eligible for upload. They remain available to the explicit delete action.

## Local log

`~/Library/Logs/OpenDictate.log` contains operational metadata such as times,
bundle and audio paths, selected model, input-device and application names,
durations, levels, status, and error descriptions. It does not intentionally log
API keys, transcript text, or audio contents. Logging is serialized and rotated at approximately 1 MiB, keeping one previous file. No timed log expiry is implemented.

## Last transcript and temporary originals

The most recent non-empty transcript is also held in memory until replaced, cleared from the menu or the app exits. No persistent text history is created. If a recovery-store write fails, the original temporary audio is deliberately not deleted and its path is shown in the error status. Historical crash leftovers are not swept automatically because they may contain the only surviving recording.
