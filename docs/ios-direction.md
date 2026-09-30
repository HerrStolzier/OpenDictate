# iOS: gewünschter Ablauf und nächster Nachweis

Stand: 29. September 2026. Basti hat iOS ausdrücklich als **besonders wichtig**
benannt und den Ablauf **„Direkt in anderen Apps diktieren“** gewählt.
Eine App, die nur aufnimmt und anschließend Kopieren/Teilen anbietet, erfüllt
dieses Ziel nicht. Die zentrale Aufgabenliste bleibt [ROADMAP](../ROADMAP.md).

## Belegte technische Ausgangslage

Eine eigene iOS-Tastatur kann über `UITextDocumentProxy.insertText` Text in
das aktuelle Eingabefeld einfügen. Das ist ein dokumentierter Übergabeweg,
noch kein Nachweis eines funktionierenden OpenDictate-Ablaufs.
[Apple: Textinteraktionen](https://developer.apple.com/documentation/uikit/handling-text-interactions-in-custom-keyboards).

Die Tastaturerweiterung hat keinen eigenen Mikrofonzugriff. „Voller Zugriff“
ergänzt unter anderem Netzwerk und gemeinsamen App-Container, hebt diese
Mikrofongrenze aber nicht auf.
[Apple: Open Access](https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard).

Für eine App-Store-Verteilung darf die Tastatur außerdem keine anderen Apps
außer Einstellungen starten. Die gewünschte Kopplung von Aufnahme in der
Haupt-App und Textübergabe aus der Tastatur muss deshalb vor größerer
Umsetzung praktisch und anhand öffentlicher Schnittstellen geprüft werden.
Eine heimliche Daueraufnahme oder private APIs sind keine Lösung.
[Apple: Richtlinie 4.4.1](https://developer.apple.com/app-store/review/guidelines/#extensions).

Als zu prüfender Ablauf bleibt: Aufnahme bewusst in der Haupt-App starten,
manuell zur Ziel-App wechseln, über die Tastatur stoppen und das Ergebnis
bewusst einfügen. Apples Audio-Hintergrundmodus erlaubt einer aktiven Aufnahme,
beim App-Wechsel weiterzulaufen; Unterbrechungen bleiben möglich.
Das belegt weder die gesamte Kopplung noch eine spätere App-Store-Annahme.
[Apple: Aufnahme im Hintergrund](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/record).

Die Tastatur darf auch ohne vollen Zugriff nicht unbedienbar sein. Sichere
Felder, bestimmte Telefonnummernfelder und Apps, die eigene Tastaturen
ausschließen, begrenzen den Übergabeweg. Der Textproxy bindet ein Ergebnis
nicht dauerhaft an ein bestimmtes Feld. Verzögerte Antworten dürfen deshalb
keine automatische spätere Einfügung auslösen.

## Kleinster sinnvoller nächster Schritt

Ein begrenzter Machbarkeitsnachweis muss klären, wie Basti eine Diktiersitzung
bewusst startet, danach in der Ziel-App diktieren kann und sie eindeutig
beendet. Die Bedienfolgen und sichtbare Mikrofonaktivität müssen zuerst
feststehen. Ein konkreter App-Store-Verteilungsauftrag liegt noch nicht vor;
die Richtlinie wird geprüft, damit kein später unbrauchbarer Weg gebaut wird.

Abschlusskriterien vor einer Produktumsetzung:

- Ein erlaubter, nachvollziehbarer Aufnahme-/Tastaturablauf ist belegt.
- Der Text erreicht auf einem benannten iPhone/iPad das ausgewählte Feld in
  repräsentativen Ziel-Apps; Wechsel, Abbruch und verspätete Antworten führen
  nicht zum Einfügen in ein anderes Feld.
- Mikrofonstart und -ende sind sichtbar; nach Ende bleibt keine unbeabsichtigte
  Aufnahme aktiv. Ablehnung von Mikrofon- oder Tastaturrechten ist bedienbar.
- Grenzen bei geschützten Feldern und Apps, die eigene Tastaturen ausschließen,
  werden anhand der gewählten Zielprogramme geprüft und klar benannt.

Ein begrenzter Offline-Tastatur-Prototyp ist separat gebaut. Er prüft
zunächst vorbereiteten synthetischen Text und enthält weder Aufnahme noch
Provider oder App-Group-Übergabe. Der vollständige Diktierablauf bleibt offen.
Noch keine Installation auf einem iPhone/iPad, Aufnahme oder Übertragung
ausgeführt. Zielgerät, Mindest-iOS, genaue Sitzungsbedienung und erste
Zielprogramme sind offen. Der erste technische Prüfpunkt ist die erlaubte
Aufnahme-/Tastaturkopplung, nicht eine Portierung der Mac-Oberfläche.

## Lokale Build-Voraussetzung

Nach ausdrücklich genehmigter Installation aus Apples App Store ist Xcode
27.0 (Build 27A266a) vorhanden. Basti hat die Ersteinrichtung bestätigt;
`xcodebuild -version` und `-checkFirstLaunchStatus` funktionieren. Der aktive
Entwicklerpfad zeigt jetzt auf `/Applications/Xcode.app/Contents/Developer`.
Der benötigte arm64-Simulator für iOS 27.0 (24A434) ist verfügbar. Ein iPhone-18-Pro-
Simulator hat den Erststart abgeschlossen; Home-Bildschirm und Bedienhierarchie
sind geprüft. Der Download-Befehl endete zuvor mit Exit 70 wegen einer fehlenden
Personalisierungs-Manifestdatei bei der Registrierung. Deshalb wird die erfolgreiche
Startprüfung getrennt vom fehlgeschlagenen Downloader protokolliert. Der erste
Offline-Build von Host-App und Tastaturerweiterung war erfolgreich; die
Textübergabe war damals offen. [Datiertes Protokoll](ios-simulator-2026-09-28.md).
[Offizielle Xcode-Ausgabe](https://apps.apple.com/de/app/xcode/id497799835).

Die separat freigegebene Simulator-Fortsetzung am 29. September besteht auf
einem frischen Diagnosegerät: sichtbare Tastaturaktivierung ohne Vollzugriff,
bewusste synthetische Einfügung, normale Eingabe, Feld-/App-/Tastaturwechsel
und Systemtastatur im Passwortfeld. Das ursprüngliche Gerät bleibt erhalten;
seine fehlende Bildschirmtastatur ist weiterhin nicht ursächlich erklärt.
Testressourcen wurden bereinigt, das funktionierende Diagnosegerät ist
ausgeschaltet gespeichert. [Aktueller E2E-Nachweis](ios-keyboard-e2e-2026-09-29.md).
Am 30. September besteht auch der begleitete synthetische Textpfad auf
Bastis iPhone 15 mit iOS 27.0.1, mit beobachtetem Anfang und Endzustand
sowie Nutzerbestätigung der Touch-Folge und Systemtastatur im Passwortfeld.
[Gerätenachweis](ios-device-2026-09-30.md). Der reale Aufnahme-/Tastaturablauf bleibt offen.
