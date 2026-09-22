# Installierte macOS-App: Terminal und Fokuswechsel am 22. September 2026

## Kandidat und Freigabe

Geprüft wurde die bereits installierte `/Applications/OpenDictate.app`, Version
0.1.0, Build 1, Quellrevision `68ef919b550eedb982e71405bb4d4d6bb9c27e93`
unter macOS 27.0 mit Apple Terminal 2.15. Die App blieb unverändert. Der
vorherige [TextEdit-Durchlauf](live-acceptance-2026-09-22.md) belegt die
erneuerte Bedienungshilfen-Freigabe für denselben Kandidaten.

Basti gab für diesen Block höchstens drei kurze Mikrofonaufnahmen und drei
OpenAI-Uploads über das bereits eingerichtete Konto mit insgesamt höchstens
45 Sekunden Audio frei. Der Block ist durch **drei Aufnahmen** ausgeschöpft.
Es gab **zwei Provider-Request-Versuche**: einen erfolgreichen und einen nach
31 Sekunden erfolglosen. Die erste Aufnahme war zu leise und wurde nicht
hochgeladen. Die einzelnen Aufnahmedauern wurden nicht instrumentiert; die
Einhaltung der 45-Sekunden-Grenze lässt sich deshalb nicht nachträglich exakt
belegen. Alle angesagten Testsätze waren kurz. Ein vierter Lauf erfolgte nicht.

## Terminal: enger sichtbarer Erfolg

Ein eigenes Terminal-Fenster zeigte eine leere lokale `zsh`-Eingabezeile.
Basti fokussierte diese Zeile. Die Prüfung des tatsächlich fokussierten
Accessibility-Elements ergab `AXTextArea`, eine Auswahl mit Länge 0,
`AXSelectedText` nicht setzbar und Secure Input aus. Das entspricht dem
vorgesehenen engen Terminal-Pfad. Es lief kein interaktives Programm; kein
Befehl wurde abgeschickt.

Der erste physische Hotkey-Durchlauf hatte Peak −53 dB und Durchschnitt
−57 dB und blieb unter der −45-dB-Schwelle. Er endete ohne Provider-Request.
Der zweite Durchlauf hatte Peak −33 dB und Durchschnitt −42 dB. Der
Provider-Request endete nach 1.774 ms, die Übergabe nach weiteren 50 ms.
In der Terminal-Zeile erschien danach sichtbarer, nicht abgesendeter Text mit
den erwarteten Testbegriffen. Terminal zeigte nicht exakt die angesagte
Schreibweise und Zeichensetzung; eine allgemeine Sprachtreue wird daraus
nicht abgeleitet. Die Zeile wurde anschließend ohne Return entfernt und als
leer nachgewiesen.

Dies belegt für diesen Kandidaten die reale Mikrofon-→-Provider-→-Unicode-
Eingabe in eine leere Apple-Terminal-Shellzeile. Es belegt weder Terminal-Tabs,
Auswahlersetzung, laufende interaktive Programme noch iTerm2 oder andere
Terminal-Emulatoren.

## Fokuswechsel: durch Providerfehler unentschieden

Für die dritte und letzte Aufnahme wurde ein eigenes, zunächst leeres
TextEdit-Dokument geöffnet. TextEdit und Terminal lagen sichtbar nebeneinander.
Basti startete und stoppte die Aufnahme in TextEdit und berichtete den direkt
danach ausgeführten Wechsel zu Terminal. Der tatsächliche Vordergrund zum
Zeitpunkt der Einfügeentscheidung wurde nicht unabhängig erfasst. Das
TextEdit-`AXTextArea` blieb leer; die zugehörige Testdatei hatte weiterhin
0 Byte. Das App-Log zeigte jedoch einen 31.004-ms-Request,
der ohne Transkript endete. Die App sicherte die fehlgeschlagene Aufnahme.
Die Zwischenablage enthielt danach nicht die erwarteten Testbegriffe.

Damit ist **kein** negativer Fokusfall bestanden: Ohne Providertranskript kam
die Einfügelogik nicht zu der entscheidenden Übergabe. Auch der manuelle
Transkript-Rückweg ist für diesen Lauf nicht belegt. Die Ursache des
Request-Fehlers wurde in diesem Block nicht bestimmt.

## Integrität und nächster Nachweis

Die eigene nicht abgesendete Terminal-Zeile wurde entfernt und das für den Test
gestartete Terminal beendet. Das eigene TextEdit-Fenster wurde geschlossen;
die leere Testdatei und ihr temporäres Verzeichnis wurden entfernt. Die beiden
eigenen fehlgeschlagenen Recovery-Paare vom 22. September und temporäre
Prüfscreenshots wurden entfernt. Die ältere Aufnahme vom 15. September samt
`.auth` blieb erhalten. Andere Benutzerdateien und Zugangsdaten wurden nicht
verändert. Der Clipboard-Inhalt vor dem Test wurde aus Datenschutzgründen
nicht gelesen oder gesichert und konnte daher nicht wiederhergestellt werden.

Als nächstes braucht der reale negative Fokusfall einen neuen, ausdrücklich
begrenzten Live-Testblock oder einen aussagekräftigen bereits vorhandenen
synthetischen Nachweis für einen engeren Teil. Weitere Mikrofonläufe sind von
dieser Freigabe nicht gedeckt. Das Mac-Produkt ist dadurch nicht insgesamt
abgenommen oder veröffentlicht.
