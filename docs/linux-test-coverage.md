# Linux-Ablaufprüfungen und Abdeckung

Gemessen am 17. Oktober 2026 lokal auf omarchy mit vorhandenem Rust/Cargo
1.98.1 und LLVM 22.1.8. Es wurde kein Werkzeug installiert und keine CI-Datei
geändert. Ausgangsstand: `8dbf0f85a2d37558917cd5cc8792111ea9f27130`.
Die Baseline wurde im Paket-Checkout `10ba599` gemessen, dessen `linux/src/`
gegen diesen Ausgangsstand identisch ist. Endstand:
`6b4620dbc40b9f22468ca677494f30d1edae5e40`. Die SHA-256-Werte aller Rust-Dateien
des gemessenen Checkouts wurden mit diesem Endstand verglichen: identisch.

## Ergebnis und Zählweise

- Vorher: 135 Offline-Tests. Nachher: 141 Offline-Tests. Beide Messläufe bestanden.
- Produktionszeilen: **2044/4213 (48,52 %) → 2644/4221 (62,64 %)**.
- Ungefilterter LLVM-Zeilenbericht einschließlich Testcode:
  **64,32 % → 74,69 %**. Diese höhere Zahl ist keine Produktionsabdeckung.
- Der unveränderte Linux-Prüfeinstieg bestand für den Endstand ebenfalls:
  Formatierung, gesperrte Abhängigkeiten, alle Tests, Clippy mit Warnungen als
  Fehler und Release-Build.

Die folgende Tabelle zählt eindeutige `DA`-Zeilen aus `llvm-cov export
-format=lcov`: Eine Zeile zählt als erreicht, sobald ihr Zähler größer null ist.
Zeilen ab dem abschließenden `#[cfg(test)] mod tests` werden ausgeschlossen.
Die vollständig testseitigen Dateien `cli_flow_tests.rs`, `test_http.rs` und
`test_support.rs` werden nicht zum Produktionsnenner addiert. Kommentare und
nicht instrumentierte Zeilen sind keine ausführbaren Zeilen.

| Produktionsdatei | Vorher | Nachher |
| --- | ---: | ---: |
| `clipboard.rs` | 36/78 (46.15 %) | 55/78 (70.51 %) |
| `i18n.rs` | 13/14 (92.86 %) | 13/14 (92.86 %) |
| `insert.rs` | 45/88 (51.14 %) | 45/88 (51.14 %) |
| `ipc.rs` | 93/114 (81.58 %) | 93/114 (81.58 %) |
| `keyring.rs` | 39/164 (23.78 %) | 110/164 (67.07 %) |
| `main.rs` | 50/937 (5.34 %) | 413/937 (44.08 %) |
| `notify.rs` | 9/17 (52.94 %) | 17/17 (100.00 %) |
| `paths.rs` | 44/101 (43.56 %) | 91/101 (90.10 %) |
| `policy.rs` | 19/19 (100.00 %) | 19/19 (100.00 %) |
| `record.rs` | 175/309 (56.63 %) | 179/309 (57.93 %) |
| `recovery.rs` | 241/290 (83.10 %) | 249/298 (83.56 %) |
| `report.rs` | 110/167 (65.87 %) | 110/167 (65.87 %) |
| `server.rs` | 131/138 (94.93 %) | 134/138 (97.10 %) |
| `settings.rs` | 190/214 (88.79 %) | 193/214 (90.19 %) |
| `setup.rs` | 50/526 (9.51 %) | 50/526 (9.51 %) |
| `shortcut.rs` | 304/373 (81.50 %) | 304/373 (81.50 %) |
| `state.rs` | 60/62 (96.77 %) | 60/62 (96.77 %) |
| `transcribe.rs` | 146/150 (97.33 %) | 146/150 (97.33 %) |
| `translate.rs` | 127/141 (90.07 %) | 127/141 (90.07 %) |
| `usage.rs` | 107/242 (44.21 %) | 181/242 (74.79 %) |
| `waybar.rs` | 47/50 (94.00 %) | 47/50 (94.00 %) |
| `window.rs` | 8/19 (42.11 %) | 8/19 (42.11 %) |
| **Gesamt** | **2044/4213 (48.52 %)** | **2644/4221 (62.64 %)** |

## Geschützte Abläufe und Grenzen

