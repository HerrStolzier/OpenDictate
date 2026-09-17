# Roadmap-Abnahme — 2026-09-17

## Stand und Aussagegrenze

Abnahmestand auf `codex/acceptance-completion`, Codecommits `0cd686c`
(Brave-Korrektur) und `8c65e35` (Prüfmittel). Installiert ist die mit
`OpenDictate Self-Signed` signierte Binärdatei mit SHA-256
`134fcef15fe9da51d636a3b9cd3bf414d7714246de96d65e6bb0a169bdac961b`;
Hardened Runtime und Audio-Entitlement sind geprüft. Dieser Bericht ist keine
Freigabe zur Veröffentlichung und keine
abgeschlossene Produktabnahme. Der aktuelle Restumfang steht in
[remaining-acceptance](remaining-acceptance.md), die Abnahmekriterien in der
[Kompatibilitätsmatrix](compatibility-matrix.md).

## Sichtbar geprüfte synthetische Übergabe

Die folgenden Versuche verwenden künstlichen Text und den Produktionseinfüger,
keine Mikrofonaufnahme und keinen Providerrequest.

| Fall | Nachweis und Grenze |
|---|---|
| Brave-Langtext vor Korrektur | Bei 600 Wiederholungen wurden statt 28.199 nur 27.154 UTF-16-Einheiten eingefügt; 1.419 Chunks. Die Reproduktion belegt Textverlust, keinen reinen Anzeigefehler. |
| Brave-Langtext nach Korrektur | Die Brave-spezifische `trailing`-Policy bindet Zeilenumbrüche an vorausgehenden Text. Der vollständige Feldvergleich stimmt exakt mit 28.199 UTF-16-Einheiten überein; 1.500 Chunks. Dies belegt diesen Langtextfall, keine allgemeine Browserkompatibilität. |
| Kurzer Brave-LF-Text | Nach ungestörter Vorbereitung exakt 46 UTF-16-Einheiten in 3 Chunks. |
| Brave-CRLF und Leerzeilen | Exakt 21 DOM-normalisierte UTF-16-Einheiten in 2 Chunks; keine zusätzliche CR-Normalisierung im Produktionscode erforderlich. |
| Native Felder A → B während simulierter Aufnahme | Während zehn Sekunden synthetischer Aufnahme wurde das Feld gewechselt. Beide Felder blieben unverändert; vollständiger Text blieb auf der isolierten Testzwischenablage. Dies prüft Zielbindung in der Aufnahmephase ohne echten Mikrofonbetrieb. |

Safari behält seine isolierten Zeilenumbruch-Events; Obsidian behält gruppierte
Events. Die Korrektur erweitert keine allgemeine Browser- oder Electron-Zusage.
Die kurzen LF-/CRLF-Fälle bestanden nach einer fünfminütigen Nutzerpause und
ungestörter GUI-Prüfung. Frühere kurze Versuche waren durch gleichzeitige
UI-Bedienung beeinflusst und werden weder als Fehler noch als Erfolg gewertet.

Die lokale HTML-Fixture kann aus bestehendem Feldinhalt, Cursor und Auswahl eine
vollständige Referenz bilden und das Ergebnis exakt vergleichen. Ihr Vergleich
deckt `input`, `textarea` und das eingebettete `textarea` ab, kein
`contenteditable`. Für das einzeilige Feld ist die einzeilige Probe zu verwenden.

## Ergänzte Offline-Prüfmittel

- Drei Lifecycle-Tests prüfen Abbruch während eines laufenden Uploads: erfolgreiche
  Recovery, fehlgeschlagene Recovery mit Erhalt des Originals sowie ausdrückliches
  Verwerfen. Das sind kontrollierte Flow-Operationen, keine echten Uploads.
- Der Offline-Transkriptauswerter hat fünf Tests. Er vergleicht vorgegebene
  Referenzen und Transkripte, berechnet WER und erfasst fehlende erwartete Begriffe
  sowie vorhandene Messwerte. Er erzeugt keinen Sprachqualitätsnachweis aus
  künstlichen Referenzdaten; Details: [Audioqualität](audio-quality-fixtures.md).
- Der Ressourcensampler hat drei Tests. Er ist für eine ausdrücklich ausgewählte
  Prozessidentität vorgesehen. CPU-Zeit und abgetastetes RSS belegen weder
  Energieverbrauch noch eine lückenlose RAM-Spitze oder Langzeitstabilität.

