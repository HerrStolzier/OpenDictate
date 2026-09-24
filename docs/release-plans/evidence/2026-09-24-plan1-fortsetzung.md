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
- Arbeitskopie zu Beginn: `694ac95e70aef159278a093c7141027cffc0355f`; `git diff c92cbc9 HEAD
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

Dies war zunächst eine Teilprüfung; die spätere Mindestbreitenrunde steht
unten. Reale Einstellungen, gehörtes VoiceOver und die 20 per Video gemessenen
Übergangszeiten bleiben gesondert zu belegen.

### Ergänzung: Aufnahme bei Mindestbreite

Die vorhandene Produktions-Fixture stellte das Panel explizit auf seine
Mindestbreite von 340 Punkten. Die künstlichen Aufnahmestände 80 und 85 Sekunden
bei −70 dB zeigten in Hell die vollständigen Countdown- und Signalhinweise sowie
die Aktionen „Aufnahme beenden“, „Abbrechen“ und „Weitere Aktionen“. Die
Screenshots wurden direkt angesehen. Das belegt diese beiden langen
Aufnahmebeschriftungen bei Mindestbreite; weitere Zustände werden dadurch nicht
pauschal abgenommen.

### Ergänzung: sämtliche Panelzustände bei Mindestbreite

Die reine Debug-Prüfhilfe aus `e704705` ergänzt „Mindestbreite prüfen“ in den
Vorschauoptionen. Sie setzt ausschließlich das eigene Vorschaupanel auf
`window.minSize.width` (340 Punkte). Die Produktionsdarstellung selbst wurde
nicht geändert. Nach einem regulären Neustart der neu gebauten Vorschau wurden
alle zehn angebotenen Zustände in Hell und Dunkel per Screenshot angesehen:
Bereit, Fast bereit, Aufnahme, Verarbeitung, bestätigt eingefügt, manuell
verfügbar, unbestätigte Übergabe, Fehler, Wiederholung und Abbruch.

Haupt- und Nebenaktionen, Erklärungen, Beispieltext und Fokusmarkierungen
blieben vollständig lesbar. Die lange Wiederholungsüberschrift brach sinnvoll
um. Zwei unmittelbar nach einem Zustandswechsel erfasste Fehlerbilder waren
angeschnitten; die gezielte erneute Aufnahme zeigte in beiden Darstellungen
das vollständige Panel. Daraus wird kein Latenzergebnis abgeleitet.

Reproduktion: Vorschau aus diesem Quellstand bauen, ⌘0 → „Mindestbreite prüfen“;
dann jedes Angebot unter „Vorschauzustand“ jeweils mit Hell und Dunkel ansehen.
Die Screenshots und AX-Zustände stehen im Haupttask
`01a0d2c3-d26d-72f2-84e9-fe3ac34fcfe8`. Diese Prüfung betrifft das gemeinsame
Panel mit Beispieldaten, nicht reale Einstellungen oder gehörte Sprachausgabe.

Die erste Messprobe der lokalen Reaktionszeit dauerte einschließlich
Automations- und Screenshot-Aufwand 735 ms. Das ist keine belastbare Messung
der App-Latenz. Ein anschließend aufgezeichneter Tastendruck wurde wegen
mehrdeutiger Fensterzuordnung vor Zustellung verweigert; daraus gibt es keinen
bestandenen Zustandswechsel. Die Aufzeichnung wurde beendet. Die 20 geforderten
Video-Messungen bleiben offen.

## Browser-Prüfhilfe und neue Safari-Befunde

Die lokale HTML-Fixture aus `e704705` setzt kontrollierte Ausgangstexte und
Cursor-/Auswahlpositionen, speichert eine getrennte Referenz und vergleicht
den vollständigen tatsächlichen Feldinhalt. Sie setzt niemals den erwarteten
Prüftext in das Feld. Der neue `contenteditable`-Vergleich nutzt sichtbare
Zeilenumbrüche; NFC-Gleichheit bleibt eine getrennte Diagnose.

| Fall | Beobachtung |
|---|---|
| Safari `textarea`, Anfang | Produktions-Fixture fügte die mehrzeilige Probe vor dem vollständigen Ausgangstext ein. Rohvergleich: 69 statt 70 UTF-16-Einheiten, erste Abweichung 34; NFC vollständig gleich. [Soll/Ist-Anzeige](2026-09-24-safari-multiline-start.json), [Screenshot](2026-09-24-safari-multiline-start.png). |
| Safari `contenteditable`, Auswahl `MARKIERUNG` | Referenz bestätigt Auswahl 8–18. Automatische Fixture-Übergabe meldete `deliveryUnconfirmed` und vollständige Zwischenablage, ließ das Feld aber unverändert. Auch nach gezieltem sichtbarem Editor-Klick und neu gespeicherter Auswahl keine Einfügung. Ursache noch nicht eingegrenzt. |
| Dasselbe Feld, ausschließlich manuelle Diagnose | Ein danach separat ausgelöstes ⌘V ersetzte die Auswahl vollständig. Rohvergleich 59 statt 60, erste Abweichung 42; NFC gleich. Das belegt den manuellen Weg und die Vergleichshilfe, **nicht** die automatische Übergabe. [Diagnose](2026-09-24-safari-rich-manual-diagnostic.json), [Screenshot](2026-09-24-safari-rich-manual-diagnostic.png). |

Vor den automatischen Versuchen bestätigte die Fenstersteuerung Safari als
Vordergrundprozess und das richtige fokussierte Fenster. Ihre zusätzliche
Prüfung des vordersten normalen Fensters blieb wegen eines kleinen überlagerten
Fensters unbestätigt. Die Ursache ist deshalb weder als Produktionsfehler noch
als reine Automationsgrenze entschieden. Keine Mikrofon-/Provideraktion war
an diesen Fällen beteiligt. Die Entscheidung über kanonische
Unicode-Normalisierung ist ebenfalls noch offen; kein Rohfehler wird als
„EXAKT“ umgedeutet.

Nach Integration bestanden Formatter, 138 vorhandene Swift-Testfunktionen
(vier Opt-in-Fälle übersprungen), acht Python-Tests, sechs Shell-Syntaxprüfungen
und `git diff --check`. Der Standard-Swift-Testaufruf scheiterte am bekannten
fehlenden `TestingMacros`-Plugin; der in `CHECKS.md` dokumentierte explizite
Plugin-Pfad bestand. Der Debug-Build bestand. Das ändert weder den installierten
Build 7 noch seine Signatur oder Berechtigungen.

Das eigene Safari-Fixturefenster und beide eigenen Prüfhilfen wurden danach
regulär geschlossen; die vorher vorhandene Safari-Startseite blieb bestehen.
Eine Prozessprüfung bestätigte, dass Vorschau, Matrix-Fixture und nativer
Feld-Host beendet waren und die installierte App mit PID 82317 weiterlief.
Die Fixture führt beim Beenden ihre vorhandene bedingte
Zwischenablage-Wiederherstellung aus. Die nicht verwertbare lokale
Videoaufnahme wurde nach bestätigtem Aufzeichnungsende entfernt.

### Spätere Safari-Fokusdiagnose

Die CI für `1f9a1b3` bestand auf macOS 14 und 15
([Lauf](https://github.com/HerrStolzier/OpenDictate/actions/runs/36026210411)).
Der Luna-Task prüfte den unveränderten Inserter: `deliveryUnconfirmed` bestätigt
nur das Posten der CGEvents, nicht deren Verarbeitung durch Safari. Die
App-Aktivierung mit anschließender 250-ms-Wartezeit prüft die Vordergrund-PID,
aber keinen konkreten Feldempfänger. Das erklärt die Unsicherheit des Befunds,
belegt für sich jedoch keine Ursache.

In einem neuen eigenen Safari-Tab blieb die kontrollierte Auswahlersetzung
erneut aus: mit ausgeblendetem Agentenzeiger der eigens angelegten Cua-Sitzung,
Aktivierung vor der Referenzvorbereitung und anschließend ausschließlich
Hintergrundaktionen. Auch eine Tastatur-Fokusprobe vor erneuter Vorbereitung
änderte das nicht. Ein gesonderter Anfangsfall mit gespeicherter Referenz 0–0
und anschließendem unveränderndem Pfeil-links-Tastendruck blieb ebenfalls ohne
Einfügung. Der native AX-Fokus zeigte dabei den formatierten Editor; die
Fixture bestätigte Safari, vollständige Zwischenablage und
`deliveryUnconfirmed`. Kein manuelles ⌘V wurde in dieser Runde als Ersatz
für den automatischen Nachweis verwendet. Keine Produktionsquelle wurde geändert.

Der anschließend vorbereitete echte Mausklickvergleich wurde von Basti
ausgeführt: eigener Safari-Tab, `contenteditable`, Cursor am Anfang,
Referenz 70 UTF-16-Einheiten, zehn Sekunden synthetische Aufnahmezeit.
Er klickte „Lokales Testfeld erfassen“ und wechselte zu Safari. Die erste
Beobachtung lag noch während der zehn Sekunden; erst nach dem abgeschlossenen
Lauf wurde das unveränderte Feld bestätigt. Die Fixture meldete
`deliveryUnconfirmed`, vollständige Zwischenablage und Safari als Ziel.
[Begrenzter Ist-Nachweis](2026-09-24-safari-physical-click-no-insertion.json).
Kein Mikrofon, Provider oder globaler Systemeinstellungswechsel war beteiligt.

### Gegenprobe: PID-Versand und unveränderter Produktionsweg

Die ausschließlich für DEBUG ergänzte PID-Option aus `153da2d` war zunächst
ausgeschaltet. Sie ersetzte nur den Versand des gleichen ⌘V-Ereignispaars;
die regulären Produktionsprüfungen blieben bestehen. Vor dem Code waren die
isolierten Fehlerfälle in `CHECKS.md` desselben Commits festgehalten.
Das eigene Fixture-Bundle wurde neu gebaut und mit der bereits vorhandenen
Identität signiert. Die installierte App und deren Freigaben blieben unverändert.

Im neuen Testprozess 81953 mit Safari-Prozess 29269, Fenster 5256, wurde je
Versandart der Ausgangstext zurückgesetzt und die Anfangsreferenz 0–0 bestätigt.
Zuerst mit eingeschalteter PID-Diagnose, anschließend mit ausgeschalteter
Diagnose und regulärem globalem `CGEvent` erschien der vollständige Text.
Beide Rohvergleiche ergeben 69 statt 70 UTF-16-Einheiten, erste Abweichung bei
34; beide vollständigen Texte sind NFC-gleich.
[Soll/Ist und Moduszuordnung](2026-09-24-safari-pid-versus-global.json),
[Bild des PID-Ergebnisses](2026-09-24-safari-pid-diagnostic.png).
Das Bild allein identifiziert die Versandart nicht; dafür dienen die separat
beobachtete Checkbox und der Fixture-Ergebnistext.

Damit ist kein nötiger Produktionswechsel auf PID-Versand belegt. Die früheren
Fehlschläge werden nicht rückwirkend als bestanden markiert. Neuaufbau,
Prozessneustart und veränderter Fokuszustand unterscheiden die Runden;
welcher Faktor ursächlich war, wurde nicht isoliert. Die erfolgreiche Runde
bestätigte das gewöhnliche Safari-Fenster als Vordergrundfenster, frühere
Automationsrunden hatten teilweise nur ein kleines Overlay bestätigt.
Die vorübergehende PID-Diagnose wird nach Sicherung des Befunds entfernt.
Der parallel angeforderte [Luna-Max-Review](2026-09-24-critical-plan1-review.md)
bestätigt diese enge Einordnung.

### Ergänzte Safari-Positionen im normalen Modus

Alle folgenden zusätzlichen Läufe nutzten den regulären globalen Einfügeweg
des selben Testprozesses; die PID-Diagnose war ausgeschaltet. Vor jedem Lauf
wurden Ausgangstext und erwartete Auswahl in der lokalen Seite geprüft und
die getrennte Sollreferenz gespeichert. Nur die Produktions-Fixture fügte
den künstlichen Text ein. Danach wurden der vollständige AX-Feldwert und
der Roh-/NFC-Vergleich der Seite gelesen. Die anderen Testfelder blieben
bei jeder Aktion unverändert.

| Feld | Anfang | Mitte | Auswahlersetzung |
|---|---|---|---|
| `input`, einzeilige Unicode-Probe | [Soll/Ist](2026-09-24-safari-input-start.json) | [Soll/Ist](2026-09-24-safari-input-middle.json) | [Soll/Ist](2026-09-24-safari-input-selection.json) |
| `textarea`, mehrzeilige Probe | [Früherer aktueller Nachweis](2026-09-24-safari-multiline-start.json) | [Soll/Ist](2026-09-24-safari-textarea-middle.json) | [Soll/Ist](2026-09-24-safari-textarea-selection.json) |
| `contenteditable`, mehrzeilige Probe | [Globale Gegenprobe](2026-09-24-safari-pid-versus-global.json) | [Soll/Ist](2026-09-24-safari-rich-middle.json) | [Soll/Ist](2026-09-24-safari-rich-selection.json) |
| Editierbares `iframe`, mehrzeilige Probe | [Soll/Ist](2026-09-24-safari-iframe-start.json) | [Soll/Ist](2026-09-24-safari-iframe-middle.json) | [Soll/Ist](2026-09-24-safari-iframe-selection.json) |

Alle zwölf Positionen haben damit einen vollständigen Einfügenachweis mit
NFC-Gleichheit. Die Rohvergleiche weichen jeweils ausschließlich durch
`e` + U+0301 gegenüber U+00E9 ab. Ihre Akzeptanzentscheidung bleibt offen;
die Anzeigen werden nicht nachträglich in „EXAKT“ geändert. Das ist eine
synthetische Feldmatrix, kein weiterer Mikrofon-/Providerlauf und keine
pauschale Safari-Kompatibilitätsaussage.

Zur Wiederholung: HTML-Fixture in einem eigenen Safari-Tab öffnen, Feld,
Position und passenden Prüftext wählen, zurücksetzen, Position setzen und
Referenz speichern. In der separaten Produktions-Fixture dieselbe ein- oder
mehrzeilige Probe wählen und bei fokussiertem Safari-Feld die lokale Prüfung
starten. Erst nach abgeschlossenem Lauf den gesamten Feldwert vergleichen.
Nie die erwartete Probe zur Vorbereitung selbst ins Zielfeld schreiben.

Der eigene Safari-Testtab wurde anschließend geschlossen; die ursprüngliche
Startseite blieb offen. Die Prozessprüfung bestätigte den beendeten eigenen
Fixture-Prozess und den weiter laufenden installierten Build 7 (PID 82317).
Die Entfernung der temporären PID-Option wurde als `c5d6a27` integriert;
`DeliveryMatrixPreview.swift` entspricht danach wieder exakt dem bereits
geprüften Stand vor dieser Diagnose. Die historischen Fehlerfallvorgaben
bleiben im Diagnose-Commit `153da2d` nachvollziehbar.

## Ergänzte native Einfügepositionen

Die isolierten Helfer wurden aus den unveränderten Produktionsquellen von
`523cbd2` neu gebaut. `DeliveryMatrixPreview` nutzte den echten `DictationFlow`
und `PasteboardInserter`, ohne Mikrofon oder Provider. Das Ziel wurde in der
Fixture jeweils als `local.opendictate.matrixhost` bestätigt. Nach der Aktion
„Lokales Testfeld erfassen“ wurden Screenshot und tatsächlicher AX-Feldwert
geprüft. Die Fixture meldete regulär `deliveryUnconfirmed` und eine vollständige
Test-Zwischenablage; diese Meldung allein ist kein Einfügenachweis.

| Neuer Fall | Ergebnis und Nachweis |
|---|---|
| Einzeilig, Cursor vor `Anfang.` in `Anfang. Ende.` | Einzeilige Unicode-Probe vollständig vor dem unveränderten Ausgangstext; direkter AX-Wert stimmt exakt. [Screenshot](2026-09-24-native-single-start.png) |
| Einzeilig, Cursor vor `Ende.` | Unverändertes `Anfang. ` + Probe + `Ende.`; 59 UTF-16-Einheiten exakt. [Soll/Ist](2026-09-24-native-single-middle.json), [Screenshot](2026-09-24-native-single-middle.png) |
| Mehrzeilig, Cursor vor `Anfang.` | Probe mit Zeilenumbruch vor unverändertem Ausgangstext; 70 UTF-16-Einheiten exakt. [Soll/Ist](2026-09-24-native-multiline-start.json), [Screenshot](2026-09-24-native-multiline-start.png) |
| Mehrzeilig, Cursor vor `MARKIERUNG`, keine Auswahl | `Anfang. ` + mehrzeilige Probe + `MARKIERUNG Ende.`; 70 UTF-16-Einheiten exakt. [Soll/Ist](2026-09-24-native-multiline-middle.json), [Screenshot](2026-09-24-native-multiline-middle.png) |

Die Probe ist `Äpfel 🍏 und Grüße.` gefolgt von Zeilenumbruch (einzeilig:
Leerzeichen) und `Zweite Zeile: e` + U+0301 + `, 👩🏽‍💻.`. Andere Testfelder
blieben unverändert. Die bereits exakt bestandenen Auswahlersetzungen vom
23. September wurden nicht wiederholt. Der eigene native Feld-Host wurde danach
beendet. Der Einfüge-Helper bleibt für die Browsermatrix geöffnet.

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

## Manueller Kopierweg: bestanden

Im installierten App-Panel öffnete „Text ansehen“ das vollständige echte
Transkript. Das eigene TextEdit-Dokument wurde anschließend durch den
kontrollierten Platzhalter `OpenDictate Kopierprobe – Platzhalter` ersetzt.
Dieser wurde kopiert und durch einmaliges ⌘V im Dokument als tatsächlicher
Zwischenablageinhalt kontrolliert. Danach wurde ausschließlich in OpenDictate
„Text kopieren“ gedrückt. Die App meldete „Letzter Text kopiert“; das manuelle
⌘V in TextEdit ersetzte den Platzhalter wieder vollständig durch
`Dieser Test enthält sieben grüne Äpfel.` Der AX-Feldwert bestätigte das Ergebnis.
Damit ist die echte Kopieraktion nach einem Diktat geprüft; dies simuliert
keinen Providerfehler oder verweigerte Accessibility-Rechte.

Die Cua-Paste-Aktion beim Vorbereiten des Platzhalters meldete zunächst eine
Zeitüberschreitung, obwohl der Platzhalter bereits im Dokument stand. Der
Zustand wurde vor weiteren Aktionen gelesen; es gab keine blinde Wiederholung.
Dies betrifft die Testbedienung, nicht die OpenDictate-Kopieraktion.

Das eigene TextEdit-Dokument wurde geschlossen, die eigens gestartete
TextEdit-App beendet und die genau identifizierte temporäre Testdatei samt
leerem Testordner entfernt. Bestehende fremde Dokumente wurden nicht bearbeitet.
