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
- Arch-Paket ([PKGBUILD](../linux/packaging/arch/PKGBUILD)) am 8. Oktober auf
  omarchy gebaut (46 Tests grün), von Basti mit `pacman -U` installiert, Super+D
  und Leiste darauf umgestellt, ein Diktat mit Übersetzung in einen Editor
  eingefügt.
- Zweisprachiges Paket aus PR #59 (`0a04ed5`) am 8. Oktober auf omarchy gebaut
  (49 Tests grün) und installiert; omarchy steht auf `en_US`, Hilfe auf
  Englisch; ein Diktat mit Übersetzung in die Claude-App eingefügt.

**Offen / bekannte Grenzen:** Ein Start direkt nach der Neuinstallation
scheiterte einmal mit „Recording could not start“ (Ursache unbekannt, der
nächste Versuch klappte); seit PR #59 steht der Grund im Protokoll
(`recording-start-failed`), und die leere Datei wird entfernt. Einfügen in Chromium-, Electron- und
Discord-Fenstern; gemischtes Deutsch/Englisch; Abbruch genau während der
Übersetzung; andere Compositoren als Hyprland; andere Distributionen;
Vokabular; konfigurierbarer Endpunkt. Für das Arch-Paket ungeprüft: `namcap`, Bau mit pacman-Rust und `makepkg -si`,
frische Ersteinrichtung des Schlüssels.
Eine alte Testaufnahme vom 7. Oktober liegt noch im Recovery-Ordner auf
omarchy; Löschen nur mit Bastis Go. Die leere Datei vom gescheiterten Start
wurde am 8. Oktober mit Bastis Go gelöscht.

**Letzter Nachweis:** 8. Oktober 2026, Arch-Paket aus `0a04ed5` (PR #59)
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
- Stufe 2 Teil B (8. Oktober 2026, mit Bastis Go): Build 8 in
  `/Applications` installiert, erster Start mit Quarantäne, neuer
  Schlüsselbundhelfer bytegleich mit dem Paket, zwei erwartete
  Schlüsselbund-Abfragen, ein Diktat mit automatischem Einfügen in TextEdit
  ([Nachweis](release-plans/evidence/2026-10-08-plan2-teil-b.md)). Nach dem
  Signaturwechsel musste der Bedienungshilfen-Eintrag entfernt und neu
  hinzugefügt werden.
- Der signierte Schlüsselbundhelfer liest den API-Schlüssel nach einem
  Build-Wechsel ohne Dialog
  ([Nachweis](release-plans/evidence/2026-09-24-keychain-and-plan1.md)).
- Temporäre Aufnahmen tragen `0600`: Originalaufnahme etwa 0,1 s nach dem
  Anlegen, Upload-Datei von Anfang an; live geprüft am 7. Oktober auf einem
  Testbuild aus `cbddf7b` (PR #49). Ein nicht löschbarer abgelaufener Eintrag
  wird nur einmal pro Start geloggt (PR #50); die alte Aufnahme vom
  15. September ist nach Entfernen ihrer ACL gelöscht.
- Offline: Swift-Suite und Bundle-Build in CI auf macOS 14.
- Übersetzung nach dem Sprechen ist im Code (Menü und Einstellungen
  „Übersetzen“, Modell `gpt-5.4-mini`, gleiche Regeln wie auf Linux) und
  offline geprüft: Ablauftests für Übersetzen, Fehler und leere Antwort
  (Aufnahme bleibt, kein Rückfall auf den Originaltext), Wiederholen mit
  Übersetzung, Anfrageaufbau ohne Netz. Die kleinen Punkte vom 7. Oktober sind
  ebenfalls umgesetzt: Originalaufnahme wird mit `0600` angelegt (lokal mit
  `AVAudioRecorder.prepareToRecord` geprüft), Grund einer nicht startenden
  Aufnahme im App-Log, Tests schreiben in eine temporäre Logdatei (Zeilenzahl
  des echten Logs vor und nach `swift test` gleich), „ca.“ beim Preis des
  Mini-Modells.

**Offen / bekannte Grenzen:**

- Beenden der App während der Transkription: nur ohne Netz geprüft. Live
  antwortete OpenAI in zwei Versuchen am 8. Oktober nach gut 3 s, bevor die
  Abfrage bestätigt war. Bekannte Grenze der Beta (Entscheidung Basti).
- „Text ansehen“ und „Text kopieren“ wurden in Teil B nicht eigens geprüft.
- Übersetzung und die Punkte vom 7. Oktober: noch kein echtes Diktat auf dem
  Mac; das prüft der nächste Kandidat (Installation und ein Diktat mit
  Übersetzung).
- Der ⌘V-Pfad bindet kein Feld: Cursor- oder Fokuswechsel nach dem Stopp
  können den Einfügeort innerhalb der ursprünglichen App verändern; er hat
  keinen Zeilenumbruchfilter. Terminal-Tabs, Markierung, Secure Input, iTerm2
  und Terminals in Editoren sind ungeprüft.
- Gerätewechsel, abgezogenes Mikrofon, Berechtigungs- und Keychainfehler,
  unterbrochenes Beenden während der Verarbeitung sind nicht praktisch geprüft.
- Gehörte VoiceOver-Ausgabe, frische Ersteinrichtung in einem neuen Konto,
  Intel-Macs.
- Der vorhandene API-Schlüssel liegt noch im alten Keychain-Account
  `OPENAI_API_KEY` mit Build-Hashes in der Zugriffsliste; er wird nur durch die
  App-Migration entfernt, nicht manuell.

**Letzter Nachweis:** 8. Oktober 2026 (Teil B, Build 8).

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
