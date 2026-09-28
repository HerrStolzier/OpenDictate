# Projektbezogene Freigaben

Diese Ablage dokumentiert Zustimmung, erteilt selbst aber keine. Vor einer Aktion
Originalumfang, Ziel, Bedingungen und neuere Einschränkungen prüfen. Widerruf
geht vor; ausdrücklich einmalige oder befristete Zustimmung bleibt begrenzt.
Technische Berechtigungsprüfungen bleiben bestehen. Keine Secrets oder privaten
Gesprächsinhalte speichern. Unbelegte historische Freigaben nicht nachtragen.

## iOS-Vorbereitung: Xcode und Simulator — 2026-09-28

- **Quelle:** Direkte Antwort „Ja, Xcode und iOS-Simulator installieren“
  auf die konkrete Frage zur fehlenden lokalen iOS-Entwicklungsumgebung.
- **Umfang:** Apples kostenloses Xcode 27 samt benötigtem iOS-Simulator auf
  diesem Mac installieren. Mehrere GB Download und lokale Entwicklungssoftware
  waren ausdrücklich Teil der Frage. Bezug über Apples offiziellen App Store.
- **Stand:** Xcode 27.0 (27A266a) ist installiert. Basti bestätigte die
  Ersteinrichtung selbst; Versionsabfrage und First-Launch-Prüfung bestehen.
  iOS 27.0 (24A434) ist registriert und startet als iPhone-18-Pro-Simulator
  bis zum geprüften Home-Bildschirm. Der vorherige Registrierungsfehler des
  Download-Befehls und die getrennte Startprüfung stehen in der [iOS-Richtung](docs/ios-direction.md).
- **Grenze:** Keine iPhone-/iPad-Installation, echte Mikrofonaufnahme,
  Anbieteranfrage, neue Signieridentität oder Veröffentlichung freigegeben.

## Linux: lokale Schlüssel einrichten — 2026-09-28

- **Quelle:** Direkte Antwort „Ja, Linux-Schlüssel einrichten“ auf die
  konkrete Frage zur Einrichtung der beiden fehlenden OpenDictate-Schlüssel
  im bestehenden geschützten Schlüsselbund auf `omarchy`.
- **Umfang:** Basti gibt den OpenAI-API-Schlüssel selbst verdeckt am
  Linux-Rechner ein. Der Schutzschlüssel für Aufnahmen wird dort erzeugt.
  Das geprüfte Skript überspringt einen bereits vorhandenen API-Schlüssel.
  Kein Schlüssel gelangt in Chat, Befehlsargumente, Umgebungsvariablen oder Dateien.
- **Stand:** Der Aufnahmeschutzschlüssel wurde erzeugt und sein vorhandener
  Schlüsselbundeintrag ohne Lesen des Inhalts nachgewiesen. Basti hat den API-Schlüssel
  selbst verdeckt eingegeben. Die anschließende Metadatenprüfung bestätigt
  beide Einträge; ihre Inhalte wurden nicht ausgelesen. Die Anbieterprüfung
  des API-Schlüssels ist noch offen.
- **Grenze:** Keine Aufnahme, Anbieteranfrage, Installation, Änderung der
  Hyprland-Konfiguration oder Veröffentlichung. Diese Einrichtung ist keine
  pauschale Freigabe späterer Zugangsdatenänderungen.

## Windows: Verteilungsvorbereitung und Schutztests — 2026-09-28

- **Zielentscheidung:** Auf die Rückfrage zum nächsten Windows-Ziel wählte
  Basti ausdrücklich „Direkt öffentliche Verteilung vorbereiten“. Der
  Fortsetzungsauftrag umfasst die technische Vorbereitung, nicht deren
  tatsächliche Veröffentlichung, Zertifikatskauf oder Softwareinstallation.
- **Testfreigabe:** Auf die konkrete Frage zu den vorhandenen Windows-
  Schutztests antwortete Basti „Ja, Windows-Schutztests ausführen“.
  Erlaubt sind künstliche temporäre Dateien sowie ein eindeutig benannter
  Testeintrag mit erfundenen Zugangsdaten, der danach entfernt wird.
  Echter API-Schlüssel und Nutzeraufnahmen bleiben unverändert.
