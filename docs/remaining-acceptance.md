# Aktueller Stand und verbleibende Abnahme

Stand: 17. September 2026. Dies ist die einzige aktuelle Übergabedatei.
Produktziel: [PROJECT.md](../PROJECT.md); Regeln: [AGENTS.md](../AGENTS.md);
Prüfverfahren: [CHECKS.md](../CHECKS.md); belegte frühere Testbudgets:
[APPROVALS.md](../APPROVALS.md).

## Aktuelle Änderung

[PR #14](https://github.com/HerrStolzier/OpenDictate/pull/14) korrigiert die
automatische Fensteröffnung beim Diktieren: Das Panel erscheint nur auf
ausdrückliche Benutzeraktion. Das ursprüngliche Zieltextfeld wird vor
asynchroner Vorbereitung, Keychain-Dialogen und einer Fokus-Rückgabe erfasst.
Einstellungen, Hilfe und „Über OpenDictate …“ zeigen die vorhandene Version,
Buildnummer und Quellcodeidentität des tatsächlich laufenden Bundles.
Für Apples Terminal enthält die Änderung einen eigenen Unicode-Eingabepfad:
Ein fokussiertes `AXTextArea` außerhalb eines Webdokuments benötigt dort kein
beschreibbares `AXSelectedText`. Das ursprüngliche Ziel bleibt gebunden;
bekannte nichtleere Markierungen, Secure Event Input und Steuerzeichen im
einzufügenden Text verhindern automatische Eingabe. Fehlende Auswahlmetadaten allein
sind kein neuer Ablehnungsgrund. Return wird nicht automatisch gesendet.
Die gemeldete fehlende Texteingabe erfolgte per Tastenkürzel in Apples Terminal;
die installierte Revision des beobachteten Fehlers war unbekannt. Der Nutzer hat
die Terminal-App ausdrücklich bestätigt. Die aktuellen CI-Ergebnisse ersetzen
weder die Prüfung ihrer tatsächlichen
AX-Struktur noch einen sichtbaren Eingabenachweis.

[PR #13](https://github.com/HerrStolzier/OpenDictate/pull/13) ergänzte die
Stabilisierung aus [PR #12](https://github.com/HerrStolzier/OpenDictate/pull/12):
abgebrochene Vorbereitungen bleiben ungültig, Beenden wartet auf laufende Arbeit,
ein neuer API-Schlüssel wird vor dem Entfernen eines alten Eintrags gespeichert,
und erfolgreiche CI-Läufe stellen überprüfte Entwicklungsarchive bereit.
Die genaue Quellcodeidentität und die tatsächlich ausgeführten macOS-CI-Prüfungen
sind am PR beziehungsweise am zugehörigen Workflow-Lauf nachvollziehbar.
Die Implementierung wurde in einer Linux-Arbeitsumgebung vorbereitet; die
installierte macOS-App wurde damit weder ersetzt noch gestartet. Ergebnisse
früherer installierter Kandidaten gelten nicht als neue Laufzeitabnahme.

| Paket | Quellcode / Vorbereitung | Weiter benötigter Nachweis |
|---|---|---|
| A: Texteingabe und Bedienung | Manuell geöffnetes Panel, früh erfasstes Ziel, sichtbare Buildidentität; begrenzter Apple-Terminal-Pfad und klare Rückmeldungen bei unbestätigter oder unterbrochener Übergabe | Geschlossenes Panel beim Hotkey-Diktat, sichtbare Terminaleingabe und Unterbrechung im tatsächlichen Zielprogramm auf dem neuen Kandidaten |
| B: CI und Archive | Strikter Formatter, Compilerwarnungen als Fehler, Plattformprotokoll, sechs Shellprüfungen; sieben kontrollierte Bundle-Fälle; Archiv nach Entpacken erneut überprüft, mit Revision und Prüfsummen | Ergebnisse und Artefakt des exakten Workflow-Laufs; echte Installation und macOS-14-Laufzeitabnahme bleiben offen |
| C: Einrichtung und Beenden | Vorgangsgebundene Rückmeldungen für Start, Retry und Einrichtung; Abbruch und Quit gegen verschachtelte Aktionen geschützt; verlustarme Keychain-Migration mit explizitem Hinweis bei unvollständiger Altbereinigung | Frische Einrichtung, verzögerte Berechtigungen, tatsächliche Keychain-Zugriffsrichtlinie und Beenden während Aufnahme/Upload auf einem Mac |
| D: Menschlicher Pilot | Zwölf begrenzte Fälle und Messgrößen vorbereitet | Tatsächlich gesprochene Diktate und physisches Tastenkürzel; noch keine neuen Messwerte |
| E: Integrationsfälle | Begrenzte erste Fallliste; Offline-Tests für verspätete Rückmeldungen, Abbruch und Quit mit kontrolliertem Aufnahme-/Transkriptionsablauf | Reale Fokuswechsel, Beenden/Abbruch, Gerätefehler und Safari-Fallback untersuchen |
| F: Dokumentation | Einstieg verkürzt, Entwicklerverfahren ausgelagert, aktuelle Übergabe und Aufbewahrungsangaben präzisiert | Nach D/E über begrenzten Betatest entscheiden |

## Nächster ausführbarer Mac-Schritt

Die vorbereitete [Pilot- und Integrationsliste](audio-quality-fixtures.md#prepared-first-human-pilot)
verwendet vorhandene Prüfmittel. Zuerst einen identifizierten Kandidaten auf dem
Mac mit der vorhandenen lokalen Signatur bauen oder ein überprüftes
[CI-Entwicklungsarchiv](development.md#ci-development-archives) für einen bewusst
gewählten Test vorbereiten. Die ad-hoc Signatur des Archivs übernimmt vorhandene
Bedienungshilfen-/Keychain-Zugriffe nicht automatisch; Gatekeeper kann es sperren.
Danach Version und Build in Einstellungen beziehungsweise „Über OpenDictate …“
ablesen. Mit geschlossenem Panel einen kleinen sichtbaren Eingabetest mit
unkritischem Text prüfen: vollständige Eingabe, Unterbrechung zwischen
Unicode-Abschnitten und nativer Normalfall. Für Apples Terminal zuerst die
tatsächliche App und AX-Zielstruktur identifizieren, dann einzeiligen Testtext
ohne Return prüfen und anschließend aus der Eingabe entfernen. Die Terminalfälle
in [CHECKS](../CHECKS.md) erfassen außerdem Markierung, Secure Event Input und
mehrzeiligen Fallback. Ein Ereigniszähler belegt gesendete Befehle, nicht
übernommene Zeichen.
Danach frühes menschliches Nutzerfeedback sammeln; die komplette
[Kompatibilitätsmatrix](compatibility-matrix.md) bleibt das breitere Produktziel.

Mikrofon, lokaler Desktop, frischer Benutzerzustand und physisches Eingabegerät
sind aus der aktuellen Linux-Umgebung nicht verfügbar. Die entsprechenden
Prüfungen stehen aus. Die früher dokumentierten sechs beziehungsweise acht
Mikrofon-/Provider-Versuche sind verbraucht; sie werden nicht als neues Budget
verwendet. Beim tatsächlichen Pilot Umfang und Audiozeit vorher festlegen.

## Bekannte offene Grenzen

- Der gemeldete Terminalfehler ist auf dem installierten Kandidaten nicht
  reproduziert. Der neue Apple-Terminal-Pfad ist durch kontrollierte Tests
  begrenzt; echte Terminaleingabe, unbekannte Auswahlmetadaten und das Verhalten
  konkreter Terminalprogramme brauchen sichtbare Prüfung. iTerm2 und Terminals
  innerhalb von Editoren werden durch diesen Sonderpfad nicht abgedeckt.
- Reale negative Appwechsel müssen als tatsächlich erfolgte Vordergrundwechsel
  belegt werden. Ein misslungener Testwechsel zählt weder als Pass noch als Fehler.
- Der erste Safari-textarea-Fallback im jüngsten historischen Zieltest bleibt
  ungeklärt, obwohl der Wiederholungsversuch bestand.
- Eine manuelle Cursor-/Auswahlbewegung innerhalb desselben Feldes während
  mehrteiliger Eingabe ist noch zu untersuchen. Die Korrektur der Rückmeldung
  erkennt solche Bewegungen nicht automatisch.
- Reale Gerätewechsel, Abziehen des Mikrofons, Berechtigungs-/Keychainfehler und
  Beenden während Aufnahme/Upload brauchen passende praktische Prüfungen.
- Menschliche Sprachqualität, Zahlen-/Namensfehler, Korrekturzeit und tatsächlicher
  Zeitgewinn sind offen. Die neue Fallliste enthält keine gemessenen Ergebnisse.
- Gehörte VoiceOver-Ausgabe und macOS 14 als Laufzeitplattform bleiben offen.
  macOS-15-CI, synthetische Fixtures und AX-Baumprüfungen ersetzen diese Nachweise nicht.
- Wer den alten API-Key-Helfer verwendet hat, speichert den Schlüssel über den
  App-Dialog neu. Der neue Account erhält die normale App-Zugriffsrichtlinie;
  die reale Migration und gegebenenfalls eine angezeigte Altbereinigung sind
  separat zu prüfen. Der Shell-Helfer schreibt keine Schlüssel mehr.

Bekannte Fehler mit falschem Ziel, beschädigtem vorhandenem Text oder Verlust der
einzigen Aufnahme/des einzigen Transkripts verhindern eine Ausweitung des betroffenen
Pfads, bis eine Korrektur oder sichere Einschränkung belegt ist. Kleine Stichproben
rechtfertigen keine allgemeine Erfolgsquote oder pauschale Programm-Unterstützung.

## Historische Evidenz

| Bericht | Aussage für seinen damaligen Kandidaten |
|---|---|
| [Zielabnahme 17. September](target-acceptance-2026-09-17.md) | Echte Auswahlersetzung in TextEdit, Safari und Obsidian mit erzeugter Referenzsprache; Safari-Fallback und tatsächlicher negativer Appwechsel offen |
| [Roadmap 17. September](roadmap-acceptance-2026-09-17.md) | Brave-Langtextkorrektur, konkrete Mikrofon-/Providerfälle und 90-Sekunden-Stopp |
| [Roadmap 16. September](roadmap-acceptance-2026-09-16.md) | Synthetische Feld-/Fokus-/Unicodeprüfungen, Recovery-Dateisystemfehler und Hotkey-Registrierung |
| [Brave 15. September](brave-insertion-2026-09-15.md) | Synthetische Brave-Einfügung und vom Nutzer bestätigter damaliger Proton-Pfad |
| [Native App 15. September](live-acceptance-2026-09-15.md), [Einstellungen](settings-acceptance-2026-09-15.md) | Konkretes menschliches Diktat und native Bedienungs-/Fensterprüfungen |
| [13. September](live-acceptance-2026-09-13.md), [7. September](live-acceptance-2026-09-07.md) | Ältere Kandidaten; insbesondere der historische Cmd+V-Pfad validiert keine heutige direkte Einfügelogik |

Einzelheiten zur früheren lokalen Signatur-/Keychain-Einrichtung und der Abnahme
vom 14. September bleiben im
[unveränderten damaligen Übergabestand](https://github.com/HerrStolzier/OpenDictate/blob/8621edf7f099d7a757ad1a25885eda5cb427a2b2/docs/remaining-acceptance.md#historische-live-abnahmen)
zugänglich. Dortige installierte Pfade, Laufzustände und Freigaben sind historische
Beobachtungen und keine heutige Zustandsabfrage oder neue Zustimmung.

## Zurückgestellte Erweiterungen

Streaming und Hold-to-talk bleiben zurückgestellt. Streaming braucht unter anderem
begrenzte Ereignispuffer, ein validiertes Endereignis, Abbruchbehandlung und
Messungen des Nutzens; unbestätigte Teiltranskripte werden nicht fortlaufend ins
Ziel eingefügt. Hold-to-talk braucht zuverlässige Release-Ereignisse und Erholung
nach verpasster Freigabe; der native Aufnahmestopp bleibt die Obergrenze.

Historische temporäre Audiooriginale werden nicht blind gelöscht, weil sie die
letzte überlebende Aufnahme sein können. Eine künftige Crash-Recovery muss
Eigentum und Wiederherstellung klären. Für öffentliche Verteilung sind außerdem
reproduzierbare Erstinstallation, geeignete Signierung/Notarisierung und Prüfung
der zugesagten Plattformen erforderlich. Die CI-Entwicklungsarchive sind keine
öffentliche signierte und notarisierte Produktveröffentlichung.
