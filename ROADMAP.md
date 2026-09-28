# OpenDictate Roadmap

Stand: 28. September 2026. Geprüfter Dokumentations- und Code-Ausgangspunkt:
`main` `5b95535b8f80d1cc868318594860f64566294386`.

Diese Datei ist die **einzige laufende Feature- und Plattform-To-do-Liste**.
Sie hält belegten Status, den nächsten nötigen Arbeitsschritt, Abhängigkeiten
und den Abschlussnachweis fest. Sie setzt weder eine neue Priorität oder einen
Termin noch eine technische, Kosten-, Test- oder Veröffentlichungsfreigabe.

Zuständigkeiten: [PROJECT.md](PROJECT.md) beschreibt Produktziel und Umfang;
[docs/remaining-acceptance.md](docs/remaining-acceptance.md) hält den aktuellen
Übergabe- und Abnahmestand fest; die verlinkten Stufenpläne enthalten ihre
konkreten Arbeitsschritte und Prüfkriterien. Der statische
[Projekt-Audit](docs/project-audit-2026-09-28.md) und die
[Code-Reduktionsbewertung](docs/code-reduction-2026-09-28.md) begründen mögliche
Bereinigungen, sind selbst keine zweite Aufgabenliste.

## Mac-Release in fünf Stufen

| Stufe | Status | Nächstes nötiges Ergebnis | Abhängigkeit | Abschlussnachweis |
| --- | --- | --- | --- | --- |
| [1. Interne Funktionsabnahme](docs/release-plans/01-interne-produktabnahme.md) | Am 24.09. für den dokumentierten Grundablauf auf dem vorhandenen Mac abgeschlossen. Die Grenzen der konkreten Felder und Kandidaten bleiben sichtbar. | Kein weiterer Plan-1-Lauf vorgesehen; offene Sicherheits- und Bediennachweise gehen in die späteren Stufen. | — | Datiertes Protokoll und exakt bezeichnete Kandidaten im [Plan-1-Bericht](docs/release-plans/evidence/2026-09-24-plan1-fortsetzung.md). |
| [2. Verteilbares Paket](docs/release-plans/02-verteilbares-mac-paket.md) | Build 8 ist signiert und einmal eingereicht. Der letzte im Übergabestand protokollierte Apple-Status war `In Progress` um 17:20:29 UTC am 28.09.; nicht erneut einreichen. | Dieselbe Einreichung abwarten. Nur bei `Accepted`: Apple-Log sichern, Ticket anheften, finales ZIP samt Manifest erstellen und entpackt prüfen. Danach kontrollierte Migration und vollständigen Diktat-/Kopierweg abnehmen. | Stufe 1 und das Ergebnis der bestehenden Einreichung. Installation/Migration und Live-Abnahme bleiben eigene kontrollierte Prüfschritte. | Der Manifest-Hash beschreibt genau das finale ZIP. Das daraus entpackte Bundle besteht Signatur-, Ticket-, Gatekeeper-, Info.plist- und App-/Helper-Prüfungen; Binärhash und Modus stimmen mit dem geprüften Kandidaten überein. Installation/Migration und beide Übergabewege sind separat bestanden. Details im [Paketplan](docs/release-plans/02-verteilbares-mac-paket.md). |
| [3. Begrenzter Betatest](docs/release-plans/03-begrenzter-betatest.md) | Noch nicht begonnen. | Erst nach Paketabnahme drei Tester, konkrete Empfänger, Paketlink, höchstens 20 Provider-Anfragen und Audioübertragung festlegen und separat freigeben. | Stufe 2; Einwilligung und konkrete Freigabe für Versand, Mikrofon und Provider-Kosten. | Drei Installationen und 20 gezählte Aufgaben; die Schwellen und Einzelmessungen stehen im [Betatestplan](docs/release-plans/03-begrenzter-betatest.md). |
| [4. Release-Kandidat](docs/release-plans/04-release-kandidat.md) | Noch nicht begonnen. | Nach dem Betatest Befunde schließen und einen eingefrorenen Kandidaten samt Hash, Installation/Update, vollständiger UX- und VoiceOver-Prüfung sowie übereinstimmenden Produkttexten abnehmen. | Stufen 1–3; für jede Live-Prüfung gilt die passende Freigabe. Ein technisches Go ist noch keine Veröffentlichungserlaubnis. | Kein offener Blocker; installierter Kandidat und Updateweg geprüft; identischer Archivhash und schriftlicher Go/No-Go-Befund nach [Plan 4](docs/release-plans/04-release-kandidat.md). |
| [5. Öffentlicher Mac-Release](docs/release-plans/05-oeffentlicher-release.md) | Nicht freigegeben und nicht veröffentlicht. | Vor Veröffentlichung die konkrete Ausgabe, Produktseite und den Kanal ausdrücklich genehmigen. Dabei die frühere ChatGPT-Sites-Planungsnotiz vom 12.09. mit dem vorhandenen statischen Website-Entwurf abgleichen. | Stufe 4 und separate ausdrückliche Freigabe zur Veröffentlichung. | Der tatsächliche öffentliche Download stimmt im Hash mit dem freigegebenen ZIP überein; Website, README, Datenschutztext und Installationsweg sind außen geprüft. Kriterien in [Plan 5](docs/release-plans/05-oeffentlicher-release.md). |

