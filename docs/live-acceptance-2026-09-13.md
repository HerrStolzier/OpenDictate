# Native Abnahme am 13. September 2026

Geprüfte Fassung: lokale Release-Testkopie `/private/tmp/OpenDictate-Livetest.app`, gleicher Quellstand und gleiche Ad-hoc-Signatur wie der zuvor gebaute Kandidat. Keine Neu-Kompilierung bei der Freigabereparatur.

## Nachweise

- Basti bestätigte den Statuswechsel während echten Diktierens. Sein Screenshot von 21:27 zeigt den diktierten Testsatz im aktiven TextEdit-Feld und die passive OpenDictate-Anzeige „Übergabe nicht bestätigt“. Anschließend wurde derselbe Text über die native Accessibility-Oberfläche von TextEdit direkt nachgewiesen. Das ist ein erfolgreicher, benutzergeführter Diktierdurchlauf; keine allgemeine Qualitätsaussage.
- Der zunächst blockierte Durchlauf meldete `accessibility=false` bei korrekt erkanntem Ziel TextEdit. LLDB bestätigte zunächst `AXIsProcessTrusted() == false`. Nach gezieltem Reset ausschließlich für `local.opendictate.app` und erneuter Registrierung bestätigte dieselbe laufende App `true`. Beide Debugger-Sitzungen wurden getrennt.
- Zwei echte kurze Aufnahmen wurden durch den Agenten über die Hauptaktion gestartet und jeweils über „Abbrechen“ beendet. Die Oberfläche wechselte von „Aufnahme läuft“ auf Bereitschaft und „Aufnahme für Wiederholung gesichert“. Es wurde keine Verarbeitung angefordert.
- Während der zweiten Aufnahme wechselte die Bedienung zu einem separat geöffneten TextEdit-Testdokument. Künstlicher Testtext konnte eingegeben werden. Nach Abbruch blieb er unverändert. Dies prüft Fokuswechsel während Aufnahme plus Abbruch, nicht den Fokuswechsel während laufender Transkription.
- Die native Einstellungsansicht zeigte „Automatisch einfügen“ aktiviert, Aufnahme starten verfügbar und die Abbruchaktionen im Leerlauf gesperrt.
- „Letzte Aufnahme wiederholen“ öffnete die Bestätigung zur zuletzt abgebrochenen Aufnahme. Erneuter Versand, mögliche Kosten und Ausgabe nur zum Kopieren wurden angezeigt. „Erneut verarbeiten“ wurde nicht bestätigt.
- Das durch Computer Use gesendete globale Tastenkürzel löste in diesem Durchlauf keine Aufnahme aus; es erreichte TextEdit als Leerzeichen. Die folgenden Agentenprüfungen verwendeten deshalb die native Hauptaktion. Der zuvor von Basti ausgeführte Hotkey-Durchlauf bleibt der Nachweis des echten Tastenkürzels.

## Nächste Prüfungen für vollständige Abnahme

- Wechsel in eine andere App während laufender Transkription: konservatives Nicht-Einfügen am tatsächlichen Endpunkt prüfen. Der Code prüft den Vordergrundprozess vor dem Einfügebefehl; die oben durchgeführte Fokus-/Abbruchprüfung ersetzt diese Prüfung nicht.
- VoiceOver mit hörbarer Sprachausgabe prüfen. Die vorhandenen Accessibility-Beschriftungen allein belegen diese Abnahme nicht.
- Für dauerhafte Nutzung einen festen App-Pfad und eine verfügbare stabile Signieridentität festlegen. Die aktuelle Testfassung liegt temporär; die installierte alte App wurde nicht ersetzt. Der gezielte Freigabe-Reset betraf die gemeinsame Bundle-ID.

Keine erneute pauschale Testserie: Der Quellstand blieb unverändert und seine 99 Offline-Tests waren bereits bestanden. Die zwei Abbruchaufnahmen bleiben entsprechend der Produktschutzregel erhalten; sie wurden weder hochgeladen noch zur Bereinigung gelöscht.

## Nachtrag: feste Alltagsfassung und Bedienprüfung

Die installierte Benutzer-App wurde inzwischen bewusst aktualisiert. Frühere
Aussagen oben zur nicht ersetzten App beziehen sich auf die damaligen Schritte.

