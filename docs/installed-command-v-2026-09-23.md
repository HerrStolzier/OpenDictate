# Lokale Installation und begrenzte Einfügeprüfung vom 23. September 2026

## Kandidat und Eingriff

Revision `bd3630f605feff1ef64598ccab85511f944662c5` aus dem in `main`
gemergten [PR #23](https://github.com/HerrStolzier/OpenDictate/pull/23),
Buildnummer 2, signiert mit der bereits vorhandenen Identität
`OpenDictate Self-Signed`. Das Bundle bestand Signatur-, Hardened-Runtime- und
Mikrofon-Entitlement-Prüfung sowie die sechs negativen Bundle-Fixtures.

Die zuvor laufende Revision `68ef919` wurde regulär beendet. Die alten Bundles
aus `/Applications/OpenDictate.app` und `~/Applications/OpenDictate.app` liegen
für ein Rollback unter `.build/install-rollback-20260923/system.app` und
`.build/install-rollback-20260923/user.app` dieses Worktrees. Beide installierten
Pfade enthalten jetzt dieselbe neue ausführbare Datei (SHA-256
`492d4b0609400a3926bd18881544d48c3ef89be90e059f9122869416821a5f5f`).
OpenDictate wurde aus `~/Applications` neu gestartet und lief anschließend.

## Sichtbare, begrenzte Prüfung

Eine eigene leere TextEdit-Datei wurde in einer getrennten TextEdit-Instanz
geöffnet. Der normale macOS-Einfügebefehl ⌘V übernahm den unkritischen Testtext
„OpenDictate Test: Äpfel 42.“ sichtbar und exakt in das Dokument. Der
Bedienungshilfen-Wert und die Fensteraufnahme zeigten denselben Text.
Anschließend wurde das eigene Fenster geschlossen, die eigene TextEdit-Instanz
beendet, die Testdatei entfernt und der vorherige Klartext der Zwischenablage
wiederhergestellt. Das Original-TextEdit des Nutzers blieb unangetastet.

Dieser Lauf verwendete **keine Aufnahme, keinen OpenAI-Upload und nicht den
automatischen Einfügeaufruf der installierten OpenDictate-App**. Er belegt die
native ⌘V-Wirkung im kontrollierten TextEdit-Feld, nicht den gesamten
Diktatpfad. Die neue App benötigt noch eine sichtbare
Mikrofon→Transkription→automatische-Einfügung-Abnahme und gezielte Tests in den
zuvor problematischen Feldtypen. Bedienungshilfen- und Keychain-Freigaben der
neu gestarteten App wurden nicht durch einen echten Diktatdurchlauf bestätigt.
