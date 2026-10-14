# Produktseite (Beta)

Auftrag: kleine deutsche Produktseite zu OpenDictate. Seit dem 11. Oktober 2026 ist sie unter https://opendictate.app live (Bastis „website live“).

Umsetzung: eigenständige statische Seite ohne Abhängigkeiten. Die Demo ist illustrativ und nimmt kein Audio auf. Aussagen basieren auf README.md und PRIVACY.md des Projekts. Seit dem 12. Oktober 2026 verlinkt die Seite den Pre-Release `v0.1.0-beta.12`.

Vorschau aus diesem Ordner: `python3 -m http.server 4317 --bind 127.0.0.1`.

## Auslieferung

Die Seite läuft als Cloudflare Worker `opendictate-website` auf
`opendictate.app`; `www.opendictate.app` leitet dauerhaft dorthin um, die
Adresse unter workers.dev ist aus. `worker.js` liefert die Dateien dieses
Ordners aus genau einem Commit (`COMMIT`). Jede Datei holt er einmal von
GitHub, prüft sie gegen ihren SHA-256-Fingerabdruck (`FILES`), legt sie im
KV-Speicher `opendictate-website` ab und liefert sie von dort aus. Besucher
verbinden sich nie mit GitHub. Der Worker setzt Sicherheitsregeln (CSP nur
eigene Adresse, keine Einbettung in fremde Seiten), beantwortet nur GET und
HEAD und liefert auf Anfrage Teilstücke einer Datei (`Range`), weil Safari
Videos nur so abspielt. Im KV-Speicher steht zu jeder Datei der geprüfte
Fingerabdruck als Metadaten, damit der Worker die Videos nicht bei jedem Abruf
neu durchrechnen muss. `README.md`, `worker.js` und `wrangler.toml` gehören nicht zur Seite.

Strengere Kopfzeilen (seit 14. Oktober 2026 im Repository, gelten erst ab dem
nächsten Ausrollen des Workers): Die CSP erlaubt keine `style`-Attribute mehr
(`style-src 'self'` ohne `'unsafe-inline'`) und verlangt
`upgrade-insecure-requests`. Größen und Verzögerungen setzt `site.js` darum
über `element.style`, nie als Attribut im HTML. Dazu kommen
`Cross-Origin-Opener-Policy: same-origin` und
`Cross-Origin-Resource-Policy: same-site`; Seiten unter opendictate.app (etwa
support.opendictate.app) dürfen Bilder und Videos einbinden, fremde Seiten
nicht. HSTS gilt im Worker zwei Jahre und für alle Subdomains (`www` und
`support` antworteten am 14. Oktober über HTTPS); für die HSTS-Preload-Liste
ist die Seite bewusst nicht angemeldet, das bräuchte Bastis Entscheidung.
Beobachtung per `curl -I` am 14. Oktober: Die Cloudflare-Zone setzt selbst
HSTS (ein Jahr mit Subdomains) und ersetzte damit den Wert des Workers; für
zwei Jahre muss die Zoneneinstellung mitziehen.
Der Worker selbst hat keine automatischen Tests; `scripts/website-worker.py`
prüft nur, dass Commit und Fingerabdrücke zusammenpassen, und ein Test hält die
Dateitypen in `worker.js` und im Skript gleich. In einem Klon mit voller
Geschichte schlägt der Test fehl, wenn der festgelegte Commit nicht in der
Geschichte von `HEAD` liegt; in flachen CI-Klonen wird diese Prüfung
übersprungen.

Cloudflare Web Analytics ist für die ganze Domain ausgeschaltet. Cloudflare
schaltet es bei kostenlosen Domains von selbst ein und fügt dann ein Zählskript
in jede Seite ein; das widerspricht „kein Tracking“ in der
Datenschutzerklärung. Nach jeder Änderung an der Domain prüfen, dass die
ausgelieferte Seite kein `static.cloudflareinsights.com` enthält. Die CSP würde
das Skript im Browser ohnehin blockieren.

Neue Fassung ausrollen, nachdem die Änderung auf `main` ist:

1. `python3 scripts/website-worker.py <commit>` trägt den Commit und die
   Fingerabdrücke in `worker.js` ein; `--check` prüft sie. Der Commit muss
   auf `main` liegen: Nach einem Squash-Merge gibt es den Commit des Zweigs
   dort nicht mehr, also danach auf den Merge-Commit neu festlegen.
