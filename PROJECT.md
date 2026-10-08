# OpenDictate: Produkt und Umfang

## Ziel und Nutzen

Gesprochenen Text per Tastenkombination aufnehmen, transkribieren, wahlweise
in eine gewählte Zielsprache übersetzen und in der zuvor aktiven Anwendung
verfügbar machen: immer über die Zwischenablage, wo belegt auch durch
automatisches Einfügen. Zielgruppe (Entscheidung vom 2. Oktober 2026):
technisch versierte Nutzer, die einen eigenen API-Schlüssel einrichten können.

Verkaufsargumente:

- Abrechnung pro gesprochener Minute statt Pauschale (belegt: 0,0045 $/min,
  rund 0,1 Cent bei einem typischen Diktat von rund 15 Sekunden, rund 18,5
  Stunden Sprache für den Preis einer 5-$-Monatspauschale). Die Zahlen stammen
  aus dem eigenen OpenAI-Verbrauch Juli bis Oktober 2026 und sind kein
  Qualitätsnachweis.
- Übersetzung beim Diktieren: Deutsch sprechen, Zielsprache wählen, der
  übersetzte Text kommt auf demselben Weg wie ein normales Diktat.
- Kein Diktat geht verloren: Eine fehlgeschlagene, abgebrochene oder nicht
  zugestellte Aufnahme bleibt erhalten und lässt sich wiederholen. Nach der
  Nutzerrecherche vom 7. und 8. Oktober 2026 sind verlorene Diktate und
  Abstürze der häufigste Grund, eine Diktier-App zu verlassen.
- Treue Abschrift: OpenDictate formt Sätze nicht ungefragt um. Jede
  Veränderung des Textes (heute: die Übersetzung) ist bewusst eingeschaltet und
  sichtbar.
- Angestrebt bessere Transkriptionsqualität als das eingebaute Diktieren
  (noch ohne Vergleichsmessung).

Der eigene API-Schlüssel ist kein Alleinstellungsmerkmal: Auf dem Mac bieten
ihn die meisten Diktier-Apps an. Der Unterschied liegt in Übersetzung,
zuverlässigem Einfügen und erhaltenen Diktaten.

## Anwendungsfälle

- **Arbeit:** Mails, Chats, Editor, Terminal. Die Produktabnahme richtet sich
  nach Feldkategorien und Fokuswechseln, nicht nach der App-Liste einer Person;
  der aktuelle Plan steht in der [Kompatibilitätsmatrix](docs/compatibility-matrix.md).
- **Übersetzung:** Deutsch sprechen, Zielsprache wählen (zum Beispiel
  Englisch). Seit dem 5. Oktober 2026 auf Linux umgesetzt und im Alltag genutzt;
  die anderen Plattformen ziehen nach ([ROADMAP](ROADMAP.md)).
- **Gaming:** Basti hat beim Spielen von World of Warcraft gemerkt, wie viel
  schneller und praktischer es ist, in den Spielchat zu diktieren statt zu
  tippen. Die Hände bleiben an Maus und Tastatur, es gibt keinen
  Fensterwechsel. Daraus folgen Anforderungen: ein Kürzel mit höchstens zwei
  Tasten, Einfügen in ein Vollbildspiel, später Einzeltaste oder
  Halten-zum-Sprechen. Belegt ist bisher nur der Textchat in World of Warcraft
  mit der Mac-App; es ist keine allgemeine Spielekompatibilitätszusage. Ob der
  Spielbetreiber externe Diktier-Software duldet, ist vor einer öffentlichen
  Gaming-Botschaft zu klären.

## Preismodell

Entscheidung von Basti am 8. Oktober 2026. Sie bestätigt und präzisiert die
Notiz vom 12. September 2026, die bisher außerhalb des Repositorys lag.

- Der Quellcode bleibt vollständig offen (MIT). Wer will, baut jede Variante
  selbst und kostenlos.
- Die CLI-Builds (heute: Linux) bleiben gratis.
- Die fertig installierbare, signierte und gepflegte App mit Oberfläche kostet
  einmalig etwas; Hypothese 2 bis 10 Euro. Bezahlt wird Komfort, Signatur,
  Updates und Support, nicht eine künstlich gesperrte Funktion. Größere spätere
  Upgrades dürfen etwas kosten.
- Die API-Kosten zahlt jeder Nutzer selbst beim Anbieter.
- Verkauft wird erst nach einer Firmengründung. Bis dahin bleibt alles
  kostenlos, auch die Betas.

Nicht entschieden: Preis, Bezahlweg, Firma, App Store. Ein Abo ist nicht
vorgesehen.

