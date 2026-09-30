# iOS Aufnahme-/Tastaturkopplung: Kandidat und Geräteprüfung

Stand: 30. September 2026. Ausgangspunkt ist `000e18e` (PR #34 integriert).
Basti beauftragte nach dem bereinigten reinen Texttest die Fortsetzung mit
„go“. Dieser Bericht trennt **Offline-Vorbereitung und begrenzte Gerätebelege**;
eine vollständige Aufnahmeabnahme ist noch offen. [Ziel](ios-direction.md), [Prüfplan](../ios/PRUEFPLAN.md),
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
Die Herausziehen-/Hineinziehen-Folge ist im Geräteprüfplan enthalten. Der
begleitete Gerätelauf unten ergänzt nun die sichtbare UIKit-Endwirkung samt
Nutzerbestätigung der Berührung; eine automatische Touch-Aufzeichnung gibt es nicht.

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
fordert weiterhin Vollzugriff für die Kopplung an. Alle zwölf Quell-/Projekt-/Test-
und CI-Dateien einschließlich `Package.swift` stimmen mit dem unabhängig geprüften
Manifest überein. Die spätere Geräteprüfung ändert diese Dateien nicht.

Lokale Nachweise unter
`/Users/basti/.codex/artifacts/opendictate/ios-coupling-live-20260930/`:
`signed-build-final.log`, `profile-check.json`, `signed-candidate-manifest.json`.
Das Manifest bindet die beiden signierten Binärdateien per SHA-256. Keine
Aufnahme entstand durch Einrichtung oder Build.

## Installation und Aktivierung

Nach Bastis Rückmeldung „ist dran“ besteht die direkte Geräteabfrage:
kein Passcode erforderlich, seit dem Start entsperrt. Die gefilterte App-Abfrage
findet vor Installation keine OpenDictate-App. Die signierten Binärhashes stimmen
mit dem vorbereiteten Kandidaten überein; Installation und Start bestehen.
Die installierte App meldet die erwartete App-Gruppe und verfügbaren Containerzugriff.
Das tatsächlich angesehene `host-installed.png` zeigt den Kopplungstest,
„Mikrofon aus. Keine Übertragung.“ und den verfügbaren Startknopf. Die eigene
Dokumentablage ist leer; noch keine Mikrofonaufnahme gestartet.

Die statische Safari-Fixture wurde als `data:`-URL geöffnet; ein Sitzungs-Kommentar
und SHA-256 in `fixture-session.json` binden die genaue Testseite. Kein Server
oder externe Ressource. `safari-initial.png` zeigt zunächst die Face-ID-Sperre,
keine geladene Testansicht. Basti wurde um Entsperren, Hinzufügen der Tastatur
mit zunächst deaktiviertem Vollzugriff und Auswahl in Feld Eins gebeten.

Basti bestätigte die sichtbare Tastatur. Das tatsächlich angesehene
`keyboard-without-full-access.png` zeigt die lokale Testseite, ein leeres
fokussiertes Feld Eins, die OpenDictate-Tasten und den gesperrten Knopf
„Kopplung braucht vollen Zugriff“. Der separate Texttest ist verfügbar.
Dies belegt die sichtbare Sperre, keinen ausgeführten Tastendruck oder Diktat.
Basti schaltete anschließend den Vollzugriff selbst ein. Das angesehene
`keyboard-ready-full-access.png` zeigt weiterhin ein leeres Feld Eins und
„Keine Aufnahmesitzung“; noch keine Aufnahme. Nach der Rückmeldung, der
Startknopf fehle, wurde nur die Haupt-App wieder geöffnet. Das angesehene
`host-reopened-before-test1.png` zeigt den blauen Startknopf und den Rückweg
„Safari“. Die Dokumentablage war dabei weiterhin leer. Die vorherige Ansicht
des Nutzers wurde nicht erfasst; die Ursache des fehlenden Startknopfs bleibt offen.

## Erster geführter Aufnahme-/Einfügelauf

Basti bestätigte nach bewusstem Start, manuellem Safari-Wechsel und Stopp:
„Mikrofon aus; Text erst nach Druck, genau einmal“. Das angesehene
`test1-result.png` zeigt in Feld Eins genau einmal
`OpenDictate Testtext (synthetisch)`. Die Bedienfolge und der Mikrofonstopp
sind Nutzerbeobachtungen, der Feld-Endzustand ist zusätzlich bildlich belegt.
Die spätere Aufnahme zeigt „Keine Aufnahmesitzung“; sie belegt den vorherigen
Stopp-/Einfügeknopf nicht. Keine Ursache für diesen späteren Zustand ableiten.

Die direkte Dokumentabfrage findet **zwei** eigene WAV-Dateien. Ihre tatsächlich
gelesenen WAV-Header ergeben:

| Datei in zeitlicher Reihenfolge | Dauer | Format | Direkt sichtbarer Dateischutz |
| --- | --- | --- | --- |
| Erste Datei | 15,000000 Sekunden | PCM, 16 kHz, Mono, 16 Bit | `0600`, vom Gerätebackup ausgeschlossen |
| Zweite Datei | 14,006625 Sekunden | PCM, 16 kHz, Mono, 16 Bit | `0600`, vom Gerätebackup ausgeschlossen |

Die eigene Aufnahmeablage hat `0700`. Die beiden Mac-Prüfkopien lagen nur
kurz in einem privaten `0700`-Verzeichnis, wurden als `0600` gesetzt und nach
Headerprüfung entfernt. Keine Audiodatei oder gesprochener Inhalt wurde in das
Repository übernommen. Nachweis: `test1-files.json`, `test1-audio-metadata.json`
und die zugehörigen Kopierprotokolle im oben genannten lokalen Live-Verzeichnis.
Die iOS-Dateischutzklasse ist im Quellstand gesetzt, wird von dieser
Dateiabfrage aber nicht als Laufzeitattribut ausgegeben.

Die direkte Abfrage von `recording-coupling-v1` über die öffentliche
App-Gruppen-Dateischnittstelle scheitert mit `CoreDevice.ActionError` 3.
Eine Abfrage der Gruppenwurzel gelingt, zeigt aber nur `Library`-Verzeichnisse.
Stopp-/Zustellmarker und `session.json` sind damit nicht unabhängig ausgelesen;
dies belegt weder deren Fehlen noch eine Ursache. Die Entitlements und die am
Gerät gemeldete Gruppe stimmen weiterhin. Keine Änderung am Kandidaten zur
Umgehung dieser Nachweisgrenze.

Die genaue Bedienfolge für die ersten zwei Aufnahmedateien ist nicht unabhängig
belegt. Beide Dateien wurden zum freigegebenen Maximum von drei gezählt. Die
verbliebene Aufnahme wurde für den folgenden Grenz-/Berührungstest verwendet.
Kein Löschen oder Neustart des Testbestands, um die Grenze zu umgehen.

## Letzte Aufnahme: native Grenze, Feld Zwei und Berührung

Nach Bastis „Feld Zwei bereit“ zeigt das angesehene
`field2-ready-confirmed.png` das leere, fokussierte zweite Feld mit OpenDictate.
Die Dokumentabfrage bestätigt weiterhin zwei WAV-Dateien. Die erneut geöffnete
Haupt-App zeigt den verfügbaren Startknopf und den erfolgreichen Abschlussstatus
der vorherigen Aufnahme (`host-before-final-test.png`).

Basti führte die letzte Aufnahme bewusst aus: sofort zurück zu Safari, den
unteren Stoppknopf halten, den Finger ohne Abheben herausziehen, 20 Sekunden
warten, zurückziehen und erst dann loslassen. Feld Zwei blieb dabei leer;
erst ein neuer Einfügedruck brachte genau einen Testtext. Er bestätigte diese
ganze Folge einschließlich automatischem Mikrofonende und wirkungslosem
wiederholten Einfügedruck mit „Ja, genau so funktioniert“.

Die Bildschirmvideo-Abfrage wird vom Gerät ausdrücklich nicht unterstützt
(`com.apple.dt.CoreDeviceError` 1001). Es entstand kein Video. Stattdessen
wurden zwölf Screenshots in einem begrenzten 55-Sekunden-Fenster gesichert.
Die tatsächlich angesehenen Bilder in `final-touch-snapshots/` ergänzen:

| Bild / Zeitpunkt im Aufnahmefenster | Sichtbare Wirkung |
| --- | --- |
| `06.png` / 30,347 Sekunden | Feld Zwei leer, Aufnahme-/Stoppaktion sichtbar. |
| `08.png` / 40,374 Sekunden | Feld Zwei weiterhin leer; hervorgehobener Stoppknopf. |
| `09.png` / 45,344 Sekunden | Feld Zwei leer; nach Ende ist die neue Aktion „TESTTEXT NACH STOPP EINFÜGEN“ verfügbar. |
| `10.png` / 50,364 Sekunden und `11.png` / 55,370 Sekunden | Genau ein synthetischer Text in Feld Zwei; „Texttest bereits verwendet“ gesperrt. |

Die Zeitpunkte stammen aus `capture-index.json`, nicht aus einem Touch-Trace.
Herausziehen, Zurückziehen, Loslassen und Mikrofonanzeige wurden von Basti
direkt beobachtet. Feld Eins blieb laut seiner Bestätigung unverändert;
es ist in diesen auf Feld Zwei ausgerichteten Bildern nicht gleichzeitig sichtbar.
`final-touch-result.png` bestätigt später denselben einzelnen Text. Der später
bereits abgelaufene Sitzungsstatus ist kein weiterer Einfügeversuch.

`final-files.json` enthält genau drei eigene WAV-Dateien. Die letzte hat
**15,000000 Sekunden**, PCM/16 kHz/Mono/16 Bit, `0600` und Backup-Ausschluss.
Alle drei Dauern zusammen ergeben 44,006625 Sekunden. Die private Mac-Kopie
wurde nach WAV-Headerprüfung entfernt (`final-audio-metadata.json`). Keine
weitere Aufnahme wurde gestartet. Der zusätzliche Host-Abbruch bleibt im
aktuellen Durchlauf offen.

## Bereinigung

Die ausdrücklich freigegebene Deinstallation von
`com.opendictate.ios.keyboarddemo` besteht. Die gefilterte App-Abfrage findet
danach keine Test-App; die direkten Abfragen ihres Dokument- und Gruppencontainers
sind danach nicht mehr verfügbar (`uninstall.json`, `apps-after-cleanup.json`,
`documents-after-cleanup.json`, `group-after-cleanup.json`). Die gemeinsame
Markerablage war bereits vor Deinstallation nicht direkt auslesbar; keine
separate forensische Löschprüfung behaupten. Alle privaten Mac-Audioprüfkopien
sind entfernt. Die benannte Apple-Gruppe und Profile bleiben erhalten.

Basti bestätigte anschließend: „Ja, beides funktioniert; Testseiten geschlossen“.
Dies belegt seine direkte Prüfung von Apples Tastatur und Diktieren sowie das
Schließen der eigenen Safari-Testseiten. Nach dem Schließen wurden keine
weiteren iPhone-Screenshots erstellt, um andere Nutzertabs zu erhalten. Der
USB-Durchlauf ist abgeschlossen; Basti kann das iPhone abstecken.

## Ergebnis und verbleibende Prüfgrenzen

Der begrenzte positive Aufnahme-/Tastaturpfad und die korrigierte
Berührungsfolge sind durch Gerätebilder, WAV-Header und Bastis Beobachtung
belegt. Die Test-App ist wieder entfernt. Vollständige Produktabnahme und
Veröffentlichung bleiben offen. Bereinigung und Apple-Diktierprüfung sind
abgeschlossen. Für weitere Geräteprüfung ist ein erneuter USB-Anschluss nötig.

Alle drei freigegebenen Aufnahmen sind verbraucht. Keine vierte Aufnahme ohne
neue konkrete Freigabe. Host-Abbruch, Unterbrechungs-/Fehlerfälle, unabhängiges
Auslesen der Gruppenmarker und die iOS-Dateischutzklasse im Laufzeitnachweis
bleiben ausdrücklich offen. Sie wurden nicht durch die positive Folge ersetzt.

Die [alten iPhone-Texttest-Nachweise](ios-device-2026-09-30.md) gelten nur für
den früheren Kandidaten. Diktatqualität, reale Transkription, zusätzliche
Ziel-Apps, Unterbrechungs-/Absturzfälle und vollständige Barrierefreiheit sind
damit weiterhin nicht abgenommen.

Der zusammengeführte lokale Nachweis `live-verification.json` bindet die
unveränderten zwölf Dateien, drei WAV-Header, angesehenen Gerätebilder,
direkte Deinstallationsprüfung und Nutzerbestätigung nach der Bereinigung.
