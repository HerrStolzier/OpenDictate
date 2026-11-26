# Machbarkeit: fremde Textfelder auf dem Mac lesen · 26. November 2026

Dieser Bericht belegt nur den hier genannten Lauf. Er ist keine Abnahme einer
Funktion und ändert nichts am Verhalten der App: OpenDictate liest heute keine
fremden Textfelder ([PRIVACY.md](../PRIVACY.md)).

## Frage

Kann eine Mac-App mit der Bedienungshilfen-Erlaubnis den Inhalt des
fokussierten Textfelds anderer Programme lesen? Das ist die Voraussetzung für
das „Lernen aus Korrekturen“ in der [ROADMAP](../ROADMAP.md) (Zeile Vokabular).
Bisher galt das als unsicher.

## Aufbau

- Mac mini, macOS 27.2.1. Wegwerf-Prüfprogramm „AXProbe“, lokal ad-hoc
  signiert, nicht im Repository. Bedienungshilfen-Erlaubnis nur für die Dauer
  der Läufe erteilt und danach wieder entfernt.
- Nur eigene Testfenster mit eigenem Testtext; laufende Programme blieben
  unberührt. Das Protokoll enthält nur Metadaten (Weg, Programm, Feldtyp,
  lesbar ja/nein, Länge, Fehlercode), nie Inhalte.
- Lesewege: `AXFocusedUIElement` mit `AXValue`, `AXSelectedText`,
  `AXStringForRange`, `AXSelectedTextRange`; für Chromium vorher
  `AXEnhancedUserInterface`/`AXManualAccessibility`; Änderungen per
  `AXObserver` (`AXValueChanged`).
- Zwei Läufe von je 53 Sekunden; vor Lauf 2 wurde die Suche nach Webfeldern
  korrigiert.

## Ergebnis

| Programm | Feldinhalt lesbar | Beleg aus dem Protokoll |
| --- | --- | --- |
| TextEdit | ja | Länge 27 = Testtext auf allen vier Wegen, Fehlercode 0 |
| Terminal | ja, ganzes Fenster | Länge 406 mit Testtext, Cursorposition lesbar |
| Chrome, Webfeld | ja | zuerst Fehler −25212; nach Einschalten des Bedienungshilfen-Modus Länge 29 = Testtext |
| Chrome, Änderungen live | ja | zwei `AXValueChanged`-Meldungen mit Testtext in 10 Sekunden |
| Passwortfelder (Safari, Chrome) | nein | Länge sichtbar, Inhalt nicht (kein Testtext), `AXSelectedText` −25212 |
| Safari, normales Webfeld | nicht gemessen | Die Probe fand das Feld nicht; Fehler der Probe, kein Beleg für „geht nicht“ |
| Notizen, Electron-Programme | nicht gemessen | ausgelassen |

## Folgerung

Technisch kann eine Mac-App mit Bedienungshilfen-Erlaubnis fremde Textfelder
lesen, in nativen Programmen sofort und in Chromium-Browsern nach Einschalten
von deren Bedienungshilfen-Modus, auch fortlaufend. Passwortfelder bleiben
geschützt. Die Grenze für OpenDictate ist damit nicht die Technik, sondern das
Datenschutzversprechen: Lesen bräuchte einen eigenen, standardmäßig
ausgeschalteten Schalter und eine geänderte [PRIVACY.md](../PRIVACY.md). Darüber
ist nicht entschieden.

Offen: Safari-Webfelder, Notizen, Electron-Programme, ältere macOS-Versionen.
Nach großen macOS-Updates gilt das Ergebnis nur nach einem neuen Lauf.
