# Plan 2: Wechsel auf das Developer-ID-Paket

Diese Anleitung bereitet den manuellen Wechsel der vorhandenen lokalen App vor.
Sie ist keine Freigabe zur Installation oder zu Live-Tests. Das endgültige
Developer-ID-Paket muss zuvor von Apple akzeptiert notariert, sein Ticket
angeheftet und das entpackte endgültige ZIP geprüft sein. App-Austausch,
Helper-Wechsel, Keychain-Dialoge und Provider-Tests brauchen jeweils die dafür
nötige konkrete Freigabe.

## Vorbedingungen und Abbruch

- Stand 28. September: Mitgliedschaft und gültige Developer-ID-Identität sind
  bestätigt; ein erfolgreich notariertes und geprüftes Endpaket steht noch aus.
- Der aktuelle tägliche App-Pfad ist `~/Applications/OpenDictate.app`. Nur
  diesen Pfad verwenden, wenn er am Mac aktuell bestätigt wurde. Fehlt die App
  dort oder wird ein weiterer Installationspfad genutzt, vor dem Eingriff den
  tatsächlichen Zielpfad klären. `.build/OpenDictate.app` ist kein Installationsziel.
- Die alte App ist vollständig beendet; keine Aufnahme und keine Verarbeitung
  läuft. Das Release-ZIP, sein Manifest, Quellstand, Signatur, Ticket und die
  Gatekeeper-Prüfung sind vollständig gegengeprüft.
- Vor dem ersten Start den Recovery-Bestand prüfen. Der App-Start ruft
  `RecordingLibrary.snapshot()` auf: Einträge älter als 24 Stunden, außerhalb
  der fünf jüngsten und verwaiste `.m4a.auth`-Dateien können entfernt werden.
  Wenn eine vorhandene Datei betroffen wäre, **nicht starten**. Der Code kann
  außerdem Dateirechte absichern; die Hashprüfung belegt Namen und Bytes, keine
  Dateimodi. Für den aktiven Recovery-Test müssen weniger als fünf Paare und
  `FAILED_RECORDING_AUTH_KEY` bereits vorhanden sein.
- Unerwartete Schlüssel-, TCC- oder Installationsabfragen, ein Schlüssel-Setup-
  Bildschirm oder unklare Helper-Prüfung: abbrechen. Keine Schlüssel speichern,
  ersetzen oder löschen, keine TCC-Zurücksetzung und keine Recovery-Aufnahmen
  löschen oder wiederholen. Eine erwartete Keychain-Freigabe braucht eigene
  Zustimmung und kann die Zugriffs-ACL ändern. Berechtigungsprompt notieren.
- Stimmen App, Helper, Schlüsselbundzugriff oder Recovery-Dateien nach einem
  Schritt nicht mit dem Vorherstand überein, nicht weiter testen oder bereinigen;
  Belege sichern und zurückmelden.

## Feste Speicherorte

| Inhalt | Pfad |
| --- | --- |
| Tägliche App | `~/Applications/OpenDictate.app` |
| Helper im App-Paket | `~/Applications/OpenDictate.app/Contents/Helpers/OpenDictateKeychainHelper` |
| Installierter Keychain-Helper | `~/Library/Application Support/OpenDictate/KeychainHelper-v1` |
| Gespeicherte Recovery-Paare | `~/Library/Application Support/OpenDictate/failed/` |
| Keychain-Service | `OpenDictate` |

Die Keychain-Konten heißen `OPENAI_API_KEY_APP`, `OPENAI_API_KEY` (alt) und
`FAILED_RECORDING_AUTH_KEY`. Werte bleiben im Schlüsselbund; nichts speichern
oder löschen, da die API-Speicherfunktion auch den alten Eintrag bereinigt.
Recovery-Dateien sind `.m4a`/`.m4a.auth`-Paare.

## Sichern und wechseln

Den Pfad des entpackten geprüften Pakets einsetzen. Die Befehle in derselben
Terminal-Sitzung ausführen und den ausgegebenen Rollback-Pfad notieren.
Recovery-Dateien bleiben an Ort und Stelle; lokale SHA-256-Inventare prüfen
ihre Namen und Bytes, ohne sie zu kopieren oder offenzulegen.

