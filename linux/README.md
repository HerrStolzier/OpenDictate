# Linux-Spike (Phase 0)

Fortsetzung für Agents: [docs/remaining-acceptance.md](../docs/remaining-acceptance.md)
(einzige aktuelle Übergabe), Plan: [docs/linux-build-plan.md](../docs/linux-build-plan.md).

Kein Produktumfang. Kleines Rust-CLI für diese omarchy/Hyprland-Session:
Toggle ohne Fenster, Mikrofon in eine lokale WAV, Secret Service, Wayland-Zwischenablage.

Die macOS-App und die Swift-CI bleiben unberührt. Upload, Auto-Insert und
`PROJECT.md`-Umfang gehören nicht zu diesem Spike.

## Bauen

Rust 1.70+ (getestet: rustc 1.98). In diesem Verzeichnis:

```bash
cargo test --manifest-path linux/Cargo.toml
cargo build --release --manifest-path linux/Cargo.toml
```

Das Binary liegt in `linux/target/release/opendictate`. `linux/target/` gehört
nicht ins Git.

## Benutzung

```bash
opendictate toggle              # Aufnahme starten oder stoppen
opendictate status              # idle / recording
opendictate copy-status         # fester Statustext in die Zwischenablage
opendictate secrets probe       # Secret Service schreiben, lesen, löschen
opendictate secrets status      # ob API-Key und Recording-Auth existieren
opendictate secrets init-auth   # Recording-Auth anlegen, falls fehlend
```

API-Schlüssel nur über stdin, nie als Argument oder Umgebungsvariable:

```bash
opendictate secrets set-api-key < keyfile     # nicht im Spike nötig
```

Aufnahmen liegen in `$XDG_STATE_HOME/opendictate/spike/` (sonst
`~/.local/state/opendictate/spike/`), nur für den aktuellen Benutzer.
Der Spike lädt nichts hoch. Nach dem Stopp steht ein Statustext in der
Zwischenablage, kein Transkript.

## Hyprland

Beispielbindung: [hyprland.conf.example](hyprland.conf.example). Die Datei nicht
blind in die Session übernehmen; den Key selbst wählen und das Binary auf
`PATH` legen oder den vollen Pfad eintragen.

## Grenzen

- Kein Tray, kein Settings-Fenster, kein OpenAI-Upload.
- Globaler Hotkey ist die Compositor-Bindung, kein In-App-Grab.
- Keyring-Backend auf dieser Session: gnome-keyring über `secret-tool`.
  Fehlt Secret Service, bricht der Befehl ab (kein Datei- oder Env-Fallback).
