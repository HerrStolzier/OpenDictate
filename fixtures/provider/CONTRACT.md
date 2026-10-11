# Provider contract for transcription uploads

One request format for the macOS, Linux and Windows clients, checked against
the shared files in this folder instead of per-platform inline strings. Only
the provider side is shared; each client keeps its own code. Decided on
2 October 2026 ([Plan-4-Notiz](../../docs/plan4-aenderungen-2026-10-02.md#3-ein-provider-vertrag-für-mac-linux-und-windows)).

## Request

- `POST <base>/audio/transcriptions`. The base address defaults to
  `https://api.openai.com/v1`; a custom server replaces only the base.
- `Authorization: Bearer <key>` for OpenAI and other `https://` servers. A
  server on the same computer (loopback) gets no header. macOS and Linux
  implement this; Windows follows with the same rule.
- `Content-Type: multipart/form-data` with these fields in this order:
  1. `model`
  2. `response_format` = `json`
  3. optional language: `languages[]` when the model is `gpt-transcribe`,
     otherwise `language`
  4. optional `prompt` (vocabulary; macOS only so far)
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
  overall.

## Response

- `2xx` with a JSON object containing `text`
  ([response-ok.json](response-ok.json)). macOS and Linux trim surrounding
  whitespace; Windows passes `text` unchanged and rejects a whitespace-only
  result. An empty result keeps the recording for retry.
- Any other status is an error. Every client shows its own message and never
  the provider's raw text. On macOS, the OpenAI error `code` (or `type` when
  `code` is missing) selects a more specific message; Linux and Windows map by
  status code, Linux also by whether the server is OpenAI, a custom server or
  one on this computer.

## Cases

[cases.json](cases.json) lists each fixture with its status code and, per
platform, a phrase the user-facing message must contain. Today only
`mac_message_contains` exists; Linux and Windows add their own key when their
tests read these files.

| Fixture | Status | Meaning |
| --- | --- | --- |
| [error-401.json](error-401.json) | 401 | key rejected (`invalid_api_key`) |
| [error-413.json](error-413.json) | 413 | upload too large, no code |
| [error-429.json](error-429.json) | 429 | quota used up (`insufficient_quota`) |
| [error-500.json](error-500.json) | 500 | provider unavailable, no code |
