# Remaining acceptance and optional extensions

The source changes and offline tests do not activate the app or prove real dictation quality. Do not install, launch a replacement app, publish a binary or make paid transcription requests without the corresponding authorization.

## Live acceptance

Already evidenced on 2026-09-07 and not to be repeated merely to rebuild the record: one human microphone dictation pasted into TextEdit; conservative no-paste behavior after a foreground-app switch; manual availability of that transcript from the clipboard; cancellation retaining an authenticated, readable AAC recording; and two bounded synthetic live API checks. See `live-acceptance-2026-09-07.md` for the exact scope and limitations.

Still open:

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
