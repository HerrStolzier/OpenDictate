# Roadmap-Neuordnung · 2. Oktober 2026

Entscheidung von Basti am 02.10.2026, auf Empfehlung aus der Planungssitzung.
Gilt ab dem Merge von PR #41. Die fünf Mac-Stufen, die Audio-/Recovery-
Invarianten in AGENTS.md, „Apple Silicon only“ und „Zwischenablage + ⌘V“
bleiben unverändert.

## 1. Seriell statt parallel

Es wird immer nur **eine Plattform** aktiv bearbeitet. Wartezeiten (z. B. auf
Apple) werden für die nächste Stufe derselben Plattform genutzt, nicht für
eine andere Plattform. Der Satz „Windows-/Linux-Fortsetzung während der
Apple-Wartezeit“ entfällt aus der ROADMAP.

## 2. Neue Stufe 6: Launch & Zuhören

Nach Stufe 5 (öffentlicher Mac-Release) folgt eine Stufe 6 von etwa zwei
Wochen:

- drei Ankündigungsorte festlegen und bespielen (Kandidaten: Show HN,
  r/macapps, Mastodon/X; endgültige Wahl in Stufe 5)
- GitHub Issues als einziger Feedback-Kanal, mit kurzer Issue-Vorlage
- Downloads und Issues zählen, Rückmeldungen sammeln

Erst nach Stufe 6 wird über Plattform 2 entschieden.

## 3. Plattform-Reihenfolge nach Nachfrage

Die historische Reihenfolge Windows → Linux → iOS → Android vom 12.09. gilt
nicht mehr als Festlegung. Entscheidung nach Stufe 6 anhand der Rückmeldungen.
Arbeitshypothese: **Linux vor Windows** (Zielgruppe technisch versiert und
Linux-affin, Clipboard-Kern vorhanden, dort nach aktuellem Kenntnisstand kein
Whisper-Flow-Wettbewerber). Windows danach (größerer Markt, aber direkter
Wettbewerb). Die Hypothese ist keine Messung und wird in Stufe 6 geprüft.

## 4. iOS zurückgestellt

iOS wird erst aufgegriffen, wenn Mac-Nutzer in Stufe 6 danach fragen. Grund:
Tastatur-Erweiterungen dürfen nicht aufnehmen; der mögliche Ablauf
(Host-App → App-Wechsel → Tastatur) ist umständlicher als Apples eingebautes
Diktieren, und eine Vollzugriff-Tastatur mit Netzwerk und API-Schlüssel ist
ein Review- und Vertrauensrisiko. Bei Wiederaufnahme braucht iOS ein eigenes
Produktkonzept, nicht die Übertragung des Mac-Ablaufs. Die bisherigen
iOS-Nachweise und PR #40 bleiben erhalten; „besonders wichtig“ wird in der
ROADMAP durch „zurückgestellt bis Nachfrage“ ersetzt.

## 5. Marke parallel ab Plan 4, Release 1.0 mit aktueller Optik

Markenarbeit (Typografie, Farben, Maskottchen, Bewegung) beginnt, sobald der
Code in Plan 4 eingefroren ist, und blockiert Plan 5 nicht. Release 1.0 geht
mit der heutigen ruhigen Optik raus; die Markenidentität kommt mit 1.1.

## 6. Prozess verschlanken

- Live-Tests (Mikrofon, Provider, Installation, Keychain) finden statt, wenn
  Basti am Mac sitzt und in der Session ausdrücklich „Go“ gibt. Keine
  gezählten Testblöcke, keine Kontingente, keine Vorab-Freigabedokumente.
- APPROVALS.md wird nicht mehr gepflegt und nach `docs/archive/` verschoben;
  Verweise darauf in AGENTS.md, PROJECT.md, ROADMAP.md und
  docs/remaining-acceptance.md werden entfernt oder auf das Archiv umgestellt.
- Die technischen Invarianten in AGENTS.md (Audio, Keychain, Logs, Hotkey,
  DictationState) bleiben unverändert. Der Abschnitt „Required verification“
  wird auf die Go-Regel oben reduziert.

## 7. CI für Doku-Änderungen abkürzen

- In den Workflows unter `.github/workflows/` ein `paths-ignore` für
  `**/*.md`, `docs/**` und `website/**` bei den Swift-, Linux-, Windows- und
  CodeQL-Jobs, so dass reine Doku-PRs nur den Repository-Hygiene-Check und
  die Doku-Checks auslösen. Branch-Schutz auf `main` entsprechend anpassen,
  falls übersprungene Checks als Pflicht eingetragen sind.
- Im Swift-Workflow `actions/cache` für `.build/` ergänzen, damit Folgeläufe
  nicht von null bauen.
- Keine Self-hosted Runner: öffentliches Repo, Geräte müssten dauerhaft an
  sein, zusätzliche Pflege für eine Person.

## Umsetzung

Eigener Doku-Branch nach dem Merge von PR #41. Betroffene Dateien:
ROADMAP.md (Reihenfolge-Regel oben, Stufe 6, Plattformtabelle, iOS-Zeile,
Markenzeile), PROJECT.md (iOS-Absatz, Windows-Absatz), AGENTS.md (Required
verification, APPROVALS-Verweis), docs/remaining-acceptance.md (Einleitung:
kein Parallelbetrieb), APPROVALS.md → docs/archive/, `.github/workflows/*`
(Punkt 7). Kein App-Code.