## Plattformen und belegter Umfang

Alle Plattformen folgen denselben Regeln: Schlüssel nur im Schlüsselspeicher
des Systems, Audio geht zur Transkription an OpenAI, nie an Dritte darüber
hinaus; fehlgeschlagene Aufnahmen bleiben begrenzt und authentifiziert
erhalten ([PRIVACY](PRIVACY.md)); Logs enthalten nie Schlüssel, Text oder Audio.
Der belegte Stand je Plattform mit Nachweisen steht in
[docs/remaining-acceptance.md](docs/remaining-acceptance.md); die nächsten
Schritte in der [ROADMAP](ROADMAP.md).

- **macOS:** Native Menüleisten-App für macOS 14+, SwiftPM und Swift 6, zuerst
  für Apple Silicon. Aufnahme, Transkription, Zwischenablage und automatisches
  Einfügen per ⌘V in die beim Start aktive App, eigenes Vokabular. Build 8 ist
  notarisiert und als Paket geprüft; Installation und Übersetzung stehen aus.
  Einrichtung: [README](README.md).
- **Linux:** Rust-CLI für Hyprland (Arch/omarchy) mit Aufnahme, Keyring,
  Transkription, Übersetzung, Zwischenablage, Auto-Einfügen in das beim Start
  erfasste Fenster, Leistenanzeige und Hotkey. Seit dem 7. Oktober 2026 im
  Alltag genutzt. Einrichtung: [linux/README.md](linux/README.md).
- **Windows:** Versionierter Prototyp unter [windows/](windows/README.md),
  nur offline geprüft; kein echtes Diktat, keine Paketierung.
- **iOS:** Synthetischer Textpfad eines Tastatur-Prototyps belegt; echte
  Aufnahme und Produktkonzept offen ([Richtung](docs/ios-direction.md)).
