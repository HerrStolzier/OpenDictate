# Plattform-Fortsetzung · 28. September 2026

Dieser datierte Nachweis ergänzt die frühere
[Geräteprüfung](platform-audit-2026-09-28.md). Laufende Aufgaben stehen nur
in [ROADMAP](../ROADMAP.md), der aktuelle Übergabestand in
[remaining-acceptance](remaining-acceptance.md).

## Windows: vorhandene Schutzprüfungen abgeschlossen

Der vorhandene Prototyp wurde unverändert in einer eigenen temporären Kopie
auf `xmg` geprüft. Die 37 zuvor verglichenen Quell-/Projekt-/Skriptdateien
stimmen weiterhin mit dem lokalen Hashinventar überein. Zusätzlich zu den
bereits bestandenen 23 Kern-/Ablaufprüfungen bestanden **18/18 Schutzprüfungen**
im angemeldeten Desktop, mit normalen Benutzerrechten: insgesamt 41/41.

Der erste SSH-Lauf bestand 16/18. Die Credential-Fälle scheiterten dort;
eine separate Abfrage eines eindeutig nicht vorhandenen Testeintrags meldete
Win32-Fehler 1312 in Session 0. Der anschließende Lauf im angemeldeten Desktop
bestand einschließlich Speichern, Lesen und Entfernen eines isolierten
Dummy-Zugangseintrags. Der Produktionscode wurde dafür nicht geändert.
Dies ist kein Nachweis einer realen Aufnahme, Anbieteranfrage oder sichtbaren
Produktabnahme.

Wiederholbarer Prüfweg nach konkreter Freigabe für den Dummy-Eintrag:

```powershell
# Im angemeldeten Windows-Desktop, in einer separaten Kopie des Prototyps:
dotnet run --no-restore --project OpenDictate.WindowsChecks -c Release
```

Für diesen Lauf startete eine eigene temporäre Aufgabe ohne Zeittrigger den
vorab gebauten Prüfer als interaktiver Benutzer mit `RunLevel=Limited`.
Ergebnis: Exitcode 0. Eigene Aufgabe und Prüfkopie wurden danach entfernt.
Die Prüfungen bestätigten das Entfernen des Dummy-Eintrags; vorhandener
API-Schlüssel und Nutzeraufnahmen wurden nicht verändert.

Lokaler Rohbeleg:
`~/.codex/artifacts/opendictate/platform-resume-20260928/windows-desktop-protection-final.log`.
Der frühere 23er-Lauf und das 37-Dateien-Hashinventar liegen im benachbarten
Verzeichnis `code-reduction-20260928`. Diese lokalen Dateien werden nicht
als öffentliche Downloadartefakte ausgegeben.

## Linux: isolierter Kandidat und Schlüsselvorbereitung

Aus `1f895537e9b36d962eb1425113423da377e95b1b` wurde ausschließlich `linux/`
in eine eigene temporäre Kopie auf `omarchy` übertragen und mit
`cargo build --offline --locked --release` gebaut. Das bestehende
Linux-Checkout blieb unverändert. Binär-SHA-256:
`0b6122eb5ccfc6d942cdb1eb9ba4161b29cf330ee06142285ae2e500a950a849`.

Vor der genehmigten Einrichtung waren beide OpenDictate-Schlüssel per
Secret-Service-Metadatenabfrage nicht vorhanden. Nach der Freigabe wurde
`secrets init-auth` erfolgreich ausgeführt; die erneute Metadatenabfrage
bestätigte den Aufnahmeschutzschlüssel. Nach Bastis verdeckter Eingabe
bestätigte dieselbe Metadatenprüfung auch den API-Schlüsseleintrag. Es wurde
kein Schlüsselinhalt ausgelesen oder protokolliert. Ob OpenAI den eingegebenen
API-Schlüssel akzeptiert, ist noch nicht geprüft.

Das lokale Einrichtungsskript verwendet `systemd-ask-password` und eine
direkte Pipe zu `opendictate secrets set-api-key`. Einen bereits vorhandenen
API-Schlüssel überspringt es. Skript und Buildprotokoll liegen unter
`~/.codex/artifacts/opendictate/platform-resume-20260928/`.
Das eigene Einrichtungsfenster wurde nach erfolgreicher Speicherung geschlossen.
Diese Vorbereitung enthält keine Mikrofonaufnahme, Anbieteranfrage oder
Clipboard-/Hotkey-Abnahme. PipeWire und WirePlumber sind aktiv; `wpctl status`
zeigt einen analogen Audioeingang, jedoch keinen ausgewählten Standard-
Audioeingang. `wpctl get-volume @DEFAULT_AUDIO_SOURCE@` scheitert mit
„not a valid ID“. Welches physische Mikrofon angeschlossen ist, ist damit
nicht belegt. Basti hat den Linux-Diktattest daraufhin ausdrücklich vorerst
zurückgestellt. Es wurde kein Live-Test begonnen. Das eigene temporäre
Quell-/Buildverzeichnis wurde nach Prüfung auf laufende Kandidatenprozesse
und Audiodateien entfernt; beide genehmigt eingerichteten Schlüssel bleiben
im Schlüsselbund.

## Windows-Snapshot und unabhängige Prüfung

Der Worker sicherte 45 Dateien im Commit `a7e7d21b8efe1b6705f1b13c80b39d960e6a1188`.
37 ursprüngliche und vier ergänzende Originaldateien stimmen direkt mit dem
Windows-PC überein. README, Herkunft, Releaseplan und Hashliste beschreiben
den Entwicklungsstand; das Hashmanifest bindet 42 Projektdateien.
Der unabhängige Kritiker prüfte diesen exakten Snapshot sowie den
Dokumentationscommit `1543d33` auf Basis `1f895537`: keine wesentlichen Befunde
im begrenzten Integritäts-/Statusumfang. Er wiederholte keine Geräte- oder
Credentialtests und führte kein vollständiges Windows-Sicherheitsaudit durch.
Die Hauptaufgabe verglich alle 45 Dateien zusätzlich mit dem eingefrorenen
Review-Snapshot, bevor sie den Commit übernahm. Kleine anschließende
Status-/Querverweisänderungen wurden separat auf Links und Prüfsummen geprüft.
