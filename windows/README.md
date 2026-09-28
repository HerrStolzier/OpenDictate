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

1. zeigt die SDK-Version an und führt `OpenDictate.Checks` aus (14 Kern-/Bridge-
   plus neun Ablaufchecks),
2. baut `OpenDictate.Prototype`,
3. baut `OpenDictate.BrowserHost`,
4. baut `OpenDictate.WindowsChecks`.

Es **führt `OpenDictate.WindowsChecks` nicht aus**. Ein erfolgreicher Skript-
lauf würde daher die 18 Credential-Manager-/Recovery-Prüfungen nicht belegen.
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
