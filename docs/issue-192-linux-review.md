# Linux-Nacharbeiten zu Issue #192

Stand: 17. Oktober 2026. Ausgangspunkt: `cf349a0d1e24ed1e1061776e85aa7bf864ac0405`.
Auftrag: [Issue #192](https://github.com/HerrStolzier/OpenDictate/issues/192).

## Geändertes Verhalten

- Eine alte Einstellungsdatei mit `model: large-v3`, ohne `server`, `service`
  und `custom_model`, lässt sich auch ohne `OPENAI_BASE_URL` laden. Die freien
  Modellnamen wandern in die eigenen Modellfelder; OpenAI erhält seine
  Standardwerte. Laden allein überschreibt die Datei nicht.
- Nach `settings server ADRESSE` nennt die Ausgabe den tatsächlich aktiven
  Dienst. Bei einer inaktiven gespeicherten Adresse nennt sie den Wechselbefehl
  und behauptet keinen Schlüsselversand dorthin. Die bisherige Rangfolge mit
  `OPENAI_BASE_URL` bleibt erhalten.
- Der Worker protokolliert Aufnahme-, Transkriptions- und Übersetzungsfehler
  mit den bekannten Berichtscodes, ohne Fehlermeldung oder Inhalte anzuhängen.
  Ein unmittelbar folgendes `recording-kept` verdeckt den Providerfehler im
  Bericht nicht. Zwischenereignisse verhindern die Zuordnung eines alten
  Providerfehlers zu einem späteren Diktat.
- Ohne bestätigte passende Kürzel-Belegung bleibt die gespeicherte Aufnahmeart
  erhalten. Der Abschluss nennt die ausstehende manuelle Einrichtung statt
  „Fertig. Halte …“. Die Anleitung fordert zum Ersetzen der bisherigen
  Belegung auf, damit keine doppelten Befehle entstehen. Nach manueller
  Änderung kann `setup` die geladene Belegung prüfen und die Aufnahmeart
  speichern; Mischungen aus Antippen und Halten werden nicht bestätigt.
  Automatische Änderungen behalten ihre Sicherung und Rücknahme bei Fehlern.

Der optionale Windows-Punkt ist nicht Teil dieser Änderung.

## Nachweis und Wiederholung

Native Prüfung auf omarchy mit dem bereits installierten Rust/Cargo 1.98.1
und ALSA 1.2.16.1, aus einer eigenen temporären Quellkopie:

```bash
bash scripts/ci/check-linux.sh
```

Exitcode 0: Formatierung, **144 Unit-Tests und 2 CLI-Integrationstests**,
Clippy mit `-D warnings` und gesperrter Release-Build bestanden.
Der abschließende Kandidat ist im [PR #193](https://github.com/HerrStolzier/OpenDictate/pull/193)
gebunden; die dortigen CI-Prüfungen nennen den genauen Commit. Das unabhängige
Review prüfte zuerst den Gesamtpatch, danach gezielt die Korrekturen aus dem
Review einschließlich der unveränderten Aufnahmeart bei manueller Einrichtung.

Die neuen Tests schützen jeweils die betroffene Grenze:

- `legacy_custom_model_without_address_or_environment_still_loads`: alte
  JSON-Datei laden, Modellwerte prüfen, unveränderte Ursprungsdatei prüfen und
  erst danach speichern/erneut laden.
- `saved_address_output_tracks_the_actual_service_in_both_languages`: echtes
  CLI mit eigener Einstellungsdatei, DE/EN-Ausgabe, inaktive und aktive Adresse
  sowie abweichende Umgebungsvariable.
- Bestehender Aufnahme-Ablauftest und
  `translation_failure_is_logged_without_provider_details`: echte
  Verarbeitung mit Loopback-HTTP-Fehlern und anschließendem Betriebsprotokoll.
- `report_reads_real_operation_log_lines_and_discards_their_details`: echte
  `log_ops`-Dateizeilen samt `recording-kept` durch den Bericht, einschließlich
  späterer Ereignisse und verworfener privater Details.
- `setup_reports_manual_work_and_persists_only_installed_bindings`:
  vollständiger `setup`-Befehl in einem Pseudoterminal. Sieben Fälle decken
  F9 ohne Konfiguration, Überspringen, bisheriges Super+D, reine Lua-Datei,
  automatische klassische Ersetzung, bereits geladenes Halten und gemischte
  Antipp-/Haltebefehle ab. Gespeicherter Modus, Abschlussmeldung und
  unveränderte beziehungsweise ersetzte Konfiguration werden geprüft.

Rotnachweis in einer getrennten Quellkopie: Produktionscode aus `cf349a0`
für `main.rs`, `settings.rs`, `setup.rs` und `report.rs` sowie `shortcut.rs`, dieselben neuen
Testmodule und Testhilfen beibehalten. Quelldateizeit vor dem erneuten Bau
aktualisiert, damit Cargo keine jüngeren Kandidatenartefakte wiederverwendet.
`cargo test --locked --no-fail-fast --manifest-path linux/Cargo.toml` endet dort
mit 101: 140 Unit-Tests bestehen, die vier betroffenen Unit-Tests und beide
CLI-Tests scheitern gezielt. Mit der Reparatur bestehen alle 146 Tests.

Zusätzlich bestanden: 56 Python-Tests, lokale Markdown-Linkprüfung,
Swift-Formatprüfung, die sieben Shell-Syntaxprüfungen aus `CHECKS.md` und
`git diff --check`. Swift-Quellcode ist unverändert; die regulären
plattformübergreifenden CI-Prüfungen laufen am PR.

## Aussagegrenze

Die CLI-Prozesse, Terminalein-/ausgabe, Dateien und Loopback-Anfragen sind echt.
Schlüsselbund und `hyprctl` sind eigene Attrappen. Kein echtes Mikrofon,
externer Provider, Desktop-Hotkey, Einfügen, Installation oder Release wurde
ausgeführt. Der Nachweis ist eine Offline-Ablaufprüfung und keine neue
Hyprland-Live-Abnahme. Temporäre Quellkopien und Testzustände werden nach dem
Git-Abschluss entfernt; die vorhandenen Live-Nachweise bleiben unverändert.
