# Plan 3: Begrenzter Betatest mit echten Nutzern

**Ziel:** Drei einwilligende Personen außerhalb der Entwicklung installieren
denselben privaten, notarisierten Mac-Build und bearbeiten zusammen 20 kurze,
unempfindliche Diktataufgaben. Der Test liefert eine priorisierte Fehlerliste
und messbare Aussagen zur Einrichtung und zum Nutzen, keine allgemeine
Erfolgsquote für alle Macs oder Textfelder. Er überprüft ausdrücklich das
[App-Design und die UX aus Plan 1](01-interne-produktabnahme.md#app-design-und-ux).
Getestet wird die **umgesetzte App**, nicht ein Mockup. Die Mockup-Feedbackrunde und die interne visuelle und Tastaturprüfung aus
Plan 1 sind abgeschlossen, bevor Tester eingeladen werden. Gehörtes VoiceOver
bleibt ein Prüfpunkt des endgültigen Release-Kandidaten in Plan 4.

**Voraussetzung:** Das Paket aus [Plan 2](02-verteilbares-mac-paket.md) ist
geprüft. Vor Einladung werden Empfänger, Paketlink, höchstens 20
Provider-Anfragen und der Umfang der Audioübertragung konkret freigegeben.
Tester verwenden eigene OpenAI-Schlüssel; keine Schlüssel oder privaten
Aufnahmen werden an das Projektteam geschickt. Der Pilot richtet sich an
Personen mit **bereits vorhandenem** API-Schlüssel. Die Zeit zur Erstellung
eines OpenAI-Kontos oder zum Einrichten seiner Abrechnung wird nicht als
App-Einrichtungszeit ausgegeben.

## Arbeit

1. Pro Tester Version, macOS, Mac-Modell, Ziel-App, Sprache und Mikrofon
   erfassen. Die drei Tester installieren ohne Entwicklerhilfe anhand der
   Anleitung; Hilfebedarf, Berechtigungsdialoge und Zeit vom ersten Start bis
   zum ersten nutzbaren Text werden protokolliert. Der eigene API-Schlüssel
   liegt dafür bei jedem Tester schon bereit. In der Gruppe müssen ein
   natives Feld, ein Browserfeld und ein Electron-Editor als normale
   Zielkategorien vorkommen; die Tester werden passend dazu ausgewählt.
2. Jeder Tester erledigt vier gemeinsame Fälle: kurze Nachricht, Einfügen
   in einen bestehenden Satz, Ersetzen einer markierten Passage und freie
   Notiz. Die acht weiteren Fälle H04 bis H11 aus der
   [vorbereiteten Pilotliste](../audio-quality-fixtures.md#prepared-first-human-pilot)
   werden je einmal unter den drei Testern verteilt. Das ergibt 20 Aufgaben;
   fehlgeschlagene Versuche zählen mit und werden nicht still ersetzt.
3. Für jede Aufgabe Start-/Stopzeit, Zeit bis nutzbarer Text, Korrekturzeit,
   sichtbares Ziel, **automatische Einfügung getrennt vom manuellen Rückweg**
   und Ursache einer Störung erfassen.
   Referenztext und Ergebnis nur mit Einwilligung erfassen; Audio und
   Schlüssel bleiben bei den Testern. Fragen: War die Einrichtung ohne Hilfe
   möglich? War die App im Alltag angenehm unauffällig? Würde die Person die
   App für solche Texte wieder verwenden? Jede Person nennt den größten
   Reibungspunkt, auch wenn alle Diktate funktionieren. Prüfen, ob die in den
   Mockups geplante Hauptaktion und Statusanzeige ohne Erklärung verstanden
   werden; Abweichungen als UX-Befund festhalten.
4. Jeden Befund gegen den genauen Build reproduzieren. Fehler mit Verlust der
   einzigen Aufnahme, Beschädigung bestehenden Textes oder unerwarteter
   Weitergabe haben Vorrang. Korrekturen erzeugen einen neuen Kandidaten und
   gezielte Wiederholungen; alte Testergebnisse werden nicht auf ihn übertragen.

## Abnahme

- Drei dokumentierte Installationen und 20 gezählte Aufgaben liegen vor.
  H08 ist die bewusst leise gesprochene Sonderprobe: ein möglicher
  Heuristik-Skip und, falls er eintritt, der bewusste Wiederholungsweg werden
  getrennt bewertet.
  Von den übrigen 19 normalen Aufgaben müssen mindestens 18 sichtbar
  automatisch im erwarteten Feld enden. Ein manueller Kopierweg zählt nicht
  zu diesen 18. Alle drei Personen beenden mindestens eine freie Notiz;
  fehlt ein Tester, ist der Plan nicht bestanden.
- Alle drei Personen erreichen mit bereitliegendem API-Schlüssel in höchstens
  fünf Minuten ab erstem Start einen nutzbaren Text ohne Entwicklerhilfe.
  Bei den vier gemeinsamen Aufgaben sind nach der Einrichtung keine
  zusätzlichen Fenster oder Bestätigungen für einen normalen Erfolg nötig.
- Kein ungeklärter Fehler mit Datenverlust oder beschädigtem vorhandenem Text.
  Jeder andere Fehler hat Reproduktion, Schweregrad und eine Entscheidung:
  beheben oder als konkrete unterstützte Grenze dokumentieren.
- Zeiten und Korrekturen sind als Einzelwerte dokumentiert; fehlende Messungen
  werden nicht zu Nullwerten gemacht. Für die zwölf gemeinsamen Aufgaben
  liegt der Median von Stopp bis nutzbarem Text einschließlich Korrektur bei
  höchstens 20 Sekunden. Das ist ein festes Pilotziel, kein bereits gemessener
  Istwert. Mindestens zwei der drei Tester würden OpenDictate für die
  getesteten Aufgaben erneut verwenden **und** bewerten
  die Einfachheit mit mindestens 4 von 5 Punkten. Das ist ein kleines
  Akzeptanzsignal, keine Marktvalidierung.

**Freigabegrenze:** Einladung und Paketversand an andere Personen sowie
deren Live-Mikrofon-/OpenAI-Nutzung erfolgen erst nach konkreter Zustimmung.
Es gibt keine automatische Wiederholung und keine Veröffentlichung des
privaten Pilotberichts.

**Übergabe an [Plan 4](04-release-kandidat.md):** Zählbarer Pilotbericht,
Fehlerliste, Entscheidungen und die Revision jedes geprüften Kandidaten.
