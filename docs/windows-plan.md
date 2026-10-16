# Windows-Plan: portable Zusammenfassung

Diese Kurzfassung stammt aus den externen, lesend geprüften Notizen
`OpenDictate-Windows-Plan.md` und `OpenDictate-Windows-Umsetzungsstand.md`,
Stand **12. September 2026**. Die Originale bleiben außerhalb dieses
Repositories. Den damals separaten Quellbaum hält der
[Projekt-Audit](project-audit-2026-09-28.md) in seinem historischen
Repository-Abstand fest. Der aktuelle Snapshot steht unter
[windows/](../windows/README.md). Diese historische Quelle ist keine heutige Geräteabnahme oder
Freigabe.

Die [ROADMAP](../ROADMAP.md) ist die zentrale Plattform-To-do-Liste. Dieses
Dokument bewahrt Windows-Planungsdetails und trennt neue Entscheidungen
vom klar begrenzten historischen Prüfstand.

## Weg zur Windows-Beta (Stand 11. Oktober 2026)

Basti hat am 11. Oktober entschieden: Windows läuft ab jetzt parallel weiter,
die nächste Beta ist iOS, danach Windows ([Log](../PROJECT.md#entscheidungen)).
Alles, was ohne Windows-Gerät geht, wird jetzt gebaut und auf Linux sowie im
Windows-Job der CI offline geprüft; die Live-Abnahme kommt am Ende.

| Schritt | Ohne Windows-Gerät | Stand |
| --- | --- | --- |
| 1. Modell, Sprache, Übersetzung und eigener Server aus den Einstellungen, Tests gegen `fixtures/provider/` | ja | Gebaut am 11. Oktober, offline geprüft (Projekt `OpenDictate.Provider`); seit 16. Oktober Auswahl „Dienst“ (OpenAI oder eigener Server, Adresse bleibt, eigene Modelle je Seite), 19 Provider-Prüfungen |
| 2. Beta-App statt Prüffenster: Symbol im Infobereich, Einstellungsfenster (Schlüssel, Sprache, Übersetzung, eigener Server, Kürzel), Texte Deutsch oder Englisch nach Systemsprache, kleine Diktatanzeige im Designsystem | ja (Bau und Offline-Prüfung) | Gebaut am 11. Oktober als `OpenDictate.App` ([README](../windows/README.md#beta-app-11-oktober-2026)), offline geprüft; seit 16. Oktober auf xmg gestartet, Einstellungen und Infobereich geprüft |
| 3. Kürzel: Strg+Win, rechte Strg für Spiele, je gedrückt halten oder antippen (einmal starten, einmal stoppen), Abfrage beim ersten Start; Wechsel transaktional | ja (Logik), live nein | Gebaut am 11. Oktober; am 16. Oktober von Basti auf xmg mit beiden Kürzeln (Halten) abgenommen; Auswahl „Gedrückt halten“ oder „Antippen“ am 16. Oktober gebaut, 22 Offline-Prüfungen, auf xmg Einstellungen geprüft, Antippen am 16. Oktober von Basti in Notepad abgenommen; Spiele offen |
| 4. Einfügen über Zwischenablage und Strg+V in das beim Start erfasste Fenster, nur wenn es noch vorne ist und die Zwischenablage noch den Text hält; sonst bleibt der Text in der Zwischenablage. Der frühere Weg über Editor-Felder und Browser-Erweiterung reichte für Spielchat und beliebige Programme nicht und wurde am 13. Oktober entfernt | ja (Logik), live nein | Gebaut am 11. Oktober, Regel offline geprüft; am 16. Oktober auf xmg in Notepad eingefügt; Spielchat bleibt bekannte Grenze (Beta-Nutzer) |
| 5. Paket: `dotnet publish` für win-x64 mit mitgelieferter Laufzeit, Installation ohne Adminrechte, Updates zum Beispiel mit Velopack | ja; ein CI-Job, der das Paket baut, braucht Bastis Wort | offen |
| 6. Signatur: ohne Signatur warnt SmartScreen jeden Nutzer. Empfehlung nach Recherche vom 11. Oktober: Microsoft Store mit MSIX (für Einzelentwickler kostenlos, Microsoft signiert); Azure Artifact Signing erst nach einer Firmengründung (Einzelpersonen nur USA/Kanada) | Konto und Wahl: Basti | offen |
| 7. Live-Abnahme: Installation, ein echtes Diktat in den Editor, Kürzel | nein, braucht einen Windows-PC | Am 16. Oktober bestanden: Installation, Schutzprüfungen und Bastis Diktat in Notepad mit beiden Kürzeln. Den Spielchat im Vollbild prüfen die Beta-Nutzer (Basti, 16. Oktober) |
| 8. Beta: Pre-Release oder Store-Testgruppe, Issue-Vorlage | Veröffentlichen nur mit Bastis Go | offen |

Schritt 7 läuft auf Bastis Windows-PC (am 28. September per SSH
erreichbar, [Geräteprüfung](platform-audit-2026-09-28.md); am 11. Oktober von
Basti als vorhanden bestätigt), mit angeschlossenem Mikrofon. Seit dem
16. Oktober testet Claude dort ohne Go und holt Basti nur für Schritte, die
Hände brauchen (AGENTS.md).
Zu prüfen sind dort vor allem, was ohne Gerät nicht geht: Hook und beide
Kürzel, kein Startmenü nach Strg+Win, Anzeige über einem Spiel im
randlosen und im exklusiven Vollbild, Strg+V in Editor und Spielchat, die
Mikrofonfreigabe von Windows, Autostart und Darstellung bei 100 und 150 %
Skalierung.

## Aktuelle Fortsetzung vom 28. September

Basti hat **Ziel B – öffentliche Verteilung vorbereiten** gewählt.
Das ist keine Veröffentlichungsfreigabe. Der vorhandene Quellstand wurde
im getrennten Arbeitschat unter `windows/` gesichert und nach unabhängiger
Integritäts-/Statusprüfung ohne wesentliche Befunde im Integrationszweig
übernommen. Produktionsdateien und Original-Arbeitskopie blieben unverändert.
Die konkreten Verteilungsgates stehen im [Releaseplan](../windows/RELEASE-PLAN.md).

Nach gesonderter Freigabe bestanden auch die 18 Windows-Schutzprüfungen im
angemeldeten Desktop: zusammen mit den 23 Kern-/Ablaufprüfungen **41/41**.
Dummy-Zugangseintrag und eigene Prüfartefakte wurden entfernt. Der frühere
SSH-Teiltest und die Grenzen bleiben im
[Fortsetzungsnachweis](platform-continuation-2026-09-28.md) sichtbar.
Echte Diktate sowie Installations-, Update- und Deinstallationsabnahme
sind dadurch nicht geprüft.

## Frühere Geräteprüfung vom 28. September

SSH zum Windows-PC und SDK 10.0.401 sind aktuell bestätigt. Die 37 verglichenen
Quell-/Projekt-/Skriptdateien des vorhandenen Prototyps stimmen exakt mit der
separaten Mac-Arbeitskopie überein. In einer temporären Kopie auf Windows
bestanden 23 Kern-/Ablaufprüfungen sowie App- und Browser-Host-Build ohne
Warnung oder Fehler. Die weiteren Schutzprüfungen und sichtbaren Abläufe
wurden nicht wiederholt. Details und Nachweisgrenzen stehen im
[Gerätebericht](platform-audit-2026-09-28.md).

Zum Zeitpunkt dieser frühen Prüfung war der Quellstand im separaten
Elternrepository unversioniert und seine README widersprüchlich. Die oben
beschriebene spätere Snapshot-Übernahme und README-Neufassung schließen diese
Lücke. Die ursprüngliche Arbeitskopie bleibt erhalten.

## Belegter Teilstand vom 12. September

- Ein sichtbarer Windows-Prototyp verband Hotkey, App, lokale Testantwort und
  Textübergabe. Der Windows-Editor und ein isoliertes Chrome-Testprofil
  bestanden die dokumentierten Cursor-, Auswahl- und Abbruchfälle mit
  künstlichem Text.
- Der damalige Bericht zählte 41 Offline-Prüfungen für den verbundenen Ablauf
  und 19 sichtbare Browserprüfungen. Eine lokale Mikrofonaufnahme war bestätigt.
- Eine echte Transkription, Provideranfrage oder Audioübertragung war in diesem
  Bericht **nicht** abgenommen. Die genannten Programmnamen und Versionen
  belegen nur genau diese historischen Prüfläufe, keine allgemeine
  Programm-Unterstützung.
- Der damalige Windows-Prototyp war ein separater lokaler Quellbaum. Die
  spätere Snapshot-Übernahme ist oben mit Herkunft und Prüfgrenzen bezeichnet;
  reproduzierbare Releasepakete bleiben offen. Diese Übernahme zählt nicht
  als macOS-Code-Reduktion.

## Historische Zieloptionen und heutige Entscheidung

Die Quelle vom 12. September unterschied zwei damals offene Abschlussziele;
am 28. September wurde Ziel B gewählt:

1. **Ziel A – eigene Nutzung:** ein installierter, im Alltag abgenommener
   Kandidat auf dem gewählten Windows-Testgerät mit einer vereinbarten Liste
   von Pflichtprogrammen.
2. **Ziel B – öffentliche Verteilung:** Ziel A plus signierte Auslieferung,
   Upgrade- und Deinstallationsprüfung, Anleitung und öffentlicher Download.
   Veröffentlichung braucht eine eigene konkrete Freigabe.

Auch Pflichtprogramme und die endgültige Integrationsbasis waren in der
Planungsquelle offen. Die historischen Editor-/Chrome-Prüfungen legen keine
allgemeine Unterstützung oder neue Zielprogramme fest.

## Nächste Ergebnisse und Abnahme

Ziel B steht fest. Vor einer Produktabnahme sind Pflichtprogramme und ein
prüfbarer aktueller Quellstand festzulegen. Datenerhalt und sichere lokale
Wiederherstellung müssen vor echter Provider-Nutzung geprüft werden. Echte
Mikrofon-/Transkriptionsläufe benötigen eine eigene aktuelle Freigabe für
Audioübertragung und Kosten; der alte Plan erteilt sie nicht.

- Für **Ziel A** muss der installierte Kandidat echte Diktate in den
  vereinbarten Programmen an Cursor und Auswahl übergeben; Fehler- und
  Abbruchfälle dürfen weder die einzige Aufnahme verlieren noch falschen Text
  einfügen. Tastatur- und Sprachausgabebedienung sowie Neustart/Installation
  gehören zur Abnahme.
- **Ziel B** ergänzt eine saubere Windows-Installation ohne Entwicklungs-
  werkzeuge, Signatur, Upgrade/Deinstallation, genaue Produkttexte und eine
  separate Freigabe für öffentliche Veröffentlichung.

Die ausführlichen historischen Fälle bleiben in den beiden externen
Originalnotizen. Die Roadmap führt nur den aktuellen Status und den nächsten
nötigen Schritt.
