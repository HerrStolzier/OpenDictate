# Arbeitsweise für Aufträge aus der Planung

Gilt ab 2. Oktober 2026 für jede Claude-Code-Session in diesem Repo.
Ergänzt AGENTS.md; bei Widerspruch gilt AGENTS.md (Invarianten, Sicherheit).

## Auftragsgröße

Ein Auftrag umfasst eine ganze Stufe oder einen abgeschlossenen Block, nicht
einen Einzelschritt. Innerhalb des Auftrags wird ohne Rückfrage weitergearbeitet,
bis ein Haltegrund (unten) eintritt oder der Auftrag erledigt ist.

## Haltegründe – nur hier wird gestoppt und gefragt

1. **Unumkehrbares:** Veröffentlichung, Löschen von Nutzerdaten oder
   Aufnahmen, Änderungen an Signierschlüsseln oder Zertifikaten, TCC-Reset,
   Uploads an Apple.
2. **Basti wird physisch gebraucht:** Live-Tests, Installation, Dialoge am
   Mac, Mikrofon. Dann die Vorbereitung abschließen und mit klarer Liste
   stoppen, was Basti tun muss.
3. **Roter Check oder offener Review-Kommentar**, den du nicht selbst
   sauber beheben kannst.
4. **Echte Entscheidung** mit zwei vertretbaren Wegen, die der Auftrag nicht
   vorwegnimmt. Dann beide Wege nennen, Empfehlung dazu, stoppen.

Alles andere – Doku, Tests, CI-Konfiguration, Fixtures, Kleinkorrekturen,
Formulierungen – wird entschieden und gemacht.

## Freigaben, die dauerhaft gelten

- Doku-, Test- und CI-Änderungen: committen, pushen, PR, Auto-Merge aktivieren
  (`gh pr merge --auto --merge`). Kein Diff vorab zeigen.
- App-Code, der Audio, Recovery, Keychain, Hotkey oder Einfügen berührt:
  critic-Review vor dem Commit, Diff in der Rückmeldung zusammenfassen,
  PR ohne Auto-Merge – die Planung schaut drüber.
- Sonstiger App-Code: critic-Review, PR mit Auto-Merge.
- PR-Branches nach Merge löschen, `main` nachziehen, `STATUS.md` (lokal)
  auf den neuen Stand bringen.

## Rückmeldung

Einmal am Ende des Auftrags, nicht nach jedem Schritt, im Block
„--- RÜCKMELDUNG AN PLANUNG ---" bis „--- ENDE ---" mit: Stand, Branches/PRs
und Merge-Commits, Erledigt, Abweichungen, Prüfung, Offen (nummeriert, mit
Vorschlag), Nächster Schritt. Wenn ein Haltegrund eintritt: Block mit dem
bis dahin erreichten Stand und dem Haltegrund unter „Offen".
