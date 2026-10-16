# OpenDictate für Windows: Entwicklungsstand

Dieses Verzeichnis enthält die Windows-App von OpenDictate (Beta, noch nicht
veröffentlicht). Basti hat am 28. September 2026 **öffentliche Verteilung als Ziel**
gewählt. Es gibt noch kein Windows-Release, keinen Produktinstaller, keine
Signatur und keine Freigabe zur Veröffentlichung. Der nächste Releasepfad steht
im [Windows-Releaseplan](RELEASE-PLAN.md). Die Herkunft des ersten Imports steht
in [PROVENANCE.md](PROVENANCE.md). Die Prüfsummen dieses Imports liegen seit
14. Oktober 2026 im Archiv
([windows-import-9bf554e-SHA256SUMS](../docs/archive/windows-import-9bf554e-SHA256SUMS));
sie gelten nur für den Import (Commit `9bf554e`), nicht für den heutigen Stand.
Prüfen lässt es sich so: `git archive 9bf554e windows | tar -x -C <leerer Ordner>`,
dann im entpackten `windows/` `sha256sum -c SOURCE-SHA256SUMS` (die Datei liegt
dort noch unter ihrem alten Namen).

## Aktueller technischer Stand

- Die App (`OpenDictate.App`) nutzt WPF und WinForms auf .NET 10 und zielt auf
  `net10.0-windows`, nur x64; Kern und Provider zielen auf `net10.0`.
  `global.json` verlangt SDK `10.0.401` mit `latestPatch`.
  `Directory.Build.props` aktiviert Nullable-Checks, Warnungen als Fehler und
  deterministische Compileroptionen.
- `NAudio.Wasapi` 3.1.0 ist die einzige direkte Paketabhängigkeit der App.
  Jedes Projekt hat eine `packages.lock.json` mit Versionen und
  Inhalts-Hashes aller Pakete; `nuget.config` erlaubt nur nuget.org als
  Quelle. Die CI stellt die Pakete mit `dotnet restore --locked-mode` her und
  bricht ab, wenn ein Paket von der Sperrdatei abweicht. Nach einer Änderung an
  den Paketen die Sperrdateien mit `dotnet restore` neu erzeugen und mit
  einchecken. Ein geprüfter `dotnet publish`-Pfad und ein Installerprojekt
  sind nicht vorhanden. `Deterministic=true` allein belegt keinen bitgleichen
  Release-Build.
- Das App-Manifest fordert normale Benutzerrechte (`asInvoker`).
- Das frühere Prüffenster (`OpenDictate.Prototype`) mit Einfügen in Editor-
  und Browserfelder, der Browser-Host und die Test-Erweiterung wurden am
  13. Oktober entfernt: Der Weg über die Zwischenablage ersetzt sie, und sie
  wären nur weiter gebaut und geprüft worden, ohne je ausgeliefert zu werden.
  Ihr Stand bleibt im Import-Commit `9bf554e` und in der Git-Geschichte.

## Einstellungen, Übersetzung und eigener Server (11. Oktober 2026)

- `OpenDictate.Provider` (`net10.0`, ohne Windows-Abhängigkeit) baut die
  Anfragen nach dem [Provider-Vertrag](../fixtures/provider/CONTRACT.md):
  Transkription mit Modell und gesprochener Sprache aus den Einstellungen,
  danach wahlweise Übersetzung über `/chat/completions` (Standard
  `gpt-5.4-mini`), beides an OpenAI oder an einen eigenen Server.
- Einstellungen liegen ohne Geheimnis in `%APPDATA%\OpenDictate\settings.json`.
  Eine beschädigte Datei wird abgelehnt und nicht überschrieben. Die
  Server-Adresse ist die Basis-URL mit `/v1`. Ohne Eintrag gilt
  `OPENAI_BASE_URL`, wenn gesetzt (die Einstellungen nennen dann das Ziel), sonst
  OpenAI; ein gespeicherter Eintrag gewinnt. Ist unter „Dienst“ OpenAI
  gewählt, gilt auch die Variable nicht. `http://` geht nur für
  diesen Computer, und dorthin geht kein Schlüssel. Jeder andere eigene
  Server, auch einer aus `OPENAI_BASE_URL`, bekommt den gespeicherten
  OpenAI-Schlüssel als Bearer-Token. Trag darum nur Server ein, denen du
  vertraust. Ein eigener Server nimmt freie Modellnamen, OpenAI nur die
  bekannten.
