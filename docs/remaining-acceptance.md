# Remaining acceptance and optional extensions

This is the single current handoff; no parallel STATUS.md is maintained.
Product decisions live in [PROJECT.md](../PROJECT.md), approvals in
[APPROVALS.md](../APPROVALS.md), and procedures in [CHECKS.md](../CHECKS.md).

## Aktueller Übergabestand — 2026-09-17

Die Roadmap-Abnahme hat einen zusätzlichen Brave-Langtextfehler
reproduziert und für die konkrete 600-Wiederholungen-Probe korrigiert: nun exakt
28.199 UTF-16-Einheiten in 1.500 Chunks statt zuvor 27.154 in 1.419 Chunks.
Brave verwendet dafür eine eigene Zeilenumbruch-Policy; Safari und Obsidian
behalten ihre jeweiligen Pfade. Auch kurze LF- und CRLF-/Leerzeilenproben sind
nach ungestörter GUI-Prüfung exakt bestanden; keine CR-Normalisierung ergänzt.
Ein nativer Feldwechsel während zehn Sekunden synthetischer Aufnahme wurde
verlustfrei abgefangen: beide Felder unverändert, vollständiger Text auf der
isolierten Testzwischenablage. Diese Prüfungen verwenden keine Mikrofonaufnahme
und keinen Providerrequest.

Ergänzt sind drei Offline-Lifecycle-Abbruchtests, ein Transkriptauswerter mit fünf
Tests und ein Ressourcensampler mit drei Tests. 134 Swift-Tests, acht Python-Tests
sowie Format-, Shell-, Diff- und Bundleprüfungen bestanden. Der installierte
Kandidat hat die echte Mikrofon-/Provider-/automatische Zielkette in Brave
`input`, `textarea`, `contenteditable` und iframe sichtbar bestanden, jeweils
mit vollständiger Auswahlersetzung ohne manuelles Einfügen. Der
90-Sekunden-Aufnahmestopp samt Countdown ist belegt. Sechs Aufnahmen und sechs
Uploads verbrauchten konservativ höchstens 210 Sekunden; die freigegebene
Versuchszahl ist ausgeschöpft. Die beabsichtigten nativen Versuche belegen nur
Fallback beziehungsweise Einfügung im tatsächlich aktiven Brave-iframe, keine
native E2E-Abnahme. Begrenzte CPU-/RSS-Messungen, Kandidatenidentität, konkrete
Fälle und instrumentierte Latenzwerte stehen im
[Abnahmebericht vom 17. September](roadmap-acceptance-2026-09-17.md).

Aktiv offen bleiben reale Zielabnahmen in nativen Feldern, Safari und Electron,
fehlende Feld-/Fokusphasen der Kompatibilitätsmatrix, physischer Hotkey,
reale Geräte-/Systemfehler und Beenden während Aufnahme/Upload,
gehörtes VoiceOver sowie menschliche Sprachqualität samt Latenz und
Korrekturaufwand. Eine erzeugte Referenz über Lautsprecher und Mikrofon kann die
technische Kette prüfen, ersetzt aber keinen menschlichen Sprachkorpus. Öffentliche
Veröffentlichung sowie Streaming und Hold-to-talk bleiben außerhalb dieser Abnahme.
Lautstärke auf 62,5 Prozent und ursprüngliche Recoverydateien sind wiederhergestellt;
Dateihashes/-modi und Präferenzhash stimmen. Eigene Testfenster und Prozesse sind
geschlossen; erzeugte Audio-/Referenzdateien und Fixture-Bundles entfernt, keine
Live-Tempaufnahmen verblieben. Der Offline-Evaluator bestätigt WER 0 für 70
Referenzwörter in fünf kurzen synthetisierten Sprachproben, keine menschliche
Sprachqualität. Energie und langfristiges Speicherwachstum sind nicht gemessen.

## Ausgangsstand — 2026-09-16

