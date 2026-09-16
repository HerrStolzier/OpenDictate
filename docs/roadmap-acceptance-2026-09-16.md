# Target binding and scoped roadmap acceptance — 2026-09-16

Candidate: the source change accompanying this report, based on `b3f0d0b`.
Checks below use macOS 27.0, Brave 153.1.95.101, Safari 27.0 and Obsidian 1.13.7.
The explicit debug fixture uses the production `DictationFlow`, `InsertionTarget`,
`PasteboardInserter` and `DictationPanel`, artificial text, and a unique pasteboard.
No microphone, provider request or personal document is a test input.

## Corrections

- Capture field/window/web-document identity and available selection at recording
  start. Reject changed, protected, explicitly disabled or non-writable targets.
  Delivery never adopts the newly focused field or activates another app.
- Native `NSTextView` may omit `AXEnabled` while exposing a writable selection.
  Absence no longer means disabled; explicit false still rejects insertion.
- Safari and Obsidian accepted an AX setter without changing the selected test
  text. Their web editors now join Brave's exact, process-addressed Unicode path.
  There is no second-method retry after an accepted command and no general
  Electron/browser support claim.
- A complete 600-repeat Safari probe exposed deterministic text loss when a
  Unicode event began with a newline followed by more text (27,209 versus 28,199
  UTF-16 units). Increasing the delay from 5 to 25 ms reproduced the same loss.
  Safari line breaks now occupy separate events (one CRLF remains one event),
  with offline regression tests. Other Unicode editors retain grouped text:
  applying Safari's rule to Obsidian omitted newlines and was corrected before
  acceptance. The production cadence remains 5 ms; no destination text is read.
- Shortcut dialog: Tab/Shift+Tab, Escape and Return work with ordinary macOS
  keyboard settings; an unfocused capture view does not consume other shortcuts.
- Recording panel: elapsed time, low input level and the final countdown are
  visible. Hidden-to-visible status and the 10/5-second milestones emit accessible
  announcements. Emitting an AX announcement is not a VoiceOver listening test.

## Visible synthetic evidence

The multiline sample is `Äpfel 🍏 und Grüße.` followed by a newline and
`Zweite Zeile: é, 👩🏽‍💻.`; the single-line fixture replaces that newline with a space.

| Case | Observed result |
|---|---|
| Native text field, cursor within existing text | Exact sample inserted, surrounding `Anfang.` and ` Ende.` retained. |
| Native `NSTextView`, selection | `MARKIERUNG` replaced by the multiline sample; prefix/suffix retained, AX and screenshot checked. Missing `AXEnabled` regression reproduced and corrected on the same field. |
| Brave `input` | Single-line Unicode sample inserted after `Anfang.`, suffix retained. |
| Brave `textarea` | Multiline sample appended exactly at the current cursor. |
| Brave `contenteditable` and iframe | Actual keyboard selection `MARKIERUNG` replaced exactly, with prefix/suffix preserved. AX and screenshot checked. |
| Safari `input` | Single-line sample inserted at the prepared cursor; prefix/suffix preserved. |
| Safari `textarea`, `contenteditable`, iframe | Same selection replacement with multiline Unicode; visible/AX results checked. |
| Obsidian editor in isolated temporary vault | Same replacement, screenshot and AX checked; saved test Markdown byte-for-byte equal to the expected UTF-8 file. |
| Obsidian cursor beginning/middle/end | Each exact multiline result checked in AX and in the saved Markdown file; existing text retained. Final screenshot checked. |
| Native and Brave password/readonly fields | No insertion; password remains visibly empty, readonly text unchanged; full sample retained on unique test pasteboard. |
| Native A→B switch during delayed processing | Both fields unchanged from their pre-run state; `textAvailable`, full sample retained. |
| Brave tab switch during delayed processing | Original target captured; new local tab received no text; `textAvailable`, full sample retained. |
| Manual fallback panel | Full sample visible, explicit explanation, Space activates “Text kopieren” and status becomes “Letzter Text kopiert”. Only the unique test pasteboard is used. |
| Shortcut dialog | Forward/backward navigation among actual dialog controls; Escape from button cancels; Option+K then Return returns that test shortcut without saving it. |
| Recording panel minimum width | Both 80 s/10 s remaining and 85 s/5 s remaining at 340 px show all text and controls without clipping; artificial −70 dB. |
| Start/end cursor positions | Native single/multiline fields and Safari input/textarea/contenteditable/iframe retain the original text and insert the exact sample at the beginning and end. These complement the middle/selection cases above; they do not cover every app at every position. |
| Safari separate-window switch during delayed processing | Captured target true; new window has an empty address field, original textarea remains `Anfang. Ende.`, zero Unicode chunks, full test pasteboard retained. |
| Live app switch during long Safari Unicode delivery | Opening the fixture result panel changes foreground app. Before the newline fix, delivery stopped after 83/1,419 chunks; on the final candidate it stopped after 66/2,400 chunks. Both report `textAvailable` and retain the complete sample on the test pasteboard; only a prefix is inserted. |
| Complete long Safari textarea | After newline isolation, all 2,400 chunks completed and the observed field exactly matched all 28,199 UTF-16 units of the 600-repeat sample. |
| Safari CRLF and consecutive LF | `Erste\r\n\r\nZweite\n\nDritte` produces exactly `Erste\n\nZweite\n\nDritte` in the textarea: one blank line in each gap, no doubled CRLF. AX, screenshot and full original clipboard checked. |

