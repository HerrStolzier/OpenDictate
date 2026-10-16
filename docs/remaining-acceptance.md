# Belegter Stand je Plattform

Stand: 13. Oktober 2026. Diese Datei hält je Plattform fest, was belegt ist,
was offen ist und wo der letzte Nachweis liegt. Die nächsten Schritte stehen
in der [ROADMAP](../ROADMAP.md), Produkt und Entscheidungen in
[PROJECT.md](../PROJECT.md), Prüfwege in [CHECKS.md](../CHECKS.md). Die
frühere chronologische Übergabedatei liegt unverändert im
[Archiv](archive/uebergabe-chronik-bis-2026-10-07.md); datierte Berichte
gelten nur für ihren damaligen Kandidaten ([Verzeichnis](archive/README.md)).

Seit dem 8. Oktober 2026 prüfen wir selbst nur noch den Weg, den jeder
Nutzer durchläuft (Installation und ein Diktat); Einzelfälle finden
Beta-Nutzer. Was hier „offen“ heißt, ist deshalb kein Testauftrag, sondern
eine bekannte Grenze, die in der jeweiligen Anleitung stehen muss.

## Linux

**Belegt** (omarchy, Hyprland, mit Bastis Go, 5. bis 7. Oktober 2026,
[Nachweise](linux-live-2026-10-05-bis-07.md)):

- Aufnahme, Keyring (API-Schlüssel und Aufnahmeschutz), Upload, Zwischenablage;
  Diktat ohne Übersetzung 2,3 s, mit Übersetzung nach Englisch 3,6 s.
- Übersetzung nach dem Sprechen (`settings target en`, Modell `gpt-5.4-mini`);
  falsches Modell behält die Aufnahme, `retry` übersetzt nach.