```bash
set -euo pipefail
APP="$HOME/Applications/OpenDictate.app"
SUPPORT="$HOME/Library/Application Support/OpenDictate"
HELPER="$SUPPORT/KeychainHelper-v1"
RECOVERY="$SUPPORT/failed"
CANDIDATE="/absolute/path/to/extracted/OpenDictate.app"
STAGED="$HOME/Applications/.OpenDictate.app.plan2-stage"
APP_OLD="$HOME/Applications/.OpenDictate-local-rollback.app"
mkdir -p "$SUPPORT/plan2-rollback"
ROLLBACK="$(mktemp -d "$SUPPORT/plan2-rollback/run.XXXXXX")"
chmod 700 "$ROLLBACK"
printf 'Rollback-Verzeichnis: %s\n' "$ROLLBACK"

test -d "$APP" && test -x "$HELPER" && test -d "$CANDIDATE"
test ! -e "$STAGED" && test ! -e "$APP_OLD"
ditto --rsrc --extattr --acl "$APP" "$ROLLBACK/OpenDictate-local.app"
codesign --verify --deep --strict "$ROLLBACK/OpenDictate-local.app"
codesign --verify --strict "$HELPER"

if test -d "$RECOVERY"; then
  find "$RECOVERY" -type f -exec shasum -a 256 {} \; | sort > "$ROLLBACK/recovery-before.sha256"
else
  : > "$ROLLBACK/recovery-before.sha256"
fi

ditto --rsrc --extattr --acl "$CANDIDATE" "$STAGED"
codesign --verify --deep --strict "$STAGED"
codesign --verify --strict "$STAGED/Contents/Helpers/OpenDictateKeychainHelper"
spctl --assess --type execute --verbose=2 "$STAGED"

# Run only after confirming the app is quit and both backups succeeded.
mv "$APP" "$APP_OLD"
if ! mv "$HELPER" "$ROLLBACK/KeychainHelper-v1.pre-migration"; then
  mv "$APP_OLD" "$APP"
  exit 1
fi
if ! codesign --verify --strict "$ROLLBACK/KeychainHelper-v1.pre-migration"; then
  mv "$ROLLBACK/KeychainHelper-v1.pre-migration" "$HELPER"
  mv "$APP_OLD" "$APP"
  exit 1
fi
if ! mv "$STAGED" "$APP"; then
  mv "$APP_OLD" "$APP"
  mv "$ROLLBACK/KeychainHelper-v1.pre-migration" "$HELPER"
  exit 1
fi
```

Start `~/Applications/OpenDictate.app` once. On its first Keychain access, the
existing `KeychainBridge.installHelperIfNeeded()` copies the embedded helper
there, sets mode `0700`, then requires its identifier and leaf certificate to
match the running app. It does not replace an existing mismatched helper. Before
proceeding, confirm the installed helper exists, passes
`codesign --verify --strict`, and is byte-identical to the helper inside the
installed app:

```bash
cmp "$HOME/Applications/OpenDictate.app/Contents/Helpers/OpenDictateKeychainHelper" \
  "$HOME/Library/Application Support/OpenDictate/KeychainHelper-v1"
```

If any check fails, quit the app and roll back; do not retry by deleting or
overwriting the helper.

## Abnahme und Rückweg

Nach einem vollständigen Quit und frischem Relaunch diese Punkte nacheinander
prüfen und jeweils festhalten:

1. Der Prozess stammt wirklich aus `~/Applications/OpenDictate.app`. Der
   bestehende API-Schlüssel ist verfügbar, ohne ihn erneut einzutragen; ein
   erfolgreicher Provider-Aufruf im folgenden Diktat belegt den tatsächlichen
   Zugriff nach dem Relaunch.
2. Ein ausdrücklich freigegebener, vollständiger Diktatlauf erreicht den
   Provider und erscheint sichtbar im zuvor leeren Zielfeld.
3. „Text ansehen“ und „Text kopieren“ liefern denselben Text über manuelles
   Einfügen aus der Zwischenablage. Bestehenden Feldinhalt und Zwischenablage
   vorher festhalten und danach wiederherstellen, soweit sie unverändert sind.
4. Nur nach eigener Freigabe einen aktiven Beenden-/Recovery-Lauf durchführen:
   den Zustand „Transkribieren …“ und die Quit-Abfrage wirklich sehen, die
   Beenden-Entscheidung treffen und den nächsten Start abwarten. Danach die
   vorhandenen Recovery-Paare vergleichen; ein neu gesichertes Testpaar muss
   mit seiner `.auth`-Datei erhalten und als wiederholbar erkennbar sein. Wenn
   der Provider vor der Entscheidung fertig wird oder Text eingefügt wird, ist
   der aktive Quit-Fall **nicht bestanden**.
