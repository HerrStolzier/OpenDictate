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

Installation and Git integration pending at report creation. No public release.
Actual Proton and a new microphone-to-editor acceptance are not established.
The local helper process was stopped; a local-window close attempt was blocked
by active user browser interaction. Preserve that window until it can be
identified and closed safely, and preserve all pre-existing browser windows.
