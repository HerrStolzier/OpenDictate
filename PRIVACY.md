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

## Clipboard and automatic paste

The transcript is written as plain text to the macOS general clipboard. Any
local application with clipboard access may be able to read it.

OpenDictate cannot reliably observe whether a target control accepted the paste
shortcut. It therefore leaves the transcript on the clipboard until another
clipboard write replaces it, preserving a manual recovery path when automatic
paste is unavailable or ineffective. Clipboard managers may retain their own
copy; OpenDictate cannot remove that copy.

Automatic paste targets the process that was active when recording started (or
when retry started). OpenDictate waits for that process to become frontmost and
sends `Cmd+V` to its PID. It cannot prove that the same text field remains
focused inside that process.

## Failed recordings

When transcription fails, OpenDictate keeps a recovery copy under
`~/Library/Application Support/OpenDictate/failed/`. The directory is restricted
to the current user, recordings and authentication files use owner-only modes,
and retry accepts only recordings authenticated with a device-local Keychain
secret. OpenDictate applies the five-file and 24-hour limits to all recognized
recording files, including legacy files or files whose authentication tag cannot
be verified. It also deletes a recording after a successful retry, or when the
user chooses **Delete Saved Recordings...**.

Recordings created by an older version have no authentication tag and are not
eligible for upload. They remain available to the explicit delete action.

## Local log

`~/Library/Logs/OpenDictate.log` contains operational metadata such as times,
bundle and audio paths, selected model, input-device and application names,
durations, levels, status, and error descriptions. It does not intentionally log
API keys, transcript text, or audio contents. The log currently has no automatic
expiry; delete the file manually if required.
