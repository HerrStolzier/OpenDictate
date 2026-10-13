# OpenDictate: Produkt und Umfang

## Ziel und Nutzen

Gesprochenen Text per Tastenkombination aufnehmen, transkribieren, wahlweise
in eine gewählte Zielsprache übersetzen und in der zuvor aktiven Anwendung
verfügbar machen: immer über die Zwischenablage, wo belegt auch durch
automatisches Einfügen. Zielgruppe (Entscheidung vom 2. Oktober 2026):
technisch versierte Nutzer, die einen eigenen API-Schlüssel einrichten können.

Verkaufsargumente (Hauptargument seit 12. Oktober 2026 ist das erste):

- Kostenlos oder fast kostenlos, ohne Abo: Mit einem Modell auf dem eigenen
  Rechner (eigener Server, Stufe 1) kostet ein Diktat nichts; am Mac seit der
  Beta 12, unter Linux seit der ersten Beta. Ohne Terminal-Einrichtung erst mit
  Stufe 2 (Modell in der App).
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
des Systems, Audio geht zur Transkription an OpenAI oder an einen selbst
eingetragenen Server (auch ein lokales Modell auf demselben Rechner), nie an
Dritte darüber hinaus; fehlgeschlagene Aufnahmen bleiben begrenzt und authentifiziert
erhalten ([PRIVACY](PRIVACY.md)); Logs enthalten nie Schlüssel, Text oder Audio.
Der belegte Stand je Plattform mit Nachweisen steht in
[docs/remaining-acceptance.md](docs/remaining-acceptance.md); die nächsten
Schritte in der [ROADMAP](ROADMAP.md).

- **macOS:** Native Menüleisten-App für macOS 14+, SwiftPM und Swift 6, zuerst
  für Apple Silicon. Aufnahme, Transkription, Zwischenablage und automatisches
  Einfügen per ⌘V in die beim Start aktive App, eigenes Vokabular. Build 12 mit
  eigenem Server (auch lokales Modell ohne Schlüssel) und neuer Diktatanzeige ist
  seit dem 12. Oktober die öffentliche Beta `v0.1.0-beta.12`; er hat ein Diktat
  über einen lokalen whisper.cpp-Server bestanden
  ([Nachweis](docs/release-plans/evidence/2026-10-12-build12.md)).
  Einrichtung: [README](README.md).