Die Zielbindung erfasst jetzt beim Start das konkrete Feld, Fenster, Web-Dokument
und die verfügbare Auswahl. Native Felder sowie Safari, Brave und Obsidian wurden
mit dem Produktionseinfüger und künstlichem Text sichtbar geprüft. Die AX-
Scheinbestätigung ohne Texteingabe in Safari/Obsidian ist durch deren gezielten
Unicodepfad korrigiert. Geschützte Felder, nativer Feldwechsel und Brave-Tabwechsel
zeigen den vollständigen manuellen Rückweg. Tastaturdialog, Countdown/Pegel bei
Mindestbreite, echte temporäre Recovery-Dateien und native Hotkey-Kollision sind
ebenfalls geprüft. Kandidat, Prüfarten und Installation:
[Abnahmebericht vom 16. September](roadmap-acceptance-2026-09-16.md).

Offen bleiben eine neue echte Mikrofon-/Provider-Abnahme dieses Kandidaten,
physische Gerätewechsel/Abziehen, native 90-Sekunden-Aufnahme, reale
Berechtigungs-/Keychainfehler, Beenden während echter Aufnahme, menschlicher
Sprachkorpus samt Latenz/Korrekturaufwand und gehörte VoiceOver-Ausgabe.
Feld-/Tab-/Fensterwechsel sowie ein App-Wechsel während laufender Unicode-Chunks
sind sichtbar geprüft, jeweils mit vollständigem Kopiertext. Anfang/Ende sind für
native Felder, Safari-Feldtypen und Obsidian ergänzend belegt. Safari-Langtext
(28.199 UTF-16-Zeichen), CRLF und Leerzeilen sind nach einer Korrektur der
Chunkgrenzen exakt geprüft. Eine vollständige Phasenmatrix ist nicht belegt.
Chrome verlangt Ersteinrichtung; Firefox fehlt.
Kein pauschaler Nachweis für sämtliche Browser oder Electron-Apps.

## Produktplan und historische Ausgangsevidenz — 2026-09-15

Die Produktphase prüft eine repräsentative
[Kompatibilitätsmatrix](compatibility-matrix.md) nach Eingabefeldtypen und
Nutzungssituationen. Einzelne persönliche Programme bestimmen nicht den
Produktumfang. TextEdit, Browser und Electron-Programme sind Beispiele für
Kategorien; ein bestandener Lauf belegt nur die konkret geprüfte Kombination.

Priorisierte nächste Schritte:

1. Native Felder, Browser-`input`/`textarea`/`contenteditable`/`iframe` und ein
   Electron-Feld mit Cursorposition, Auswahl, mehrzeiligem Unicode und
   App-/Fenster-/Tabwechsel abnehmen. Ablehnung und geschützte Felder müssen einen
   verständlichen, verlustfreien Zwischenablage-Rückweg zeigen.
2. Danach Aufnahme-, Geräte-, Abbruch-, Fehler- und Recoveryfälle robust prüfen.
3. Anschließend VoiceOver, Tastaturbedienung sowie Sprachqualität, Latenz und
   Korrekturaufwand systematisch prüfen.

Damals vorhandene Evidenz: Der Produktionseinfüger wurde synthetisch in einem Brave-
`textarea` und `contenteditable` sichtbar geprüft, ein echter TextEdit-Durchlauf
wurde beobachtet und ein Proton-Diktat in Brave vom Nutzer ausdrücklich bestätigt.
Diese drei Nachweisarten sind verschieden. Die Brave-spezifische Unicode-Korrektur
belegt weder andere Browser noch Electron. Iframe, weitere Browser-Engines,
Electron, vollständige Fokuswechselmatrix und sichtbarer Fallback bei einem
abgelehnten Feld waren damals offen. Der aktuelle Stand steht oben.

Die folgenden datierten Abschnitte sind historische Nachweise ihrer jeweiligen
Kandidaten. Sie ändern diese heutige Priorisierung nicht.

## Historischer Nachweis: Brave insertion regression — 2026-09-15

The installed candidate replaces ineffective AXSelectedText delivery in Brave
with exact process-scoped Unicode input, rechecking foreground app and focused
field before each chunk. Other applications retain their existing AX path.
110 offline tests and stable signed-bundle verification passed.

Synthetic delivery through the production inserter is visibly confirmed in a
normal Brave textarea and a contenteditable editor. A longer Unicode sample
with a line break replaced only the selected text, preserving both surrounding
parts. No manual paste, microphone or provider request was used for these
candidate checks. Exact evidence and helper diagnosis:
[Brave insertion report](brave-insertion-2026-09-15.md).

