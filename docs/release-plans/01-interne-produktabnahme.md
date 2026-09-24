# Plan 1: Interne macOS-Funktionsabnahme

**Ergebnis am 24. September 2026: abgeschlossen für den vorhandenen Mac und die unten belegten Nutzungswege.** Das ist die interne Prüfung des einfachen Diktatablaufs, keine Freigabe zur Verteilung oder Veröffentlichung. Der [datierte Bericht](evidence/2026-09-24-plan1-fortsetzung.md) hält die einzelnen Nachweise und Grenzen fest.

## Ziel und belegter Umfang

OpenDictate lässt sich mit vorhandenem eigenem API-Schlüssel über das Kürzel starten und stoppen. Das Transkript erscheint im Ziel oder bleibt zum Kopieren verfügbar. Die App zeigt ihren Zustand und den Rückweg zum Text beziehungsweise zu einer erhaltenen Aufnahme verständlich. Der Normalweg bleibt ohne zusätzliches Fenster oder Bestätigung.

- Installierter Kandidat: OpenDictate 0.1.0 Build 7 aus `c92cbc98af06049708095411cb12a8f35f87bac6`, Apple Silicon, macOS 27.0. Signatur und Bundle wurden verifiziert. Der spätere Plan-1-Branch änderte den produktiven Diktier- und Einfügepfad nicht.
- Auf Build 7 bestand ein echter TextEdit-Lauf mit physischem ⌥⇧Leertaste, Mikrofon, OpenAI-Transkription und sichtbarer automatischer Einfügung. Der echte manuelle Kopierweg bestand ebenfalls. [Nachweis](evidence/2026-09-24-plan1-fortsetzung.md#physisches-kürzel-auf-build-7-textedit-bestanden).
- Fünf echte Diktate in TextEdit, Safari, Brave, Obsidian und einer nicht abgeschickten Terminal-Zeile bestanden auf dem älteren `bd3630f`. Ihre produktiven Aufnahme-, Transkriptions- und Einfügepfade blieben bis Build 7 unverändert. Diese fünf Läufe werden nicht als neue Build-7-Läufe bezeichnet. [Nachweis](evidence/2026-09-23-plan1-status.md).
- Die kontrollierte Feldmatrix deckt native Felder, zwölf Safari- und zwölf Brave-Positionen sowie Obsidian an Anfang, Mitte und bei Auswahlersetzung ab. Brave und Obsidian stimmen roh überein. Safari zeigt vollständigen kanonisch gleichen Text; der Browser normalisiert in diesen Fällen `e` plus Akzent zu `é`. Die frühere ausgebliebene Safari-Einfügung ist dokumentiert, die Ursache nicht bewiesen. [Einzelwerte](evidence/2026-09-24-plan1-fortsetzung.md).
## App-Design und UX

- Die gewählte ruhige Mockup-Richtung wurde umgesetzt. Panel, Einstellungen, Mindestgröße, Hell/Dunkel, Tastaturfokus, Hilfe und sichtbare Fehler-/Rückwege wurden am jeweils bezeichneten Build oder in der isolierten Vorschau geprüft. [Gestaltungsbefund](evidence/2026-09-23-plan1-status.md), [Build-7-Prüfung](evidence/2026-09-24-plan1-fortsetzung.md#reale-einstellungen-auf-build-7).
- Die installierte App blieb in der zehnminütigen Leerlaufprobe bei durchschnittlich 0,02833 % CPU und höchstens 81,40625 MiB Resident-Speicher. macOS-14- und macOS-15-CI-Prüfungen bestanden für den dokumentierten Quellstand. [Messung](evidence/2026-09-24-plan1-fortsetzung.md#zehn-minuten-leerlauf-bestanden).

Damit ist der interne Grundablauf auf dem vorhandenen Mac nachgewiesen. Die Matrix und die älteren fünf Läufe belegen jeweils nur ihre konkreten Felder und Kandidaten. Ein erfolgreicher ⌘V-Versand bestätigt nie allein, dass das Ziel den Text angenommen hat.

## Offene Grenzen mit festem nächsten Prüfpunkt

| Grenze | Nächster Prüfpunkt |
|---|---|
| Frische Ersteinrichtung in einem neuen macOS-Konto | Von Basti ausdrücklich als offene Grenze belassen. Keine Installation oder Kontenänderung für Plan 1. Die erste Einrichtung mit vorhandenen API-Schlüsseln wird im [begrenzten Betatest](03-begrenzter-betatest.md) beobachtet. |
| Absichtlich ausgelöster Provider- oder Recorderfehler und wirklich unterbrochenes Beenden während Verarbeitung | Vor externen Testern in [Plan 2](02-verteilbares-mac-paket.md) gezielt prüfen. Vorhandene Offline-Fehlerprüfungen ersetzen keinen behaupteten realen Fehlerlauf. Keine erhaltene fremde Aufnahme für einen Test löschen. |
| Gehörte VoiceOver-Ausgabe | Am endgültigen signierten Kandidaten in [Plan 4](04-release-kandidat.md) prüfen; dort ist die Hörprüfung bereits vorgesehen. |
| Exakte 0,5-Sekunden-Grenze für 20 lokale Fixture-Wechsel | Nicht als App-Latenz nachgewiesen: Video und Klickwerkzeug haben keinen gemeinsamen kalibrierten Eingabezeitpunkt. Die 20 sichtbaren Wechsel sind [belegt](evidence/2026-09-24-plan1-fortsetzung.md#zwanzig-sichtbare-zustandswechsel-zeitgrenze-noch-offen). Reaktionszeit als reale Bedienungsqualität im [Betatest](03-begrenzter-betatest.md) erfassen; keinen weiteren Pflichtlauf mit derselben ungeeigneten Messmethode. |
| Safari-Rohfolge und früherer nicht eingefügter Testtext | Kanonisch gleicher sichtbarer Text zählt hier als vollständige Übertragung. Die Rohabweichung und die nicht geklärte frühere Auslassung bleiben dokumentiert. Wiederauftreten am verteilten Kandidaten wird vor Weitergabe untersucht. |
| Interaktive macOS-14-Abnahme | CI belegt Offline-Tests und Bundle-Bau, keine Benutzung auf macOS 14. Diese Grenze bleibt in Paket- und Freigabeprotokoll sichtbar. |

Datenverlust, beschädigter vorhandener Text oder falsche Ziel-App wären weiter Blocker, sobald sie beobachtet werden. Der manuelle Zwischenablageweg und die geschützte Wiederholung bleiben Teil des Produkts. Die offenen Punkte sind keine Zusage, dass diese Fälle bereits bestanden haben.

**Übergabe an [Plan 2](02-verteilbares-mac-paket.md):** datierter interner Bericht, exakte Kandidaten, offene Grenzen und ein belegter Grundablauf. Plan 2 sichert die Fehler- und Beenden-Pfade, bevor ein Paket an andere Personen geht.
