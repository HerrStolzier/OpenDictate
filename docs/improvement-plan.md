# OpenDictate: Umsetzungs- und Abnahmeplan

Stand: 2026-09-06. Ausgangspunkt: Commit 6b4c6d74011212b44ec5547f6fb7bc06d1e5cfa3, sauberer Arbeitsbaum, 72 Tests in 11 Suites bestanden.

## Auftrag und Grenzen

Alle 30 Reviewpunkte werden in der untenstehenden Reihenfolge bearbeitet. Ziel ist ein zuverlässiger Diktierablauf mit wiederherstellbaren Ergebnissen, sichtbarem Aufnahmezustand und belegten statt vermuteten Optimierungen. Umsetzung und lokale Tests sind autorisiert. Keine Commits, Pushes, Installation, Aktivierung, Veröffentlichung oder Änderung von Zugangsdaten. Live-Mikrofon-, Zielapp- und kostenpflichtige API-Abnahmen sind gesondert auszuweisen. Ein experimenteller Kandidat gilt auch dann als bearbeitet, wenn Messungen gegen eine Umsetzung sprechen; Gründe und Evidenz werden dokumentiert. Keine pauschale Zusage zu Geschwindigkeit, Kosten oder Erkennungsqualität.

## Reihenfolge

1. Zuverlässigkeit: Punkte 1–8, begleitet von 27.
2. Sichtbarer Zustand und Wiederherstellung: 17–23, einschließlich 13 und Abschluss der zugehörigen Ablaufprüfungen.
3. Messgrundlage: 28–29; anschließende Optimierung 9–16.
4. Komfort und Erkennungsqualität: 24–26, einschließlich freier Hotkeys und deutscher/barrierefreier UI aus 25.
5. Abschluss: 30, vollständige Regression, Release-Build, Dokumentationsabgleich und unabhängige Diff-Prüfung.

## Phase A – Zuverlässigkeit

| Punkt | Umsetzung | Abnahme |
|---|---|---|
| 1 | Aufnahme/Verarbeitung/Übergabe durch eindeutige Zustände koordinieren; Retry während Aufnahme sperren; Stop-Timer nur beim wirklichen Stop beenden. | Retry während Aufnahme, mehrfacher Stop und automatischer Stop sind deterministisch getestet; keine überschriebene Zielapp. |
| 2 | Textübergabe liefert ein Ergebnis; leere Antwort und Clipboard-Fehler erhalten Recovery; letzten gültigen Text vor Übergabe sichern. | Kein Löschen der Retry-Aufnahme bei leerer Antwort oder nicht gesichertem Text; erneutes Kopieren möglich. |
| 3 | Unsichere/kurze Aufnahmen für bewussten Retry erhalten; keine automatische Übertragung von als still eingestuften Aufnahmen. | Kurzes Wort, leise Sprache und digitale Stille durch Fixtures abgedeckt; verständlicher Status und manuelle Wiederholung. |
| 4 | Modellabhängige Sprachparameter und Antwortverarbeitung; bekannte ungeeignete Modelle vor Aufnahme blockieren. | Offline-Requesttests gegen aktuelle dokumentierte Verträge; gültige/leere/fehlerhafte Antworten getestet. Live-API-Verifikation separat. |
| 5 | Hotkey transaktional ersetzen und erst nach Erfolg speichern. | Kollision erhält alten Hotkey und gespeicherte Wahl; echter Carbon-Konflikttest nur isoliert ohne Nutzerhotkeys. |
| 6 | Verwaltete Tasks, Abbruchaktion, Recorderfehler und kontrolliertes App-Ende. | Abbruch in Aufnahme, Vorverarbeitung, Anfrage und Übergabe; Audio bleibt entsprechend expliziter Verwerfen-/Behalten-Semantik verfügbar. |
| 7 | Temporäre Artefakte haben eindeutige Eigentümer; lokale Fehlerbereinigung und begrenzte Behandlung von Absturzresten. | Fehlgeschlagener Start/Export und Abbruch hinterlassen keine unzugeordneten neuen Artefakte; fremde Dateien bleiben unangetastet. |
| 8 | Ablaufzeit bei Zugriff prüfen und während App-Laufzeit bereinigen. | Uhr-injizierte Tests unmittelbar vor/an/nach 24 Stunden; keine abgelaufenen Retry-Angebote. |
| 27 | Kleine austauschbare Schnittstellen für Aufnahme, Transkription, Textübergabe und Recovery, soweit für Ablaufprüfungen nötig. | Integrationstests der obigen Fehlerpfade; vorhandene Tests bestehen; keine unnötige Framework-Abhängigkeit. |

## Phase B – Aufnahmefeedback und Wiederherstellung