The original real-app/hotkey failure and the later attended Proton/Brave
acceptance are recorded in that report. The user confirmed that a normal
dictation with the installed correction automatically inserted into the actual
Proton editor in Brave. Iframe insertion, selection behavior in Proton and a
live interruption between chunks remain unevidenced. The additional native
helper check was blocked by the foreground guard; the unchanged native AX path
has not been newly accepted. These limits do not invalidate the observed local
contenteditable insertion or the user-confirmed Proton path.

Installation, exact executable identity and Git integration status are recorded in the report.
The test helper was stopped, the exact local test tab was closed, and its
owned temporary files were removed. Existing browser windows were preserved.

## Historischer Nachweis: Documentation pilot — 2026-09-14

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

The source changes and offline tests did not activate the app or prove real dictation quality. That historical documentation task did not authorize installation, app replacement, publication or paid transcription requests.

## Historischer Nachweis: Native recording panel integration — 2026-09-15

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

Diese damalige Grenze wird heute durch die vollständige Kompatibilitätsmatrix
konkretisiert. Historische September-13/14-Evidenz bleibt auf ihre Kandidaten begrenzt.

## Historischer Nachweis: Compact settings — 2026-09-15

The daily settings now show four main options, with collapsible advanced options
and separate recording/help pages. Native UI, keyboard navigation and compact/
large windows were checked; 105 offline tests and signed-bundle verification
passed. Stored preferences and the user's existing short recording were verified
unchanged by before/after hashes. No new audio or provider request was needed.
See [settings acceptance](settings-acceptance-2026-09-15.md) for the exact candidate
and scope. The window-close/menu-bar lifecycle is also confirmed in the earlier
[September 15 report](live-acceptance-2026-09-15.md#window-lifecycle-follow-up).

## Historische Live-Abnahmen

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

Robustheits- und Qualitätsnachweise nach der Kompatibilitätsmatrix:

- Current Keychain state: users of the older helper must save the API key once through the in-app dialog. Confirming the real item's narrowed ACL is a credential-state check and remains separately authorized.
- Microphone permission denied; built-in versus selected external input; visible elapsed time and low level; native 90-second stop; unplug/interruption.
- Custom shortcut keyboard navigation and real Carbon collision/registration rollback are covered by the September 16 checks. An actual physical shortcut press in the installed candidate remains a separate live check.
- Clipboard-failure retention is covered by deterministic flow tests, and the complete manual panel/copy action is visibly checked. Heard VoiceOver recognition of recording state, countdown and cancel/discard distinction remains open.
- App end during a real recording/transcription remains open. Real temporary recovery creation failure on recording/processing cancellation preserves the original and reports failure in the September 16 filesystem checks.
- Real speech corpus and reference transcripts, followed by authorized API requests: language options, proper names, mixed languages, short/quiet words, actual request latency and correction effort.
- GitHub checks run for the triggers in `.github/workflows/checks.yml`; Git routine follows the governing implementation authorization. Notarization/public binary distribution is not part of the local build.

## Review 26: streaming

Deferred until a real request baseline and usable preview UX are measured. File streaming is documented by OpenAI, but an event parser alone would not establish end-to-end usefulness. A later candidate needs incremental UTF-8/SSE parsing, bounded event buffers, duplicate/partial-event handling, explicit final-event validation, cancellation, one final clipboard delivery, and measurements of time to first text versus final text. Do not insert uncommitted partial text into the target field or silently retry a streaming request. No streaming flag is enabled in this change.

## Review 25: hold-to-talk

The optional hold-to-talk mode is deferred. Custom toggle shortcuts are supported. A hold mode additionally needs key-release delivery through app switches, missed-release recovery and accessibility testing. The existing native duration limit remains the backstop.

## Review 7: crash leftovers

New start/export failure paths clean their own partial outputs. The flow preserves the original if copying into recovery fails. It deliberately does not sweep historical temp audio by filename: such a file might be the only remaining copy after a crash or failed save. A future crash-recovery feature should establish ownership and recovery consent before deleting legacy recordings.
