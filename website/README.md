# Lokaler Seitenentwurf

Auftrag: kleine deutsche Produktseite zu OpenDictate als lokale Entscheidungsgrundlage. Keine Veröffentlichung, Installation, API-Aufrufe oder Änderungen an der App.

Umsetzung: eigenständige statische Seite ohne Abhängigkeiten. Die Demo ist illustrativ und nimmt kein Audio auf. Aussagen basieren auf README.md und PRIVACY.md des Projekts. Kein Download wird angeboten.

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
