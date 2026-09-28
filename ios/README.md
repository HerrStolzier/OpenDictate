# OpenDictate iOS Tastatur-Prototyp

Dieser kleine iOS-Prototyp soll zunächst nur den Textpfad prüfen: Eine eigene
Tastatur fügt nach bewusstem Tastendruck vorbereiteten synthetischen Text in
das gerade fokussierte Feld ein. Die Safari-Fixture und der sichtbare Ablauf
stehen in [PRUEFPLAN.md](PRUEFPLAN.md).

## Grenzen

- Kein Mikrofon, keine Aufnahme, kein Provider, kein Netzwerk und keine
  Speicherung von Texteingaben.
- `RequestsOpenAccess` ist ausgeschaltet. Die Tastatur arbeitet ohne
  „Allow Full Access“.
- Es gibt keine automatische Einfügung und keine feste Bindung an ein
  bestimmtes Zielfeld.
- Das QWERTZ-Layout ist ein einfacher Funktionsnachweis, keine fertige
  Tastatur oder Produktabnahme.
- Der Simulator-Build belegt nicht die sichtbare Einfügung in Safari. Dafür
  ist die separat koordinierte E2E-Prüfung nötig.
- Das technische Deployment-Ziel im Xcode-Projekt ist nur eine Einstellung
  dieses Prototyps und entscheidet keine Produkt-Mindestversion.

## Offline-Simulator-Build

Der Build schreibt nur nach
`/Users/basti/.codex/artifacts/opendictate/ios-prototype-20260928/`.
`CODE_SIGNING_ALLOWED=NO` und `CODE_SIGNING_REQUIRED=NO` verhindern eine
Signierung für diesen Simulator-Build.

```sh
xcodebuild \
  -project ios/OpenDictateKeyboardDemo.xcodeproj \
  -scheme OpenDictateKeyboardDemo \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /Users/basti/.codex/artifacts/opendictate/ios-prototype-20260928/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build
```

Die lokale Safari-Fixture hat keine externen Ressourcen. Die Hauptaufgabe
stellt sie für die Simulatorprüfung ausschließlich auf `127.0.0.1` bereit.
