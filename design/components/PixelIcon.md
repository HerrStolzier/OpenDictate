# PixelIcon

Symbole im 12 × 12-Pixelraster für Aufnahme, Eingefügt, Fehler und Eingabe.

**Was du übergibst:** `name` (`rec`, `check`, `error`, `prompt`), optional `size` (Vielfaches von 12, Standard 36), `tone` (`signal`, `rec`, `ink`, `muted`) und `label`.

**Wann:** In Zustandszeilen, Listen und Hinweisen. Jedes Symbol steht neben einem Wort; dann `label=""` übergeben, damit Screenreader es nicht doppelt vorlesen.

**Do**
- Größen 12, 24, 36, 48 px, damit die Pixel scharf bleiben.
- `rec` und `error` in `rec`, `check` und `prompt` in `signal`.

**Don't**
- Keine Emoji und keine Fremd-Icon-Sets daneben mischen. Neue Symbole im selben 12 × 12-Raster zeichnen.
