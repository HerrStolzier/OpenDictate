# Plan 3: Messbogen für den Betatest

Vorlage für die 20 Aufgaben aus [Plan 3](03-begrenzter-betatest.md). Jeder
Tester erledigt die vier gemeinsamen Fälle H01, H02, H03 und H12; die acht
Sonderfälle H04 bis H11 aus der
[Pilotliste](../audio-quality-fixtures.md#prepared-first-human-pilot) werden
einmal verteilt. Ausgefüllte Bögen mit Testtexten bleiben privat und kommen
nicht ins Repository.

## Pro Tester einmal

| Tester | macOS | Mac-Modell | Build | Ziel-App(s) | Sprache | Mikrofon | Minuten vom ersten Start bis zum ersten nutzbaren Text | Hilfe nötig? | Einfachheit (1–5) | Wieder verwenden? | Größter Reibungspunkt |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| T1 | | | 0.1.0 (8) | | | | | | | | |
| T2 | | | 0.1.0 (8) | | | | | | | | |
| T3 | | | 0.1.0 (8) | | | | | | | | |

Die Gruppe deckt ein natives Feld, ein Browserfeld und einen Electron-Editor ab.

## Aufgaben

„Zeit bis Text“: Sekunden vom Stopp bis zum nutzbaren Text **einschließlich
Korrektur**. „Auto“: ja, wenn der Text ohne eigenes Einfügen im erwarteten
Feld landete; der manuelle Kopierweg zählt als nein. Fehlende Messungen
bleiben leer, nicht 0. Fehlgeschlagene Versuche zählen mit.

| Nr. | Tester | Aufgabe | Zeit bis Text (s) | Auto | Fehler | Notiz |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | T1 | H01 Kurze Nachricht (zwei Sätze, leeres Feld) | | | | |
| 2 | T1 | H02 Einschub in einen bestehenden Satz | | | | |
| 3 | T1 | H03 Markierte Passage ersetzen | | | | |
| 4 | T1 | H12 Freie Notiz (zwei bis drei Sätze, ohne Vorlage) | | | | |
| 5 | T1 | H04 „Der Termin ist am siebten Mai um vierzehn Uhr dreißig.“ | | | | |
| 6 | T1 | H05 „Bitte lege zwölf Schrauben und drei Muttern bereit.“ | | | | |
| 7 | T1 | H06 „Müller und Schuster prüfen OpenDictate.“ | | | | |
| 8 | T2 | H01 Kurze Nachricht (zwei Sätze, leeres Feld) | | | | |
| 9 | T2 | H02 Einschub in einen bestehenden Satz | | | | |
| 10 | T2 | H03 Markierte Passage ersetzen | | | | |
| 11 | T2 | H12 Freie Notiz (zwei bis drei Sätze, ohne Vorlage) | | | | |
| 12 | T2 | H07 Kurze Liste über mehrere Sätze | | | | |
| 13 | T2 | H08 Kurzer Satz, bewusst leise gesprochen (Sonderprobe) | | | | |
| 14 | T2 | H09 Satz mit Zögern oder Selbstkorrektur | | | | |
| 15 | T3 | H01 Kurze Nachricht (zwei Sätze, leeres Feld) | | | | |
| 16 | T3 | H02 Einschub in einen bestehenden Satz | | | | |
| 17 | T3 | H03 Markierte Passage ersetzen | | | | |
| 18 | T3 | H12 Freie Notiz (zwei bis drei Sätze, ohne Vorlage) | | | | |
| 19 | T3 | H10 Kurze englische Nachricht, Sprache automatisch | | | | |
| 20 | T3 | H11 Deutscher Satz mit „Pull Request“ und „Code Review“ | | | | |

## Auswertung gegen die Abnahme

- Von den 19 Aufgaben ohne H08 enden mindestens 18 mit „Auto: ja“.
- H08 wird getrennt bewertet: möglicher Heuristik-Skip und bewusster
  Wiederholungsweg.
- Alle drei Tester erreichen den ersten nutzbaren Text in höchstens fünf
  Minuten ohne Hilfe; jeder beendet mindestens eine freie Notiz.
- Median „Zeit bis Text“ über die zwölf gemeinsamen Aufgaben (Nr. 1–4, 8–11,
  15–18) höchstens 20 Sekunden.
- Mindestens zwei Tester würden die App wieder verwenden **und** geben bei
  Einfachheit mindestens 4.
- Jeder Fehler bekommt Reproduktion, Schweregrad und die Entscheidung
  „beheben“ oder „als Grenze dokumentieren“. Datenverlust oder beschädigter
  vorhandener Text stoppt den Test.
