# Produktseite (Beta)

Auftrag: kleine deutsche Produktseite zu OpenDictate als lokale Entscheidungsgrundlage. Keine Veröffentlichung, Installation, API-Aufrufe oder Änderungen an der App.

Umsetzung: eigenständige statische Seite ohne Abhängigkeiten. Die Demo ist illustrativ und nimmt kein Audio auf. Aussagen basieren auf README.md und PRIVACY.md des Projekts. Seit dem 11. Oktober 2026 verlinkt die Seite den Pre-Release `v0.1.0-beta.10`; sie ist noch nicht über GitHub Pages veröffentlicht.

Vorschau aus diesem Ordner: `python3 -m http.server 4317 --bind 127.0.0.1`.

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
Designsystem nur Symbole für ⌥, ⇧ und Leertaste hat. Impressum und Datenschutz
verlinken auf support.opendictate.app (live seit 11. Oktober 2026). Vor dem Livegang der Website Cloudflare Web Analytics abschalten,
weil die Datenschutzerklärung „kein Tracking“ sagt. Headless Chromium: 1440, 375 und 320
Pixel Breite ohne horizontalen Überlauf, keine Konsolenfehler, alle fünf
Schriften geladen. Zoom und Tastaturweg wurden für diesen Stand nicht erneut
geprüft.
