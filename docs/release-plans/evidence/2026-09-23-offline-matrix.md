# Plan 1 · Lokale Einfügematrix am 23. September 2026

**Kandidat:** Quellstand `bd3630f605feff1ef64598ccab85511f944662c5`,
`DeliveryMatrixPreview` aus demselben Stand. Der Debug-Fixture-Pfad verwendet
`DictationFlow` und `PasteboardInserter` mit künstlichem Transkript. Er verwendet
weder Mikrofon noch OpenAI, Keychain, globale Kürzel oder Aufnahmedateien.
Die lokale Browserseite ist `scripts/fixtures/delivery-matrix.html`.

| Fall | Sichtbares Ergebnis | Grenze |
|---|---|---|
| Native einzeilige Eingabe, vollständige Auswahl | Unicode-Text ersetzte die Auswahl; der AX-Feldwert war exakt die Vorlage. [Vorher](2026-09-23-matrix-native-single-before.png) · [Nachher](2026-09-23-matrix-native-single-after.png) | Künstliches Transkript |
| Native mehrzeilige Eingabe, Auswahl „MARKIERUNG“ in der Mitte | Vor- und Nachtext blieben erhalten; Zeilenumbruch, Emoji und kombinierendes Zeichen stimmten im AX-Feldwert exakt. [Vorher](2026-09-23-matrix-native-multiline-before.png) · [Nachher](2026-09-23-matrix-native-multiline-after.png) | Künstliches Transkript |
| Safari-`input`, vollständige Auswahl | Text wurde sichtbar eingefügt. Der lokale Vergleich der tatsächlichen `input.value` meldete **Ist 45, Soll 46 UTF-16-Einheiten, erste Abweichung 34**: Safari stellte `e` + kombinierenden Akzent als vorgeformtes `é` dar. [Vorher](2026-09-23-matrix-safari-input-before.png) · [Nachher](2026-09-23-matrix-safari-input-after.png) · [Vergleich](2026-09-23-matrix-safari-input-exact.png) | Die strikte Zeichenfolgen-Abnahme ist nicht bestanden; der sichtbare Text ist kanonisch gleichwertig. Keine Änderung am allgemeinen ⌘V-Pfad vorgenommen. |
| Feldwechsel innerhalb derselben nativen App während fünf Sekunden künstlicher Verarbeitung | Startfeld A blieb nach dem Wechsel unverändert; das dann fokussierte Feld B erhielt den gesamten mehrzeiligen Testtext. [Nachher](2026-09-23-matrix-native-focus-switch.png) | Künstliches Transkript; keine Feldbindung durch den bestehenden Pfad |
| Appwechsel von Safari zum nativen Testfenster während fünf Sekunden künstlicher Verarbeitung | Safari wurde als Start-App erfasst. Nach dem Wechsel erhielt deren ausgewähltes `textarea` den gesamten sichtbaren Testtext; `NSWorkspace.frontmostApplication` war nach der Übergabe Safari. [Vorher](2026-09-23-matrix-cross-app-before.png) · [Nachher](2026-09-23-matrix-cross-app-after.png) | Künstliches Transkript; der AX-Wert zeigte den Akzent vorgeformt, ein exakter Seitenvergleich wurde hier nicht durchgeführt |

Die Fixture meldet `deliveryUnconfirmed`, weil der normale ⌘V-Befehl keine
Erfolgsbestätigung liefert. Der Zieltext wurde deshalb zusätzlich im Feld
und, wo vorhanden, mit dem lokalen Vergleich geprüft. Die beiden Fokusfälle
bestätigen den alten Ablauf für diese konkreten Fenster: Start-App reaktivieren,
im **dann** fokussierten Feld einfügen. Sie belegen keine allgemeine Garantie
für jedes Programm oder für einen echten Providerlauf mit Fokuswechsel.

Weitere Matrixfälle (`textarea`, `contenteditable`, `iframe`, Obsidian sowie
Anfang/Mitte/Ende je Kategorie) sind mit dieser Sitzung noch nicht vollständig
abgenommen. Der Safari-Zeichenfolgenbefund muss für die Release-Abnahme
ausdrücklich bewertet werden; die Paste-Implementierung wurde hier nicht
verändert.