Die neuen Tests rufen den echten Argument-Dispatcher und die bestehenden
Verarbeitungs-/Retry-Funktionen auf. Sie prüfen Einstellungen samt unveränderten
Dateien bei ungültigen Werten; gesicherte Originalbytes nach Providerfehler,
leerem Ergebnis, Abbruch und Zwischenablagefehler; erhaltene Originale bei
fehlendem Sicherungsschlüssel oder fehlgeschlagener Dateisicherung; normale
und ausdrücklich übersprungene Wiederholung; sowie Abbruch in allen fünf
Zuständen über echte lokale Unix-Sockets. Die Fehlertabelle prüft jeweils den
Fehlergrund, damit ein früher Decoderfehler keinen Zwischenablagefehler verdeckt.

Die Ablaufzeit wird für beide Wiederholungsarten mit einer festen Uhr geprüft:
eine Sekunde vor 24 Stunden zugelassen, bei genau 24 Stunden abgewiesen.
Manipulation gleicher Dateilänge muss an der Inhaltsauthentifizierung scheitern.
Die Grenze von fünf betrifft gesicherte Kopien; sieben fehlgeschlagene
Sicherungsversuche dürfen ihre Originale nicht verlieren. Bereits vorhandene
Prüfungen sichern die fünf neuesten Kopien und die Bereinigung alter Originale.

Es gibt keinen neuen Produktionsadapter nur für Tests. Die vorhandenen
Funktionseinstiege reichen aus. Die einzige Produktionsumstrukturierung ist
die private Auswahlfunktion mit injizierbarer Uhr; der normale Aufruf fragt
weiterhin erst nach dem Lesen und Authentifizieren die Systemzeit ab.
Nutzertexte, Dateiformate und Aufbewahrungsregeln bleiben gleich. Der restliche
Diff liegt hinter `cfg(test)`: eine eigene Testdatei, bounded HTTP-Attrappen und
die bestehende Umgebungssperre für zwei parallel laufende Clipboard-Tests.

Alle Dateipfade liegen in eigenen temporären XDG-Verzeichnissen. `PATH` enthält
nur selbst erzeugte Befehlsattrappen; Rücksetzen erfolgt unter der gemeinsamen
Testsperre auch beim Verlassen der Fixture. Der Schlüsselbund, Wayland-
Zwischenablage und Benachrichtigungen sind Attrappen. Daher belegen etwa die
höheren Werte in `keyring.rs` und `notify.rs` keinen echten Zugriff auf Secret
Service oder sichtbare Benachrichtigungen. Kein Mikrofon und kein externer
Provider werden verwendet. Das ist eine Integrationsprüfung mit Fixtures,
keine reale Diktat- oder Desktop-E2E-Abnahme.

## Messung wiederholen

Auf dem jeweiligen sauberen Stand mit bereits vorhandenen Werkzeugen:

```bash
bash scripts/ci/check-linux.sh
COVERAGE_DIR="$(mktemp -d /tmp/od-coverage.XXXXXX)"
RUSTUP_AUTO_INSTALL=0 CARGO_INCREMENTAL=0 \
  CARGO_TARGET_DIR="$COVERAGE_DIR/target" RUSTFLAGS='-C instrument-coverage' \
  LLVM_PROFILE_FILE=/dev/null \
  cargo test --locked --manifest-path linux/Cargo.toml --no-run --message-format=json \
  > "$COVERAGE_DIR/artifacts.jsonl"
COVERAGE_BINARY="$(python3 - "$COVERAGE_DIR/artifacts.jsonl" <<'PY'
import json, sys
for line in open(sys.argv[1]):
    artifact = json.loads(line)
    if (artifact.get('reason') == 'compiler-artifact'
            and artifact.get('profile', {}).get('test') and artifact.get('executable')):
        print(artifact['executable'])
        break
PY
)"
LLVM_PROFILE_FILE="$COVERAGE_DIR/profile-%p-%m.profraw" "$COVERAGE_BINARY"
llvm-profdata merge -sparse "$COVERAGE_DIR"/*.profraw -o "$COVERAGE_DIR/coverage.profdata"
llvm-cov report "$COVERAGE_BINARY" -instr-profile="$COVERAGE_DIR/coverage.profdata" linux/src/*.rs
llvm-cov export "$COVERAGE_BINARY" -instr-profile="$COVERAGE_DIR/coverage.profdata" \
  -format=lcov linux/src/*.rs > "$COVERAGE_DIR/coverage.lcov"
```

Für die Produktionsspalte wird der LCOV-Bericht wie oben beschrieben gefiltert.
Die Profil- und Ausgabeordner liegen außerhalb des Checkouts und werden nach
der Auswertung entfernt. LLVM und der LLVM-Anteil des Rust-Compilers müssen
zueinander passen; diese Messung nutzte auf beiden Seiten 22.1.8. Es gibt keine
Coverage-Schwelle und keine Instrumentierung im normalen Build oder in CI.
