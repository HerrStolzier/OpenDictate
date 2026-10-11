# Progress

Fortschritt als Reihe von Pixelzellen; die nächste Zelle blinkt, solange gearbeitet wird.

**Was du übergibst:** optional `value` (0–1), `cells` (Anzahl, Standard 14), `busy` und `label`.

**Wann:** Während der Transkription („Transkription läuft …“) und beim Herunterladen von Updates. Wenn die Dauer unbekannt ist, `value` langsam laufen lassen und `busy` an.

**Do**
- Text in `label`-Stil daneben oder darunter, der sagt, was passiert.
- `aria-label` setzen, wenn mehrere Fortschritte auf einer Seite stehen.

**Don't**
- Keine Prozentzahlen erfinden, wenn die App sie nicht kennt.
