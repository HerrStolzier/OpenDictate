# iPhone-Test: begrenzter synthetischer Textpfad bestanden

Stand: 30. September 2026. Fortsetzung des bestandenen
[synthetischen Simulator-Tests](ios-keyboard-e2e-2026-09-29.md) mit Bastis
[Freigabe](archive/APPROVALS.md) für das angeschlossene echte Gerät.

## Ausgangsprüfung vor Installation

- iPhone 15, iOS 27.0.1 (24A446), per Kabel verbunden und gekoppelt;
  Entwicklermodus aktiv. Keine Gerätekennung oder Seriennummer hier gespeichert.
- Gefilterte Abfrage der installierten Apps: keine OpenDictate-App vorhanden.
- Unveränderter Kandidat `bb10df83644560b497add9329ce86205d8bdf4be`.
- Debug-Build für `generic/platform=iOS` mit `CODE_SIGNING_ALLOWED=NO`
  und `CODE_SIGNING_REQUIRED=NO`: **BUILD SUCCEEDED**.
- Signierter Build ohne Erlaubnis automatischer Provisionierungsänderungen:
  Exit 65; keine iOS-App-Development-Profile für
  `com.opendictate.ios.keyboarddemo` und `.keyboard` vorhanden.
- Lokale gültige Signieridentitäten: ausschließlich Developer ID Application.
  Beide üblichen lokalen Provisionierungsordner enthalten keine Profile.

## Reproduzierbarer Build

```sh
xcodebuild -project ios/OpenDictateKeyboardDemo.xcodeproj \
  -scheme OpenDictateKeyboardDemo -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$HOME/.codex/artifacts/opendictate/ios-device-20260930/DerivedData" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Lokale Nachweise im selben Artefaktordner: `device-build.log`,
`device-signing-check.log`, `device-provisioning-build.log` und
`candidate-manifest.json`.
Der Build belegt Kompilierbarkeit für ein echtes Gerät, keine Installation
oder sichtbare Funktion. Der Simulator-Nachweis wird nicht zur Geräteabnahme.

## Signierung und sichtbarer Start

Basti bestätigte die Einrichtung mit „go“ und meldete sich selbst in Xcode
an. Der erste automatische Versuch meldete ein bereits bestehendes
Entwicklungszertifikat ohne lokalen privaten Schlüssel und schlug Widerruf
vor. Dieses Zertifikat wurde **nicht widerrufen**. Über Xcodes
Zertifikatsverwaltung ließ sich stattdessen eine zusätzliche Apple-Development-
Identität für diesen Mac anlegen. Die bestehende Developer-ID-Identität bleibt
ebenfalls erhalten; `security find-identity` bestätigt beide lokalen Identitäten.

Nach Profilbereitstellung verwies ein Build auf eine nicht vorhandene
Profildatei. Download der Profile und ein frischer, getrennter Buildordner
führten zu **BUILD SUCCEEDED**. Keine Projekt- oder Quelländerung nötig.
Beide eingebetteten Profile enthalten das genehmigte iPhone, passende
Bundle-IDs und das richtige Team. `RequestsOpenAccess=false` bleibt erhalten.

Wiederholbarer signierter Build nach vorhandener Freigabe und Anmeldung:

```sh
xcodebuild -project ios/OpenDictateKeyboardDemo.xcodeproj \
  -scheme OpenDictateKeyboardDemo -configuration Debug \
  -destination 'id=<genehmigte Gerätekennung>' \
  -derivedDataPath "$HOME/.codex/artifacts/opendictate/ios-device-20260930/SignedDerivedData" \
  DEVELOPMENT_TEAM=K5AF446C3N \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
