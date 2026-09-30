# Projektprüfung und Bereinigung · 28. September 2026

## Ergebnis und Umfang

Die größte belegte Unordnung liegt in der verteilten Planung und den vermischten
aktuellen und historischen Statusangaben. Der macOS-Kern ist bereits in Ablauf,
Lebenszyklus, Audio, Übertragung, UI und Systemzugriffe aufgeteilt. Ein kompletter
Architekturwechsel oder pauschales Kürzen der Tests ist daraus nicht begründet.

Geprüfte Ausgangsrevision: `5b95535b8f80d1cc868318594860f64566294386`.
Dies ist eine statische Bestands- und Refactoringprüfung, keine neue Laufzeit-,
Sicherheits- oder Plattformabnahme. Die zentrale Aufgabenliste steht in
[ROADMAP.md](../ROADMAP.md); dieser datierte Bericht begründet die dortigen
Bereinigungspakete, führt aber keine zweite laufende To-do-Liste.

Nachtrag desselben Auftrags: Auf ausdrückliche Bitte wurden Linux und Windows
direkt verbunden und ihre Quellen/Offline-Prüfungen lokal geprüft. Die genauen
Stände, Ergebnisse und Grenzen stehen im
[Gerätebericht](platform-audit-2026-09-28.md).

Bestandsaufnahme aller 262 versionierten Dateien am Ausgangsstand:

| Bereich | Bestand | Prüfung |
| --- | ---: | --- |
| macOS `Sources/` | 46 Dateien, 237.168 Bytes | Modulgrenzen, Aufrufer, Ablauf/Abbruch, Schlüsselbund, UI, Duplikat- und Referenzsuche; vertiefte Lektüre der zentralen Pfade |
| `Tests/` | 27 Dateien, 109 `@Test`-Deklarationen | Aktuelle Anzahl und Verbraucher; vorhandene Testaudits wiederverwendet |
| `docs/` | 141 Dateien, 7.359.101 Bytes | Zuständigkeiten, aktuelle Aussagen, historische Nachweise, lokale Linkziele und Dateiduplikate |
| Linux | 17 Dateien | Getrennter Rust-Pfad und seine dokumentierte Abnahmegrenze |
| Skripte und CI | 12 Dateien plus ein Workflow | Build-/Paketwege, Wiederholungen und Seiteneffekte |
| Website | 4 Dateien | Lokaler Entwurf, Ressourcen und Verhältnis zu Produkt-/Releaseangaben |
| Windows | Separater lokaler Quellbaum | Getrennt vom Hauptrepository und von einer heutigen Geräteabnahme bewerten |

Dateigröße ist ein Suchhinweis, kein Fehlernachweis. Die aktuelle Übergabe hatte
562 Zeilen; `AppDelegate` 713, `DictationPanel` 607 und `MenuBarController` 534.
Historische Bildschirmaufnahmen und Prüfberichte sind keine App-Laufzeitlast.

## Belegte Ansatzpunkte im macOS-Code

### A: Kleine Entfernung und Korrektur ohne Funktionsumbau

- **Unbenutzter Farbhelfer:** `PanelColors.hex` in
  [DictationPanel.swift](../Sources/OpenDictate/App/DictationPanel.swift),
  Zeilen 510–514, hat im versionierten Swift-Bestand keinen Aufrufer.
  `pair` erzeugt die RGB-Farbe selbst. Die private Projektimplementierung
  kann den ungenutzten Helfer entfernen; kein neues Farbsystem nötig.
- **Irreführender Fokuskommentar:**
  [AppDelegate.swift](../Sources/OpenDictate/App/AppDelegate.swift),
  Zeilen 271–279, behauptet auch für die Auslieferung, dass kein Ziel nach einem
  Appwechsel reaktiviert werde. Der aktuelle
  [PasteboardInserter](../Sources/OpenDictate/System/PasteboardInserter.swift),
  Zeilen 44–58, aktiviert ausdrücklich die ursprüngliche App und prüft danach
  Vordergrund und Zwischenablage. Kommentar an das dokumentierte Verhalten
  anpassen; keine neue Fokusregel durch eine Textbereinigung einführen.
