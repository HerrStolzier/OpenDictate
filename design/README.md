# Designsystem

Dieser Ordner ist die gemeinsame Quelle für das Aussehen von OpenDictate auf
allen Oberflächen. Er ist eine unveränderte Kopie des Designsystems
„OpenDictate“, das Basti in Claude Design angelegt hat. Claude Design bleibt
das Original: Änderungen dort werden hier per Pull-Request nachgezogen, nie
umgekehrt von Hand.

Stand der Kopie: 9. Oktober 2026, entspricht der Fassung „Erste Fassung aus
den Markenentwürfen“ vom 2. Oktober 2026.

## Inhalt

| Pfad | Was |
| --- | --- |
| [`brand.md`](brand.md) | Markenhandbuch: Stimme, Farben, Schrift, Pixelraster, Blink, Bewegung, Zugänglichkeit |
| [`tokens.json`](tokens.json) | Alle Werte: Farben in drei Themes (Nacht, Bernstein, Papier), Schriftstile, Abstände, Radien, Pixelmaße |
| [`fonts/`](fonts/) | Geist, Geist Mono und Geist Pixel (SIL Open Font License, [`fonts/OFL.txt`](fonts/OFL.txt)) |
| [`assets/logos/`](assets/logos/) | Wortmarke und Blink als SVG; wie App-Icons nicht unter der MIT-Lizenz ([TRADEMARKS.md](../TRADEMARKS.md)) |
| [`assets/app-icon/`](assets/app-icon/) | App-Icon in 1024, 512 und 256 px |
| [`assets/symbols/`](assets/symbols/) | Pixelsymbole im 12 × 12-Raster |
| [`components/`](components/) | Richtlinien je Komponente; `components/web/` ist die Web-Umsetzung aus Claude Design und Vorlage für die Pixelbilder von Blink auf anderen Plattformen |
| [`generated/`](generated/) | Aus `tokens.json` erzeugte Dateien, nicht von Hand ändern |

## Erzeugte Dateien

```bash
python3 scripts/design-tokens.py          # neu erzeugen
python3 scripts/design-tokens.py --check  # prüfen, ob sie aktuell sind
```

| Datei | Für |
| --- | --- |
| `generated/tokens.css` | Website und Web-Oberflächen: CSS-Variablen mit denselben Namen wie in Claude Design (`--bg`, `--signal`, `--font-pixel`, `--space-6` …); Theme per `data-theme` |
| `generated/gtk-colors.css` | Linux: `@define-color`-Einträge für Waybar und GTK, z. B. `@od_signal_nacht` |
| [`Sources/OpenDictateCore/DesignTokens.swift`](../Sources/OpenDictateCore/DesignTokens.swift) | macOS und später iOS: Farben je Theme, Maße und Schriftstile; wird direkt in den App-Kern erzeugt |

Die Python-Tests unter `scripts/tests/` schlagen fehl, wenn `tokens.json`
geändert wurde, ohne die Dateien neu zu erzeugen.

## Stand je Oberfläche

Linux-Leiste, Website (live seit 11. Oktober) und Mac-Diktatanzeige (öffentlich
seit `v0.1.0-beta.12`) nutzen diesen Ordner. Seit dem 11. Oktober 2026 laufen die Umstellungen parallel statt
in der Reihenfolge der Tabelle unten ([Entscheidungs-Log](../PROJECT.md#entscheidungen)). Veröffentlichte Betas bleiben in ihrer Fassung; die Markenarbeit blockiert keine Beta
([PROJECT](../PROJECT.md#marken--und-gestaltungsrichtung)).

| Oberfläche | Wie sie das Designsystem übernimmt |
| --- | --- |
| Website (`website/`) | `tokens.css`, Schriften und SVGs in den Seitenordner kopieren; Entwurf der Startseite liegt in Claude Design |
| macOS-App | Im Code, live auf dem Mac Mini geprüft, Notch-Maße mit der Vorschau auf einem MacBook Air bestätigt: `DesignTokens.swift` liegt in `OpenDictateCore`, die Schriften liegen im App-Bundle unter `Resources/Fonts` (mit `OFL.txt`), Blink ist aus `components/web/bundle.js` nach Swift übertragen (`BlinkFigure`, ein Test vergleicht beide). Neue Diktatanzeige an der Notch, ohne Notch schwebend unter der Menüleiste (Bastis Wahl), wahlweise flach in der Menüleiste, Blink-Silhouette als Menüleisten-Symbol, Menü mit Wortmarke. Offen: `.icns` aus `app-icon-1024.png`. Bauen und prüfen nur auf dem Mac |
| Linux | Leistenanzeige mit Blink (`▮`), „REC“ und den Zustandswörtern im Tooltip, Farben aus `gtk-colors.css` im Waybar-Beispiel; ein Test prüft, dass sie zu den Tokens passen. Bekannte Abweichung: Beim Schreiben zeigt die Leiste aus Platzgründen nur `▮ …`, das Wort „Schreibt“ steht im Tooltip |
| Support-Formular und Dashboard | `tokens.css` und Schriften übernehmen; der Support ist seit 11. Oktober live (privates Repo `support-desk`) |
| iOS | dieselbe Swift-Datei wie macOS |
| Windows | Im Code, Theme Nacht: `windows/OpenDictate.Core/DesignTokens.cs` kommt vom Generator, `windows/OpenDictate.App/Brand.cs` legt daraus die Farb- und Schrift-Ressourcen an, `Theme.xaml` gestaltet damit Knöpfe (Stufenecken), Umschalter, Felder und Listen; Blink ist aus `blink-32.svg` übertragen. Bauen und live prüfen auf xmg |

## Englische Markentexte (Vorschlag)

Das Markenhandbuch [`brand.md`](brand.md) ist deutsch. Für die Linux-Beta,
englische Programmtexte und englischsprachige Ankündigungen gilt bis zur
Übernahme ins Original in Claude Design dieser Vorschlag. Danach wandert er nach
`brand.md` und dieser Abschnitt entfällt.

- Englisch per „you“, kurze Sätze, Verben zuerst: „Send again“, „View on GitHub“.
  Satzanfang groß, sonst klein, auch in Knöpfen und Menüs.
- Zustände: **Ready** (Bereit), **Listening** (Hört zu), **Writing** (Schreibt),
  **Inserted** (Eingefügt), **Copied** (Kopiert, Text nur in der
  Zwischenablage), **Oops** (Hoppla). „Inserted“ statt „Pasted“, weil die
  Linux-App ihre Einstellung „auto-insert“ nennt.
- Fehler beginnen mit „Oops.“ und sagen sofort, was sicher ist: „Oops. No
  connection. Your recording is safe.“
- Nur sagen, was die App wirklich tut: „your own OpenAI API key“, unter Linux im
  Secret Service gespeichert, kein Tracking, Quellcode unter MIT-Lizenz. Keine
  Versprechen zu fehlerfreier Erkennung, Geschwindigkeit oder Preis.
- Keine Emoji, keine Ausrufezeichen, keine Superlative, kein „simply“ oder
  „just“. „REC“ bleibt in beiden Sprachen gleich.

Die Linux-Leiste nutzt die Zustandswörter schon (Tooltip von `opendictate bar`).
Benachrichtigungen und Meldungen der Linux-App folgen nach dem Linux-Beta-Release,
damit die Beta in der heutigen Fassung bleibt.