| Punkt | Umsetzung | Abnahme |
|---|---|---|
| 17 | Unterschiedliche Menüleistensymbole, sichtbare Zeit und zugänglicher Zustandsname; optionales nicht fokussierendes Statusfenster nur bei konkretem Nutzen. | Aufnahme und Verarbeitung ohne Menüöffnung unterscheidbar; Fokus bleibt im Zielprogramm. |
| 18 | Countdown vor 90-Sekunden-Limit; feste Grenze zunächst erhalten. | Warnung und Stop mit kontrollierter Zeit getestet; Live-Signal separat prüfen. |
| 19 | Berechtigungsstatus, Eingabegerät und gemessener Pegel; sachliche Hinweise statt pauschaler Bluetooth-Ursache. | Verweigertes Mikrofon, fehlendes Gerät und niedriger Pegel unterscheidbar; keine Aufnahme ohne Nutzeraktion. |
| 13 | Metering für sparsames Aufnahmefeedback nutzen und außerhalb aktiver Aufnahme stoppen. | Kein dauerhaft laufender Pegeltimer im Leerlauf. |
| 20 | Auto-Paste versus nur Kopieren; bei zwischenzeitlichem App-Wechsel konservativer Clipboard-Fallback. | App-Wechsel, geschlossene Zielapp und fehlende Accessibility führen nicht zu ungewolltem Fokuswechsel. |
| 21 | Letzten Text nur im Arbeitsspeicher halten, erneut kopieren und löschen können. | Clipboard-Überschreiben erfordert keinen neuen Upload; nach Neustart kein dauerhafter Textverlauf. |
| 22 | Einzelne Recovery-Aufnahmen mit Datum/Dauer und Wiederholen/Löschen anbieten. | Ältere Aufnahme gezielt wiederholbar; Einzellöschung beeinflusst andere Aufnahmen nicht; unbekannte Daten nie uploaden. |
| 23 | Routinefehler nichtmodal als Status mit passender Aktion; Dialoge nur für Entscheidungen. | Wiederholte fehlende Berechtigung blockiert Diktierablauf nicht mit Dialogserien. |

## Phase C – Messen und optimieren

| Punkt | Umsetzung/Entscheidung | Abnahme |
|---|---|---|
| 28 | Reproduzierbares Offline-Audio-Testset für Stille, Pegel, kurze Signale, Trimmränder; gesondertes reales Sprachset mit Transkript und Einwilligung für WER/Korrekturaufwand. | Synthetische Tests nicht als Sprachqualitätsbeweis deklarieren. Reale Sprach-/Providerabnahme nur mit geeigneten Daten/Freigaben. |
| 29 | Phasenlaufzeiten und Gesamtzeit instrumentieren; reproduzierbaren lokalen Benchmark bereitstellen. | Gleiche Fixtures, Release-Build, mehrere Wiederholungen; Median und Streuung; keine Text-/Audiodaten im Messlog. |
| 9 | Menüzustand asynchron aus Metadaten/Verfügbarkeit aktualisieren; Authentifizierung bleibt am Upload. | Menü benötigt keine vollständigen synchronen Audio-Reads; veränderte Dateien werden beim Retry erneut geprüft. |
| 10 | Neueste Kandidaten sortiert prüfen, erster gültiger Treffer; keine Sammlung aller Payloads. | Ungültiger neuester Kandidat fällt auf nächsten gültigen zurück; maximal ein Ergebnis wird gehalten. |
| 11 | Aktuelle Trimmschwelle gegen konservativere Varianten messen; nur mit begründetem Nutzen ändern. | Exportkosten und Dateiersparnis dokumentiert; keine erfundenen Netzwerk-/Kosteneinsparungen. |
| 12 | Sample-Schleife gegen native Vektoroperationen prüfen; Echtzeitanalyse nur bei belegtem Bedarf. | Numerische Gleichwertigkeit, Trimmränder und Release-Benchmark; unnötigen Umbau ablehnen. |
| 14 | Serielles begrenztes Logging mit wiederverwendeter Formatierung. | Parallelzugriffe, Rotation und Fehlerpfad getestet; UI wartet nicht auf Dateischreiben. |
| 15 | Speicherbedarf bei regulären 90-Sekunden-Dateien messen; Datei-Upload nur bei relevantem Bedarf. | Entscheidung samt Messung dokumentiert; keine zusätzliche Komplexität für unerheblichen Bedarf. |
| 16 | Explizite Request-/Gesamtzeitlimits, Offline-/Timeout-/HTTP-Fehler, bewusstes Retry. | URLProtocol-Tests; keine automatische Wiederholung von möglicherweise bereits verarbeiteten Anfragen. |

## Phase D – Komfort

