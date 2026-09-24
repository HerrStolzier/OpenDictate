# Plan 1: Fortsetzung am 24. September 2026

Plan 1 ist wieder aufgenommen, noch nicht insgesamt abgenommen. Basti entschied
in der Fortsetzung ausdrücklich: **„Ersteinrichtung als offene Grenze belassen“**.
Es wird kein zusätzliches macOS-Konto angelegt und keine frische Einrichtung
behauptet. Diese benannte Grenze bleibt auch in einer späteren Übergabe erhalten.

## Identität und Prüfung

- Installierte App: `~/Applications/OpenDictate.app`, Version 0.1.0, Build 7,
  saubere Quellrevision `c92cbc98af06049708095411cb12a8f35f87bac6`.
- Signaturprüfung: `codesign --verify --deep --strict` bestanden.
- Plattform: Apple Silicon (`arm64`), macOS 27.0, Build `26A428`.
- Arbeitskopie: `694ac95e70aef159278a093c7141027cffc0355f`; `git diff c92cbc9 HEAD
  -- Sources` ist leer. Die Testbereinigung ändert keinen Produktionspfad.
- Aktueller Debug-Build mit `swift build --build-system native -Xswiftc
  -warnings-as-errors` bestanden. SwiftPM meldet lediglich die veraltete
  Kommandooption `--build-system native`.

## Zehn Minuten Leerlauf: bestanden

Der bereits laufende Build-7-Prozess (PID 82317, Start 09:19:40 Uhr) wurde ohne
Bedienung der installierten App zweimal unmittelbar nacheinander je 300 Sekunden
im Sekundenabstand gemessen. Die Gestaltungsvorschau lief als eigener Prozess;
ihre Bedienung gehört nicht zum gemessenen Prozess. Es war kein frischer Appstart.

| Messung | Wert | Ziel |
|---|---:|---:|
| Beobachtete Zeit | 600,081 Sekunden | 600 Sekunden |
| Mittlere Prozess-CPU, aus kumulierter CPU-Zeit | 0,02833 % | unter 1 % |
| Höchster beobachteter RSS | 81,40625 MiB | unter 100 MiB |

Beide Teile haben Status `completed` und jeweils 301 Samples. Zwischen ihnen
liegen 0,088 Sekunden. Rohdaten: [Teil 1](2026-09-24-idle-build7-part1.json),
[Teil 2](2026-09-24-idle-build7-part2.json). Peaks zwischen Samples und Energie
sind nicht erfasst.

Wiederholung: aktuelle PID und exakten ausführbaren Pfad ermitteln; den Befehl
aus [CHECKS.md](../../../CHECKS.md#offline-resource-benchmark) zweimal mit
`--duration 300 --interval 1` und jeweils neuer absoluter Ausgabedatei ausführen.
In dieser Zeit die installierte App nicht bedienen. Die gemeinsame CPU-Quote ist
`100 × Summe(cpu_delta_seconds) / Summe(observed_elapsed_seconds)`.

## Sichtbare UI-Teilprüfung

Die isolierte `OpenDictatePreview` wurde aus dem aktuellen Debug-Binary neu
erstellt, ad-hoc signiert und gestartet. Sie nutzt die gleichen Panelquellen wie
Build 7, jedoch künstliche Zustände ohne Mikrofon, Provider, Keychain,
Benutzereinstellungen oder echte Zwischenablageänderung. Screenshots und
AX-Zustände wurden in der Aufgabe `01a0d2c3-d26d-72f2-84e9-fe3ac34fcfe8` geprüft.

- Bereit, Fehler und manuell verfügbarer Text: bei 360 Punkten Breite in Hell
  und Dunkel lesbar, ohne abgeschnittene Hauptaktionen oder Erklärung.
- Aufnahme und Verarbeitung: in Dunkel lesbar. Tab wechselte bei Verarbeitung
  von „Abbrechen“ zu „Weitere Aktionen“; Umschalt-Tab führte zurück. Die
  Fokusmarkierung war sichtbar.
- Unbestätigte automatische Übergabe: „Diktat verarbeitet“ mit Aufforderung,
  das Zielprogramm zu prüfen. „Text ansehen“ zeigte den vollständigen
  künstlichen Text und warnte vor möglicher Doppelung; der Fokus erreichte das
  Textfeld.

Reproduktion: isolierte Gestaltungsvorschau starten, mit ⌘0 die Optionen öffnen,
Zustand und Erscheinungsbild wählen; im Panel Hauptaktion, Rückweg und
Tab/Umschalt-Tab prüfen. Nach der Prüfung wurde der Vorschauprozess beendet.

Das ist kein vollständiger UI-Abschluss: 340-Punkte-Mindestbreite, sämtliche
Zustände in beiden Darstellungen, reale Einstellungen, gehörtes VoiceOver und
die 20 per Video gemessenen Übergangszeiten bleiben gesondert zu belegen.

## Wiederverwendbare frühere Nachweise

Der direkte Vergleich `git diff bd3630f c92cbc9` ist für `AudioRecorder`,
`HotKeyManager`, `DictationFlow`, `OpenAITranscriber` und `PasteboardInserter`
leer. Die [fünf echten Diktate vom 23. September](2026-09-23-plan1-status.md)
behalten deshalb ihren Aussagewert für diese konkreten Zielprogramme und
Produktionspfade. Ebenso bleiben die tatsächlich bestandenen nativen und
Fokusfälle der [Offline-Matrix](2026-09-23-offline-matrix.md) verwendbar.
Das macht fehlende Matrixfälle nicht bestanden und benennt die alten Läufe
nicht nachträglich als fünf Build-7-Läufe. Der unten dokumentierte aktuelle
physische Kürzel-Durchlauf ergänzt diese Nachweise.

Die frühere falsche Erfolgsmeldung beim Pruning ist bereits durch `620dc39`
korrigiert: `prune` zählt nur erfolgreich gelöschte Dateien und protokolliert
verweigerte Löschungen gesondert. Die installierte Build-3-Prüfung steht im
historischen Bericht. Dieser alte Befund ist kein erneut offener Fehler.

## Physisches Kürzel auf Build 7: TextEdit bestanden

Basti führte den vorbereiteten Lauf mit physischem Option+Shift+Space aus und
meldete „text ist da“. Anschließend wurde das eigene Dokument
`OpenDictate Matrix Plan 1.txt` direkt per Accessibility-Wert und Screenshot
geprüft. Im vorher leeren Feld stand vollständig:

> Dieser Test enthält sieben grüne Äpfel.

Das Panel der installierten App zeigte „Diktat verarbeitet“ und die reguläre
Rückmeldung zum ausgelösten automatischen Einfügen. Damit ist dieser aktuelle
Durchlauf mit menschlicher Sprache, physischem Kürzel und sichtbarer Einfügung
in TextEdit belegt. Kein künstlicher Tastendruck oder synthetischer Text wurde
für dieses Ergebnis verwendet. Die Aussage gilt für diesen konkreten Lauf,
nicht als allgemeines Sprachqualitätsurteil oder erneuter Fünf-App-Nachweis.

Das eigene Testdokument bleibt für die anschließende Prüfung des manuellen
Kopierwegs vorübergehend geöffnet und ist danach zu bereinigen.
