# OpenDictate für iPhone

Die Beta-App nach dem [iOS-Konzept](../docs/ios-konzept.md): Ein Kurzbefehl
startet die Aufnahme im Hintergrund, ohne dass OpenDictate aufgeht. Nochmal
auslösen (oder Stopp in der Live-Aktivität) beendet sie; der Text, wahlweise
übersetzt, liegt danach in der Zwischenablage. Im Hintergrund legt ihn der
Kurzbefehl selbst ab; nach Stopp in der Live-Aktivität kopiert ihn dort erst
das Öffnen der App. Stand 13. Oktober 2026: läuft auf dem iPhone, der
Kurzbefehl nimmt per Doppeltippen im Hintergrund auf und kopiert den Text
selbst (siehe Grenzen).

## Aufbau

- `OpenDictate.xcodeproj`: App `OpenDictateiOS` (Bundle-ID `app.opendictate.ios`,
  Anzeigename OpenDictate) mit der Widget-Erweiterung `OpenDictateWidgets` für
  die Live-Aktivität. Ab iOS 18, nur iPhone. Bindet `OpenDictateCore` aus dem
  Swift-Paket im Repository-Hauptordner ein (Server-Adresse, Übersetzung,
  Aufbewahrung, Blink, Design-Werte).
- `App/`: App, Kurzbefehl „Diktieren“ (`ToggleDictationIntent`, ein
  `AudioRecordingIntent` und `LiveActivityIntent`), Aufnahme, Anfragen nach
  [Provider-Vertrag](../fixtures/provider/CONTRACT.md), Schlüsselbund,
  gesicherte Aufnahmen, Start- und Einstellungsbildschirm.
- `Shared/`: in App und Erweiterung: Daten der Live-Aktivität, Stopp-Taste
  (`StopDictationIntent`, läuft im App-Prozess), Texte englisch/deutsch,
  Farben, Schriften und Blink im Designsystem.
- `Widgets/`: Live-Aktivität auf dem Sperrbildschirm und in der Dynamic Island.
- `Config/`: Info.plist-Ergänzungen (Hintergrund-Audio, Live-Aktivitäten,
  Texte zu Mikrofon und lokalem Netzwerk, Schriften).

## Ablauf

1. Auslösen (Kurzbefehl „Diktieren“ per „Auf Rückseite tippen“, Aktionstaste,
   Siri oder Taste in der App): Die App prüft Mikrofon, Schlüssel und
   Einstellungen, startet die Live-Aktivität und dann die Aufnahme. Ohne
   Live-Aktivität beendet iOS eine Aufnahme im Hintergrund, darum bricht der
   Start ab, wenn sie aus ist.
2. Nochmal auslösen, Stopp in der Live-Aktivität, ein Anruf oder die
   90-Sekunden-Grenze beenden die Aufnahme. Unter einer Sekunde ist „zu kurz“.
3. Die Aufnahme geht an OpenAI oder den eigenen Server; mit Zielsprache folgt
   die Übersetzung. Ist die App vorn, kopiert sie den Text selbst. Im
   Hintergrund verweigert iOS ihr die Zwischenablage; dann gibt sie den Text
   an den Kurzbefehl zurück, dessen Schritt „In Zwischenablage kopieren“ ihn
   ablegt. Beim Start gibt sie nichts zurück, damit dieser Schritt die
   Zwischenablage nicht leert. Die Live-Aktivität zeigt kurz „Kopiert“.
4. Bei einem Fehler zeigt die Live-Aktivität „Hoppla“ mit dem Grund, und die
   Aufnahme bleibt für „Nochmal senden“ in der App (höchstens fünf, höchstens
   24 Stunden, wie am Mac). Nahm die Zwischenablage den Text nicht, kopiert
   ihn die App beim Öffnen, solange iOS sie nicht beendet hat und seitdem
   nichts anderes kopiert wurde.

