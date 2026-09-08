# OpenDictate Live-Abnahme – 2026-09-07

Historischer Prüfbericht für den damaligen Kandidaten. Er dokumentiert den
belegten Umfang, ersetzt aber keine erneute Prüfung eines späteren Builds.
Insbesondere verwendete dieser Kandidat noch automatisches `Cmd+V`; der Bericht
belegt nicht die später eingeführte direkte `AXSelectedText`-Einfügung.

## Geprüft

- Aktueller Repository-Kandidat mit `scripts/build-app.sh` gebaut und signaturgeprüft; aus `.build/OpenDictate.app` gestartet. Der laufende Prozess verweist auf dieses Bundle, dessen Signatur als `OpenDictate Self-Signed` verifiziert wurde. Die installierte App unter `/Applications` wurde nicht ersetzt.
- Zwei echte, einzeln autorisierte API-Anfragen mit synthetischer deutscher Referenzsprache (5,22 Sekunden, 36.775 Bytes), ohne Mikrofonaufnahme: `gpt-transcribe` und `gpt-4o-mini-transcribe` bestanden. Beide erkannten Test, sieben und Apfel. Gemessene Aufrufdauer: 0,850 beziehungsweise 5,042 Sekunden. Einzelmessungen erlauben keinen belastbaren Geschwindigkeitsvergleich.
- Anschließendes `swift test`: Runner meldet 96 Tests in 20 Suites bestanden; Live-API-Test und Benchmark planmäßig übersprungen.
- `git diff --check` bestanden.

## Noch offen

Der laufende fensterlose Kandidat lässt sich durch das native UI-Werkzeug weiterhin nicht direkt auslesen (Timeout -10005), auch nicht nach Öffnen des Menüs. Ein unveränderter Wiederholungsversuch ist daher kein geeigneter nächster Nachweis. Normaler Mikrofonlauf, Zielapp-Übergabe, Fokuswechsel, Zwischenablage-Fallback und Abbruch/Behalten sind unten belegt. Offen bleiben VoiceOver, der sichtbare Countdown samt nativem 90-Sekunden-Stopp und die weiteren Randfälle in `remaining-acceptance.md`. Synthetische Sprache und ein einzelner menschlicher Satz ersetzen keine allgemeine Sprachqualitätsprüfung. Streaming und Hold-to-talk bleiben optionale, nicht implementierte Erweiterungen.

Kein Commit, Push, Installationsaustausch oder öffentliche Binärveröffentlichung erfolgt. Der Kandidat bleibt für den noch ausstehenden bedienten Test geöffnet.

## Menschlicher Diktiertest in TextEdit

Nach Nutzermeldung „done“ wurde das TextEdit-Dokument „Apfelzahl-Test“ über die native Accessibility-Schnittstelle gelesen. Inhalt: „Dies ist ein kurzer Test, bitte schreibt die Zahl sieben und das Wort Apfel.“ Der Zieltext ist damit direkt nachgewiesen; gegenüber der vorgegebenen Referenz steht „schreibt“ statt „schreibe“. Ohne Abhören der Aufnahme ist offen, ob diese Abweichung beim Sprechen oder bei der Transkription entstand.

Das App-Protokoll zeigt am 2026-09-07 um 09:01:11–09:01:13 UTC die Audioverarbeitung, eine Anfrage von 2033,10 ms, Übergabe von 30,14 ms und Stop-bis-Ergebnis von 2143,95 ms. Zusammen mit dem bedienten Test und sichtbaren Zieltext belegt dies einen erfolgreichen normalen Diktierdurchlauf. Fokuswechsel und Abbruch wurden anschließend separat geprüft; 90-Sekunden-Stopp und VoiceOver bleiben offen. Keine allgemeine Sprachqualitäts- oder Latenzgarantie aus dieser Einzelprobe.

## Fokuswechsel-Test

Nutzer meldet: nach Aufnahmebeginn in TextEdit, Wechsel zu Codex und Stoppen wurde in beiden Apps kein Text eingefügt. Das App-Protokoll bestätigt am 2026-09-07 um 15:18:14.564 UTC ausdrücklich: `Auto-paste skipped: user changed the foreground application`. Damit ist die Unterdrückung des automatischen Einfügens für diesen bedienten Fokuswechsel belegt. Die manuelle Verfügbarkeit des Transkripts wurde anschließend durch die Rückgabe des Referenztexts bestätigt.

## Zwischenablage und erhaltene Aufnahme

Der Nutzer hat den erwarteten Fokuswechseltext zurückgegeben: „Dieser Text gehört zum Fokuswechseltest.“ Damit ist die manuelle Verfügbarkeit durch Nutzerrückmeldung bestätigt.

Nach dem angeleiteten Abbruchtest wurde der Zustand direkt geprüft: Logeintrag vom 2026-09-07 15:28:03.246 UTC meldet eine authentifizierte gesicherte Aufnahme. Die zugehörige M4A-Datei (92.984 Bytes) und .auth-Datei (32 Bytes) sind vorhanden, jeweils mit Dateirechten 0600. `afinfo` liest einen Mono-AAC-Track mit 24 kHz und 10,195 Sekunden. Dies belegt die erhaltene, als Audiodatei lesbare Aufnahme; der Menü-Klick und die sichtbare Statusänderung wurden nicht vom UI-Werkzeug beobachtet. Kein erneuter Upload und kein Abspielen für diese Prüfung. VoiceOver und nativer 90-Sekunden-Stopp bleiben live ungeprüft.

## VoiceOver-Versuch

VoiceOver wurde über die sichtbare Systemeinstellung eingeschaltet; der laufende VoiceOver-Prozess und der aktive Schalter wurden direkt bestätigt. Der Beschriftungsbereich war aktiviert. Der direkte Zugriff auf den laufenden `.build`-Kandidaten endete auch unter VoiceOver mit Timeout `-10005`. Die UI-Automation leitete weder `Control+Option` noch die testweise aktivierte einzelne Option-Taste als VoiceOver-Sondertaste an die Menüleistennavigation weiter. Die nur für diesen Versuch geänderte Option-Tastensteuerung wurde auf den vorherigen Zustand zurückgesetzt und VoiceOver anschließend wieder ausgeschaltet. Damit ist nur der kontrollierte Testaufbau belegt, nicht die Erkennung der OpenDictate-Zustände oder Bedienelemente durch VoiceOver.

## 90-Sekunden-Stopp – Startwerkzeug blockiert

Die Umgebung ist still; das ist für den Timer-Nachweis geeignet. Die Vorverarbeitung sollte bei tatsächlich stillem Audio ohne Provideraufruf in den lokalen Recovery-Pfad wechseln. Zwei synthetische Versuche, `Option+Shift+Space` über die UI-Automation zu senden, erzeugten jedoch nur ein geschütztes Leerzeichen im leeren TextEdit-Testdokument. Es entstand keine neue `opendictate-*.m4a`, und das OpenDictate-Protokoll blieb unverändert. Der Carbon-Hotkey wurde somit nicht ausgelöst. Das ist eine Werkzeuggrenze und weder ein bestandener noch ein fehlgeschlagener Produkt-Timertest. Für diesen einen Start ist eine physische Betätigung des Hotkeys erforderlich.
