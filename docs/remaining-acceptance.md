# Remaining acceptance and optional extensions

This is the single current handoff; no parallel STATUS.md is maintained.
Product decisions live in [PROJECT.md](../PROJECT.md), approvals in
[APPROVALS.md](../APPROVALS.md), and procedures in [CHECKS.md](../CHECKS.md).

## Brave insertion regression — 2026-09-15

The working candidate replaces ineffective AXSelectedText delivery in Brave
with exact process-scoped Unicode input, rechecking foreground app and focused
field before each chunk. Other applications retain their existing AX path.
110 offline tests and stable signed-bundle verification passed.

Synthetic delivery through the production inserter is visibly confirmed in a
normal Brave textarea and a contenteditable editor. A longer Unicode sample
with a line break replaced only the selected text, preserving both surrounding
parts. No manual paste, microphone or provider request was used for these
candidate checks. Exact evidence and helper diagnosis:
[Brave insertion report](brave-insertion-2026-09-15.md).

The original real-app/hotkey failure is recorded in that report. A new
microphone-to-editor test of the installed fix, actual Proton editor, iframe
insertion and live interruption between chunks remain unevidenced. The additional
native helper check was blocked by the foreground guard; the unchanged native
AX path has not been newly accepted. These limits do not invalidate the observed
local contenteditable insertion.

Installation and Git integration are recorded in the report when completed.
The test helper was stopped. Closing the local test window was blocked by active
user browser interaction; do not close an unrelated or private Brave window.

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

## Native recording panel integration — 2026-09-15

The existing central recording panel and separate settings window are integrated
with the current SDK, direct Accessibility delivery and microphone entitlement
fixes. The installed candidate `5a672f7` passed 104 offline tests, format/shell
checks and release bundle verification; GitHub CI also passed.

One attended human microphone → transcription → automatic TextEdit insertion
passed on September 15. The artificial sentence was visibly correct in the
prepared target field; user feedback, panel state and matching operational logs
support the result. The test document was discarded and TextEdit closed. The
installed daily app remains running. Exact candidate, timing, focus evidence and
limits: [September 15 acceptance](live-acceptance-2026-09-15.md).

Browser/Electron controls and a live switch-away case remain open. Historical
September 13 and 14 evidence remains scoped to its original candidates.

## Compact settings — 2026-09-15

The daily settings now show four main options, with collapsible advanced options
and separate recording/help pages. Native UI, keyboard navigation and compact/
large windows were checked; 105 offline tests and signed-bundle verification
passed. Stored preferences and the user's existing short recording were verified
unchanged by before/after hashes. No new audio or provider request was needed.
See [settings acceptance](settings-acceptance-2026-09-15.md) for the exact candidate
and scope. The window-close/menu-bar lifecycle is also confirmed in the earlier
[September 15 report](live-acceptance-2026-09-15.md#window-lifecycle-follow-up).

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
`accessibility=false, previousApp=TextEdit`. This attempt established no direct
insertion; the later manual fallback and stable-candidate test are recorded below.
Packaging fix: [PR #3](https://github.com/HerrStolzier/OpenDictate/pull/3), merged
after the Swift checks and ad-hoc bundle build passed.

### Stable local identity — 2026-09-14

The user confirmed the transcript was correct after manual clipboard paste;
this establishes that fallback, not direct insertion. The installed daily-use
copy at `~/Applications/OpenDictate.app` was backed up, replaced with the current
microphone-enabled bundle signed by `OpenDictate Self-Signed`, and restarted.
The local certificate expires on 2027-09-14. No private key was exported.
The private key's persistent `codesign` exception was removed through Keychain
Access; future signing should require individual approval.

The old Accessibility entry was replaced through System Settings. Its enabled
requirement now matches the installed app's certificate identity, rather than
an old ad-hoc code hash, including after restart. The existing API-key ACL was
extended to the installed app; the user had already approved this app for the
recording-authentication item. Neither secret was replaced. The restart logged
successful shortcut registration and no new Keychain prompt was observed.
Both microphone and Accessibility grants now match this stable installed
candidate's signature, verified after the attended test below. Temporary setup
windows and all temporary TextEdit documents have been closed.

### Direct TextEdit insertion — 2026-09-14, 21:57 CEST

Candidate: installed `~/Applications/OpenDictate.app`, source including packaging
fix `ab9f1b3`, signed by `OpenDictate Self-Signed`, CDHash
`d495368f28bbf1bcb87444dbffa1f9118ac883fb`. TextEdit was initially not running.
Exactly one fresh empty document was created and focused. The user started and
stopped human microphone dictation with Option+Shift+Space, without Cmd+V, and
confirmed automatic insertion worked. The resulting text was verified in the
native accessibility tree and screenshot:
"Dies ist ein kurzer Test. Sieben Äpfel liegen auf dem Tisch."

Matching operational logs show preparation, a 1.810 s transcription request,
29 ms delivery and 1.863 s stop-to-result, without a fallback/error entry for
that attempt. User observation plus visible field content establish the direct
insertion result; timings alone would not. The test document was immediately
discarded without saving and TextEdit terminated, confirmed by process check.
The daily-use OpenDictate app remains running. No additional recording, retry,
browser test or general speech-quality assessment was performed.

The 2026-09-07 candidate proved one human microphone dictation through its then-current `Cmd+V` delivery, conservative no-paste behavior after a foreground-app switch, manual clipboard recovery, cancellation retaining authenticated readable AAC, and two bounded synthetic live API checks. Those microphone, transcription, focus-switch, clipboard and recovery observations remain historical evidence for their exact paths. The successful TextEdit delivery does **not** validate the current direct `AXSelectedText` insertion implementation. See `live-acceptance-2026-09-07.md` for the exact scope and limitations.

Still open:

- Current hardened bundle: one actually used browser or Electron text control, and clipboard fallback for a control that rejects insertion. Confirm that a target switch still prevents insertion. TextEdit direct insertion and the earlier missing-permission clipboard fallback are evidenced above. Unsupported controls are allowed to fall back; silent insertion of different clipboard contents is not.
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
