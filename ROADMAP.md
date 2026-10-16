# OpenDictate Roadmap

Stand: 13. Oktober 2026 (macOS-Beta 12 und Linux-Beta veröffentlicht); Ordnung vom 8. Oktober,
damals geprüft auf `main` `cdd4b7f`. Begründung dieser Ordnung:
[Neuordnung vom 8. Oktober](docs/roadmap-neuordnung-2026-10-08.md).

Diese Datei ist die **einzige laufende Feature- und Plattform-To-do-Liste**.
Sie hält je Plattform den belegten Stand, die nächsten Schritte in Reihenfolge
und die Grenzen fest, die bewusst den Beta-Nutzern überlassen werden. Sie
setzt keinen Termin und erteilt keine technische, Kosten-, Test- oder
Veröffentlichungsfreigabe.

Zuständigkeiten: [PROJECT.md](PROJECT.md) beschreibt Produkt, Anwendungsfälle,
Preismodell und Entscheidungen; [docs/remaining-acceptance.md](docs/remaining-acceptance.md)
hält den belegten Stand je Plattform mit Nachweisen fest; [CHECKS.md](CHECKS.md)
die Prüfwege. Die Detailpläne der Plattformen enthalten ihre konkreten
Arbeitsschritte und Prüfkriterien.

## Grundsätze seit dem 8. Oktober 2026

- **Fünf Tracks parallel.** Linux, macOS, Windows, iOS und Android werden als
  eigene Tracks vorangetrieben, weil alle für eine Beta gebraucht werden. Die
  Regel „eine Plattform zur Zeit“ vom 2. Oktober gilt nicht mehr.
- **Jeder Track endet in einer Beta** mit fremden Nutzern: GitHub Pre-Release
  mit Kennzeichnung „Beta“, GitHub Issues mit der Vorlage „Beta-Rückmeldung“ als
  einziger Feedback-Kanal, ein bis drei Ankündigungsorte je Plattform.
