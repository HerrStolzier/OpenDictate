OpenDictate ist eine Diktier-App für die Menüleiste: Tastenkürzel drücken, sprechen, nochmal drücken, und der Text landet in der App, in der man gerade war. Die Marke ist ein Terminal mit Charme. Ein dunkler Grund, ein grünes Signal, ein feines Pixelraster und Blink, ein Block-Cursor mit Beinen, der genau das tut, was die App tut.

## Stimme und Texte

- Deutsch, per du, kurze Sätze. Verben zuerst: „Nochmal senden“, „Auf GitHub ansehen“.
- Zustände heißen immer gleich: **Bereit**, **Hört zu**, **Schreibt**, **Eingefügt**, **Hoppla**. Fehler beginnen mit „Hoppla.“ und sagen sofort, was sicher ist: „Hoppla. Keine Verbindung. Deine Aufnahme ist gesichert.“
- Nur sagen, was die App wirklich tut: eigener OpenAI-API-Schlüssel, Schlüssel im macOS-Schlüsselbund, kein Tracking, Quellcode unter MIT-Lizenz, macOS 14 oder neuer auf Apple Silicon. Keine Versprechen zu fehlerfreier Erkennung, Geschwindigkeit oder Preis.
- Keine Emoji, keine Ausrufezeichen, keine Superlative.
- Die Wortmarke schreibt sich „opendictate“, im Fließtext heißt die App „OpenDictate“.

## Farben und Themes

- Drei Themes: **Nacht** ist der Standard, **Bernstein** und **Papier** sind gleichwertige Alternativen. Jede Farbe kommt aus einem Token, nie als fester Hex-Wert, damit alles mit dem Theme wechselt.
- Flächen: `bg` für Seite und Fenster, `surface` für Karten und Panels, `surface-sunken` für eingelassene Flächen wie die Bühne hinter Blink. `line` nur als Haarlinie zur Gliederung.
- Text: `ink` für Inhalte, `ink-muted` für Labels, Zeiten und Hinweise. Beide lesen sich auf `bg`, `surface` und `surface-sunken` in allen Themes.
- `signal` ist die Markenfarbe: Blinks Körper, der Hauptknopf, Fortschritt, aktive Zustände. Text auf einer `signal`-Fläche ist immer `on-signal`.
- `rec` heißt Aufnahme oder Fehler und steht nie allein: immer mit „REC“, „Hoppla“ oder einem Symbol.
- `signal-light`, `signal-shade`, `signal-deep`, `signal-ink`, `sneaker`, `sneaker-light`, `sole`, `floor` und `glitch` gehören zur Figur und zu Pixel-Elementen, nicht zu Flächen oder Text.
- Keine Verläufe auf Flächen. Einzige Ausnahme ist das leise Leuchten hinter Blink im App-Icon und im Hero (`glow`).

## Schrift

- **Geist Pixel** (`display`, `title`, `heading`) für die Wortmarke, Titel und Zustandsnamen. Sie hat nur einen Schnitt; nie fett faken, nie für Fließtext.
- **Geist** (`lead`, `body`, `strong`, `small`) für allen Fließtext.
- **Geist Mono** (`ui`, `label`, `code`) für Knöpfe, Zeiten, Labels, Terminal-Zeilen und Tastenkürzel.
- Die Schriftdateien liegen unter `fonts/` (SIL Open Font License, siehe `fonts/OFL.txt`). Auf Websites alternativ von Google Fonts laden: Geist, Geist Mono, Geist Pixel.

## Feines Pixelraster

- Pixel ja, aber fein. Pixel-Elemente sind aus kleinen Quadraten gebaut und werden mit `shape-rendering: crispEdges` gezeichnet, nie weichgezeichnet oder schräg gestellt.
- Kanten von Knöpfen und Tastenkappen haben **Stufenecken**: zwei Stufen zu je `pixel-step` statt einer Rundung. Karten und Panels dürfen `radius-card` haben.
- Übergänge innerhalb einer Pixelfläche entstehen durch Dithering (Schachbrett aus zwei Tönen), nicht durch Verläufe.
- Symbole im 12 × 12-Raster, angezeigt in `pixel-icon` (je Zelle 3 px). Größen immer als Vielfaches der Rastergröße, damit jede Zelle auf ganzen Bildschirmpixeln landet.

## Blink

- Blink ist ein Block-Cursor im Verhältnis 1 : 2 mit Beinen und Turnschuhen. Kein Gesicht, keine Arme, keine Accessoires. Er drückt sich nur über Haltung, Bewegung und die Sohlen aus.
- Seine Sohlen sind das Aufnahme-Licht: Sie leuchten in `rec`, solange zugehört wird, und bei einem Fehler. Sonst sind sie `sole`.
- Eine Figur pro Ansicht. In der App zeigt Blink den Zustand, immer zusammen mit dem Zustandswort.
- Größen: ab 100 px die Komponente `Blink` (Raster 20 × 40 für den Körper), darunter die pixelgenauen Dateien `blink-32.svg` und `blink-16.svg`. In der Menüleiste nur `blink-16.svg` beziehungsweise die einfarbige Silhouette.
- Im App-Icon steht Blink rechts neben dem Eingabezeichen „›“: Er ist der Cursor in der Eingabezeile.

## Bewegung

- Alles bewegt sich in Schritten (`steps()`), wie in einem alten Spiel, nie weich.
- Bereit: Körper blinkt im Takt von 1,1 s, die Beine bleiben stehen. Hört zu: Bögen pulsieren in 1,2 s, Sohlen blinken in 0,8 s. Schreibt: zwei Laufbilder im Wechsel von 0,18 s. Eingefügt: ein Hüpfer von 5 Pixeln in 1,4 s. Hoppla: Bildstörung, die alle 2,2 s ruckt.
- Bei „Bewegung reduzieren“ steht alles still und zeigt das erste Bild. Die Komponenten tun das von selbst; eigene Animationen müssen es auch.

## Logos, App-Icon und Symbole

- Wortmarke: `wordmark-nacht.svg` auf dunklem Grund, `wordmark-papier.svg` auf hellem Grund. Freiraum rundum mindestens die Höhe von Blinks Körper. Nicht verzerren, nicht umfärben, keine andere Schrift.
- App-Icon: `app-icon-1024.png`, `app-icon-512.png`, `app-icon-256.png` in macOS-Form, mit eingebautem Rand und Schatten. Für die `.icns`-Datei aus der 1024er-Datei erzeugen.
- Symbole: Aufnahme, Eingefügt, Fehler, Eingabe und die Tastensymbole ⌥ ⇧ Leertaste im 12 × 12-Raster (`PixelIcon`, `Keycap`). Geist Pixel hat kein ⌥, deshalb sind die Tastensymbole selbst gezeichnet. Keine Emoji, keine fremden Icon-Sets.

## Layout

- 4-px-Raster: `space-1` bis `space-16`. Karten haben `space-6` Innenabstand, Karten im Raster `space-4` Abstand, Seitenabschnitte `space-12`.
- Dunkel zuerst: Entwürfe immer in Nacht anlegen und in Papier gegenprüfen.

## Zugänglichkeit

- Text erreicht mindestens 4,5 : 1 in jedem Theme auf den Flächen, die sein Token nennt; `line` ist Gliederung, keine Grenze eines Bedienelements.
- Tastaturfokus: 2 px Abstand, dann 2 px `focus-ring`. Bei Knöpfen mit Stufenecken liegt der Ring außerhalb der Ecken.
- Zustände nie nur über Farbe oder Blink allein: immer mit Wort.
- Knöpfe sind 44 px hoch.
