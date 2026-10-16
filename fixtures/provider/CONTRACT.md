# Provider contract for transcription uploads

One request format for the macOS, Linux and Windows clients, checked against
the shared files in this folder instead of per-platform inline strings. Only
the provider side is shared; each client keeps its own code. Decided on
2 October 2026 ([Plan-4-Notiz](../../docs/plan4-aenderungen-2026-10-02.md#3-ein-provider-vertrag-für-mac-linux-und-windows)).

## Request

- `POST <base>/audio/transcriptions`. The base address defaults to
  `https://api.openai.com/v1`; a custom server replaces only the base.
- `Authorization: Bearer <key>` for OpenAI and other `https://` servers. A
  server on the same computer (loopback) gets no header. macOS, Linux and
  Windows implement this.
- `Content-Type: multipart/form-data` with these fields in this order:
  1. `model`
  2. `response_format` = `json`
  3. optional language: `languages[]` when the model is `gpt-transcribe`,
     otherwise `language`
  4. optional `prompt` (vocabulary; macOS and Linux)
  5. `file`, with a fixed transport filename and type:

| Platform | Filename | Content-Type |
| --- | --- | --- |
| macOS | `recording.m4a` | `audio/mp4` |
| Linux | `recording.wav` | `audio/wav` |
| Windows | `recording.wav` | `audio/wav` |

- Audio must be non-empty and at most 25 MiB (26,214,400 bytes); macOS and
  Linux reject larger or empty audio locally before any request. Windows
  instead limits a recording to 90 s of WAV (2,880,044 bytes).
- Timeouts: macOS 30 s without data and 120 s overall; Linux 10 s to connect,
  then a 15 s response budget (120 s for a custom server) plus upload time at about 2 Mbit/s; Windows 60 s
  overall (180 s for a custom server).

## Response

- `2xx` with a JSON object containing `text`
  ([response-ok.json](response-ok.json)). All clients trim surrounding
  whitespace. For a server of the user's own, macOS also joins line breaks
  between segments (whisper.cpp ends each segment with one) into single spaces;
  Linux and Windows do not yet. An empty result keeps the recording for retry.
- Any other status is an error. Every client shows its own message and never
  the provider's raw text. On macOS, the OpenAI error `code` (or `type` when
  `code` is missing) selects a more specific message; Linux and Windows map by
  status code and by whether the server is OpenAI, a custom server or one on
  this computer.

## Cases

[cases.json](cases.json) lists each fixture with its status code and, per
platform, a phrase the user-facing message must contain:
`mac_message_contains`, `linux_message_contains` and `windows_message_contains`
(the Linux and Windows phrases are those for OpenAI as the server, with a
German display language).

| Fixture | Status | Meaning |
| --- | --- | --- |
| [error-401.json](error-401.json) | 401 | key rejected (`invalid_api_key`) |
| [error-413.json](error-413.json) | 413 | upload too large, no code |
| [error-429.json](error-429.json) | 429 | quota used up (`insufficient_quota`) |
| [error-500.json](error-500.json) | 500 | provider unavailable, no code |

## Explicit vocabulary

The additive `vocabulary` case in `cases.json` contains `entries` and the
exact joined `prompt`. Existing success/error cases are unchanged. Linux
accepts up to 64 non-empty entries and 800 UTF-8 bytes including `, ` separators,
rejects controls and surrounding whitespace, and sends no prompt when empty.
This is a conservative application bound, not a guarantee about token count:
Whisper considers only its last 224 prompt tokens. The Mac stores free-form
context without this list bound; Linux bounds a short list of spelling hints.

Official API checked on 16 October 2026:
[transcription context](https://developers.openai.com/api/docs/guides/speech-to-text#add-transcription-context)
also documents `keywords[]` for `gpt-transcribe`. These clients keep `prompt`
for compatibility with all offered models and custom servers; no undocumented
keyword field is sent. Hints do not guarantee recognition or permit rewriting.
