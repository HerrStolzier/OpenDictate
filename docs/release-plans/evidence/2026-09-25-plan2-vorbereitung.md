# Plan 2: Vorbereitung am 25. September 2026

Ausgangsrevision: `2fe569a0af354dc32488ce5b23a0bcbfab9820bc`.
Auftrag: „Dann weiter mit plan 2, Nicht overengineeren bitte.“

## Zugang und konkrete Grenze

- Registrierung und Zahlung wurden von Basti bestätigt. Keine erneute Zahlung.
- Die angemeldete Apple-Accountseite zeigte bei der lesenden Prüfung noch
  „Schließen Sie den Kauf Ihrer Mitgliedschaft ab“ und den Hinweis, die
  Bearbeitung könne bis zu 48 Stunden dauern. Eine aktive Mitgliedschaft und
  Zugriff auf die Zertifikatsverwaltung sind damit noch nicht bestätigt.
- `security find-identity -v -p codesigning`: `0 valid identities found`.
- `xcode-select -p`: vorhandene Command Line Tools. `xcrun --find notarytool`
  findet das mitgelieferte Werkzeug. Keine zusätzliche Installation erfolgt.
- Weder Zertifikat/Schlüssel noch Notarisierungszugang wurden erzeugt oder
  verändert. Kein Apple-Upload, Appaustausch oder Live-Diktat wurde ausgeführt.

## Wechsel von der lokalen Signatur

`KeychainBridge.installHelperIfNeeded()` installiert den eingebetteten Helfer
nur, wenn `KeychainHelper-v1` noch fehlt. Ein bereits vorhandener Helfer mit
anderem Zertifikat wird abgelehnt, nicht ersetzt. Deshalb ist ein bloßer
Austausch der App gegen einen Developer-ID-Build für den bestehenden Test-Mac
nicht ausreichend. Das ist ein belegter Migrationspunkt im Code, noch kein
am Developer-ID-Kandidaten ausgeführter Fehlerlauf.

Nach Freischaltung und vor dem Appaustausch: neue Identität und Paket prüfen,
den vorhandenen Helfer kontrolliert sichern und ersetzen, vorhandene API- und
Recovery-Schlüssel sowie Aufnahmen erhalten und die notwendigen macOS-Abfragen
beobachten. Das konkrete Ziel und die Wirkung werden vor diesem Eingriff zur
Freigabe vorgelegt. Kein TCC-Reset und kein Löschen vorhandener Schlüssel.

## Abschlussgrenze

Plan 2 bleibt offen bis Developer-ID-Signierung, erfolgreiche Notarisierung,
Ticket-/Gatekeeper-Prüfung des entpackten endgültigen ZIPs, kontrollierter
Installation/Migration und den im Plan genannten echten Bedienungsprüfungen.
Offline-Bundleprüfungen belegen diese Schritte nicht.