```

Der Quellstand ist `1e00093`; gegenüber dem Simulator-Kandidaten sind die
iOS-Quellen unverändert. Der öffentlich erreichbare Quellanker `bd81fda`
und die fünf Build-Dateihashes sowie getesteten Binärhashes stehen im
[versionierten Kandidatenmanifest](ios-prototype-candidate-2026-09-30.json).
`codesign --verify --deep --strict` besteht.
`devicectl device install app` bestätigt Installation,
`devicectl device process launch` bestätigt Start. Screenshot `host-launch.png`
wurde tatsächlich angesehen und zeigt die Prototyp-Anleitung auf dem iPhone.

Weitere lokale Belege: `device-signed-build.log` (fehlende Profildatei),
`device-signed-fresh-build.log` (erfolgreich), `signed-candidate-manifest.json`
mit Binärhashes, Profilprüfung und Kandidatenbindung. Kennungen des persönlichen
Geräts werden nicht in diesem Repository veröffentlicht.

## Reale Bedienprüfung mit synthetischem Text

Basti bedient das iPhone, die Hauptaufgabe prüft die sichtbaren Ergebnisse
über `devicectl`-Screenshots. Die native Device-Hub-Steuerung bleibt mit
Timeout blockiert. Dies ist ein begleiteter echter Gerätepfad mit künstlichem
Text, keine automatische Geräte-E2E und kein Diktat.

Die unveränderte `ios/fixtures/keyboard-focus.html` wurde als Base64-`data:`-URL
über `devicectl device process launch --payload-url` in Safari geöffnet.
Kein HTTP-Server, kein LAN-Zugriff und keine externe Ressource nötig.
Basti entsperrte Safari selbst per Face ID. Der Screenshot
`safari-after-unlock.png` zeigt die lokale Fixture mit zwei leeren Textfeldern.

| Prüfschritt | Ergebnis und Beleg |
| --- | --- |
| Aktivierung | Basti bestätigte das Hinzufügen ohne Vollzugriff; die Erweiterung ist anschließend im Screenshot sichtbar. |
| Feld Eins | Ein bewusster Testknopfdruck; genau einmal `OpenDictate Testtext (synthetisch)` und die aktive OpenDictate-Tastatur sichtbar (`first-device-insert.png`). |
| Feld Zwei | Nach Fokuswechsel und bewusstem Testknopfdruck genau einmal derselbe Text sichtbar (`second-insert-secure-field.png`). |
| Passwortfeld | Leer und fokussiert, keine OpenDictate-Tasten im Screenshot. Die Apple-Tastatur selbst fehlt in den Aufnahmen. Basti bestätigte ausdrücklich ihre Sichtbarkeit auf dem tatsächlichen Display: sowohl nach Wechsel von OpenDictate als auch nach vorheriger Wahl der Apple-Tastatur. Dieser Teil beruht auf seiner direkten Beobachtung, nicht auf einem Bildnachweis der Systemtastatur. |

Die zunächst vermutete fehlende Systemtastatur ist damit kein bestätigter
Bedienfehler. Aus den Screenshots allein lässt sich dieser Prüfpunkt nicht
beurteilen; eine technische Ursache des abweichenden Aufnahmebilds wurde
nicht behauptet oder diagnostiziert. Kein echtes Passwort eingegeben.

## Frischer Wiederholungslauf nach USB-Unterbrechung

Basti bat um einen neuen Durchlauf, nachdem er das iPhone zwischenzeitlich
abgezogen hatte und Safari nach seiner Beobachtung nicht mehr lud. Die
Ursache dieser Ladebeobachtung wurde nicht belegt. `devicectl list devices`
bestätigte erneut das verbundene iPhone. Die Fixture wurde frisch als
`data:`-URL geladen; ein statischer HTML-Kommentar unterscheidet die Sitzung.
Die Seite benötigt weder USB noch einen Server, um ihre Felder darzustellen;
USB ist der hier verwendete Weg zum Starten und zur Nachweisaufnahme.

`rerun-01/initial-fields.png` zeigt beide Felder leer und wurde angesehen.
Basti führte die vorgegebene Bedienfolge aus und bestätigte sie mit „done“:

1. Ein bewusster Testknopfdruck in Feld Eins.
2. Ein bewusster Testknopfdruck in Feld Zwei, danach ` abc`, einmal Löschen.
3. Zur OpenDictate-App und zurück zu Safari wechseln, ohne erneut einzufügen.
4. Passwortfeld ohne Eingabe prüfen, Tastatur schließen, nach oben scrollen.

Das tatsächlich angesehene `rerun-01/final-fields.png` zeigt:

- Feld Eins: genau `OpenDictate Testtext (synthetisch)`.
- Feld Zwei: genau `OpenDictate Testtext (synthetisch) ab`.
- Passwortfeld leer, Tastatur geschlossen.

Damit stimmt der Endzustand für Einfügen, Feldwechsel, normale Eingabe,
Löschen und Rückkehr nach App-Wechsel. Die Touch-Folge wurde vom Nutzer
bestätigt; der Bildnachweis dokumentiert Anfang und Ende, keine lückenlose
Aufzeichnung der einzelnen Tasten. Die Apple-Tastatur im Passwortfeld war
bereits im ersten Durchlauf ausdrücklich am tatsächlichen Display bestätigt.
Der Wiederholungslauf enthält dazu lediglich die allgemeine Abschlussantwort,
keinen zusätzlichen separaten Bildnachweis. Return, weitere Apps und
Barrierefreiheit auf diesem iPhone wurden hier nicht zusätzlich geprüft.

Lokale Sitzungsbelege unter `rerun-01/`: `session.json`, die tatsächlich
geladene `keyboard-focus.html` sowie beide Screenshots mit SHA-256-Bindung.
Der installierte Kandidat bleibt durch `signed-candidate-manifest.json` gebunden.
Keine Quelländerung oder Neuinstallation war für die Wiederholung nötig.

## Bereinigung und verbleibende Grenzen

Die eigene Test-App wurde nach gesichertem Endbild per `devicectl`
deinstalliert. Die anschließende gefilterte App-Abfrage findet keine
OpenDictate-App. Basti wurde um Schließen ausschließlich der eigenen
Safari-Testseiten gebeten; er bestätigte anschließend „sind zu“.
Keine Aufnahme, Anbieteranfrage, Testserver oder neues Simulatorgerät gestartet.
Die freigegebenen dauerhaften Entwicklungszertifikate und Profile bleiben erhalten.
Der reale Aufnahme-/Tastaturablauf, weitere Ziel-Apps, Barrierefreiheit und
Verteilung sind durch diese Textprüfung nicht abgenommen.
