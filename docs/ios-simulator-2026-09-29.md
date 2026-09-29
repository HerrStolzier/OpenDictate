# iOS-Simulator: Installation geprüft, Bedienung blockiert

Stand: 29. September 2026. Fortsetzung des [Buildnachweises](ios-simulator-2026-09-28.md)
nach Bastis konkreter Freigabe für den Simulator-Test in [APPROVALS](../APPROVALS.md).

## Geprüft

- Kandidat: iOS-Quellen aus `e416a3d`, unverändert in PR #34, Head `7973d3a`.
  Die beiden Binärhashes stimmen mit `candidate-manifest.json` des Buildnachweises
  überein. Kein neuer Build oder Quellcodewechsel.
- Bereits gestarteter iPhone-18-Pro-Simulator, iOS 27.0 (24A434),
  Geräte-ID `BA2BD038-BA76-4B0F-8005-C036B2F80D77`.
- `com.opendictate.ios.keyboarddemo` erfolgreich installiert und gestartet.
  Screenshot und Accessibility-Ausgabe zeigen die Anleitungsoberfläche mit
  dem Hinweis auf vorbereiteten synthetischen Text und fehlende Aufnahme.

## Konkrete Prüfsperre

Die iOS-Einstellungen starten und sind lesbar. Zwei über XcodeBuildMCP
ausgeführte Klicks auf „Allgemein“ melden Erfolg, öffnen aber keine Unterseite.
Auch die Eingabe „Tastatur“ ins Suchfeld meldet Erfolg, ohne im Feld sichtbar
zu werden. Die anschließend erhobenen Screenshots und UI-Ausgaben zeigen
weiter die Einstellungsübersicht. Ein zweiter Bedienweg über die native
Device-Hub-Oberfläche endet zweimal mit einem Timeout.

Damit sind Tastaturaktivierung, Safari-Einfügung, Feldwechsel und sicheres
Passwortfeld **nicht geprüft**. Die Ursache der fehlenden Bedienwirkung ist
nicht belegt; dies ist kein nachgewiesener Fehler der OpenDictate-Tastatur.
Basti wurde um einen einzelnen manuellen Klick auf „Allgemein“ gebeten, um
normale Bedienbarkeit von der automatisierten Steuerung zu unterscheiden.
Es wurden keine Systemdienste neu gestartet oder Einstellungen zur Umgehung
der Sperre verändert. PR #34 bleibt Entwurf; keine Zusammenführung.

## Bereinigung und Belege

Die eigene Test-App wurde wieder deinstalliert. `simctl get_app_container`
findet sie anschließend nicht mehr. Die Tastatur wurde nicht aktiviert.
Der eigene Python-Fixture-Server auf `127.0.0.1:8766` wurde beendet;
anschließend lauscht dort kein Prozess. Sein Log enthält keine Seitenabrufe,
eine Testseite wurde in Safari nicht geöffnet. Der von Basti bereits geöffnete
Simulator bleibt für den erbetenen manuellen Prüfklick verfügbar.

Keine Aufnahme, Anbieteranfrage, Zugangsdatenänderung oder Geräteinstallation
auf einem echten iPhone/iPad. Keine Änderung am Produktionscode.

Lokale Belege: `~/.codex/artifacts/opendictate/ios-simulator-20260929/`:
`host-app-launched.jpg`, `settings-input-blocked.jpg`, `blocked-ui.json` und
`fixture-server.log`. Wiederholung nach Klärung der Bedienbarkeit:
[bestehender Prüfplan](../ios/PRUEFPLAN.md). Die Freigabe muss für denselben
unveränderten Testumfang nicht erneut eingeholt werden.
