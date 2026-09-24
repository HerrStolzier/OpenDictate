# Plan 1 · Fortsetzung am 24. September 2026

Dies ist ein Zwischenstand für die lokal installierte App, keine fertige
Produktabnahme. Der geprüfte Mac mini läuft auf macOS 27.0 und arm64.

## Schlüsselbund über einen App-Build-Wechsel

Der signierte Quellstand `78826a3` wurde in beiden bestehenden App-Pfaden
installiert. Beim ersten Betrieb bestätigte Basti die beiden getrennten
macOS-Abfragen für den vorhandenen Wiederherstellungsschlüssel und den alten
API-Schlüssel direkt am Mac. Danach startete die App eine Aufnahme. Die App
legte den signierten `KeychainHelper-v1` einmal in ihrem Application-Support-
Ordner ab; sein Code-Hash war `d5403a920fcee4b08d48a01e1f6493d8db62b930`.

Anschließend wurden beide App-Kopien auf Quellstand `cbdfb34` aktualisiert.
Die laufende App wechselte von Code-Hash
`7a55ce5e68f8003de670eeeee7839eb08481795d` auf
`42825d25c4afe58f0951ac620015bc6c480cb9e6`; der installierte Helfer
behielt seinen Hash. Ein Klick auf „Aufnahme starten“ erreichte auf dem neuen
Build sofort „Aufnahme läuft“ mit Eingangssignal, ohne SecurityAgent-Prozess
oder neuen Schlüsselbunddialog. Der App-Startpfad liest den API-Schlüssel vor
der Aufnahme. Dieser konkrete Build-Wechsel ist damit praktisch bestanden.
Ein Helferwechsel oder anderes Signierzertifikat ist damit nicht abgedeckt.

Die bisherigen Bundles liegen lokal unter
`.build/keychain-rollback-20260923/` und
`.build/keychain-followup-rollback-20260924/`. Der Pull Request bestand nach
dem Code- und Dokumentationsstand die CI-Jobs auf macOS 14 und macOS 15.
Der macOS-14-Job ist ein nativer Offline- und Bundle-Nachweis, kein
interaktiver Diktatnachweis.

## Diktat und sichtbares Ziel

Nach der ersten Freigabe lief eine unbeabsichtigt lange Aufnahme an. Sie
wurde ohne Provider-Upload abgebrochen und als 81,3-Sekunden-Recovery-Datei
gesichert. Basti entfernte genau diesen Eintrag über die App; Audio und
`.auth` waren anschließend nicht mehr vorhanden. Die drei älteren
vorhandenen Aufnahmen blieben in der App-Liste.

Der kurze Build-Wechseltest wurde ebenfalls ohne Upload abgebrochen und
als eigene 4,7-Sekunden-Recovery-Datei gesichert. Ein weiterer Live-Lauf
erreichte OpenAI bei 31 Prozent Systemausgabe, lieferte aber keinen Text;
Peak und Durchschnitt lagen laut App-Log bei −29 und −46 dB. Die Aufnahme
blieb korrekt zur Wiederholung erhalten. Bei vorübergehend 80 Prozent
Ausgabe erkannte ein zweiter Provider-Lauf den harmlosen Systemsprache-Text
als „Oben digitale Probe Apfel sieben.“ und die App meldete ausgelöstes
automatisches Einfügen. Im eigenen leeren TextEdit-Dokument erschien aber
kein Text. Eine unabhängige Vordergrundabfrage meldete Brave als aktive App,
obwohl die Computersteuerung TextEdit als fokussiertes Feld anzeigte. Der
tatsächlich erfasste Zielprozess wurde für diesen Lauf nicht protokolliert;
der sichtbare Einfügefall ist daher **nicht bestanden** und wird mit bewusst
hergestelltem TextEdit-Vordergrund wiederholt. Die Ausgabe wurde auf ihre
vorherigen 31 Prozent zurückgestellt; die Toneinstellungen sind geschlossen.

Die zwei eigenen Recovery-Dateien aus dem 4,7-Sekunden-Abbruch und dem
Lauf ohne Text bleiben bis zur gezielten Einzelbereinigung bestehen. Die
älteren Aufnahmen werden nicht verändert.

Das tatsächlich installierte Panel zeigte den Bereit-Zustand ohne erzwungene
Fensteröffnung während der Aufnahme. Die kompakten Einstellungen zeigten
Mikrofon, Kürzel, Sprache, automatisches Einfügen, Aufnahmen und Hilfe ohne
Scrollen. Im ausgeklappten Bereich blieben Modell, API-Schlüssel und
Vokabular über Scrollen erreichbar. Tab wechselte vom Mikrofon zum Kürzel,
Shift-Tab zurück. Diese Sicht- und Tastaturprobe ersetzt weder gehörte
VoiceOver-Ausgabe noch die vollständige Zustandsprüfung in Hell und Dunkel.

Die Bibliothek enthält momentan die drei vorgefundenen und zwei eigenen
gesicherten Aufnahmen. Vor einem weiteren fehlgeschlagenen Aufnahmelauf
müssen die eigenen beiden Dateien gezielt bereinigt werden, damit die
Fünf-Dateien-Grenze keine ältere Aufnahme verdrängt.
