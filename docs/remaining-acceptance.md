# Belegter Stand je Plattform

Stand: 8. Oktober 2026. Diese Datei hält je Plattform fest, was belegt ist,
was offen ist und wo der letzte Nachweis liegt. Die nächsten Schritte stehen
in der [ROADMAP](../ROADMAP.md), Produkt und Entscheidungen in
[PROJECT.md](../PROJECT.md), Prüfwege in [CHECKS.md](../CHECKS.md). Die
frühere chronologische Übergabedatei liegt unverändert im
[Archiv](archive/uebergabe-chronik-bis-2026-10-07.md); datierte Berichte
gelten nur für ihren damaligen Kandidaten ([Verzeichnis](archive/README.md)).

Seit dem 8. Oktober 2026 prüfen wir selbst nur noch den Weg, den jeder
Nutzer durchläuft (Installation und ein Diktat); Einzelfälle finden
Beta-Nutzer. Was hier „offen“ heißt, ist deshalb kein Testauftrag, sondern
eine bekannte Grenze, die in der jeweiligen Anleitung stehen muss.

## Linux

**Belegt** (omarchy, Hyprland, mit Bastis Go, 5. bis 7. Oktober 2026,
[Nachweise](linux-live-2026-10-05-bis-07.md)):

- Aufnahme, Keyring (API-Schlüssel und Aufnahmeschutz), Upload, Zwischenablage;
  Diktat ohne Übersetzung 2,3 s, mit Übersetzung nach Englisch 3,6 s.
- Übersetzung nach dem Sprechen (`settings target en`, Modell `gpt-5.4-mini`);
  falsches Modell behält die Aufnahme, `retry` übersetzt nach.
