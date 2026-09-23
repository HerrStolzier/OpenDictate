# Aktueller Stand und verbleibende Abnahme

Stand: 23. September 2026. Dies ist die einzige aktuelle Übergabedatei.
Produktziel: [PROJECT.md](../PROJECT.md); Regeln: [AGENTS.md](../AGENTS.md);
Prüfverfahren: [CHECKS.md](../CHECKS.md); belegte frühere Testbudgets:
[APPROVALS.md](../APPROVALS.md). Linux-Plan:
[linux-build-plan.md](linux-build-plan.md).

Zwei parallele Arbeitspfade: **macOS-Produktabnahme** (unverändert offen) und
**Linux Phase 1** (Kern in `main`, noch nicht in `PROJECT.md`). Linux markiert
macOS nicht als erledigt.

## Neuer Quellcodekandidat: normaler Einfügebefehl

Auf Bastis ausdrücklichen Wunsch ist die automatische Übergabe wieder auf
Zwischenablage, Aktivierung der beim Diktatbeginn aktiven App und ⌘V umgestellt.
Das Feld muss kein setzbares `AXSelectedText` mehr anbieten. Vor dem Tastendruck
werden Accessibility-Freigabe, Vordergrund-App und unveränderter Kopiertext
geprüft. Fenster und Feld sind nicht mehr gebunden: Ein Fokuswechsel kann Text
in ein anderes Feld derselben ursprünglichen App lenken; ein Appwechsel kann
durch die Reaktivierung rückgängig gemacht werden. Der Terminal-Sonderpfad und
seine Zeilenumbruchfilter sind entfallen. Offline-Tests belegen die
Entscheidungslogik. Der neue Build `bd3630f` ist in beiden lokalen App-Pfaden
installiert und neu gestartet; ein
[begrenzter sichtbarer TextEdit-Test](installed-command-v-2026-09-23.md)
bestätigte normales ⌘V ohne Mikrofon, Provider oder automatischen
OpenDictate-Aufruf. Ein vollständiger Diktatdurchlauf dieses Builds ist offen.
Die historischen Live-Nachweise unten gelten nur für ihre damaligen Kandidaten.

Nächster Mac-Nachweis: den installierten neuen Build mit Mikrofon und Provider
in einem eigenen leeren TextEdit-Dokument und gezielt in zuvor problematischen
Browser-/Electron-Feldern prüfen. Fokuswechsel und Terminal nur mit klarer
Erwartung an die Reaktivierung und einem harmlosen Ziel prüfen; vorherige
Negativtests sind keine Sollvorgabe mehr. Live-Aufnahme und Provider brauchen
eine separate konkrete Freigabe.

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
weitere Feldtypen sowie Einrichtung/Abbruch bleiben offen. Alle bisherigen
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
TextEdit→Finder-Wechsel sichtbar geprüft. Diese Einfügenachweise gelten nicht
für den neuen ⌘V-Pfad. Der identifizierte Build `bd3630f` ist nun mit der
vorhandenen lokalen Signatur installiert. Als Nächstes seine automatische
Einfügung in einem echten Diktat und weitere repräsentative Felder prüfen;
Bedienungshilfen- und Keychain-Zugriff sind noch nicht live bestätigt. Danach frühes
menschliches Nutzerfeedback sammeln; die komplette
[Kompatibilitätsmatrix](compatibility-matrix.md) bleibt das breitere Produktziel.

Mac-spezifischer lokaler Desktop, frischer macOS-Benutzerzustand und physisches
Mac-Eingabegerät sind von der Linux-Umgebung aus nicht prüfbar. Auf omarchy sind
Mikrofon und Hyprland-Sitzung erreichbar, wurden für Phase 1 aber mangels neuer
Live-Freigabe nicht verwendet. Die früher dokumentierten sechs beziehungsweise acht
Mikrofon-/Provider-Versuche sind verbraucht; sie werden nicht als neues Budget
verwendet. Beim tatsächlichen Pilot Umfang und Audiozeit vorher festlegen.

## Bekannte offene Grenzen

- Der gemeldete Terminalfehler wurde auf dem installierten Kandidaten in einer
  leeren Shellzeile nicht reproduziert. Der neue ⌘V-Pfad ist dort ungetestet und
  hat keinen Zeilenumbruchfilter. Terminal-Tabs, Markierung, Secure Input
  und das Verhalten interaktiver Programme brauchen noch sichtbare Prüfung.
  iTerm2 und Terminals innerhalb von Editoren sind nicht abgedeckt.
- Ein echter negativer Appwechsel nach dem Stoppen ist für TextEdit→Finder auf
  dem älteren Kandidaten bestanden. Der neue Pfad reaktiviert die ursprüngliche
  App; dieses frühere Ergebnis ist keine Abnahme des neuen Verhaltens.
- Der erste Safari-textarea-Fallback im jüngsten historischen Zieltest bleibt
  ungeklärt, obwohl der Wiederholungsversuch bestand.
- Eine manuelle Cursor-/Auswahlbewegung kann den Einfügeort ändern. Der neue
  Pfad bindet kein bestimmtes Feld.
- Reale Gerätewechsel, Abziehen des Mikrofons, Berechtigungs-/Keychainfehler und
  Beenden während Aufnahme/Upload brauchen passende praktische Prüfungen.
- Menschliche Sprachqualität, Zahlen-/Namensfehler, Korrekturzeit und tatsächlicher
  Zeitgewinn sind offen. Die neue Fallliste enthält keine gemessenen Ergebnisse.
- Gehörte VoiceOver-Ausgabe und macOS 14 als Laufzeitplattform bleiben offen.
  macOS-15-CI, synthetische Fixtures und AX-Baumprüfungen ersetzen diese Nachweise nicht.
- Wer den alten API-Key-Helfer verwendet hat, speichert den Schlüssel über den
  App-Dialog neu. Der neue Account erhält die normale App-Zugriffsrichtlinie;
  die reale Migration und gegebenenfalls eine angezeigte Altbereinigung sind
  separat zu prüfen. Der Shell-Helfer schreibt keine Schlüssel mehr.

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
