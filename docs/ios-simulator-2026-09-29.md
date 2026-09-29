# iOS-Simulator: Neustart ohne Behebung, Test bereinigt

Stand: 29. September 2026. Fortsetzung des [Buildnachweises](ios-simulator-2026-09-28.md)
nach Bastis konkreter Freigabe für den Simulator-Test in [APPROVALS](../APPROVALS.md).

Historischer Befund am ursprünglichen Gerät. Der später genehmigte Vergleich
mit einem frischen Gerät besteht einschließlich synthetischer Textübergabe:
[aktueller E2E-Nachweis und Bereinigung](ios-keyboard-e2e-2026-09-29.md).

## Erster Versuch: geprüft

- Kandidat: iOS-Quellen aus `e416a3d`, unverändert in PR #34, Head `7973d3a`.
  Die beiden Binärhashes stimmen mit `candidate-manifest.json` des Buildnachweises
  überein. Kein neuer Build oder Quellcodewechsel.
- Bereits gestarteter iPhone-18-Pro-Simulator, iOS 27.0 (24A434),
  Geräte-ID `BA2BD038-BA76-4B0F-8005-C036B2F80D77`.
- `com.opendictate.ios.keyboarddemo` erfolgreich installiert und gestartet.
  Screenshot und Accessibility-Ausgabe zeigen die Anleitungsoberfläche mit
  dem Hinweis auf vorbereiteten synthetischen Text und fehlende Aufnahme.

## Erster Versuch: konkrete Prüfsperre

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

## Erster Versuch: Bereinigung und Belege

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

## Fortsetzung: belegter Bedienweg

Auf Bastis anschließenden Reparaturauftrag wurde derselbe unveränderte
Prototyp erneut im bereits gestarteten Simulator installiert. XcodeBuildMCP
`touch` mit aktuellem `elementRef`, `down: true`, `up: true` und `delay: 0.15`
öffnete sichtbar Allgemein, Tastatur und die Tastaturliste. Darüber wurde
„OpenDictate Tastaturtest“ hinzugefügt. Die Liste enthält danach Deutsch,
Emoji-Symbole und die Erweiterung; Vollzugriff wurde nicht aktiviert.
Dies belegt einen funktionierenden Bedienweg, noch keine Ursache für das
vorher wirkungslose `tap`.

Die lokale Safari-Fixture wurde geöffnet. Textfeld Zwei ist sichtbar
fokussiert und leer; die Bildschirmtastatur bleibt verborgen. Die vorhandenen
XcodeBuildMCP-CLI-Befehle `toggle-software-keyboard` und
`toggle-connect-hardware-keyboard` melden jeweils das Senden des Kürzels,
ändern aber den sichtbaren Bildschirm nicht. Ein erneuter nativer Zugriff
auf Device Hub endet mit Timeout. Eine Hardwaretastatur-Verbindung ist damit
nicht als Ursache belegt. Basti bestätigte anschließend: Auch manuelles Cmd+K im iPhone-Fenster
hat keine sichtbare Wirkung.

**Zwischenstand vor dem späteren Neustart:** Test-App, aktivierte Testtastatur und eigener Safari-Tab
bleiben für die weitere Prüfung des Device-Hub-Tastaturmenüs vorbereitet. Der eigene
Fixture-Server läuft auf `127.0.0.1:8766` (Log `fixture-server-retry.log`).
Nach Abschluss sind eigener Tab, Test-App/Tastatur und Server zu entfernen;
der zuvor von Basti geöffnete Simulator bleibt erhalten. Die Bereinigung des
ersten Versuchs oben beschreibt nicht diesen späteren Zwischenstand.

Neue lokale Belege im selben Artefaktordner: `touch-retry.json` dokumentiert
die aktivierte Tastaturliste; `safari-keyboard-hidden.jpg` zeigt die leere
Fixture mit Fokus. Safari-Einfügung, normale Tasteneingabe, Feldwechsel und
Passwortfeld bleiben ungeprüft. PR #34 bleibt Entwurf. Keine Produktions-
oder Prototyp-Quelländerung, keine neuen Installationspakete, keine Aufnahme,
Anbieteranfrage, Zugangsdatenänderung oder Veröffentlichung.

