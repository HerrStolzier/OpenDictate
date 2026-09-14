# Remaining acceptance and optional extensions

This is the single current handoff; no parallel STATUS.md is maintained.
Product decisions live in [PROJECT.md](../PROJECT.md), approvals in
[APPROVALS.md](../APPROVALS.md), and procedures in [CHECKS.md](../CHECKS.md).

## Documentation pilot — 2026-09-14

Documentation ownership is implemented and checked against the existing
Git/acceptance handoff. Local links, diff and preservation of technical invariants
passed. No new app functionality or live test is part of this task. The next
product step remains the separately authorized live acceptance below; the documentation
pilot does not authorize it. Detailed pilot evidence is kept in
[the dated pilot report](documentation-pilot-2026-09-14.md).

Documentation Git handoff: [PR #2](https://github.com/HerrStolzier/OpenDictate/pull/2)
tracks upload, CI and merge. The initial upload approval block was resolved by
direct user authorization. The SDK fix from merged PR #1 is integrated for CI;
this does not establish any of the live acceptance below.

The source changes and offline tests do not activate the app or prove real dictation quality. Do not install, launch a replacement app, publish a binary or make paid transcription requests without the corresponding authorization.

## Live acceptance

The 2026-09-14 attended attempt on `6401655` reached microphone permission
checking through the registered Option+Shift+Space shortcut, but macOS denied
access: the Hardened Runtime bundle lacked the audio-input entitlement. The
packaging fix adds it and verifies the final signed entitlement during every
build. Existing local microphone and Accessibility grants matched the previous
ad-hoc binary, so current-candidate permission and live delivery acceptance
remain required. No successful recording or transcription was established by
that attempt.
The corrected local bundle passed signature, Hardened Runtime and entitlement
verification and was restarted with the shortcut registered. Separately signed
temporary bundles with missing, false and string-valued audio-input entitlements
were all rejected by the verifier. These packaging checks do not establish
microphone access, transcription or insertion.

The subsequent attended attempt with the corrected bundle completed audio
preparation and transcription (request: 2.564 s; stop-to-result: 2.595 s).
The delivery path copied a nonempty result successfully, then logged
`accessibility=false, previousApp=TextEdit`. Direct insertion is therefore still
unverified; the current bundle needs a valid Accessibility grant. The transcript
content and visible manual clipboard recovery have not yet been checked.
Packaging fix: [PR #3](https://github.com/HerrStolzier/OpenDictate/pull/3), merged
after the Swift checks and ad-hoc bundle build passed.

The 2026-09-07 candidate proved one human microphone dictation through its then-current `Cmd+V` delivery, conservative no-paste behavior after a foreground-app switch, manual clipboard recovery, cancellation retaining authenticated readable AAC, and two bounded synthetic live API checks. Those microphone, transcription, focus-switch, clipboard and recovery observations remain historical evidence for their exact paths. The successful TextEdit delivery does **not** validate the current direct `AXSelectedText` insertion implementation. See `live-acceptance-2026-09-07.md` for the exact scope and limitations.

Still open:

- Current hardened bundle: direct insertion into TextEdit, clipboard-only fallback when insertion is rejected, and one actually used browser or Electron text control. Confirm that a target switch still prevents insertion. Unsupported controls are allowed to fall back; silent insertion of different clipboard contents is not.
- Current Keychain state: users of the older helper must save the API key once through the in-app dialog. Confirming the real item's narrowed ACL is a credential-state check and remains separately authorized.
- Microphone permission denied; built-in versus selected external input; visible elapsed time and low level; native 90-second stop; unplug/interruption.
- Custom shortcut capture with keyboard-only navigation; collision with another app; original shortcut still works after a failed replacement.
- Clipboard failure exposes last text. VoiceOver recognizes recording state and controls, including the countdown and cancel/discard distinction.
- App end during recording/transcription preserves audio; real failed recovery writes are visible and do not delete the only original.
- Real speech corpus and reference transcripts, followed by authorized API requests: language options, proper names, mixed languages, short/quiet words, actual request latency and correction effort.
- GitHub checks run for the triggers in `.github/workflows/checks.yml`; Git routine follows the governing implementation authorization. Notarization/public binary distribution is not part of the local build.

## Review 26: streaming

Deferred until a real request baseline and usable preview UX are measured. File streaming is documented by OpenAI, but an event parser alone would not establish end-to-end usefulness. A later candidate needs incremental UTF-8/SSE parsing, bounded event buffers, duplicate/partial-event handling, explicit final-event validation, cancellation, one final clipboard delivery, and measurements of time to first text versus final text. Do not insert uncommitted partial text into the target field or silently retry a streaming request. No streaming flag is enabled in this change.

## Review 25: hold-to-talk

The optional hold-to-talk mode is deferred. Custom toggle shortcuts are supported. A hold mode additionally needs key-release delivery through app switches, missed-release recovery and accessibility testing. The existing native duration limit remains the backstop.

## Review 7: crash leftovers

New start/export failure paths clean their own partial outputs. The flow preserves the original if copying into recovery fails. It deliberately does not sweep historical temp audio by filename: such a file might be the only remaining copy after a crash or failed save. A future crash-recovery feature should establish ownership and recovery consent before deleting legacy recordings.