- **Linux:** Rust-CLI für Hyprland (Arch/omarchy) mit Aufnahme, Keyring,
  Transkription, Übersetzung, Zwischenablage, Auto-Einfügen in das beim Start
  erfasste Fenster, Leistenanzeige und Hotkey; seit 11. Oktober auch eigener
  Server und geführte Einrichtung (`opendictate setup`, offline geprüft). Seit
  dem 7. Oktober 2026 im Alltag genutzt, seit 11. Oktober als Pre-Release
  [`linux-v0.1.0-beta.1`](https://github.com/HerrStolzier/OpenDictate/releases/tag/linux-v0.1.0-beta.1) veröffentlicht. Einrichtung: [linux/README.de.md](linux/README.de.md).
- **Windows:** Versionierter Prototyp unter [windows/](windows/README.md),
  nur offline geprüft; kein echtes Diktat, keine Paketierung.
- **iOS:** Produktkonzept seit dem 11. Oktober 2026: Aufnahme im
  Hintergrund, Ergebnis in die Zwischenablage, keine eigene Tastatur
  ([Konzept](docs/ios-konzept.md)). Die Beta-App dazu liegt unter
  [ios/](ios/README.md); auf dem iPhone ist sie noch nicht gebaut und geprüft.
  Nächste Beta nach Mac und Linux, vor Windows.
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
- Streaming und Echtzeit-Übersetzung sind gewünscht, nicht implementiert und
  kein Teil des Funktionsumfangs. Hold-to-talk und Einzeltaste sind auf macOS
  seit Build 10 Teil der Beta (veröffentlicht am 11. Oktober 2026); auf den
  anderen Plattformen noch nicht. Stand in der
  [ROADMAP](ROADMAP.md#plattformübergreifend).
- Die Betas sind keine öffentlichen Releases mit Supportzusage. Jede
  Veröffentlichung braucht Bastis ausdrückliches Go.
- Künftige Preise, Vertrieb und Firmengründung bleiben offen; das Preismodell
  oben ist die Richtung, nicht die Umsetzung.
- Die Website unter opendictate.app (live seit dem 11. Oktober 2026) zeigt
  eine illustrative Demo, keinen Diktiernachweis.
- Support läuft seit dem 11. Oktober 2026 über support@opendictate.app und
  das Formular unter support.opendictate.app; zugesagte Antwortzeiten gibt es
  nicht, und der KI-Agent ist aus.

## Entscheidungen

Regel seit dem 8. Oktober 2026: Wer mit Basti eine Produkt- oder
Planungsentscheidung trifft, trägt sie in derselben Sitzung hier ein (Datum,
Entscheidung, Link zur Notiz) und ins Projektgedächtnis. Was nur im Gespräch
bleibt, ist später nicht auffindbar; so ging die ursprüngliche Fassung des
Preismodells und der Gaming-Ursprung verloren.

| Datum | Entscheidung | Quelle |
| --- | --- | --- |
| 13. Oktober 2026 | Aufnahmen, deren Text nicht ankam, gelten 24 Stunden (höchstens die fünf neuesten) und werden danach gelöscht, auch wenn sie nie zugestellt wurden. Die Repo-Regel „die einzige Aufnahme nie löschen“ wird daran angepasst; die Apps verhalten sich schon so. | [AGENTS.md](AGENTS.md#behavioral-invariants), [PRIVACY.md](PRIVACY.md); Thread „Projektübersicht und offene Punkte“, 13. Oktober 11:04 |
| 13. Oktober 2026 | Die CI zieht vor dem Ende des macOS-14-Runners (2. November) um: Der Kompatibilitätsjob prüft die älteste Xcode-16-Toolchain auf macOS 15, und die CI baut die iPhone-App auf macOS 26 statt des alten Tastatur-Prototyps. Die offenen Dependabot-Updates (Rust-Bibliotheken für Linux, GitHub-Aktionen) werden geprüft und übernommen, und Altlasten im Repo (alte Zweige, Entwürfe) werden aufgeräumt, nachdem gesichert ist, dass keine ungemergte Arbeit verloren geht. | [CHECKS.md](CHECKS.md); Thread „Projektübersicht und offene Punkte“, 13. Oktober 11:04 |
| 13. Oktober 2026 | Fehler aus den Apps kommen nur über „Fehler melden …“ zu uns: Die App öffnet das Kontaktformular des Supports mit einem kurzen Bericht (Version, System, letzter Fehler, Auszug aus dem lokalen Protokoll, nie Text, Audio oder Schlüssel), den die Person sieht, ändern kann und selbst abschickt. Kein automatisches Fehlersammeln, keine zentrale Fehlerdatenbank, „kein Tracking“ bleibt. Das Support-Backend zeigt die Berichte gruppiert nach Fehler und meldet seine eigenen Fehler per Mail an Basti, mit einem Protokoll ohne IP-Adressen. | [Fehler melden](docs/fehler-melden.md); Thread „Support für die App“, 13. Oktober 09:19 |
| 13. Oktober 2026 | Blinks Stimme ist eine winzige, helle, freche Kunststimme: OpenAI-Stimme „nova“ mit der Anweisung, wie eine kleine Figur zu sprechen, danach höher und schneller gestellt (Probe L). Basti hat natürliche Stimmen verworfen („Blink ist ja kein Mensch“) und aus drei Runden mit 21 Proben L gewählt. | [ROADMAP](ROADMAP.md#plattformübergreifend); Thread „Erklärvideos mit Blink“, 13. Oktober 08:01 |
| 13. Oktober 2026 | Apples Spracherkennung auf dem iPhone (SpeechAnalyzer, ab iOS 26, auf dem Gerät, ohne Schlüssel und ohne Kosten) wird als Option der iOS-App ausprobiert und am iPhone mit OpenAI verglichen. Veröffentlicht wird dabei nichts. Reicht die Qualität nicht, ist ein Whisper-Modell in der App (WhisperKit, rund 600 MB) der nächste Kandidat. | [ROADMAP](ROADMAP.md#track-ios); Karte „Testen“ im Projektchat 13. Oktober |
| 12. Oktober 2026 | Mac-Beta 12 veröffentlicht: Pre-Release `v0.1.0-beta.12` mit Build 12 aus `2d8d4ed` (eigener Server, neue Diktatanzeige, Sicherheitsprüfung); README, Anleitung und Website zeigen darauf. `v0.1.0-beta.10` bleibt als ältere Beta stehen. | [Nachweis](docs/release-plans/evidence/2026-10-12-build12.md#veröffentlichung-als-beta-12-oktober-2026); Bastis „Ja, bitte veröffentlichen“ im Projektchat |
| 12. Oktober 2026 | Blink bekommt schon jetzt eine richtige Stimme: OpenAI-Sprachausgabe mit Bastis eigenem Schlüssel, erzeugt am Mac Mini. Sie ist eine Übergangslösung für etwa sechs Wochen; danach ersetzt eine lokal auf dem Mac Studio erzeugte Stimme sie. Für diese Zeit bringen wir keinen Hinweis auf die KI-Stimme an (Bastis Karte „Gar kein Hinweis“ um 15:26, obwohl OpenAIs Nutzungsregeln ihn verlangen). Basti hatte die Karte „Mac Studio“ als Grundsatzfrage verstanden und das am selben Tag korrigiert. Solche Aufgaben laufen später lokal auf dem Mac Mini oder Mac Studio. | [ROADMAP](ROADMAP.md#plattformübergreifend); Thread „Erklärvideos mit Blink“, 12. Oktober 15:08 |
| 12. Oktober 2026 | Kurze Erklärvideos mit Blink: je Funktion ein Clip von 10 bis 15 Sekunden, der beeindrucken soll, mit Text im Bild, einer Stimme für Blink und Hintergrundmusik, im Stil des Designsystems (Blink, Tastenkappe und Pegel direkt aus `design/`, gerendert mit dem quelloffenen HyperFrames statt mit HeyGens Gratis-Tarif). Sie kommen an zwei Stellen auf die Website: als kurze Schleife mit Pause-Knopf neben dem passenden Abschnitt der Startseite und gesammelt auf einer eigenen Seite „Anleitungen“. Musik und Effekte werden als Code komponiert und gehören uns. Online nur auf Bastis Wort. Für Gesten (etwa mit drei Fingern wischen zum Einfügen) folgen später hochwertige 3D-Videos, die ab Ende November lokal entstehen, damit alle Rechte bei uns liegen. Blinks Stimme kommt schon jetzt von OpenAI (Eintrag darüber). | [ROADMAP](ROADMAP.md#plattformübergreifend); Karte „Beides“ im Projektchat 12. Oktober |
| 12. Oktober 2026 | Die kurze Startseite (rund 370 Wörter, 0,1 Cent pro Diktat vorn, SEO-Grundlagen) geht mit Bastis Satz unter „Probier es aus“ live, sobald sie und die Anleitung zum lokalen Modell (docs/lokales-modell.md) auf `main` sind. | [website/README.md](website/README.md); Karte „Mit Satz live“ im Projektchat 12. Oktober |
| 12. Oktober 2026 | Die Startseite wird kurz (rund 400 Wörter, fünf Abschnitte) und führt mit 0,1 Cent pro Diktat, weil „lokal kostenlos“ allein OpenDictate nicht mehr unterscheidet. Dazu kommen die SEO-Grundlagen (Titel, Vorschaubild, strukturierte Daten, Sitemap). Live nur auf Bastis Wort. | Karte „Bauen“ im Projektchat 12. Oktober |
| 12. Oktober 2026 | Die umgebaute Website („Diktieren ohne Abo“, Preis vorn) geht sofort live, nicht erst mit Build 11. Bis die Mac-Beta mit eigenem Server veröffentlicht ist, sagt die 0-€-Karte „Unter Linux schon jetzt, am Mac ab der nächsten Version“. Bastis „Jetzt live“ (10:41) ersetzt sein „Mit Build 11“ (10:27). | [website/README.md](website/README.md); Karte „Jetzt live“ im Projektchat 12. Oktober |
| 12. Oktober 2026 | Die nach dem Preis umgebaute Website geht erst live, wenn die Mac-Beta mit eigenem Server (Build 11 oder später) veröffentlicht ist; gebaut wird sie schon jetzt. Bis dahin wäre „lokal kostenlos“ am Mac nicht einlösbar. (Ersetzt durch „Jetzt live“, 10:41.) | [Anleitung lokales Modell](docs/lokales-modell.md); Karte „Mit Build 11“ im Projektchat 12. Oktober |
| 12. Oktober 2026 | Hauptargument nach außen ist der Preis: mit einem Modell auf dem eigenen Rechner kostenlos, mit OpenAI wenige Cent im Monat. Website, README und Release-Texte führen damit; die Website wird darum umgebaut. | [README](README.md); Projektchat 12. Oktober |
| 12. Oktober 2026 | Alle öffentlichen Texte (Website, GitHub, App-Texte) werden überarbeitet, damit sie sich lesen, als hätte ein Mensch sie geschrieben. Maßstab für den Ton: Die App soll Spaß machen und ein gutes Gefühl geben, ohne albern zu sein. Auf allen Plattformen gelten dieselben Begriffe (Tastenkürzel, Nochmal senden, Gesicherte Aufnahmen, du). | Karte „Alles“ im Projektchat 12. Oktober |
| 11. Oktober 2026 | Nach der Sicherheitsprüfung (Code aller Plattformen, support-desk, Cloudflare-Konto, nur lesend) erzwingt die Cloudflare-Zone opendictate.app HTTPS: „Always Use HTTPS“ an, HSTS mit allen Subdomains, Mindest-TLS 1.2; http-Aufrufe auf Website und Support leiten per 301 um. Der Bericht mit Angriffsdetails liegt nur in der Projektbibliothek, nicht im Repo; offene Code-Befunde (Zeilenumbrüche vor dem Einfügen in Terminals, Zwischenablage-Kennzeichen, Schlüsselbund-Details) werden als eigene PRs behoben. | [ROADMAP](ROADMAP.md#plattformübergreifend), Zeile „Sicherheitsprüfung vom 11. Oktober“; Karte „HTTPS-Zwang“ im privaten Projektchat, 11. Oktober |
| 11. Oktober 2026 | Die nächste Beta ist iOS, danach Windows. Beide Tracks laufen parallel weiter, aber iOS geht zuerst an Tester (TestFlight). Vorgaben des iOS-Threads für die erste iOS-Beta, Basti mitgeteilt: Erkennung über OpenAI mit eigenem Schlüssel oder einen eigenen Server (Apples Erkennung auf dem Gerät folgt später); Start über „Auf Rückseite tippen“ oder die Aktionstaste, das Kontrollzentrum folgt später; der alte Tastatur-Prototyp (PR #40) ist geschlossen, sein Zweig bleibt. Hochladen zu TestFlight und das Einladen von Testern brauchen Bastis eigenes Go. | [ROADMAP](ROADMAP.md#track-ios); Projektchat 11. Oktober |
| 11. Oktober 2026 | Die Live-Abnahme der Windows-Beta (Installation, ein Diktat in Editor und Spielchat, beide Kürzel) läuft auf Bastis Windows-PC `xmg`, wenn die Beta-App fertig ist, und nur mit seinem Go. | [Windows-Plan](docs/windows-plan.md#weg-zur-windows-beta-stand-11-oktober-2026); Karte im Projektchat 11. Oktober |
| 11. Oktober 2026 | Windows läuft ab jetzt parallel zu iOS weiter. Reihenfolge der nächsten Betas: zuerst iOS, danach Windows. Was ohne Windows-Gerät geht, wird jetzt gebaut und offline geprüft; die Live-Abnahme kommt am Ende. | [Windows-Plan](docs/windows-plan.md#weg-zur-windows-beta-stand-11-oktober-2026); Projektchat 11. Oktober |
| 11. Oktober 2026 | Die Website geht live unter opendictate.app, als Cloudflare Worker mit den Dateien eines festen Commits. Cloudflare Web Analytics, das Cloudflare bei kostenlosen Domains von selbst einschaltet, ist für die ganze Domain aus, weil Website und Support „kein Tracking“ zusagen. | [website/README.md](website/README.md#auslieferung); Bastis „website live“ im privaten Projektchat |
| 11. Oktober 2026 | Linux-Beta veröffentlicht: Pre-Release `linux-v0.1.0-beta.1` auf Commit `afa3506` nach Bastis „go release“, ohne vorherigen Durchlauf von `opendictate setup` auf omarchy (als bekannte Grenze im Release-Text). Angekündigt wird vorerst nirgends; Reddit-Posts erst, wenn Basti das Thema wieder aufmacht. | [Release](https://github.com/HerrStolzier/OpenDictate/releases/tag/linux-v0.1.0-beta.1); Projektchat 11. Oktober |
| 11. Oktober 2026 | Auf Macs ohne Notch ist die schwebende Pille unter der Menüleiste der Standard; die flache Pille in der Menüleiste und „Aus“ bleiben Einstellungen. Ersetzt den Standard aus der Zeile zu den parallelen Design-Punkten. Anlass: Basti hat beide Varianten live ausprobiert und „schwebend“ gewählt. | [docs/remaining-acceptance.md](docs/remaining-acceptance.md); Projektchat 11. Oktober |
| 11. Oktober 2026 | Name, Wortmarke, Blink und App-Icons sind von der MIT-Lizenz ausgenommen; der Quellcode bleibt MIT. Berichte, Links und unveränderte Kopien sind erlaubt, veränderte Versionen brauchen einen eigenen Namen und ein eigenes Icon. Anlass: Schutz der bezahlten, signierten App vor Nachbauten unter gleichem Namen. Keine eingetragene Marke; das wäre ein eigener späterer Schritt. | [TRADEMARKS.md](TRADEMARKS.md); Karte im privaten Projektchat |
| 11. Oktober 2026 | Die offenen Design-Punkte laufen parallel statt nacheinander: Mac-Diktatanzeige, Linux-Leiste mit englischen Markentexten und die Website auf Basis der Beta-Website. Für Macs ohne Notch ist die Anzeige mittig in der Menüleiste der Standard, weil sie dort nichts verdeckt; eine schwebende Anzeige unter der Menüleiste und „Aus“ sind Einstellungen. Im Live-Test am 11. Oktober hat Basti die Anzeige in der Menüleiste bestätigt („schön klein, aber groß genug, dass man sie sieht“); sie bleibt Standard. (Standard am selben Tag ersetzt, siehe die neuere Zeile zur schwebenden Pille.) Anlass: Bastis Sorge, eine schwebende Anzeige verdecke die Browserleiste. Build 9 und die Betas bleiben unverändert. | [ROADMAP](ROADMAP.md#track-macos); Gespräch im privaten Projektchat |
| 11. Oktober 2026 | Mac-Beta startet („Beta los“). Beta-Kandidat ist Build 10 aus `a1903a9` (Einzeltasten und Kürzel-Abfrage, Übersetzung), nicht mehr Build 9; der eigene Server folgt mit der nächsten Version. Jede Veröffentlichung und Ankündigung bekommt weiter ein eigenes Go; der Pre-Release `v0.1.0-beta.10` ist am 11. Oktober mit Bastis Go veröffentlicht. | [Build-10-Nachweis](docs/release-plans/evidence/2026-10-11-build10.md); Gespräch im privaten Projektchat |
| 11. Oktober 2026 | Der Support-Agent schreibt seine Antwortentwürfe weiter mit OpenAI. Cloudflare Workers AI wurde als Alternative recherchiert (kein zweiter Auftragsverarbeiter, günstiger) und nicht gewählt. Der Agent bleibt aus, bis der Auftragsverarbeitungsvertrag mit OpenAI abgeschlossen ist; Basti versendet jede Antwort weiterhin selbst. | [ROADMAP](ROADMAP.md#plattformübergreifend); Karte im privaten Projektchat |
| 11. Oktober 2026 | Basti liest und mergt keine PRs mehr. Fertige, von critic geprüfte PRs mit grüner CI mergt der Workflow „Auto-Merge“ selbst; PRs, die Workflow-Dateien ändern, mergt Claude. Als Entwurf bleibt ein PR nur, wenn er auf ein Ereignis wartet (Release, Livegang). | [CLAUDE.md](CLAUDE.md); Karte im privaten Projektchat |
| 11. Oktober 2026 | Die Linux-Beta bekommt vor ihrem Pre-Release zwei offene Punkte: eigener Server als Stufe 1 für ein lokales Modell (kostenlos, gleiche Begriffe und Regeln wie auf dem Mac) und die geführte Einrichtung `opendictate setup` mit Kürzel-Abfrage (Super+D, F9, rechte Alt nur bei US-Layout). Anlass: Bastis Auftrag „Mach alle offenen To-Dos parallel fertig“; die Abfrage aus der Entscheidung vom 9. Oktober kommt damit für Linux in das kostenlose CLI. Pre-Release und Ankündigungen warten weiter auf Bastis eigenes Go. | [ROADMAP](ROADMAP.md#track-linux); Projektchat 11. Oktober |
| 11. Oktober 2026 | Diktier-Ablauf der iOS-App für die erste Beta: Auslösen per Aktionstaste, Rückseite oder Kontrollzentrum nimmt im Hintergrund auf, das Ergebnis kommt in die Zwischenablage, der Nutzer fügt selbst ein. Keine eigene Tastatur mit Vollzugriff und kein Diktieren nur in der App. Löst den Wunsch vom 29. September 2026 ab, direkt in das Feld anderer Apps einzufügen. | [iOS-Konzept](docs/ios-konzept.md); Karte im privaten Projektchat |
| 11. Oktober 2026 | Der Support geht live: Kontaktformular, Impressum und Datenschutz unter support.opendictate.app, Mails an support@opendictate.app landen als Ticket im Dashboard, das nur nach Cloudflare-Anmeldung erreichbar ist. Der KI-Agent bleibt aus. | [PR #66](https://github.com/HerrStolzier/OpenDictate/pull/66); Bastis Freigabe im privaten Projektchat |
| 11. Oktober 2026 | Cloudflare-Einstellungen (DNS, Zugangsschutz, Speicher) richtet Claude über Cloudflares offiziellen API-Connector selbst ein; Änderungen fragen vorher nach, Deploys weiterhin nur mit ausdrücklichem OK. | [PR #66](https://github.com/HerrStolzier/OpenDictate/pull/66); Karte im privaten Projektchat |
| 11. Oktober 2026 | Support-Mails laufen nur über Cloudflare: Empfang mit Email Routing, Antworten direkt aus dem Support-Dashboard über Cloudflare Email Service (braucht Workers Paid, 5 $ im Monat). Kein zusätzlicher Mail-Anbieter, keine Kopie der Anfragen in ein Postfach. | [PR #66](https://github.com/HerrStolzier/OpenDictate/pull/66); Karte im privaten Projektchat |
| 11. Oktober 2026 | Die Domain für Website und Support wird opendictate.app (bei Cloudflare, wo Worker und Email Routing liegen); opendictate.com ist anderweitig registriert. | [PR #66](https://github.com/HerrStolzier/OpenDictate/pull/66); Gespräch im privaten Projektchat |
| 10. Oktober 2026 | Die Empfehlung in der Mac-Kürzel-Abfrage hängt von der Tastatur ab: Fn halten bei MacBook- oder kompakter Apple-Tastatur, rechte Wahltaste bei Apple-Tastatur mit Ziffernblock (Fn liegt dort weit rechts) oder Tastatur eines anderen Herstellers. Anlass: Bastis Live-Test mit der großen Apple-Tastatur. | [ROADMAP](ROADMAP.md#plattformübergreifend); Gespräch im privaten Projektchat |
| 9. Oktober 2026 | Die neue Diktatanzeige der Mac-App wird vorgezogen: Statt des heutigen Fensters zeigt eine kleine Anzeige an der Notch mit Blink den Stand des Diktats und schließt sich bei Erfolg von selbst; „Beenden“ kommt ins Menü der Menüleiste. Entwurf sofort, Bau gleich nach dem Start der Mac-Beta und vor der Linux-Leiste. Anlass: Bastis Test, im heutigen Fenster stehen zu viele gleich starke Elemente und „Beenden“ ist versteckt. Build 9 und die Beta bleiben unverändert. | [design/README.md](design/README.md), [ROADMAP](ROADMAP.md#track-macos); Karte im privaten Projektchat |
| 9. Oktober 2026 | Der Entwurf der Startseite im neuen Design ist abgenommen. Er übernimmt die Beta-Texte der Website; Notch-Anzeige und Blink sind als Vorschau gekennzeichnet. Eingebaut wird er nach dem Merge der Beta-Website; vor der Veröffentlichung fehlt noch ein Impressum. | [design/README.md](design/README.md); Gespräch im privaten Projektchat |
| 9. Oktober 2026 | Ein lokales Modell statt OpenAI wird eine kostenlose Funktion, keine bezahlte. Umsetzung als „Eigener Server“: Ein Server auf demselben Rechner bekommt keinen API-Schlüssel und braucht keinen; andere Server nur über `https://` und mit dem gespeicherten Schlüssel; eine ungültige Adresse fällt nie auf OpenAI zurück. Zuerst die Adresse (Mac und Linux), ein mitgeliefertes Modell erst später. Build 9 bleibt der Beta-Kandidat. | [ROADMAP](ROADMAP.md#plattformübergreifend), [PR #70](https://github.com/HerrStolzier/OpenDictate/pull/70); Gespräch im privaten Projektchat |
| 9. Oktober 2026 | Das Designsystem „OpenDictate“ aus Claude Design wird die gemeinsame Quelle für das Aussehen aller Oberflächen (Kopie und Generator unter `design/`). Reihenfolge der Umstellung: Website (nach dem Merge der Beta-Website), Linux-Leiste, Support-Formular und Dashboard beim Livegang, Mac-App nach dem Start der Mac-Beta, iOS mit seinem Track, Windows zuletzt. Die Betas bleiben in der heutigen Optik. | [design/README.md](design/README.md); Karte im privaten Projektchat |
| 9. Oktober 2026 | Kürzel-Abfrage nach der Installation wird Funktion der fertigen, bezahlten App: zwei bis drei recherchierte Vorschläge je Plattform, die Empfehlung vorausgewählt, eigenes Kürzel möglich. Alle empfohlenen Vorschläge übernommen (macOS Fn halten, Linux Super+D, Windows Strg+Win halten, iOS Aktionstaste, Android Mikrofon-Taste der Tastatur; Liste in der ROADMAP). Die dafür nötige Technik für Einzeltasten und Halten-zum-Sprechen wird gebaut, zuerst auf macOS. Die laufenden Betas bleiben unverändert. | [ROADMAP](ROADMAP.md#plattformübergreifend); Gespräch im privaten Projektchat |
| 8. Oktober 2026 | Die Linux-Beta erscheint auf Englisch: Das Programm spricht die Systemsprache (Deutsch oder Englisch), die Anleitung gibt es auf Englisch und Deutsch, angekündigt wird in englischsprachigen Communities (r/omarchy, r/hyprland). Veröffentlichung und Ankündigung nur nach Bastis Go. | [Linux-Anleitung](linux/README.md); Gespräch im privaten Projektchat |
| 8. Oktober 2026 | Reihenfolge der Betas: Linux und macOS werden jetzt zur Beta gebracht, iOS danach. Linux beginnt mit Anleitung und installierbarem Arch-Paket. | [ROADMAP](ROADMAP.md#track-linux); Gespräch im privaten Projektchat |
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
