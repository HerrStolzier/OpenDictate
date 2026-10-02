# OpenDictate: Produkt und Umfang

## Ziel und Nutzen

Gesprochenen Text per Tastenkombination aufnehmen, transkribieren und in der
zuvor aktiven Mac-Anwendung verfügbar machen. Zielgruppe
(Entscheidung vom 2. Oktober 2026): technisch versierte Nutzer, die einen
eigenen API-Schlüssel einrichten können. Verkaufsargument: Abrechnung pro
gesprochener Minute statt Pauschale (belegt: 0,0045 $/min, rund 0,1 Cent bei
einem typischen Diktat von rund 15 Sekunden, rund 18,5 Stunden Sprache für den
Preis einer 5-$-Monatspauschale) und angestrebt bessere Transkriptionsqualität
als das eingebaute Diktieren (noch ohne Vergleichsmessung). Die Zahlen stammen
aus dem eigenen OpenAI-Verbrauch Juli–Oktober 2026 und sind kein
Qualitätsnachweis.

OpenDictate soll als allgemeines macOS-Produkt in repräsentativen Eingabefeldtypen
und Nutzungssituationen zuverlässig arbeiten. Die Produktabnahme richtet sich
daher nach Feldkategorien und Fokuswechseln, nicht nach der persönlichen App-Liste
einer einzelnen Person. Der aktuelle Plan steht in der
[Kompatibilitätsmatrix](docs/compatibility-matrix.md).

## Marken- und Gestaltungsrichtung

Basti hat am 29. September 2026 die langfristige Richtung konkretisiert:
Marketing, Markenauftritt und Produktoberfläche sollen zusammen eine
eigenständige, wiedererkennbare Identität bilden, die Lust auf das Produkt
macht und Freude an seiner Nutzung vermittelt. Die bisherige ruhige
Mockup-/Panel-Optik ist ein Zwischenstand, kein finales Gestaltungsziel.
Der schlanke Umfang und die einfache Bedienung bleiben dabei erhalten.

Als visuelle Referenzen dienen seine sechs bereitgestellten Screenshots:
CUA mit Maskottchen und inszeniertem Markenauftritt; Omarchy mit prägnanter
Pixelschrift, Farben und zusammenhängenden Themes; Meeting Recorder mit
gestalteten Aufnahme- und Transkriptionszuständen, Wellenformen und Retro-Grafik.
Entscheidend ist für Basti das Zusammenspiel von Typografie, Grafikdesign,
Farben, möglichen Maskottchen und Animationen über App und Marketing hinweg.
Die Referenzen legen weder einen bestimmten Retro-/Pixelstil noch ein
Maskottchen oder konkrete Markenbestandteile für OpenDictate fest.

Die spätere Gestaltung soll an tatsächlichen Produktzuständen und einem
Marketingbeispiel sichtbar beurteilt werden: Wiedererkennbarkeit, Freude an
der Nutzung, klare Zustände, Lesbarkeit und Bedienbarkeit einschließlich
reduzierter Bewegung. Stilwahl, konkrete Ausgestaltung und Zeitpunkt bleiben
offen. Diese Ergänzung beauftragt die Planung, noch keine Neugestaltung;
der nächste Arbeitsschritt steht ausschließlich in [ROADMAP](ROADMAP.md).

## Belegter Produktumfang

- Native Menüleisten-App für macOS 14+, SwiftPM und Swift 6.
- Der erste öffentliche Mac-Release wird für Apple Silicon mit macOS 14+
  abgenommen. Intel-Macs sind nicht Teil dieser ersten Produktabnahme.
- Aufnahme → OpenAI-Transkription mit eigenem API-Schlüssel → Zwischenablage
  und optional automatisches Einfügen. Einrichtung und Details: [README](README.md).
- Bewusste Wiederholung erhaltener Aufnahmen bei Fehlern; Schutz des Originals,
  begrenzte Aufbewahrung und authentifizierte Wiederholung: [PRIVACY](PRIVACY.md).
- MIT-lizenzierter Quellcode. Das belegt weder eine öffentliche notarisierte
  Binärversion noch eine Entscheidung über spätere Bezahlangebote.
- Nach erfolgreichen CI-Prüfungen sind zeitlich begrenzte, ad-hoc signierte
  [Entwicklungsarchive](docs/development.md#ci-development-archives) verfügbar.
  Sie enthalten ihre genaue Quellcodeidentität und ersetzen keine Produktabnahme.

## Grenzen und offene Entscheidungen

- Kein Versprechen fehlerfreier Sprache, garantierter Latenz oder bestätigter
  Annahme in jedem Zieltextfeld. Repräsentative Programme sind Testbeispiele,
  keine pauschale Supportzusage. Zwischenablage bleibt der verlustfreie manuelle Rückweg.
- Streaming ist ausdrücklich als spätere Erweiterung gewünscht; technische
  Gestaltung und Preisentscheidung sind offen. Hold-to-talk bleibt eine
  zurückgestellte Erweiterung. Beides ist nicht implementiert und kein Teil des
  aktuellen Funktionsumfangs; Wünsche und Planungsstand stehen in [ROADMAP](ROADMAP.md).
- Ein Linux-Clipboard-MVP-Kern und ein separater Windows-Prototyp belegen noch
  keinen plattformweiten Produktumfang. Die aktuellen Stände, offenen Abnahmen
  und nicht festgelegten Plattformziele stehen in [ROADMAP](ROADMAP.md).
- Für Windows hat Basti am 28. September die direkte Vorbereitung öffentlicher
  Verteilung als nächstes Ziel gewählt. Ein versionierter Ausgangsstand,
  reproduzierbare Paketierung und belegte Installation/Abnahme sind dafür
  Voraussetzungen. Dies ist kein Nachweis eines fertigen Windows-Produkts
  und keine Freigabe seiner Veröffentlichung.
- iOS ist nach Bastis ausdrücklicher Aussage vom 28. September besonders
  wichtig. Gewünschter Ablauf: direkt in anderen Apps diktieren. Die erlaubte
  Aufnahme-/Tastaturkopplung und ihre Abnahme werden zuerst geklärt;
  [iOS-Richtung](docs/ios-direction.md). Die historische Plattformreihenfolge
  bestimmt keine heutige niedrige Priorität.
- Künftige Preise, Vertrieb und Firmengründung bleiben offen; dieser
  Dokumentationsstand entscheidet sie nicht.
- Die Website ist ein lokaler Entwurf mit illustrativer Demo, kein Diktiernachweis.

## Zuständige Quellen

[AGENTS](AGENTS.md) enthält technische Invarianten, [CHECKS](CHECKS.md) die
Prüfwege, [ROADMAP](ROADMAP.md) die zentrale Feature-/Plattform-Liste,
[remaining-acceptance](docs/remaining-acceptance.md) den aktuellen
Abnahme- und Übergabestand und [APPROVALS](APPROVALS.md) belegte Freigaben.
Produktentscheidungen hier nur bei geänderter Entscheidung aktualisieren;
Testergebnisse und laufende Aufgaben gehören nicht hierher.
