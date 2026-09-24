# Plan 1: Interne macOS-Produktabnahme

**Ziel:** Für die erste öffentliche Mac-Version liegt ein datierter Abnahmebericht
zum exakt identifizierten Quellstand und installierten Build vor. Der vorgeschlagene
Release-Umfang ist Apple Silicon mit macOS 14 oder neuer. Intel-Macs, Linux,
Windows, Streaming und Hold-to-talk sind kein Teil dieser Abnahme. Diese
Umfangsentscheidung wird vor Beginn der Release-Arbeit bestätigt und anschließend
in `PROJECT.md` und `README.md` einheitlich beschrieben.

**Startpunkt:** Basti meldete am 23. September 2026, dass die wiederhergestellte
Einfügefunktion in seinem Test funktioniert. Spätere
[Live-Tests](evidence/2026-09-23-plan1-status.md) belegten fünf konkrete
Zielprogramme für den damaligen Build `bd3630f`. Der aktuell installierte
Build 7 fügte in einem [Knopf-Lauf](evidence/2026-09-24-keychain-and-plan1.md#build-7-echter-textedit-einfügeweg)
sichtbar Text in TextEdit ein. Diese Teilnachweise schließen Plan 1 nicht ab;
ältere Kandidatenberichte gelten nicht automatisch für den jetzigen Build.

## App-Design und UX

Dieses Kapitel verantwortet das Produktgefühl **vor** dem Betatest. Ziel ist
eine ruhige Menüleisten-App, deren normaler Ablauf nach der einmaligen
Einrichtung mit zwei Betätigungen desselben Kürzels auskommt: starten und
stoppen. Sie öffnet dabei kein Fenster von selbst und verlangt keine weitere
Bestätigung. Der Status zeigt Aufnahme, Verarbeitung und Ergebnis klar an;
Text oder erhaltene Aufnahme bleiben bei einem Fehler erreichbar.

**Mockup-Zeitpunkt:** Zu Beginn von Plan 1 zuerst die vorhandene App in ihren
wichtigen Zuständen aufnehmen und ihre konkreten Reibungspunkte notieren.
**Vor jeder UI-Codeänderung** daraus drei kompakte Mockup-Gruppen erstellen:

1. Menüleiste: bereit, Aufnahme und Verarbeitung.
2. Ergebnis-Panel: fertiger Text, Kopieren und Wiederholung einer erhaltenen
   Aufnahme.
3. Einrichtung und Fehler: eigener API-Schlüssel, Berechtigungen und ein
   verständlicher Rückweg bei fehlgeschlagener Transkription oder Einfügung.

Jede Gruppe zeigt den aktuellen Zustand neben dem vorgeschlagenen Entwurf,
jeweils mit klarer Hauptaktion und den notwendigen Nebenaktionen. Die
Mockups sind **Entwürfe**, kein Funktionsnachweis. Sie werden Basti in einer
gemeinsamen Feedbackrunde gezeigt; die gewählte Richtung und konkrete
Änderungen werden festgehalten. Erst danach werden nötige UI-Anpassungen
umgesetzt und am laufenden Build beurteilt.

- Menüleiste und Panel am tatsächlich laufenden Build prüfen: eine eindeutige
  Hauptaktion und ein klarer Status; Einstellungen, Wiederholung und weitere
  Aktionen bleiben auffindbar, ohne den Normalweg zu füllen. Keine zusätzliche
  Funktion nur für dekorative Wirkung einführen.
- Einen gezielten Gestaltungsdurchgang für Typografie, Abstände, Symbolik,
  Beschriftungen und die Übergänge zwischen Bereit, Aufnahme, Verarbeitung,
  Ergebnis und Fehler durchführen. Überflüssige Wörter und doppelte Aktionen
  entfernen. Änderungen an Screenshots des tatsächlichen Builds beurteilen;
  die Hauptaktion muss in jedem Zustand auf Anhieb erkennbar sein.
- Das Panel bei kleinster unterstützter Größe sowie in hellem und dunklem
  Erscheinungsbild ansehen. Texte, Fokusmarkierung und Bedienelemente müssen
  lesbar und eindeutig sein. Tastaturbedienung und gehörte VoiceOver-Ausgabe
  werden mitgeprüft.
- Die Einrichtung beginnt mit einem **bereits vorhandenen eigenen
  OpenAI-API-Schlüssel**. Der Dialog erklärt dessen Eingabe, Berechtigungen und
  Kosten ohne zusätzlichen OpenDictate-Account. Erwerb und Abrechnung eines
  OpenAI-Kontos sind kein Teil dieser App-Abnahme.
- Jede normale Aktion und jeder Fehlerzustand bekommt eine sichtbare,
  verständliche Rückmeldung. Ein Fehler nennt einen konkreten nächsten Schritt;
  technische Details bleiben in der Hilfe. Die automatische Einfügung wird
  weiterhin als unbestätigt bezeichnet, weil ⌘V keinen Erfolg zurückmeldet.

Plan 3 prüft diese Kriterien bei echten Nutzern; Plan 4 prüft die endgültige
Gestaltung am signierten Release-Kandidaten erneut. Die Zahlen für
Reaktionszeit und Leerlaufverbrauch sind Ziele für diesen Release. Eine
zehnminütige Leerlaufmessung bestand bereits auf dem früheren Build 4; die
Reaktionszeit der lokalen Zustandswechsel und der Leerlauf des aktuellen
Build 7 sind dadurch nicht belegt.

## Arbeit

1. Quellrevision, Buildnummer, Signatur, macOS-Version, Zielprogramm und
   Berechtigungszustand für jede Prüfung festhalten. Die Quellenchecks aus
   [CHECKS.md](../../CHECKS.md) auf diesem Stand ausführen.
2. Die Produktionslogik mit den vorhandenen Offline-Fixtures in nativen ein-
   und mehrzeiligen Feldern, Safari und Brave (`input`, `textarea`,
   `contenteditable`, editierbares `iframe`) sowie Obsidian prüfen. Je Kategorie
   Anfang, Mitte, Auswahlersetzung und mehrzeiligen Unicode prüfen; den
   tatsächlichen sichtbaren Zieltext mit der Vorlage vergleichen.
3. Auf dem installierten Build fünf kurze echte End-to-End-Diktate mit physischem
   Kürzel, Mikrofon und Provider prüfen: TextEdit, Safari-`textarea`,
   Brave-`contenteditable`, Obsidian-Editor und eine harmlose einzelne
   Terminal-Zeile. Im Terminal weder Return drücken noch Befehle diktieren.
   Fokuswechsel innerhalb derselben App und in eine andere App gesondert mit
   künstlichem Text prüfen. Das bereits entschiedene Verhalten ist die
   Reaktivierung der Start-App und Paste in deren dann fokussiertes Feld,
   ohne Bindung an das ursprüngliche Feld. Bei einem Wechsel in ein anderes
   Feld derselben App dort den Zieltext prüfen; bei einem Appwechsel die
   Rückkehr zur Start-App prüfen. Das Verhalten wird hier abgenommen, nicht
   erneut als Produktentscheidung behandelt.
4. Auf dem vorhandenen Apple-Silicon-Mac Einrichtung in einem kontrolliert
   frischen lokalen Benutzerzustand mit eigenem Testschlüssel, Mikrofon- und
   Bedienungshilfen-Dialog sowie den manuellen Zwischenablageweg prüfen.
   Die macOS-14-Kompatibilität separat durch native CI-Tests und einen
   verifizierten Bundle-Build prüfen; daraus keine interaktive Abnahme auf
   macOS 14 ableiten. Drei zusätzliche kurze reale Aufnahmen decken
   Abbruch während Aufnahme, Providerfehler und Beenden während Verarbeitung
   ab. Dateizustand und Wiederholung vor und nach dem Fall prüfen. Einen
   Geräteausfall ohne verfügbares externes Testgerät über einen kontrollierten
   Recorder-Fehler prüfen; physisches Abziehen wird nicht als bestanden behauptet.
5. Nach der Mockup-Feedbackrunde die gewählten UI-Anpassungen umsetzen und
   das Kapitel **App-Design und UX** am installierten Build visuell und mit
   Tastatur prüfen. Die wichtigsten Zustände mit VoiceOver **anhören**,
   inklusive Aufnahme, Verarbeitung, Fehler, Ergebnis und Einstellung. Nach
   jedem Lauf eigene
   Dokumente, Aufnahmen und Fenster bereinigen, ohne unklare Nutzerdaten zu
   löschen.
6. Im kontrollierten Offline-Pfad zehn Aufnahme-/Stopp-Paare über dessen
   Bedienelement auslösen und die Zeit bis zur sichtbaren Zustandsänderung
   messen. Diese Fixture registriert **kein** globales Kürzel; die fünf echten
   Diktate aus Schritt 3 prüfen das physische Kürzel gesondert. Ziel sind bei
   allen 20 lokalen Zustandswechseln höchstens 0,5 Sekunden. Messbeginn ist
   die Aktion im Fixture-Fenster, Messende die sichtbare Statusänderung;
   eine Bildschirmaufnahme mit Zeitstempel liefert den Nachweis. Die spätere
   Provider-Antwort zählt nicht mit.
7. Nach dem Start zehn Minuten ohne Bedienung CPU und Speicher der laufenden
   App mit dem vorhandenen Prozess-Sampler im Sekundenabstand messen. Ziel:
   mittlere Prozess-CPU unter 1 Prozent und maximaler Resident-Speicher
   unter 100 MiB auf dem geprüften
   Apple-Silicon-Mac. Eine Überschreitung ist vor Freigabe zu untersuchen.

## Abnahme

- Die genannten normalen editierbaren Feldkategorien haben einen sichtbaren
  Soll/Ist-Nachweis für Paste und Auswahlersetzung; Terminal hat nur den
  Einzelzeilen-Nachweis ohne Auswahlersetzung. Bei allen fünf stabil
  fokussierten echten Diktaten erscheint der Text automatisch und vollständig
  im erwarteten Feld. Ein bloß kopierbarer Text zählt hier **nicht** als
  bestandene automatische Einfügung. Abweichungen werden korrigiert und auf
  demselben Kandidaten erneut geprüft.
- In ausdrücklich provozierten Fehler- und Fokusfällen wird gesondert
  geprüft, ob der vollständige Text kopierbar bleibt. Bei Feldwechseln gilt
  das oben beschriebene ⌘V-Verhalten; Terminal-Zeilenumbrüche und
  Passwortfelder werden als Fälle für bewusst manuelles Einfügen erklärt,
  ohne die wiederhergestellte allgemeine Einfügelogik still zu ändern.
- In den drei Störfällen geht weder die einzige Aufnahme noch ein bereits
  erzeugtes vollständiges Transkript verloren. Keine Prüfung beschädigt
  vorhandenen fremden Text.
- macOS 14 hat einen nativen CI-Nachweis für Offline-Tests und Bundle-Build.
  Die interaktive Diktat- und VoiceOver-Abnahme erfolgt auf dem vorhandenen
  Mac; der Bericht nennt dessen macOS-Version und die fehlende interaktive
  macOS-14-Prüfung ausdrücklich. Er nennt auch die bewusst nicht unterstützten
  Situationen, insbesondere Terminal mit Zeilenumbrüchen und Feldwechsel
  während der Verarbeitung.
- Der normale Erfolgspfad braucht nach der Einrichtung keine Fensteröffnung,
  keinen weiteren Klick und keine Bestätigung. Die 20 lokalen
  **Fixture-Zustandswechsel** erfüllen das 0,5-Sekunden-Ziel; die fünf
  echten Läufe bestätigen zusätzlich das physische Kürzel. Die sichtbare
  Gestaltung erfüllt das Kapitel **App-Design und UX**. Fehlermeldungen
  nennen eine verständliche Handlung und lassen den Rückweg zum Text oder
  Audio sichtbar.
- Die drei Mockup-Gruppen, Bastis Feedback und die gewählte Richtung sind vor
  UI-Codeänderungen dokumentiert. Der sichtbare Build wird mit dieser
  Richtung verglichen; Abweichungen haben eine kurze Begründung.
- Die zehnminütige Leerlaufmessung erfüllt die genannten CPU- und
  Speichergrenzen. Das ist ein Ziel für den geprüften Mac, keine Zusage für
  jede Hardware und jede Betriebssystemversion.
- Der Abnahmebericht trennt echte Diktate, synthetische Fixtures und Bastis
  Rückmeldung. Jeder später geänderte Einfüge- oder Recovery-Pfad bekommt
  erneut die betroffenen Prüfungen.

**Live-Freigabe:** Basti hat nach Verbrauch des ersten Testblocks die
Fortsetzung der Plan-1-Abnahme ohne feste Kontingentgrenze ausdrücklich
freigegeben; siehe [APPROVALS.md](../../APPROVALS.md). Weiterhin keine
automatische Wiederholung.

**Übergabe an [Plan 2](02-verteilbares-mac-paket.md):** Datierter Bericht,
Quellrevision, offene Grenzen und keine ungeklärten Fehler mit Text- oder
Aufnahmeverlust.
