# Aktueller Stand und verbleibende Abnahme

Stand: 24. September 2026. Dies ist die einzige aktuelle Übergabedatei.
Produktziel: [PROJECT.md](../PROJECT.md); Regeln: [AGENTS.md](../AGENTS.md);
Prüfverfahren: [CHECKS.md](../CHECKS.md); belegte frühere Testbudgets:
[APPROVALS.md](../APPROVALS.md). Linux-Plan:
[linux-build-plan.md](linux-build-plan.md).

Zwei parallele Arbeitspfade: **macOS-Produktabnahme** (wieder aufgenommen, offen) und
**Linux Phase 1** (Kern in `main`, noch nicht in `PROJECT.md`). Linux markiert
macOS nicht als erledigt.

## Dokumentationsstand

Am 24. September wurden die maßgeblichen Gegenwartsquellen `PROJECT.md`,
`README.md`, `PRIVACY.md`, `CHECKS.md`, diese Übergabe, die
Kompatibilitätsmatrix, die fünf Release-Pläne und der lokale Website-Entwurf
gegen den dokumentierten Build-7-Stand abgeglichen. Veraltete Aussagen über
den installierten Build und den ⌘V-Ablauf wurden korrigiert. Datierte
Abnahmeberichte behalten ihren damaligen Kandidaten und werden dadurch nicht
zu Nachweisen für Build 7. Alle lokalen Markdown-Links und Website-Ressourcen
wurden geprüft. Die aktualisierte Website konnte wegen einer Browser-URL-Sperre
nicht erneut visuell abgenommen werden. Plan 1 und die öffentliche
Release-Dokumentation sind damit weiterhin nicht freigegeben.

Die anschließende [Testbereinigung](test-signal-audit.md) entfernt 22
schwach aussagekräftige oder redundante Testfunktionen. Die verbleibende
Swift-Suite mit 138 Testfunktionen (vier Opt-in-Tests übersprungen) sowie die
acht Python-Tests bestanden lokal; die zwei Rust-Testlöschungen
wurden separat auf `omarchy` gegen exakt `ab839fd5ab64ff69cc5a126e859f804b473b59a5`
geprüft: 23 Rust-Tests, Formatter, Clippy mit `-D warnings` und Release-Build
bestanden offline. Der isolierte Quellbaum aus allen 17 committed `linux/`
Dateien stimmte per SHA-256 überein und wurde nach dem Lauf entfernt; das
bestehende Remote-Checkout blieb sauber. Details und reproduzierbare Befehle
stehen im [Testsignal-Audit](test-signal-audit.md). Produktionscode,
installierter Build und E2E-Nachweise bleiben unverändert. Die Plan-1-Arbeit
ist auf Bastis erneuten Auftrag wieder aufgenommen.

Die [Fortsetzung vom 24. September](release-plans/evidence/2026-09-24-plan1-fortsetzung.md)
belegt für den laufenden Build 7 zehn Minuten Leerlauf mit durchschnittlich
0,02833 Prozent CPU und maximal 81,40625 MiB RSS. Eine aktuelle isolierte
UI-Teilprüfung ergänzt Hell/Dunkel, Tastaturfokus und den Rückweg zum Text.
Ein anschließendes echtes Diktat mit physischem Option+Shift+Space wurde von
Basti bestätigt und direkt im vorher leeren TextEdit-Testdokument verifiziert:
„Dieser Test enthält sieben grüne Äpfel.“ Dieser Build-7-Kürzellauf ist bestanden.
Auch „Text ansehen“ → „Text kopieren“ → manuelles ⌘V wurde mit diesem echten
Transkript und kontrollierter vorheriger Zwischenablage erfolgreich geprüft.
Vier synthetische native Positionen (Anfang/Mitte in ein- und mehrzeiligen
Feldern) wurden mit den unveränderten Produktionsquellen von `523cbd2` exakt
bestätigt; Einzelheiten stehen im
[Fortsetzungsbericht vom 24. September](release-plans/evidence/2026-09-24-plan1-fortsetzung.md).
Die frische Ersteinrichtung bleibt auf Bastis ausdrückliche Entscheidung als
offene Grenze bestehen; kein neues Benutzerkonto wird dafür angelegt. Plan 1
ist insgesamt weiter offen: die verbleibenden Browser-/Editor-Matrixfälle,
reale Störfälle, gehörtes VoiceOver und die 20 per Video zu messenden
lokalen Zustandswechsel sind nicht erledigt. Die realen Einstellungen wurden
inzwischen am installierten Build 7 in der bestehenden dunklen Darstellung
bei Mindestgröße einschließlich Tastaturfokus, Hilfe und Aufnahmen geprüft;
API-Schlüssel und Vokabular wurden dabei nicht geöffnet oder verändert. Frühere
bestandene Tests werden anhand unveränderter Produktionspfade wiederverwendet,
nicht pauschal verworfen.