2. `worker.js` deployen, am Mac mit `npx wrangler deploy` in diesem Ordner
   oder über Cloudflares API, und nur mit Bastis Wort.
3. Ausgelieferte Seite prüfen: Seite, Schriften, kein Zählskript.

Abnahme: HTML-Struktur und lokale Ressourcen prüfen, HTTP-Antwort prüfen, lokale Vorschau öffnen. Browser-Abnahme am 2026-09-08 durchgeführt: Desktop sowie 390 und 320 Pixel Mobilbreite visuell geprüft; Sprunglinks, Rücksprung und Tastaturweg (Zum Inhalt → Ablauf) erfolgreich. Kein horizontaler Überlauf bei 320 Pixel. Echter Browserzoom am 2026-09-08 in Helium über das Darstellungsmenü auf bestätigte 200 Prozent gesetzt: Einstieg, Beispiel, Ablauf, Informationen und Footer visuell geprüft; keine sichtbaren abgeschnittenen Texte oder horizontalen Überläufe. Sprungnavigation und Rücksprung geprüft. Zoom anschließend auf Originalgröße zurückgesetzt und separaten Testtab geschlossen. Kein Build-Schritt erforderlich, da HTML und CSS direkt ausgeliefert werden.

Textstand 2026-09-24: Der Ablauf nennt wieder den allgemeinen ⌘V-Weg in der
beim Start aktiven App, die mögliche Änderung des fokussierten Feldes und den
manuellen Zwischenablage-Rückweg. Die Plattformangabe entspricht dem geplanten
ersten Release für Apple Silicon und macOS 14+. Die Prüfung der lokalen Links
und Ressourcen bestand. Eine erneute visuelle Browser-Abnahme dieses Textstands
liegt nicht vor; der Browserzugriff auf die lokale Datei wurde durch die
URL-Richtlinie abgewiesen. Die Sichtprüfung vom 8. September gilt nur für den
damaligen Seitenstand.

Textstand 2026-10-02: „Gut zu wissen“ nennt Kosten pro Minute (0,0045 $ mit
gpt-transcribe, rund 0,1 Cent bei einem typischen Diktat von rund 15 Sekunden, rund 18,5 Stunden für 5 $), das
Transkriptionsmodell, eigenes Vokabular und die bewusste 90-Sekunden-Grenze,
übereinstimmend mit README.md und PROJECT.md. Lokale Vorschau über
127.0.0.1 im Browser geprüft: Desktop und 375 Pixel Mobilbreite, kein
horizontaler Überlauf. Zoom und Tastaturweg wurden für diesen Stand nicht erneut
geprüft.

Textstand 2026-10-08: Kennzeichnung „Beta“, Abschnitt „Loslegen“ mit drei
Schritten, Zeile „Übersetzung“ und Beta-Hinweis mit Links auf Pre-Release,
Installationsanleitung und Issue-Vorlage. Headless Chrome: Desktop sowie 375
und 320 Pixel Breite geprüft, kein horizontaler Überlauf. Zoom und Tastaturweg
wurden für diesen Stand nicht erneut geprüft.

Textstand 2026-10-11: Download-Link auf `v0.1.0-beta.10` (Build 10). Die
Kürzel-Zeile zeigt Fn halten statt ⌥⇧Leertaste und nennt die Kürzel-Abfrage
beim ersten Start; „Loslegen“ angepasst; der eigene Server ist „ab der
nächsten Version“ erwähnt. Headless Chrome: Desktop sowie 375 und 320 Pixel
Breite geprüft.