- Abbruch und Netzausfall während der Transkription: Aufnahme bleibt erhalten,
  `retry` liefert. Die seitdem kürzeren Zeitlimits (PR #51) sind nur offline
  geprüft.
- Physischer Hotkey Super+D; Leistenanzeige in der Omarchy-Leiste mit
  Klick-Umschalter der Zielsprache.
- Auto-Einfügen in das beim Start erfasste Fenster (Editor, Terminal), mit
  Fokus- und Zwischenablage-Prüfung; Fensterwechsel wird korrekt übersprungen.
- Offline: `scripts/ci/check-linux.sh` (Formatierung, Tests, Clippy,
  Release-Build) grün auf `main`.
- Täglicher Gebrauch durch Basti seit dem 7. Oktober.

**Offen / bekannte Grenzen:** Einfügen in Chromium-, Electron- und
Discord-Fenstern; gemischtes Deutsch/Englisch; Abbruch genau während der
Übersetzung; andere Compositoren als Hyprland; andere Distributionen;
Vokabular; konfigurierbarer Endpunkt. Das Arch-Paket
([PKGBUILD](../linux/packaging/arch/PKGBUILD)) ist seit dem 8. Oktober nur
offline geprüft (Paketfunktionen mit Rust 1.97 nachgestellt, Tests grün); die
Installation auf omarchy steht aus.
Eine alte Testaufnahme vom 5. Oktober liegt noch im Recovery-Ordner auf
omarchy; Löschen nur mit Bastis Go.

**Letzter Nachweis:** 7. Oktober 2026, installierter Stand `f3f0ef9`
([Live-Nachweise](linux-live-2026-10-05-bis-07.md)).

## macOS

**Belegt:**

- Stufe 1 (interne Funktionsabnahme) am 24. September 2026 für den
  dokumentierten Grundablauf auf Build 7 abgeschlossen: echtes Diktat mit
  physischem Kürzel in TextEdit, Feldmatrix in TextEdit, Safari, Brave,
  Obsidian, Terminal-Zeile ohne Return, negativer Appwechsel, Leerlaufmessung
  ([Plan-1-Bericht](release-plans/evidence/2026-09-24-plan1-fortsetzung.md)).
- Stufe 2: Build 8 aus `b786d4c` ist von Apple notarisiert, das finale ZIP mit
  Manifest geprüft (Signatur, Entitlement, Ticket, Gatekeeper mit Quarantäne,
  4,14 MiB, SHA-256 `2e994cd8…e335768`) und in der privaten Release-Draft
  `v0.1.0-beta.8` hinterlegt
  ([Nachweis](release-plans/evidence/2026-10-02-plan2-build8-final.md)).
  Nichts davon wurde installiert oder gestartet.
- Der signierte Schlüsselbundhelfer liest den API-Schlüssel nach einem
  Build-Wechsel ohne Dialog
  ([Nachweis](release-plans/evidence/2026-09-24-keychain-and-plan1.md)).
- Temporäre Aufnahmen tragen `0600`: Originalaufnahme etwa 0,1 s nach dem
  Anlegen, Upload-Datei von Anfang an; live geprüft am 7. Oktober auf einem
  Testbuild aus `cbddf7b` (PR #49). Ein nicht löschbarer abgelaufener Eintrag
  wird nur einmal pro Start geloggt (PR #50); die alte Aufnahme vom
  15. September ist nach Entfernen ihrer ACL gelöscht.
- Offline: Swift-Suite und Bundle-Build in CI auf macOS 14.

**Offen / bekannte Grenzen:**

- Stufe 2 Teil B: erster Start des entpackten Pakets mit Quarantäne,
  Migration nach der [Anleitung](release-plans/plan2-migration.md),
  Diktat- und Kopierweg, aktiver Beenden-/Recovery-Fall. Mit Bastis Go am Mac.
- Übersetzung fehlt auf dem Mac.
- Der ⌘V-Pfad bindet kein Feld: Cursor- oder Fokuswechsel nach dem Stopp
  können den Einfügeort innerhalb der ursprünglichen App verändern; er hat
  keinen Zeilenumbruchfilter. Terminal-Tabs, Markierung, Secure Input, iTerm2
  und Terminals in Editoren sind ungeprüft.
- Gerätewechsel, abgezogenes Mikrofon, Berechtigungs- und Keychainfehler,
  unterbrochenes Beenden während der Verarbeitung sind nicht praktisch geprüft.
- Gehörte VoiceOver-Ausgabe, frische Ersteinrichtung in einem neuen Konto,
  Intel-Macs.
- Kleine Punkte vom 7. Oktober: Originalaufnahme gleich geschützt anlegen,
  Grund einer nicht startenden Aufnahme ins App-Log, Tests schreiben ins echte
  App-Log, „ca.“ beim Preis des Mini-Modells im Menü.
- Der vorhandene API-Schlüssel liegt noch im alten Keychain-Account
  `OPENAI_API_KEY` mit Build-Hashes in der Zugriffsliste; er wird nur durch die
  App-Migration entfernt, nicht manuell.

**Letzter Nachweis:** 7. Oktober 2026 (Dateirechte, PR #49); Paketstand
2. Oktober 2026 (Build 8).

## Windows

**Belegt:** Der Quellsnapshot unter [windows/](../windows/README.md) stimmt
bytegleich mit der Arbeitskopie überein; 41 von 41 Offline-Prüfungen (23
Kern-/Ablaufprüfungen, 18 Schutzprüfungen) und App-/Browser-Host-Build
bestanden am 28. September 2026 auf dem Windows-PC
([Geräteprüfung](platform-audit-2026-09-28.md),
[Fortsetzung](platform-continuation-2026-09-28.md)). Der historische Prototyp
vom 12. September bestand Cursor-, Auswahl- und Abbruchfälle mit künstlichem
Text in Editor und Chrome-Testprofil ([Windows-Plan](windows-plan.md)).

**Offen / bekannte Grenzen:** Kein echtes Diktat, keine Provideranfrage;
Modell fest `gpt-transcribe`, keine Sprache, kein Prompt, keine Übersetzung;
keine reproduzierbare Paketierung, keine Signatur, kein Installer; Update- und
Deinstallationsweg; Pflichtprogramme nicht festgelegt.

**Letzter Nachweis:** 28. September 2026.

## iOS

**Belegt:** Der Offline-Tastatur-Prototyp aus `e416a3d` besteht Build,
Installation und den synthetischen Safari-Textpfad auf einem frischen
Simulator (29. September, [Nachweis](ios-keyboard-e2e-2026-09-29.md)) und auf
Bastis iPhone 15 mit iOS 27.0.1 (30. September, signiert gebaut, installiert,
Einfügen in beide Safari-Felder, Systemtastatur im Passwortfeld,
[Gerätenachweis](ios-device-2026-09-30.md)). Test-App deinstalliert; Draft-PR
#40 bleibt erhalten.

**Offen / bekannte Grenzen:** Echte Aufnahme und Transkription, Produktkonzept
(Aktionstaste, Host-App, Zwischenablage statt Vollzugriff-Tastatur),
Abbruch-/Unterbrechungsfälle, Dateischutz am Gerät, Verteilung über TestFlight,
Barrierefreiheit. Die ferngesteuerte Device-Hub-Steuerung bleibt blockiert;
Basti bedient das Gerät selbst.

**Letzter Nachweis:** 30. September 2026.

## Android

**Belegt:** Nichts. Kein Code, kein Plan, kein Konto.

**Offen:** Produktkonzept, Prototyp, Verteilungsweg ([ROADMAP](../ROADMAP.md#track-android)).

## Historische Evidenz

| Bericht | Aussage für seinen damaligen Kandidaten |
|---|---|
| [Linux-Spike 20. September](linux-spike-2026-09-20.md), [Phase-1-Kern 22. September](linux-phase1-core-2026-09-22.md) | Wegwahl auf omarchy/Hyprland und offline geprüfter Clipboard-Kern; kein Live-Upload |
| [Zielabnahme 17. September](target-acceptance-2026-09-17.md) | Echte Auswahlersetzung in TextEdit, Safari und Obsidian mit erzeugter Referenzsprache |
| [Roadmap 17. September](roadmap-acceptance-2026-09-17.md), [16. September](roadmap-acceptance-2026-09-16.md) | Brave-Langtext, Mikrofon-/Providerfälle, 90-Sekunden-Stopp, synthetische Feld-/Fokus-/Unicodeprüfungen |
| [Brave 15. September](brave-insertion-2026-09-15.md), [Native App 15. September](live-acceptance-2026-09-15.md), [Einstellungen](settings-acceptance-2026-09-15.md) | Synthetische Brave-Einfügung, menschliches Diktat, Bedienungs-/Fensterprüfungen |
| [22. September](live-acceptance-2026-09-22.md), [Terminal](terminal-focus-acceptance-2026-09-22.md), [autonom](autonomous-focus-acceptance-2026-09-22.md), [23. September](live-focus-acceptance-2026-09-23.md), [⌘V-Test](installed-command-v-2026-09-23.md) | Ältere Kandidaten vor dem ⌘V-Pfad und der erste negative Appwechsel |
| [13. September](live-acceptance-2026-09-13.md), [7. September](live-acceptance-2026-09-07.md) | Älteste Kandidaten; Hinweis, kein Test heutiger Builds |

Die vollständige Chronik bis zum 7. Oktober 2026 mit allen Zwischenständen
steht im [Archiv](archive/uebergabe-chronik-bis-2026-10-07.md).