- **Dienst** (seit 16. Oktober): Eine Auswahl „OpenAI“ oder „Eigener Server“
  bestimmt, wohin Diktate gehen. Die Adresse bleibt gespeichert, wenn OpenAI
  gewählt ist, und jede Seite hat eigene Modelle für Erkennung und
  Übersetzung, damit ein Wechsel keinen falschen Modellnamen schickt. Ein
  leeres Adressfeld wählt OpenAI, wenn auch `OPENAI_BASE_URL` leer ist; die
  erste Adresse wählt den eigenen Server; sonst bleibt die Wahl, wie sie ist. Die App wechselt nie von
  selbst: Fehlt beim eigenen Server die Adresse oder ist sie ungültig, bricht
  das Diktat mit einer Meldung ab. Ältere Einstellungen mit Server-Adresse
  (auch einer nur aus `OPENAI_BASE_URL`) wählen den eigenen Server, geben ihm
  ihre Modellnamen und schreiben diese Wahl in `settings.json`; ein bekanntes
  OpenAI-Modell bleibt für OpenAI. Das Adressfeld steht direkt unter der
  Wahl „Eigener Server“; ohne Adresse wird diese Wahl erst mit dem Speichern
  einer Adresse wirksam. Die Modellnamen stehen im aufklappbaren Bereich
  „Modelle“. „Mit OpenAI senden“ für eine einzelne
  Aufnahme wie am Mac gibt es auf Windows noch nicht.
- Meldungen erscheinen auf Deutsch oder Englisch nach der Anzeigesprache von
  Windows und enthalten nie die Antwort des Servers; eine Netzwerkmeldung zum
  eigenen Server nennt nur dessen Host.
- Die Provider-Prüfungen laufen mit `OpenDictate.Checks` (auch auf Linux und
  im Windows-Job der CI); `OpenDictate.WindowsChecks` enthält die 14
  Schutzprüfungen.
- Kein echtes Diktat, keine Anfrage an OpenAI oder an ein lokales Modell; den
  aktuellen Prüfstand nennt der Abschnitt „Beta-App“.

## Beta-App (11. Oktober 2026)

`OpenDictate.App` (Programmname `OpenDictate.exe`) ist die App für die
Windows-Beta.

- Die App lebt im Infobereich der Taskleiste: Diktat starten oder beenden (dann
  nur Zwischenablage), Letzten Text kopieren, Letzte Aufnahme nochmal senden
  (mit Rückfrage, weil es bei OpenAI erneut kostet; danach nur Zwischenablage),
  Einstellungen, Beenden. Ein zweiter Start öffnet die Einstellungen.
- Kürzel: **Strg+Win** (Standard) oder **rechte Strg** (für Spiele, deren
  Tastaturen die Win-Taste sperren). Seit 16. Oktober wählt „So nimmst du
  auf“, wie es startet: **Gedrückt halten** (Standard): Nach 0,3 Sekunden
  Halten beginnt die Aufnahme, Loslassen beendet sie; kommt während der
  Aufnahme eine andere Taste dazu, wird abgebrochen und die Aufnahme
  gesichert. **Antippen**: Ein kurzer Druck (unter 0,3 Sekunden) startet, der
  nächste stoppt; längeres Drücken tut nichts. Kommt eine andere Taste dazu,
  zählt der Druck in beiden Arten nicht (Strg+Win+D oder rechte Strg+C bleiben
  frei). Bei Strg+Win müssen vor dem nächsten Druck beide Tasten los sein. Ein systemweiter Tastatur-Hook beobachtet nur und gibt
  jede Taste unverändert weiter. Damit beim Loslassen von Strg+Win kein
  Startmenü aufgeht, sendet die App einmal die unbelegte Taste `0xE8`.
- Einfügen: Der Text kommt in die Zwischenablage, markiert als nicht für den
  Zwischenablage-Verlauf und die Cloud-Zwischenablage bestimmt. Dort bleibt er,
  bis etwas anderes kopiert wird; Programme, die die Zwischenablage mitlesen,
  sehen ihn. Steuerzeichen
  aus der Antwort des Dienstes werden vorher entfernt. Strg+V folgt nur in das
  Fenster, das beim Start vorne war, wenn es noch vorne ist, alle
  Zusatztasten losgelassen sind und die Zwischenablage noch den Text hält;
  sonst bleibt der Text in der Zwischenablage („Kopiert“). Text mit
  Zeilenumbruch wird nicht in Konsolen (Windows Terminal, cmd, PowerShell und
  andere) eingefügt, weil ein Zeilenumbruch die diktierte Zeile als Befehl
  ausführen würde; er bleibt in der Zwischenablage. Abschaltbar mit
  „Automatisch einfügen“. Strg+V wird als Scancode im Tastaturlayout des
  Zielfensters gesendet, weil manche Spiele nur diesen lesen; ob jedes Spiel
  es annimmt, ist erst live prüfbar.
