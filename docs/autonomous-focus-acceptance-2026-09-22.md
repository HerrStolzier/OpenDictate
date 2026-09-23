# Autonomer Fokuswechselversuch am 22. September 2026

## Freigabe und Kandidat

Basti genehmigte auf die konkrete Rückfrage höchstens zwei kurze
Mikrofonaufnahmen, zwei OpenAI-Uploads und zusammen höchstens 20 Sekunden
Audio über das eingerichtete Konto. Der Agent durfte Testfenster, Kürzel und
eine künstlich gesprochene Phrase selbst bedienen und eigene Artefakte
bereinigen. Geprüft wurde die unveränderte installierte macOS-App
`/Applications/OpenDictate.app`, Revision `68ef919b550eedb982e71405bb4d4d6bb9c27e93`.

## Einziger Live-Lauf

Ein eigenes leeres TextEdit-Dokument war das Ausgangsziel. Ein eigenes
Rechner-Fenster war das harmlose Wechselziel. Vor dem Start wurde TextEdit als
Vordergrund-App und das leere Dokument sichtbar geprüft. Ein künstlich
gesprochener deutscher Testsatz wurde als 2,032-Sekunden-Audiodatei vorbereitet
und während der Aufnahme über die vorhandene Ausgabe abgespielt.

Der globale Hotkey startete und stoppte die Aufnahme; unmittelbar nach dem
Stopp wurde das Rechner-Fenster mit einem bestätigten Vordergrundwechsel nach
vorn geholt. Die App meldete Peak −35 dB und Durchschnitt −53 dB, bereitete
Audio vor und führte **einen** Provider-Request in 2.420 ms aus. Die
anschließende Übergabe dauerte 5,86 ms. Der Zwischenablage-Änderungszähler
blieb unverändert. Das TextEdit-Feld und die zugehörige Datei blieben leer.
Die App legte ein authentifiziertes Recovery-Paar an. Ein nutzbares Transkript
und eine automatische Einfügung wurden nicht beobachtet; die genaue Ursache
dieses Ergebnisses wurde nicht bestimmt.

**Die Aufnahme dauerte laut der gespeicherten Audiodatei 31,272 Sekunden.**
Damit wurde die ausdrücklich genehmigte Obergrenze von 20 Sekunden verletzt.
Der Agent hatte den Hotkey gestartet und vor dem Stoppen zu lange mit
Vorbereitung und Prüfung verbracht. Diese Zeitsteuerung war ein Fehler des
Agenten. Die Aufnahme wurde einmal an OpenAI hochgeladen; sie konnte während
der zusätzlichen Zeit auch Umgebungsgeräusche enthalten. Ihr Inhalt wurde
nicht abgehört oder ausgewertet. Nach Feststellung der Überschreitung gab es
keinen weiteren Mikrofonlauf oder Upload.

Der begleitende Vordergrund-Monitor lieferte wegen ausbleibender
Runloop-Aktualisierung nur den anfänglichen TextEdit-Wert. Der bestätigte
Wechsel zum Rechner und der spätere Rechner-Vordergrund belegen daher nicht
lückenlos die App am genauen Zeitpunkt der Einfügeentscheidung. Ohne nutzbares
Transkript wurde der negative Fokus-Schutz ohnehin nicht entscheidend
ausgeführt. Dieser Lauf ist **kein bestandener Fokuswechsel-Test**.

## Bereinigung und Grenze

Das eigene TextEdit-Dokument und Rechner-Fenster wurden geschlossen. Die
temporäre Textdatei, die synthetische Stimulusdatei, der eigene Monitor und
die eigene Recovery-Aufnahme samt `.auth` wurden entfernt. Nur das ältere
Recovery-Paar vom 15. September blieb erhalten. Die zuvor vordere Codex-App
war nach der Bereinigung wieder vorn. Der für diesen Test gestartete Rechner-
Prozess blieb ohne sichtbares Fenster bestehen; ein CUA-Menübefehl und ein
Kürzel beendeten ihn nicht nachweisbar. TextEdit und OpenDictate liefen wie
vor dem Test weiter. Die Zwischenablage wurde nicht verändert.

Der genehmigte Live-Block ist durch die überschrittene Audiozeit beendet.
Die damalige Forderung nach einer technisch erzwungenen Aufnahme-Obergrenze
war eine falsche Folgerung des Agenten. Basti stellte dies am 23. September
klar und beauftragte einen neuen, [bestandenen echten Fokuswechseltest](live-focus-acceptance-2026-09-23.md).
Die überschrittene Freigabe und der unentschiedene Befund dieses früheren Laufs
bleiben als historische Tatsachen erhalten.