- **Einzelfall-Live-Tests übernehmen Beta-Nutzer.** Wir prüfen selbst nur den
  Weg, den jeder Nutzer durchläuft: Installation und ein echtes Diktat. Alles
  Weitere (einzelne Programme, Randfälle, Sprachmischungen) steht als bekannte
  Grenze in der jeweiligen Anleitung und wird nach Rückmeldung behoben. Die
  Go-Regel für Live-Tests in [AGENTS](AGENTS.md#required-verification) bleibt.
- **Jede Veröffentlichung und jede Ankündigung braucht Bastis ausdrückliches
  Go.** Nichts in dieser Datei ist eine solche Freigabe.
- **Reihenfolge der nächsten Betas (11. Oktober):** nach Linux und macOS
  zuerst iOS, danach Windows. Beide Tracks laufen parallel weiter.
- **Erledigtes wandert ins [Log](#erledigt) am Ende**, mit Datum und Link,
  statt in den Tracks stehen zu bleiben.

## Track Linux

**Ziel der Beta:** Omarchy-/Hyprland-Nutzer installieren das CLI, diktieren
mit Super+D in ihr aktives Fenster, wahlweise mit Übersetzung, und melden
Probleme über GitHub Issues.

**Stand:** Phase 1 (Clipboard-MVP) ist seit dem 5. bis 7. Oktober auf Bastis Linux-Rechner (Omarchy)
belegt: Aufnahme, Keyring, Upload, Übersetzung, Zwischenablage, Fehler- und
Abbruchfälle mit erhaltener Aufnahme und `retry`, physischer Hotkey Super+D,
Leistenanzeige mit Zielsprachen-Umschalter. Phase 2 (Auto-Einfügen in das beim
Start erfasste Fenster, mit Fokus- und Zwischenablage-Prüfung) ist Standard und
in Editor und Terminal erprobt. Basti nutzt es seit dem 7. Oktober im Alltag.
Nachweise: [Live-Nachweise 5. bis 7. Oktober](docs/linux-live-2026-10-05-bis-07.md),
[Linux-Detailplan](docs/linux-build-plan.md).

**Nächste Schritte:**

1. Linux-Beta auf Englisch (Entscheidung 8. Oktober): Das Programm spricht die
   Systemsprache, Anleitung auf Englisch und Deutsch, eigene Issue-Vorlage.
   Seit 11. Oktober zusätzlich gebaut, nur offline geprüft: eigener Server
   (Stufe 1 für ein lokales Modell, gleiche Begriffe wie auf dem Mac) und die
   geführte Einrichtung `opendictate setup` mit Kürzel-Abfrage (Super+D, F9,
   rechte Alt nur bei US-Layout). Pre-Release
   [`linux-v0.1.0-beta.1`](https://github.com/HerrStolzier/OpenDictate/releases/tag/linux-v0.1.0-beta.1)
   seit 11. Oktober veröffentlicht; der Durchlauf von `opendictate setup` auf
   Bastis Linux-Rechner folgt. Ankündigung in r/omarchy und r/hyprland vorerst nicht
   (Basti, 11. Oktober); erst wenn er das Thema wieder aufmacht.
2. Beta laufen lassen: Issues zeitnah beantworten, Rückmeldungen sammeln,
   danach entscheiden, was gebaut wird (Kandidaten: Echtzeit-Übersetzung,
   Feinjustierung der Zeitlimits, Stufe 2 mit Modell im Programm).
3. Vokabular und Verbrauchsanzeige bauen (am 16. Oktober 2026 für alle
   Plattformen beauftragt, siehe [Plattformübergreifend](#plattformübergreifend)).

**Bekannte Grenzen, den Beta-Nutzern überlassen:** Einfügen in Chromium-,
Electron- und Discord-Fenstern; gemischtes Deutsch/Englisch mit Übersetzung;
Abbruch und Netzausfall genau während der Übersetzung; die seit PR #51
kürzeren Zeitlimits (nur offline geprüft); nur Hyprland, kein anderer
Compositor; nur Arch/omarchy.

## Track macOS

**Ziel der Beta:** Mac-Nutzer (Apple Silicon, macOS 14+) laden das notarisierte
Paket, richten ihren Schlüssel ein, diktieren mit dem beim ersten Start gewählten Kürzel,
wahlweise mit Übersetzung, und melden Probleme über GitHub Issues.

**Stand:** Stufe 1 (interne Funktionsabnahme) am 24. September abgeschlossen.
Stufe 2: Build 8 aus `b786d4c` ist von Apple notarisiert, das finale ZIP samt
Manifest geprüft (SHA-256 `2e994cd8…e335768`); die private Release-Draft
`v0.1.0-beta.8` ist seit 13. Oktober gelöscht, abgelöst durch Beta 10 und 12. Teil B am 8. Oktober: installiert,
erster Start mit Quarantäne und ein Diktat mit automatischem Einfügen bestanden
([Nachweis](docs/release-plans/evidence/2026-10-08-plan2-teil-b.md)). Übersetzung und die kleinen Punkte vom 7. Oktober sind im Code und
offline geprüft ([Stand](docs/remaining-acceptance.md#macos)); ein echtes
Diktat mit Übersetzung ist mit Build 9 und Build 10 belegt
([Build 9](docs/release-plans/evidence/2026-10-08-build9.md),
[Build 10](docs/release-plans/evidence/2026-10-11-build10.md)). **Die Mac-Beta
ist seit dem 11. Oktober öffentlich**, aktuell als Pre-Release
[`v0.1.0-beta.12`](https://github.com/HerrStolzier/OpenDictate/releases/tag/v0.1.0-beta.12)
mit Build 12 aus `2d8d4ed` (seit 12. Oktober; vorher `v0.1.0-beta.10`), Download
ohne Login von außen geprüft (Hash, Notarisierung, Gatekeeper;
[Nachweis](docs/release-plans/evidence/2026-10-12-build12.md#veröffentlichung-als-beta-12-oktober-2026)). Die Stufenpläne unter
[docs/release-plans/](docs/release-plans/01-interne-produktabnahme.md) bleiben
die Quelle der Prüfkriterien; ihr Umfang ist am 8. Oktober wie unten verkleinert.

**Nächste Schritte:**

1. Ankündigung: vorerst keine (Basti, 11. Oktober). Wenn sie kommt, Go je Ort: zuerst r/macapps (nach Moderator-Hinweisen von 2026
   vermutlich im monatlichen „App Pile“-Sammelthread; Regeln vor dem Posten
   prüfen), Show HN erst
   nach den ersten Rückmeldungen, Mastodon/X über Bastis Account.
2. Beta laufen lassen: Issues beantworten, Rückmeldungen sammeln.
   Weil GitHub den macOS-14-Runner am 2. November 2026 abschaltet, prüft die
   CI seit dem 13. Oktober die älteste Xcode-16-Toolchain auf macOS 15 statt
   der macOS-14-Laufzeit ([CHECKS](CHECKS.md)).
3. Eigener Server mit lokalem Modell: erledigt mit Build 11 und Build 12
   (Live-Diktate über whisper.cpp ohne Schlüssel, siehe Erledigt). Build 12 ist
   seit dem 12. Oktober die öffentliche Beta `v0.1.0-beta.12`. Die
   vollständige UX- und VoiceOver-Prüfung bleibt bekannte Grenze der Beta.
4. Neue Diktatanzeige im neuen Design (am 9. Oktober vorgezogen, seit
   11. Oktober im Code, offline und live am Mac Mini geprüft (Menüleiste,
   schwebend, Vollbild), Notch-Maße per Vorschau am MacBook Air bestätigt;
   ein Diktat an der Notch, „Nochmal senden“ und „Aus“ sind live offen;
   parallel zur Beta): Statt des Fensters zeigt eine
   kleine Anzeige an der Notch mit Blink den Stand und schließt sich bei Erfolg
   von selbst. Macs ohne Notch zeigen sie schwebend unter der Menüleiste
   (Bastis Wahl nach dem Live-Test am 11. Oktober); flach in der Menüleiste
   oder „Aus“ lassen sich einstellen. „Beenden“ steht im
   Menü der Menüleiste
   ([design/README.md](design/README.md#stand-je-oberfläche)).
5. Für den nächsten Mac-Kandidaten (Bastis Wünsche vom 13. Oktober, noch
   nicht gebaut):
   - Im Menü und in den Einstellungen ist sichtbar, wer gerade transkribiert,
     und es gibt eine Wahl „OpenAI / Eigener Server“. Gebaut am 14. Oktober,
     noch nicht live geprüft: „Dienst“ schaltet um und behält die Server-Adresse,
     beide Seiten haben eigene Modelle. Antwortet der eigene Server nicht,
     bietet die Anzeige „Mit OpenAI senden“ für diese eine Aufnahme an; die
     App wechselt nie von selbst (Bastis Fund nach dem Neustart des Mac mini
     am 14. Oktober). Live-Test mit dem nächsten Kandidaten.
   - Die Übersetzung läuft auch lokal, ohne OpenAI. Sie braucht dafür einen
     eigenen Weg, weil der lokale whisper.cpp-Server nur transkribiert.
     Vorgesehen ist Apples Übersetzung auf dem Gerät (Translation, offline und
     kostenlos); sie gibt es ab macOS 15, unter macOS 14 bleibt es beim
     bisherigen Dienst.

**Bekannte Grenzen, den Beta-Nutzern überlassen:** Feldtypen und Programme
jenseits der [Kompatibilitätsmatrix](docs/compatibility-matrix.md); gehörte
VoiceOver-Ausgabe; frische Ersteinrichtung in einem neuen macOS-Konto;
Beenden der App, während OpenAI noch transkribiert (nur ohne Netz geprüft;
live antwortete OpenAI in zwei Versuchen vor der Bestätigung); Intel-Macs sind
nicht Teil der ersten Beta.

## Track Windows

**Ziel der Beta:** Windows-Nutzer installieren eine signierte App, diktieren
mit einem Zwei-Tasten-Kürzel in Editor, Browser und Spielchat (siehe
Anwendungsfall Gaming in [PROJECT](PROJECT.md#anwendungsfälle)) und melden
Probleme über GitHub Issues.

**Stand:** Seit 11. Oktober läuft Windows parallel; die nächste Beta ist iOS,
danach Windows ([Log](PROJECT.md#entscheidungen)). Die Windows-App unter
[windows/](windows/README.md) nimmt Modell, gesprochene Sprache, Übersetzung
nach dem Sprechen und eigenen Server aus den Einstellungen und prüft seine
Anfragen gegen die gemeinsamen Fixtures (11. Oktober, nur offline, auf Linux und
im Windows-Job der CI). Seit dem Abend des 11. Oktober gibt es die Beta-App
`OpenDictate.App`: Symbol im Infobereich, Strg+Win halten oder rechte Strg,
Einfügen per Zwischenablage, Diktatanzeige im Designsystem, Begrüßung mit
Kürzeltest. Seit dem 16. Oktober läuft sie auf Bastis Windows-PC xmg: 15
Schutzprüfungen bestanden, und Bastis Diktat mit beiden Kürzeln landete in
Notepad; der Spielchat ist noch offen ([Stand](docs/remaining-acceptance.md#windows)). Keine
Paketierung, keine Signatur. Details: [Windows-Plan](docs/windows-plan.md#weg-zur-windows-beta-stand-11-oktober-2026),
[Releaseplan](windows/RELEASE-PLAN.md).

**Nächste Schritte:**

1. ~~Modell und Sprache aus den Einstellungen statt fest; Übersetzung wie auf
   Linux; Provider-Tests gegen die gemeinsamen Fixtures.~~ Am 11. Oktober
   gebaut, offline geprüft; eigener Server gleich mit.
2. ~~Beta-App ohne Windows-Gerät bauen: Symbol im Infobereich,
   Einstellungsfenster, Kürzel Strg+Win halten (rechte Strg für Spiele),
   Einfügen per Zwischenablage und Strg+V in das beim Start erfasste Fenster,
   Texte nach Systemsprache.~~ Am 11. Oktober gebaut, offline geprüft; der
   Live-Teil gehört zu Schritt 4.
3. Paket für win-x64 mit mitgelieferter Laufzeit, Installation ohne
   Adminrechte. Ein CI-Job dafür braucht Bastis Wort. Signatur: Empfehlung
   Microsoft Store mit MSIX (kostenlos, Microsoft signiert); Konto und Wahl
   liegen bei Basti. Ohne Signatur warnt Windows jeden Nutzer beim Start.
4. Ein echtes Diktat auf einem Windows-PC: Installation, Mikrofon, Upload,
   Einfügen in den Editor und in den Spielchat im Vollbild, beide Kürzel.
   Einmal, als Installationsprüfung, auf Bastis Windows-PC xmg mit
   angeschlossenem Mikrofon; seit 16. Oktober testet Claude dort ohne Go und
   holt Basti nur für Schritte, die Hände brauchen (AGENTS.md).
5. Windows-Beta nach der iOS-Beta: Pre-Release oder Store-Testgruppe,
   Issue-Vorlage.

**Bekannte Grenzen, den Beta-Nutzern überlassen:** Programme jenseits von
Editor, Chrome-Testprofil und dem einen geprüften Spiel; Update- und
Deinstallationsweg; Verhalten mit anderen Spracheingaben wie Voice Access.

## Track iOS

**Ziel der Beta:** iPhone-Nutzer starten die Aufnahme in der Ziel-App über
die Aktionstaste oder „Auf Rückseite tippen“, ohne dass OpenDictate aufgeht,
bekommen den (wahlweise übersetzten) Text in die Zwischenablage und fügen ihn
selbst ein. Verteilung über TestFlight. Nächste Beta nach Linux und macOS,
vor Windows (11. Oktober).

**Stand:** Die Beta-App ist seit dem 11. Oktober unter [ios/](ios/README.md)
geschrieben: Kurzbefehl „Diktieren“ als Aufnahme-Kurzbefehl mit
Live-Aktivität und Stopp-Taste, Erkennung über OpenAI mit eigenem Schlüssel
oder einen eigenen Server, Übersetzung, Zwischenablage, „Nochmal senden“ nach
einem Fehler, Texte englisch und deutsch. Am 12. Oktober lief sie
zum ersten Mal auf Bastis iPhone 15: Ein Diktat aus der App kam an, der Start
über den Kurzbefehl aus dem Hintergrund scheiterte mit „Die Aufnahme konnte
nicht starten“. Seit dem 13. Oktober nimmt der Kurzbefehl per Doppeltippen im
Hintergrund auf; die Zwischenablage verweigert iOS der App dort, darum
kopiert der Kurzbefehl selbst, und so lässt sich der Text einfügen. Vorgaben für die erste Beta (11. Oktober): das
Kontrollzentrum folgt später; der
Tastatur-Prototyp bleibt als Nachweis im Repository, Draft-PR #40 ist
geschlossen ([Richtung](docs/ios-direction.md)).

**Nächste Schritte:**

1. ~~Produktkonzept auf einer Seite festlegen.~~ Erledigt am 11. Oktober
   ([Konzept](docs/ios-konzept.md)): Aufnahme im Hintergrund über einen
   Kurzbefehl mit Live-Aktivität, Ergebnis in die Zwischenablage, keine
   Vollzugriff-Tastatur, Übersetzung als Merkmal.
2. Am Mac bauen, dann der erste Prüfpunkt auf dem iPhone 15 mit Bastis Go:
   Startet die Aufnahme per „Auf Rückseite tippen“ im Hintergrund, ohne dass
   die App aufgeht, und landet der Text in der Zwischenablage? Danach die
   Abnahme aus dem Konzept. Stand 13. Oktober: Doppeltippen nimmt im
   Hintergrund auf und der Text kommt in der App an, aber iOS lässt die App
   dort nicht in die Zwischenablage schreiben. Mit dem Schritt „In
   Zwischenablage kopieren“ im Kurzbefehl kommt der Text an und lässt sich
   einfügen. Die nächste Fassung gibt beim Start nichts zurück, damit der
   Schritt die Zwischenablage nicht leert; das ist am Gerät noch zu prüfen.
3. Apples Spracherkennung auf dem Gerät (SpeechAnalyzer, ab iOS 26) als
   kostenlose Option ausprobieren und am iPhone mit OpenAI vergleichen
   (entschieden am 13. Oktober). Reicht die Qualität nicht, folgt ein
   Whisper-Modell in der App (WhisperKit). Stand 13. Oktober: als Einstellung
   „Erkennung: Auf dem iPhone“ gebaut (Sprache des iPhones, Modell einmal in
   den Einstellungen laden); am Gerät und im Vergleich noch nicht geprüft.
   Bastis Wunsch vom 13. Oktober: auch die Übersetzung lokal. Gebaut als
   „Übersetzen mit: Auf dem iPhone“ (Apples Übersetzung, ab iOS 26); am Gerät
   noch nicht geprüft. Am Mac übernimmt das der Track macOS.
   Am 14. Oktober fand Basti Apples Erkennung am iPhone spürbar schwächer
   als OpenAI; darum kommt NVIDIAs Parakeet (über FluidAudio, etwa 500 MB)
   als dritte Wahl „Erkennung: Parakeet“ dazu, als Probe. Danach Vergleich
   OpenAI, Apple und Parakeet am iPhone mit festen deutschen Sätzen
   (Wortfehler, Dauer, Lauf im Hintergrund). Vor einer Veröffentlichung ist zu
   entscheiden, woher alle Nutzer das Modell laden.
4. TestFlight-Beta. Hochladen und Tester einladen erst mit Bastis Go.
   Abhängigkeiten: Apple-Developer-Mitgliedschaft (vorhanden, Verlängerung
   September 2027), ein Zertifikat „Apple Distribution“ (am Mac noch nicht
   vorhanden) und der App-Eintrag in App Store Connect.

**Bekannte Grenzen, den Beta-Nutzern überlassen:** Einfügen in einzelne Apps,
Hintergrundverhalten, Datenschutz-Dialoge in iOS-Versionen, die nicht
getestet wurden.

## Track Android

**Ziel der Beta:** Android-Nutzer installieren eine Tastatur mit Mikrofon-Taste,
diktieren in jede App, wahlweise mit Übersetzung, und melden Probleme über
GitHub Issues. Verteilung als interner Test in Google Play oder als APK.

**Stand:** Kein Code, kein Plan. Android erlaubt eigene Tastaturen mit
Mikrofon, anders als iOS; die Nutzerrecherche vom 8. Oktober zeigt Bedarf an
Mehrsprachigkeit ohne Umschalten, Datenschutz und schnellem Zugriff.

**Nächste Schritte:**

1. Produktkonzept auf einer Seite: Tastatur mit Mikrofon-Taste oder schwebende
   Blase, Übersetzung, Schlüssel im Android-Keystore, dieselben
   Audio-/Recovery-Regeln wie überall.
2. Prototyp: Aufnahme, Upload, Einfügen über die Tastatur in eine beliebige App.
3. Android-Beta. Abhängigkeit: Google-Play-Entwicklerkonto (nicht vorhanden)
   oder APK-Verteilung mit Anleitung.

## Plattformübergreifend

| Punkt | Stand | Nächster Schritt |
| --- | --- | --- |
| Preismodell | Am 8. Oktober entschieden ([PROJECT](PROJECT.md#preismodell)): offener Code, CLI-Builds gratis, fertige App mit UI einmalig bezahlt; bis zur Firmengründung bleibt alles kostenlos. Seit 16. Oktober: 9 Euro einmalig für alle Desktop-Plattformen, die iPhone-App einzeln im App Store; Verkauf in der Reihenfolge macOS, iOS, Windows, Linux, Android; Ankündigung mit dem Verkaufsstart der Mac-App. | Vor der ersten bezahlten Version: Firmengründung, Bezahlweg, neuen Namen festlegen und als Marke anmelden (seit 16. Oktober gesucht). Keine Beta hängt daran. |
| Gaming | Ursprungs-Anwendungsfall ([PROJECT](PROJECT.md#anwendungsfälle)). Belegt: Textchat in World of Warcraft mit der Mac-App. Offen: Einfügen im exklusiven Vollbild, Zwei-Tasten-Kürzel auf jeder Plattform, Einzeltaste oder Halten-zum-Sprechen. | Im Windows-Track Schritt 4 live prüfen. Vor einer Gaming-Botschaft per Blizzard-Ticket klären, dass externe Diktier-Software geduldet ist. Hold-to-talk und Einzeltaste sind auf macOS mit der Kürzel-Abfrage gebaut (seit 11. Oktober in der veröffentlichten Beta `v0.1.0-beta.10` und `v0.1.0-beta.12`); Windows folgt mit seinem Track. |
| Kürzel-Abfrage beim ersten Start | Am 9. Oktober entschieden ([PROJECT](PROJECT.md#entscheidungen)) für die fertige (bezahlte) App: Nach der Installation fragt die App, wie die Aufnahme starten soll, und schlägt je Plattform zwei bis drei recherchierte Kürzel vor; die Empfehlung ist vorausgewählt, ein eigenes Kürzel bleibt möglich, ein Tastendruck prüft, dass es ankommt. Bestätigte Vorschläge (Recherche 9. Oktober, die erste Option ist jeweils vorausgewählt; außer macOS nicht gebaut): macOS Fn halten, rechte Wahltaste, ⌃⌥D (seit 10. Oktober ist die rechte Wahltaste vorausgewählt, wenn eine Apple-Tastatur mit Ziffernblock oder eine fremde Tastatur angeschlossen ist); Linux Super+D, F9 (Omarchys Diktiertaste), rechte Alt nur bei US-Layout; Windows Strg+Win halten, rechte Strg für Spiele, Maus-Seitentaste; iOS Aktionstaste, Auf Rückseite tippen, Steuerelement; Android Mikrofon-Taste der Tastatur, Schnelleinstellungs-Kachel, schwebende Blase. Die Mac-App hat schon eine Kürzelauswahl im Menü (drei Vorschläge, eigenes Kürzel); ihr Standard Option+Shift+Leertaste hat drei Tasten. Einzeltasten und Halten-zum-Sprechen brauchen auf macOS und Windows eine andere Technik als heute. macOS: Fn halten, rechte Wahltaste (beide mit Halten-zum-Sprechen) und die Abfrage sind gebaut, offline geprüft und am 9. Oktober live am Mac geprüft; einzelne Fälle sind noch offen ([Abnahme](docs/remaining-acceptance.md#macos)). Build 9 enthält sie nicht; Build 10 enthält sie und ist seit dem 11. Oktober als Beta `v0.1.0-beta.10` veröffentlicht ([Nachweis](docs/release-plans/evidence/2026-10-11-build10.md)). | macOS: seit `v0.1.0-beta.10` veröffentlicht, aktuell `v0.1.0-beta.12` (Build 12). Linux: seit 11. Oktober `opendictate setup` (Hinweis nach der Paketinstallation; zeigt freie und belegte Tasten, trägt die Zeile mit Sicherung in die Hyprland-Konfiguration ein), offline geprüft, live auf Bastis Linux-Rechner offen. Windows: am 11. Oktober gebaut (Strg+Win halten vorausgewählt, rechte Strg; Begrüßung mit Kürzeltest), offline geprüft, live offen. Danach iOS und Android mit ihrem Track. |
| Konfigurierbarer Endpunkt | Am 2. Oktober für macOS spezifiziert ([Plan-4-Notiz](docs/plan4-aenderungen-2026-10-02.md)); seit dem 8. Oktober für alle Plattformen gewünscht, als Antwort auf den Wunsch nach lokaler Verarbeitung. | Mac: als „Eigener Server“ umgesetzt und offline geprüft (11. Oktober, inklusive echtem Testserver auf 127.0.0.1); ein lokaler Server bekommt keinen Schlüssel und braucht keinen, damit ist ein lokales Modell kostenlos nutzbar (Basti, 9. Oktober); ein mitgeliefertes Modell kommt erst später. Nicht in Build 10; in Build 11, öffentlich seit `v0.1.0-beta.12` ([Nachweis](docs/release-plans/evidence/2026-10-11-build11.md)). Linux am 11. Oktober mit denselben Begriffen gebaut (`opendictate settings server`, Abschnitt „Custom server“ / „Eigenen Server verwenden“ in der Linux-Anleitung), offline geprüft, live offen. Windows am 11. Oktober im Prototyp gebaut (Feld „Server-Adresse“, `OPENAI_BASE_URL`, gespeicherter Wert gewinnt), offline geprüft. Nur die Adresse, `http://` nur für Loopback; eine Fremd-URL wird nicht abgenommen. |
| Provider-Vertrag | Am 2. Oktober entschieden: gemeinsame Fixtures unter `fixtures/provider/` für Swift, Rust und C#. Mac-Teil am 11. Oktober erledigt: [Vertrag](fixtures/provider/CONTRACT.md), Antwort- und Fehlerdateien, Swift-Tests lesen sie. | Linux- und Windows-Tests lesen die Dateien seit 11. Oktober; offen: Linux `validate_model` wie Mac. |
| Markenidentität 1.1 | Langfristiges Ziel vom 29. September ([PROJECT](PROJECT.md#marken--und-gestaltungsrichtung)). Das Designsystem aus Claude Design (Pixel-Terminal, Blink, grünes Signal, drei Themes) liegt seit dem 9. Oktober als gemeinsame Quelle unter [`design/`](design/README.md). Seit dem 11. Oktober nutzen es die Linux-Leiste (offline geprüft) und die Mac-Diktatanzeige (live geprüft, öffentlich seit `v0.1.0-beta.12`); die Website im neuen Design ist seit dem 11. Oktober unter opendictate.app live. | Blockiert keine Beta; die veröffentlichten Betas bleiben in ihrer Fassung. Richtung mit Basti anhand echter App-Zustände und eines Marketingbeispiels festlegen. |
| Erklärvideos mit Blink | Am 12. Oktober entschieden ([PROJECT](PROJECT.md#entscheidungen)): kurze, beeindruckende Clips mit Blink, je Funktion einer, mit Stimme, eigener Chiptune-Musik und Text im Bild, als Schleife neben dem passenden Abschnitt der Startseite und gesammelt auf einer Seite „Anleitungen“. Seit 13. Oktober als 3D-Animation in Pixel-Optik, in der Blink jeden Schritt vormacht; Blinks Stimme ist Probe L. Themen: so diktierst du, kostenlos mit eigenem Modell, Übersetzen, keine Aufnahme geht verloren, erste Schritte, iPhone-Rückseite. | Die Clips 1 bis 5 sind abgenommen (Basti, 13. Oktober 16:23) und in `website/` eingebaut: auf der Startseite seit Bastis Rückmeldung vom Abend als ein Player mit fünf Kapiteln, auf `anleitungen.html` mit Ton und Text zum Mitlesen ([website/README.md](website/README.md)). Seit 13. Oktober live auf opendictate.app. Der iPhone-Clip geht erst mit der veröffentlichten iOS-App online. Ab Ende November ersetzt die Stimme vom Mac Studio die OpenAI-Stimme. |
| Vokabular | Mac hat „Vokabular und Kontext“; Linux und Windows nicht. Laut Recherche häufiger Wunsch. Am 16. Oktober 2026 für alle Plattformen beauftragt, dazu auf Wunsch ein selbst lernendes Vokabular: lokal, standardmäßig aus, Gelerntes sichtbar und löschbar. | Je Plattform im eigenen Track bauen; OpenAIs Feld `keywords` prüfen. Lernen zuerst aus Korrekturen, die die Person in der App selbst macht; Mitlesen in fremden Textfeldern nur dort, wo das System es erlaubt, nie in Passwortfeldern, und mit eigenem Schalter. |
| Echtzeit-Übersetzung und Streaming | Weg C (`gpt-realtime-translate`) ist recherchiert, nicht gebaut ([Plan](docs/linux-live-translation-plan.md)). Streaming beim Diktieren ist seit dem 26. September gewünscht. Beides widerspricht der Regel, unbestätigte Teilergebnisse nicht ins Zielfeld zu schreiben, und braucht eigene Akzeptanzkriterien. | Erst nach Beta-Rückmeldung, dass die Wartezeit von Weg A stört. |
| Zielsprache je Anwendung | Idee aus der Recherche, nicht beauftragt. | Keiner. |
| Glätten auf Wunsch | Am 16. Oktober 2026 beschlossen ([PROJECT](PROJECT.md#grenzen-und-offene-entscheidungen)): ein sichtbarer Schalter, der Zeichensetzung und Füllwörter korrigiert; Standard bleibt die treue Abschrift, die Originalfassung muss zurückholbar sein. Nicht gebaut. | Zuerst auf macOS im Track macOS, danach die anderen Plattformen in ihren Tracks; vorher festlegen, ob lokal oder über den gewählten Dienst geglättet wird, und den Datenfluss in `PRIVACY.md` nachziehen. |
| Verbrauchsanzeige in der App | Wunsch von Basti vom 8. Oktober: Nutzer sollen ihren Verbrauch (zum Beispiel pro Tag) direkt in der App sehen, ohne sich im Dashboard des Anbieters anzumelden, ähnlich den Verbrauchsmodulen anderer Plattformen. Am 16. Oktober 2026 für alle Plattformen beauftragt. Zwei Wege sind denkbar: lokal mitzählen (Audiosekunden je Diktat mal Listenpreis des gewählten Modells, Übersetzungs-Tokens aus der `usage`-Antwort) oder die Verbrauchs- und Kostenschnittstelle des Anbieters abfragen, die nach aktuellem Stand einen Admin-Schlüssel statt des normalen API-Schlüssels verlangt. | Je Plattform im eigenen Track bauen; lokales Mitzählen ist der wahrscheinlichere Weg, weil es mit dem vorhandenen Schlüssel auskommt. Preise als änderbare Tabelle, Zähler lokal und ohne Transkripte; Datenfluss in `PRIVACY.md` nachziehen. |
| Support-Backend | Am 8. Oktober entschieden ([PROJECT](PROJECT.md#entscheidungen)): eigenes kleines Backend statt fertiger Ticketsoftware. Seit dem 11. Oktober live unter support.opendictate.app (eigenes privates Repository): Kontaktformular und support@opendictate.app werden Tickets, ein Dashboard nur für Basti hinter Cloudflare-Anmeldung, Antworten gehen direkt aus dem Dashboard raus. Impressum und Datenschutzerklärung liefert das Backend selbst. Der Agent, der sortiert und Entwürfe schreibt, ist aus. Seit dem 13. Oktober gibt es das Formular auch auf Englisch, und scheitert eine Anfrage, bekommt Basti eine Mail (Protokoll ohne IP-Adressen). Am 13. Oktober ist der ganze Weg einmal echt geprüft: Anfrage über das Formular, Hinweis-Mail an Basti, Antwort aus dem Dashboard und Rückantwort per Mail ins selbe Ticket. Dabei fiel auf, dass Formular und Dashboard seit dem Start jedes Absenden aus dem Browser abgelehnt hatten (die Seite verbot dem Browser, die Herkunft mitzuschicken); am selben Tag behoben, das Prüfskript kontrolliert es seitdem. | Agent erst nach der Auftragsverarbeitung mit OpenAI einschalten (Entscheidung 11. Oktober); Spamschutz für das Formular, falls nötig. KI-Chatbot später als weiterer Eingang. |
| Sicherheitsprüfung vom 11. Oktober | Code aller Plattformen, das Support-Backend und die Cloudflare-Einstellungen wurden am 11. Oktober lesend auf Sicherheitslücken geprüft: keine kritische Lücke, die Kernregeln (Schlüssel nur im Schlüsselbund, kein Schlüssel an einen lokalen Server, keine Weiterleitungen, Aufnahme überlebt Fehler, Einfügen nur ins gemerkte Programm) sind überall umgesetzt. Erledigt am selben Tag: Die Domain erzwingt HTTPS ([PROJECT](PROJECT.md#entscheidungen)), und die Code-Befunde aller Plattformen sind in einem gemeinsamen PR statt je Plattform behoben (siehe [Log](#erledigt)); Basti hat am Abend „Code-Befunde beheben“ beauftragt. Der vollständige Bericht liegt in der Projektbibliothek, nicht im Repository. | Zwei-Faktor-Anmeldung für das Cloudflare-Konto (nur Basti). Die Support-Backend-Fixes (Gesamtlimit des Formulars, Betreff auf einer Zeile, Dashboard ohne Browser-Cache) sind seit dem 11. Oktober live. |
| Fehler melden | Am 13. Oktober entschieden ([PROJECT](PROJECT.md#entscheidungen), [Ablauf](docs/fehler-melden.md)): „Fehler melden …“ öffnet das Support-Formular mit einem Bericht, den die Person sieht und selbst abschickt; kein Tracking. Support-Backend nimmt die Berichte an und zeigt sie gruppiert nach Fehler (live seit 13. Oktober 2026, Prüfskript von außen grün). | macOS: Menüpunkt und Knopf in der Fehlermeldung, mit dem nächsten Mac-Build. Linux: `opendictate report`. Je Plattform `PRIVACY.md` im selben Änderungssatz nachziehen. |
| Alte verwaiste Audiooriginale nach Absturz | Regel seit 13. Oktober ([PROJECT](PROJECT.md#entscheidungen)): Aufnahmen bleiben 24 Stunden und werden danach entfernt. Automatisch gelöscht wird nur, was die App eindeutig als ihr eigenes Aufnahme-Journal erkennt, nie fremde oder unklare Dateien. Windows löscht seit 14. Oktober beim Start eigene Journalordner im Aufnahmeordner, sobald sie 24 Stunden alt sind; Ordner mit fremden Dateien bleiben ([Windows-README](windows/README.md#beta-app-11-oktober-2026)). | Mac: liegengebliebene Originale und Dateien älterer Versionen nach derselben Regel zuordnen und bereinigen; mit Verlust- und Manipulationsfällen abnehmen. |

## Erledigt

| Datum | Ergebnis | Nachweis |
| --- | --- | --- |
| 16. Oktober 2026 | Website in acht Sprachen live: Deutsch bleibt unter `/`, dazu Englisch, Französisch, Spanisch, Italienisch, Portugiesisch, Niederländisch und Polnisch unter `/en/` usw., mit Sprachwahl, `hreflang`, Sitemap-Alternativen und übersetzten Untertiteln. Der Produktname steht nur in `website/i18n/site.json`. Der Worker liefert Commit `5f07fe1`. | [#145](https://github.com/HerrStolzier/OpenDictate/pull/145), [website/README.md](website/README.md#sprachen); Bastis Karte „Live schalten“ |
| 13. Oktober 2026 | Startseite neu gestaltet und live: ein Player mit fünf Kapiteln statt vier gleichzeitig startender Video-Kästen, „Einmal zahlen, nicht jeden Monat“ mit Einmalzahlung statt Abo, „Mit lokalem Modell / Deine Stimme bleibt bei dir“ mit Weg-Grafik, Untertitel auf „Anleitungen“, Werte aus den Design-Tokens. Handy-Leistung in Lighthouse 84 → 98 (lokale Vorschau). Der Worker liefert Commit `f887c31`. | [#123](https://github.com/HerrStolzier/OpenDictate/pull/123), [website/README.md](website/README.md); Bastis Karten „Live schalten“ und „Mit live“ |
| 13. Oktober 2026 | Erklärvideos mit Blink auf opendictate.app live: fünf stumme Schleifen mit Pause-Knopf auf der Startseite, alle fünf mit Ton und Text zum Mitlesen auf der neuen Seite „Anleitungen“; der Abschnitt Datenschutz steht als zweites Argument direkt nach den Kosten. Alle zehn Videos und fünf Standbilder live per Browser Rendering geladen. Der Worker liefert Commit `d6e6adf` aus. | [website/README.md](website/README.md), [website/worker.js](website/worker.js) |
| 12. Oktober 2026 | Website zeigt auf die Mac-Beta 12: Download-Knöpfe und strukturierte Daten auf `v0.1.0-beta.12`, die 0-€-Karte sagt „Am Mac und unter Linux“, die Notch-Animation ist keine Vorschau mehr. Der Worker liefert Commit `5c8bffe` aus. | [website/README.md](website/README.md), [website/worker.js](website/worker.js) |
| 12. Oktober 2026 | Mac Build 12 aus `2d8d4ed` notarisiert, als Update installiert und als Pre-Release `v0.1.0-beta.12` veröffentlicht. Diktat mit mehreren Pausen über einen lokalen whisper.cpp-Server ohne Schlüssel kam als ein Absatz; vorher am 11. Oktober vier lokale Diktate mit Build 11. | [Build 12](docs/release-plans/evidence/2026-10-12-build12.md), [Build 11](docs/release-plans/evidence/2026-10-11-build11.md#eigener-server-mit-lokalem-modell) |
| 12. Oktober 2026 | Blink rennt in der Website-Fußzeile nur noch, solange seine ganze Laufbahn im Fenster ist, und wird am Desktop beim Hochscrollen nicht mehr abgeschnitten. Der Worker liefert Commit `39738a9` aus. | [website/README.md](website/README.md), [website/worker.js](website/worker.js) |
| 12. Oktober 2026 | Kurze Startseite live (rund 370 Wörter, 0,1 ct pro Diktat vorn, Bastis Satz unter „Probier es aus“) mit Vorschaubild für geteilte Links, strukturierten Daten, `sitemap.xml` und `robots.txt`. Der Worker liefert Commit `8b13db2` aus. | [website/README.md](website/README.md), [website/worker.js](website/worker.js) |
| 12. Oktober 2026 | Website mit dem Preis vorn live („Diktieren ohne Abo“: 0 € mit Modell auf dem eigenen Rechner, rund 0,1 ct pro Diktat mit OpenAI); Blink bleibt am Handy beim Antippen der Zustände im Bild. Der Worker liefert Commit `2d8d4ed` aus. | [website/README.md](website/README.md), [website/worker.js](website/worker.js) |
| 11. Oktober 2026 | Code-Befunde der Sicherheitsprüfung in einem PR behoben, alle Plattformen: Steuerzeichen und unsichtbare Richtungszeichen aus der Serverantwort entfernt; mehrzeiliger Text wird in bekannte Terminals und Konsolen nicht automatisch eingefügt (Linux, macOS, Windows); Zwischenablage ohne Chronik und Cloud-Sync (Windows), mit `ConcealedType` (macOS) und „nur lokal“ (iOS); macOS übernimmt den alten Schlüsselbund-Eintrag beim Lesen und erneuert den Schlüsselbund-Helfer nach einem Zertifikatswechsel; iOS ersetzt den Schlüssel erst nach erfolgreichem Schreiben; Linux bricht ohne `XDG_RUNTIME_DIR` mit Meldung ab. Nur offline geprüft (Linux 87 Tests, Core- und Windows-Prüfungen in CI). | [PRIVACY](PRIVACY.md#clipboard-and-automatic-insertion) |
| 11. Oktober 2026 | Windows-Prototyp nimmt Modell, Sprache, Übersetzung nach dem Sprechen und eigenen Server aus den Einstellungen; Provider-Prüfungen lesen die gemeinsamen Prüfdateien (nur offline geprüft). | [Windows-Plan](docs/windows-plan.md#weg-zur-windows-beta-stand-11-oktober-2026) |
| 11. Oktober 2026 | Website-Fußzeile verlinkt das Kontaktformular des Supports; der Worker liefert die Dateien aus Commit `87cec8b` aus. | [website/worker.js](website/worker.js) |
| 11. Oktober 2026 | Windows-Beta-App gebaut: Infobereich, Strg+Win halten oder rechte Strg, Einfügen per Zwischenablage ins erfasste Fenster, Diktatanzeige und Begrüßung mit Kürzeltest (nur offline geprüft, nicht gestartet). | [Windows-README](windows/README.md#beta-app-11-oktober-2026) |
| 11. Oktober 2026 | Website im neuen Design live unter opendictate.app (Cloudflare Worker, Dateien aus Commit `8d178ed` mit Fingerabdruck geprüft); Impressum und Datenschutz verlinkt; Cloudflare Web Analytics für die ganze Domain aus. | [website/README.md](website/README.md#auslieferung) |
| 11. Oktober 2026 | Linux-Beta als Pre-Release `linux-v0.1.0-beta.1` veröffentlicht: eigener Server, `opendictate setup` mit Kürzel-Abfrage (PR #67, #73); Provider-Tests lesen die gemeinsamen Prüfdateien. | [Release](https://github.com/HerrStolzier/OpenDictate/releases/tag/linux-v0.1.0-beta.1) |
| 11. Oktober 2026 | macOS-Beta veröffentlicht: Pre-Release `v0.1.0-beta.10` mit Build 10 (`a1903a9`), Download von außen geprüft; Website, README und Anleitung auf Build 10 (PR #60). | [Release](https://github.com/HerrStolzier/OpenDictate/releases/tag/v0.1.0-beta.10), [Build-10-Nachweis](docs/release-plans/evidence/2026-10-11-build10.md) |
| 8. Oktober 2026 | macOS Build 9 aus `46103b0`: notarisiert, als Update per Finder installiert, Diktat mit Übersetzung nach Englisch, Originalaufnahme von Anfang an `0600` (PR #58). | [Nachweis](docs/release-plans/evidence/2026-10-08-build9.md) |
| 8. Oktober 2026 | macOS Stufe 2 Teil B: Build 8 installiert, erster Start mit Quarantäne, Diktat mit Einfügen. Beenden während der Transkription als bekannte Grenze eingetragen. | [Nachweis](docs/release-plans/evidence/2026-10-08-plan2-teil-b.md) |
| 8. Oktober 2026 | Linux: Beta-Anleitung in `linux/README.md` und Arch-Paket ([PKGBUILD](linux/packaging/arch/PKGBUILD)); von Basti auf seinem Linux-Rechner (Omarchy) installiert, Diktat mit Übersetzung über das Paket (PR #57). | [Live-Nachweise](docs/linux-live-2026-10-05-bis-07.md#live-nachweis-arch-paket--8-oktober-2026) |
| 7. Oktober 2026 | Linux: Abbruch und Netzausfall während der Transkription behalten die Aufnahme; Zeitlimits auf Sekunden statt zwei Minuten (PR #51). | [Live-Nachweise](docs/linux-live-2026-10-05-bis-07.md) |
| 7. Oktober 2026 | macOS: temporäre Aufnahmen tragen `0600`, live geprüft (PR #49); Löschfehler nur einmal pro Start geloggt (PR #50); die alte Aufnahme vom 15. September ist gelöscht. | [Stand macOS](docs/remaining-acceptance.md#macos) |
| 5. bis 6. Oktober 2026 | Linux: Übersetzung nach dem Sprechen, Leistenanzeige, Auto-Einfügen, Hotkey Super+D (PR #45, #47). Phase 1 damit belegt. | [Live-Nachweise](docs/linux-live-2026-10-05-bis-07.md) |
| 5. Oktober 2026 | Aus dem Branch `rescue/grok-clone-2026-09` drei Härtungen übernommen (PR #46); Rest bleibt liegen. | [PROJECT](PROJECT.md#entscheidungen) |
| 2. Oktober 2026 | Zielgruppe und Kostenargument in PROJECT, README und Website festgeschrieben. Das „ca.“ im Modellmenü ist inzwischen umgesetzt ([Stand macOS](docs/remaining-acceptance.md#macos)). | [Plan-4-Notiz](docs/plan4-aenderungen-2026-10-02.md) |
| 2. Oktober 2026 | macOS Build 8 notarisiert, finales Paket geprüft. | [Nachweis](docs/release-plans/evidence/2026-10-02-plan2-build8-final.md) |
| 28. September 2026 | Code-Reduktionsversuch: fünf Zeilen weniger, Coverage ohne Verlust; das 10%-Ziel wurde nicht erreicht und nicht erzwungen. | [Bewertung](docs/code-reduction-2026-09-28.md), [Projekt-Audit](docs/project-audit-2026-09-28.md) |
| 24. September 2026 | macOS Stufe 1 (interne Funktionsabnahme) abgeschlossen. | [Plan-1-Bericht](docs/release-plans/evidence/2026-09-24-plan1-fortsetzung.md) |
