# Linux-Pakete lokal bauen und prüfen

Das Maintainer-Skript erzeugt Quell- und Binärarchive aus einem sauberen,
festgehaltenen Commit. Es veröffentlicht nichts und legt keinen Git-Tag an.
Rust/Cargo 1.98.1 und die ALSA-Entwicklungsdateien müssen vorhanden sein.

```bash
bash scripts/ci/check-linux.sh
bash scripts/package-linux.sh --tag linux-v0.1.0-beta.2 --output /tmp/od-package-one
bash scripts/package-linux.sh --tag linux-v0.1.0-beta.2 --output /tmp/od-package-two
cmp /tmp/od-package-one/SHA256SUMS /tmp/od-package-two/SHA256SUMS
bash scripts/package-linux.sh --verify /tmp/od-package-one/opendictate-linux-v0.1.0-beta.2-x86_64-unknown-linux-gnu.tar.gz
```

Die Ausgabeordner müssen neu und außerhalb des Checkouts sein. Der Tagname
wird nur mit Cargo-/Arch-Paketversion verglichen; ein existierender Release
wird dadurch weder verändert noch vorausgesetzt. Der Prüfbefehl entpackt
vorübergehend, prüft Manifest und Prüfsummen und startet ausschließlich
`--version` und `--help`. Er installiert die App nicht.

## Echter Nachweis vom 17. Oktober 2026

Geprüfter Commit: `10ba599cc1c325ebeb8449b6402b39671afc7471`.
Rechner: omarchy, Linux `7.2.5-3-omarchy`, x86_64, GNU/Linux.
Werkzeuge: `rustc 1.98.1 (48a229cea 2026-09-01)`, Cargo 1.98.1,
LLVM 22.1.8, ALSA 1.2.16.1. Es wurden vorhandene Werkzeuge genutzt.

- `scripts/ci/check-linux.sh`: 135 Tests bestanden, Clippy und Release-Build
  bestanden.
- Zwei getrennte Aufrufe des Paketskripts: jeweils eigener temporärer
  Quell-Snapshot und eigener Cargo-Zielordner. Beide integrierten nativen
  Archivprüfungen bestanden.
- `cmp` der beiden `SHA256SUMS`: identisch. Damit stimmen beide Archive
  vollständig überein, einschließlich des enthaltenen Programms.
- Separater CLI-Aufruf mit `--verify`: bestanden.

| Datei | SHA-256 in beiden Läufen |
| --- | --- |
| Binärarchiv `opendictate-linux-v0.1.0-beta.2-x86_64-unknown-linux-gnu.tar.gz` | `95ec193f675163816e197255fe6223fe2660ec6b95378148ad1e182ce2f98a54` |
| Quellarchiv `opendictate-linux-v0.1.0-beta.2-source.tar.gz` | `6130bd8f3651b86ab04dea7bbfdddec0531d327b9f870816d8c2c38e32501634` |
| Enthaltenes Programm `bin/opendictate` | `a5e771c5b124024d2f7175ad0ab0081c30bb6f6e209e57a7e15a60120160124a` |

Das Manifest bindet Commit, Version, Ziel `x86_64-unknown-linux-gnu`,
Rust-Version, `SOURCE_DATE_EPOCH=1792189876` und jede enthaltene Datei.
Dieser Nachweis gilt für genau diesen Commit und diese Werkzeugumgebung.
Er belegt keine Reproduzierbarkeit zwischen verschiedenen Rust-Versionen,
Architekturen oder Distributionen. Kein Mikrofon, Provider, Schlüsselbund,
Installation oder echter Diktatablauf wurde damit geprüft. Es wurde kein
Tag oder Release veröffentlicht.
