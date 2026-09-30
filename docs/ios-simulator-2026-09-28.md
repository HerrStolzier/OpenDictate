# iOS-Simulator: abgegrenzter Nachweis vom 28. September 2026

## Umgebung

Nach der ausdrücklich genehmigten Installation aus Apples App Store und
Bastis eigener Bestätigung der Ersteinrichtung:

- macOS 27.0; Xcode 27.0, Build 27A266a.
- `xcodebuild -checkFirstLaunchStatus` endet erfolgreich.
- Aktiver Entwicklerpfad: `/Applications/Xcode.app/Contents/Developer`.
- iOS 27.0 (24A434), arm64; Simulatorgerät iPhone 18 Pro.
- `simctl bootstatus` bestätigt den abgeschlossenen Erststart. Home-Bildschirm
  und Accessibility-Hierarchie wurden direkt geprüft.

Der Download über `xcodebuild -downloadPlatform iOS -architectureVariant arm64`
endete mit Exit 70: Bei der Registrierung fehlte eine Personalisierungs-
Manifestdatei. Die anschließende Inventur zeigte den Runtime dennoch als
verfügbar. Der erfolgreich abgeschlossene Erststart belegt die tatsächliche
Startfähigkeit; er macht den ursprünglichen Download-Befehl nicht erfolgreich.
Es wurden keine Caches gelöscht, Schutzmechanismen umgangen oder zusätzlichen
Runtime-Pakete heruntergeladen.

Lokale Belege liegen unter
`~/.codex/artifacts/opendictate/ios-prototype-20260928/`:
`simulator-inventory.json` und `simulator-ready.jpg`.
Das ursprüngliche Installationslog liegt unter
`~/.codex/artifacts/opendictate/platform-resume-20260928/ios-runtime-install.log`.

## Umfang der nächsten Abnahme

Der erste Simulatorbuild von Host-App und Tastaturerweiterung besteht mit
dem iOS-27-SDK und deaktivierter Codesignierung. Das Log liegt im obigen
Artefaktordner unter `xcodebuild-build-final.log`. Geprüfter Quellstand:
`e416a3d71a0a7d62bed204aec7d401d4d0b586cf`, Basis `9bf554e`.
`candidate-manifest.json` bindet alle acht neuen Dateien und beide gebauten
Binärdateien per SHA-256. Der strikte Formatter-Lint der neuen Swift-Dateien,
Plist-Prüfung und Diff-Prüfung bestehen.

Der unabhängige Worktree-Kritiker prüfte exakt `e416a3d` gegen `9bf554e`:
keine wesentlichen Code- oder Testsicherheitsprobleme im begrenzten Umfang.
Er benannte die fehlende Commit-ID im ursprünglichen Build-Log als
Nachweislücke. Ein anschließender Root-Build vom sauberen Worker-Checkout
bestand erneut; `root-verified-build.log` protokolliert vor und nach dem Build
dieselbe volle Commit-ID. Der Quellbaum blieb unverändert. Damit ist diese
Zuordnungslücke geschlossen. Der Review ersetzt keine sichtbare Abnahme.

Installation, Start und Tastaturaktivierung des Prototyps im neuen Simulator
sind als konkreter Testblock angefragt, noch nicht freigegeben oder ausgeführt.
Der Simulatorstart selbst war Teil der genehmigten Umgebungseinrichtung.

Die bestehende Mac-Suite besteht außerdem mit dem neuen Xcode in einem eigenen
Scratch-Verzeichnis: 80 plus 29 Swift-Tests, vier vorgesehene Opt-in-Fälle
übersprungen. Die acht Python-Tests, bestehende Swift-Formatprüfung und sieben
Shell-Syntaxprüfungen bestehen ebenfalls. Mac-Quellen und bestehende
Testdeklarationen wurden dabei nicht geändert. Log: `mac-regression.log`.

Der separat entwickelte Tastatur-Prototyp verwendet ausschließlich
synthetischen Testtext. Zu prüfen ist dessen bewusste Einfügung in eine
lokale Safari-Fixture, einschließlich Feldwechsel, normaler Eingabe,
Tastaturwechsel und sicherem Passwortfeld. Ein erfolgreicher Build allein
belegt diese sichtbaren Wirkungen nicht.

Noch keine echte Aufnahme, Anbieteranfrage oder Installation auf einem
iPhone/iPad. Die Umgebung ist keine Abnahme einer Hintergrundaufnahme,
Diktiersitzung, App-Group-Übergabe oder App-Store-Tauglichkeit.

Produktziel und technische Grenzen stehen in [ios-direction.md](ios-direction.md);
die einzige Plattform-Aufgabenliste bleibt [ROADMAP.md](../ROADMAP.md).
