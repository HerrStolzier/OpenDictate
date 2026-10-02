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
reduzierter Bewegung. Stilwahl und konkrete Ausgestaltung bleiben
offen. Release 1.0 erscheint mit der heutigen ruhigen Optik; die
Markenidentität folgt mit 1.1. Zeitpunkt und nächster Arbeitsschritt stehen
ausschließlich in [ROADMAP](ROADMAP.md).

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
- Es wird immer nur eine Plattform aktiv bearbeitet (Entscheidung vom
  2. Oktober 2026, [Neuordnung](docs/roadmap-neuordnung-2026-10-02.md)).
  Über Plattform 2 wird erst nach Stufe 6 (öffentlicher Betatest & Zuhören) anhand der
  Rückmeldungen entschieden; Arbeitshypothese ist Linux vor Windows.
- Windows wartet auf diese Entscheidung. Das am 28. September gewählte Ziel,
  öffentliche Verteilung vorzubereiten, gilt erst, wenn die Wahl auf Windows
  fällt; ein versionierter Ausgangsstand, reproduzierbare Paketierung und
  belegte Installation/Abnahme bleiben dann Voraussetzungen. Dies ist kein
  Nachweis eines fertigen Windows-Produkts und keine Freigabe seiner Veröffentlichung.
- iOS ist seit dem 2. Oktober zurückgestellt, bis Mac-Nutzer in Stufe 6 danach
  fragen. Tastatur-Erweiterungen dürfen nicht aufnehmen; der mögliche Ablauf
  über Host-App und App-Wechsel ist umständlicher als das eingebaute Diktieren,
  und eine Vollzugriff-Tastatur mit Netzwerk und API-Schlüssel ist ein Review-
  und Vertrauensrisiko. Bei Wiederaufnahme braucht iOS ein eigenes
  Produktkonzept; bisherige Nachweise: [iOS-Richtung](docs/ios-direction.md).
- Künftige Preise, Vertrieb und Firmengründung bleiben offen; dieser
  Dokumentationsstand entscheidet sie nicht.
- Die Website ist ein lokaler Entwurf mit illustrativer Demo, kein Diktiernachweis.

## Zuständige Quellen

[AGENTS](AGENTS.md) enthält technische Invarianten, [CHECKS](CHECKS.md) die
Prüfwege, [ROADMAP](ROADMAP.md) die zentrale Feature-/Plattform-Liste,
[remaining-acceptance](docs/remaining-acceptance.md) den aktuellen
Abnahme- und Übergabestand. Frühere Freigaben liegen im
[Archiv](docs/archive/APPROVALS.md) und werden nicht mehr gepflegt.
Produktentscheidungen hier nur bei geänderter Entscheidung aktualisieren;
Testergebnisse und laufende Aufgaben gehören nicht hierher.
