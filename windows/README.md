# OpenDictate für Windows: Entwicklungsstand

Dieses Verzeichnis enthält einen versionierten Quellsnapshot des Windows-
Prototyps. Basti hat am 28. September 2026 **öffentliche Verteilung als Ziel**
gewählt. Es gibt noch kein Windows-Release, keinen Produktinstaller, keine
Signatur und keine Freigabe zur Veröffentlichung. Der nächste Releasepfad steht
im [Windows-Releaseplan](RELEASE-PLAN.md); Herkunft und Prüfsummen stehen in
[PROVENANCE.md](PROVENANCE.md) und [SOURCE-SHA256SUMS](SOURCE-SHA256SUMS).

## Aktueller technischer Stand

- Die App nutzt WPF und WinForms auf .NET 10. Das WPF-Projekt zielt auf
  `net10.0-windows10.0.19041.0`; `global.json` verlangt SDK `10.0.401` mit
  `latestPatch`. `Directory.Build.props` aktiviert Nullable-Checks,
  Warnungen als Fehler und deterministische Compileroptionen.
- `NAudio.Wasapi` 3.1.0 ist die einzige direkte Paketabhängigkeit der App.
  Eine `packages.lock.json`, ein geprüfter `dotnet publish`-Pfad und ein
  Installerprojekt sind nicht vorhanden. `Deterministic=true` allein belegt
  keinen bitgleichen Release-Build.
- Das App-Manifest fordert normale Benutzerrechte (`asInvoker`). Der
  Browser-Host und die Extension sind Entwicklungs-/Testkomponenten. Die
  installierbare Browserprobe beschränkt Seitenzugriff auf `127.0.0.1`; sie
  begründet keine allgemeine Browserunterstützung.

## Einstellungen, Übersetzung und eigener Server (11. Oktober 2026)

- `OpenDictate.Provider` (`net10.0`, ohne Windows-Abhängigkeit) baut die
  Anfragen nach dem [Provider-Vertrag](../fixtures/provider/CONTRACT.md):
  Transkription mit Modell und gesprochener Sprache aus den Einstellungen,
  danach wahlweise Übersetzung über `/chat/completions` (Standard
  `gpt-5.4-mini`), beides an OpenAI oder an einen eigenen Server.
- Einstellungen liegen ohne Geheimnis in `%APPDATA%\OpenDictate\settings.json`.
  Eine beschädigte Datei wird abgelehnt und nicht überschrieben. Die
  Server-Adresse ist die Basis-URL mit `/v1`. Ohne Eintrag gilt
  `OPENAI_BASE_URL`, wenn gesetzt (das Prüffenster nennt dann das Ziel), sonst
  OpenAI; ein gespeicherter Eintrag gewinnt. `http://` geht nur für
  diesen Computer, und dorthin geht kein Schlüssel. Ein eigener Server nimmt
  freie Modellnamen, OpenAI nur die bekannten.
- Meldungen erscheinen auf Deutsch oder Englisch nach der Anzeigesprache von
  Windows und enthalten nie die Antwort des Servers; eine Netzwerkmeldung zum
  eigenen Server nennt nur dessen Host.
- Im Prüffenster stehen die Felder im Bereich „Sprache, Übersetzung und
  eigener Server“. Die Provider-Prüfungen laufen jetzt mit
  `OpenDictate.Checks` (auch auf Linux und im Windows-Job der CI);
  `OpenDictate.WindowsChecks` enthält nur noch die 13 Schutzprüfungen.
- Geprüft am 11. Oktober nur offline auf Linux mit .NET SDK 10.0.401:
  40 von 40 Prüfungen, App, Browser-Host und Schutzprüfer bauen ohne Warnung.
  Kein echtes Diktat, keine Anfrage an OpenAI oder an ein lokales Modell.

## Beta-App (11. Oktober 2026)

`OpenDictate.App` (Programmname `OpenDictate.exe`) ist die App für die
Windows-Beta; das Prüffenster `OpenDictate.Prototype` bleibt Entwicklerwerkzeug.

- Die App lebt im Infobereich der Taskleiste: Diktat starten oder beenden (dann
  nur Zwischenablage), Letzten Text kopieren, Letzte Aufnahme nochmal senden
  (mit Rückfrage, weil es bei OpenAI erneut kostet; danach nur Zwischenablage),
  Einstellungen, Beenden. Ein zweiter Start öffnet die Einstellungen.