- Fester Startort: `/Users/basti/Applications/OpenDictate.app`. Sicherung der vorherigen
  Fassung: `outputs/backups/OpenDictate-vor-Alltagsfassung.app` im Aufgabenordner.
  Die regulären Dateien der Sicherung wurden vor dem Austausch byteweise geprüft.
- Installiertes Release-Programm SHA-256:
  `61ceb48ca7c224ac8045bed97cfa7406c29dd56c840f3e9ed22354a01576c806`.
  Build und installierte ausführbare Datei stimmten überein; strikte Bundle-Signaturprüfung bestand.
- Expliziter Start zeigt das Tagesfenster und fokussiert die Hauptaktion. Der Run-Weg
  verwendet die vorhandene Instanz und verhindert parallele Tages-/Vorschaufassungen.
- Mikrofon: direkter Status `authorized` (3), reale Aufnahme und erhaltender Abbruch
  über die sichtbare Alltagsoberfläche bestätigt. Kein Versand dieser Testaufnahmen.
- Einfügefreigabe: im laufenden installierten Prozess zunächst `AXIsProcessTrusted == false`;
  nach gezielter Erneuerung derselben App-Zuordnung `true`. Debugger jeweils getrennt.
- VoiceOver wurde in den Systemeinstellungen als eingeschaltet nachgewiesen. Bei
  eingeschaltetem VoiceOver führten Tab und Control+Option+Leertaste in der Tagesansicht
  zu Einstellungen, Aufnahme und Abbruch. Die sichtbaren Zustandswechsel wurden gelesen.
  Anschließend wurde der Schalter als ausgeschaltet nachgewiesen und die Hilfsprogramme
  geschlossen. Dies ist eine praktische Bedienprüfung bei aktivem VoiceOver; hörbare
  Ausgabe, deren genaue Formulierung und reine VoiceOver-Cursor-Navigation sind damit
  nicht vollständig abgenommen. Die Audioausgabe war dem Agenten nicht zugänglich.
- Neue Ergebnisformulierung: „Diktat verarbeitet.“ mit „Automatisches Einfügen wurde
  ausgelöst. Prüfe den Text im Zielprogramm.“ Keine behauptete Zielbestätigung.
- 99 Offline-Tests nach Ergänzung der ausschließlich in Debug verfügbaren
  Verarbeitungstesthilfe bestanden; Formatierung, Shell-Syntax und Whitespace geprüft.

### Nächste konkrete Prüfhandlung

Den vorbereiteten `--processing-focus-preview` mit fester synthetischer Transkription
und echter Einfügelogik in einem eigenen leeren TextEdit-Dokument durchführen:
Ziel einmal beibehalten, einmal während der Verarbeitung verlassen. Die vorhandene
Vorschau-Freigabe benötigt aktuell die macOS-Authentifizierung. Noch kein erfolgreicher
Verarbeitungs-/Einfüge-Durchlauf dieser neuen Hilfe behauptet. Die Alltagsfassung ist
für diesen isolierten Test geschlossen, ihr finaler Build bleibt unverändert.

Zusätzlicher Live-Nachweis des Startschutzes: Während die einzige Vorschauinstanz
lief, verweigerte `--daily` den Start mit Exit 1 und dem Hinweis auf die laufende
andere Fassung. Es wurde dadurch keine zweite App gestartet.

## Abschluss der drei lokalen Arbeitspunkte · 13. September 2026

### Ergebnisformulierung

Die native Vorschau zeigt jetzt tatsächlich „Diktat verarbeitet.“ in neutralem Blau
mit „Automatisches Einfügen wurde ausgelöst. Prüfe den Text im Zielprogramm.“
Der Button „Text ansehen“ ist fokussierbar. Darstellung und Accessibility-Text wurden
gemeinsam kontrolliert. Der Produktionsflow liefert weiterhin `deliveryUnconfirmed`,
keine erfundene Einfügebestätigung.

### Fokuswechsel während Verarbeitung

Die ausschließlich in Debug verfügbare Hilfe wurde als identische, signaturgeprüfte
Kopie unter `/private/tmp/OpenDictate-ProcessingTest.app` gestartet. Ihre bereits
bestehende Vorschau-Berechtigung wurde erneuert; der laufende Prozess bestätigte
`AXIsProcessTrusted == true`. Alltagsfassung und Testkopie liefen nie parallel.

