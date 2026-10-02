# Plan 3: Messbogen für die Eigennutzung

Vorlage für die 20 Aufgaben aus [Plan 3](03-eigennutzung.md): drei Runden an
verschiedenen Tagen, jede mit den vier gemeinsamen Fällen H01, H02, H03 und
H12 in einer anderen Zielkategorie; die Sonderfälle H04 bis H11 aus der
[Pilotliste](../audio-quality-fixtures.md#prepared-first-human-pilot) einmal
verteilt. Der ausgefüllte Bogen mit Testtexten bleibt privat und kommt nicht
ins Repository.

## Einmalig

| macOS | Mac-Modell | Build | Modell | Sprache | Mikrofon | Einfachheit (1–5) | Weiter verwenden? | Größter Reibungspunkt |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| | | 0.1.0 (8) | gpt-transcribe | | | | | |

## Aufgaben

- **Start / Stopp:** Uhrzeit mit Sekunden beim ersten und zweiten Tastendruck.
- **Stopp → Text (s):** Sekunden vom Stopp, bis der Text im Feld oder in der
  Zwischenablage steht.
- **Korrektur (s):** Sekunden, um den Text danach in die gewollte Form zu
  bringen; 0 nur, wenn wirklich nichts zu korrigieren war.
- **Ziel sichtbar:** ja, wenn der Text sichtbar im erwarteten Feld stand.
- **Auto:** ja, wenn er dort ohne eigenes Einfügen landete.
- **Manueller Rückweg:** ja, wenn „Text kopieren“, „Text ansehen“ oder ⌘V
  aus der Zwischenablage nötig war.
- **Fehlerursache:** kurz und konkret, z. B. „falsches Feld“, „Heuristik
  übersprungen“, „Providerfehler 429“, „Wort falsch erkannt“.

Fehlende Messungen bleiben leer, nicht 0. Fehlgeschlagene Versuche zählen mit.

| Nr. | Datum | Aufgabe | Ziel-App / Feld | Start | Stopp | Stopp → Text (s) | Korrektur (s) | Ziel sichtbar | Auto | Manueller Rückweg | Fehlerursache | Notiz |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | | H01 Kurze Nachricht (zwei Sätze, leeres Feld) | natives Feld: | | | | | | | | | |
| 2 | | H02 Einschub in einen bestehenden Satz | natives Feld: | | | | | | | | | |
| 3 | | H03 Markierte Passage ersetzen | natives Feld: | | | | | | | | | |
| 4 | | H12 Freie Notiz (zwei bis drei Sätze, ohne Vorlage) | natives Feld: | | | | | | | | | |
| 5 | | H04 „Der Termin ist am siebten Mai um vierzehn Uhr dreißig.“ | | | | | | | | | | |
| 6 | | H05 „Bitte lege zwölf Schrauben und drei Muttern bereit.“ | | | | | | | | | | |
| 7 | | H06 „Müller und Schuster prüfen OpenDictate.“ | | | | | | | | | | |
| 8 | | H01 Kurze Nachricht (zwei Sätze, leeres Feld) | Browserfeld: | | | | | | | | | |
| 9 | | H02 Einschub in einen bestehenden Satz | Browserfeld: | | | | | | | | | |
| 10 | | H03 Markierte Passage ersetzen | Browserfeld: | | | | | | | | | |
| 11 | | H12 Freie Notiz (zwei bis drei Sätze, ohne Vorlage) | Browserfeld: | | | | | | | | | |
| 12 | | H07 Kurze Liste über mehrere Sätze | | | | | | | | | | |
| 13 | | H08 Kurzer Satz, bewusst leise gesprochen (Sonderprobe) | | | | | | | | | | |
| 14 | | H09 Satz mit Zögern oder Selbstkorrektur | | | | | | | | | | |
| 15 | | H01 Kurze Nachricht (zwei Sätze, leeres Feld) | Electron-Editor: | | | | | | | | | |
| 16 | | H02 Einschub in einen bestehenden Satz | Electron-Editor: | | | | | | | | | |
| 17 | | H03 Markierte Passage ersetzen | Electron-Editor: | | | | | | | | | |
| 18 | | H12 Freie Notiz (zwei bis drei Sätze, ohne Vorlage) | Electron-Editor: | | | | | | | | | |
| 19 | | H10 Kurze englische Nachricht, Sprache automatisch | | | | | | | | | | |
| 20 | | H11 Deutscher Satz mit „Pull Request“ und „Code Review“ | | | | | | | | | | |

## Tagesnotizen (Nutzung außerhalb der 20 Aufgaben)

| Tag | Datum | Auffälligkeit (Dialog, falsches Ziel, Verzögerung, Recovery-Meldung) |
| --- | --- | --- |
| 1 | | |
| 2 | | |
| 3 | | |
| 4 | | |
| 5 | | |
| 6 | | |
| 7 | | |

## Auswertung gegen die Abnahme

- Von den 19 Aufgaben ohne H08 enden mindestens 18 mit „Auto: ja“ und
  „Ziel sichtbar: ja“; „Manueller Rückweg: ja“ zählt nicht dazu.
- H08 getrennt bewerten: möglicher Heuristik-Skip und bewusster
  Wiederholungsweg.
- Jede Runde enthält eine beendete freie Notiz (Nr. 4, 11, 18).
- Median von „Stopp → Text“ plus „Korrektur“ über die zwölf gemeinsamen
  Aufgaben (Nr. 1–4, 8–11, 15–18) höchstens 20 Sekunden; Einzelwerte bleiben
  sichtbar.
- „Weiter verwenden: ja“ und Einfachheit mindestens 4.
- Jeder Fehler bekommt Reproduktion, Schweregrad und die Entscheidung
  „beheben“ oder „als Grenze dokumentieren“. Datenverlust oder beschädigter
  vorhandener Text stoppt die Eigennutzung.
