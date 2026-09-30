# iPhone-Test: signiert installiert und sichtbar gestartet

Stand: 30. September 2026. Fortsetzung des bestandenen
[synthetischen Simulator-Tests](ios-keyboard-e2e-2026-09-29.md) mit Bastis
[Freigabe](../APPROVALS.md) für das angeschlossene echte Gerät.

## Direkt geprüft

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
iOS-Quellen unverändert. `codesign --verify --deep --strict` besteht.
`devicectl device install app` bestätigt Installation,
`devicectl device process launch` bestätigt Start. Screenshot `host-launch.png`
wurde tatsächlich angesehen und zeigt die Prototyp-Anleitung auf dem iPhone.

Weitere lokale Belege: `device-signed-build.log` (fehlende Profildatei),
`device-signed-fresh-build.log` (erfolgreich), `signed-candidate-manifest.json`
mit Binärhashes, Profilprüfung und Kandidatenbindung. Kennungen des persönlichen
Geräts werden nicht in diesem Repository veröffentlicht.

## Offene Bedienprüfung und Bereinigung

Der native Steuerungszugriff auf Device Hub endet mit Timeout. Daher wurde
Basti um den einzigen aktuell nicht fernbedienbaren Aktivierungsschritt in
Einstellungen gebeten. Sichtbarer App-Start ist keine erfolgreiche
Tastatureinfügung. Die eigentliche Geräte-E2E und der spätere
Aufnahme-/Tastaturablauf bleiben offen.

Die Test-App bleibt für diese laufende Prüfung installiert. Keine Aufnahme,
Anbieteranfrage, Testserver oder neues Simulatorgerät gestartet. Die
freigegebenen dauerhaften Entwicklungszertifikate und Profile bleiben erhalten.