- **Android:** Kein Code.
- MIT-lizenzierter Quellcode. Nach erfolgreichen CI-Prüfungen sind zeitlich
  begrenzte, ad-hoc signierte [Entwicklungsarchive](docs/development.md#ci-development-archives)
  verfügbar; sie ersetzen keine Produktabnahme.

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
reduzierter Bewegung. Stilwahl und konkrete Ausgestaltung bleiben offen. Die
Betas erscheinen mit der heutigen ruhigen Optik; die Markenarbeit beginnt nach
der ersten Beta und blockiert keine ([ROADMAP](ROADMAP.md#plattformübergreifend)).

## Grenzen und offene Entscheidungen

- Kein Versprechen fehlerfreier Sprache, garantierter Latenz oder bestätigter
  Annahme in jedem Zieltextfeld. Repräsentative Programme sind Testbeispiele,
  keine pauschale Supportzusage. Die Zwischenablage bleibt der verlustfreie
  manuelle Rückweg.
- Keine Nachbearbeitung: OpenDictate glättet, formatiert oder kürzt nicht.
  Nutzer, die das erwarten, finden es bei anderen Apps; die Website soll das
  erklären.
- Streaming, Echtzeit-Übersetzung, Hold-to-talk und Einzeltaste sind gewünscht,
  nicht implementiert und kein Teil des Funktionsumfangs; Stand in der
  [ROADMAP](ROADMAP.md#plattformübergreifend).
- Die Betas sind keine öffentlichen Releases mit Supportzusage. Jede
  Veröffentlichung braucht Bastis ausdrückliches Go.
- Künftige Preise, Vertrieb und Firmengründung bleiben offen; das Preismodell
  oben ist die Richtung, nicht die Umsetzung.
- Die Website ist ein lokaler Entwurf mit illustrativer Demo, kein
  Diktiernachweis.
- Support läuft bis zum Livegang des Support-Backends nur über die
  Projektkanäle; es gibt noch keine Supportadresse und keine zugesagten
  Antwortzeiten.

## Entscheidungen

Regel seit dem 8. Oktober 2026: Wer mit Basti eine Produkt- oder
Planungsentscheidung trifft, trägt sie in derselben Sitzung hier ein (Datum,
Entscheidung, Link zur Notiz) und ins Projektgedächtnis. Was nur im Gespräch
bleibt, ist später nicht auffindbar; so ging die ursprüngliche Fassung des
Preismodells und der Gaming-Ursprung verloren.

| Datum | Entscheidung | Quelle |
| --- | --- | --- |
| 8. Oktober 2026 | Der Livegang des Supports wartet auf die neue Marke: Domain und Supportadresse kommen von dort. Bis dahin wird nichts eingerichtet oder veröffentlicht; die erste Version bleibt ein Entwurf. | [PR #56](https://github.com/HerrStolzier/OpenDictate/pull/56), [ROADMAP](ROADMAP.md#plattformübergreifend); Gespräch im privaten Projektchat |
| 8. Oktober 2026 | Support: eigenes kleines Backend statt fertiger Ticketsoftware. Kontaktformular und Supportadresse werden Tickets, Dashboard nur für Basti, ein Agent sortiert und schreibt nur Entwürfe, Basti entscheidet und versendet; KI-Chatbot später als weiterer Eingang. Produktneutral für spätere Apps, eigenes privates Repository; die Website bleibt statisch, das Formular schickt nur an das Backend. Grundlage: Support-Richtung seit dem 12. September (E-Mail zuerst, später gemeinsamer KI-Support). | [ROADMAP](ROADMAP.md#plattformübergreifend); Notizen nur lokal bei Basti |
| 8. Oktober 2026 | Alle fünf Plattformen laufen parallel als eigene Tracks; jeder Track endet in einer Beta; Einzelfall-Live-Tests übernehmen Beta-Nutzer. Preismodell: offener Code, CLI gratis, fertige App einmalig bezahlt. Gaming ist ein Anwendungsfall. Die Regel „eine Plattform zur Zeit“ und die Mac-Stufen 3 und 4 im alten Umfang entfallen. Verbrauchsanzeige in der App als plattformübergreifender Wunsch aufgenommen, nicht beauftragt ([ROADMAP](ROADMAP.md#plattformübergreifend)). | [Neuordnung 8. Oktober](docs/roadmap-neuordnung-2026-10-08.md) |
| 5. Oktober 2026 | Linux wird aktive Plattform mit Schwerpunkt Übersetzung nach dem Sprechen; Echtzeit erst als möglicher zweiter Schritt. Aus `rescue/grok-clone-2026-09` nur drei Härtungen übernommen (PR #46). | [Übersetzungsplan](docs/linux-live-translation-plan.md) |
| 2. Oktober 2026 | Eine Plattform zur Zeit, Stufe 6 „Launch & Zuhören“, iOS zurückgestellt (alle drei am 8. Oktober abgelöst). Go-Regel für Live-Tests; APPROVALS.md ins Archiv. Zielgruppe und Kostenargument; konfigurierbarer Endpunkt; Provider-Vertrag. Plan 3 als Eigennutzung, Plan 5 als Beta-Release. | [Neuordnung 2. Oktober](docs/roadmap-neuordnung-2026-10-02.md), [Plan-4-Notiz](docs/plan4-aenderungen-2026-10-02.md) |
| 29. September 2026 | Eigenständige, spielerische Markenidentität als langfristiges Ziel. | oben, Abschnitt Marke |
| 28. September 2026 | Windows: öffentliche Verteilung vorbereiten (Ziel B). | [Windows-Plan](docs/windows-plan.md) |
| 26. September 2026 | Streaming als gewünschte spätere Erweiterung; Gaming-Shortcut mit höchstens zwei Tasten (Textchat in World of Warcraft). | [ROADMAP](ROADMAP.md#plattformübergreifend) |
| 25. September 2026 | Erster Mac-Release nur für Apple Silicon. | [Plan 2](docs/release-plans/02-verteilbares-mac-paket.md) |
| 16. September 2026 | Abnahme nach Feldtypen und Situationen, nicht nach Lieblings-Apps. | [Kompatibilitätsmatrix](docs/compatibility-matrix.md) |
| 12. September 2026 | Reihenfolge Mac → Windows → Linux → iOS → Android (am 2. Oktober aufgehoben). Geschäftsmodell-Notiz außerhalb des Repositorys: offener Code, fertige App einmalig, keine Basis/Pro-Aufteilung (am 8. Oktober hier übernommen). | [Windows-Plan](docs/windows-plan.md); Notiz nur lokal bei Basti |

Frühere Freigaben liegen im [Archiv](docs/archive/APPROVALS.md) und werden
nicht mehr gepflegt.

## Zuständige Quellen

[AGENTS](AGENTS.md) enthält technische Invarianten, [CHECKS](CHECKS.md) die
Prüfwege, [ROADMAP](ROADMAP.md) die Tracks mit den nächsten Schritten,
[remaining-acceptance](docs/remaining-acceptance.md) den belegten Stand je
Plattform. Produktentscheidungen hier nur bei geänderter Entscheidung
aktualisieren; Testergebnisse und laufende Aufgaben gehören nicht hierher.