Geprüft wurden echte `DictationFlow`, `DictationPanel` und `PasteboardInserter`, mit
fester synthetischer Transkription und 20 Sekunden Verarbeitungszeit. Kein Mikrofon,
kein Provideraufruf und kein Zugriff auf vorhandene Aufnahmen in dieser Hilfe.

- **Ziel beibehalten:** Verarbeitung startete erst nach tatsächlich erkanntem TextEdit
  im Vordergrund. Der Testtext erschien genau einmal hinter dem vorhandenen Testsatz.
  Ergebnis `deliveryUnconfirmed`, ursprüngliches Ziel weiterhin aktiv (`true`).
  Die passive Statusanzeige entzog TextEdit den Vordergrund nicht.
- **Ziel während Verarbeitung verlassen:** Nach Beginn derselben Verarbeitung wurde
  zur bereits laufenden Test-App gewechselt. Ergebnis `textAvailable`, ursprüngliches
  Ziel nicht mehr aktiv (`false`). TextEdit erhielt keinen zweiten Testzusatz. Das
  Protokoll vom 13.09.2026, 20:21:54 UTC bestätigt konkret `Auto-paste skipped: user
  changed the foreground application`; fehlende Rechte sind damit nicht die Erklärung.
- Der einzige eingefügte Testzusatz wurde anschließend gezielt ausgewählt und entfernt.
  Der ursprüngliche Testsatz war danach wieder unverändert im bestehenden Dokument.
  Ein vorher angelegtes zusätzliches leeres TextEdit-Fenster wurde auf Bastis Hinweis
  geschlossen und für den eigentlichen Durchlauf nicht wieder geöffnet.

Frühere erfolglose Starts der Hilfe warteten auf einen echten Vordergrundwechsel.
Hintergrundbedienung durch das UI-Werkzeug allein löste ihn nicht aus. Der normale
macOS-Aufruf der bereits laufenden Apps ermöglichte den tatsächlichen Wechsel, ohne
neue Instanz oder Dokument. Die beiden erfolgreichen Durchläufe dauerten laut
Phasenprotokoll etwa 20,6 bzw. 20,8 Sekunden.

**Prüfumfang:** E2E der Oberfläche, Zustandsmaschine und tatsächlichen Textübergabe
mit synthetischer Transkription. Keine neue Behauptung über Mikrofon-/Providerqualität.
Der frühere benutzergeführte echte Diktierdurchlauf bleibt separat dokumentiert.

### VoiceOver und dauerhafter Start

Die oben dokumentierte praktische Tastaturbedienung bei aktiviertem VoiceOver
(Einstellungen, Aufnahme, Abbruch) ist durchgeführt. Die genaue hörbare Ausgabe
und reine VoiceOver-Cursor-Navigation wurden vom Agenten nicht vollständig beobachtet;
dies ist ausdrücklich keine vollständige Barrierefreiheitszertifizierung.

Die feste Alltagsfassung wurde abschließend zweimal über `--daily` aufgerufen:
beide Aufrufe verwendeten dieselbe Prozess-ID. Nach diesem Neustart waren in der
App weiterhin Accessibility `true` und Mikrofonstatus `authorized` (3) nachgewiesen.
Die strikte Signaturprüfung bestand; der oben genannte Release-Hash blieb unverändert.
Die zusätzliche Verarbeitungshilfe ist vollständig durch `#if DEBUG` abgeschirmt.

### Bereinigung und Übergabe

Alle OpenDictate-Testinstanzen, die Alltagsinstanz nach ihrem Abschlusscheck,
Systemeinstellungen, VoiceOver, VoiceOver-Einführung, Dienstprogramm und Debugger
sind beendet. Abschließende Prozessprüfung zeigte davon ausschließlich die vorherige
TextEdit-App; ihr vorhandenes Dokument bleibt erhalten. Testaufnahmen wurden gemäß
Produktschutzregel aufbewahrt. Keine Veröffentlichung, kein Commit und kein Push.

Die lokale Umsetzung der drei Arbeitspunkte ist abgeschlossen; obige Prüfumfänge
und Grenzen bleiben Teil des Ergebnisses.