- **Ausgeführt:** 18/18 Schutztests im angemeldeten Windows-Desktop mit
  normalen Benutzerrechten bestanden. Der vorausgegangene SSH-Lauf hatte
  16/18 bestanden; Credential-Zugriffe in Session 0 meldeten Win32-Fehler
  1312. Der Desktop-Lauf verwendete denselben unveränderten Quellstand.
  Die eigene temporäre Startaufgabe und Prüfkopie wurden entfernt; die
  Tests bestätigten das Entfernen ihres Dummy-Zugangseintrags.
- **Grenze:** Keine reale Schlüsseländerung, Mikrofonaufnahme, Anbieteranfrage,
  Produkt-App-Installation oder Veröffentlichung freigegeben. Der Nachweis
  steht in der aktuellen Plattform-Fortsetzung.

## Developer-ID-Signieridentität — 2026-09-28

- **Quelle:** Direkte Antwort „Ja, diese Signieridentität einrichten“ in der
  Hauptaufgabe `01a0e819-2220-7da2-8d9b-f82ce6f0cef4` auf die konkrete
  Rückfrage zur Einrichtung einer Developer ID Application für OpenDictate.
- **Umfang:** Privaten Signierschlüssel auf diesem Mac erzeugen, öffentliche
  Zertifikatsanfrage an Apple senden und das ausgestellte Zertifikat im
  Anmeldeschlüsselbund einrichten. Bestehende Zertifikate, App und Aufnahmen
  bleiben unverändert.
- **Ausgeführt:** Lokale Anfrage über den macOS-Zertifikatsassistenten,
  Ausstellung durch Apple, Import des Application-Zertifikats und des
  offiziellen, gegen Apple Root CA geprüften G2-Zwischenzertifikats.
  macOS meldet eine gültige Signieridentität. Keine Änderung von
  Vertrauenseinstellungen und kein Export des privaten Schlüssels.
- **Grenze:** Kein Notarisierungszugang eingerichtet, kein App-Upload,
  App-/Helper-Austausch oder Live-Diktat durch diese Freigabe. Die
  Einrichtung ist abgeschlossen; dies ist keine pauschale Erlaubnis für
  spätere Schlüssel- oder Zertifikatsänderungen.

## Lokaler Notarisierungszugang — 2026-09-28

- **Quelle:** Direkte Antwort „Ja, Notarisierungszugang vorbereiten“ in
  Hauptaufgabe `01a0e819-2220-7da2-8d9b-f82ce6f0cef4`.
- **Umfang:** Eigenes lokales Schlüsselbundprofil `OpenDictate-Notary`
  vorbereiten und bei Apple validieren. Ein nötiges anwendungsspezifisches
  Apple-Passwort erstellt Basti selbst und trägt es direkt in die verdeckte
  lokale Eingabe ein, nicht in den Chat, Befehlsargumente oder Dateien.
- **Ausgeführt:** Basti hat das anwendungsspezifische Passwort selbst erstellt
  und über die verdeckte Terminal-Eingabe gespeichert. Die zurückgemeldete
  Werkzeugausgabe bestätigt Validierung und Speicherung im Anmeldeschlüsselbund.
  Ein anschließender eigener Aufruf von `notarytool history` mit dem Profil
  und diesem Schlüsselbund war erfolgreich; Apple meldet keine bisherigen
  Einreichungen. Der Zugang ist damit verwendbar geprüft, ohne App-Upload.
- **Grenze:** Diese Zustimmung erlaubt keinen App-Upload zur Notarisierung,
  keine Installation/Migration und keine Veröffentlichung.

## Lokale Signierung von Build 8 — 2026-09-28

- **Quelle:** Fortsetzungsauftrag „Dann weiter mit der Agentensteuerung“ und
  anschließende Antwort „Dialog bestätigt“ auf die konkrete Rückfrage zum
  Zugriff von `codesign` auf den OpenDictate-Developer-ID-Schlüssel.
- **Ausgeführt:** Basti bestätigte den macOS-Zugriffsdialog selbst. App und
  Helper des getrennten lokalen Build-8-Kandidaten wurden mit der bestehenden
  Identität und sicheren Apple-Zeitstempeln signiert und geprüft.
- **Grenze:** Keine Freigabe für Schlüssel-/Zertifikatsänderungen, globale
  Schlüsselbund-/ACL-Eingriffe, App-Upload, Installation oder Live-Diktat.

## Apple-Notarisierung von Build 8 — 2026-09-28

- **Quelle:** Direkte Antwort „Du hast sie“ in Hauptaufgabe
  `01a0e819-2220-7da2-8d9b-f82ce6f0cef4` auf die konkrete Frage zum Upload
  des lokal und unabhängig geprüften Build-8-Pakets an Apple.
