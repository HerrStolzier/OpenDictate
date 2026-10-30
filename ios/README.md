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
- `UITests/`: UI-Tests für Simulator und iPhone (Ziel `OpenDictateiOSUITests`).
- `UnitTests/`: Unit-Tests für gesicherte Aufnahmen, Einstellungen und
  Anfragen, nur im Simulator (Ziel `OpenDictateiOSTests`).
- `Config/`: Info.plist-Ergänzungen (Hintergrund-Audio, Live-Aktivitäten,
  Texte zu Mikrofon und lokalem Netzwerk, Schriften).

## Ablauf

1. Auslösen (Kurzbefehl „Diktieren“ per Aktionstaste, dreimal Tippen auf
   die Rückseite, den schwebenden AssistiveTouch-Knopf, Siri oder Taste in
   der App): Die App prüft Mikrofon, Schlüssel und
   Einstellungen, startet die Live-Aktivität und dann die Aufnahme. Ohne
   Live-Aktivität beendet iOS eine Aufnahme im Hintergrund, darum bricht der
   Start ab, wenn sie aus ist.
2. Nochmal auslösen, Stopp in der Live-Aktivität, ein Anruf oder die
   90-Sekunden-Grenze beenden die Aufnahme. Unter einer Sekunde ist „zu kurz“;
   so eine Aufnahme bleibt gesichert, wird aber nicht zum Nochmal-Senden
   angeboten. Ist nichts lauter als Raumrauschen (wie am Mac: kein
   50-ms-Abschnitt über -45 dBFS), geht die Aufnahme nicht raus, denn bei
   Stille erfinden Dienste gern ein Wort wie „you“. Die App zeigt „Die
   Aufnahme war zu leise“ wie am Mac und bietet die Aufnahme zum
   Nochmal-Senden an.
3. Die Aufnahme geht an OpenAI oder den eigenen Server, oder Apples
   Spracherkennung oder Parakeet schreibt sie auf dem iPhone (Einstellung
   „Erkennung“, siehe unten). Deutsche Uhrzeiten und Zahlen ab 13 schreibt
   die App danach als Ziffern („zehn Uhr dreißig“ wird „10:30 Uhr“,
   „fünfundzwanzig“ wird „25“); kleinere Zahlen bleiben Wörter, außer vor
   „Uhr“, „Prozent“, „Euro“ oder „Cent“. Mit Zielsprache folgt die
   Übersetzung. Ist die App vorn, kopiert sie den Text selbst, nur
   lokal und mit Ablaufzeit: Nach zehn Minuten nimmt iOS ihn wieder aus der
   Zwischenablage („Nochmal kopieren“ legt ihn erneut ab). Im
   Hintergrund verweigert iOS ihr die Zwischenablage; dann gibt sie den Text
   an den Kurzbefehl zurück, dessen Schritt „In Zwischenablage kopieren“ ihn
   ablegt. Beim Start gibt sie nichts zurück, damit dieser Schritt die
   Zwischenablage nicht leert. Die Live-Aktivität zeigt kurz „Kopiert“.
   Tippt man danach in ein Textfeld, schlägt die iOS-Tastatur den Text oben
   als „Einsetzen von Kurzbefehle“ vor; ein Tipp setzt ihn ein (am iPhone
   gesehen am 14. Oktober 2026; wie lange iOS den Vorschlag zeigt, ist offen).
   Endet die Aufnahme im Hintergrund ohne den Kurzbefehl (Stopp in der
   Live-Aktivität, Anruf, 90-Sekunden-Grenze), zeigt sie „Fertig“: Wer den
   Kurzbefehl innerhalb von fünf Minuten nochmal startet, bekommt diesen Text
   statt eines neuen Diktats, und beim Öffnen kopiert ihn die App, solange iOS
   sie nicht beendet hat. Bricht Kurzbefehle das Warten auf den Text ab, laufen
   die Anfragen trotzdem zu Ende, und es gilt dasselbe.
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
kopieren“ mit „Nur lokal“; „Beim Ausführen öffnen“ bleibt aus (so am
13. Oktober 2026 am Gerät bestätigt). Die Anleitung empfiehlt ohne
Aktionstaste dreimal statt zweimal Tippen, weil zweimal Tippen im Alltag oft
nicht auslöste (Basti, 30. Oktober 2026); AssistiveTouch („Eigene Aktionen →
Einmal tippen“) nennt sie als zweiten Weg. Ob der Kurzbefehl den Text kopiert hat, sieht die
App nicht; darum behält sie die Aufnahme und bietet sie nach dem nächsten
Diktat unter „Nochmal senden“ an, bis sie nach 24 Stunden verfällt.