- **Irreführender Recovery-Kommentar:**
  [FailedRecordingStore.swift](../Sources/OpenDictate/System/FailedRecordingStore.swift),
  Zeilen 6–7, beschränkt auch Pruning sprachlich auf authentifizierte Dateien.
  `prune` in Zeilen 126–152 verwendet dagegen verwaltete Dateinamen sowie Alter
  und Anzahl. [PRIVACY.md](../PRIVACY.md) beschreibt das bereits einschließlich
  älterer Dateien korrekt. Kommentar korrigieren, keine Aufbewahrungsregel ändern.

**Abschlussprüfung:** Vollständige Referenzsuche, Source-Checks aus
[CHECKS.md](../CHECKS.md), Diff ohne veränderte Farbwerte, Fokus- oder
Löschentscheidung. Diese drei kleinen Wartungsänderungen wurden anschließend
in `1f895537` umgesetzt und bestanden die Source-Checks sowie die
[Coverage-Nachmessung](code-reduction-2026-09-28.md).

### B: Vorbereitung eines Diktats einmal ausführen

[AppDelegate.swift](../Sources/OpenDictate/App/AppDelegate.swift) liest bei
Aufnahmestart erst über `hasAPIKey` den Schlüssel (Zeilen 287 und 367–370) und
später über `TranscriptionOptions.current()` erneut (Zeile 301). Der Retrypfad
wiederholt dasselbe Muster (Zeilen 344 und 354). Der zweite Zugriff steht in
[OpenAITranscriber.swift](../Sources/OpenDictate/Transcription/OpenAITranscriber.swift),
Zeilen 10–14. Beide laufen über dieselbe Schlüsselablage.

Das ist eine bestätigte doppelte Operation, kein gemessener Latenzfehler.
Die [KeychainBridge](../Sources/OpenDictate/System/KeychainBridge.swift),
Zeilen 45–67, startet je Zugriff einen Prozess und wartet synchron auf dessen
Antwort. Ein kleiner Vorbereitungsbaustein könnte den bereits gelesenen Schlüssel
nur für die aktuelle Operation in einen Options-Snapshot übernehmen. Dadurch
wird zugleich ein klar abgegrenzter Verantwortungsbereich aus `AppDelegate`
herausgelöst. Kein globaler Secret-Cache und kein Umbau der gesamten App nötig.

**Abhängigkeit/Risiko:** Mikrofonfreigabe und Keychain-Dialoge können den Ablauf
unterbrechen. Die bestehenden `AppLifecycle.Operation`-Prüfungen nach jeder
Wartephase und vor dem Start müssen erhalten bleiben. Den Zeitpunkt der
Optionsaufnahme bewusst festlegen; nicht unbemerkt andere Einstellungen lesen.

**Abschlussprüfung:** Start, Retry, fehlender/gesperrter Schlüssel, abgebrochene
Einrichtung und Beenden während einer Freigabe; genau ein Credential-Lesevorgang
pro erfolgreicher Vorbereitung, keine Aufnahme nach veraltetem Callback.
Vorhandene Offline-Nachweise ergänzen; echte Schlüsselbund-/Mikrofonpfade erst
mit passender Freigabe sichtbar prüfen. Keine behauptete Beschleunigung ohne
Vorher-/Nachhermessung.

### C: UI nur gezielt entkoppeln, nicht komplett neu schreiben

[SettingsWindowController.swift](../Sources/OpenDictate/App/SettingsWindowController.swift)
benutzt ein `NSMenu` als Datenmodell: `item` sucht String-IDs, `control(for:)`
kopiert Menüpunkte in Controls, `valueTitle` zerlegt den angezeigten Text am
Doppelpunkt. `refresh` baut das gesamte sichtbare Fenster neu auf und stellt
den Fokus anhand der ID wieder her. Die Verknüpfung mit
[MenuBarController.swift](../Sources/OpenDictate/App/MenuBarController.swift)
ist dadurch von IDs und Beschriftungsformaten abhängig.

Ein kleiner typisierter Einstellungs-Snapshot mit bestehenden Aktionen würde
diese Kopplung entfernen. Das lohnt beim nächsten echten Einstellungsumbau;
es ist kein belegter aktueller Bedienfehler und rechtfertigt keinen Framework-
oder UI-Wechsel. `DictationPanel` enthält außerdem echte UI-Zustände, Layout und
Tastaturbedienung; seine Zeilenzahl allein rechtfertigt keine weitere Zerlegung.