Early Safari attempts before strict app selection could target the other local
native fixture and are discarded. The fixture now requires both the selected
bundle ID and a local `OpenDictate Matrix` window title. Normal Finder “Open” of
the installed browser established foreground activation; AX selection alone did
not. An early separate-window attempt was interrupted by user interaction and
discarded; the later controlled Safari case above passed. The long-probe fixture
initially compared against an extra trailing space that the production flow trims;
the corrected sample was rerun. No private field received a test insertion.

## Offline and controlled system evidence

### Fixture relaunch incident and recovery

An old debug helper reopened without its CLI mode argument and fell through to
the production delegate. Its startup retention pass removed an expired user
recovery recording. The process was stopped; the audio and authentication sidecar
were restored from the existing Time Machine backup. Their combined SHA-256
inventory exactly matches the pre-task inventory, both files retain mode 0600,
and exported preferences match the pre-task hash. No recording content was read.
An additional UI observation after quitting the old fixture reopened that old
binary again; it was stopped and replaced. The subsequent integrity check still
matched the restored inventory. This was not uninterrupted preservation.

Debug dispatch now recognizes each named helper without CLI arguments and exits
for unknown renamed executables. Both rebuilt matrix helpers were actually
started without arguments: process arguments and their respective native fixture
windows were checked. Recovery and preference inventories remained identical;
there was no further production-delegate startup. The installed daily app remains
stopped, as it was before the task. Existing expiry policy is unchanged.

- Target tests: changed process/window/field/web document, missing start target,
  changed selection, protected/disabled/unwritable field, permission loss,
  own cursor movement, and stopping remaining chunks on target loss.
- Actual temporary recovery copy: authenticated exact bytes and mode 0600;
  original preserved. A regular file occupying the destination-directory path
  creates a real filesystem failure. Recording cancellation and processing
  cancellation both retain the only original and report failure without upload.
  Test keys are constant synthetic bytes, not Keychain material.
- Existing deterministic flow tests cover clipboard failure retaining text/audio,
  empty retries, no overlapping requests, deliberate discard and cancellation.
  Synthetic audio-file tests cover level detection, trimming and playable export.
- Explicit opt-in Carbon test uses temporary Control+Option+Command+F18/F19
  registrations. Real collision rejects replacement; original OS registration
  remains reserved, then both combinations are released and can be registered
  again. No key press, microphone activation or preference change.

## Remaining limits

- No new microphone-to-provider-to-target acceptance for this candidate; historical
  TextEdit and Proton confirmations remain evidence of their older candidates.
- Visible synthetic evidence covers field/tab/window changes during processing
  and a live app switch during Unicode delivery. Long-text fidelity is checked
  specifically in Safari textarea; every phase/category permutation is not
  established. No new real recording/provider phase was run.
- Chrome opened its first-run setup, which was left unchanged; Firefox is absent.
  Other browser/Electron applications remain unverified.
- Physical input change/unplug, denied/revoked TCC access, native microphone
  90-second stopping, real Keychain access failure, application termination during
  a real recording, human speech corpus, actual provider latency/correction effort
  and heard VoiceOver output require separately coordinated acceptance.
- Streaming, hold-to-talk, other operating systems and public release stay deferred.

## Final verification, cleanup and installation

- Final offline suite: 128 tests in 27 suites passed with warnings treated as
  errors. The local Command Line Tools runner needed the existing explicit
  framework/plugin paths; no toolchain was installed. Formatting, shell syntax
  and diff checks passed. The separate opt-in Carbon collision test also passed.
- Release bundle signed with the existing `OpenDictate Self-Signed` identity;
  signature, Hardened Runtime, Plist and microphone entitlement verified.
- Installed at `~/Applications/OpenDictate.app` without launching. Installed and
  built executable SHA-256 both
  `dabd6d6aee5eca7f0d588c9f2b7bee4b15f61461bc49079b8d22c179f2ab915e`.
  Previous app and a protected extra copy of the restored recovery pair are in
  `~/Library/Application Support/OpenDictate/Backups/before-roadmap-20260916/`.
  The extra copy survives the normal expiry pass on the next daily-app start.
- Final preferences and restored recovery inventories match the pre-task hashes.
  Both helper processes are stopped; own Safari/Brave tabs and Finder windows
  were closed. The isolated Obsidian vault was removed from its vault list and
  moved to Trash; the existing personal vault and browser content were preserved.
- Repository automation contains only checks and a local build; no deployment
  records or configured GitHub Pages endpoint were found before push. No public
  release or new permission grant is part of this change.
