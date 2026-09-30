# iPhone-Test: Build vorbereitet, Xcode-Anmeldung offen

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

## Nächste Voraussetzung und Bereinigung

Vor Installation sind eine passende Entwicklungssignieridentität und
Geräteprofile nötig. Basti hat die konkrete Einrichtung und Registrierung
bei Apple inzwischen mit „go“ freigegeben. Der anschließende Build mit
`-allowProvisioningUpdates -allowProvisioningDeviceRegistration` scheitert
mit „No Accounts“. Xcodes Account-Einstellungen bestätigen, dass keine
Anmeldung vorliegt. Der Anmeldedialog wurde für Basti geöffnet; persönliche
Anmeldung und Zwei-Faktor-Abfrage bleiben bei ihm. Signierung und
Installation sind damit noch nicht abgeschlossen.
Keine App installiert, kein Aufnahme- oder Anbieterprozess gestartet,
kein Testserver oder neues Simulatorgerät angelegt. Auf dem iPhone gibt es
daher bislang keine eigenen Testressourcen zu entfernen.

Der reale Textpfad sowie der spätere Aufnahme-/Tastaturablauf bleiben offen.