**Abschlussprüfung:** Einstellungen/Aufnahmen/Hilfe, Auswahländerung, kleiner
Fensterumfang, Tab/Shift-Tab, geöffnetes Untermenü während Refresh, Hell/Dunkel
und bestehender Textzustand sichtbar prüfen. Fokus darf bei Refresh nicht
verloren gehen. Vor dieser Änderung keine neue Abstraktionsschicht vorsorglich
einziehen.

## Windows-Bestand vor jeder Zusammenführung sichern

Der gelesene Windows-Pfad liegt unter
`Documents/Codex/2026-09-10/dies-ist-ein-neuer-chat-mit/work/OpenDictate/windows`.
Das umgebende separate OpenDictate-Repository meldet `?? windows/`;
`git ls-files windows` liefert keine Dateien. Außerhalb von `bin/obj` liegen
29 C#- bzw. Projektdateien. Der Prototyp ist damit vorhanden, aber in diesem
Checkout nicht versioniert. Die Plan-/Abnahmeberichte vom September sind keine
heutige Geräteprüfung und binden diesen unversionierten Baum nicht automatisch
an einen nachprüfbaren Commit.

**Empfehlung:** Vor Wiederaufnahme einen separaten, geprüften Quellstand mit
eigenen Abhängigkeiten und reproduzierbaren Checks versionieren. Erst danach
über Integration oder archivierte Prototypteile entscheiden. Nicht einfach den
Ordner löschen, in die Mac-Reduktionsquote aufnehmen oder alles unbesehen in
`main` kopieren. In diesem Auftrag bleibt er lesend geprüft.

## Unabhängiger Erstpass: Linux, Werkzeuge und Website

Der separate Kritiker prüfte lesend dieselbe Ausgangsrevision. Er fand in
Linux, Skripten und Website keinen belegten größeren, funktionsneutralen
Codeschnitt. Ähnliche CI- und Release-Schritte haben unterschiedliche
Prüfverträge und rechtfertigen allein keine Zusammenlegung.

Ein konkreter Dokumentationsfehler betrifft `linux/README.md`: Die Angabe
Rust 1.70+ passt nicht zum vorhandenen Lockdateiformat v4. Die vorhandenen
Linux-Nachweise nennen tatsächlich Rust 1.98.1. Deshalb die geprüfte Version
angeben und eine niedrigere Mindestversion offenlassen, bis sie geprüft ist.
Dies verlangt keine Änderung des Rust-Codes oder der Lockdatei.

Linux Phase 1 bezeichnet einen offline geprüften Kern. Mikrofon bis Anbieter,
physischer Hyprland-Hotkey, Tray/Panel und Packaging bleiben offen; Auto-Insert
gehört zu Phase 2. Die Website ist ein lokaler Entwurf. Ihr Textstand vom
24. September wurde laut `website/README.md` noch nicht erneut visuell
abgenommen. Diese Grenzen gehören in die zentrale Planung und dürfen nicht
als fertige Plattformen oder veröffentlichte Website erscheinen.

Die Reihenfolge Windows → Linux → iOS → Android ist eine datierte Vorgabe aus
dem Windows-Plan vom 12. September. Später vorhandener Linux-Code und der
Ausschluss anderer Plattformen aus dem aktuellen Mac-Produktumfang belegen
keine neue Prioritätsentscheidung. Die Roadmap muss Herkunft und Datum nennen.

## Duplikate mit begrenztem Nutzen einer Zusammenlegung

- Die beiden Debug-Fixtures
  [ProcessingFocusPreview.swift](../Sources/OpenDictate/App/ProcessingFocusPreview.swift)
  (Zeilen 114–126) und
  [DeliveryMatrixPreview.swift](../Sources/OpenDictate/App/DeliveryMatrixPreview.swift)
  (Zeilen 211–223) besitzen denselben Block zum Wiederherstellen der
  Zwischenablage. Ein kleiner `#if DEBUG`-Helfer wäre möglich. Er muss die
  `changeCount`-Prüfung behalten, damit zwischenzeitliche Nutzereingaben nicht
  überschrieben werden. Niedrige Priorität; kein Produktionsframework daraus.
- CI- und Release-Paketbau wiederholen Plist-Auslese und ZIP-Rundlauf. Gemeinsame
  Metadaten-/Archivhilfen sind ein Kandidat; Ad-hoc- und Developer-ID-Prüfregeln
  müssen ausdrücklich getrennt bleiben. Nicht während der noch offenen
  Build-8-Notarisierung umbauen.
