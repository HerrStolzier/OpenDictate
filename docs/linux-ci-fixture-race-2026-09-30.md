# Linux-CI: getrennte HTTP-Testdateien

## Fehler und geschützter Vertrag

Die [Linux-Pflichtprüfung](https://github.com/HerrStolzier/OpenDictate/actions/runs/36719903424)
für `f38f521b4f7d70dc837f65d5ebae941abf9e2d61` scheiterte mit
22 bestandenen Tests und `Aufnahme nicht lesbar.` im Test
`stub_receives_multipart_and_returns_trimmed_text`.
Beide Transkriptions-Tests verwendeten denselben Dateinamen aus der Prozess-ID.
Der Fehlertest konnte diese Datei vor dem Lesen durch den Erfolgstest löschen.

Die vorhandenen Tests schützen den Multipart-HTTP-Aufruf und das Kürzen der
Antwort beziehungsweise die verständliche Fehlermeldung ohne Provider-Inhalt.
Ihre Daten müssen bei paralleler Ausführung unabhängig bleiben. Die Korrektur
ergänzt den Testfall im Dateinamen; Assertions und Produktionscode bleiben
unverändert. Es wurden keine Tests hinzugefügt oder entfernt.

## Geprüfter Kandidat

- Basis: `f38f521b4f7d70dc837f65d5ebae941abf9e2d61`.
- SHA-256 von `linux/src/transcribe.rs` nach der Korrektur:
  `b633729305c2dc4c9c6426f527d4b52ded0324c8635b56ededa826ff2cad1064`.
- Linux-Rechner `omarchy`, Rust und Cargo 1.98.1, ALSA 1.2.16.1.
  `RUSTUP_AUTO_INSTALL=0` und `CARGO_NET_OFFLINE=true`; keine Installation.
- Nur eine eigene temporäre Repository-Kopie und künstliche Loopback-HTTP-Daten.
  Kein Mikrofon, externer Provider oder Zugangsdaten-Schreibzugriff.

## Nachweis und Wiederholung

In separaten temporären Testkopien erzwangen zwei Barrieren die Reihenfolge:
beide Dateien angelegt → Fehlertest beendet und Datei entfernt → Erfolgstest
liest. Mit dem alten Helfer scheitert genau der Erfolgstest beim Lesen
(Exit 101); mit getrennten Dateien bestehen beide Tests (Exit 0).
Die Barrieren gehören ausschließlich zur lokalen Gegenprüfung und wurden
nicht in den Repository-Kandidaten übernommen.

Am unveränderten korrigierten Kandidaten bestehen anschließend alle 23 Tests,
Formatierung, Clippy mit `-D warnings` und der Release-Build. Weitere 100
parallele Durchläufe der beiden vorhandenen HTTP-Tests bestehen. Wiederholbare
Befehle mit bereits installierter Toolchain, im Repository-Hauptordner:

```sh
RUSTUP_AUTO_INSTALL=0 CARGO_NET_OFFLINE=true bash scripts/ci/check-linux.sh
for iteration in $(seq 1 100); do
  RUSTUP_AUTO_INSTALL=0 CARGO_NET_OFFLINE=true cargo test --locked \
    --manifest-path linux/Cargo.toml transcribe::tests:: -- --test-threads=2 || exit
done
```

Lokale Detailnachweise liegen unter
`~/.codex/artifacts/opendictate/ci-linux-fixture-20260930/`:
Prüfskript, Quellhash-Manifest, Rot-/Grün-Protokolle, vollständige Linux-Checks
und Wiederholungsprotokoll. Nach den Tests sind keine Fixture-Dateien übrig;
die eigene Linux-Testkopie wurde entfernt und ihre Abwesenheit geprüft.
Dies ist ein synthetischer CI-Nachweis, keine Diktat-Abnahme.

Ein unabhängiges lesendes Worktree-Review prüfte denselben Quellhash und den
vollständigen Patch vor dem Code-Commit. Keine wesentlichen Befunde;
Produktionscode, Assertions und Testanzahl sind unverändert. Das Review
prüfte die vorhandenen Protokolle, wiederholte keine Laufzeittests.