Die isolierte Vorschau ergänzt inzwischen alle zehn Panelzustände bei
340 Punkten Mindestbreite in Hell und Dunkel. Der neue Safari-textarea-Fall
am Anfang ist vollständig NFC-gleich, aber nicht rohzeichengleich; die
Akzeptanzentscheidung bleibt offen. Die anfänglich ausgebliebene automatische
Safari-`contenteditable`-Übergabe trat auch nach Bastis echten Mausklicks auf.
Im anschließend neu gebauten Debug-Testprozess funktionierten dagegen sowohl
die PID-Diagnose als auch der unveränderte globale Produktionsweg am selben
Feldanfang. Weitere Positionen liefern inzwischen vollständige NFC-Gleichheit.
Die Ursache der früheren Fehlschläge bleibt ungeklärt; ein Wechsel der
Produktions-Zustellart ist durch die Gegenprobe nicht begründet.
[A/B-Nachweis](release-plans/evidence/2026-09-24-safari-pid-versus-global.json),
[kritischer Luna-Max-Review](release-plans/evidence/2026-09-24-critical-plan1-review.md)
und die Einzelwerte stehen im Fortsetzungsbericht. Die Rohabweichungen werden
nicht still als bestanden umgedeutet.

## Neuer Quellcodekandidat: normaler Einfügebefehl

Auf Bastis ausdrücklichen Wunsch ist die automatische Übergabe wieder auf
Zwischenablage, Aktivierung der beim Diktatbeginn aktiven App und ⌘V umgestellt.
Das Feld muss kein setzbares `AXSelectedText` mehr anbieten. Vor dem Tastendruck
werden Accessibility-Freigabe, Vordergrund-App und unveränderter Kopiertext
geprüft. Fenster und Feld sind nicht mehr gebunden: Ein Fokuswechsel kann Text
in ein anderes Feld derselben ursprünglichen App lenken; ein Appwechsel kann
durch die Reaktivierung rückgängig gemacht werden. Der Terminal-Sonderpfad und
seine Zeilenumbruchfilter sind entfallen. Offline-Tests belegen die
Entscheidungslogik. Ein
[begrenzter sichtbarer TextEdit-Test](installed-command-v-2026-09-23.md)
am damaligen Build `bd3630f` bestätigte normales ⌘V ohne Mikrofon, Provider
oder automatischen OpenDictate-Aufruf. Die anschließende
[Plan-1-Liverunde](release-plans/evidence/2026-09-23-plan1-status.md) belegte
am selben installierten Build automatische Einfügung nach fünf echten
Diktaten in TextEdit, Safari, Brave, Obsidian und eine nicht abgeschickte
Terminal-Zeile. Sie belegt diese konkreten Felder, keine allgemeine
Feldkompatibilität. Die historischen Live-Nachweise unten gelten nur für ihre
damaligen Kandidaten.