| Punkt | Umsetzung/Entscheidung | Abnahme |
|---|---|---|
| 24 | Einstellbares Vokabular mit Validierung und modellabhängigen Hinweisen; dauerhafte lokale Einstellung. | Requesttests für Sonderzeichen/Längen; reale Qualitätswirkung gesondert messen. |
| 25 | Deutsche UI und zugängliche Beschriftungen; freie Shortcuts mit sicherer Validierung und Konfliktbehandlung. Gedrückthalten-Modus nur mit sauberem Press/Release-Vertrag. | Tastaturbedienung, persistierte Wahl, Konflikt-Rollback; VoiceOver und Hardwareverhalten separat abnehmen. |
| 26 | Streaming-Vorschau als kontrollierten Kandidaten evaluieren; fertigen Text nur einmal übergeben. | Offline-Eventtests für geteilte Events, Abbruch, Fehler, finale Antwort; Zeit bis Ersttext live nur separat messen. Nicht ungeprüft als Standard aktivieren. |

## Phase E – Abschluss

| Punkt | Umsetzung | Abnahme |
|---|---|---|
| 30 | CI für Swift-Tests und Release-Build, nachvollziehbare Versionierung, Bundle-/Signaturprüfung und Dokumentationsabgleich. | Lokale Checks bestanden; Workflow statisch geprüft. GitHub-Lauf, öffentliche Distribution, Notarisierung und Installation bleiben ohne Freigabe offen. |

## Gesamt-Abnahme

- Jeder Punkt hat Ergebnis, Evidenz und Status: umgesetzt / begründet nicht geändert / experimentell geprüft / konkrete externe Abnahme offen.
- Bestehende und neue sinnvolle Tests sowie Release-Build bestehen.
- Gesamtdiff auf Datenverlust, Parallelität, Fokus, Datenschutz und Umfang geprüft.
- Keine Audio-/Textinhalte in Logs; keine impliziten neuen Provideraufrufe.
- Keine Nutzeränderungen überschrieben und keine Installation/Veröffentlichung.
- Abschlussbericht benennt konkret, was nur offline geprüft ist.

## Arbeitsstand

Die lokale Umsetzung und ihre Grenzen sind in der abschließenden Statustabelle dokumentiert.

## Bearbeitungsstand nach lokaler Umsetzung

| Punkte | Ergebnis |
|---|---|
| 1–6, 8, 27 | Zustandssteuerung, Audio-/Textwiederherstellung, modellabhängige Requests, transaktionaler Hotkey und Abbruch lokal umgesetzt; Offline-Ablauftests ergänzt. Native Bedienung bleibt live abzunehmen. |
| 7 | Teilfehlerbereinigung umgesetzt. Historische Absturzreste bewusst nicht pauschal gelöscht; Begründung in `remaining-acceptance.md`. |
| 17–23, 13 | Aufnahmezeit/Pegel/Countdown, native Zeitgrenze, konservatives Auto-Paste, letzter Text, Einzelliste und nichtmodale Routinefehler im Quellcode umgesetzt. VoiceOver/Mikrofon/Zielapp nicht live abgenommen. |
| 9–10, 14, 16, 29 | Asynchrone Bibliotheksansicht, gezieltes Laden, begrenztes serielles Logging, explizite Zeitlimits, HTTP-Stubs und Phasenmessung umgesetzt. |
| 11–12, 15 | Mit lokalem Release-Benchmark bearbeitet; Schwelle, Sample-Schleife und In-Memory-Upload begründet beibehalten. Keine behauptete Verbesserung der realen Netzwerklatenz. |
| 24–25 | Vokabular-Einstellung, eigene modifizierte Hotkeys und deutsche UI-Beschriftungen umgesetzt. Reale Sprachqualität und Barrierefreiheit offen; optionaler Hold-Modus zurückgestellt. |
| 26 | Streaming als späterer Kandidat dokumentiert; vor einer Implementierung fehlen reale Latenzbaseline und Vorschau-Abnahme. Nicht als erledigte Streamingfunktion ausweisen. |
| 28 | Synthetisches Audiotestset und Spezifikation für reales Sprachset vorhanden. Geeignete freigegebene Sprachdaten/Referenzen und Providerabnahme fehlen. |
| 30 | CI-Datei, VERSION, Buildnummer und Plist-/Signaturprüfung vorbereitet; lokaler Release-Build bestanden. Kein GitHub-Lauf, keine Installation oder Veröffentlichung. |

Der geprüfte Kandidat wurde in das Ausgangsrepository übernommen und dateiweise per SHA-256 verifiziert. Git-Diff-Prüfung und Shell-Syntaxprüfung bestanden. Kein Commit, Push, Start oder Installieren der App. Offen sind die in `remaining-acceptance.md` aufgeführten Live-Abnahmen und optionalen Erweiterungen; das Gesamtprojekt ist nicht live abgenommen.

Abschließende Testevidenz: Swift Testing meldet 95 Testfälle in 19 Suites erfolgreich, davon ist der nur explizit aktivierte Benchmark im normalen Lauf übersprungen. Dieser Benchmark wurde separat mit macOS-Codec-Zugriff ausgeführt und bestand. Release-Build, Plist-Prüfung und Ad-hoc-Signaturprüfung des Kandidaten bestanden. Die Übernahme ins Repository ist inhaltsgleich; Testartefakte bleiben separat.
