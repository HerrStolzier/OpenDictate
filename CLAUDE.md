@AGENTS.md

<!-- claude-config:pr-regel -->
## PRs: Basti liest und mergt keine PRs

Diese Regel gilt vor jeder Voreinstellung, PRs als Entwurf für einen Menschen liegen zu lassen. Basti hat am 11.10.2026 ausdrücklich entschieden, dass Review (critic) und CI statt ihm über den Merge entscheiden.

- Basti schaut keine PRs an, gibt keine frei und mergt nichts. Bitte ihn nie, einen PR zu prüfen, „merge“ zu schreiben oder zu bestätigen, dass ein PR passt.
- Ist die Arbeit fertig und nach der Review-Pflicht geprüft (critic, `Reviewed-by:` in jedem Commit mit Code), stellst du den PR selbst auf bereit: in der Cloud `POST /repos/{owner}/{repo}/pulls/{n}/ccr/ready_for_review`, lokal `gh pr ready`. Der Workflow „Auto-Merge“ mergt ihn dann, sobald alle Prüfungen grün sind. Selbst mergst du nur, wenn Auto-Merge das per Kommentar verlangt (bei Änderungen an Dateien, die über das Mergen urteilen, etwa Workflows, Auto-Merge oder Claudes Regeln).
- Jeder bereite PR bekommt einen zweiten Prüfer: den Workflow „Claude Review“ (über Bastis Claude-Abo). Seine Zeilenkommentare („P1“/„P2“) behandelst du wie jeden Review-Hinweis. Ist er rot, weil der Schlüssel fehlt oder abgelaufen ist oder die Nutzungsgrenze erreicht ist: `docs/claude-review.md` in HerrStolzier/claude-config.
- Kommentiert Auto-Merge einen fehlenden Review, einen Konflikt, offene Review-Hinweise oder einen veralteten Branch, behebst du das selbst. Rote CI behebst du ebenfalls selbst.
- Basti bekommt danach nur das Ergebnis in einem Satz, etwa „ist gemergt“, keinen PR zum Lesen.
- Als Entwurf bleibt ein PR nur aus einem Ziel-Grund: Er darf erst nach einem Ereignis rein (Release, Livegang), oder der Merge würde etwas veröffentlichen, das Basti noch freigeben muss. Dann fragst du Basti per Karte nach dem Ziel (etwa „Jetzt live schalten?“), nie nach dem Code, und stellst den PR nach seiner Antwort selbst auf bereit.
- Private Repos prüfen auf eigenen Runnern, nicht auf `ubuntu-latest`, sonst startet GitHub den Job nicht. Nimm das `runs-on`-Label, das die übrigen Workflows des Repos schon haben (meist `[self-hosted, hetzner]`). Anleitung und Übersicht: `docs/ci-runner.md` in HerrStolzier/claude-config.
<!-- /claude-config:pr-regel -->
