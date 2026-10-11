# Windows-Quellsnapshot: Herkunft und Integrität

## Herkunft

Dieser Quellsnapshot wurde am **28. September 2026** aus dem zuvor
unversionierten Verzeichnis `windows/` des getrennten OpenDictate-Prototyps
übernommen. Der neue Repository-Zweig basiert auf `main` unter
`1f895537e9b36d962eb1425113423da377e95b1b`. Die ursprüngliche Arbeitskopie
wurde nur lesend geprüft und nicht verändert.

Das Windows-Archiv `80cbffd838c45b5198406283d242f810ddae2df1e1d5785de01fada2629b78b4`
war die unabhängige Vergleichsbasis. Alle **37** dort inventarisierten
Quell-, Projekt- und Skriptdateien stimmten SHA-256-genau mit der lokalen
Windows-Arbeitskopie überein. Die gleiche Dateiliste wurde unverändert in
diesen Snapshot kopiert. Der Plattformbericht hält die getrennte
Windows-Prüfung und deren Grenzen fest:
[Geräte- und Quellstandbericht](../docs/platform-audit-2026-09-28.md).

## Ergänzende Dateien

Fünf vorhandene Dateien waren nicht Teil des 37-Dateien-Abgleichs. Sie wurden
vor der Aufnahme getrennt auf Textinhalt, Geheimnisse und Buildartefakte
geprüft. Die vier unverändert übernommenen Dateien hatten in der lokalen
Arbeitskopie diese Prüfsummen:

| Datei | SHA-256 der lokalen Ergänzung | Verwendung |
| --- | --- | --- |
| `.gitignore` | `fc8e8958377f6026fbdbe82b144fcdc6ec12c6765bb0fcf5fe1b930cc62ea422` | Hält `bin/`, `obj/`, `artifacts/` und lokale Aufnahmen aus Git. |
| `OpenDictate.Prototype/app.manifest` | `4f7615cc560d67ac2528bcfeceebb8c3f0f7eb692149264007fed4b320fd2396` | Vom WPF-Projekt eingebundenes App-Manifest; fordert `asInvoker`. |
| `browser-prototype/extension-id.txt` | `1c292ec46ed3c750297ba645f058187ea15fbbbcaf1fd3a2735a668a8324e33d` | Öffentliche Identität der lokalen Testextension; stimmt mit ihrem Manifest-Schlüssel überein. |
| `browser-prototype/fixture.html` | `53d10bf2dddf46112fc755d740960f1e451f0bc1997717c98df217aee02e8041` | Lokale Testfelder mit künstlichem Text. |

Die ursprüngliche `README.md` hatte vor der Neufassung SHA-256
`09142b3351a27f0e9f71f7f0b70075fd556bca0c758612d41f33622f5a6cd0f2`.
Sie wurde durch eine aktuelle Statusbeschreibung ersetzt; ihr neuer Snapshot-
Hash steht in [SOURCE-SHA256SUMS](SOURCE-SHA256SUMS). Die vier oben genannten
Zusatzdateien sind lokal geprüft, aber nicht als Teil des Windows-PC-Abgleichs
ausgewiesen.

## Prüfumfang und Ausschlüsse

`SOURCE-SHA256SUMS` bindet alle 42 aufgenommenen Projektdateien einschließlich
der neuen README an diesen Snapshot. Darin sind auch die 37 Dateien enthalten,
deren Hashes zusätzlich gegen das Windows-Archiv verglichen wurden. Die
Prüfsummendatei selbst sowie diese Provenienz- und Releaseplan-Dokumente sind
nicht selbst gelistet.

Eine dateiweise Inhaltsprüfung fand keine API-Schlüssel, Zugangstoken,
Passwörter, privaten Schlüssel, E-Mail-Adressen oder absoluten Benutzerpfade.
Alle 42 aufgenommenen Projektdateien sind Textdateien. Es wurden keine
`bin/`-/`obj/`-Ausgaben, Buildartefakte, Audio, Nutzeraufnahmen, Browserprofile,
Protokolle oder historischen Bildschirmnachweise übernommen. Der Browser-
Installationshelfer wurde nicht ausgeführt. Der Schlüssel im Extension-Manifest
ist der öffentliche Identitätsschlüssel der lokalen Testextension; ein privater
Signierschlüssel oder ein Browserprofil wurde nicht übernommen.

## Entwicklung nach dem Snapshot

`SOURCE-SHA256SUMS` bleibt das historische Importmanifest des unveränderten
Windows-Snapshots aus dem retained Merge-Commit `9bf554ea7d2c48b87022469ddb4d6a36a5cf7cd0`.
Spätere, normal versionierte Änderungen unter `windows/` ändern die aktuellen
Dateien, ohne dieses Herkunftsmanifest umzuschreiben. Für den ursprünglichen
Windows-PC-Abgleich ist deshalb dieser Snapshot-Commit maßgeblich, nicht der
jeweilige Stand von `main`.

## Ergänzender Abgleich durch die Hauptaufgabe

Nach der Snapshot-Erstellung wurden auch die vier unveränderten Ergänzungen
oben per `Get-FileHash -Algorithm SHA256` direkt auf dem Windows-PC geprüft:
4/4 stimmen überein. Damit sind insgesamt 41 unverändert übernommene
Originaldateien gegen denselben Windows-Quellbaum abgeglichen. Die README
wurde separat neu geschrieben. Der lokale Zusatzbeleg liegt unter
`~/.codex/artifacts/opendictate/platform-resume-20260928/windows-supplemental-hashes.json`.