Erkennung „Auf dem iPhone“ (ab iOS 26, Probe vom 13. Oktober 2026): Apples
`SpeechTranscriber` schreibt die Aufnahme in der Sprache des iPhones,
kostenlos, offline und ohne Schlüssel. Das Sprachmodell lädt man einmal in
den Einstellungen („Sprache laden“); ein Diktat lädt nie selbst nach. Ohne
Modell startet es gar nicht, und „Nochmal senden“ behält die Aufnahme.
Erkennung „Parakeet“ (Probe vom 14. Oktober 2026): NVIDIAs Modell Parakeet
TDT 0.6B v3 schreibt die Aufnahme über die Bibliothek
[FluidAudio](https://github.com/FluidInference/FluidAudio) (feste Version
0.15.5) auf dem iPhone, kostenlos, offline und ohne Schlüssel. Die Sprache
erkennt das Modell selbst (25 europäische Sprachen). Das Modell (etwa 500 MB,
CC BY 4.0) lädt man einmal in den Einstellungen („Modell laden“) von Hugging
Face, bei offener App; es liegt danach im Container der App, nicht im Backup.
Ein Diktat lädt nie selbst nach; ohne Modell startet es nicht. Meldet ein
Diktat, dass Parakeet nicht geklappt hat, lädt „Modell neu laden“ es frisch.
Nach dem Herunterladen und nach jeder Installation oder jedem Update der App
richtet iOS das Modell einmal für die Neural Engine ein (am iPhone 15 zwischen 20 und 40
Sekunden, siehe Grenzen); danach geht das nach einem Start der App in
Sekundenbruchteilen. Darum lädt die App das Modell gleich nach dem Herunterladen,
beim Öffnen und während der Aufnahme in den Speicher. Wartet ein Diktat auf
dieses Einrichten, zeigt die Insel eine Sanduhr und die Live-Aktivität sagt
es. Übersetzen geht dabei über „Übersetzen mit“ wie bei den anderen
Erkennungen.
Übersetzen geht genauso auf dem iPhone („Übersetzen mit: Auf dem iPhone“, ab
iOS 26): Apples `TranslationSession` übersetzt offline, nachdem die App die
Sprache des Textes auf dem Gerät erkannt hat. Die Sprachen lädt man einmal mit
„Sprachen laden“ (für die Sprache des iPhones und die Zielsprache); fehlt ein
Sprachpaar, endet das Diktat mit „Hoppla“ und die Aufnahme bleibt. Das gilt
auch, wenn du in einer dritten Sprache sprichst: „Sprachen laden“ lädt bisher
nur das Paar mit der Sprache des iPhones, und die App übersetzt nie aus einer
anderen Sprache als der des Textes. Laufen
Erkennung und Übersetzung beide auf dem iPhone, braucht die App keinen
Schlüssel und sendet nichts. In den Einstellungen heißt der Dienst so, wie er
gerade eingestellt ist: „OpenAI“ oder „Eigener Server“.

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
swift format lint --strict --configuration .swift-format --recursive ios/App ios/Shared ios/Widgets ios/UITests ios/UnitTests
```

`UITests/` (Ziel `OpenDictateiOSUITests`) tippt die App durch und hängt
Screenshots an das Testergebnis; die Live-Tests mit echtem Diktat und dem
Kurzbefehl laufen am iPhone, während der Mac einen Satz spricht
([CHECKS](../CHECKS.md#ios-app)).

Für das iPhone braucht der Build das Team (`DEVELOPMENT_TEAM=…`) und eine
Signatur „Apple Development“; TestFlight zusätzlich „Apple Distribution“ und
den App-Eintrag in App Store Connect. Hochladen nur mit Bastis Go.

## Grenzen der ersten Beta

- Ziffern für Uhrzeiten und Zahlen gibt es bisher nur auf dem iPhone und nur
  für Deutsch. „Halb elf“, „Viertel nach zehn“ und Ordnungszahlen bleiben
  Wörter, und am Gerät ist das noch nicht geprüft.
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
- Wer sehr leise oder weit weg spricht, bekommt „Die Aufnahme war zu leise“;
  die Aufnahme geht dann erst mit „Nochmal senden“ raus. Die Schwelle ist die
  des Macs und am iPhone noch nicht mit echter Sprache gemessen.
- Kein Kontrollzentrum-Schalter, kein Vokabular und keine feste Sprache; die
  Sprache erkennt der Dienst. Die Erkennung auf dem iPhone nutzt die Sprache
  des iPhones und ist am Gerät noch nicht geprüft; ob sie im Hintergrund nach
  dem Tippen auf die Rückseite schreibt und wie gut sie gegen OpenAI abschneidet, zeigt
  erst der Vergleich am iPhone.
- Parakeet ist eine Probe. Am 14. Oktober schrieb es am iPhone 15 auch über
  den Kurzbefehl im Hintergrund. Nach einer Installation dauerte das
  Einrichten des Modells 22 bis 39 Sekunden (drei Läufe); danach brauchte
  das Einrichten des größten Teils nach einem Neustart der App 0,1 Sekunden.
  „Stopp“ in der App wirkt auch während des Einrichtens sofort, und die Insel
  zeigt die Sanduhr. Ob sie das auch beim Kurzbefehl direkt nach einem Update
  tut, ist offen. Löscht iOS den Zwischenspeicher (etwa bei wenig Platz),
  dauert es ohne Hinweis wieder lange.
  Im ersten Alltagstest war es gut, aber nicht so genau wie OpenAI; ein
  Vergleich mit festen Sätzen fehlt noch. Für eine Veröffentlichung ist
  offen, woher alle Nutzer das Modell laden.
- Das Datenschutz-Manifest gibt Audio und Text als für die App-Funktion
  erfasst und mit der Person verknüpft an (kein Tracking), weil der gewählte
  Dienst beides eine Zeit lang aufbewahren und dem Konto hinter dem
  API-Schlüssel zuordnen kann. Die Angaben im App Store
  werden beim TestFlight-Schritt noch einmal geprüft.
- Ein eigener Server im Heimnetz braucht `https://`; `http://` gilt nur für
  einen Server auf dem iPhone selbst. Jeder Server außerhalb des iPhones
  bekommt den gespeicherten API-Schlüssel mit; trag nur Server ein, denen du
  vertraust. Dazu braucht er die iOS-Freigabe
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
