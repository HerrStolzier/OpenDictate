# Installierte macOS-App: negativer Appwechsel am 23. September 2026

## Kandidat und Ziel

Geprüft wurde die unveränderte installierte `/Applications/OpenDictate.app`,
Version 0.1.0, Build 1, Quellrevision
`68ef919b550eedb982e71405bb4d4d6bb9c27e93` unter macOS 27.0. Ziel war
ein echter Diktatlauf: Aufnahme in einem leeren TextEdit-Dokument stoppen,
während der Provider-Verarbeitung zu einem eigenen Finder-Fenster wechseln und
prüfen, dass der Text nicht in das verlorene Ausgangsziel gelangt, aber auf
der Zwischenablage verfügbar bleibt. Basti beauftragte die Wiederholung ohne
seine Bedienung und verwarf die zuvor vom Agenten geforderte technische
Aufnahmezeitgrenze.

Ein eigener, künstlich gesprochener deutscher Testsatz von 5,479 Sekunden
wurde über den Lautsprecher und das vorhandene Mikrofon verwendet. Diese
Referenz belegt keinen menschlichen Sprachqualitätswert. TextEdit war vor
beiden Starts nachweislich vorne; das Testdokument war leer. Der
Vordergrund-Monitor wurde vorab durch einen Finder→TextEdit-Wechsel geprüft
und verarbeitete danach macOS-Aktivierungsereignisse während der Testläufe.

## Durchläufe und Ergebnis

Der erste Hotkey-Lauf dauerte laut eigener Recovery-Audiodatei 7,037 Sekunden.
Bei ursprünglicher Ausgabelautstärke 38 meldete die App Peak −47 dB und
Durchschnitt −54 dB; ihre Schwelle liegt bei −45 dB. Sie übersprang die
Aufnahme ohne Provider-Request. Dieser Lauf ist kein Fokusnachweis. Die
Lautsprecherlautstärke wurde für den zweiten Lauf vorübergehend auf 70 gesetzt
und danach auf den geprüften Ausgangswert 38 zurückgestellt.

Im zweiten Lauf begann die Aufnahme um 06:05:52 UTC und wurde um 06:06:00 UTC
gestoppt. Der Finder wurde direkt danach als vorderes Fenster unabhängig
bestätigt. Der kontinuierliche Monitor sah TextEdit bis 06:05:59,563 UTC und
Finder ab 06:06:00,087 UTC, durchgehend auch vor und nach der
Einfügeentscheidung um 06:06:02,027 UTC. Die App meldete Peak −41 dB und
Durchschnitt −49 dB. Der echte Provider-Request dauerte 2.012 ms.

Anschließend protokollierte die App:
`Auto-paste unavailable: original target is missing, protected or changed`.
Die Zwischenablage wechselte von Änderungszähler 15 auf 16 und enthielt
39 Zeichen mit dem erkennbaren Testbegriff „Fokuswechsel“. Das TextEdit-
`AXTextArea` war danach leer; die Testdatei hatte weiterhin 0 Byte. Ein
Fensterbild bestätigte den leeren Zustand. Es gab keine Einfügung in Finder.
Damit ist der **negative Appwechsel nach dem Aufnahmestopp während der
Provider-Verarbeitung** für diesen Kandidaten bestanden: Das ursprüngliche
Ziel wurde nicht wieder aktiviert oder beschrieben, und der Text blieb als
manueller Kopierweg erhalten. Die genaue Transkriptschreibweise wurde nicht
als Sprachqualitätsmaß gewertet. Ein App-Quellcodefehler zeigte sich in diesem
Fall nicht; es war keine Codeänderung nötig.

## Bereinigung und Grenzen

Das eigene TextEdit-Dokument und Finder-Fenster wurden geschlossen. Die
temporäre Datei, Stimulus-Audiodatei, Monitor-Logs und Prüfbilder sowie das
eigene fehlgeschlagene Recovery-Paar des ersten Laufs wurden entfernt. Das
ältere Recovery-Paar vom 15. September blieb erhalten. Die zuvor vordere
Codex-App war nach dem Test wieder vorne. Die Zwischenablage enthält den
harmlosen Testtext; ihr Inhalt vor dem Lauf wurde nicht gelesen und kann
daher nicht wiederhergestellt werden.

Dieser Nachweis gilt für einen Appwechsel **nach dem Stoppen** von TextEdit zu
Finder mit einem künstlich gesprochenen Satz. Wechsel während Aufnahme,
mehrteiliger Übergabe, andere Zielprogramme, Terminal-Tabs und menschliche
Sprachqualität bleiben gesonderte Fälle. Die installierte App wurde nicht
ersetzt oder veröffentlicht.
