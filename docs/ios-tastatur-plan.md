# Plan: iPhone-Tastatur, Tippgefühl, Emojis, Wörterbuch

Stand 24.11.2026, Fassung 4. Anlass: Rückmeldung aus dem Gerätetest (Emoji-Feld, fehlende Wörter, Verzögerung, Tippgefühl).

„Belegt“ heißt: im Code nachgelesen. Am iPhone ist noch nichts gemessen. Recherche (Apple, Gboard, Hex,
UITextChecker) steht in Abschnitt 3.

Entscheidung 24.11.: „Tippen lernen“ ist ab Werk an (Schalter und „Gelerntes löschen“ bleiben, Lerndaten standardmäßig nicht im Backup). Fehlende Wörter im Test: „Aber“, „Ab“.

## 1. Befunde (vom Prüfer gegengeprüft)

### Tippgefühl
| # | Befund | Stand |
|---|---|---|
| U1 | **Tote Lücken.** Ohne „Tippen lernen“ (ab Werk aus) geht ein Tipp zwischen zwei Tasten verloren (`KeyArea.hitTest`, `KeyboardViewController.swift:714`). Beim iPhone 15 sind das rund 27 % der Buchstabenfläche, dazu der Rand (3 pt links/rechts, 6 oben, 4 unten). Auch mit Modell bleiben Lücken an Systemtasten tot (ß│⌫). | bestätigt, Hauptursache |
| U2 | **Zwei Daumen:** Buchstaben gehen nicht verloren, kommen aber in der Reihenfolge des Loslassens, nicht des Aufsetzens. Verlust nur, wenn beide Finger dieselbe Taste treffen. | bestätigt (abgeschwächt) |
| U3 | **Keine Vorschau-Blase.** Wer zur Nachbartaste rutscht, bekommt trotzdem die erste Taste. | bestätigt |
| U4 | Punkt-Taste 0,35 s verzögert | **falsch**, gestrichen |
| U5 | **Arbeit nach jedem Buchstaben:** Vorschläge synchron, Leiste mit neuen Knöpfen neu gebaut; dazu zwei Durchläufe über alle Kontaktnamen und bis zu 1000 gelernte Wörter je Tastendruck (`Autocorrect.swift:74`, `:84–86`). | bestätigt |
| U6 | **Takt alle 0,25 s** liest den Zustand zweimal und baut den Diktierknopf neu, auch ohne Diktat. | bestätigt, kleiner Beitrag |
| U7 | Keine Feststelltaste per Doppeltipp auf ⇧. | bestätigt |
| U8 | **Leertaste:** Wer sie 0,3 s hält, ohne zu ziehen, bekommt kein Leerzeichen (Halten bricht den Tipp ab). | neu, Prüfer |
| U9 | **Debug-Build auf dem iPhone** (`-Onone`): alles oben läuft unoptimiert ein Vielfaches langsamer. | neu, Prüfer; erst messen |
| U10 | Nach Zeilenumbruch kein Großbuchstabe; Emoji-Zellen ohne Hervorhebung beim Tippen. | neu, Prüfer |

### Emojis
| # | Befund | Stand |
|---|---|---|
| E1 | Halbvolle Spalten (Ende von „Zuletzt“ und jeder Kategorie) werden vom Layout verteilt statt oben bündig: Reihen wirken versetzt. | wahrscheinlich, am Gerät prüfen |
| E2 | Zellen ~29 pt, Schrift 28 pt: Emojis sind gequetscht. Abschneiden am Rand ist bei waagrechtem Scrollen normal. Unicode-Sequenzen werden nicht auf Darstellbarkeit geprüft. | wahrscheinlich |
| E3 | Leiste unten markiert die aktuelle Gruppe nicht. | bestätigt |

