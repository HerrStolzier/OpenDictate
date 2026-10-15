# Sicherheit

Danke, dass du hinschaust. Wenn du in OpenDictate eine Sicherheitslücke
findest, sag mir bitte zuerst privat Bescheid, damit ich sie beheben kann,
bevor jemand sie ausnutzt.

## Lücke melden

1. Öffne im Repository den Tab **Security** und klick auf
   **Report a vulnerability**. Die Meldung sehen nur du und die Maintainer.
2. Beschreib, was passiert, wie man es nachstellt und welche Version oder
   welchen Build du nutzt.
3. Du bekommst eine Antwort, sobald ich die Meldung gelesen habe. Bis die
   Lücke behoben ist, bleibt sie bitte unter uns.

Fehlt der Knopf, öffne ein kurzes Issue ohne Details und bitte um einen
privaten Kontakt.

**Bitte nie öffentlich posten:** API-Schlüssel (auch abgelaufene),
Aufnahmen, Transkripte oder Logs mit persönlichen Inhalten. Das gilt auch für
Issues, Diskussionen und Pull Requests. Falls doch einmal ein Schlüssel
irgendwo landet: Widerruf ihn sofort bei deinem Anbieter.

## Was dazugehört

- die Mac-App (`Sources/`, Skripte zum Bauen und Signieren)
- die iPhone-App (`ios/`)
- die Linux-App (`linux/`)
- die Windows-App (`windows/`)
- die Website [opendictate.app](https://opendictate.app) (`website/`)

Lücken in OpenAI, in deinem eigenen Server oder in Bibliotheken anderer meldest
du bitte direkt dort. Wenn OpenDictate sie unsicher nutzt, gehört es wieder
hierher.

Wie Aufnahmen, Texte und Schlüssel durch die Apps laufen, steht in
[PRIVACY.md](PRIVACY.md).

## Für Maintainer: Einstellungen auf GitHub

Diese Schutzmaßnahmen lassen sich nicht im Code festlegen. Sie werden in den
Einstellungen des Repositorys und des Kontos gesetzt:

- [x] **Private vulnerability reporting** einschalten (Settings → Code
      security), damit „Report a vulnerability“ erscheint.
- [x] **Secret scanning** und **Push protection** einschalten.
- [x] **CodeQL** im Default setup laufen lassen (CHECKS.md setzt das voraus).
- [x] **Dependabot alerts** und **Dependabot security updates** einschalten.
- [x] Ruleset für `main`: erforderliche Statusprüfungen, Force-Push und
      Löschen blockieren.
- [x] Ruleset für die Tags `v*` und `linux-v*`: Ändern und Löschen blockieren.
- [ ] Releases mit signierten, annotierten Tags erstellen (`git tag -s`).
- [ ] Commit-E-Mail auf die GitHub-noreply-Adresse stellen und „Block command
      line pushes that expose my email“ einschalten.
- [ ] Windows-Code-Signierung ist noch offen (Azure Trusted Signing oder ein
      OV-Zertifikat).
- [ ] Die Website-Videos aus dem Git-Verlauf nach Cloudflare R2 oder Git LFS
      verlegen, damit das Repository klein bleibt.

**Dependabot-PRs:** Auto-Merge mergt nur PRs des Repo-Besitzers und
überspringt Dependabot. Seine PRs brauchen eine Claude-Routine, die sie prüft
und mergt, oder jemanden, der das von Hand macht. Ein FluidAudio-Update braucht
außerdem eine neue Version in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md),
ein Cargo-Update eine neu erzeugte Crate-Liste
(`python3 scripts/third-party-rust.py`).

**Auto-Merge und Regeln:** PRs, die `.github/`, `scripts/ci/`, `.claude/`,
`CLAUDE.md`, `AGENTS.md`, `.gitleaksignore` oder `.gitattributes` ändern,
mergt Auto-Merge nicht selbst, weil sie die Prüfungen ändern, die über sie
urteilen. Diese Regel steht in `.github/scripts/auto_merge.py`, einer Kopie aus
`HerrStolzier/claude-config`.

- [x] Die Änderung an `guarded()` auch in `HerrStolzier/claude-config`
      (`ci/auto_merge.py`) nachziehen. Sonst setzt der nächste Lauf von
      `install-repo-gate.py` sie zurück; `scripts/tests/test_auto_merge.py`
      fällt dann rot aus und zeigt das an.

**Secret-Scan:** Er liest `.gitleaksignore` vom Basis-Commit, ein PR kann also
kein eigenes Leck über diese Datei freigeben. Eine neue Ausnahme kommt deshalb
in einem eigenen PR vor dem PR mit dem Fund; die Schritte stehen in
[CHECKS.md](CHECKS.md#workflow-and-secret-checks). Ein `gitleaks:allow` direkt
in der Zeile wirkt weiterhin, darauf achtet das Review.