- **Umfang:** Genau das Kandidaten-ZIP mit SHA-256
  `cee6fcc5d7c2bc311eacbad82f1e6e7538148d1c8808fd61b18b598a0b199a82`
  (0.1.0 Build 8, saubere Quellrevision
  `b786d4ccd75462b902d3a1439c247bd1a5aeeca8`, 3.487.252 Bytes) über das
  bestehende Profil `OpenDictate-Notary` an Apple senden. Bei Annahme das
  Prüfticket anheften und das endgültige Paket erzeugen und prüfen.
- **Grenze:** Keine Installation, Migration, App-/Live-Diktat-Abnahme oder
  Veröffentlichung; keine Änderung von Zugangsdaten oder Schlüsselbundrechten.

## Dokumentationspilot — 2026-09-14

- **Umfang:** OpenDictate-Dokumentation bereinigen, PROJECT und APPROVALS ergänzen,
  bestehende Abnahmedatei als einzige Statusquelle verwenden, Workspace-Vorlage
  und Migrationsanleitung integrieren; Übertragbarkeit auf ICG-V2, random-stuff
  und codex-config prüfen. Keine pauschale Migration dieser Repositories.
- **Quelle:** Direkte Nutzernachricht „Dann setz ihn um“, gelesen in Aufgabe
  `01a09e64-fca4-7042-be66-229e57530531`, Turn
  `01a09f8c-2ae1-7083-b7d8-dec51ba013e7`; Bezug ist der vollständige Plan im
  vorherigen Turn `01a09f8a-d6a4-75c3-8c69-ae6bb0345db5`.
- **Bedingungen:** Nutzeränderungen erhalten; mit bestehender Git-Abschlussaufgabe
  abstimmen. Git-Routine gemäß geltenden übergeordneten Regeln; vor Push/Merge
  Veröffentlichungseffekte prüfen. Keine Features, App-/Website-Releases oder
  neuen Subagenten. Keine globale Freigabespeicherregel aktivieren.
- **Gültigkeit:** Dieser Umsetzungsauftrag bis Abschluss oder Widerruf. Kein
  Dauerauftrag zur Änderung anderer Repositories oder zu Live-Tests.

Weitere dauerhafte Projektfreigaben sind hier nicht belegt. Frühere einzelne
Mikrofon-/API-Abnahmen sind Nachweise und keine erneute Ausführungserlaubnis.

## Plan 1: Live-Tests — 2026-09-23

- **Auftrag:** Basti beauftragte die Umsetzung von
  [Plan 1](docs/release-plans/01-interne-produktabnahme.md) mit „Dann leg los mit dem ersten Plan“.
- **Konkrete Antwort:** Auf die Frage nach höchstens acht kurzen Aufnahmen und
  acht OpenAI-Uploads mit der installierten App über das bereits eingerichtete
  Konto antwortete er „Ja, diesen Live-Testblock freigeben“. Die App begrenzt
  eine einzelne Aufnahme auf 90 Sekunden. Harmlose Testsätze, keine
  automatischen Wiederholungen, Bereinigung eigener Testartefakte und keine
  Änderung von Zugangsdaten oder Systemrechten waren Teil der Frage.
- **Zusätzlicher Auftrag:** Basti bat direkt darum, die Eingangslautstärke so
  anzupassen, dass das Mikrofon ein Signal wahrnimmt. Das JBL Quantum Stream
  Talk war Standardmikrofon, nicht stumm und auf 23,5 Prozent gestellt. Sein
  Eingangsregler steht nach der Änderung auf dem vom Gerät bestätigten Wert
  77,2 Prozent. Die acht realen Mikrofonaufnahmen mit lokal abgespielter
  Referenzsprache erreichten danach Spitzen zwischen −34 und −33 dB. Das
  belegt ein Eingangssignal, keine allgemeine Qualität menschlicher Sprache.
- **Verbrauch des ersten Blocks:** Acht Aufnahmen und sieben OpenAI-Uploads. Die
  Ereignisse und Ergebnisse stehen im
  [Live-Ledger](docs/release-plans/evidence/2026-09-23-live-ledger.json).
  Es gab keine automatische Wiederholung.