- Grenze: In ein Programm, das mit Adminrechten läuft, lässt Windows eine
  normale App nicht tippen; das Strg+V verpufft dort, ohne dass die App es
  merkt, und die Anzeige kann trotzdem „Eingefügt“ zeigen. Der Text liegt
  dann in der Zwischenablage und lässt sich von Hand einfügen. Ob das Kürzel
  in einem solchen Fenster überhaupt ankommt, ist live noch offen.
- Die kleine Anzeige oben auf dem Bildschirm zeigt Hört zu (mit Zeit und
  Pegel), Schreibt, Eingefügt, Kopiert oder Hoppla mit dem Grund und, wenn die
  Aufnahme gesichert ist, „Nochmal senden“. Sie nimmt nie den Fokus. Farben,
  Abstände und Schriften (Geist, mitgeliefert unter der SIL Open Font License)
  kommen aus dem Designsystem (`OpenDictate.Core/DesignTokens.cs`, erzeugt von
  `scripts/design-tokens.py`); das Symbol baut `scripts/make-icon.py` aus Blink.
- Das Einstellungsfenster ist seit 16. Oktober dunkel (Theme Nacht) wie die
  Anzeige: Blink mit dem Zustand („Bereit“, „Schlüssel fehlt“ oder „Hoppla“)
  und dem Ziel, Karten für Tastenkürzel, Dienst und Sprache, Schalter statt
  Häkchen, Knöpfe mit Stufenecken. Das Fenster ist höchstens 780 Pixel hoch,
  der Inhalt scrollt, „Fertig“ bleibt unten. Die Stile stehen in
  `OpenDictate.App/Theme.xaml`, ihre Farben und Schriften setzt `Brand.cs` aus
  `DesignTokens.cs`; unter Windows 11 nimmt die Titelleiste die Hintergrundfarbe an.
- Beim ersten Start öffnen sich die Einstellungen mit einer Begrüßung und dem
  Kürzeltest: Solange das Fenster vorne ist, meldet es „Erkannt“, statt
  aufzunehmen. Jede Wahl wird sofort gespeichert; scheitert das Speichern,
  bleiben Kürzel und gespeicherte Wahl beim alten Wert. „Mit Windows starten“
  setzt einen Eintrag unter dem Run-Schlüssel des Benutzers.
- Aufnahmen entstehen unter `%LOCALAPPDATA%\OpenDictate\Recordings` und werden
  vor dem Senden als geschützte Kopie unter `%LOCALAPPDATA%\OpenDictate\Recovery`
  gesichert (höchstens fünf, 24 Stunden); erst danach verschwindet das
  Original. Bleibt ein Original im Aufnahmeordner liegen, weil die App vorher
  endete oder die Sicherung scheiterte, löscht die App es beim nächsten Start,
  sobald es 24 Stunden alt ist, nie früher; ein Ordner mit fremden Dateien
  bleibt unangetastet. Kürzer als eine halbe Sekunde wird nicht von selbst gesendet und
  lässt sich nicht nochmal senden, bleibt aber gesichert. Bricht die Aufnahme
  ab, weil das Mikrofon wegfällt, wird das Aufgenommene ebenso gesichert und
  lässt sich nochmal senden. Hält ein anderes Programm (etwa ein Virenscanner)
  eine alte Sicherung offen, bleibt sie bis zum nächsten Aufräumen liegen; das
  neue Diktat scheitert daran nicht, und angeboten werden nur die fünf neuesten.
- Geprüft am 14. Oktober nur offline auf Linux mit .NET SDK 10.0.401: 54 von
  54 Prüfungen (8 Kern-, 9 Ablauf-, 17 Provider- und 20 Kürzel-/App-Prüfungen),
  Beta-App und Schutzprüfer bauen ohne Warnung.
- Am 16. Oktober auf Bastis Windows-PC aus `40911f3` gebaut und installiert:
  54 Prüfungen und alle 15 Schutzprüfungen bestanden; ein Diktat über das
  Menü im Infobereich lief mit Mikrofon, Anzeige und Zwischenablage durch, das
  Startmenü blieb zu, „Mit Windows starten“ schaltet an und aus. Kürzel und
  Strg+V brauchen echte Tasten, weil die App künstliche Tastendrücke ignoriert:
  Basti diktierte mit Strg+Win und mit der rechten Strg-Taste in Notepad, der
  Text wurde automatisch eingefügt. Offen ist der Spielchat im Vollbild
  (Windows-Plan, Schritt 7); er hält Paket und Signatur nicht auf.
