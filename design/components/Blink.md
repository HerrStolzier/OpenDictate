# Blink

Blink ist die Figur von OpenDictate: ein Block-Cursor mit Beinen und Turnschuhen, der jeden App-Zustand vorspielt.

**Was du übergibst:** `state` (`bereit`, `hoert`, `schreibt`, `eingefuegt`, `hoppla`), optional `size` (Höhe in px), `still`, `framed`, `glow`, `label`.

**Wann:** Eine Figur pro Ansicht. In der App zeigt Blink den aktuellen Zustand, auf der Website stellt er das Produkt vor. Immer neben einem Wort, das den Zustand nennt („Hört zu“, „Eingefügt“), nie Blink allein als einzige Information.

**Zustände**

| state | was Blink tut |
| --- | --- |
| `bereit` | steht, der Körper blinkt, die Beine bleiben stehen |
| `hoert` | Schallbögen kommen von links, die Sohlen blinken in `rec` |
| `schreibt` | rennt nach rechts, hinter ihm entsteht Text |
| `eingefuegt` | hüpft am Ende der eingefügten Zeile, ein Funkeln in `warn` |
| `hoppla` | Bildstörung in `rec` und `glitch`, Sohlen leuchten `rec` |

**Do**
- Ganze Pixel: `size` als Vielfaches von 50 (100, 150, 200 …), dann landet jede Zelle auf einem Bildschirmpixel.
- `framed` setzen, wenn mehrere Zustände nebeneinanderstehen, damit sie auf einer Linie stehen.
- `still` für Screenshots, Druck und alles unter 100 px.
- Unter 48 px nicht diese Komponente nehmen, sondern die pixelgenauen Dateien `blink-32.svg` und `blink-16.svg` aus den Logos.

**Don't**
- Kein Gesicht, keine Arme, keine Accessoires. Blink drückt sich nur über Haltung, Bewegung und die Sohlen aus.
- Nicht drehen, spiegeln oder weichzeichnen. Leuchten nur über `glow`.
- `rec` an den Sohlen nur, wenn wirklich aufgenommen wird oder ein Fehler vorliegt.