## Ergänzende Diagnose nach manuellem Cmd+K

Ein dreisekündiges Prozess-Sample von Device Hub zeigt den Hauptthread in
der regulären AppKit-Ereignisschleife, keinen darin belegten Hänger
(`devicehub-sample.txt` im Artefaktordner). Schließen und erneutes Fokussieren
von Feld Eins in Safari funktionieren, zeigen aber keine Bildschirmtastatur.
iOS-Einstellungen > Tastatur zeigen eine Hardwaretastatur; deren Untermenü
bietet Layout, Sondertasten und Tastaturtyp, keinen sichtbaren Schalter zum
Einblenden. Danach wurde wieder Safari geöffnet.

Die [Apple-Hinweise zu Xcode 27](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)
bestätigen den Menüeintrag „Simulate Hardware Keyboard“ und eine Einstellung
zur Weiterleitung von Tastenkombinationen. Die tatsächlich sichtbare
Menüstruktur und der Schalterzustand dieser Device-Hub-Instanz sind wegen
der nativen Zugriffssperre noch nicht geprüft. Nächster Schritt: direkte
Sichtprüfung dieses Menüs, statt weitere Tastenkürzel zu wiederholen.
Apples bekannter Fehler beim Softwaretastatur-Umschalter betrifft ausdrücklich
iPad-Simulatoren; er erklärt diesen iPhone-Befund nicht nachweislich. Keine
Voreinstellung geändert, kein Dienst oder Simulator neu gestartet.

## Autorisierter Neustart und abschließende Bereinigung

Basti bestätigte „Ja, starte neu.“ für Device Hub und den iPhone-Simulator.
Zuvor berichtete er, dass auch das Ausschalten des Tastatursymbols und das
Trennen seiner Bluetooth-Tastatur keine Bildschirmtastatur hervorbringen.
Die Gegenprobe in Safaris eigener Adresszeile zeigte ebenfalls keine
Bildschirmtastatur (`native-address-keyboard-hidden.jpg`); es ist damit nicht
nur ein beobachtetes Verhalten der HTML-Testfelder.

Derselbe Simulator wurde mit `simctl shutdown` sauber heruntergefahren.
Device Hub beendete sich nach SIGTERM nicht; nach beendetem Simulator wurde
ausschließlich dessen Oberflächenprozess beendet (SIGKILL, PID 14325).
Anschließend wurden dasselbe Gerät und Device Hub neu gestartet. Bootstatus
meldet abgeschlossen, Device Hub hat PID 54118. Kein Simulator wurde gelöscht,
kein globaler CoreSimulator-Dienst neu gestartet und keine Voreinstellung
geändert. Der native Steuerungszugriff auf Device Hub endet weiter mit Timeout.

Auch nach diesem Neustart blieb Safaris fokussierte Adresszeile ohne
Bildschirmtastatur. Nach Entfernung unserer App wurde dieselbe Gegenprobe
wiederholt: weiterhin keine Bildschirmtastatur
(`after-restart-without-prototype.jpg`). Die Tastaturdienste InputUI und
TextInput.kbd liefen; die begrenzte Fehlerabfrage lieferte keine belegte Ursache.
Dies ist keine bestandene Abnahme und keine bewiesene Ursache in OpenDictate
oder Xcode. Ein getrenntes frisches Simulatorgerät wäre ein nächster möglicher
Vergleich mit Systemtastatur; zu diesem Zeitpunkt war es noch nicht angelegt.

Abschließende Bereinigung: `get_app_container` findet unsere Test-App nicht
mehr; die sichtbare Tastaturliste zeigt nur Deutsch und Emoji. Der eigene
Safari-Fixture-Tab wurde geschlossen, der eindeutig zugeordnete Python-Server
(PID 38794) beendet; Port 8766 hat keinen Listener. Der Simulator bleibt
geöffnet und gestartet. Nachweis: `cleanup-after-restart.json`. Keine echten
Aufnahmen, Anbieteranfragen, Zugangsdatenänderungen oder Veröffentlichung.