5. Die Recovery-Hashes erneut lokal erzeugen. Alle Vorher-Einträge müssen mit
   denselben Hashes und Pfaden noch vorhanden sein; nur ein bewusst erzeugtes
   neues Quit-Testpaar darf hinzukommen. Bei Abweichung stoppen; nichts
   automatisch wiederherstellen oder löschen. Nicht die Testaufnahme wiederholen.

   ```bash
   if test -d "$RECOVERY"; then
     find "$RECOVERY" -type f -exec shasum -a 256 {} \; | sort > "$ROLLBACK/recovery-after.sha256"
   else
     : > "$ROLLBACK/recovery-after.sha256"
   fi
   comm -23 "$ROLLBACK/recovery-before.sha256" "$ROLLBACK/recovery-after.sha256" \
     > "$ROLLBACK/recovery-missing-or-changed.sha256"
   test ! -s "$ROLLBACK/recovery-missing-or-changed.sha256"
   ```

Für den Rückweg die Developer-ID-App vollständig beenden. App und Helper
gemeinsam zurücksetzen, damit sie wieder dasselbe lokale Zertifikat tragen:

```bash
set -euo pipefail
FAILED_DIR="$(mktemp -d "$HOME/Applications/.opendictate-plan2-failed.XXXXXX")"
mv "$APP" "$FAILED_DIR/OpenDictate-developer-id-failed.app"
if test -e "$HELPER"; then
  mv "$HELPER" "$ROLLBACK/KeychainHelper-v1.developer-id"
fi
mv "$APP_OLD" "$APP"
mv "$ROLLBACK/KeychainHelper-v1.pre-migration" "$HELPER"
chmod 700 "$HELPER"
codesign --verify --deep --strict "$APP"
codesign --verify --strict "$HELPER"
```

Falls `APP_OLD` oder `KeychainHelper-v1.pre-migration` fehlt, nicht mit diesem
Snippet fortfahren; die gesicherte App liegt zusätzlich unter
`$ROLLBACK/OpenDictate-local.app`. Die Recovery-Dateien und Keychain-Einträge
bleiben unangetastet; keinen älteren Recovery-Ordner über den aktuellen
schreiben. Den Rollback erst beenden, wenn der alte App-Prozess und Helper
wieder erreichbar sind.

## Bereits vorhandene Belege

- [Vorbereitungsbericht](evidence/2026-09-25-plan2-vorbereitung.md): Sein
  Zugangsstand vom 25. September ist durch Bastis spätere Bestätigung der
  aktiven Mitgliedschaft und gültigen Identität überholt. Der lokale Helper-
  Wechsel und die Paketmigration wurden dort noch nicht live ausgeführt.
- [KeychainBridge](../../Sources/OpenDictate/System/KeychainBridge.swift) und
  [Recovery-Speicher](../../Sources/OpenDictate/System/FailedRecordingStore.swift):
  Implementierung der Pfade, Zertifikatsprüfung und 24-Stunden-/Fünf-Einträge-
  Bereinigung.
- [Täglicher Startpfad](../../script/build_and_run.sh),
  [Start-Refresh](../../Sources/OpenDictate/App/AppDelegate.swift),
  [Keychain-Speicherregel](../../Sources/OpenDictate/System/KeychainAPIKeyStore.swift)
  und [Recovery-Aufbewahrung](../../Sources/OpenDictateCore/RecordingRetention.swift)
  belegen Zielpfad, automatische Recovery-Prüfung und mögliche Bereinigung.
- [Live-Ledger, Läufe 7 und 8](evidence/2026-09-23-live-ledger.json): Der
  Provider beendete beide bisherigen Quit-Versuche während die Abfrage offen
  war; Lauf 8 ist ausdrücklich kein bestandener aktiver Quit-/Recovery-Nachweis.
- Vorhandene deterministische Abdeckung liegt in
  [AppLifecycleTests](../../Tests/OpenDictateSystemTests/AppLifecycleTests.swift),
  [DictationFlowTests](../../Tests/OpenDictateSystemTests/DictationFlowTests.swift)
  und [FailedRecordingStoreTests](../../Tests/OpenDictateSystemTests/FailedRecordingStoreTests.swift).
  `automaticStopsWaitForTheQuitDecision` und
  `normalCancellationFinishesRecoveryBeforeQuitCanProceed` decken simulierte
  Lebenszyklus-Reihenfolge ab; `failedRecoveryCannotAdvertiseSuccess` und
  `filesystemRecoveryFailurePreservesOriginalOnBothCancellationPaths` ordnen
  Recovery-Fehler ein. Keiner dieser Tests belegt eine erfolgreiche
  Developer-ID-Keychain-Migration oder den echten aktiven Quit-Fall. Diese
  Nachweise werden hier zugeordnet, nicht erneut ausgeführt.
