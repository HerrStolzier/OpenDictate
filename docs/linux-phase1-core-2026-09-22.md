# Linux Phase-1-Kern — 22. September 2026

## Umfang

Kerncommit `e17d37c`, über [PR #17](https://github.com/HerrStolzier/OpenDictate/pull/17)
als `83c944f` in `main`, Basis `0ae6a49`. Kein Produktumfang, keine
Hyprland-Konfigurationsänderung, kein API-Key-Zugriff, kein Mikrofontest und kein
OpenAI-Request. Die installierte macOS-App blieb unverändert.

Implementiert ist der testbare Kern des Clipboard-MVP:

- Zustände `idle`, `recording`, `processing`, `delivering`; kein neuer Start
  während Verarbeitung oder Übergabe; sicherer Abbruchmarker.
- WAV-Prüfung mit 1 Sekunde Minimum, 90 Sekunden Maximum, −45 dBFS in
  50-ms-Fenstern, 0,25 Sekunden Padding und Trim erst ab 0,35 Sekunden Ersparnis.
- HTTPS-Multipart-Upload an `/v1/audio/transcriptions`; API-Key ausschließlich
  aus Secret Service, Modell-/Sprachwahl in einer owner-only Settings-Datei.
- Wayland-Clipboard als einzige Delivery. Löschen nur nach nichtleerem Text und
  erfolgreichem Clipboard-Copy.
- HMAC-SHA256-Recovery bindet Dateiname, Zeit, Größe und exakte Audio-Bytes.
  Retry lädt nur frisch authentifizierte Bytes; fünf Dateien/24 Stunden.
- Echte Anwendungsverzeichnisse `0700`, Audio/Nachweise `0600`; Symlink für das
  Anwendungsverzeichnis wird abgelehnt. Logs enthalten keine Keys, Transkripte,
  Fenstertitel oder Audioinhalte.

## Prüfung auf omarchy

Rust 1.98.1, aktuelles Omarchy/Hyprland-Zielsystem:

- `cargo fmt --manifest-path linux/Cargo.toml -- --check`
- `cargo test --manifest-path linux/Cargo.toml`: 25 bestanden
- `cargo clippy --manifest-path linux/Cargo.toml --all-targets -- -D warnings`
- `cargo build --release --manifest-path linux/Cargo.toml`

Die HTTP-Tests verwenden ausschließlich einen gebundenen Loopback-Stub. Sie
prüfen Multipart-Felder, Antwortdekodierung und begrenzte Fehlermeldungen. Die
Recovery-Tests prüfen exakte Bytes, Dateiname, falschen Key, Manipulation,
Kopierfehler sowie Count-/Altersgrenze. Das ist keine Live-Provider-, Mikrofon-,
Keyring- oder Clipboard-Abnahme.

## Offene Phase-1-Abnahme

- Live-Durchstich auf omarchy mit neu begrenzter Aufnahme-/Upload-Freigabe.
- Reale Fehler-/Abbruch-/leere Antwort-/Clipboard-Fehlerfälle und Nachweis, dass
  jeweils die einzige Aufnahme erhalten bleibt.
- Physischer Hyprland-Hotkey dieses Kandidaten.
- Tray und kleines Panel auf Zuruf; kein ungefragtes Fenster während Aufnahme.
- Abbruch während eines blockierenden HTTP-Aufrufs wird derzeit erst nach
  Rückkehr oder Timeout ausgewertet. Die Aufnahme bleibt dabei erhalten, aber
  ein sofortiger Transportabbruch ist noch nicht implementiert.
