# Linux Clipboard-MVP (Phase-1-Kern)

Aktuelle Übergabe: [docs/remaining-acceptance.md](../docs/remaining-acceptance.md),
Plan: [docs/linux-build-plan.md](../docs/linux-build-plan.md), technischer
Nachweis: [docs/linux-phase1-core-2026-09-22.md](../docs/linux-phase1-core-2026-09-22.md).

Noch kein Produktumfang und keine öffentliche Veröffentlichung. Das Rust-CLI
für die omarchy/Hyprland-Session bildet den Phase-1-Kern ab: Aufnahme ohne
Fenster, Audio-Prüfung, OpenAI-Upload mit eigenem Key, Wayland-Zwischenablage,
Zustandsmaschine und authentifizierte Recovery. Dazu kommen eine
Waybar-Anzeige mit Übersetzungsumschalter und Auto-Einfügen ins Startfenster
(Phase 2, noch ohne Live-Nachweis).

## Bauen und prüfen

Geprüft mit `rustc 1.98.1`. Eine niedrigere Mindestversion ist nicht
verifiziert:

```bash
cargo fmt --manifest-path linux/Cargo.toml -- --check
cargo test --manifest-path linux/Cargo.toml
cargo clippy --manifest-path linux/Cargo.toml --all-targets -- -D warnings
cargo build --release --manifest-path linux/Cargo.toml
```

Das Binary liegt in `linux/target/release/opendictate`. `linux/target/` gehört
nicht ins Git. Die macOS-App und ihre Swift-CI werden davon nicht verändert.

## Bedienung

```bash
opendictate toggle                  # Aufnahme starten oder stoppen
opendictate status                  # idle / recording / processing / delivering
opendictate waybar                  # Status als JSON-Zeile für Waybar
opendictate cancel                  # Aufnahme/Verarbeitung sicher abbrechen
opendictate retry                   # neueste authentifizierte Aufnahme erneut senden
opendictate settings show
opendictate settings model gpt-transcribe
opendictate settings language de    # `auto` für automatische Erkennung
opendictate settings target en      # Diktat ins Englische übersetzen; `off` aus
opendictate settings target toggle  # aus bzw. mit letzter Zielsprache (sonst en) an
opendictate settings insert off     # nur Zwischenablage, kein Auto-Einfügen
opendictate settings translation-model gpt-5.4-mini
opendictate secrets status
```

Der API-Schlüssel wird ausschließlich über stdin im Secret Service gespeichert,
nie als Argument, Umgebungsvariable oder Datei:

```bash
trusted-secret-command | opendictate secrets set-api-key
```

Das ist eine schreibende Keyring-Aktion. Für Entwicklung und Tests sind keine
echten Secrets nötig; die HTTP-Tests verwenden nur einen lokalen Stub.

## Ablauf und Schutzregeln

- `toggle` startet eine fokusneutrale Aufnahme. Der zweite Aufruf beendet sie
  und wechselt auf `processing`; weitere Starts während `processing` oder
  `delivering` werden abgelehnt.
- Unter 1 Sekunde oder ohne 50-ms-Fenster oberhalb −45 dBFS erfolgt kein Upload.
  Erkannte Sprache erhält 0,25 Sekunden Rand; nur Einsparungen ab 0,35 Sekunden
  erzeugen eine zugeschnittene Upload-WAV. Das 90-Sekunden-Limit bleibt aktiv.
- Mit gesetzter Zielsprache wird das Transkript danach über
  `/v1/chat/completions` übersetzt und nur die Übersetzung ausgegeben. Scheitert
  die Übersetzung oder ist sie leer, bleibt die Aufnahme wie bei jedem anderen
  Fehler erhalten; `retry` übersetzt erneut. Am 05.10. auf omarchy live
  erprobt ([Plan mit Nachweis](../docs/linux-live-translation-plan.md)).
- Ein nichtleeres Transkript wird ausschließlich in die Wayland-Zwischenablage
  geschrieben. Erst nach erfolgreichem Copy darf die zugehörige Aufnahme
  entfernt werden.
- Auto-Einfügen (Standard an, `settings insert off` schaltet es ab): Beim
  Start wird das aktive Hyprland-Fenster erfasst. Nach dem Kopieren prüft das
  CLI, dass genau dieses Fenster noch vorne ist und die Zwischenablage noch den
  Text enthält, und sendet dann per `hyprctl dispatch sendshortcut` Ctrl+V,
  in bekannten Terminals Ctrl+Shift+V, an dieses Fenster. Sonst bleibt es bei
  der Zwischenablage mit Hinweis. Das Einfügen selbst ist unbestätigt; die
  Aufnahme gilt mit dem erfolgreichen Kopieren als geliefert. `retry` fügt nie
  automatisch ein.
- Fehler, Abbruch, leere Antwort oder Clipboard-Fehler behalten Audio. Eine
  Recovery-Kopie wird mit einem Secret-Service-Schlüssel per HMAC-SHA256 an
  Dateiname, Erstellzeit und exakte Bytes gebunden. Scheitert die Kopie, bleibt
  das Original erhalten.
- `retry` lädt nur frisch authentifizierte Bytes und entfernt sie erst nach
  erfolgreichem Clipboard-Copy. Unbekannte, veränderte oder abgelaufene Dateien
  werden nie hochgeladen. Verwaltete Recovery hält höchstens fünf Dateien und
  24 Stunden.
- Logs enthalten Zustände und begrenzte Zeitangaben, aber keinen Key, kein
  Transkript und keine Audioinhalte. Die erfasste Fensterklasse darf enthalten
  sein; Fenstertitel werden nicht gelesen oder geloggt.

Zustand liegt unter `$XDG_STATE_HOME/opendictate/` (sonst
`~/.local/state/opendictate/`), Einstellungen unter
`$XDG_CONFIG_HOME/opendictate/`. Anwendungs-, Pending- und Recovery-Verzeichnisse
sind echte Verzeichnisse mit Modus `0700`; Audiodateien und Nachweise `0600`.

## Hyprland

Die Beispielbindung steht in [hyprland.conf.example](hyprland.conf.example).
Sie wurde nicht in die Nutzerkonfiguration geschrieben. Den Key bewusst wählen
und das Release-Binary über einen absoluten Pfad aufrufen.

## Waybar

[waybar.example.jsonc](waybar.example.jsonc) und
[waybar.example.css](waybar.example.css) zeigen ein Modul, das jede Sekunde
`opendictate waybar` abfragt: Mikrofon-Symbol, rot während der Aufnahme, Sanduhr
während der Verarbeitung und die aktive Zielsprache (z. B. `EN`). Ein Klick ruft
`settings target toggle` auf. Die Ausgabe enthält nur Zustand und Einstellungen,
nie Text. Die Symbole brauchen eine Nerd Font, wie sie Omarchy mitbringt.

## Noch offen

- Kein Live-Upload und kein echter Phase-1-Durchstich auf omarchy in diesem
  Stand; dafür braucht es eine neue begrenzte Mikrofon-/Provider-Freigabe.
- Waybar-Modul und Auto-Einfügen sind offline geprüft, aber noch nicht live
  auf omarchy abgenommen. Kein Settings-Fenster.
- Ein Abbruch während des blockierenden HTTP-Aufrufs wird nach dessen Rückkehr
  beziehungsweise Timeout ausgewertet; er löscht die einzige Aufnahme nicht.
- Kein Packaging und kein zweites Distro-Ziel.
