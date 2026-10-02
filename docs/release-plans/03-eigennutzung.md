# Plan 3: Eigennutzung

**Ziel:** Basti nutzt den notarisierten Build aus
[Plan 2](02-verteilbares-mac-paket.md) sieben Tage lang täglich im Alltag und
erledigt dabei 20 kurze, unempfindliche Diktataufgaben nach dem
[Messbogen](plan3-messbogen.md). Das Ergebnis ist eine priorisierte
Befundliste und messbare Einzelwerte zu Einfügen, Zeit und Korrekturaufwand,
keine allgemeine Erfolgsquote für alle Macs oder Textfelder. Geprüft wird die
**umgesetzte App** einschließlich des
[App-Designs und der UX aus Plan 1](01-interne-produktabnahme.md#app-design-und-ux).
Gehörtes VoiceOver bleibt ein Prüfpunkt des Release-Kandidaten in Plan 4.

Entscheidung vom 2. Oktober 2026: Es gibt keinen Betatest mit fremden Testern
vor dem öffentlichen Release. Fremde Nutzer testen erst in
[Stufe 6](../../ROADMAP.md) über GitHub Issues, nach dem öffentlichen
Beta-Release in [Plan 5](05-oeffentlicher-release.md).

**Voraussetzung:** Plan 2 einschließlich Teil B ist bestanden: Migration auf
das finale Paket, Start aus `~/Applications`, vollständiger Diktat- und
Kopierweg und aktiver Beenden-/Recovery-Fall. Basti verwendet seinen eigenen
OpenAI-Schlüssel; Audio und Schlüssel verlassen den Mac nur in Richtung
OpenAI. Live-Nutzung folgt der Go-Regel in
[AGENTS.md](../../AGENTS.md#required-verification).

## Arbeit

1. Einmalig macOS, Mac-Modell, Build, Modell, Sprache und Mikrofon im
   Messbogen festhalten.
2. Die 20 Aufgaben auf drei Runden an verschiedenen Tagen verteilen. Jede
   Runde enthält die vier gemeinsamen Fälle H01 (kurze Nachricht), H02
   (Einfügen in einen bestehenden Satz), H03 (markierte Passage ersetzen) und
   H12 (freie Notiz), jeweils in einer anderen Zielkategorie: natives Feld,
   Browserfeld, Electron-Editor. Die acht Fälle H04 bis H11 aus der
   [Pilotliste](../audio-quality-fixtures.md#prepared-first-human-pilot)
   werden je einmal auf die Runden verteilt. Fehlgeschlagene Versuche zählen
   mit und werden nicht still ersetzt.
3. Für jede Aufgabe getrennt erfassen: Start- und Stoppzeit, Zeit vom Stopp bis
   zum Text, Korrekturzeit, ob das Ziel sichtbar war, **automatische
   Einfügung getrennt vom manuellen Rückweg** und die Ursache einer Störung.
   Fehlende Messungen bleiben leer und werden nicht zu Nullwerten.
4. Außerhalb der 20 Aufgaben die App an allen sieben Tagen normal nutzen und
   Auffälligkeiten mit Datum notieren: unerwartete Fenster oder Dialoge,
   falsches Ziel, Verzögerungen, Recovery-Meldungen. Am Ende festhalten, ob
   die Hauptaktion und die Statusanzeige ohne Nachdenken funktionieren und was
   der größte Reibungspunkt war.
5. Jeden Befund gegen den genauen Build reproduzieren. Fehler mit Verlust der
   einzigen Aufnahme, Beschädigung bestehenden Textes oder unerwarteter
   Weitergabe haben Vorrang. Korrekturen erzeugen einen neuen Kandidaten und
   gezielte Wiederholungen; alte Messwerte werden nicht auf ihn übertragen.

## Abnahme

- Sieben Nutzungstage und 20 gezählte Aufgaben liegen vor. H08 ist die
  bewusst leise gesprochene Sonderprobe: ein möglicher Heuristik-Skip und,
  falls er eintritt, der bewusste Wiederholungsweg werden getrennt bewertet.
  Von den übrigen 19 Aufgaben enden mindestens 18 sichtbar automatisch im
  erwarteten Feld; ein manueller Kopierweg zählt nicht dazu. Jede der drei
  Runden enthält eine beendete freie Notiz.
- Bei den zwölf gemeinsamen Aufgaben sind nach der Einrichtung keine
  zusätzlichen Fenster oder Bestätigungen für einen normalen Erfolg nötig.
  Der Median von Stopp bis nutzbarem Text einschließlich Korrektur liegt bei
  höchstens 20 Sekunden. Das ist ein festes Ziel, kein bereits gemessener
  Istwert.
- Basti würde OpenDictate für diese Aufgaben weiter verwenden und bewertet die
  Einfachheit mit mindestens 4 von 5 Punkten. Das ist ein Eigensignal, keine
  Marktvalidierung.
- Die Ersteinrichtung ohne Hilfe auf einem fremden Mac ist hier nicht
  messbar; sie wird im öffentlichen Betatest (Stufe 6) beobachtet.

**Abbruch:** Ein ungeklärter Fehler mit Datenverlust oder beschädigtem
vorhandenem Text stoppt die Eigennutzung, bis die Ursache geklärt ist. Jeder
andere Fehler bekommt Reproduktion, Schweregrad und eine Entscheidung:
beheben oder als konkrete unterstützte Grenze dokumentieren.

**Freigabegrenze:** Keine Weitergabe des Pakets und keine Veröffentlichung.
Der ausgefüllte Messbogen mit Testtexten bleibt privat und kommt nicht ins
Repository; ins Repository gehen nur die ausgewerteten Zahlen und Befunde.

**Übergabe an [Plan 4](04-release-kandidat.md):** Ausgewerteter Messbogen,
Befundliste mit Entscheidungen und die Revision jedes geprüften Kandidaten.
