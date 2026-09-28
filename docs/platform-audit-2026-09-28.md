# Geräteprüfung Linux und Windows · 28. September 2026

Basti hat im laufenden Bereinigungsauftrag ausdrücklich die Verbindung zu
beiden eingeschalteten Rechnern und eine lokale Prüfung beauftragt. Beide
SSH-Anmeldungen wurden direkt bestätigt. Vorhandene Hostschlüssel wurden
verwendet; keine Zugangsdaten oder Dienstkonfiguration geändert.

## Linux

- Rechner `omarchy`: Linux 7.2.5-3-omarchy, Rust/Cargo 1.98.1.
- Vorhandener Checkout `/home/basti/Desktop/projekte-grok/OpenDictate`:
  sauber auf `68ef919b550eedb982e71405bb4d4d6bb9c27e93`. Der dortige lokale
  `origin/main` ist kein Nachweis des heutigen GitHub-Stands.
- Gegenüber der aktuellen Audit-Basis `5b95535` unterscheidet sich der Rust-Code
  nur durch zwei bereits früher entfernte Tests (zwölf Zeilen). Diese alte
  Testbereinigung zählt nicht zur jetzigen Code-Reduktion.
- Die exakte `linux/`-Quelle aus `5b95535` wurde in einer eigenen temporären
  Prüfkopie auf dem Linux-Rechner geprüft. `cargo fmt --check`, alle **23 Tests**,
  Clippy für alle Targets mit `-D warnings` und der Release-Build bestanden.
  Test, Clippy und Build liefen mit `--offline --locked` und vorhandenen
  Abhängigkeiten. Kein Paket oder Werkzeug wurde installiert.
- Der bestehende Checkout blieb unverändert. Die eigene Prüfkopie wurde danach
  entfernt und der saubere Checkout erneut geprüft.

Eine Rust-Coverage-Werkzeugkette ist dort nicht installiert. Die Prüfungen liefern
keine Prozentmessung und keine Mikrofon-/Provider-/Clipboard-/Hotkey-Abnahme.
Linux Phase 1 bleibt daher trotz bestandener Offline-Prüfungen offen.

## Windows

- Anmeldung auf `xmg` bestätigt; .NET SDK 10.0.401 vorhanden.
- Der Quellbaum unter
  `%LOCALAPPDATA%\OpenDictateBuild\Prototype-80cbffd838c4` bezeichnet das
  Quellarchiv `80cbffd838c45b5198406283d242f810ddae2df1e1d5785de01fada2629b78b4`.
  **37 Quell-/Projekt-/Skriptdateien** wurden per SHA-256 mit der separaten
  Mac-Arbeitskopie verglichen: keine Abweichung. Generierte `bin/obj`-Dateien
  waren ausgeschlossen. Der Archivmarker allein war nicht der Vergleich.
- Der C#-Bestand umfasst 23 Dateien und 2.311 Zeilen einschließlich Prüfcode.
  Er bleibt außerhalb der vorher festgelegten Mac-/Rust-Reduktionsbasis und ist
  im separaten Mac-Elternrepository weiterhin unversioniert.
- In einer eigenen temporären Kopie auf Windows bestanden **14 Kern-/Bridge-
  und neun Ablaufprüfungen**. App und Browser-Host ließen sich mit
  `dotnet build --no-restore -c Release` ohne Warnung oder Fehler bauen.
  Keine App wurde gestartet oder installiert. Die Prüfkopie wurde entfernt.
- Die weiteren Windows-Schutzprüfungen wurden nicht gestartet: Ihr bestehender
  Ablauf erzeugt einen Testeintrag in der Windows-Anmeldeinformationsverwaltung
  und verlangt den angemeldeten Desktop. Dafür wurde in diesem Auftrag keine
  separate Zugangsdatenschreibfreigabe erteilt. Die alten 41 Prüfergebnisse
  bleiben historische Nachweise; heute sind nur die genannten 23 erneuert.

Die README im Windows-Archiv ist nachweislich veraltet: Frühe Abschnitte nennen
keine Anbieteranbindung und eine noch ausstehende Integration, während der
Quellbaum bereits `IntegrationControls`, `OpenAiTranscriber`, `ProtectedJournal`
und `RecoveryStore` enthält und der spätere externe Bericht die Integration
beschreibt. Vor weiterer Windows-Umsetzung einen versionierten Ausgangsstand
herstellen und diese konkurrierenden Statusabschnitte bereinigen. Die
[zentrale Windows-Zusammenfassung](windows-plan.md) trennt aktuellen Codebestand,
heutige Offline-Prüfung und historische sichtbare Abnahme.

## Nachweise und Grenze

Lokale Nachweise liegen unter
`/Users/basti/.codex/artifacts/opendictate/code-reduction-20260928/`:
`linux-checks.log`, `linux-replay-command.txt`, `linux-cleanup.log`,
`windows-checks.log`, `windows-source-inventory.json`, `windows-cleanup.log`
und das Hilfsskript `remote_windows.py`.

Dies ist eine Geräte-/Quellstand-/Offline-Prüfung. Es gab keine Aufnahme,
Provideranfrage, Secret-Lektüre, Schlüsseländerung, GUI-Abnahme oder
Veröffentlichung. Nutzeraufnahmen, Recovery-Daten, vorhandene Prototyparchive,
Browserprofile und installierte Apps blieben erhalten. Die laufenden Aufgaben
stehen ausschließlich in [ROADMAP.md](../ROADMAP.md).
