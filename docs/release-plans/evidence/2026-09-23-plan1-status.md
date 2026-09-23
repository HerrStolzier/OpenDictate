# Plan 1 · Zwischenstand vom 23. September 2026

Dieser Stand ist noch **keine Produktabnahme**. Er trennt lokale Prüfungen von
den ausstehenden sichtbaren Diktat-, UX- und Plattformnachweisen.

**Neuer installierter Kandidat:** Build 3 aus Quellrevision
`7621a7f18345a25c178c286e06e56a9558fc0d1a` liegt unter `/Applications`
und `~/Applications`; beide Programmdateien haben SHA-256
`a6204f3c07c68ca22587dd658aeda7c636e10cf42255971796a48bf6d7da765e`.
Die Signatur, Hardened Runtime, Mikrofon-Berechtigung im Bundle und sieben
kontrollierte Bundle-Prüffälle bestanden. Beide bisherigen Build-2-Kopien sind
unter `.build/plan1-rollbacks-20260923-build2/` gesichert. Der neue Build läuft
aus `~/Applications` und meldete beim Start die gesperrte alte Audiodatei als
nicht löschbar, ohne eine falsche Bereinigungserfolgsmeldung; Audio und
Authentifizierungsdatei sind weiter vorhanden. Beim ersten neuen Diktierlauf
forderte macOS Zugriff auf den bestehenden Schlüsselbund-Eintrag an.
Basti bestätigte den Zugriff direkt am Mac. Anschließend wurde die laufende
installierte App gezielt in die Zugriffsliste genau dieses API-Schlüssel-Eintrags
aufgenommen; „alle Programme“ blieb aus. Nach dem Speichern war „Änderungen
sichern“ deaktiviert. Ein neuer Start über das App-Panel erreichte ohne neue
Schlüsselbundabfrage „Aufnahme läuft“ mit Eingangssignal. Der Quellpfad liest
den Schlüssel vor diesem Zustand in `hasAPIKey` und `TranscriptionOptions.current`.
Dieser Lauf wurde nach 14,9 Sekunden ohne Provider-Upload abgebrochen; die
eigene Recovery-Aufnahme wurde einzeln über die App gelöscht und ihr Dateipaar
war danach nicht mehr vorhanden. Eine weitere Berechtigungsabfrage nach einer
App-Änderung bleibt möglich.

Der installierte Build wurde anschließend regulär beendet und erneut aus
`~/Applications` gestartet. Das globale Kürzel war wieder registriert; ein
erneuter Lauf erreichte den Provider und dessen Antwort ohne neuen sichtbaren
Schlüsselbunddialog. Dieser Neustart prüft die gespeicherte Freigabe für genau
dieses Bundle, nicht für zukünftige Signaturen. Die 46,9 Sekunden lange
Testaufnahme enthielt keinen erkannten Text und blieb korrekt als
authentifizierte Wiederholungsdatei erhalten. Sie wurde einzeln im
Aufnahmen-Fenster gelöscht; Audio und `.auth` sind danach nicht mehr vorhanden.
Die zwei älteren Aufnahmen blieben bestehen. Für diesen Neustarttest fiel ein
Provider-Request an.

Ein anschließender echter Build-3-Durchlauf startete mit dem physischen
Kürzel in einem leeren eigenen TextEdit-Dokument. Die lokale Systemstimme
Anna spielte einen harmlosen Testsatz über den Mac-Lautsprecher in das
JBL-Mikrofon. Der erste Versuch lieferte nach einem Provider-Request keinen
Text: Die Systemausgabe war stummgeschaltet (Aufnahme: Peak −35 dB,
Durchschnitt −45 dB). Nach vorübergehendem Aufheben der Stummschaltung und
Anheben der Ausgabe von 56 auf 80 ergab der zweite Versuch Peak −14 dB und
Durchschnitt −32 dB. Ein Provider-Request lieferte den vollständigen Text;
das installierte Build fügte ihn ohne Klick oder manuelles Paste sichtbar in
das zuvor leere TextEdit-Dokument ein. Der per Accessibility gelesene Feldtext
stimmte mit dem App-Ergebnistext überein; die Spracherkennung schrieb
„Build“ als „Bild“ und „sieben“ als „7“. Das belegt den Übertragungsweg,
keine allgemeine Sprachqualität. Die Lautstärke 56 und Stummschaltung wurden
wiederhergestellt. Die eigene Aufnahme des leeren Versuchs wurde einzeln
gelöscht; lokale Audiodatei des erfolgreichen Laufs, Testdokument,
Screenshots und der letzte Text im App-Speicher wurden bereinigt. Die zwei
älteren vorgefundenen
Recovery-Einträge blieben unangetastet.

## Vorheriger Kandidat

