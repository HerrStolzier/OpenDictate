# Brave direct insertion — 2026-09-15

## Problem and scoped change

The user reported a failed real Option+Shift+Space dictation in the local Brave
contenteditable field. The existing log records request completion at 18:33:24
UTC and 28 ms delivery with no AX failure. The field was observed empty, with
zero input events. Accessibility was enabled; no permission was changed.

Brave now receives the exact transcript as modifier-free Unicode keyboard events
addressed to its PID. No clipboard content is read and no Cmd+V is sent. The
same foreground process and focused AX element are required before each chunk;
cancellation or a failed check stops remaining text. Already posted input cannot
be rolled back. The ordinary non-Brave AX path is unchanged. Submission remains
an unconfirmed delivery outcome, never a claim that every editor accepted it.

## Observed synthetic delivery

A local signed helper compiled the actual production PasteboardInserter and
UnicodeTextDelivery sources. It used fixed artificial text only, never called
copy(), recorded audio, accessed credentials or made a provider request.

- The user's 20:42 screenshot showed exact `Testtext: grüne Äpfel.` in the normal
  textarea and two input events. The formatted field remained empty.
- The helper initially accepted any of three test fields, so it could select
  the old textarea focus during browser activation. This did not prove a
  contenteditable failure.
- Narrowing the helper to AXDescription exposed a second helper bug: the rich
  field's description is empty; its AXTitle is `Formatierter Editor` and role
  AXTextArea. This was directly inspected only within the matching local window.
- The corrected helper requires that exact local window and field title/role,
  with the same PID and CFEqual AX element stable for 600 ms. It uses an elapsed
  120-second deadline. No repeated user click was requested after the diagnosis.
- The exact test sentence was then observed in the middle contenteditable field
  in both AX and screenshot, with the input-event count increasing from 2 to 4.
- Selecting only `grüne Äpfel` and delivering a longer sample with accents, emoji,
  a combining mark, a joined emoji and a newline preserved `Testtext: ` before
  the selection and the original period afterward. AX and screenshot showed
  the full expected result; the event count increased to 10. The resulting two
  final periods were expected: one in the inserted sample and one preserved.

An additional iframe check never submitted input: the actual foreground app
was Safari, so the helper remained gated and was stopped. A native NSTextView
helper also returned false when it could not establish foreground ownership.
Neither attempt is recorded as a product insertion failure or successful test.

## Offline and bundle checks

110 tests in 24 suites passed with warnings as errors. Five new tests check
Unicode/surrogate boundaries, exact event strings without modifiers, target
switches, failed posting and cancellation; they never post system events.
The local default Swift runner could not locate TestingMacros. The native
SwiftPM runner with the installed Testing framework and plugin paths passed.
Format lint, shell syntax checks and diff checks passed. The release bundle
passed Plist, stable certificate signature, Hardened Runtime and microphone
entitlement verification. No signing identity, grant or credential was changed.

## Delivery status and limits

Installed source candidate: `3cdef50`, signed by `OpenDictate Self-Signed`.
The installed executable exactly matches the verified release build, SHA-256:
`8b127138336aeafb5438a0e9a284f03bee940ad803181914550c9ceaf6f29805`.
The prior app is preserved under the local Backups directory in
`before-brave-20260915-210346/OpenDictate.app`. The replacement started at
19:03:51 UTC, registered Option+Shift+Space and visibly showed “Bereit zum
Diktieren”. Preference export and existing recovery-file hashes matched before
and after installation. The helper was stopped before installation.
Git integration: [PR #6](https://github.com/HerrStolzier/OpenDictate/pull/6), gated by repository CI. No public release.

## Attended Proton acceptance

After the installed correction, the user performed a normal dictation with
OpenDictate into a Proton text field in Brave and confirmed: “Funktioniert”.
This is the user's confirmation of the end-to-end microphone, transcription
and automatic-insertion path in the actual intended browser editor. No Proton
message content was read, recorded or sent, and no separate Proton macOS app
was involved. The confirmation does not establish an exact transcript,
selection behavior in Proton, iframe support or handling of an interruption
between Unicode chunks.

The local helper process was stopped. After an initial user-interaction block,
the exact local test window was selected through the Window menu and its only
test tab closed. The changed window state confirmed closure. All agent-created
helper binaries, fixture files, diagnostic snapshots and temporary logs were
removed; the installed app and its original backup remain. No pre-existing
browser window or private Proton content was modified.
