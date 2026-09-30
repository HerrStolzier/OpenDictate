# iOS Aufnahme-/Tastaturkopplung: vorbereiteter Kandidat

Stand: 30. September 2026. Ausgangspunkt ist `000e18e` (PR #34 integriert).
Basti beauftragte nach dem bereinigten reinen Texttest die Fortsetzung mit
„go“. Dieser Bericht beschreibt die **Offline-Vorbereitung**, keine reale
Aufnahmeabnahme. [Ziel](ios-direction.md), [Prüfplan](../ios/PRUEFPLAN.md),
[Freigaben](../APPROVALS.md).

## Geschützter Ablauf

Bewusst in der Haupt-App starten → manuell zu Safari wechseln → in der
Tastatur stoppen → markierten synthetischen Text bewusst einfügen. Die
Tastatur nimmt nicht auf und startet keine andere App. Kein Provider oder
API-Schlüssel. Höchstens drei lokale WAV-Dateien à maximal 15 Sekunden;
kein Löschen der einzigen Datei bei Fehlern oder Abbruch.

Vor den isolierten Tests festgehaltene Fehlerfälle: alte Sitzungs-ID,
abgelaufene Aufnahme/Ergebnisse, Einfügen vor Abschluss oder nach Abbruch,
konkurrierende Zustellversuche, zu große/ungültige Metadaten, falsche Version,
Zeitpunkte aus der Zukunft, fehlender Vollzugriff/App-Gruppe, Einrichtung nach
aktivierter Audio-Sitzung fehlgeschlagen, Unterbrechung und Encoderfehler.
Die neuen Fixtures prüfen die echte Dateischnittstelle der Bridge, keine
Test-Exports oder nachgebauten SDK-Mocks. Hardwarefälle bleiben separat offen.

## Bisher ausgeführte Prüfung

| Prüfung | Ergebnis und Reichweite |
|---|---|
| `swift test -Xswiftc -warnings-as-errors` | 80 App-, 29 Core- und 6 Bridge-Tests bestanden. Offline; kein Mikrofon oder Anbieter. |
| `swift test -Xswiftc -warnings-as-errors --filter RecordingBridgeTests` | Sechs Bridge-Tests bestanden, einschließlich Abbruch, gültiger übergroßer JSON-Fixture und gebundener Bedienaktion. Acht konkurrierende Dateizugriffe ergeben genau einen Claim. |
| Strict Swift-Format | App, Core, Package und beide iOS-Quell-/Testverzeichnisse bestanden. |
| Python-Werkzeuge | Acht vorhandene Offline-Tests bestanden. |
| Bash-Syntax | Sieben vorgeschriebene Skripte und geändertes iOS-CI-Skript bestanden. |
| Xcode Debug für Simulator und generisches iOS-Gerät | Beide unsigned Builds bestanden, Swift-Warnungen als Fehler. Kein Start oder Installation. |
| Kompilierte Plists | Nur Host enthält Mikrofontext und `UIBackgroundModes = [audio]`; Tastatur fordert Vollzugriff an, enthält keine Mikrofon-/Hintergrunddeklaration. Beide Quellentitlements nennen dieselbe App-Gruppe. |

Die vollständigen Logs und der vorab festgehaltene Vertrag liegen lokal unter
`/Users/basti/.codex/artifacts/opendictate/ios-recording-coupling-20260930/`.
Die genaue Kandidatenbindung und die unabhängigen Nachprüfungen liegen dort
in `review-manifest-v3.json` und `verification-v3.json`. Eigene UUID-Dateifixtures wurden entfernt; keine WAV-Aufnahme
entsteht durch diese Prüfungen.

## Unabhängiger Befund und Korrektur

Der bestehende Kritiker-Chat fand am ersten Patch einen konkreten P2-Fehler:
Ein angezeigter Stoppknopf konnte nach dem inzwischen eingetretenen Aufnahme-
Ende bereits synthetischen Text einfügen. Der Handler übernahm auch eine neue
Sitzungs-ID ungeprüft. Die Bridge bindet jetzt die angezeigte Aktion samt ID;
ein Stoppdruck bleibt Stopp, eine geänderte Phase/ID bewirkt keine Einfügung.
Während ein Finger den Knopf hält, wechselt dessen angezeigte Bedeutung nicht.
Ein neuer bewusster Druck ist nach der Aktualisierung nötig.

Die gezielte Nachprüfung fand eine unvollständige Berührungssperre:
`isHighlighted` endet beim Herausziehen des Fingers, obwohl dieselbe Berührung
fortbesteht. Die Sperre verwendet jetzt `isTracking`, das bis Ende oder Abbruch
der Berührung gilt. [Apple: Tracking](https://developer.apple.com/documentation/uikit/uicontrol/istracking).
Die Herausziehen-/Hineinziehen-Folge ist im Geräteprüfplan enthalten und noch
nicht als echte UIKit-Endwirkung geprüft.

Die abschließende unabhängige Nachprüfung bestätigt beide Befunde auf
Codeebene als geschlossen; keine weiteren wesentlichen Befunde im gezielten
Umfang. Simulator-/Gerätebuild und iOS-CI-Skript bestehen für die Korrektur.

Die sechste Fixture prüft genau diesen Aktions-/Sitzungswechsel an der von der
Tastatur verwendeten Dateischnittstelle. Der vorherige UIKit-Fehler ist durch
Codeprüfung belegt; ein unveränderter UI-Vorherlauf wurde nicht ausgeführt.
Diese Offline-Prüfung ersetzt nicht den späteren sichtbaren Gerätelauf.

## Einrichtung nach konkreter Freigabe

Basti bestätigte die konkrete Frage nach Apple-Gruppe, Profilen, Installation,
höchstens drei lokalen Aufnahmen à 15 Sekunden und Bereinigung mit
„Du hast die Freigabe“. Über Xcodes vorhandene Apple-Anmeldung wurden die
beiden Targets einer getrennten lokalen Signierungsprojektkopie dem bestehenden
Team zugeordnet. Der geprüfte Projekt-/Quellstand im Repository blieb dabei
unverändert. Xcode richtete `group.com.opendictate.ios.keyboarddemo` und passende
Entwicklungsprofile für App und Tastatur ein.

Beide eingebetteten Profile enthalten genau die benötigte App-Gruppe, das
genehmigte iPhone und die vorhandene Apple-Development-Identität. Der anschließende
Gerätebuild aus dem unveränderten Projekt besteht ohne weitere Provisionierungs-
Änderung. Host und Erweiterung bestehen `codesign --verify --deep --strict`.
Die Mikrofon-/Hintergrunddeklaration ist nur im Host vorhanden; die Erweiterung
fordert weiterhin Vollzugriff für die Kopplung an. Elf Implementierungs-/Projekt-
und Testdateien stimmen mit dem unabhängig geprüften Manifest überein.

Lokale Nachweise unter
`/Users/basti/.codex/artifacts/opendictate/ios-coupling-live-20260930/`:
`signed-build-final.log`, `profile-check.json`, `signed-candidate-manifest.json`.
Das Manifest bindet die beiden signierten Binärdateien per SHA-256. Keine
Aufnahme entstand durch Einrichtung oder Build.

## Offene Abnahme

Der geänderte Kandidat ist noch nicht installiert, aktiviert oder veröffentlicht.
Die aktuelle Entwicklerverbindung zum gekoppelten iPhone ist nicht verfügbar;
auch die direkte Lock-State-Abfrage schlägt fehl. Basti wurde um Anschließen
per USB und Entsperren gebeten. Das Gerät bleibt für Installation, Nachweisaufnahme,
Auslesen der eigenen Testdateien und Deinstallation bis zur bestätigten Bereinigung
angeschlossen. Die geladene Testseite und die Aufnahme benötigen selbst kein USB.

Die Freigabe für maximal drei lokale Aufnahmeprüfungen liegt vor. Der Prüfplan benennt
Kopplung, automatische Grenze, Fokuswechsel, einmalige Einfügung, Abbruch und
Bereinigung. Sichtbarer Mikrofonstopp, Hintergrund-Timer, tatsächliche Dauer,
iOS-Dateischutz und die neue Ansicht sind erst am Gerät zu prüfen.

Die [alten iPhone-Texttest-Nachweise](ios-device-2026-09-30.md) gelten nur für
den früheren Kandidaten. Diktatqualität, reale Transkription, zusätzliche
Ziel-Apps, Unterbrechungs-/Absturzfälle und vollständige Barrierefreiheit sind
damit weiterhin nicht abgenommen.