Bestanden: 134 Swift-Tests (65 System-, 69 Core-Tests; vier Opt-in-Prüfungen
übersprungen), acht Python-Tests sowie Format-, Shell-, Diff- und Bundleprüfungen.
Der nötige CLT-TestingMacros-Prüfaufruf ist in [CHECKS](../CHECKS.md) dokumentiert.

Die installierte App wurde im Leerlauf 60,025707 Sekunden gemessen: CPU-Zuwachs
0,01 Sekunden, entsprechend 0,017 Prozent, maximal abgetastetes RSS 103.328 KiB.
Das ist ein begrenzter Leerlaufbefund, keine Energie- oder Belastungsmessung.
Ein weiteres Messfenster von 180,023078 Sekunden umfasste Leerlauf, den ersten
Live-Versuch und den Anfang der 90-Sekunden-Aufnahme: CPU-Zuwachs 3,55 Sekunden
(1,972 Prozent), maximal abgetastetes RSS 119.776 KiB. Es umfasst nicht die gesamte
90-Sekunden-Aufnahme und ist kein isolierter Aufnahmebenchmark.

## Begrenzte Live-Abnahme

Für diesen Auftrag ist eine begrenzte Mikrofon-/Providerprüfung mit höchstens
sechs Aufnahmen/sechs Uploads und insgesamt höchstens 240 Sekunden Testaudio autorisiert,
einschließlich einer 90-Sekunden-Aufnahme. Lautsprecherausgabe der erzeugten
Referenz und nötige Lautstärkeanpassung sind Teil dieses konkreten Testumfangs.
Die Referenz lautet:

> Dies ist ein kurzer Test. Bitte schreibe die Zahl sieben und das Wort Apfel.

Abgeschlossen: **sechs Aufnahmen und sechs OpenAI-Uploads**, konservativ höchstens
210 Sekunden Aufnahmezeit (`40 + 90 + 4 × 20`). Die kurzen Aufnahmedauern wurden
nicht exakt gemessen; Trimming verkürzt gegebenenfalls die Uploads. Die Anzahl
der freigegebenen Versuche ist ausgeschöpft; weitere Uploads sind nicht autorisiert.

| Fall | Sichtbares Ergebnis | Request / instrumentiert Stopp bis Ergebnis |
|---|---|---|
| 1: beabsichtigter nativer Testhost | Referenz exakt transkribiert; Zielprüfung lehnt fehlendes/geschütztes/geändertes Ziel ab, vollständiger manueller Rückweg. Keine native Einfügung. Peak −29 dB, Mittel −45 dB. | 2.265,45 / 2.302,32 ms |
| 2: Brave `textarea`, 90 Sekunden | Automatischer Aufnahmestopp bestanden. Zustand bei 66 Sekunden und Countdown bei 85 Sekunden („Noch 5 s“) gesehen; ohne Stoppaktion folgt das Ergebnis. App-Transkript und automatisch eingefügter Feldinhalt exakt gleich: 329 UTF-16-Einheiten. | 1.971,07 / 2.187,03 ms |
| 3: Brave `input` | Referenzwortlaut automatisch eingefügt; Komma und kleingeschriebenes „bitte“ statt der Referenzinterpunktion. | 1.057,68 / 1.119,49 ms |
| 4: Brave `contenteditable` | Referenzwortlaut automatisch eingefügt, gleiche Interpunktions-/Großschreibungsabweichung wie Fall 3. | 850,78 / 916,71 ms |
| 5: Brave iframe | Referenzwortlaut automatisch eingefügt, gleiche Interpunktions-/Großschreibungsabweichung wie Fall 3. | 1.099,49 / 1.165,67 ms |
| 6: beabsichtigter nativer Testhost, tatsächlich Brave iframe | Die GUI-Steuerung aktualisierte den nativen AX-Kontext, wechselte jedoch nicht die von `NSWorkspace` erfasste Vordergrund-App. Das Transkript wurde korrekt ans bestehende Brave-iframe-Ende angehängt; nativer Host unverändert. Kein nativer E2E-Nachweis und kein belegter Produktfehler der Zielbindung. | 749,47 / 815,27 ms |

In den Fällen 2–5 wurde jeweils die vollständige bestehende Feldauswahl ohne
manuelles Einfügen ersetzt: Lautsprecher → JBL-Stream-Mikrofon → Provider →
sichtbare automatische Zielübergabe ist für diese vier Brave-Feldtypen belegt.
Das 90-Sekunden-Ergebnis enthält vier vollständige Testsätze und einen
abgeschnittenen fünften Anfang („Dies ist ein kurzer …“), weil die Wiedergabe
versetzt startete. Daraus wird keine WER abgeleitet.