Der erste öffentliche Mac-Umfang bleibt Apple Silicon mit macOS 14 oder neuer;
Intel ist darin nicht enthalten. Stufe 5 ist kein Beschluss zu Preisen,
Unternehmen, Mac App Store oder anderen Plattformen. Die Detailpläne bleiben
die Quelle ihrer vollständigen Prüfkriterien.

## Plattformen außerhalb des Mac-Releaseplans

Aktualisierung vom 28.09.: Beide Geräte sind direkt per SSH geprüft. Linux
bestand 23 Offline-Tests, Formatter, Clippy und Release-Build; Windows 23
Kern-/Ablaufprüfungen und App-/Browser-Host-Build. 37 Windows-Quelldateien
stimmen mit der separaten Mac-Kopie überein. Vor weiterer Windows-Umsetzung
den unversionierten Stand sichern/versionieren und seine widersprüchliche
README bereinigen. Die [Geräteprüfung](docs/platform-audit-2026-09-28.md)
ergänzt die datierten sichtbaren Nachweise unten, ersetzt sie aber nicht.

| Plattform | Belegter Stand | Nächstes nötiges Ergebnis | Abhängigkeit | Abschlussnachweis |
| --- | --- | --- | --- | --- |
| Windows | Der zuletzt gelesene Plan-/Umsetzungsstand ist vom 12.09.2026: ein separater, nicht in diesem Repo versionierter Prototyp bestand Teilprüfungen mit künstlicher Antwort und Testtext. Echte Transkription/Provideranfrage war dort offen; das ist keine heutige Geräteabnahme. | Ziel A (eigene Nutzung) oder B (öffentliche Verteilung) und Pflichtprogramme festlegen; danach einen aktuellen Quellstand und die nötige Live-Prüfung bestimmen. | Entscheidung zu Ziel und Programmen; echte Mikrofon-/Providerprüfung erst mit eigener aktueller Budgetfreigabe. | Ziel A: installierter Kandidat und vereinbarte Pflichtprogramme auf dem Testgerät abgenommen. Ziel B ergänzt reproduzierbare signierte Verteilung, Update-/Deinstallationsprüfung und eigene Veröffentlichungsfreigabe. Details und Herkunft: [Windows-Plan](docs/windows-plan.md). |
| Linux | Phase 0 ist als Wegwahl belegt; der Phase-1-Clipboard-MVP-Kern ist in `main` vorhanden und offline geprüft. Phase 1 ist **nicht** abgenommen: Live-Upload, reale Fehlerfälle, physischer Hotkey sowie Tray/Panel fehlen als Nachweise. | Erst eine neue begrenzte Live-Freigabe festlegen; dann den realen Aufnahme-, Keyring-, Provider-, Clipboard- und Fehlerpfad prüfen. Anschließend Tray/Panel und physischen Hyprland-Hotkey abnehmen; Paketierung folgt danach. | Zielsystem Omarchy/Hyprland; neue Mikrofon-/Providerfreigabe. Keine Änderung der Nutzer-Hyprland-Konfiguration ohne eigenen Auftrag. | Phase 1 erst nach dem vollständigen Durchstich samt Fehler-/Abbruchfällen, physischem Hotkey und UI-Minimum. Automatisches Einfügen ist eine spätere Phase und braucht eine belegte Zielfensterregel oder einen begründeten Clipboard-only-Ship. [Linux-Detailplan](docs/linux-build-plan.md), [Phase-1-Bericht](docs/linux-phase1-core-2026-09-22.md). |
| iOS | In den geprüften Quellen als dritte Plattform in der Reihenfolge vom 12.09. erwähnt; kein iOS-Plan oder Implementierungsnachweis in diesem Repository gefunden. | Ziel, Produktnutzen und gewünschte Abnahme festlegen, wenn die Plattform aufgegriffen wird. | In der zuletzt ausdrücklich dokumentierten Reihenfolge nach Windows und Linux; technische Gates sind offen. | Noch nicht definiert; vor Umsetzung im Rahmen eines konkreten Plattformplans festlegen. |
| Android | In den geprüften Quellen als vierte und letzte Plattform in der Reihenfolge vom 12.09. erwähnt; kein Android-Plan oder Implementierungsnachweis in diesem Repository gefunden. | Ziel, Produktnutzen und gewünschte Abnahme festlegen, wenn die Plattform aufgegriffen wird. | In der zuletzt ausdrücklich dokumentierten Reihenfolge nach Windows, Linux und iOS; technische Gates sind offen. | Noch nicht definiert; vor Umsetzung im Rahmen eines konkreten Plattformplans festlegen. |

