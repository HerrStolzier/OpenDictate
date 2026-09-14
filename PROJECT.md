# OpenDictate: Produkt und Umfang

## Ziel und Nutzen

Gesprochenen Text per Tastenkombination aufnehmen, transkribieren und in der
zuvor aktiven Mac-Anwendung verfügbar machen. Zielgruppe, aus diesem Ablauf
abgeleitet: Menschen, die kurze Texte am Mac lieber diktieren als tippen.
Eine darüber hinaus validierte Marktsegmentierung liegt hier nicht vor.

## Belegter Produktumfang

- Native Menüleisten-App für macOS 14+, SwiftPM und Swift 6.
- Aufnahme → OpenAI-Transkription mit eigenem API-Schlüssel → Zwischenablage
  und optional automatisches Einfügen. Einrichtung und Details: [README](README.md).
- Bewusste Wiederholung erhaltener Aufnahmen bei Fehlern; Schutz des Originals,
  begrenzte Aufbewahrung und authentifizierte Wiederholung: [PRIVACY](PRIVACY.md).
- MIT-lizenzierter Quellcode. Das belegt weder eine öffentliche notarisierte
  Binärversion noch eine Entscheidung über spätere Bezahlangebote.

## Grenzen und offene Entscheidungen

- Kein Versprechen fehlerfreier Sprache, garantierter Latenz oder bestätigter
  Annahme im Zieltextfeld. Zwischenablage bleibt der manuelle Rückweg.
- Streaming und Hold-to-talk sind zurückgestellt, keine aktiven Funktionen.
- Windows-/Linux-Umfang, künftige Preise, Vertrieb und Firmengründung werden
  hier nicht festgelegt; dieser Dokumentationsauftrag entscheidet sie nicht.
- Die Website ist ein lokaler Entwurf mit illustrativer Demo, kein Diktiernachweis.

## Zuständige Quellen

[AGENTS](AGENTS.md) enthält technische Invarianten, [CHECKS](CHECKS.md) die
Prüfwege, [remaining-acceptance](docs/remaining-acceptance.md) den aktuellen
Übergabestand und offene Nachweise, [APPROVALS](APPROVALS.md) belegte Freigaben.
Produktentscheidungen hier nur bei geänderter Entscheidung aktualisieren;
Testergebnisse und laufende Aufgaben gehören nicht hierher.