Die [lokale Plan-1-Matrix](release-plans/evidence/2026-09-23-offline-matrix.md)
zeigt zwei native Feldfälle und beide Fokuswechselarten mit künstlichem Text;
Safari normalisierte im `input` einen kombinierenden Akzent. Nächster
Mac-Nachweis: die übrige sichtbare Feldmatrix mit kontrollierten künstlichen
Texten prüfen. Der Abbruch während Aufnahme bestand;
Providerfehler und tatsächlich unterbrochene Verarbeitung bleiben offen.
Der erste Live-Testblock mit acht Aufnahmen ist verbraucht. Basti hat die
Fortsetzung von Plan 1 ohne festes Kontingent ausdrücklich freigegeben;
Details stehen in [APPROVALS.md](../APPROVALS.md).
Die Quellkorrektur zur Aufbewahrung einer Authentifizierungsdatei bei gesperrter
Audiodatei ist offline getestet und als Build 3 in beiden lokalen App-Pfaden
installiert. Beim Start dieses Builds meldete die App den verweigerten
Löschversuch korrekt; Audio und Authentifizierungsdatei blieben erhalten.
Für den bestehenden API-Schlüssel-Eintrag wurde die installierte App gezielt
als zugriffsberechtigt gespeichert; „alle Programme“ blieb ausgeschaltet.
Ein neuer Lauf erreichte danach ohne Schlüsselbundabfrage die laufende
Aufnahme. Die Aufnahme wurde ohne Provider-Upload abgebrochen und ihre eigene
Recovery-Datei wieder gelöscht. Ein anschließender echter Build-3-Lauf mit
lokaler Systemstimme, Mikrofon und Provider fügte Text automatisch in ein
leeres eigenes TextEdit-Dokument ein. Der erste Versuch blieb wegen stumm
geschalteter Systemausgabe ohne Text; die App erhielt dessen Aufnahme zur
Wiederholung. Nach vorübergehendem Einschalten der Ausgabe bestand der zweite
Versuch. Ausgabe und Testartefakte wurden wieder bereinigt; Einzelheiten im
[Plan-1-Bericht](release-plans/evidence/2026-09-23-plan1-status.md).
Nach einem regulären Neustart las genau dieses installierte Bundle den
API-Schlüssel erneut ohne sichtbare Rückfrage und erreichte einen
Provider-Request. Seine eigene leere Wiederholungsaufnahme wurde danach
einzeln gelöscht. Safari-`iframe` und `contenteditable` scheiterten zunächst
in der künstlichen Matrix. Ein Accessibility-Klick bewegte den Fokus im
eingebetteten Feld nicht zuverlässig. Nach sichtbar gesetztem Fokus bestand
⌘V auch über einen Appwechsel hinweg. Die
[wiederholte Produktions-Fixture](release-plans/evidence/2026-09-23-offline-matrix.md#wiederholung-mit-der-produktions-fixture)
fügte danach in beide Felder sichtbar mehrzeiligen künstlichen Text ein.
Der exakte DOM-Rohvergleich und die übrigen Matrixpositionen bleiben offen.
Die frische zehnminütige [Build-4-Leerlaufmessung](release-plans/evidence/2026-09-23-plan1-status.md)
bestand CPU- und RSS-Ziel mit 0,0017 Prozent und höchstens 97,219 MiB.
Build 3 hatte das RSS-Ziel zuvor stabil um etwa 0,4 MiB überschritten;
die Abweichung bleibt als diagnostischer Befund erhalten.

## macOS-Nachweise vom 22. und 23. September (älterer Kandidat)

Die installierte Revision `68ef919` fügte nach gezielter Erneuerung ihrer
Bedienungshilfen-Freigabe in einem echten Durchlauf mit physischem Kürzel,
Mikrofon und Provider sichtbaren Text in ein zuvor leeres TextEdit-Dokument ein.
Kandidat, Ursache der früheren Fehlschläge, Eingriff, Evidenz und Bereinigung
stehen in der [installierten TextEdit-Abnahme vom 22. September](live-acceptance-2026-09-22.md).
Ein weiterer [enger Terminal-Durchlauf](terminal-focus-acceptance-2026-09-22.md)
fügte per physischem Kürzel und echtem Provider-Request sichtbaren Text in eine
leere Shellzeile ein, ohne Return oder Befehlsausführung. Der danach versuchte
reale negative Fokusfall blieb wegen eines 31-Sekunden-Requestfehlers ohne
Transkript unentschieden. Diese Nachweise gelten nur für ihre Zielzustände;
weitere Feldtypen sowie Einrichtung/Abbruch blieben damals offen. Die damaligen
Mikrofon-Testblöcke sind verbraucht.

Ein [autonomer Wiederholungsversuch](autonomous-focus-acceptance-2026-09-22.md)
lieferte ebenfalls keinen negativen Fokusnachweis. Der Agent überschritt dabei
die neu genehmigte Audio-Obergrenze von 20 Sekunden mit einer 31,272-Sekunden-
Aufnahme. Er beendete den Live-Block nach einem Upload und bereinigte eigene
Artefakte. Die damalige Freigabe endete damit.

**Korrektur vom 23. September:** Basti verwarf die technische Zeitgrenze als
Voraussetzung und beauftragte die Wiederholung. Der
[echte negative Appwechsel](live-focus-acceptance-2026-09-23.md) ist nun für
TextEdit→Finder nach dem Aufnahmestopp mit Provider-Transkript, leerem
Ausgangsfeld und Kopiertext bestanden. Der erste Wiederholungslauf war zu
leise und wurde ohne Upload übersprungen; im erfolgreichen zweiten Lauf war
keine Quellcodekorrektur nötig. Andere Fokusphasen bleiben offen.

## Aktuelle Änderung

[PR #16](https://github.com/HerrStolzier/OpenDictate/pull/16) ist als `0ae6a49`
in `main` gemergt. [PR #17](https://github.com/HerrStolzier/OpenDictate/pull/17)
ergänzt als `83c944f` den offline geprüften Clipboard-MVP-Kern: Zustandsmaschine,
Audio-Prüfung/Trim, HTTPS-Multipart-Client,
Wayland-Clipboard, HMAC-Recovery, authentifizierter Retry, 5-Dateien/24-Stunden-
Retention sowie CLI-Einstellungen für Modell und Sprache. 25 Rust-Tests,
Formatter, Clippy mit `-D warnings` und Release-Build bestanden auf omarchy.
Es gab keinen Live-Upload, keinen API-Key-Zugriff und keinen Mikrofontest dieses
Kandidaten. Technischer Nachweis:
[Linux Phase-1-Kern vom 22. September](linux-phase1-core-2026-09-22.md).

[PR #15](https://github.com/HerrStolzier/OpenDictate/pull/15) ist auf `main`
(`a611f27`): Plan mit beantworteten Fragen, Hyprland-Daemon als Spike-Pfad,
Pflichtpolitik für Phase 1, Tauri nur als spätere UI-Option.

[PR #14](https://github.com/HerrStolzier/OpenDictate/pull/14) korrigiert die
automatische Fensteröffnung beim Diktieren: Das Panel erscheint nur auf
ausdrückliche Benutzeraktion. Das ursprüngliche Zieltextfeld wird vor
asynchroner Vorbereitung, Keychain-Dialogen und einer Fokus-Rückgabe erfasst.
Einstellungen, Hilfe und „Über OpenDictate …“ zeigen die vorhandene Version,
Buildnummer und Quellcodeidentität des tatsächlich laufenden Bundles.
Für Apples Terminal enthält die Änderung einen eigenen Unicode-Eingabepfad:
Ein fokussiertes `AXTextArea` außerhalb eines Webdokuments benötigt dort kein
beschreibbares `AXSelectedText`. Das ursprüngliche Ziel bleibt gebunden;
bekannte nichtleere Markierungen, Secure Event Input und Steuerzeichen im
einzufügenden Text verhindern automatische Eingabe. Fehlende Auswahlmetadaten allein
sind kein neuer Ablehnungsgrund. Return wird nicht automatisch gesendet.
Die gemeldete fehlende Texteingabe erfolgte per Tastenkürzel in Apples Terminal;
die installierte Revision des beobachteten Fehlers war unbekannt. Der Nutzer hat
die Terminal-App ausdrücklich bestätigt. Die aktuellen CI-Ergebnisse ersetzen
weder die Prüfung ihrer tatsächlichen
AX-Struktur noch einen sichtbaren Eingabenachweis.

[PR #13](https://github.com/HerrStolzier/OpenDictate/pull/13) ergänzte die
Stabilisierung aus [PR #12](https://github.com/HerrStolzier/OpenDictate/pull/12):
abgebrochene Vorbereitungen bleiben ungültig, Beenden wartet auf laufende Arbeit,
ein neuer API-Schlüssel wird vor dem Entfernen eines alten Eintrags gespeichert,
und erfolgreiche CI-Läufe stellen überprüfte Entwicklungsarchive bereit.
Die genaue Quellcodeidentität und die tatsächlich ausgeführten macOS-CI-Prüfungen
sind am PR beziehungsweise am zugehörigen Workflow-Lauf nachvollziehbar.
Die Implementierung wurde in einer Linux-Arbeitsumgebung vorbereitet; die
installierte macOS-App wurde damit weder ersetzt noch gestartet. Ergebnisse
früherer installierter Kandidaten gelten nicht als neue Laufzeitabnahme.

| Paket | Quellcode / Vorbereitung | Weiter benötigter Nachweis |
|---|---|---|
| A: Texteingabe und Bedienung | Manuell geöffnetes Panel, früh erfasstes Ziel, sichtbare Buildidentität; physisches Hotkey-Diktat mit sichtbarer TextEdit-Einfügung und enger Apple-Terminal-Eingabe auf `68ef919`; klare Rückmeldungen bei unbestätigter oder unterbrochener Übergabe | Geschlossenes Panel beim Hotkey-Diktat, Terminal-Auswahl-/Tabfälle und Unterbrechung im tatsächlichen Zielprogramm |
| B: CI und Archive | Strikter Formatter, Compilerwarnungen als Fehler, Plattformprotokoll, sechs Shellprüfungen; sieben kontrollierte Bundle-Fälle; Archiv nach Entpacken erneut überprüft, mit Revision und Prüfsummen | Ergebnisse und Artefakt des exakten Workflow-Laufs; echte Installation und macOS-14-Laufzeitabnahme bleiben offen |
| C: Einrichtung und Beenden | Vorgangsgebundene Rückmeldungen für Start, Retry und Einrichtung; Abbruch und Quit gegen verschachtelte Aktionen geschützt; verlustarme Keychain-Migration mit explizitem Hinweis bei unvollständiger Altbereinigung | Frische Einrichtung, verzögerte Berechtigungen, tatsächliche Keychain-Zugriffsrichtlinie und Beenden während Aufnahme/Upload auf einem Mac |
| D: Menschlicher Pilot | Zwölf begrenzte Fälle und Messgrößen vorbereitet; ein menschlich gesprochener TextEdit-Durchlauf mit physischem Kürzel bestanden | Weitere tatsächlich gesprochene Diktate und Auswertung der Pilot-Messgrößen |
| E: Integrationsfälle | Begrenzte erste Fallliste; Offline-Tests für verspätete Rückmeldungen, Abbruch und Quit; ein realer negativer TextEdit→Finder-Wechsel nach Aufnahmestopp mit Kopiertext bestanden | Weitere Fokusphasen, Beenden/Abbruch, Gerätefehler und Safari-Fallback untersuchen |
| F: Dokumentation | Einstieg verkürzt, Entwicklerverfahren ausgelagert, aktuelle Übergabe und Aufbewahrungsangaben präzisiert | Nach D/E über begrenzten Betatest entscheiden |

Linux nimmt die macOS-Pakete A–F und den nächsten Mac-Schritt nicht als erledigt.
`PROJECT.md` nennt Windows/Linux weiter als nicht festgelegt.

## Linux-Fortsetzung (für nachfolgende Agents)

Dies ist der Einstieg, wenn der Chatverlauf fehlt. Zuerst diese Datei, dann
[linux-build-plan.md](linux-build-plan.md), [AGENTS.md](../AGENTS.md) und
[linux/README.md](../linux/README.md). Checkout-Stand prüfen, bevor der Bericht
unten als gegeben gilt.

### Git

| | |
|---|---|
| Phase 0 | [PR #16](https://github.com/HerrStolzier/OpenDictate/pull/16) als `0ae6a49` gemergt; Swift-CI grün |
| Phase-1-Kern | [PR #17](https://github.com/HerrStolzier/OpenDictate/pull/17), Kerncommit `e17d37c`, Merge `83c944f`; Swift-CI grün |
| Spike-Commit | `f7572a6` |
| `main` | `83c944f` mit Phase-1-Kern |
| Nächster Schritt | Live-Abnahme separat und nur mit neu begrenzter Freigabe; danach Tray/Panel und physischer Hotkey |

Lokales Release-Binary (nicht im Git): `linux/target/release/opendictate`.
`linux/target/` ist gitignored. Rustc 1.98.1 liegt unter `~/.cargo` (rustup,
nicht als Pacman-Paket).

### Entschieden (nicht neu aufmachen)

1. Erster Ship ist Clipboard-only; Recovery/State/authentifizierter Retry gehören
   in Phase 1, nicht in eine spätere Politur.
2. Zielsession: omarchy / Hyprland / Wayland / XDPH. Kein X11-Nachweis.
3. UI-Minimum: Tray plus Panel auf Zuruf, erst nach Toggle/Mic/Keyring/Clipboard.
   Panel öffnet nie von selbst während der Aufnahme.
4. Core-Politik in Rust mit Tests nachziehen. Swift-`OpenDictateCore` auf Linux
   ist ein Plus, kein Spike-Tor.
5. Kein zweites Distro in v1.

Tauri/Electron/Flutter sind nachrangig. `tauri-plugin-global-shortcut` auf
Hyprland nicht als „grün“ werten. Hyprland-Bind `exec, opendictate toggle` ist
der v1-Hotkey; XDPH GlobalShortcuts ist Phase-2-UX.

### Aktueller Linux-Code

| Datei | Rolle |
|---|---|
| `linux/src/main.rs` | CLI: Toggle, Status, Cancel, Retry, Settings, Secrets und Worker-Ablauf |
| `linux/src/record.rs` | cpal-Aufnahme, 1/90-s-Grenzen, −45-dB-Analyse, Padding und WAV-Trim |
| `linux/src/ipc.rs`, `state.rs` | Exklusiver Unix-Socket, vier Zustände und Abbruchmarker |
| `linux/src/keyring.rs` | `secret-tool`; Attribute `service=opendictate`, `key=api-key` / `recording-auth` / `spike-probe` |
| `linux/src/clipboard.rs` | `wl-copy --type text/plain`, fail ohne `WAYLAND_DISPLAY` |
| `linux/src/transcribe.rs` | HTTPS-Multipart-Upload und begrenzte Fehlerdekodierung; Offline-Stubtests |
| `linux/src/recovery.rs` | HMAC-SHA256, exakte authentifizierte Bytes, fünf Dateien/24 Stunden |
| `linux/src/settings.rs` | Owner-only Modell-/Sprachkonfiguration, kein Secret |
| `linux/src/window.rs` | `hyprctl activewindow -j`: nur `address` und `class`, **kein Title** (Title kann Nutzertext sein) |
| `linux/src/paths.rs` | XDG runtime/state/config, echte Verzeichnisse `0700` |
| `linux/hyprland.conf.example` | Beispiel-Bind; **nicht** in `~/.config/hypr/` installiert |

Pending/Recovery: `$XDG_STATE_HOME/opendictate/` (sonst `~/.local/state/...`),
Dateien `0600`. Operations-Log: `$XDG_STATE_HOME/opendictate/operations.log` —
nur Betriebsereignisse. Nach erfolgreichem Upload ist das Transkript die
Clipboard-Delivery. `secrets set-api-key` nur stdin, bricht ab wenn stdin ein TTY ist.
`OPENAI_API_KEY` / `OPENDICTATE_API_KEY` werden beim Worker-Spawn entfernt.

Session 20. September 2026: Probe ok, `api-key` und `recording-auth` fehlten,
Clipboard-Rundlauf ok, ~1,3 s WAV 116 648 Bytes, Fokus blieb `foot`. Test-WAV
gelöscht. `secret-tool --help` endet mit Status 2 — Verfügbarkeit über `PATH`.

### Absichtlich nicht tun

- `PROJECT.md` Linux zum Produkt machen, ohne ausdrückliche Freigabe.
- macOS-Pakete A–F oder Terminal-Abnahme als erledigt markieren.
- Cargo/Node/WebKit in `.github/workflows/checks.yml` (macOS-15 Swift-Job).
- API-Key als Argument, Env, Fixture, Log oder eingecheckte Datei.
- Datei- oder Env-Fallback, wenn Secret Service fehlt.
- OpenAI-Upload oder neues Mikrofon-/Provider-Budget ohne Eintrag in
  [APPROVALS.md](../APPROVALS.md). Die Budgets vom 17. September (6+8) sind
  **verbraucht**.
- Automatisches Insert in Phase 1. Retry später nie `allowPaste: true`.
- `Sources/OpenDictate*` für Linux verbiegen; Core bleibt Orakel, kein Link.
- Hyprland-Config des Users ohne Auftrag ändern (siehe omarchy-Skill, falls doch).
- Title-Felder aus `hyprctl` loggen. Sprachqualität aus einer Spike-WAV ableiten.

### Phase-1-Kern und nächste Abnahme

Die Pflichtzahlen wurden aus dem Swift-Orakel übernommen:

| Politik | Quelle |
|---|---|
| State `idle/recording/processing/delivering`, kein zweiter Start wenn busy | `Sources/OpenDictateCore/DictationState.swift` |
| Retention 5 Dateien / 24 h | `Sources/OpenDictateCore/RecordingRetention.swift` |
| 1 s Skip / 90 s Cap, Silence −45 dB, Padding 0,25 s | `Sources/OpenDictate/Support/Config.swift` |
| Nur nach erfolgreichem Copy löschen | `TranscriptDelivery.canRemoveRecoveryAudio` |
| Retry kopiert nur | `DictationFlow.deliver(..., allowPaste: false)` |
| Authentifizierte Bytes, Ablauf beim Zugriff | `Sources/OpenDictate/System/FailedRecordingStore.swift` |
| Kein realtime-only-Modell | `TranscriptionModel.isUsableForUpload` |
| HTTP-Form von `POST /v1/audio/transcriptions` | `Sources/OpenDictate/Transcription/OpenAITranscriber.swift` |

Implementiert und offline geprüft sind State, Cancel-Marker, Audio-Schwellen und
Trim, Upload-Request/Antwort, Clipboard-Löschregel, HMAC-Recovery, Retry,
Retention und CLI-Settings. Der HTTP-Test bindet ausschließlich Loopback. Die
Recovery-Tests prüfen manipulierte Bytes, falschen Key, umbenannte Dateien,
Kopierfehler sowie Count-/Altersgrenze.

Als Nächstes, getrennt vom Code-Commit:

1. Branch pushen, CI prüfen und nach erfolgreichem Review mergen; kein Live-
   Deployment ist an den Repository-Workflow gekoppelt.
2. Für einen echten Linux-Durchstich ein neues enges Mikrofon-/Upload-Budget
   festlegen. Erst dann Keyring, Aufnahme, Provider und Clipboard real prüfen.
3. Reale Abbruch-/Fehler-/leere Antwort-/Clipboard-Fehlerfälle bestätigen. Ein
   Abbruch während des blockierenden Requests wird derzeit erst nach Rückkehr
   oder Timeout ausgewertet, bewahrt aber die Aufnahme.
4. Danach physischen Hyprland-Hotkey und UI-Minimum (Tray, Panel auf Zuruf)
   implementieren und sichtbar prüfen. Keine Nutzer-Hyprland-Konfiguration ohne
   eigenen Auftrag ändern.
5. `PROJECT.md` weiter nicht anfassen, bis Phase 1 wirklich abgenommen ist und
   jemand den Produktumfang bewusst erweitert.

Prüfen nach Linux-Source-Änderungen (nicht Swift-CI):

```bash
cargo fmt --manifest-path linux/Cargo.toml -- --check
cargo test --manifest-path linux/Cargo.toml
cargo clippy --manifest-path linux/Cargo.toml --all-targets -- -D warnings
cargo build --release --manifest-path linux/Cargo.toml
git diff --check
```

User-Status deutsch, technische Kommentare englisch. Kein Key/Transkript/Audio
in Logs.

### Optionale Hyprland-Bindung

Die Bindung bleibt Nutzersache und wurde nicht installiert:

`bind = SUPER SHIFT, D, exec, <absoluter-pfad>/linux/target/release/opendictate toggle`

## Nächster ausführbarer Mac-Schritt

Die vorbereitete [Pilot- und Integrationsliste](audio-quality-fixtures.md#prepared-first-human-pilot)
verwendet vorhandene Prüfmittel. Für den installierten älteren Kandidaten
`68ef919` sind TextEdit, eine leere Terminal-Shellzeile und der negative
TextEdit→Finder-Wechsel sichtbar geprüft. Der neue ⌘V-Build `bd3630f` hat nun
eigene echte TextEdit-, Safari-, Brave-, Obsidian- und Terminal-Nachweise
im [Plan-1-Bericht](release-plans/evidence/2026-09-23-plan1-status.md). Der
inzwischen installierte Build 7 aus Quellstand `c92cbc9` enthält die UX-Änderung,
den stabilen Schlüsselbundhelfer und die präzisierte Bereit-Zeile. Nach zwei
einmaligen Freigaben startete der
vorherige Quellstand `cbdfb34` auch nach einem App-Build-Wechsel ohne weitere
Abfrage eine Aufnahme. Ein Provider-Lauf lieferte Text im App-Panel; der Text erschien im vorbereiteten
TextEdit-Dokument nicht sichtbar, während macOS Brave als vorderste App
meldete. Build 7 startete ohne Dialog, beide installierten Bundles sind
signaturgeprüft, und der Bereit-Zustand wurde sichtbar geprüft. Der erste
geplante Build-7-Diktatlauf wurde wegen unklaren Zieles ausgelassen: Die
Computersteuerung fokussierte ein TextEdit-Feld, während macOS OpenDictate
als vorderste App meldete. In diesem Versuch gab es keinen Upload.

Am 24. September wurde TextEdit anschließend als wirkliche Vordergrund-App
bestätigt. Ein kurzer Build-7-Lauf über den sichtbaren Aufnahme-Knopf erreichte
ohne Schlüsselbunddialog Mikrofon und Provider, lieferte bei 44 Prozent
Ausgabe jedoch keinen Text; die Aufnahme blieb erhalten. Ein zweiter Lauf bei
80 Prozent fügte den erkannten Satz automatisch sichtbar in TextEdit ein.
Ausgabe, eingefügter Testsatz und eigene Testartefakte wurden danach
wiederhergestellt beziehungsweise entfernt. [Einzelheiten](release-plans/evidence/2026-09-24-keychain-and-plan1.md#build-7-echter-textedit-einfügeweg).
Der physische Option+Shift+Space-Lauf auf Build 7 bestand anschließend ebenfalls;
auch der echte manuelle Kopierweg und vier synthetische native Anfangs-/Mittelfälle
bestanden, jeweils nur für ihren dokumentierten Umfang. Die fünf echten Diktate
des älteren `bd3630f` bleiben getrennte Nachweise.

Die verbleibenden Browser-/Editor-Matrixfälle, Fokusfälle, Störfälle und die
vollständige UX-Prüfung am installierten Build bleiben offen. Die frische
Ersteinrichtung ist ausdrücklich als offene, akzeptierte Grenze belassen; dafür
wird kein zusätzliches Benutzerkonto angelegt. Bastis erste Designrückmeldung
und die gewählte Richtung stehen im
[Plan-1-Bericht](release-plans/evidence/2026-09-23-plan1-status.md). Danach
frühes menschliches Nutzerfeedback sammeln; die komplette
[Kompatibilitätsmatrix](compatibility-matrix.md) bleibt das breitere Produktziel.

Die aktuelle Arbeit läuft am Mac mini mit physischem Eingabegerät. Für macOS 14
ist nur der native CI-Nachweis der Offline-Tests und des Bundle-Builds vorgesehen;
eine macOS-14-VM oder ein zweiter Mac stehen nicht zur Verfügung. Die
interaktive Diktatabnahme erfolgt auf dem vorhandenen Mac und wird nicht als
macOS-14-Nachweis bezeichnet. Bastis Plan-1-Freigabe erlaubt weitere
kurze Live-Aufnahmen und Provider-Uploads ohne festes Stückkontingent;
automatische Wiederholungen bleiben ausgeschlossen. Frühere Testzahlen sind
Verbrauchsnachweise und kein künftiges Limit.

## Bekannte offene Grenzen

- Der neue ⌘V-Pfad fügte eine harmlose einzelne Zeile in einer leeren
  Apple-Terminal-Shell sichtbar ein, ohne Return oder Befehlsausführung.
  Er hat keinen Zeilenumbruchfilter. Terminal-Tabs, Markierung, Secure Input
  und das Verhalten interaktiver Programme brauchen noch sichtbare Prüfung.
  iTerm2 und Terminals innerhalb von Editoren sind nicht abgedeckt.
- Ein echter negativer Appwechsel nach dem Stoppen ist für TextEdit→Finder auf
  dem älteren Kandidaten bestanden. Der neue Pfad reaktiviert die ursprüngliche
  App; dieses frühere Ergebnis ist keine Abnahme des neuen Verhaltens.
- Der erste Versuch mit dem vorherigen Build landete bei Brave als
  Vordergrund-App nicht in TextEdit. Die Wiederholung auf Build 7 mit
  bestätigtem TextEdit-Vordergrund fügte den Satz sichtbar ein. Das belegt den
  Knopf-Ablauf für dieses Feld. Ein separater physischer Option+Shift+Space-Lauf
  mit Build 7 bestand; beide Nachweise gelten für ihren jeweiligen Ablauf und
  schließen die offenen Browser-/Editorfälle nicht.
- Der erste Safari-textarea-Fallback im jüngsten historischen Zieltest bleibt
  ungeklärt, obwohl der Wiederholungsversuch bestand.
- Eine manuelle Cursor-/Auswahlbewegung kann den Einfügeort ändern. Der neue
  Pfad bindet kein bestimmtes Feld.
- Reale Gerätewechsel, Abziehen des Mikrofons, Berechtigungs-/Keychainfehler und
  tatsächlich unterbrochenes Beenden während Verarbeitung brauchen passende
  praktische Prüfungen. Zwei Beenden-Versuche wurden vom Provider überholt.
- Menschliche Sprachqualität, Zahlen-/Namensfehler, Korrekturzeit und tatsächlicher
  Zeitgewinn sind offen. Die neue Fallliste enthält keine gemessenen Ergebnisse.
- Gehörte VoiceOver-Ausgabe und die vollständige interaktive Abnahme am
  vorhandenen Mac bleiben offen; der einzelne Build-7-TextEdit-Lauf schließt sie
  nicht. Der bestandene macOS-14-CI-Lauf prüft native Offline-Tests und
  Bundle-Build, aber keine Berechtigungen, Aufnahme oder Einfügung unter macOS 14.
- Der vorhandene API-Schlüssel liegt noch im alten Account `OPENAI_API_KEY`.
  Dessen Dateischlüsselbund-Zugriffsliste enthält einzelne Build-Hashes;
  deshalb ist die frühere Freigabe nicht updatefest. Auch ein von einer lokal
  selbst signierten Test-App neu angelegter Eintrag forderte nach einem
  Build-Wechsel erneut Zugriff. Ein bloßes Speichern über den App-Dialog ist
  somit keine belegte dauerhafte Lösung. Der neue, fest installierte signierte
  Schlüsselbundhelfer bestand einen isolierten Aufruf aus einem signierten
  App-Host; der echte API-Schlüssel wurde dabei nicht gelesen. Der neue Build
  wurde in beide lokalen App-Kopien installiert, die bisherigen Bundles wurden
  gesichert. Der installierte Helfer ist signiert und stimmt mit dem Bundle
  überein. Beide getrennten macOS-Freigaben sind inzwischen bestätigt; ein
  Start nach einem weiteren App-Build mit verändertem Code-Hash erreichte ohne
  Dialog die Aufnahme. Der [Fortsetzungsbericht](release-plans/evidence/2026-09-24-keychain-and-plan1.md)
  dokumentiert diesen bestandenen Ausschnitt. Den alten API-Key-Eintrag nur
  durch die bestehende verlustarme App-Migration entfernen, nicht manuell.

Bekannte Fehler mit falschem Ziel, beschädigtem vorhandenem Text oder Verlust der
einzigen Aufnahme/des einzigen Transkripts verhindern eine Ausweitung des betroffenen
Pfads, bis eine Korrektur oder sichere Einschränkung belegt ist. Kleine Stichproben
rechtfertigen keine allgemeine Erfolgsquote oder pauschale Programm-Unterstützung.

## Historische Evidenz

| Bericht | Aussage für seinen damaligen Kandidaten |
|---|---|
| [Linux-Spike 20. September](linux-spike-2026-09-20.md) | Phase-0-CLI auf omarchy/Hyprland: Keyring-Probe, Clipboard, WAV-Capture, Fokus blieb; kein Upload, kein Produktumfang |
| [Zielabnahme 17. September](target-acceptance-2026-09-17.md) | Echte Auswahlersetzung in TextEdit, Safari und Obsidian mit erzeugter Referenzsprache; Safari-Fallback und tatsächlicher negativer Appwechsel offen |
| [Roadmap 17. September](roadmap-acceptance-2026-09-17.md) | Brave-Langtextkorrektur, konkrete Mikrofon-/Providerfälle und 90-Sekunden-Stopp |
| [Roadmap 16. September](roadmap-acceptance-2026-09-16.md) | Synthetische Feld-/Fokus-/Unicodeprüfungen, Recovery-Dateisystemfehler und Hotkey-Registrierung |
| [Brave 15. September](brave-insertion-2026-09-15.md) | Synthetische Brave-Einfügung und vom Nutzer bestätigter damaliger Proton-Pfad |
| [Native App 15. September](live-acceptance-2026-09-15.md), [Einstellungen](settings-acceptance-2026-09-15.md) | Konkretes menschliches Diktat und native Bedienungs-/Fensterprüfungen |
| [13. September](live-acceptance-2026-09-13.md), [7. September](live-acceptance-2026-09-07.md) | Ältere Kandidaten; der damalige Cmd+V-Pfad ist ein Hinweis, aber kein Test des neuen Builds |

Einzelheiten zur früheren lokalen Signatur-/Keychain-Einrichtung und der Abnahme
vom 14. September bleiben im
[unveränderten damaligen Übergabestand](https://github.com/HerrStolzier/OpenDictate/blob/8621edf7f099d7a757ad1a25885eda5cb427a2b2/docs/remaining-acceptance.md#historische-live-abnahmen)
zugänglich. Dortige installierte Pfade, Laufzustände und Freigaben sind historische
Beobachtungen und keine heutige Zustandsabfrage oder neue Zustimmung.

## Zurückgestellte Erweiterungen

Streaming und Hold-to-talk bleiben zurückgestellt. Streaming braucht unter anderem
begrenzte Ereignispuffer, ein validiertes Endereignis, Abbruchbehandlung und
Messungen des Nutzens; unbestätigte Teiltranskripte werden nicht fortlaufend ins
Ziel eingefügt. Hold-to-talk braucht zuverlässige Release-Ereignisse und Erholung
nach verpasster Freigabe; der native Aufnahmestopp bleibt die Obergrenze.

Historische temporäre Audiooriginale werden nicht blind gelöscht, weil sie die
letzte überlebende Aufnahme sein können. Eine künftige Crash-Recovery muss
Eigentum und Wiederherstellung klären. Für öffentliche Verteilung sind außerdem
reproduzierbare Erstinstallation, geeignete Signierung/Notarisierung und Prüfung
der zugesagten Plattformen erforderlich. Die CI-Entwicklungsarchive sind keine
öffentliche signierte und notarisierte Produktveröffentlichung.