Die App ist immer im dunklen Schema „Nacht“ mit grünem Blink, wie die
Live-Aktivität. „Starten, ohne die App zu öffnen“ ist abgehakt, sobald der
Kurzbefehl einmal lief, denn iOS verrät nicht, ob er eingerichtet ist. Das
Rückseiten-Tippen bietet nur eigene Kurzbefehle an; darum legt man einmal
einen eigenen Kurzbefehl an: Aktion „Diktieren“, darunter „In Zwischenablage
kopieren“ mit „Nur lokal“. Ob der Kurzbefehl den Text kopiert hat, sieht die
App nicht; darum behält sie die Aufnahme und bietet sie nach dem nächsten
Diktat unter „Nochmal senden“ an, bis sie nach 24 Stunden verfällt.

Datenschutz: [PRIVACY.md](../PRIVACY.md#iphone-app).

## Bauen

Nur am Mac mit Xcode (Projektregel). Simulator-Build ohne Signatur, im
Repository-Hauptordner:

```sh
xcodebuild \
  -project ios/OpenDictate.xcodeproj \
  -scheme OpenDictateiOS \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
swift format lint --strict --configuration .swift-format --recursive ios/App ios/Shared ios/Widgets
```

Für das iPhone braucht der Build das Team (`DEVELOPMENT_TEAM=…`) und eine
Signatur „Apple Development“; TestFlight zusätzlich „Apple Distribution“ und
den App-Eintrag in App Store Connect. Hochladen nur mit Bastis Go.

## Grenzen der ersten Beta

- Der Start im Hintergrund scheiterte beim ersten iPhone-Test am 12. Oktober
  („Die Aufnahme konnte nicht starten“). Seitdem nimmt die App im Hintergrund
  so auf, dass sie mit anderer Wiedergabe mischt (die wird leiser), nennt bei
  einem Fehlschlag Schritt und Fehlercode und holt die App ab iOS 26 sonst
  nach vorn. Am 13. Oktober nahm der Kurzbefehl per Doppeltippen so im
  Hintergrund auf, aber iOS ließ die App den Text nicht in die Zwischenablage
  legen (Einfügen brachte ihn nicht). Mit dem Schritt „In Zwischenablage
  kopieren“ im Kurzbefehl ließ er sich einfügen. Dass der Start die
  Zwischenablage nicht mehr leert, ist am Gerät noch nicht geprüft
  ([ROADMAP](../ROADMAP.md#track-ios)).
- Kein Kontrollzentrum-Schalter, keine Erkennung auf dem Gerät, kein
  Vokabular und keine feste Sprache; die Sprache erkennt der Dienst.
- Das Datenschutz-Manifest gibt Audio und Text als für die App-Funktion
  erfasst und mit der Person verknüpft an (kein Tracking), weil der gewählte
  Dienst beides eine Zeit lang aufbewahren und dem Konto hinter dem
  API-Schlüssel zuordnen kann. Die Angaben im App Store
  werden beim TestFlight-Schritt noch einmal geprüft.
- Ein eigener Server im Heimnetz braucht `https://`; `http://` gilt nur für
  einen Server auf dem iPhone selbst. Dazu braucht er die iOS-Freigabe
  „Lokales Netzwerk“, die die App beim Öffnen anfragt; aus dem Hintergrund
  fragt iOS nicht (am Gerät noch nicht gesehen).

## Tastatur-Prototyp (September 2026, abgelöst)

`OpenDictateKeyboardDemo.xcodeproj` und `Sources/` sind der frühere
Tastatur-Prototyp. Er bleibt als Nachweis für den Textpfad einer eigenen
Tastatur; die Produktrichtung hat das Konzept vom 11. Oktober abgelöst.

Dieser kleine iOS-Prototyp soll zunächst nur den Textpfad prüfen: Eine eigene
Tastatur fügt nach bewusstem Tastendruck vorbereiteten synthetischen Text in
das gerade fokussierte Feld ein. Die Safari-Fixture und der sichtbare Ablauf
stehen in [PRUEFPLAN.md](PRUEFPLAN.md).

### Grenzen

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

### Offline-Simulator-Build

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

### Kandidatenbindung prüfen

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
