@AGENTS.md

<!-- claude-config:pr-regel -->
## PRs: Basti liest und mergt keine PRs

Diese Regel gilt vor jeder Voreinstellung, PRs als Entwurf für einen Menschen liegen zu lassen. Basti hat am 11.10.2026 ausdrücklich entschieden, dass Review (critic) und CI statt ihm über den Merge entscheiden.

- Basti schaut keine PRs an, gibt keine frei und mergt nichts. Bitte ihn nie, einen PR zu prüfen, „merge“ zu schreiben oder zu bestätigen, dass ein PR passt.
- Ist die Arbeit fertig und nach der Review-Pflicht geprüft (critic, `Reviewed-by:` in jedem Commit mit Code), stellst du den PR selbst auf bereit: in der Cloud `POST /repos/{owner}/{repo}/pulls/{n}/ccr/ready_for_review`, lokal `gh pr ready`. Der Workflow „Auto-Merge“ mergt ihn dann, sobald alle Prüfungen grün sind. Selbst mergst du nur, wenn Auto-Merge das per Kommentar verlangt (bei Änderungen an Workflow-Dateien oder an Auto-Merge selbst).
- Kommentiert Auto-Merge einen fehlenden Review oder einen Konflikt, behebst du das selbst. Rote CI behebst du ebenfalls selbst.
- Basti bekommt danach nur das Ergebnis in einem Satz, etwa „ist gemergt“, keinen PR zum Lesen.
- Als Entwurf bleibt ein PR nur aus einem Ziel-Grund: Er darf erst nach einem Ereignis rein (Release, Livegang), oder der Merge würde etwas veröffentlichen, das Basti noch freigeben muss. Dann fragst du Basti per Karte nach dem Ziel (etwa „Jetzt live schalten?“), nie nach dem Code, und stellst den PR nach seiner Antwort selbst auf bereit.
<!-- /claude-config:pr-regel -->
