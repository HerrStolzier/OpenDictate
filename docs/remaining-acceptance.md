# Remaining acceptance and optional extensions

The source changes and offline tests do not activate the app or prove real dictation quality. Do not install, launch a replacement app, publish a binary or make paid transcription requests without the corresponding authorization.

## Live acceptance

The 2026-09-07 candidate proved one human microphone dictation through its then-current `Cmd+V` delivery, conservative no-paste behavior after a foreground-app switch, manual clipboard recovery, cancellation retaining authenticated readable AAC, and two bounded synthetic live API checks. Those microphone, transcription, focus-switch, clipboard and recovery observations remain historical evidence for their exact paths. The successful TextEdit delivery does **not** validate the current direct `AXSelectedText` insertion implementation. See `live-acceptance-2026-09-07.md` for the exact scope and limitations.

Still open:

- Current hardened bundle: direct insertion into TextEdit, clipboard-only fallback when insertion is rejected, and one actually used browser or Electron text control. Confirm that a target switch still prevents insertion. Unsupported controls are allowed to fall back; silent insertion of different clipboard contents is not.
- Current Keychain state: users of the older helper must save the API key once through the in-app dialog. Confirming the real item's narrowed ACL is a credential-state check and remains separately authorized.
- Microphone permission denied; built-in versus selected external input; visible elapsed time and low level; native 90-second stop; unplug/interruption.
- Custom shortcut capture with keyboard-only navigation; collision with another app; original shortcut still works after a failed replacement.
- Clipboard failure exposes last text. VoiceOver recognizes recording state and controls, including the countdown and cancel/discard distinction.
- App end during recording/transcription preserves audio; real failed recovery writes are visible and do not delete the only original.
- Real speech corpus and reference transcripts, followed by authorized API requests: language options, proper names, mixed languages, short/quiet words, actual request latency and correction effort.
- GitHub checks only run after a separately authorized push. Notarization/public binary distribution is not part of the local build.

## Review 26: streaming

Deferred until a real request baseline and usable preview UX are measured. File streaming is documented by OpenAI, but an event parser alone would not establish end-to-end usefulness. A later candidate needs incremental UTF-8/SSE parsing, bounded event buffers, duplicate/partial-event handling, explicit final-event validation, cancellation, one final clipboard delivery, and measurements of time to first text versus final text. Do not insert uncommitted partial text into the target field or silently retry a streaming request. No streaming flag is enabled in this change.

## Review 25: hold-to-talk

The optional hold-to-talk mode is deferred. Custom toggle shortcuts are supported. A hold mode additionally needs key-release delivery through app switches, missed-release recovery and accessibility testing. The existing native duration limit remains the backstop.

## Review 7: crash leftovers

New start/export failure paths clean their own partial outputs. The flow preserves the original if copying into recovery fails. It deliberately does not sweep historical temp audio by filename: such a file might be the only remaining copy after a crash or failed save. A future crash-recovery feature should establish ownership and recovery consent before deleting legacy recordings.