| Merkmal | Aktuell geprüft |
|---|---|
| Quell-HEAD | `8be59821d9e5bc3874299b910e463d9acc42e7d5` · nur Release-Pläne nach dem App-Quellstand |
| Installiertes Bundle | `~/Applications/OpenDictate.app`, Build `2`, Quellrevision `bd3630f605feff1ef64598ccab85511f944662c5` |
| Programmdatei | SHA-256 `492d4b0609400a3926bd18881544d48c3ef89be90e059f9122869416821a5f5f` |
| Signatur | `codesign --verify --deep --strict` bestanden; `local.opendictate.app`, `OpenDictate Self-Signed`, Hardened Runtime |
| Test-Mac | Mac mini, Apple M4, macOS 27.0 (26A428) |
| Standardmikrofon | JBL Quantum Stream Talk (USB), nicht stumm; Eingangspegel von 0,235 auf gerätebestätigt 0,772 gestellt |

Das installierte Ergebnis-Panel wurde mit Cua Driver direkt aufgenommen:
[Ist-Screenshot](../mockups/01-ist-ergebnis.png). Die drei visuellen
[Vergleiche](../mockups/01-ux-richtung.html) sind Entwürfe und keine
implementierten App-Zustände. Bastis Feedback zur Richtung ist angefragt.
Seine Zwischenfrage bestätigte die Grenze: Die wiederhergestellte allgemeine
Zwischenablage-/⌘V-Einfügung wird durch UX-Arbeit nicht erneut geändert.

## Offline-Prüfungen

- `swift format lint --strict --configuration .swift-format --recursive Sources Tests Package.swift`: bestanden.
- `swift test -Xswiftc -warnings-as-errors`: auf diesem Swift-6.4-Host wegen
  fehlender `TestingMacros`-Plugin-Erkennung gescheitert. Der dokumentierte
  Aufruf mit `-plugin-path` bestand: 69 Tests in 12 Suites; Opt-in-Live- und
  Benchmark-Tests blieben ausgeschaltet.
- `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts/tests -p 'test_*.py' -v`: 8 Tests bestanden.
- `bash -n` für die sechs in `CHECKS.md` aufgeführten Skripte: bestanden.
- `git diff --check`: bestanden.

## Sichtbare Live-Prüfungen

Die fünf normalen Diktate mit physischem Kürzel, JBL-Mikrofon, OpenAI und
installiertem Build haben Text im jeweils vorher geprüften Feld erzeugt:
TextEdit, Safari-`textarea`, Brave-`contenteditable`, eine harmlose
**nicht abgeschickte** Terminal-Zeile und Obsidian im isolierten temporären
Vault. Soll-/Ist-Bilder und Messwerte stehen im
[Live-Ledger](2026-09-23-live-ledger.json). Safari verschmolz in der
Transkription einmal „Apfel sieben“ zu „Apfelsieben“; der sichtbare Zieltext
stimmte mit der Zwischenablage überein. Das ist kein Nachweis allgemeiner
Sprachqualität oder sämtlicher Felder einer App.

Ein sechster Lauf wurde während der Aufnahme im Panel abgebrochen. Die App
erzeugte eine 78,2 Sekunden lange, authentifizierte Recovery-Datei ohne
Provider-Upload; nach dem App-Neustart war „Wiederholen“ dafür aktiv. Die
eigene Testaufnahme wurde anschließend über den einzelnen App-Eintrag
gelöscht. Die ältere fremde Aufnahme blieb bytegleich. Zwei weitere Läufe
forderten das Beenden an, als der Status „Transkribieren …“ zeigte. Der
Provider antwortete jeweils während des Bestätigungsdialogs und der Text
gelangte noch in das eigene TextEdit-Dokument. Diese Versuche **bestehen den
Unterbrechungsfall nicht**. Beim zweiten Lauf ging ein Return an das eigene
TextEdit-Dokument statt an den Dialog; dessen führender Zeilenumbruch gehörte
zum Testartefakt und wurde mit ihm entfernt. Die App wurde erst danach
beendet. Insgesamt wurden acht Aufnahmen und sieben Uploads verbraucht.

Bei einer vorgefundenen Aufnahme vom 15. September zeigte `ls -leO@` eine
macOS-ACL mit `deny delete`. Die App protokollierte dennoch wiederholt
„Pruned 1 expired failed recording(s)“, während Audio- und
Authentifizierungsdatei bytegleich liegen blieben. Der Quellcode zählt
ausgewählte abgelaufene Einträge, ohne das Ergebnis von `unlink` für die
Erfolgsmeldung zu prüfen. Das ist eine falsche Bereinigungsmeldung. Die
vorgefundene Datei wurde nicht verändert oder gelöscht; eine Quellkorrektur
und Prüfung am nächsten Kandidaten bleiben offen.

## Weiter offen

Die [lokale Einfügematrix](2026-09-23-offline-matrix.md) zeigt zwei exakte
native Fälle und sichtbare, synthetische Fokuswechsel innerhalb einer App
und zwischen zwei Apps. Der Safari-`input`-Vergleich meldete eine
Unicode-Normalisierung (`e` + Akzent zu `é`); die strikte Zeichenfolgen-
Abnahme ist dafür nicht bestanden. Der allgemeine ⌘V-Pfad blieb unverändert.

