# Ergänzende Zielabnahme — 2026-09-17

## Kandidat und Umfang

Die installierte Produktionsbinärdatei ist unverändert, SHA-256:
`134fcef15fe9da51d636a3b9cd3bf414d7714246de96d65e6bb0a169bdac961b`.
Die Quelländerung erweitert ausschließlich die DEBUG-Matrix-Fixture um
Zielerfassung ohne Eingabe und TextEdit. Sie verändert nicht den installierten
Produktionseinfüger. Dieser Bericht ergänzt die
[vorherige Abnahme](roadmap-acceptance-2026-09-17.md), ohne deren historische
Versuche umzudeuten. Eine neue Installation oder Veröffentlichung gehört nicht
zu dieser Ergänzung.

Der neue, gesondert begrenzte Liveblock umfasst acht Aufnahmen und acht Uploads,
konservativ höchstens 170 von 180 Sekunden Aufnahmezeit (`25 + 6 × 20 + 25`).
Die kurzen Aufnahmedauern wurden nicht exakt gemessen. Alle Versuche verwenden
denselben etwa 4,7 Sekunden langen, mit Anna erzeugten Testsatz über Lautsprecher
und echtes Mikrofon:

> Dies ist ein kurzer Test. Bitte schreibe die Zahl sieben und das Wort Apfel.

Die freigegebene Versuchszahl ist ausgeschöpft. Die acht Fälle sind getrennt von
den sechs Aufnahmen der früheren Abnahme zu zählen; ein Fehlversuch zählt mit.
Lokale Evidenz: `.build/target-acceptance-20260917/live-ledger.json` und
`live-operations.log`. Der Logauszug enthält zusätzlich synthetische und Offline-
Prüfeinträge; diese sind keine weiteren Live-Aufnahmen.

## Reale Mikrofon-/Provider-/Zielübergabe

| Fall | Ziel und Beobachtung | Bewertung |
|---|---|---|
| 1 | TextEdit `AXTextArea`: `MARKIERUNG` durch das Transkript ersetzt, `Anfang.` und `Ende.` erhalten. | Bestanden |
| 2 | Safari `input`: gleiche genaue Auswahlersetzung. | Bestanden |
| 3 | Safari `textarea`: ursprüngliches Feld bleibt `Anfang. MARKIERUNG Ende.`; vollständiger Text im manuellen Rückweg angezeigt. | Automatische Einfügung nicht bestanden; verlustfreier Rückweg belegt, Ursache ungeklärt |
| 4 | Safari `textarea`: erneuter Lauf nach Aktivierung über Finder; genaue Auswahlersetzung. | Bestanden; erklärt den vorherigen Fallback nicht |
| 5 | Safari `contenteditable`: genaue Auswahlersetzung. | Bestanden |
| 6 | Safari iframe: genaue Auswahlersetzung im eingebetteten Feld. | Bestanden |
| 7 | Obsidian CodeMirror im isolierten Vault: genaue Auswahlersetzung. | Bestanden |
| 8 | Beabsichtigt war Safari → TextEdit während Aufnahme. Tatsächlicher App-Wechsel nicht belegt; das ursprüngliche Safari-Feld erhält Text, TextEdit bleibt unverändert. | Kein bestandener negativer Fokusfall; kein belegter Produktfehler |

Die bestandenen Fälle liefen ohne manuelles Einfügen. Der sichtbare Zieltext in
Fall 1 enthält Punkt und großes „Bitte“, die weiteren Zieltexte Komma und kleines
„bitte“; die Wörter stimmen mit der Referenz überein. Auswahlersetzung bedeutet
hier vollständigen Ersatz des Platzhalters bei erhaltenem Feldumfeld. Ein
separater Zeichen-für-Zeichen-Abgleich zwischen Ergebnisansicht und Ziel wurde
in diesen Läufen nicht durchgeführt. Daraus folgt weder eine allgemeine
App-Supportzusage noch ein Nachweis menschlicher Sprachqualität.

Die acht eindeutig zugeordneten Logpaare für Request/Stopp bis Ergebnis betragen
in Fallreihenfolge (ms): 1.732,77/1.784,24; 1.322,68/1.419,00;
1.223,67/1.252,53; 520,53/596,97; 631,27/693,93; 581,70/651,83;
714,60/780,17; 669,81/744,69. Das sind instrumentierte Logzeiten, keine
gemessenen visuellen Latenzen.

## Mikrofonfreie Prüfungen und Grenzen

Die erweiterte Matrix-Fixture prüft die tatsächliche Vordergrund-App über
`NSWorkspace` und das konkrete AX-Ziel; ein ausgewählter CUA-Appkontext allein
gilt nicht als Fokusnachweis. Zusätzliche synthetische Unicode-Übergaben in
nativen Feldern, Safari-`input` und Obsidian sind bestanden. Diese Prüfungen
benötigen keine Provideranfragen und ersetzen keine reale Aufnahmephase.
Zwei getrennte synthetische Safari-Tabwechsel sind bestanden: vom lokalen
`input` zur vorhandenen Startseite während zehn Sekunden simulierter Aufnahme
sowie während fünf Sekunden simulierter Verarbeitung. Der Wechsel war jeweils
sichtbar; Ergebnis `textAvailable`, vollständige isolierte Testzwischenablage
und 0 von 4 Unicode-Chunks. Nach Rückkehr blieb das Feld unverändert; für die
Verarbeitungsphase ist der genaue AX-Vorher-/Nachher-Wert belegt. Zwei zusätzlich
versuchte synthetische Appwechsel konnten nicht zuverlässig aktiviert werden
und gelten ausdrücklich nicht als bestanden.

Bestanden: 130 Swift-Tests bei vier übersprungenen Opt-in-Prüfungen, acht
Python-Tests, Formatprüfung, vier Shell-Syntaxprüfungen und Diffprüfung.

Die reale negative Appwechselprüfung und die vollständige Feld-/Fokusphasenmatrix
bleiben offen. Ebenso offen: physischer Hotkey, Gerätewechsel/Abziehen, reale
Berechtigungs-/Keychainfehler, Beenden während Aufnahme/Upload, gehörte VoiceOver-
Ausgabe, menschlicher Referenzkorpus und Korrekturaufwand. Dieser Block wiederholt
weder die frühere 90-Sekunden-Prüfung noch Ressourcenmessungen. Streaming,
Hold-to-talk, andere Betriebssysteme und öffentliche Veröffentlichung bleiben
außerhalb dieses Auftrags.

## Integrität und Bereinigung

Die Lautstärke ist von temporär 75 Prozent auf die aktuelle Nutzerbaseline
68,75 Prozent zurückgestellt. Beide ursprünglichen Recoverydateien sind mit
übereinstimmenden Hashes und Dateimodi wiederhergestellt. Der Präferenzexport
ist unverändert; die Obsidian-Vaultregistrierung wurde nach Prüfung der einzigen
Änderung (eigener Testvault) bytegenau wiederhergestellt. Vorhandene Notizen
wurden nicht bearbeitet. App, Helper, TextEdit, Safari, Obsidian und
Systemeinstellungen sind wie vor dem Block beendet; Finder zeigt wieder den
Schreibtisch. Der lokale Safari-Testtab ist geschlossen, durch erneutes Öffnen
auf die Startseite zusätzlich kontrolliert. Eigene Referenzaudiodatei,
TextEdit-Datei, Testvault und Helper-Bundle sind entfernt. Keine temporäre
OpenDictate-M4A-Datei verbleibt. Kandidatenhash unverändert. Der lokale
Integritätsnachweis steht in `.build/target-acceptance-20260917/cleanup.json`.