- **Fortsetzung:** Basti sagte anschließend ausdrücklich: „Es gibt kein
  begrenztes Kontingent. Du kannst arbeiten, bis die Aufgabe beendet ist. Bitte
  stell Plan 1 fertig.“ Weitere kurze Live-Aufnahmen und OpenAI-Uploads zur
  Abnahme von Plan 1 sind damit ohne feste Stückzahl autorisiert. Das erweitert
  weder den Produktumfang noch erlaubt es automatische Wiederholungen,
  Änderungen an Zugangsdaten oder Systemrechten oder eine Veröffentlichung.

## Begrenzte Roadmap-Abnahme — 2026-09-17

- **Umfang:** Direkter Auftrag in Aufgabe `01a0ae15-cb33-7ca2-9c6e-78fd5988f0bd`,
  ambitionierte Ziele für die offenen macOS-Abnahmen zu erstellen und möglichst
  autonom umzusetzen. Reversible Korrekturen, passende Prüfungen und der geregelte
  Git-Abschluss gehören dazu; zurückgestellte Produktfunktionen und Veröffentlichung
  werden dadurch nicht aktiviert.
- **Konkrete Live-Freigabe:** Basti bestätigte die vorbereitete Testfrage mit
  „Ja, diesen begrenzten Live-Test freigeben“: angekündigte Mikrofonprüfungen mit
  lokal erzeugter Sprachausgabe über Lautsprecher, höchstens sechs Testaufnahmen
  und sechs Uploads mit insgesamt höchstens vier Minuten Audio über das bestehende OpenAI-Konto,
  einschließlich einer 90-Sekunden-Aufnahme. Bekannter Testtext: „Dies ist ein
  kurzer Test. Bitte schreibe die Zahl sieben und das Wort Apfel.“ Auf mögliche
  Umgebungsgeräusche wurde vor der Zustimmung hingewiesen.
- **Lautstärke:** Basti erlaubte ergänzend eine nötige Erhöhung der Systemlautstärke.
  Der Ausgangswert wird nach der Prüfung wiederhergestellt.
- **Grenzen:** Keine Änderung von Zugangsdaten oder Systemrechten, keine neue
  Software, kein menschlicher Sprachkorpus aus privaten Aufnahmen und keine
  öffentliche Veröffentlichung. Diese Zustimmung gilt nur für diesen begrenzten
  Auftrag; verbrauchte Uploads und Audiozeit werden im datierten Bericht erfasst.
- **Verbraucht:** Sechs Aufnahmen und sechs Uploads; konservative Obergrenze
  der aufgenommenen Audiozeit 210 Sekunden. Das Versuchslimit ist ausgeschöpft.
  Weitere Mikrofon-/Providerläufe sind durch diese Zustimmung nicht freigegeben.

## Zweiter begrenzter Zielprogramm-Testblock — 2026-09-17

- **Auftrag:** Direkte Nutzernachricht „nächstes Ziel und go“; anschließend
  ausdrücklicher Wunsch nach einem Agenten für Commit, Push und Merge.
- **Live-Freigabe:** Direkte Antwort „Ja, diesen neuen Testblock freigeben“ zur
  vorbereiteten Frage in derselben Aufgabe: höchstens acht angekündigte
  Mikrofonaufnahmen und acht OpenAI-Uploads mit insgesamt höchstens drei Minuten
  Audio über das bestehende Konto. Ziele: native Felder, vier Safari-Feldtypen,
  Obsidian und Fokuswechsel. Der bekannte Testsatz wird lokal über Lautsprecher
  abgespielt: „Dies ist ein kurzer Test. Bitte schreibe die Zahl sieben und das
  Wort Apfel.“ Mögliche Umgebungsgeräusche waren Teil der Freigabefrage.
- **Lautstärke:** Vorübergehend höchstens 75 Prozent; den unmittelbar vor diesem
  Block gemessenen Ausgangswert anschließend wiederherstellen.
- **Grenzen:** Dieser neue Testblock erweitert weder Systemrechte noch
  Zugangsdaten, Softwareinstallation oder Veröffentlichung. Keine privaten
  Audioinhalte als Referenz und kein unbegrenztes Wiederholen. Verbrauch und
  Aufräumen werden im zugehörigen Abnahmebericht festgehalten.
- **Verbraucht:** Acht Aufnahmen und acht Uploads, konservativ höchstens
  170 Sekunden. Das Versuchslimit ist ausgeschöpft; die Lautstärke wurde auf
  die gemessenen 68,75 Prozent zurückgestellt. Ergebnisse, Bereinigung und
  verbleibende Nachweisgrenzen: [ergänzende Zielabnahme](docs/target-acceptance-2026-09-17.md).

