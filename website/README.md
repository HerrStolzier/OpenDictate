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
eigene Adresse, keine Einbettung in fremde Seiten) und beantwortet nur GET und
HEAD. `README.md`, `worker.js` und `wrangler.toml` gehören nicht zur Seite.
Der Worker selbst hat keine automatischen Tests; `scripts/website-worker.py`
prüft nur, dass Commit und Fingerabdrücke zusammenpassen, und ein Test hält die
Dateitypen in `worker.js` und im Skript gleich.

Cloudflare Web Analytics ist für die ganze Domain ausgeschaltet. Cloudflare
schaltet es bei kostenlosen Domains von selbst ein und fügt dann ein Zählskript
in jede Seite ein; das widerspricht „kein Tracking“ in der
Datenschutzerklärung. Nach jeder Änderung an der Domain prüfen, dass die
ausgelieferte Seite kein `static.cloudflareinsights.com` enthält. Die CSP würde
das Skript im Browser ohnehin blockieren.

Neue Fassung ausrollen, nachdem die Änderung auf `main` ist:

1. `python3 scripts/website-worker.py <commit>` trägt den Commit und die
   Fingerabdrücke in `worker.js` ein; `--check` prüft sie.
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