- Die Bridge und der dauerhafte Schlüsselbundhelfer wiederholen das kleine
  JSON-Protokoll und Zertifikatsauslesen. Dies ist eine Prozess- und
  Versionsgrenze. Eine gemeinsame Typdatei allein beseitigt nicht die
  Kompatibilitätsanforderung zum bereits installierten Helper. Hier ist
  unbedachtes Zusammenlegen riskanter als wenige doppelte Zeilen.

Exakter SHA-256-Vergleich aller versionierten Dateien fand drei Paare:

| Gleiches Material | Doppelte Bytes | Entscheidung |
| --- | ---: | --- |
| `Assets/OpenDictateIcon.png` / `website/icon.png` | 1.477.612 | Behalten: Website soll eigenständig statisch auslieferbar bleiben. Allenfalls Ableitung/Größenoptimierung beim Website-Paket prüfen. |
| `2026-09-23-quit-race-dialog.png` / `…-second-dialog.png` | 30.911 | Historische Belegrollen und Verweise erst prüfen; kein automatisches Löschen. |
| `2026-09-23-terminal-before.png` / `…-cleared.png` | 24.628 | Gleiche Pixel können zwei Zeitpunkte belegen. Kein Defekt allein durch Hashgleichheit. |

## Was erhalten bleiben sollte

- `OpenDictateCore` importiert ausschließlich Foundation; `Package.swift`
  enthält keine externen Swift-Paketabhängigkeiten. Kein erkennbarer Nutzen
  eines neuen DI-Frameworks oder einer plattformübergreifenden UI-Schicht.
- `DictationFlow` und `AppLifecycle` lösen unterschiedliche Aufgaben: aktive
  Diktate gegenüber Vorbereitung, verschachtelten Dialogen und Beenden. Nicht
  als vermeintlich doppelte Zustandsmaschine zusammenwerfen.
- Authentifizierter Retry, Schutz der letzten Aufnahme, Ablaufprüfung,
  transaktionaler Hotkeywechsel und Zwischenablage-Fallback sind Invarianten.
  Weniger Zeilen sind kein Grund, diese Pfade zu entfernen.
- `KeychainItem.isMissing` und `Settings.resetToEnvironment` sind aktuell
  testseitig verwendet; `.ping` hat keinen gefundenen Bridge-Aufrufer, ist aber
  Bestandteil des versionierten Helper-Protokolls. Als kleine Prüf-/API-Reste
  inventarisieren, nicht allein nach Texttreffern entfernen. AppKit-Delegates
  werden vom Framework aufgerufen und sind trotz einzelner Fundstelle kein
  toter Code.
- Die Swift-Tests wurden am 24./25. September bereits gezielt reduziert.
  [Testsignal-Audit](test-signal-audit.md) und
  [Messung](test-audit-2026-09-25/README.md) begründen die verbleibenden Pfade.
  Aktuell sind 109 Deklarationen vorhanden; die frische
  [Baseline](code-reduction-2026-09-28.md) reproduziert die damalige Coverage
  mit unveränderten Quell- und Testdateien. Keine weitere
  pauschale Prozentvorgabe zur Testlöschung ableiten.
- Debug-Vorschauen sind durch `#if DEBUG` abgegrenzt und dienen wiederholbaren
  Prüfungen. Nicht mit ausgelieferten Produktfunktionen verwechseln.
- Alte App-/Recovery-Daten, Build-8-Artefakte, Git-Worktrees und externe
  Windows-Arbeitskopien sind keine genehmigte Löschliste.

## Nachweisgrenzen

Inventar, exakte Dateiduplikate, Referenzen und lokale Markdown-Dateiziele wurden
direkt geprüft. In der Ausgangsrevision wurden keine fehlenden relativen
Markdown-Dateiziele gefunden; das prüft keine externen Webseiten oder sämtliche
Anker. Die Codelektüre konzentriert sich auf die benannten Verantwortlichkeiten
und Risiken, sie ist kein formaler Beweis, dass jede Zeile fehlerfrei ist.
Offline-Testprogramme und Builds wurden auf Mac, Linux und Windows ausgeführt;
keine Produkt-App wurde neu gestartet oder installiert. Es gab keine Aufnahme,
Provideranfrage, Zugangsdatenänderung oder Veröffentlichung. Entfernt wurde nur
der belegte unbenutzte Farbhelfer. Größere Refactorings und Assetlöschungen
wurden nicht umgesetzt; die gewünschte 10–25%-Codekürzung blieb unerreicht.
