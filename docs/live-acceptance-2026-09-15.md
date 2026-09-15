# Native recording panel acceptance — 2026-09-15

## Candidate

Source: `5a672f70480f03fc70dc2dae6e5bc08f2d826ca5`, integrating the existing
native panel with main `53fb666`. Installed path: `~/Applications/OpenDictate.app`.
Executable SHA-256:
`7df2f0e0cef8a016f2a075714ca5926429b20440a1ee9ceaea6c58fdaaa8d9f6`.
The installed file matched the tested build exactly. Signature, Hardened Runtime
and microphone entitlement verification passed. The designated requirement
matched the existing local certificate identity. The previous app was backed up
before replacement; no credentials, grants or signing identity were changed.

## Verification

- 104 offline tests passed with warnings treated as errors; format and shell syntax
  checks passed. GitHub CI run `34955923243` passed format, tests and bundle build.
- The real installed AppKit panel and separate settings window were inspected
  through the native accessibility tree and screenshot.
- TextEdit was not running at the start. One new empty document was created and
  its text field focused. Basti was asked to start and stop with the panel button,
  speak the artificial sentence below, and not manually paste.
- The attended run completed at approximately 12:04:59 CEST. Basti reported
  “Sorry, es scheint zu funktionieren”. No new test was requested after that
  feedback, and the agent did not insert or paste the result.
- The existing document contained exactly “Sieben grüne Äpfel liegen auf dem Tisch.”,
  verified in both its native text field and screenshot. The panel displayed
  “Diktat verarbeitet.” and stated that automatic insertion had been triggered.
- Matching operational logs showed audio analysis/preparation, a 2301.52 ms
  transcription request, 26.85 ms delivery and 2374.08 ms stop-to-result. There
  was no fallback or delivery-error entry for this run. The panel's unconfirmed
  delivery state is reached only after the direct insertion operation succeeds.

Together, user feedback, unchanged empty-document setup, visible target text,
production panel state and the matching request/delivery sequence establish one
human microphone → transcription → automatic TextEdit insertion on this candidate.
The agent did not directly observe every click or intermediate recording frame;
button use follows the attended instructions and user feedback, rather than a
separately captured click trace. Focus was sufficient for the production target
and frontmost-application checks to permit direct insertion.

## Cleanup and limits

The test document was discarded through TextEdit's close/save dialog, and
TextEdit was quit. Process and file checks confirmed termination and removal of
its temporary autosaved document. Existing Finder/user windows were preserved.
The installed OpenDictate app remains running for daily use; no preview was started.

This single run is not broad speech-quality, VoiceOver, browser/Electron, target
switch, interruption or 90-second-stop acceptance. The new panel target-return
policy has offline coverage; a live switch-away case remains open. No public app
or website release occurred. See [remaining acceptance](remaining-acceptance.md).
