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
- Der Simulator-Build allein belegt keine sichtbare Einfügung. Die separate
  [Safari-E2E-Prüfung vom 29.09.](../docs/ios-keyboard-e2e-2026-09-29.md)
  besteht auf dem frischen Diagnosegerät mit synthetischem Text, einschließlich
  Feld-, App- und Tastaturwechsel sowie Systemtastatur im Passwortfeld.
- Der [begleitete iPhone-Test vom 30.09.](../docs/ios-device-2026-09-30.md)
  bestätigt den begrenzten synthetischen Textpfad auf iPhone 15 / iOS 27.0.1.
  Anfang und Ende sind bildlich geprüft; Basti bediente das Gerät und
  bestätigte die Apple-Tastatur im Passwortfeld direkt am Display.
- Das technische Deployment-Ziel im Xcode-Projekt ist nur eine Einstellung
  dieses Prototyps und entscheidet keine Produkt-Mindestversion.

## Offline-Simulator-Build

Die Build-Ausgabe liegt unter
`$HOME/.codex/artifacts/opendictate/ios-prototype/`.
`CODE_SIGNING_ALLOWED=NO` und `CODE_SIGNING_REQUIRED=NO` verhindern eine
Signierung für diesen Simulator-Build.

```sh
xcodebuild \
  -project ios/OpenDictateKeyboardDemo.xcodeproj \
  -scheme OpenDictateKeyboardDemo \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$HOME/.codex/artifacts/opendictate/ios-prototype/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build
```

Die lokale Safari-Fixture hat keine externen Ressourcen. Die Hauptaufgabe
stellt sie für die Simulatorprüfung ausschließlich auf `127.0.0.1` bereit.

## Kandidatenbindung prüfen

Das versionierte [Kandidatenmanifest](../docs/ios-prototype-candidate-2026-09-30.json)
verweist auf einen öffentlich erreichbaren Commit. Die folgenden Befehle
prüfen dessen Quelldateien im frisch geklonten Repository, ohne Build oder
Installation. Im Repository-Hauptordner ausführen:

```sh
python3 - <<'PYCODE'
import hashlib, json, subprocess
from pathlib import Path
manifest = json.loads(Path("docs/ios-prototype-candidate-2026-09-30.json").read_text())
for entry in manifest["sourceFiles"]:
    content = subprocess.check_output([
        "git", "show", manifest["reachableSourceCommit"] + ":" + entry["path"]
    ])
    assert hashlib.sha256(content).hexdigest() == entry["digest"], entry["path"]
print("Recorded source hashes match the reachable candidate.")
PYCODE
```

Die Binärhashes identifizieren die damals lokal getesteten Dateien; ein neuer
Build muss wegen Toolchain und Signierung nicht dieselben Binärbytes erzeugen.
