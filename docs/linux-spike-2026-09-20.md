# Linux Phase-0 Spike — 20. September 2026

Session: omarchy, Hyprland 0.56.2, Wayland (`wayland-1`), PipeWire 1.6.8
(Pulse-Kompatibilität), gnome-keyring (`org.freedesktop.secrets`), Default-Source
`alsa_input.usb-Harman_International_Inc_JBL_Quantum_Stream_Talk-00.mono-fallback`.
Code: `linux/` CLI `opendictate`. Kein Upload, kein `PROJECT.md`-Umfang.

## Gewählter Weg

| Schicht | Belegt |
|---|---|
| Toggle | `opendictate toggle` startet einen Hintergrundprozess, stoppt über Unix-Socket in `$XDG_RUNTIME_DIR/opendictate/` |
| Aufnahme | cpal Default-Input → mono-16-bit-WAV, ohne Fenster, Cap 90 s |
| Fokus | `hyprctl activewindow` vor, während und nach Toggle: Adresse unverändert (`class=foot`) |
| Keyring | `secret-tool` gegen gnome-keyring: Probe schreiben, lesen, löschen |
| Clipboard | `wl-copy` / `wl-paste`, Typ `text/plain` |
| Hotkey | Beispielbindung in `linux/hyprland.conf.example`; **nicht** in die Session installiert |

## Befehle auf dieser Session

- `opendictate secrets probe` → `Keyring erreichbar`
- `opendictate secrets status` → `api-key=missing recording-auth=missing` (kein Fake-Key)
- `opendictate copy-status` → Zwischenablage `OpenDictate: Zwischenablage ok.`
- `opendictate toggle` (~1,3 s) → `recording`, WAV 116 648 Bytes, danach `idle`
- Stopp-Zwischenablage: `OpenDictate: Aufnahme gespeichert (… s).`
- Testaufnahme anschließend gelöscht; sie war kein Recovery-Stand

Offline: `cargo test --manifest-path linux/Cargo.toml` (9 Tests) und
`cargo build --release --manifest-path linux/Cargo.toml` auf rustc 1.98.1.

## Was nicht ging / Fallbacks

- `secret-tool --help` endet mit Status 2; Verfügbarkeit wird über `PATH` geprüft,
  nicht über den Help-Exitcode.
- Die Hyprland-Bindung wurde nicht in `~/.config/hypr/` geschrieben. Der Spike
  belegt Toggle ohne Fokusverlust über die CLI; der Compositor-Hotkey bleibt
  eine manuelle Bindung durch den User.
- Kein Tauri, kein X11-Umweg. Clipboard und Keyring brauchten keinen Fallback.
- Recording-Auth und API-Key wurden nicht angelegt (Phase 1).

## Grenzen

Ein CLI-Toggle ist kein physischer Hotkey-Nachweis. Die WAV-Größe belegt Capture,
nicht Sprachqualität. macOS-CI prüft dieses Crate nicht. Linux bleibt außerhalb
von [PROJECT.md](../PROJECT.md).
