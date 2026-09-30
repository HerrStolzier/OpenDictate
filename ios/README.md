# OpenDictate iOS Kopplungs-Prototyp

Der nächste Machbarkeitsnachweis prüft **Aufnahme in der Haupt-App → manueller
Wechsel zu Safari → Stopp über die Tastatur → bewusstes Einfügen von Testtext**.
Der Text bleibt synthetisch; es gibt noch keine Transkription. Aufbau und
Abnahme stehen in [PRUEFPLAN.md](PRUEFPLAN.md). Dieser neue Kandidat ist noch
nicht auf dem iPhone installiert oder mit dessen Mikrofon geprüft.
[Offline-Nachweis](../docs/ios-recording-coupling-2026-09-30.md).

## Grenzen

- Nur die Haupt-App kann nach bewusstem Start und iOS-Mikrofonfreigabe
  aufnehmen. `AVAudioRecorder.record(forDuration:)` begrenzt jede Aufnahme auf
  15 Sekunden; maximal drei WAV-Dateien im privaten App-Verzeichnis.
- Kein Provider, Netzwerk, API-Schlüssel oder Speichern gelesener/geschriebener
  Tastatureingaben. Der Audio-Hintergrundmodus erlaubt den zu prüfenden App-Wechsel;
  er startet keine Aufnahme. Kein automatischer Neustart nach Unterbrechungen.
- Beide Targets verwenden `group.com.opendictate.ios.keyboarddemo`.
  Apple-Gruppe und passende Entwicklungsprofile sind nach konkreter Freigabe
  eingerichtet; beide enthalten das genehmigte iPhone und die bestehende
  Entwicklungsidentität. Der signierte Kandidat ist geprüft, aber noch nicht
  installiert. [Einrichtungsnachweis](../docs/ios-recording-coupling-2026-09-30.md).
  Ohne verfügbaren Gruppencontainer startet die Haupt-App nicht.
- `RequestsOpenAccess` ist für die neue Kopplung eingeschaltet. Basti muss
  „Vollen Zugriff erlauben“ selbst aktivieren, bevor die Tastatur Stopp- und
  Zustellmarker schreiben kann. Normale Tasten und „Separater Texttest“ bleiben
  ohne diesen Zugriff nutzbar. Die Tastatur bekommt keinen Mikrofonzugriff.
- Im Gruppencontainer liegen nur Version, zufällige Sitzungs-ID, Zeitpunkte,
  Phase, Dauer und leere sitzungsgebundene Marker. Audio bleibt in der Haupt-App.
  Sitzungsmetadaten verfallen für den Zugriff spätestens 60 Sekunden nach dem
  Ende; alte oder ungültige Zustände bewirken keine Einfügung.
- Die WAV-Dateien nutzen iOS-Dateischutz `completeUnlessOpen`, Rechte `0600`
  und sind vom Backup ausgeschlossen. Sie werden bei Erfolg, Fehler und Abbruch
  erhalten. Keine eigene Verschlüsselung oder Recovery-/Wiederholungsfunktion;
  das ist ein begrenzter lokaler Test. Deinstallation zur Bereinigung benötigt
  die ausdrückliche Freigabe für diese selbst erzeugten Testdateien.
- Es gibt keine automatische Einfügung und keine feste Bindung an ein
  bestimmtes Zielfeld.
- Das QWERTZ-Layout ist ein einfacher Funktionsnachweis, keine fertige
  Tastatur oder Produktabnahme.
- Der neue Build und die Bridge-Fixtures belegen keine echte Aufnahme oder
  Hintergrundkopplung. Die separate
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

## Historische Kandidatenbindung des reinen Texttests prüfen

Das versionierte [Kandidatenmanifest](../docs/ios-prototype-candidate-2026-09-30.json)
verweist auf den damaligen reinen Texttest, nicht diesen Kopplungs-Kandidaten.
Die folgenden Befehle
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
