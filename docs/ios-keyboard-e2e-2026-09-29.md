# iOS-Tastatur: synthetischer Safari-Pfad bestanden

Stand: 29. September 2026. Geprüft ist ausschließlich der Offline-Textpfad
des Prototyps nach [Prüfplan](../ios/PRUEFPLAN.md), kein echtes Diktat.

## Kandidat und Umgebung

- Öffentlich erreichbarer Quellanker:
  [`bd81fda`](https://github.com/HerrStolzier/OpenDictate/commit/bd81fdafc22e8f8fa6c1012e15087f5b5a5a828c).
  Seine fünf Build-Quelldateien stimmen bytegenau mit dem lokalen damaligen
  Reviewstand `e416a3d` und dem Buildmanifest überein. Der lokale Reviewcommit
  selbst ist kein von einem frischen Repository-Checkout erreichbarer Nachweis.
- Das versionierte [Kandidatenmanifest](ios-prototype-candidate-2026-09-30.json)
  enthält diese Dateihashes und die Hashes beider getesteten Simulator-Binärdateien.
  Die installierten Binärhashes wurden damals gegen das lokale Buildmanifest
  geprüft. Für diesen Test kein neuer Build und keine Quelländerung.
- Xcode 27.0 (27A266a), iOS 27.0 (24A434), iPhone 18 Pro.
- Genehmigtes separates Gerät „OpenDictate Keyboard Diagnose 20260929“,
  `D3DB8C1A-C44E-4980-99E1-6D2E13B9AB61`. Es wurde frisch angelegt.
- Die Systemtastatur erschien hier in Safaris Adresszeile. Anders als beim
  alten Gerät war die weitere Prüfung möglich. Die genaue Ursache des alten
  Fehlers ist nicht bewiesen; der [Diagnosebericht](ios-simulator-2026-09-29.md)
  bleibt ein historischer Nachweis der erfolglosen Versuche dort.
- Prototyp installiert und über iOS-Einstellungen hinzugefügt.
  `RequestsOpenAccess=false` am tatsächlich verwendeten Bundle geprüft;
  Vollzugriff nicht aktiviert. Nur lokale Fixture unter `127.0.0.1:8766`.

## Sichtbare Ergebnisse

| Prüfung | Beobachtetes Ergebnis | Screenshot |
| --- | --- | --- |
| Anzeigen in Feld Eins | Feld bleibt leer; bewusst beschrifteter Testknopf sichtbar. | `prototype-visible.jpg` |
| Einmal einfügen | Genau der sichtbare Text `OpenDictate Testtext (synthetisch)` erscheint in Feld Eins. | `first-insert.jpg` |
| Normale Prototyp-Tasten | `q`, Leerzeichen, `w`, Return, `x`; danach löscht Rückschritt das `x`. | `normal-input.jpg`, `normal-delete.jpg` |
| Tastaturwechsel | Eigener Globus-Knopf öffnet die deutsche Systemtastatur; darüber `Hallo` eingegeben. | `system-after-switch.jpg`, `system-typed.jpg` |
| Feld Zwei | Nach Fokus-/Tastaturwechsel zunächst leer. Erst der Testknopf fügt Text ein; Feld Eins bleibt unverändert. | `second-before.jpg`, `second-once.jpg` |
| Zweiter bewusster Druck | Feld Zwei enthält zwei direkt aufeinanderfolgende Testtexte. | `second-twice.jpg`, `secure-field.jpg` |
| Passwortfeld | Leer und fokussiert; iOS-Systemtastatur sichtbar, kein OpenDictate-Testknopf. Kein Passwort eingegeben. | `secure-field.jpg` |
| Tastatur schließen | Kein Testknopf sichtbar; beide Texte bleiben erhalten. | `keyboard-dismissed.jpg` |
| App-Wechsel und Rückkehr | Von aktiver Prototyp-Tastatur zur Host-App und zurück: kein zusätzlicher Text. Danach Feld Eins gewählt und bewusst eingefügt; nur Feld Eins ändert sich. | `before-app-switch.jpg`, `host-switch.jpg`, `return-first-before.jpg`, `final-fields.jpg` |

Das sind sichtbare Interaktionen mit einem Simulator und künstlichem Text.
Die Einfügungen wurden visuell geprüft; keine bytegenaue DOM-Auswertung.
Die native Device-Hub-Automation bleibt eingeschränkt. Manche Tastatur- und
Webelemente fehlten im Accessibility-Snapshot. Deshalb erfolgten die Aktionen
über XcodeBuildMCP/sein vorhandenes AXe-Werkzeug mit expliziten Touch-Ereignissen
und anhand frischer Screenshots. Dies ist keine VoiceOver-Abnahme.

## Wiederholung und Belege

Nach demselben [Prüfplan](../ios/PRUEFPLAN.md) das gespeicherte Diagnosegerät
starten, den gebauten Kandidaten installieren, die Tastatur hinzufügen und die
Fixture lokal bereitstellen. Bei nicht brauchbaren semantischen Klicks:
`touch` mit aktuellem Element oder sichtbarer Position, Down/Up und 0,15 Sekunden
Haltedauer; nach Layoutwechsel neu beobachten. Keine festen Bildschirmpositionen
auf andere Geräte übertragen. Kein Mikrofon oder Anbieter nötig.

Lokaler Belegordner: `~/.codex/artifacts/opendictate/ios-simulator-20260929/`.
`fresh-e2e-manifest.json` bindet Gerät, Quellstand, Aktivierung und Screenshots.
Die Tabelle nennt die dort dauerhaft gesicherten Bilddateien. Vorher-/Nachher-
Inventare stehen in `before-fresh-device.json` und `after-fresh-device.json`.

## Bereinigung und Grenze

Test-App deinstalliert (`get_app_container`: nicht vorhanden), sichtbare
Tastaturliste wieder nur Deutsch und Emoji, eigener Safari-Tab geschlossen,
eigener Python-Server beendet (Port 8766 ohne Listener). Die vom Werkzeug
gestarteten Log-Helfer sind ebenfalls beendet. Das neue Gerät hat den Test
ermöglicht und bleibt daher gespeichert, ist aber ausgeschaltet. Alle vorher
vorhandenen Geräte sind erhalten; das ursprüngliche iPhone bleibt gestartet.
Die temporäre Werkzeug-Geräteauswahl wurde auf den ursprünglichen Wert gesetzt.

Offen bleiben der reale Aufnahme-/Tastaturablauf auf einem benannten iPhone,
Provider, Diktatqualität, weitere Ziel-Apps, Barrierefreiheitsabnahme und
Verteilung. Dieser bestandene Textpfad ist keine fertige iOS-Diktier-App und
keine Veröffentlichungsfreigabe.