- Kürzel: **Strg+Win halten** (Standard) oder **rechte Strg** halten oder
  antippen (für Spiele, deren Tastaturen die Win-Taste sperren). Nach 0,3
  Sekunden Halten beginnt die Aufnahme, Loslassen beendet sie. Kommt eine andere
  Taste dazu, zählt das Kürzel nicht (Strg+Win+D oder rechte Strg+C bleiben
  frei); kommt sie während einer Aufnahme dazu, wird abgebrochen und die
  Aufnahme gesichert. Ein systemweiter Tastatur-Hook beobachtet nur und gibt
  jede Taste unverändert weiter. Damit beim Loslassen von Strg+Win kein
  Startmenü aufgeht, sendet die App einmal die unbelegte Taste `0xE8`.
- Einfügen: Der Text kommt in die Zwischenablage, markiert als nicht für den
  Zwischenablage-Verlauf und die Cloud-Zwischenablage bestimmt. Steuerzeichen
  aus der Antwort des Dienstes werden vorher entfernt. Strg+V folgt nur in das
  Fenster, das beim Start vorne war, wenn es noch vorne ist, alle
  Zusatztasten losgelassen sind und die Zwischenablage noch den Text hält;
  sonst bleibt der Text in der Zwischenablage („Kopiert“). Text mit
  Zeilenumbruch wird nicht in Konsolen (Windows Terminal, cmd, PowerShell und
  andere) eingefügt, weil ein Zeilenumbruch die diktierte Zeile als Befehl
  ausführen würde; er bleibt in der Zwischenablage. Abschaltbar mit
  „Automatisch einfügen“.
- Die kleine Anzeige oben auf dem Bildschirm zeigt Hört zu (mit Zeit und
  Pegel), Schreibt, Eingefügt, Kopiert oder Hoppla mit dem Grund und, wenn die
  Aufnahme gesichert ist, „Nochmal senden“. Sie nimmt nie den Fokus. Farben,
  Abstände und Schriften (Geist, mitgeliefert unter der SIL Open Font License)
  kommen aus dem Designsystem (`OpenDictate.Core/DesignTokens.cs`, erzeugt von
  `scripts/design-tokens.py`); das Symbol baut `scripts/make-icon.py` aus Blink.
- Beim ersten Start öffnen sich die Einstellungen mit einer Begrüßung und dem
  Kürzeltest: Solange das Fenster vorne ist, meldet es „Erkannt“, statt
  aufzunehmen. Jede Wahl wird sofort gespeichert; scheitert das Speichern,
  bleiben Kürzel und gespeicherte Wahl beim alten Wert. „Mit Windows starten“
  setzt einen Eintrag unter dem Run-Schlüssel des Benutzers.
- Aufnahmen entstehen unter `%LOCALAPPDATA%\OpenDictate\Recordings` und werden
  vor dem Senden als geschützte Kopie unter `%LOCALAPPDATA%\OpenDictate\Recovery`
  gesichert (höchstens fünf, 24 Stunden); erst danach verschwindet das
  Original. Kürzer als eine halbe Sekunde wird nicht von selbst gesendet und
  lässt sich nicht nochmal senden, bleibt aber gesichert.
- Geprüft am 11. Oktober nur offline auf Linux mit .NET SDK 10.0.401: 60 von
  60 Prüfungen (darunter 20 für Kürzel, Auslöser, Einfügeregel, Einstellungen
  und Anzeige), Beta-App, Prüffenster, Browser-Host und Schutzprüfer bauen ohne
  Warnung. Nicht gestartet: Hook, Mikrofon, Anzeige, Strg+V und Autostart sind
  erst mit einem Windows-PC prüfbar (Windows-Plan, Schritt 7).

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

1. zeigt die SDK-Version an und führt `OpenDictate.Checks` aus (14 Kern-/Bridge-,
   neun Ablauf-, 17 Provider- und 20 Kürzel-/App-Checks),
2. baut `OpenDictate.App` und `OpenDictate.Prototype`,
3. baut `OpenDictate.BrowserHost`,
4. baut `OpenDictate.WindowsChecks`.

Es **führt `OpenDictate.WindowsChecks` nicht aus**. Ein erfolgreicher Skript-
lauf würde daher die 13 Credential-Manager-/Recovery-Prüfungen nicht belegen.
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
