# iOS: gewünschter Ablauf und nächster Nachweis

Stand: 28. September 2026. Basti hat iOS ausdrücklich als **besonders wichtig**
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

Noch keine iOS-Implementierung, Geräteinstallation, Aufnahme oder Übertragung
ausgeführt. Zielgerät, Mindest-iOS, genaue Sitzungsbedienung und erste
Zielprogramme sind offen. Der erste technische Prüfpunkt ist die erlaubte
Aufnahme-/Tastaturkopplung, nicht eine Portierung der Mac-Oberfläche.

## Lokale Build-Voraussetzung

Die Prüfung am 28. September fand auf diesem Mac nur die ausgewählten
Command Line Tools. `xcodebuild` meldet, dass vollständiges Xcode erforderlich
ist; weder in den beiden üblichen Programmeordnern noch im Spotlight-Index
wurde Xcode gefunden. macOS 27.0 ist installiert, etwa 212 GiB sind frei.
Die Installation von Apples kostenlosem Xcode 27 samt benötigtem iOS-Simulator
ist angefragt, aber noch nicht genehmigt oder begonnen.
[Offizielle Xcode-Ausgabe](https://apps.apple.com/de/app/xcode/id497799835).
