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

Die beiden zunächst installierten lokalen Helfer-Builds trugen wegen des
Standardwerts im Buildskript fälschlich die sichtbare Buildnummer 1, obwohl
zuvor Build 4 installiert war. Das wurde durch einen explizit mit
`OPENDICTATE_BUILD_NUMBER=6` gebauten, signierten Bundle-Build aus Quellstand
`d79b947` korrigiert und in beiden App-Pfaden installiert. Deren Plists melden
Build 6, der neue Prozess startete ohne Schlüsselbunddialog. Das vorherige
Bundle ist unter `.build/keychain-build1-rollback-20260924/` gesichert. Ein
erneuter tatsächlicher API-Schlüssel-Lesezugriff auf Build 6 wurde wegen der
voll belegten Recovery-Bibliothek noch nicht ausgelöst.

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
Lauf ohne Text wurden nach Bastis Freigabe einzeln in der App gelöscht.
Ihre Audio- und `.auth`-Dateien sind nicht mehr vorhanden; die drei älteren
Aufnahmen stehen weiterhin in der App-Liste und im Speicherordner.

Das tatsächlich installierte Panel zeigte den Bereit-Zustand ohne erzwungene
Fensteröffnung während der Aufnahme. Die kompakten Einstellungen zeigten
Mikrofon, Kürzel, Sprache, automatisches Einfügen, Aufnahmen und Hilfe ohne
Scrollen. Im ausgeklappten Bereich blieben Modell, API-Schlüssel und
Vokabular über Scrollen erreichbar. Tab wechselte vom Mikrofon zum Kürzel,
Shift-Tab zurück. Diese Sicht- und Tastaturprobe ersetzt weder gehörte
VoiceOver-Ausgabe noch die vollständige Zustandsprüfung in Hell und Dunkel.

Die Bibliothek enthält die drei vorgefundenen Aufnahmen. Die beiden eigenen
Testaufnahmen sind bereinigt.

## Build 7: bereinigter Bereit-Zustand

Die doppelte Bereit-Zeile im Panel wurde in Quellstand `c92cbc9` durch eine
konkrete Anleitung für das Zieltextfeld ersetzt. Beide bestehenden App-Pfade
enthalten den signaturgeprüften Build 7. Der echte Bereit-Zustand zeigte die
neue Zeile sichtbar. Lokale Swift- und Python-Tests, Format- und Shell-Prüfungen,
Bundle-Verifikation und die Bundle-Fehlerfixtures bestanden. Die CI-Jobs auf
macOS 14 und 15 bestanden für diesen Quellstand.

Ein neues leeres TextEdit-Dokument ist vorbereitet. Ein Accessibility-Klick
und die Fensteraktion „Alle nach vorne bringen“ ließen macOS dennoch
OpenDictate als vorderste App melden. Deshalb wurde kein Diktatversuch mit
unbekanntem Ziel gestartet. Die Ausgabe wurde nach einer vorübergehenden
Anhebung von 44 auf 80 Prozent wieder auf 44 Prozent zurückgestellt. Der
sichtbare Einfügeweg und der echte Schlüsselbund-Lesezugriff von Build 7 sind
weiter offen.

## Build 7: echter TextEdit-Einfügeweg

Am 24. September stand TextEdit laut `NSWorkspace.frontmostApplication`
tatsächlich im Vordergrund; dessen `First Text View` war fokussiert und enthielt
vor dem Test nur ein vorhandenes Leerzeichen. Die Computersteuerung löste das
globale Kürzel nicht aus, weshalb die folgenden Läufe ausdrücklich **über den
Aufnahme-Knopf** der installierten App gestartet und beendet wurden. Der
App-Quellstand war `c92cbc9`, beide installierten Bundles meldeten Build 7;
Testsystem war der Apple-Silicon-Mac mit macOS 27.0.

Der erste kurze Lauf bei 44 Prozent Systemausgabe erreichte nach der Aufnahme
den Provider, lieferte aber keinen Text. Die App zeigte „Kein Text“ und
behielt die authentifizierte Aufnahme zur Wiederholung. Beim zweiten Lauf
mit vorübergehend 80 Prozent Systemausgabe lieferte der Provider Text.
OpenDictate meldete ausgelöstes automatisches Einfügen; das TextEdit-Feld
enthielt danach sichtbar `Obendichtate Probe Apfel sieben.` hinter seinem
vorhandenen Leerzeichen. Damit sind API-Schlüssel-Lesezugriff, Mikrofon,
Provider-Antwort und automatische Einfügung **für diesen Knopf-Lauf auf Build 7**
belegt. Die leichte Wortabweichung stammt aus der Spracherkennung; ein
Sprachqualitätsnachweis ist das nicht. Das physische globale Kürzel auf Build 7
und andere Zielprogramme wurden in dieser Runde nicht erneut geprüft.

Nur der eingefügte Testsatz wurde aus TextEdit entfernt; der vorherige
Feldinhalt blieb erhalten. Die eigene leere Wiederholungsaufnahme und ihre
Authentifizierungsdatei sowie die erzeugte Sprachdatei wurden einzeln
entfernt. Die drei zuvor vorhandenen Aufnahmen blieben bestehen. Die
Systemausgabe wurde auf die vorherigen 44 Prozent zurückgestellt. Während
beider Läufe erschien kein neuer Schlüsselbunddialog.
