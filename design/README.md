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
| [`assets/logos/`](assets/logos/) | Wortmarke und Blink als SVG |
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
| `generated/DesignTokens.swift` | macOS und später iOS: Farben je Theme, Maße und Schriftstile |

Die Python-Tests unter `scripts/tests/` schlagen fehl, wenn `tokens.json`
geändert wurde, ohne die Dateien neu zu erzeugen.

## Stand je Oberfläche

Noch keine Oberfläche nutzt diesen Ordner. Als erste wird die Website
umgestellt (Entscheidung vom 9. Oktober 2026 im
[Entscheidungs-Log](../PROJECT.md#entscheidungen)). Die laufenden Betas erscheinen in
der heutigen Optik; die Markenarbeit blockiert keine Beta
([PROJECT](../PROJECT.md#marken--und-gestaltungsrichtung)).

| Oberfläche | Wie sie das Designsystem übernimmt |
| --- | --- |
| Website (`website/`) | `tokens.css`, Schriften und SVGs in den Seitenordner kopieren; Entwurf der Startseite liegt in Claude Design |
| macOS-App | `DesignTokens.swift` nach `OpenDictateCore`, Schriften im App-Bundle registrieren, `.icns` aus `app-icon-1024.png`, Blink in Panel und Menüleiste (`blink-16.svg`); bauen und prüfen nur auf dem Mac |
| Linux | `gtk-colors.css` im Waybar-Beispiel, Blink als Symbol der Leistenanzeige |
| Windows | Der WPF-Prototyp braucht ein XAML-ResourceDictionary; dafür bekommt der Generator eine weitere Ausgabe |
| iOS | dieselbe Swift-Datei wie macOS |