### Wörterbuch
| # | Befund | Stand |
|---|---|---|
| W1 | „Aber“ und „aber“ doppelt: Filter muss Groß/Klein ignorieren. Test geschrieben (rot erwartet). | bestätigt |
| W2 | Fehlende Standardwörter, Beispiele „Aber“, „Ab“: beide großgeschrieben, also am Satzanfang. Vermutung: `isWord` prüft nur die getippte Schreibweise, und iOS kennt „aber“/„ab“ nur klein. Lösung: bei Großbuchstabe am Anfang auch die kleine Form prüfen. Am Simulator bestätigen. | Vermutung |

## 2. Umsetzung (Reihenfolge nach Nutzen)
0. **Messen und Verzögerung (U5, U6, U9):** Release-Build aufs iPhone, Dauer je Tastendruck messen (nur Zahlen). Buchstabe zuerst, Vorschläge danach und nur bei geändertem Text; Knöpfe merken sich ihr Wort (sonst „HHaustür“); Wortsuche ohne Durchlauf über alle Wörter; Takt nur, solange etwas läuft oder angezeigt wird. Doppelte Vorschläge filtern (W1).
1. **Lücken und Rand (U1, D1):** Jede Stelle trifft eine Taste, Lücken in der Mitte geteilt, Randtasten bis zum Rand; die Diktiertaste nur ihre sichtbare Fläche. Abnahme: Tipp 6 pt über „q“ ergibt „q“.
2. **Leertaste (U8):** Halten ohne Ziehen gibt ein Leerzeichen.
3. **Vorschau-Blase (U3):** beim Aufsetzen, immer an.
4. **Zwei Daumen (U2):** Setzt ein zweiter Finger auf, wird die gehaltene Taste sofort geschrieben; die Taste folgt dem gleitenden Finger. Größter Umbau; VoiceOver, Globus und Halte-Gesten mit Tests absichern. Abnahme: „a“ und „s“ schnell mit zwei Daumen ergibt „as“ (Gerätetest von Hand).
5. **Emojis (E1–E3):** Felder größer (Richtung 46 pt wie Apple), Schrift ~0,8 × Feld, oben bündig, Kategorie-Leiste mit aktiver Gruppe, Tipp hervorheben, Sequenzen prüfen. Suche und Emoji-Vorschläge später.
6. **Feststelltaste und Großschreibung (U7, U10):** Doppeltipp über Zeitabstand, ohne Verzögerung für den einfachen Tipp.
7. **Wörterbuch (W2):** großgeschriebene Wörter am Satzanfang auch klein prüfen; Test mit „Aber“, „Ab“.
8. **„Tippen lernen“ ab Werk an** (Entscheidung 24.11.), `PRIVACY.md`, App-Text und `PROJECT.md`-Entscheidung mitziehen.

## 3. Recherche (am Mac im Browser geprüft)
- **Trefferflächen:** Bei Hex (und laut Hex bei Apple) trifft jede Stelle der Tastatur eine Taste; Lücken in der Mitte geteilt, Randtasten bis zum Rand.
- **Vorschau-Blase:** Hex zeigt den Buchstaben beim Drücken vergrößert, standardmäßig an.
- **Zwei Daumen:** Hex schreibt den ersten Buchstaben, sobald der zweite Finger aufsetzt; die Taste folgt dem gleitenden Finger.
- **Emoji-Feld:** Apple laut Hex ~46 pt je Feld, wir ~29 pt (berechnet).
- **Gboard:** Hilfeseiten sagen nichts dazu; belegt ist nur das Tippmodell von 2017.
- **UITextChecker:** im Simulator nur „de_DE“ (kein AT/CH); am iPhone nicht gemessen.
- **D1 (neu):** Die Diktiertaste sitzt direkt über i/o/p/ü; ein zu hoher Tipp auf „p“ startet Diktat oder öffnet die App.

## 4. Prüfung
- Automatisch: Lücken, Leertaste, Doppel-Vorschläge, Emoji-Spaltenrechnung.
- iPhone 15: Messwerte vor/nach, Emojis hell und dunkel.
- Zwei Daumen gleichzeitig kann kein automatischer Test: Das Gerätetest von Hand beim Tippen.
- pruefer vor jedem Commit (`Verified-by`); Doku (`ios/README.md`, `docs/remaining-acceptance.md`) im selben Wurf.