Die übrige sichtbare Feldermatrix, ein echter Providerfehler, tatsächlich
unterbrochene Verarbeitung, Feedbackentscheidung und anschließende
UI-Änderungen, gehörtes VoiceOver, macOS-14-Laufzeit und lokale Statuszeiten
sind noch nicht abgeschlossen. Der erste konkrete Live-Testblock war zu diesem
Zeitpunkt ausgeschöpft. Für macOS 14 ist auf dem aktuellen
Mac kein Laufzeitnachweis möglich; der konfigurierte MacBook-SSH-Host antwortete
nicht innerhalb von fünf Sekunden.

**Fortsetzung:** Basti hat die Fortsetzung von Plan 1 ohne festes
Aufnahmekontingent ausdrücklich freigegeben; die ältere Verbrauchsangabe oben
beschreibt nur den ersten Block. Die Offline-Tests für gesperrte Audiodateien,
Recorder- und Providerfehler bestehen auf dem neuen Quellstand. Beim Pruning
bleibt die Authentifizierungsdatei jetzt erhalten, wenn macOS die Audiodatei
nicht löschen kann; nur tatsächlich entfernte Dateien werden als entfernt
gezählt. Das ist noch kein installierter Live-Nachweis dieses neuen Builds.
Die [Matrix-Fortsetzung](2026-09-23-offline-matrix.md#fortsetzung-mit-der-lokalen-safari-seite)
zeigt Safari-`textarea` mit derselben Normalisierung sowie zwei bisher
erfolglose Browserfelder. Diese Fälle werden nicht als bestanden gezählt.
Eine anschließende [direkte Safari-Kontrolle](2026-09-23-offline-matrix.md#direkte-safari-kontrolle-nach-dem-fehlversuch)
fügte per ⌘V in beide gezielt fokussierten Felder vollständig ein. Das grenzt
die früheren Fixture-Fehler auf deren Ablauf oder Fokuszustand ein, ohne die
Produktions-Fixture nachträglich als bestanden zu bewerten.
Ein gesonderter Appwechseltest zeigte, dass ein Accessibility-Klick in das
`iframe`-Feld den sichtbaren Fokus nicht immer bewegt. Nach gezieltem
Pixelklick blieb der Feldfokus bei einem Appwechsel erhalten und ⌘V landete
im `iframe`; [Fallnotiz und Bild](2026-09-23-offline-matrix.md#direkte-safari-kontrolle-nach-dem-fehlversuch).

Eine diagnostische Leerlaufmessung des seit 08:45 Uhr laufenden, installierten
Prozesses ist abgeschlossen: zwei unmittelbar aufeinanderfolgende
[300-Sekunden-Teile](2026-09-23-idle-32011-part1.json) und
[Teil 2](2026-09-23-idle-32011-part2.json), zusammen 600,09 Sekunden. Die
gemittelte Prozess-CPU betrug 0,0133 Prozent. Das höchste abgetastete RSS lag
bei 110.368 KiB (107,78 MiB) und überschritt das Ziel von 100 MiB. `vmmap`
meldete danach 27,5 MiB Physical Footprint; diese andere Metrik ersetzt den
RSS-Abnahmewert nicht. Die beiden JSON-Dateien enthalten die Sekundensamples.

Nach einem frischen App-Start ohne weitere App-Bedienung ergaben
[Teil 1](2026-09-23-idle-7259-part1.json) und
[Teil 2](2026-09-23-idle-7259-part2.json) über denselben Prozess zusammen
600,094 Sekunden, 0,0167 Prozent mittlere Prozess-CPU und höchstens 100.432
KiB (98,078 MiB) abgetastetes RSS. Damit besteht der installierte Build das
Leerlaufziel auf diesem Mac im frischen Lauf. Die frühere Überschreitung beim
bereits stundenlang laufenden Prozess bleibt als diagnostische Beobachtung
erhalten; sie ist durch den frischen Lauf nicht erklärt. Der Sampler erfasst
keine Spitzen zwischen Sekundenabfragen und keine Energieaufnahme.

Für den aktuell installierten **Build 3** wurde die App anschließend erneut
frisch aus `~/Applications` gestartet und ohne App-Bedienung gemessen.
[Teil 1](2026-09-23-idle-build3-12111-part1.json) und
[Teil 2](2026-09-23-idle-build3-12111-part2.json) umfassen denselben Prozess
über zusammen 600,087 Sekunden mit nur 0,071 Sekunden Abstand. Die mittlere
Prozess-CPU betrug 0,025 Prozent. Das höchste abgetastete RSS lag bei 102.816
KiB (100,406 MiB) und damit **knapp über** dem 100-MiB-Ziel. Es begann bei
102.512 KiB und blieb in beiden Teilen ungefähr auf diesem Niveau; der Befund
ist kein einzelner später Ausreißer. Build 3 besteht damit das CPU-Kriterium,
aber vorerst nicht das festgelegte RSS-Kriterium. Die frühere frische Messung
stammt von einem anderen, zuvor installierten Kandidaten und ersetzt diesen
Build-3-Nachweis nicht. Die Ursache der etwa 2,3 MiB Differenz zwischen den
beiden frischen Messungen ist noch nicht geklärt.
