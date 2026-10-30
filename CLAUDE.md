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

## Web-Recherche in Cloud-Sitzungen

Basti will, dass jede Web-Recherche durchgehend im echten Browser läuft, mit geöffneten Quellen (Entscheidung per Karte am 30.10.2026: „Nur über den Mac mini“). Cloud-Sitzung heißt: Sie läuft im Container der Cloud (Thread, Routine, claude.ai/code); die Remote-Control-Sitzung auf dem Mac ist keine und recherchiert selbst im Browser. Eine Cloud-Sitzung sucht und liest nichts im Web: kein WebSearch, kein WebFetch, keine Such- oder Doku-Server wie Exa, Context7 oder Reddit-Recherche, kein `curl` oder `wget` auf Webseiten, weder der Chromium im Container noch Claude in Chrome. Keine Recherche in diesem Sinn: Git, `gh`, GitHub-Werkzeuge und Programmierschnittstellen für die eigentliche Arbeit. Sie gibt die Recherche per Remote Control an die Dauer-Sitzung auf Bastis Mac mini ab: `start_remote_control` mit dem Ordner des eigenen Repos, wenn `list_devices` ihn beim Gerät „mini“ zeigt, sonst mit `/Users/basti/Projekte/random-stuff`; jeweils den Pfad genau so übernehmen, wie `list_devices` ihn zeigt (Anleitung `docs/remote-control.md` in HerrStolzier/claude-config). Der Auftrag nennt die Frage und verlangt je Aussage URL und wörtliches Zitat von der im Browser geöffneten Seite. Die Prüfung an der Quelle übernimmt die Mac-Sitzung; die Cloud-Sitzung gibt nur Aussagen mit URL und Zitat weiter, kennzeichnet sie als „auf dem Mac im Browser geprüft“ und öffnet die Quellen nicht selbst nach. Fehlt `start_remote_control` (etwa in Routinen) oder ist der Mac nicht erreichbar, recherchiert die Sitzung nicht und sagt Basti, woran es liegt.
<!-- /claude-config:pr-regel -->