Die Offline-Auswertung der fünf kurzen Aufnahmen mit dem festgelegten,
interpunktionsunabhängigen WER-Verfahren ergibt 70 Referenzwörter, null
Substitutionen/Löschungen/Einfügungen und WER 0. „Apfel“ und „sieben“ sind jeweils
in allen fünf Fällen vorhanden. Die Quelle ist synthetisierte Sprache über
Lautsprecher und echtes Mikrofon, kein menschlicher Sprachkorpus. Korrekturzeit
und Zeit bis zum ersten sichtbaren Text wurden nicht gemessen. Die obigen
Logzeiten sind instrumentierte Stopp-bis-Ergebnis-Werte, keine gemessene visuelle
Latenz; die Zeitfelder des Evaluators bleiben in allen fünf Fällen `null`.
Der GUI-Tastaturversuch mit Option+Shift+Space erzeugte ein geschütztes
Leerzeichen statt des globalen Shortcuts; eine menschliche physische
Hotkey-Bestätigung liegt für diesen Kandidaten nicht vor.

## Integrität und Bereinigung

Das für die Tests geschützt umbenannte ursprüngliche Recoveryverzeichnis ist
wiederhergestellt: beide ursprünglichen Dateien stimmen in Hash und Dateimodus
exakt überein, keine neuen Recoverydateien vorhanden. Der Präferenzhash blieb
unverändert. Lautstärke ist von temporär 75 Prozent auf die neue Nutzerbaseline
62,5 Prozent zurückgestellt, nicht stummgeschaltet. Systemeinstellungen
(Allgemein) und Finder (Downloads) sind wiederhergestellt. Das eigene Brave-
Testfenster ist geschlossen, das Nutzerfenster erhalten; tägliche App,
Matrix-Fixture, nativer Host und Audioplayer sind beendet.

Erzeugte Referenztext-/AIFF-/WAV-Dateien einschließlich der 90-Sekunden-WAV-Datei
und eigene temporäre Fixture-/Host-Bundles sind entfernt. Im Zeitfenster der
Live-Abnahme verbleiben keine `opendictate`-Tempaufnahmen. Dauerhafte lokale
Backups und Prüfevidenz bleiben privat beziehungsweise im ignorierten
`.build`-Verzeichnis. Git-Abschluss wird getrennt festgehalten; dieser Bericht
behauptet keinen PR, Merge oder öffentlichen Release.

## Verbleibende Produktgrenzen

1. Reale Mikrofon-/Provider-/Zielabnahme für native Felder, Safari und Electron
   sowie verbleibende Feld-/Fokusphasen der Kompatibilitätsmatrix schließen.
   Vier bestandene Brave-Feldtypen ersetzen nicht jede Zelle; die physische
   Hotkey-Bedienung bleibt gesondert zu bestätigen.
2. Physische Gerätewechsel/Abziehen und reale Berechtigungs-/Keychainfehler sowie
   Beenden während echter Aufnahme/Transkription bleiben eigene Abnahmefälle.
   Kontrollierte Offline-Fehler beweisen diese Hardware-/Systemfälle nicht.
3. Gehörte VoiceOver-Ausgabe für Zustand, Countdown und Abbrechen/Verwerfen bleibt
   offen. AX-Ereignisse oder ein ausgelesener Accessibility-Baum genügen nicht.
4. Ein menschlicher Referenzkorpus mit leiser/kurzer Sprache, Namen, Zahlen,
   Sprachwechseln, Geräuschen und Mikrofonvarianten sowie gemessenem Korrekturaufwand
   bleibt erforderlich. Die begrenzte erzeugte Referenz deckt ihn nicht ab.
5. Ressourcenmessungen müssen ihren konkreten Zeitraum und Workload nennen.
   Energie, Spitzen zwischen RSS-Stichproben und langfristiges Speicherwachstum
   bleiben ohne zusätzliche geeignete Messungen unbekannt.

Streaming, Hold-to-talk und die Behandlung alter Crash-Aufnahmen bleiben
zurückgestellte Erweiterungen. Andere Betriebssysteme, Notarisierung und
öffentliche App-/Website-Veröffentlichung sind keine abgeschlossenen oder durch
diesen Testauftrag neu freigegebenen Schritte.