- Dienst und Art des Kürzels (16. Oktober): auf Linux offline geprüft, 58 von
  58 Prüfungen (8 Kern-, 9 Ablauf-, 19 Provider- und 22 Kürzel-/App-Prüfungen),
  Beta-App und Schutzprüfer bauen ohne Warnung. Auf xmg aus `37518c3`:
  58 von 58 Prüfungen, 15 von 15 Schutzprüfungen, beide Auswahlen bedienbar.
  Mit Adresse `http://127.0.0.1:9/v1` und „Eigener Server“ endete ein
  Menü-Diktat mit „Dein Server (127.0.0.1) ist nicht erreichbar …“, ohne
  Verbindung zu OpenAI, und die Aufnahme blieb gesichert; nach dem Wechsel auf
  OpenAI blieb die Adresse gespeichert und das Diktat ging an OpenAI. Danach
  diktierte Basti mit „Antippen“ und echter Tastatur in Notepad: Der Text kam an.

## Heutige Offline-Prüfung, 28. September 2026

- **41 bestehende Offline-Checks bestanden:** 14 Kern-/Bridge- und neun
  Ablaufchecks sowie 18 Schutz-/Providerchecks. Die 18 Schutzchecks liefen in
  einer angemeldeten interaktiven Windows-Sitzung mit einem eigens angelegten
  Dummy-Zugangseintrag; die temporäre Kopie, Dateien, Aufgabe und der Eintrag
  wurden danach bereinigt.
- App und Browser-Host wurden mit dem vorhandenen .NET SDK ohne Warnungen oder
  Fehler gebaut. Die Dateiprüfsummen von 37 Quell-, Projekt- und Skriptdateien
  stimmten mit dem separat geprüften Windows-Archiv überein.
- Die Credential-Manager-Prüfung ist an eine angemeldete Windows-Sitzung
  gebunden. In SSH-Sitzung 0 trat für den Lesezugriff der Windows-Fehler 1312
  auf; im interaktiven Lauf bestanden anschließend alle 18 Schutzchecks.
- Es gab dabei keinen Start oder keine Installation der Produkt-App, keine
  echte API-Zugangsdatenverwendung, keine Mikrofonaufnahme und keine
  Provideranfrage. Die Offline-Prüfungen sind keine Live-Diktatabnahme.

Der [Plattformbericht](../docs/platform-audit-2026-09-28.md) hält die
ursprüngliche 37-Datei-Prüfung und die ersten 23 Offline-Checks fest. Die dort
noch offenen 18 Schutzchecks bestanden anschließend im interaktiven Desktoplauf;
der aktuelle Gesamtstand ist oben mit 41/41 angegeben. Der spätere Lauf ist
in der [Plattform-Fortsetzung](../docs/platform-continuation-2026-09-28.md)
mit Prüfweg und Bereinigung dokumentiert. Historische Editor- und
isolierte Chrome-Prüfungen gelten nur für den dort benannten Kandidaten, die
konkret geprüften Felder und Zeitpunkte. Sie versprechen keine Unterstützung
beliebiger Editoren, Browser oder Webseiten.

## Umfang von `scripts/check.ps1`

Das vorhandene Skript:

1. zeigt die SDK-Version an und führt `OpenDictate.Checks` aus (Kern-, Ablauf-,
   Provider-, Kürzel-/App- und gemeinsame Fixture-Prüfungen),
2. baut `OpenDictate.App`,
3. baut `OpenDictate.WindowsChecks`.

Es **führt `OpenDictate.WindowsChecks` nicht aus**. Ein erfolgreicher Skript-
lauf würde daher die 15 Credential-Manager-/Recovery-Prüfungen nicht belegen.
Das Skript startet und installiert die App nicht; echte Aufnahme und
Provideraufruf gehören nicht zu seinen Prüfungen. Das Bauen kann NuGet-Restore
benötigen, falls die Abhängigkeit lokal noch nicht vorhanden ist. Das Skript
wurde bei dieser Dokumentation nicht ausgeführt.

## Prüfbefehle auf Windows

In einer PowerShell am Repository-Stamm:

```powershell
./windows/scripts/check.ps1
```

Die Schutz-/Providerprüfungen sind ein eigener Ablauf und benötigen eine
angemeldete normale Windows-Sitzung. Sie dürfen nur in einer isolierten
Prüfumgebung mit einem Dummy-Zugangseintrag ausgeführt werden; sie verwenden
keinen echten OpenAI-Schlüssel. Diese Dokumentation startet keinen dieser
Abläufe.

## Fehlerbericht im Kern

`ProblemReport` baut offline die begrenzte Support-Adresse nach
[dem gemeinsamen Vertrag](../docs/fehler-melden.md). Es übernimmt nur feste
Diagnosekategorien, keine rohen Protokollmeldungen. Die Prüfungen lesen das
plattformübergreifende Beispiel in `fixtures/report/`. Ein Menüpunkt und das
Öffnen des Browsers sind in dieser Änderung noch nicht angeschlossen.