- Abbruch und Netzausfall während der Transkription: Aufnahme bleibt erhalten,
  `retry` liefert. Die seitdem kürzeren Zeitlimits (PR #51) sind nur offline
  geprüft.
- Physischer Hotkey Super+D; Leistenanzeige in der Omarchy-Leiste mit
  Klick-Umschalter der Zielsprache. Seit dem 11. Oktober zeigt die Leiste Blink
  (`▮`) statt Mikrofon und Sanduhr, noch nicht im Pre-Release
  `linux-v0.1.0-beta.1`; diese neue Darstellung, der Tooltip und das
  Waybar-Beispiel sind nur offline geprüft, noch nicht live gesehen.
- Auto-Einfügen in das beim Start erfasste Fenster (Editor, Terminal), mit
  Fokus- und Zwischenablage-Prüfung; Fensterwechsel wird korrekt übersprungen.
- Offline: `scripts/ci/check-linux.sh` (Formatierung, Tests, Clippy,
  Release-Build) grün auf `main`.
- Täglicher Gebrauch durch Basti seit dem 7. Oktober.
- Arch-Paket ([PKGBUILD](../linux/packaging/arch/PKGBUILD)) am 8. Oktober auf
  omarchy gebaut (46 Tests grün), von Basti mit `pacman -U` installiert, Super+D
  und Leiste darauf umgestellt, ein Diktat mit Übersetzung in einen Editor
  eingefügt.
- Zweisprachiges Paket aus PR #59 (`0a04ed5`) am 8. Oktober auf omarchy gebaut
  (49 Tests grün) und installiert; omarchy steht auf `en_US`, Hilfe auf
  Englisch; ein Diktat mit Übersetzung in die Claude-App eingefügt.

**Offen / bekannte Grenzen:** Ein Start direkt nach der Neuinstallation
scheiterte einmal mit „Recording could not start“ (Ursache unbekannt, der
nächste Versuch klappte); seit PR #59 steht der Grund im Protokoll
(`recording-start-failed`), und die leere Datei wird entfernt. Am 11. Oktober
scheiterten auf omarchy alle Starts seit dem 9. Oktober, weil kein Mikrofon
angeschlossen war (PipeWire ohne Quelle). Bis dahin meldete `toggle` trotzdem
„Aufnahme läuft“ und der Grund stand nur im Protokoll; seitdem erscheint ein
gescheiterter Start als Benachrichtigung, die nach dem Mikrofon fragt, und
`toggle` meldet ihn mit Verweis auf das Protokoll (in der Sandbox ohne
Audiogerät geprüft, auf omarchy noch nicht). Während das Mikrofon öffnet,
heißt der Zustand `starting`; ein weiteres `toggle` wird dann abgelehnt, und
braucht das Mikrofon länger als 5 Sekunden, bricht der Start ab. Bekannte
Grenze: Hängt das Öffnen des Mikrofons ganz, bleibt `starting` stehen, bis der
Aufnahmeprozess beendet wird, und `cancel` meldet dann, dass der Abbruch erst
greift, sobald das Mikrofon antwortet; geprüft ist das nur mit einer nachgestellten
Zustandsdatei, nicht mit einem langsamen Mikrofon. Einfügen in Chromium-, Electron- und
Discord-Fenstern; gemischtes Deutsch/Englisch; Abbruch genau während der
Übersetzung; andere Compositoren als Hyprland; andere Distributionen;
Vokabular. Eigener Server und `opendictate setup` mit Kürzel-Abfrage
(11. Oktober) sind nur offline geprüft: Tests mit lokalem HTTP-Stub (kein
Schlüssel an Loopback, Schlüssel an Fremdserver) und ein Durchlauf im
Test-Terminal mit Attrappen für `hyprctl` und `secret-tool`. Ebenso nur mit
einer `hyprctl`-Attrappe geprüft: Übernimmt Hyprland ein neues Kürzel nicht,
stellt `setup` die Konfiguration wieder her (seit dem Folge-PR zu #67). Live offen:
Durchlauf auf omarchy, die Lua-Zeilen für F9 und rechte Alt, ein echter
lokaler Server. Für das Arch-Paket ungeprüft: `namcap`, Bau mit pacman-Rust und `makepkg -si`,
frische Ersteinrichtung des Schlüssels.
Seit der Gesamtprüfung vom 13. Oktober meldet ein Mikrofon, das während der
Aufnahme ausfällt, das per Benachrichtigung und sichert den Ton bis dahin für
`retry`; zu kurze oder stille Aufnahmen werden mit Vermerk gesichert, den
`retry` übergeht (`retry --skipped` sendet die letzte davon), und abgelaufene
Sicherungen verschwinden nach jedem Diktat. Geprüft nur mit
Unit-Tests (auch Stereo-Abmischung und Formatwandlung), nicht mit einem echt
abgezogenen Mikrofon.
Eine alte Testaufnahme vom 7. Oktober liegt noch im Recovery-Ordner auf
omarchy; Löschen nur mit Bastis Go. Die leere Datei vom gescheiterten Start
wurde am 8. Oktober mit Bastis Go gelöscht.

**Letzter Nachweis:** 8. Oktober 2026, Arch-Paket aus `0a04ed5` (PR #59)
([Live-Nachweise](linux-live-2026-10-05-bis-07.md)). Seit 11. Oktober ist
`afa3506` als Pre-Release
[`linux-v0.1.0-beta.1`](https://github.com/HerrStolzier/OpenDictate/releases/tag/linux-v0.1.0-beta.1)
veröffentlicht; für diesen Stand gibt es noch keinen Live-Nachweis.

## macOS

**Belegt:**

- Stufe 1 (interne Funktionsabnahme) am 24. September 2026 für den
  dokumentierten Grundablauf auf Build 7 abgeschlossen: echtes Diktat mit
  physischem Kürzel in TextEdit, Feldmatrix in TextEdit, Safari, Brave,
  Obsidian, Terminal-Zeile ohne Return, negativer Appwechsel, Leerlaufmessung
  ([Plan-1-Bericht](release-plans/evidence/2026-09-24-plan1-fortsetzung.md)).
- Stufe 2: Build 8 aus `b786d4c` ist von Apple notarisiert, das finale ZIP mit
  Manifest geprüft (Signatur, Entitlement, Ticket, Gatekeeper mit Quarantäne,
  4,14 MiB, SHA-256 `2e994cd8…e335768`) und lag in der privaten Release-Draft
  `v0.1.0-beta.8` (am 13. Oktober 2026 gelöscht, abgelöst durch Beta 10 und 12)
  ([Nachweis](release-plans/evidence/2026-10-02-plan2-build8-final.md)).
- Stufe 2 Teil B (8. Oktober 2026, mit Bastis Go): Build 8 in
  `/Applications` installiert, erster Start mit Quarantäne, neuer
  Schlüsselbundhelfer bytegleich mit dem Paket, zwei erwartete
  Schlüsselbund-Abfragen, ein Diktat mit automatischem Einfügen in TextEdit
  ([Nachweis](release-plans/evidence/2026-10-08-plan2-teil-b.md)). Nach dem
  Signaturwechsel musste der Bedienungshilfen-Eintrag entfernt und neu
  hinzugefügt werden.
- Der signierte Schlüsselbundhelfer liest den API-Schlüssel nach einem
  Build-Wechsel ohne Dialog
  ([Nachweis](release-plans/evidence/2026-09-24-keychain-and-plan1.md)).
- Temporäre Aufnahmen tragen `0600`: Originalaufnahme etwa 0,1 s nach dem
  Anlegen, Upload-Datei von Anfang an; live geprüft am 7. Oktober auf einem
  Testbuild aus `cbddf7b` (PR #49). Ein nicht löschbarer abgelaufener Eintrag
  wird nur einmal pro Start geloggt (PR #50); die alte Aufnahme vom
  15. September ist nach Entfernen ihrer ACL gelöscht.
- Offline: Swift-Suite und Bundle-Build in CI bis Build 12 auch nativ auf
  macOS 14; seit dem 13. Oktober auf macOS 15 mit Standard- und ältester
  Xcode-16-Toolchain, weil GitHub den macOS-14-Runner am 2. November abschaltet.
- Übersetzung nach dem Sprechen ist im Code (Menü und Einstellungen
  „Übersetzen“, Modell `gpt-5.4-mini`, gleiche Regeln wie auf Linux) und
  offline geprüft: Ablauftests für Übersetzen, Fehler und leere Antwort
  (Aufnahme bleibt, kein Rückfall auf den Originaltext), Wiederholen mit
  Übersetzung, Anfrageaufbau ohne Netz. Die kleinen Punkte vom 7. Oktober sind
  ebenfalls umgesetzt: Originalaufnahme wird mit `0600` angelegt (lokal mit
  `AVAudioRecorder.prepareToRecord` geprüft), Grund einer nicht startenden
  Aufnahme im App-Log, Tests schreiben in eine temporäre Logdatei (Zeilenzahl
  des echten Logs vor und nach `swift test` gleich), „ca.“ beim Preis des
  Mini-Modells.
- Build 9 aus `46103b0` (8. Oktober 2026, mit Bastis Go): notarisiert, per
  Finder als Update über Build 8 installiert (Bedienungshilfen blieben
  erhalten), Diktat mit Übersetzung nach Englisch in TextEdit eingefügt,
  Originalaufnahme beim Anlegen bereits `0600`
  ([Nachweis](release-plans/evidence/2026-10-08-build9.md)).
- Einzeltasten und Kürzel-Abfrage (seit Build 10, [Nachweis](release-plans/evidence/2026-10-11-build10.md)):
  Fn/Globus halten und rechte Wahltaste über NSEvent-Monitore, Abfrage beim
  ersten Start nach dem API-Schlüssel mit Tastendruck-Test. Offline geprüft:
  Erkennung von Antippen, Halten, fremder Taste und Mindestdauer in
  `ModifierKeyGestureTests`, Speicherung und Vorrang alter Kürzel in
  `SettingsTests`; die Fenster der Abfrage wurden mit einem lokalen,
  nicht eingecheckten Testlauf gerendert und angesehen.
- Live am 9. Oktober 2026 mit einem lokalen Testbuild aus `22ce2a9`
  (Developer-ID-signiert, nicht notarisiert, gleiche Signaturanforderung wie
  Build 9), separate Apple-Tastatur: Ohne gespeichertes Kürzel erschien die
  Abfrage beim Start. Diktat per rechter Wahltaste und, nach Wechsel im Menü,
  per Fn halten wurde jeweils in eine andere App eingefügt (laut App-Log 1,9 s
  und 1,3 s nach dem Stopp). Die Bedienungshilfen-Freigabe von Build 9 galt
  ohne neue Abfrage. ⌥L mit der rechten Wahltaste als Kürzel ist live nicht
  separat geprüft: Der ⌥L-Test lief laut App-Log mit Fn als Kürzel. Abgedeckt
  ist der Fall offline in `ModifierKeyGestureTests` (fremde Taste während des
  Haltens).

- Empfehlung je Tastatur (nach PR #63): Die Abfrage wählt Fn bei eingebauter
  oder kompakter Apple-Tastatur vor, sonst die rechte Wahltaste. Grundlage sind
  Hersteller- und Produkt-ID aus der I/O Registry (Ziffernblock-Modelle laut
  Linux `hid-ids.h`), nicht der umbenennbare Name. Offline in
  `ModifierKeyRecommendationTests`; lokal am 10. Oktober auf Bastis Mac
  gelesen: ein Magic Keyboard mit Ziffernblock (`004C:026C`) ergibt die rechte
  Wahltaste, das Fenster wurde gerendert und angesehen.

- Neue Diktatanzeige und Menü der Menüleiste (seit Build 11, öffentlich
  seit `v0.1.0-beta.12`, Entwurf in Claude Design vom 9. Oktober): kleine schwarze Anzeige
  oben am Bildschirm mit Blink, Zustandswort und Zeile; an der Notch, ohne
  Notch schwebend unter der Menüleiste (Standard seit Bastis Wahl am
  11. Oktober), flach in der Menüleiste oder aus; Menü mit
  „OpenDictate beenden“. Offline geprüft: Zuordnung der Fensterzustände,
  Wahl der Variante je Bildschirm, Aufnahmezeile mit Countdown, Menüreihenfolge,
  Anzeige ohne Fokus (`DictationIndicatorTests`), Blink Pixel für Pixel gegen
  die Web-Komponente des Designsystems (`BlinkConformanceTests`). Alle Varianten
  und Zustände wurden als Bilder gerendert (`--indicator-snapshots`) und
  angesehen.
- Live am 11. Oktober 2026 auf Bastis Mac Mini (ohne Notch, 3440 × 1440 bei
  1×) mit einem lokalen Testbuild aus `47fe2dd` (Developer-ID-signiert, nicht
  notarisiert, nicht in /Applications): Diktat per Fn halten mit Übersetzung
  nach Englisch in TextEdit. Die Pille in der Menüleiste zeigte laut
  Bildschirmaufnahmen „Hört zu REC 0:00“ bis „0:03“, „Schreibt OpenAI
  übersetzt“ und „Eingefügt per ⌘V, kurz prüfen“ und schloss danach von selbst;
  laut App-Log 2,9 s vom Stopp bis zum Ergebnis. Basti bestätigte: Der Text kam
  in TextEdit an, TextEdit blieb vorne, die Pille ist klein und gut sichtbar.
  Ein zu kurzes Diktat (0,6 s) zeigte die Fehlerkarte mit Grund und ohne
  „Nochmal senden“. Ein selbstsignierter Testbuild bekommt den API-Schlüssel
  nicht, weil der installierte Schlüsselbund-Helfer die Developer-ID verlangt;
  die Anzeige meldete das als „Hoppla“ mit dem Hinweis auf die Einrichtung.
  Zweites Diktat neben einem Spiel: Als das Einfügen das Vollbild-Spiel nach
  vorne holte, blieb die Menüleisten-Pille bis zum nächsten Zustandswechsel über
  der Leiste des Spiels und sprang erst dann in die schwebende Pille. Seitdem
  platziert sich die Anzeige auch beim Wechsel der vorderen App neu; das ist
  offline geprüft, live noch nicht wiederholt.
  Dritte Runde mit „Schwebend unter der Menüleiste“ (Testbuild aus `8872044`):
  „Hört zu REC 0:01“, „Schreibt OpenAI übersetzt“, „Eingefügt“, danach von
  selbst zu; der übersetzte Text kam an (3,0 s vom Stopp bis zum Ergebnis).
  Zwei Versuche davor waren zu leise (Spitze −45 dB, Basti zu weit vom
  Mikrofon); die Fehlerkarte zeigte Grund, „Schließen“ und „Nochmal senden“.
  Basti wählte danach „schwebend“ als Standard.
  Vollbild: Basti diktierte in World of Warcraft im Vollbild und bestätigte,
  dass es funktioniert; laut App-Log ein Diktat mit 2,2 s vom Stopp bis zum
  Ergebnis (davor ein zu leiser Versuch, der als Fehler endete). Was die
  Anzeige dabei im Einzelnen zeigte, ist nur von Basti beobachtet, nicht
  aufgezeichnet.
  Notch: Auf Bastis MacBook Air 15" (M3, macOS 27.0.1) lief die Debug-Vorschau
  (`--indicator-preview`) an der echten Notch, ohne Diktat und ohne Schlüssel.
  Laut Bastis Screenshots ist die Anzeige offen etwa 355 × 90 Punkte groß,
  bei „Hoppla“ etwa 115 Punkte hoch; Wort und Zeile sitzen unter der Kamera.
  Basti bestätigte die Maße („passt“). Die Vorschau wurde danach beendet und
  vom MacBook gelöscht.
- Eigener Server (11. Oktober, seit Build 11, öffentlich seit `v0.1.0-beta.12`): Adresse unter
  Einstellungen → Erweitert, `https://` beliebig, `http://` nur auf diesem Mac.
  Offline geprüft: Adressregeln, Vorrang vor `OPENAI_BASE_URL`, kein Rückfall
  auf OpenAI bei ungültiger Adresse, Schlüssel nur an Server außerhalb dieses
  Macs, und ein echter Testserver auf 127.0.0.1 empfängt Transkription und
  Übersetzung ohne Schlüssel (`LocalServerTransportTests`). Eine
  http-Verbindung zu `127.0.0.1` und `localhost` blockiert macOS auch ohne
  Ausnahme im App-Paket nicht (Probe-App am 11. Oktober; `http://example.com`
  wurde blockiert); `[::1]` ist nicht geprobt. Dass bei lokalem Server kein
  Schlüssel gelesen und keine Einrichtung verlangt wird, ist aus dem Code
  abgeleitet, nicht getestet.

**Offen / bekannte Grenzen:**

- Diktatanzeige live noch offen: „Nochmal senden“ mit Rückfrage; „Aus“;
  andere Ziel-Apps als TextEdit; ein echtes Diktat an einem MacBook mit Notch
  (die Maße sind nur mit der Vorschau bestätigt). Im Vollbild gilt eine App als Vollbild, wenn ihr vorderstes
  Fenster den ganzen Bildschirm bedeckt. Mit der Einstellung „In der Menüleiste“
  liegt die Pille bei „Menüleiste immer ausblenden“ über dem Fensterinhalt, und
  in Apps mit sehr vielen Menüs kann sie in der Mitte einen Menütitel verdecken, solange sie
  sichtbar ist. Gehörte VoiceOver-Ansagen der Anzeige sind ungeprüft.
- Eigener Server: Live am 11. Oktober mit Build 11 gegen whisper.cpp 1.9.5
  (Modell large-v3-turbo, nur auf diesem Mac): vier Diktate eingefügt, laut
  App- und Server-Log ohne Anfrage an OpenAI, rund 2,4 s vom Stopp bis zum
  Text. Dabei fiel auf, dass whisper.cpp an Sprechpausen Zeilenumbrüche setzt;
  seit Build 12 werden sie bei einem eigenen Server zu Leerzeichen (live am
  12. Oktober bestätigt: Diktat mit mehreren Pausen kam als ein Absatz,
  [Nachweis](release-plans/evidence/2026-10-12-build12.md)). Andere Server werden nicht abgenommen,
  Übersetzung über einen eigenen Server ist live nicht geprüft
  ([Nachweis](release-plans/evidence/2026-10-11-build11.md#eigener-server-mit-lokalem-modell)). Ebenfalls nur aus dem Code
  abgeleitet: Bei einer frischen Installation ohne Schlüssel führt das
  Speichern eines lokalen Servers wie das Speichern eines Schlüssels weiter zur
  Kürzel-Abfrage und zur Bedienungshilfen-Freigabe.
- Empfehlung je Tastatur: MacBook-Tastatur und Fremdtastatur am echten Gerät
  ungeprüft. Jedes HID-Gerät mit Tastatur-Schnittstelle oder einer
  Tastatur-Collection neben seiner Hauptfunktion zählt, auch Gaming-Mäuse mit
  Makrotasten,
  Funkempfänger von Mäusen, YubiKeys oder virtuelle Tastaturen; dann wird die
  rechte Wahltaste vorgeschlagen, obwohl Fn passen würde.
- Einzeltasten live noch offen: ⌥L mit der rechten Wahltaste als Kürzel,
  Abfrage ohne Bedienungshilfen-Freigabe und
  Wirkung einer neu erteilten Freigabe ohne Neustart, rechte Wahltaste länger
  als 0,3 s halten und dann eine Taste drücken (Aufnahme wird abgebrochen und
  aufbewahrt), MacBook-Tastatur. Die Fn-Taste wird nur beobachtet: Ohne
  „🌐 drücken für: Nichts“ öffnet macOS zusätzlich Emoji oder Diktat. Auf der
  separaten Apple-Tastatur mit Ziffernblock liegt Fn weit rechts; Basti nutzt
  dort die rechte Wahltaste.
- Preset F5: Auf MacBooks seit 2021 trägt F5 Apples Diktat-Symbol. Ob die Taste
  ohne „F1, F2 usw. als Standard-Funktionstasten verwenden“ oder gedrückte Fn
  als F5 bei OpenDictate ankommt, ist nicht belegt; ungeprüft und nicht
  umgebaut.

- Beenden der App während der Transkription: nur ohne Netz geprüft. Live
  antwortete OpenAI in zwei Versuchen am 8. Oktober nach gut 3 s, bevor die
  Abfrage bestätigt war. Bekannte Grenze der Beta (Entscheidung Basti).
- „Text ansehen“ und „Text kopieren“ wurden in Teil B nicht eigens geprüft;
  seit der neuen Anzeige öffnet „Letzten Text ansehen“ im Menü dieses Fenster.
- Übersetzung: Diktate mit Übersetzung nach Englisch wurden mit Build 9 und
  Build 10 eingefügt ([Build 9](release-plans/evidence/2026-10-08-build9.md),
  [Build 10](release-plans/evidence/2026-10-11-build10.md)); Wiederholen,
  Fehlerfälle und Abbruch während der Übersetzung sind nur offline belegt.
- Der ⌘V-Pfad bindet kein Feld: Cursor- oder Fokuswechsel nach dem Stopp
  können den Einfügeort innerhalb der ursprünglichen App verändern. Mehrzeiliger
  Text wird in bekannte Terminals nicht automatisch eingefügt (seit 11. Oktober,
  nur offline belegt); Terminal-Tabs, Markierung, Secure Input, iTerm2 und
  Terminals in Editoren sind ungeprüft.
- Gerätewechsel, abgezogenes Mikrofon, Berechtigungs- und Keychainfehler,
  unterbrochenes Beenden während der Verarbeitung sind nicht praktisch geprüft.
- Gehörte VoiceOver-Ausgabe, frische Ersteinrichtung in einem neuen Konto,
  Intel-Macs.
- Der vorhandene API-Schlüssel liegt noch im alten Keychain-Account
  `OPENAI_API_KEY` mit Build-Hashes in der Zugriffsliste; er wird nur durch die
  App-Migration entfernt, nicht manuell.

**Letzter Nachweis:** 12. Oktober 2026 (Build 12 aus `2d8d4ed` notarisiert, als Update installiert, Diktat über lokalen Server, als `v0.1.0-beta.12` veröffentlicht; [Nachweis](release-plans/evidence/2026-10-12-build12.md)).

## Windows

**Belegt:** Der Quellsnapshot unter [windows/](../windows/README.md) stimmt
bytegleich mit der Arbeitskopie überein; 41 von 41 Offline-Prüfungen (23
Kern-/Ablaufprüfungen, 18 Schutzprüfungen) und App-/Browser-Host-Build
bestanden am 28. September 2026 auf dem Windows-PC
([Geräteprüfung](platform-audit-2026-09-28.md),
[Fortsetzung](platform-continuation-2026-09-28.md)). Der historische Prototyp
vom 12. September bestand Cursor-, Auswahl- und Abbruchfälle mit künstlichem
Text in Editor und Chrome-Testprofil ([Windows-Plan](windows-plan.md)).

Seit 11. Oktober 2026 nimmt die Windows-App Modell, gesprochene Sprache,
Übersetzung nach dem Sprechen (`gpt-5.4-mini`) und eigenen Server aus
`%APPDATA%\OpenDictate\settings.json`; ein Server auf diesem Computer bekommt
keinen Schlüssel. Die Provider-Prüfungen laufen gegen `fixtures/provider/`.

Ebenfalls seit 11. Oktober gibt es die Beta-App `OpenDictate.App`
([Beschreibung](../windows/README.md#beta-app-11-oktober-2026)): Infobereich,
Strg+Win halten oder rechte Strg, Einfügen per Zwischenablage und Strg+V nur ins
erfasste Fenster, Diktatanzeige, Begrüßung mit Kürzeltest. Am 13. Oktober
wurden das alte Prüffenster, der Browser-Host und die Test-Erweiterung
entfernt. Seit 14. Oktober löscht die App beim Start liegengebliebene
Originale im Aufnahmeordner, sobald sie 24 Stunden alt sind; seitdem bestanden
54 Offline-Prüfungen (davon 20 für Kürzel, Auslöser, Einfügeregel,
Einstellungen und Anzeige) und beide Builds auf Linux.

Am 16. Oktober lief die App aus `40911f3` erstmals auf Bastis Windows-PC xmg,
installiert ohne Adminrechte: 54 von 54 Offline-Prüfungen, beide Builds ohne
Warnungen und alle 15 Schutzprüfungen bestanden. Ein echtes Diktat über das
Menü im Infobereich (Computerstimme, eine Anfrage an OpenAI) zeigte „Hört zu“,
„Schreibt“ und „Kopiert“ und legte den Text in die Zwischenablage; das
Startmenü blieb zu. „Mit Windows starten“ setzt und entfernt den Run-Eintrag.
Das Kürzel lässt sich nicht automatisch testen, weil die App künstliche
Tastendrücke absichtlich ignoriert. Danach diktierte Basti selbst mit echter
Tastatur und Stimme in Notepad: Mit Strg+Win und mit der rechten Strg-Taste
wurde der Text samt Satzzeichen automatisch eingefügt („funktioniert
wunderbar“).

**Offen / bekannte Grenzen:** Kein Diktat gegen ein lokales Modell; Spielchat im
Vollbild (Anzeige über Spielen, Strg+V mit Scancode) und Skalierung ungeprüft; in Programme mit
Adminrechten lässt Windows nicht einfügen, und die Anzeige erkennt das nicht
(Text bleibt in der Zwischenablage); kein Prompt (Vokabular); keine Maus-Seitentaste; keine
reproduzierbare Paketierung, keine Signatur, kein Installer; Update- und
Deinstallationsweg; Pflichtprogramme nicht festgelegt.

**Letzter Nachweis:** 16. Oktober 2026 (xmg, Bastis Diktat in Notepad).

## iOS

**Belegt:** Der Offline-Tastatur-Prototyp aus `e416a3d` besteht Build,
Installation und den synthetischen Safari-Textpfad auf einem frischen
Simulator (29. September, [Nachweis](ios-keyboard-e2e-2026-09-29.md)) und auf
Bastis iPhone 15 mit iOS 27.0.1 (30. September, signiert gebaut, installiert,
Einfügen in beide Safari-Felder, Systemtastatur im Passwortfeld,
[Gerätenachweis](ios-device-2026-09-30.md)). Test-App deinstalliert.

**Teilweise am Gerät gesehen:** Die Beta-App nach dem [Konzept](ios-konzept.md)
liegt seit dem 11. Oktober unter [ios/](../ios/README.md). Am 12. Oktober lief
`39738a9` auf Bastis iPhone 15 (iOS 27.0.1, Debug-Build mit Apple-Development-
Signatur, per Kabel installiert): Mikrofon-Freigabe, Schlüssel und ein Diktat
aus der App heraus kamen als Text an. Der Kurzbefehl „Diktieren“, aus der
Kurzbefehle-App gestartet, scheiterte mit „Die Aufnahme konnte nicht
starten“; die Live-Aktivität lief vorher an. Am 13. Oktober lief `b1781e7`
(Aufnahme, die im Hintergrund mit anderer Wiedergabe mischt): Derselbe
Kurzbefehl nahm im Hintergrund auf, die Dynamic Island zeigte Aufnahme und
„Schreibt“ (im kleinen Feld abgeschnitten), und der Text kam in der App an.
Danach meldete die App, dass sie den Text nicht in die Zwischenablage legen
konnte. Mit demselben `b1781e7` nahm sie auch per Doppeltippen auf die
Rückseite auf, aber der neue Text ließ sich nicht einfügen: iOS verweigert der
App im Hintergrund die Zwischenablage. Mit einem eigenen Kurzbefehl
„Diktieren“, darunter „In Zwischenablage kopieren“, ließ sich der Text nach
dem Doppeltippen einfügen. Draft-PR #40 ist geschlossen.

**Automatisch getestet:** Am 13. Oktober abends liefen die UI-Tests aus
`ios/UITests` mit `39224d8` und den Korrekturen aus diesem Lauf
(Swift-6-Import in `TranslationDownload.swift`, Start des Kurzbefehls per
Name, Auslesen der Auswahlmenüs): `testScreens` im Simulator grün mit 8
angesehenen Bildschirmfotos. Auf Bastis iPhone 15 (über WLAN verbunden) bestand
`testDictationInApp`: Der Mac sprach einen Testsatz, das iPhone nahm ihn mit
dem Mikrofon auf, der Text kam an. Ebenso bestand `testShortcutPastesIntoNotes`:
Der eigene Kurzbefehl „Diktieren“ legte den Text ab, und er ließ sich in eine
neue Notiz einsetzen. Beide Tests liefen mit der Erkennung über den Dienst,
ohne Übersetzung. Einmal fragte die Kurzbefehle-App, ob „Diktieren“ seinen
Text ausgeben darf.

Am 14. Oktober liefen mit `33dc985` (Übergabe an den Kurzbefehl nach einem
Stopp im Hintergrund, Unit-Tests) am Mac Mini Bau und Formatprüfung ohne
Fehler und Warnungen, alle 16 Unit-Tests aus `ios/UnitTests` im Simulator und
`testScreens` grün. Auf dem iPhone 15 (per Kabel) bestanden danach beide
Live-Tests. Ein erster Lauf mit stummem Mac-Lautsprecher zeigte, dass OpenAI
bei Stille „you“ zurückgab und die App es kopierte; seitdem sendet die App
eine stille Aufnahme nicht. Die geleerte Test-Notiz blieb in Notizen stehen;
der Test löscht sie seitdem.

Mit `e843fb5` (Stille-Prüfung, Löschen der Test-Notiz) liefen am 14. Oktober
am Mac Mini Bau und Formatprüfung ohne Fehler und Warnungen, alle 20
Unit-Tests (signiert, keiner übersprungen) und `testScreens` grün, auf dem
iPhone 15 beide Live-Tests; danach stand keine leere Test-Notiz mehr in
Notizen. Ein Diktat ohne Ton endete am Gerät mit „Die Aufnahme war zu leise“,
ohne Anfrage an OpenAI. Der Aufräumschritt löschte dabei die erste leere
„Neue Notiz“, hätte also auch eine eigene leere Notiz treffen können; seitdem
schreibt der Test eine nur für diesen Lauf erzeugte Zahl in seine Notiz und
löscht nur die Notiz mit dieser Zahl (am Gerät noch nicht gelaufen). Gelöschte
Test-Notizen landen in „Zuletzt gelöscht“. Von Hand bestand mit `e843fb5` auch
das Doppeltippen auf die Rückseite: Aufnahme im Hintergrund, der Kurzbefehl
kopierte den Text, und die Tastatur bot ihn in WhatsApp oben als „Einsetzen
von Kurzbefehle“ an (iPhone 15, iOS 27.0.1).

Mit `ce98609` (Erkennung „Parakeet“) liefen am 14. Oktober am Mac Mini Bau
und Formatprüfung samt FluidAudio ohne Fehler und Warnungen, alle 21
Unit-Tests und `testScreens` grün. Auf dem iPhone 15 dauerte „Modell laden“
44 Sekunden über das WLAN des iPhones. Lief die App schon, kam der Text
1,2 Sekunden nach dem Stopp; nach einem Neustart der App 18 bis 19 Sekunden
nach dem Stopp einer 2-Sekunden-Aufnahme (zwei Läufe), weil das Modell dann
neu geladen wird. Beide Live-Tests bestanden mit Parakeet, auch der Weg über
den Kurzbefehl im Hintergrund bis Notizen. Gesprochen hat die Computerstimme
des Macs; das sagt nichts über die Erkennung echter Stimmen.

Mit `6379c54` maß der Mac Mini am 14. Oktober je Start der App die Zeilen
„Compiled model …“ von FluidAudio. Beim ersten Start nach dem Aufspielen
brauchte der Encoder 39,3 Sekunden, bei den beiden folgenden Starts je
0,09 Sekunden. Die frühere Messung von 18 bis 19 Sekunden „nach einem
Neustart“ war verfälscht, weil jeder Testlauf die App neu aufspielte. Im
ersten Lauf wirkte der Tipp des UI-Tests auf „Stopp“ erst nach dem
Einrichten, die Aufnahme lief rund 50 Sekunden; über den Kurzbefehl stoppte
eine Aufnahme direkt nach dem Aufspielen sofort. Die kleine Insel zeigte
dabei nur „•••“, den Hinweis aufs Laden nicht.

Mit `d698e06` liefen am 14. Oktober Bau, alle 21 Unit-Tests, `testScreens`
und beide Live-Tests mit Parakeet grün. Direkt nach dem Aufspielen wirkte ein
Tipp auf „Stopp“ in der App nach 0,5 Sekunden, während der Encoder noch
22 Sekunden kompilierte; der Text kam 24 Sekunden nach dem Stopp. Die kleine
Insel zeigte dabei Blink und die Sanduhr. Wurde das Diktat direkt nach dem
Aufspielen über eine URL zum Kurzbefehl gestartet, war die Insel gleich nach
dem Stopp weg (zweimal); ob das am Testaufbau liegt, ist offen.

**Offen / bekannte Grenzen:** Start ohne Leeren der Zwischenablage und die
Änderungen nach `4993214` am Gerät, die Übergabe nach einem Stopp im
Hintergrund (Live-Aktivität, Anruf, 90-Sekunden-Grenze) am Gerät, die Erkennung „Auf dem iPhone“ (Apples
Spracherkennung, ab iOS 26) am Gerät und im Vergleich mit OpenAI, der
Vergleich mit Parakeet, die Insel beim Kurzbefehl während des einmaligen
Einrichtens von Parakeet, die
Übersetzung „Auf dem iPhone“ (ab iOS 26) am Gerät, Abfrage
„Lokales Netzwerk“, Abbruch-/Unterbrechungsfälle, Dateischutz am Gerät, Verteilung über TestFlight,
Barrierefreiheit, wann die Kurzbefehle-App vor der Ausgabe fragt (auch beim
Doppeltippen?). Das Doppeltippen auf die Rückseite prüft Basti selbst; alles
andere am Gerät laufen die UI-Tests.

**Letzter Nachweis:** 14. Oktober 2026.

## Android

**Belegt:** Nichts. Kein Code, kein Plan, kein Konto.

**Offen:** Produktkonzept, Prototyp, Verteilungsweg ([ROADMAP](../ROADMAP.md#track-android)).

## Historische Evidenz

| Bericht | Aussage für seinen damaligen Kandidaten |
|---|---|
| [Linux-Spike 20. September](linux-spike-2026-09-20.md), [Phase-1-Kern 22. September](linux-phase1-core-2026-09-22.md) | Wegwahl auf omarchy/Hyprland und offline geprüfter Clipboard-Kern; kein Live-Upload |
| [Zielabnahme 17. September](target-acceptance-2026-09-17.md) | Echte Auswahlersetzung in TextEdit, Safari und Obsidian mit erzeugter Referenzsprache |
| [Roadmap 17. September](roadmap-acceptance-2026-09-17.md), [16. September](roadmap-acceptance-2026-09-16.md) | Brave-Langtext, Mikrofon-/Providerfälle, 90-Sekunden-Stopp, synthetische Feld-/Fokus-/Unicodeprüfungen |
| [Brave 15. September](brave-insertion-2026-09-15.md), [Native App 15. September](live-acceptance-2026-09-15.md), [Einstellungen](settings-acceptance-2026-09-15.md) | Synthetische Brave-Einfügung, menschliches Diktat, Bedienungs-/Fensterprüfungen |
| [22. September](live-acceptance-2026-09-22.md), [Terminal](terminal-focus-acceptance-2026-09-22.md), [autonom](autonomous-focus-acceptance-2026-09-22.md), [23. September](live-focus-acceptance-2026-09-23.md), [⌘V-Test](installed-command-v-2026-09-23.md) | Ältere Kandidaten vor dem ⌘V-Pfad und der erste negative Appwechsel |
| [13. September](live-acceptance-2026-09-13.md), [7. September](live-acceptance-2026-09-07.md) | Älteste Kandidaten; Hinweis, kein Test heutiger Builds |

Die vollständige Chronik bis zum 7. Oktober 2026 mit allen Zwischenständen
steht im [Archiv](archive/uebergabe-chronik-bis-2026-10-07.md).