Textstand 2026-10-11: Seite im neuen Designsystem (Entwurf aus Claude Design,
am 9. Oktober abgenommen). Inhalte und Links der Beta-Seite bleiben: Beta,
„Loslegen“ in drei Schritten, Übersetzung, Pre-Release `v0.1.0-beta.10`,
Installationsanleitung und Rückmelde-Vorlage. `tokens.css` ist eine Kopie von
`design/generated/tokens.css`; Schriften sind aus den TTF in `design/fonts/` nach
WOFF2 umgewandelt, `fonts/OFL.txt` stammt von dort, `blink-32.svg` aus `design/assets/logos/`. Diese Dateien bei
Änderungen am Designsystem mitziehen. `site.js` spielt nur die Vorschau der
Anzeige ab und nimmt kein Audio auf; mit „Bewegung reduzieren“ steht sie still.
Notch-Anzeige und Blink sind als „Vorschau“ gekennzeichnet. Texte zu Kürzel
(Fn halten oder rechte Wahltaste) und eigenem Server folgen dem Textstand für
Build 10. „Fn“ steht als Text in Geist Pixel auf der Kappe, weil das
Designsystem nur Symbole für ⌥, ⇧ und Leertaste hat. Kontakt, Impressum und
Datenschutz verlinken auf support.opendictate.app (live seit 11. Oktober 2026).
Cloudflare Web Analytics ist aus, weil die Datenschutzerklärung „kein Tracking“
sagt (siehe [Auslieferung](#auslieferung)). Headless Chromium: 1440, 375 und 320
Pixel Breite ohne horizontalen Überlauf, keine Konsolenfehler, alle fünf
Schriften geladen. Zoom und Tastaturweg wurden für diesen Stand nicht erneut
geprüft.

Textstand 2026-10-12: Umbau rund ums Kostenargument (Bastis Entscheidung vom
12. Oktober). Titel „Diktieren ohne Abo“; direkt unter dem
Kopf „Was ein Diktat kostet“ mit 0 € (Modell auf dem eigenen Rechner), rund
0,1 ct pro Diktat mit OpenAI und 1,35 $ im Monat bei zehn Minuten am Tag
(10 × 30 × 0,0045 $). Neu sind „Kein Diktat geht verloren“ (24 Stunden, wie
README.md) und die Übersetzung mit einem lokalen Sprachmodell. Die alten
Abschnitte „Kosten“, „Gut zu wissen“ und die drei Schritte unter „Loslegen“
sind in „Was ein Diktat kostet“ und „Bevor du loslegst“ aufgegangen; der
Ablauf Mac → OpenAI → Mac im Datenschutz entfällt, weil es jetzt zwei Wege
gibt. Der Schlüsselbund-Punkt sagt nicht mehr, dass der Schlüssel nur an
OpenAI geht, weil ein eigener Server über HTTPS ihn laut PRIVACY.md bekommt.
„So richtest du es unter Linux ein“ zeigt auf „Eigenen Server verwenden“ in
linux/README.de.md, solange es den eigenen Server nur unter Linux
veröffentlicht gibt; mit dem Mac-Release zeigt der Link auf die Anleitung für
beide Systeme. Blink und die fünf Zustände
stehen weiter unten und kleiner (Vorschau, solange die Anzeige in keiner
veröffentlichten Version steckt). Am Mac gibt es den eigenen Server erst ab
Build 11. Bis dahin sagt die 0-€-Karte „Unter Linux schon jetzt, am Mac ab der
nächsten Version“ und „Was du brauchst“ nennt das Modell „ab der nächsten
Version“; beides fiel mit der Beta 12 weg. Headless Chromium für diesen Stand
erneut geprüft: 1440, 375 und 320 Pixel ohne horizontalen Überlauf, keine
Konsolenfehler, alle fünf Schriften geladen; Zustände bei 320 und 393 Pixel mit
Touch (nach jedem Antippen ist die Bühne ganz oben im Bild und die angetippte
Karte darunter sichtbar).

Textstand 2026-10-12, kurz: Die Seite folgt der Textvorlage „Startseite, kurz
und mit Recherche“ vom 12. Oktober (Bastis „Bauen“). Rund 370 Wörter in fünf
Abschnitten: Kopf, „Was ein Diktat kostet“ (0,1 ct vorn, 0 € an dritter
Stelle), „Kein Diktat geht verloren“, „Sprich Deutsch, schreib Englisch“ und
„Was mit deiner Aufnahme passiert“, dazu der Schluss „Probier es aus“. Die fünf
Zustände, „Bevor du loslegst“ und die Plattform-Liste sind weg; Blink bleibt
in der Bühne im Kopf. Der Link „So geht's“ zeigt auf `docs/lokales-modell.md`.
Für Suchmaschinen und geteilte Links trägt der Kopf Titel, Beschreibung,
Canonical, Open-Graph- und Twitter-Tags, ein Vorschaubild (`og.png`,
1200 × 630, Bildschirmfoto einer HTML-Komposition auf `--bg` Nacht: Wortmarke
`wordmark-nacht.svg` oben links, „Diktieren / ohne Abo.“ in Geist SemiBold
118 px mit der zweiten Zeile in `--signal`, `blink-32.svg` 320 px groß rechts,
unten „0,1 Cent pro Diktat · Mac und Linux · Open Source“ in Geist Mono 28 px), `apple-touch-icon.png`
(180 × 180 aus `design/assets/app-icon/app-icon-256.png`) und strukturierte
Daten (JSON-LD `WebSite` und `SoftwareApplication` mit Version
`0.1.0-beta.12`). `sitemap.xml` und `robots.txt` liegen daneben; der Worker
liefert dafür auch PNG und XML aus. Der Link „So geht's“ funktioniert erst, wenn
`docs/lokales-modell.md` auf `main` ist; vorher nicht ausrollen. Mit dem
Mac-Release ändern sich der Hinweis an der 0-€-Karte, die Download-Links und
die Version im JSON-LD; sobald die App etwas kostet, auch `offers` und
`isAccessibleForFree`.

Textstand 2026-10-12, Mac-Beta 12: Download-Links und JSON-LD-Version zeigen
auf `v0.1.0-beta.12` (Build 12 mit eigenem Server); die 0-€-Karte sagt „Am Mac
und unter Linux“. Der Chip „Vorschau“ an der Notch-Bühne ist weg; der Satz darunter
sagt, dass Notch-Anzeige und Blink ab Build 12 in der Mac-Beta sind.

Stand 2026-10-12, Fußzeile: Blink rennt nur noch, solange die ganze Laufbahn im
Fenster ist (Bastis Meldung, am Desktop wurde er beim Hochscrollen unten
abgeschnitten). Ist die Laufbahn teilweise verdeckt, bleibt er stehen; ist sie
ganz weg, springt er ungesehen an seinen Platz. Er läuft dem Scrollen mit
höchstens einer Bahnbreite in 0,6 Sekunden hinterher, statt zu springen.
Headless Chromium bei 1440 und 390 Pixel: beim schnellen Hoch- und
Runterscrollen höchstens ein Bild mit Bewegung am Fensterrand (Messverzug),
keine Konsolenfehler.

Stand 2026-10-13 abends, Erklärvideos und Datenschutz: Die fünf 3D-Clips mit
Blink liegen in `videos/`, je Clip in drei Formen. Die Fassung mit Ton ist
1920 × 1080 (`blink-0N-….mp4`, 2,9 bis 3,8 MB). Die stumme Schleife ist
1280 × 720 ohne den Abspann mit dem Schriftzug (`…-schleife.mp4`, 1,0 bis
1,3 MB). Die Standbilder gibt es als WebP für die Seite (`….webp`, rund 25 KB)
und als JPG für Vorschaubilder und JSON-LD (`….jpg`).

Auf der Startseite steht seit Bastis Rückmeldung (13.10., 18:29: Kästen
„generisch“, alle Clips starteten gleichzeitig) ein einziger Player mit fünf
Kapiteln statt vier gleicher Video-Kästen:
- **Abspielen:** Es läuft immer nur ein Clip. Der Player startet erst, wenn er
  zur Hälfte im Fenster ist, und geht danach von selbst zum nächsten Kapitel.
- **Bedienung:** Die Kapitel-Leiste zeigt den Fortschritt in Pixelzellen. „Ton
  an“ wechselt an derselben Stelle auf die Fassung mit Ton.
- **Bewegung reduzieren und Datensparen:** Der Player zeigt das Standbild und
  startet erst auf Klick. Ein von Hand angehaltener Clip bleibt angehalten.
- **Ohne JavaScript:** Der Browser zeigt seine eigenen Knöpfe, alle
  Kapiteltexte sind sichtbar, und die Kapitel führen zu `anleitungen.html`.
- **Pixelzeichen:** `play` und `pause` gibt es nur auf der Website, nicht im
  Designsystem.
- **Inhalt:** Die Kapiteltexte übernehmen die früheren Abschnitte „Kein Diktat
  geht verloren“ und „Übersetzen“; der Link `#uebersetzen` öffnet das passende
  Kapitel.

Der Kosten-Abschnitt heißt seit Bastis Hinweis vom Abend „Einmal zahlen,
nicht jeden Monat“: kein Abo, die Beta ist kostenlos, die fertige App kostet
später einmal ein paar Euro (Preismodell in PROJECT.md, wie README.md).

Der Vergleichswert „Ein Diktier-Abo kostet meist 8 bis 15 $“ stützt sich auf
die Preisseiten zweier bekannter Diktier-Apps, Stand 12. Oktober 2026: 8,49 $
und 15 $ im Monat beim Monatsabo (Recherche im geteilten Projektordner unter
`texte-review/recherche/marketing-techniken-2026-10-12.md`). Andere Apps werden
auf der Seite bewusst nicht genannt.

Der Abschnitt nach den Kosten ist das zweite Argument: „Deine Stimme bleibt
bei dir“, darüber die Einschränkung „Mit lokalem Modell“. Im Menü heißt er
„Privat“, damit „Datenschutz“ nur die Datenschutzerklärung meint. Er nennt bewusst kein Gerät, weil später alle
gängigen dazukommen. Ein Schaubild zeigt zwei Wege, lokal
(0 €, die Aufnahme bleibt auf dem Gerät) und mit OpenAI (0,1 ct, mit eigenem
Schlüssel). Das gilt für Mac und Linux mit lokalem Modell; mit whisper.cpp aus
der Anleitung geht Übersetzen noch nicht. Das iPhone kommt dazu, sobald die
iOS-App veröffentlicht ist.

`anleitungen.html` zeigt alle fünf Clips mit Ton, dazu den gesprochenen Text
zum Mitlesen, je eine deutsche Untertitelspur und je ein `VideoObject` im JSON-LD. Die Spuren
(`videos/*.vtt`) beginnen mit den Sprecheinsätzen aus `videos/quelle/3d/clips/`
im geteilten Projektordner und enden 0,3 s nach dem Satz, höchstens 50 ms vor
dem nächsten Einsatz. Der Player auf der Startseite zeigt keine Untertitel, weil
sie dort die Texte im Bild verdecken würden; er verweist auf diese Seite. Der iPhone-Clip (Nr. 6) kommt
erst mit der veröffentlichten iOS-App dazu.

Player und Weg-Grafik nehmen Farben, Abstände, Radien und Schriftgrößen aus
`design/generated/tokens.css`. Fest bleibt nur das Schwarz des Mac-Rahmens in
der Startanimation, weil es die Hardware zeigt.

Die Startanimation im Kopf der Seite läuft nur, solange sie im Fenster ist. Die
Schrift für den Einleitungstext wird vorab geladen.

Lighthouse 12.8 gegen die lokale Vorschau (ohne Kompression), Handy vorher und
nachher:

| Messung | Vorher | Nachher |
| --- | --- | --- |
| Leistung | 84 | 98 |
| Größter Inhalt | 3,9 s | 2,0 s |
| Blockierzeit | 220 ms | 0 ms |
| Seitengewicht | 455 KB | 190 KB |

Am Desktop war die Leistung vorher und nachher 100. Barrierefreiheit,
Best Practices und SEO liegen bei 100.

Headless Chromium bei 1440 und 390 Pixel, auch mit „Bewegung reduzieren“,
geprüft mit WebM-Ersatz, weil Chromium ohne H.264 kommt:
- kein horizontaler Überlauf und keine Konsolenfehler,
- nie mehr als ein Video auf der Seite,
- Kapitelwechsel und Pause verhalten sich wie beschrieben.

Die `Range`-Antworten des Workers (ganze Datei, Anfang–Ende, ab Stelle, letzte
n Bytes, ungültig, `If-Range`, HEAD) sind mit einer nachgebauten KV-Umgebung in
Node geprüft.

Live seit 2026-10-13, 20:53 UTC, auf Commit `f887c31`: Player mit fünf
Kapiteln, „Einmal zahlen, nicht jeden Monat“, „Mit lokalem Modell / Deine
Stimme bleibt bei dir“, Untertitel und Tokens (Bastis Karten „Live schalten“
19:06 und „Mit live“ 20:00 UTC). Per Browser Rendering geprüft: Überschriften,
Menü „Privat“, Kapitel und Weg-Grafik auf der echten Seite, alle fünf
Schleifen laden (1280 × 720, 13,6 bzw. 11,6 s), alle fünf WebP-Standbilder
laden, die Untertitel kommen als WebVTT.

Die erste Fassung mit vier Video-Kästen war live seit 2026-10-13, 17:25 UTC, auf Commit `d6e6adf` (Bastis Karte „Live
schalten“ um 17:02 UTC). Per Browser Rendering geprüft: alle Überschriften und
Clips auf Startseite und `anleitungen.html`, kein Zählskript; alle zehn Videos
spielen bis zum Ende vor (Dauer und Größe stimmen), alle fünf Standbilder laden.
