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

## Unusual replies (Rust and C#)

The additive `edge_cases` list leaves the existing Swift success/error schema
unchanged. Rust and C# read the same response files. `text_repeat` generates a
large synthetic text without checking a megabyte into source control.
HTTP 400/403/404/502/503 and redirects 301/302/307 fail once. Redirects are never
followed, even if their body contains a usable transcript. Missing/invalid
JSON or missing/non-string text fails; empty or whitespace text returns empty
and the existing dictation flow retains the recording without delivery.

Linux now matches Windows' bounded response policy: at most 131,072 body bytes
and 16,000 UTF-16 code units of trimmed/sanitized text. This comfortably covers
a 90-second dictation; oversized replies are rejected, never truncated into a
possibly misleading transcript. Linux previously allowed up to 1 MiB and did
not cap text independently. Both accept valid JSON under a wrong Content-Type
for compatibility with local servers; content is still parsed and bounded.
The provider error body is never shown. The existing flow tests separately
cover audio retention for errors/empty replies; transport tests alone do not
prove a live dictation or target-field insertion.
