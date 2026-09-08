# Lokaler Seitenentwurf

Auftrag: kleine deutsche Produktseite zu OpenDictate als lokale Entscheidungsgrundlage. Keine Veröffentlichung, Installation, API-Aufrufe oder Änderungen an der App.

Umsetzung: eigenständige statische Seite ohne Abhängigkeiten. Die Demo ist illustrativ und nimmt kein Audio auf. Aussagen basieren auf README.md und PRIVACY.md des Projekts. Kein Download wird angeboten.

Vorschau aus diesem Ordner: `python3 -m http.server 4317 --bind 127.0.0.1`.

Abnahme: HTML-Struktur und lokale Ressourcen prüfen, HTTP-Antwort prüfen, lokale Vorschau öffnen. Browser-Abnahme am 2026-09-08 durchgeführt: Desktop sowie 390 und 320 Pixel Mobilbreite visuell geprüft; Sprunglinks, Rücksprung und Tastaturweg (Zum Inhalt → Ablauf) erfolgreich. Kein horizontaler Überlauf bei 320 Pixel. Vergrößerung auf 200 Prozent weiterhin nicht geprüft. Kein Build-Schritt erforderlich, da HTML und CSS direkt ausgeliefert werden.
