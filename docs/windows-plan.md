# Windows-Plan: portable Zusammenfassung

Diese Kurzfassung stammt aus den externen, lesend geprüften Notizen
`OpenDictate-Windows-Plan.md` und `OpenDictate-Windows-Umsetzungsstand.md`,
Stand **12. September 2026**. Die Originale bleiben außerhalb dieses
Repositories. Der separate Windows-Quellbaum ist hier nicht versioniert; der
[Projekt-Audit](project-audit-2026-09-28.md) hält den geprüften Repository-
Abstand fest. Diese historische Quelle ist keine heutige Geräteabnahme oder
Freigabe.

Die [ROADMAP](../ROADMAP.md) ist die zentrale Plattform-To-do-Liste. Dieses
Dokument bewahrt Windows-Planungsdetails und trennt neue Entscheidungen
vom klar begrenzten historischen Prüfstand.

## Aktuelle Fortsetzung vom 28. September

Basti hat **Ziel B – öffentliche Verteilung vorbereiten** gewählt.
Das ist keine Veröffentlichungsfreigabe. Der vorhandene Quellstand wird
im getrennten Arbeitschat für die Aufnahme unter `windows/` vorbereitet.
Produktcode und Original-Arbeitskopie bleiben dabei unverändert;
Integration und unabhängige Prüfung sind noch offen.

Nach gesonderter Freigabe bestanden auch die 18 Windows-Schutzprüfungen im
angemeldeten Desktop: zusammen mit den 23 Kern-/Ablaufprüfungen **41/41**.
Dummy-Zugangseintrag und eigene Prüfartefakte wurden entfernt. Der frühere
SSH-Teiltest und die Grenzen bleiben im
[Fortsetzungsnachweis](platform-continuation-2026-09-28.md) sichtbar.
Echte Diktate sowie Installations-, Update- und Deinstallationsabnahme
sind dadurch nicht geprüft.

## Direkte Geräteprüfung vom 28. September

SSH zum Windows-PC und SDK 10.0.401 sind aktuell bestätigt. Die 37 verglichenen
Quell-/Projekt-/Skriptdateien des vorhandenen Prototyps stimmen exakt mit der
separaten Mac-Arbeitskopie überein. In einer temporären Kopie auf Windows
bestanden 23 Kern-/Ablaufprüfungen sowie App- und Browser-Host-Build ohne
Warnung oder Fehler. Die weiteren Schutzprüfungen und sichtbaren Abläufe
wurden nicht wiederholt. Details und Nachweisgrenzen stehen im
[Gerätebericht](platform-audit-2026-09-28.md).

Der Quellstand ist weiterhin im separaten Elternrepository unversioniert.
Die mitgelieferte README enthält widersprüchliche alte Aussagen zur bereits
vorhandenen Anbieterintegration. Vor weiterer Umsetzung versionieren und
Statusabschnitte bereinigen; die heutige Offline-Prüfung ist keine Live-Abnahme.

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
- Der geprüfte Windows-Prototyp ist ein separater lokaler Quellbaum, kein
  Bestandteil des macOS-Repositories. Er muss vor einer künftigen Integration
  mit eigener Herkunft, reproduzierbaren Builds und Checks versioniert und
  geprüft werden. Nicht in `main` kopieren oder als macOS-Code-Reduktion zählen.

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