Der Windows-Plan vom **12.09.2026** nannte ausdrücklich die Reihenfolge
**Windows → Linux → iOS → Android**. Das bleibt die zuletzt ausdrücklich
dokumentierte Plattformreihenfolge. Seitdem sind Linux-Vorarbeiten mit
Phase-1-Code vorhanden; daraus wird hier keine neue Priorisierung abgeleitet,
und die Linux-Live-Abnahme bleibt offen.

## Belegte künftige Erweiterungen und offene Produktfragen

| Punkt | Status | Nächstes nötiges Ergebnis | Abhängigkeit / Abschlussprüfung |
| --- | --- | --- | --- |
| Streaming beim Diktieren | Basti hat es am 26.09. ausdrücklich als gewünschte spätere Erweiterung benannt. Technische Gestaltung und Produkt-/Preisentscheidung sind offen; optionale Funktion oder Upsell ist nur eine Möglichkeit. | UX und technische Grenzen einschließlich Teil-/Endereignis, Abbruch, Fehler und Nutzenmessung festlegen, bevor Umsetzung geplant wird. Unbestätigte Teilergebnisse nicht fortlaufend in das Zielfeld schreiben. | Keine freigegebene Implementierung oder Preisentscheidung. Eigene Akzeptanzkriterien vor Umsetzung definieren; dann sichtbaren Ablauf, Abbruch und sichere Endausgabe prüfen. |
| Hold-to-talk | Als nicht implementierte Erweiterung in den Produkt-/Kompatibilitätsnotizen geführt. | Press-/Release-Verhalten, verpasste Freigabe und Wiederherstellung konkret definieren. | Kein Implementierungsauftrag. Vor Abnahme Tastendruck, Loslassen, Wiederherstellung und bestehende Aufnahmekappung prüfen; genaue Zielplattform muss feststehen. |
| Gaming-Shortcut | Basti wünscht einen leicht erreichbaren Shortcut mit höchstens zwei Tasten. Die Belegung ist offen; Ergonomie und Konflikte mit Spielbelegungen müssen berücksichtigt werden. Der berichtete WoW-Chat-Nutzen ist keine allgemeine Kompatibilitätszusage. | Belegung anhand des Zielspiels auswählen und Kollisionen prüfen. | Kein Implementierungsauftrag und keine Supportzusage. Abschluss erst nach Prüfung der gewählten Belegung in den ausdrücklich gewählten Spielen; unterstützte Spiele auf geprüfte Fälle begrenzen. |
| Alte, verwaiste Audiooriginale nach Absturz | Die sichere Zuordnung und Wiederherstellung historischer temporärer Dateien ist offen. Bestehende Regel: die einzige überlebende Aufnahme nicht blind löschen. | Eigentum, Erkennung, Zugriff, Ablauf und Wiederherstellung festlegen, bevor Bereinigung automatisiert wird. | Bestehende Audio-/Recovery-Invarianten aus [AGENTS.md](AGENTS.md) und [PRIVACY.md](PRIVACY.md) erhalten; mit konkreten Verlust-/Manipulationsfällen abnehmen, nicht nur mit einem erfolgreichen Pfad. |

## Technischer Audit

Der separate [Projekt-Audit vom 28.09.2026](docs/project-audit-2026-09-28.md)
ordnet belegte kleine Korrekturen, begrenzte Codevereinfachungen, vorsichtige
Duplikatbehandlung und erhaltenswerte Sicherheits-/Recovery-Pfade ein. Die
[Code-Reduktionsbewertung](docs/code-reduction-2026-09-28.md) konkretisiert den
jetzt ausdrücklich beauftragten Versuch: Die gemessene Ausgangsbasis beträgt
8.009 Sourcezeilen; das Reduktionsziel liegt bei 10–25 %. Die Coverage-Baseline
beträgt 33,526570 %, die zulässige Untergrenze bei höchstens 2 % relativem
Verlust 32,856039 %. Der sichere Wartungsdurchlauf in Commit `a9165fd` entfernte
den unbenutzten Farbhelfer und korrigierte zwei irreführende Kommentare: netto
fünf Sourcezeilen weniger (0,06 % der Ausgangsbasis). Das 10%-Ziel von mindestens
801 Zeilen wurde nicht erreicht; eine sichere größere Kürzung innerhalb des
freigegebenen Mac-Umfangs war nicht belegt und wurde nicht erzwungen. Die
vorgeschriebenen Offline-Quellchecks bestanden. Die Nachhermessung ergibt
33,55899 % Swift-Coverage (vorher 33,52657 %): kein Verlust. Der Anstieg stammt
nur von fünf entfernten ungetesteten Zeilen. Bestehende Tests und Rust-Code
sind bytegleich; Verhaltens- und Sicherheitsregeln wurden nicht geändert.