## Begrenzter Terminal- und Fokusblock — 2026-09-22

- **Auftrag und Antwort:** Basti setzte die macOS-Abnahme mit „Okay, dann mach
  damit weiter“ fort und bestätigte anschließend die konkrete Frage mit „Ja,
  diesen begrenzten Live-Testblock freigeben“.
- **Freigabe:** Höchstens drei kurze Mikrofonaufnahmen und drei OpenAI-Uploads
  über das bereits eingerichtete Konto, zusammen höchstens 45 Sekunden Audio.
  Ziel: sichtbare Eingabe in einem eigenen Apple-Terminal-Fenster und ein
  Fokuswechsel nach dem Stoppen; der dritte Lauf durfte einen gezielten
  Fehlversuch abdecken. Keine Änderung von Zugangsdaten oder Systemrechten.
- **Verbrauch:** Drei Aufnahmen, zwei Provider-Request-Versuche. Der erste Lauf
  war zu leise und wurde ohne Upload übersprungen; der zweite Request war
  erfolgreich, der dritte endete nach 31 Sekunden ohne Transkript. Die
  Audio-Gesamtdauer wurde nicht instrumentiert. Dieser Block ist wegen der
  ausgeschöpften Aufnahmezahl beendet. Einzelheiten und Bereinigung:
  [Terminal- und Fokusabnahme](docs/terminal-focus-acceptance-2026-09-22.md).

## Autonomer Fokuswechselblock — 2026-09-22

- **Auftrag und Antwort:** Auf die Frage nach einer vollständig selbst gesteuerten
  Wiederholung antwortete Basti „Ja, du hast meine Freigabe. mach den Test bitte
  ohne mich.“ Die konkrete Frage begrenzte den Block auf höchstens zwei kurze
  Mikrofonaufnahmen und zwei OpenAI-Uploads über das eingerichtete Konto mit
  zusammen höchstens 20 Sekunden Audio; eigene Testartefakte sollten bereinigt
  werden. Keine Änderungen an Zugangsdaten oder Systemrechten.
- **Tatsächlicher Verbrauch und Abweichung:** Eine Aufnahme und ein
  Provider-Request. Die Aufnahme dauerte laut eigener Audiodatei **31,272
  Sekunden** und überschritt damit die freigegebene Audioobergrenze. Der Agent
  stoppte die weitere Live-Ausführung; es gab keine zweite Aufnahme und keinen
  zweiten Upload. Die Freigabe ist beendet. Ablauf, fehlender Fokusnachweis und
  Bereinigung: [autonomer Fokuswechselversuch](docs/autonomous-focus-acceptance-2026-09-22.md).

## Wiederholter Fokuswechsel — 2026-09-23

- **Auftrag und Korrektur:** Basti wies an, den Fokuswechseltest ohne seine
  Bedienung zu wiederholen und einen dabei gefundenen Fehler zu beheben. Er
  stellte klar, dass eine technisch erzwungene Aufnahmezeitgrenze dafür keine
  Voraussetzung ist. Diese neue Anweisung bezog sich auf den konkreten
  Wiederholungstest, nicht auf unbegrenzte künftige Mikrofon-/API-Läufe.
- **Ausführung:** Zwei kurze Aufnahmen über das vorhandene Mikrofon; die erste
  wurde wegen zu leisem Signal ohne Upload übersprungen. Die zweite führte zu
  einem OpenAI-Request und einem [bestandenen negativen Appwechsel](docs/live-focus-acceptance-2026-09-23.md).
  Die eigens gestarteten Testfenster und die fehlgeschlagene eigene Aufnahme
  wurden bereinigt. Weitere Live-Läufe erfolgten in diesem Auftrag nicht.

## Konkreter Git-Abschluss — 2026-09-14

- **Umfang:** Dokumentationsstand `956afec` nach `HerrStolzier/OpenDictate`
  hochladen und nach erfolgreicher Prüfung zusammenführen; kein App-/Website-Release.
- **Quelle:** Direkte Antwortannotation „jup“ zur konkreten Freigabefrage in
  Aufgabe `01a09e64-fca4-7042-be66-229e57530531`, Turn
  `01a09fa1-2fb7-7261-b25f-321740e62453`, im Original gelesen.
- **Gültigkeit:** Dieser Git-Abschluss, kein Dauerauftrag. Bestehende Änderungen
  erhalten und erforderliche Prüfungen bestehen lassen; Widerruf geht vor.
