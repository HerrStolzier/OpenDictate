# Aktueller Stand und verbleibende Abnahme

Stand: 2. Oktober 2026. Dies ist die einzige aktuelle Übergabedatei.
Produktziel und Umfang: [PROJECT.md](../PROJECT.md); die einzige Feature-/
Plattform-To-do-Liste: [ROADMAP.md](../ROADMAP.md); Regeln: [AGENTS.md](../AGENTS.md);
Prüfverfahren: [CHECKS.md](../CHECKS.md); frühere Freigaben: [Archiv](archive/APPROVALS.md).
Diese Datei hält nur den aktuellen Übergabe- und Abnahmestand. Detailpläne und
datierte Belege sind jeweils an ihrer zuständigen Quelle verlinkt.

Seit dem 5. Oktober ist **Linux** die aktive Plattform, mit Schwerpunkt
Live-Übersetzung ([Plan](linux-live-translation-plan.md)); der folgende
Mac-Stand ruht unverändert. Davor galt: Seit dem 2. Oktober wird immer nur
eine Plattform aktiv bearbeitet ([ROADMAP](../ROADMAP.md)). Aktiv war **macOS Plan 2** (Build 8 von Apple
akzeptiert, finales Paket geprüft; Installation und Live-Abnahme offen). **Windows**
(öffentliche Verteilung vorbereiten) und **Linux Phase 1** (Clipboard-MVP-Kern
in `main`, ohne Live-Durchstich und UI-Abnahme) laufen nicht parallel, sondern
warten auf die Plattform-2-Entscheidung nach Stufe 6; ihre Abschnitte unten
sind der zuletzt belegte Übergabestand. **iOS** ist bis zu einer Nachfrage aus
Stufe 6 zurückgestellt; die bisherigen Nachweise unten bleiben erhalten
([Neuordnung](roadmap-neuordnung-2026-10-02.md)).

## iOS: synthetischer Safari-Textpfad bestanden · 29. September 2026

Fortsetzung am 30. September: Bastis iPhone 15 mit iOS 27.0.1 ist per USB
verbunden. Nach eigener Xcode-Anmeldung und genehmigter Entwicklungssignierung
bestehen signierter Build, Signaturprüfung, Installation und sichtbarer Start.
Das alte Entwicklungszertifikat wurde nicht widerrufen. Die fernbediente
Device-Hub-Steuerung bleibt blockiert; Basti bedient die aktivierte Tastatur.
Einfügung in beide Textfelder ist per Screenshot belegt. Im Passwortfeld
bestätigt Basti die Apple-Tastatur direkt am Display; die Aufnahme zeigt sie
nicht. Der frische Wiederholungslauf bestätigt Anfang und erwarteten Endzustand
nach Eingabe, Löschen und vom Nutzer bestätigtem App-Wechsel. Die Test-App
ist wieder deinstalliert; Basti bestätigte das Schließen der eigenen Safari-Tabs.
Der begrenzte synthetische Textpfad ist bestanden. Echte Aufnahme bleibt offen.
[Aktueller Gerätenachweis](ios-device-2026-09-30.md).

Der unabhängig geprüfte Offline-Tastatur-Prototyp aus `e416a3d` besteht nun
auch den sichtbaren E2E-Test auf dem separat genehmigten frischen iPhone-18-Pro-
Simulator: Aktivierung ohne Vollzugriff, bewusste Einfügung, normale Eingabe,
Feld-/App-/Tastaturwechsel und Systemtastatur im leeren Passwortfeld.
Die installierten Binärhashes entsprechen dem bereits geprüften Kandidaten;
keine iOS-Quelländerung war nötig. [Nachweis](ios-keyboard-e2e-2026-09-29.md).

Test-App, sichtbarer Tastatureintrag, eigener Safari-Tab, Server und Log-Helfer
sind bereinigt. Das funktionierende Diagnosegerät bleibt ausgeschaltet
vorhanden, alle alten Geräte sind erhalten. Die genaue Ursache der fehlenden
Tastatur im ursprünglichen Gerät bleibt unbewiesen.

Offen bleiben der reale Aufnahme-/Tastaturablauf auf einem benannten iPhone,
Provider, Diktatqualität, weitere Ziel-Apps und Barrierefreiheit. Der bestandene
synthetische Textpfad ist keine fertige iOS-Diktier-App oder Veröffentlichungsfreigabe.

## Aktuelle Projektbereinigung · 28. September 2026

Plattformen und Erweiterungen stehen jetzt zentral in [ROADMAP.md](../ROADMAP.md).
Die [Projektprüfung](project-audit-2026-09-28.md) und die direkte
[Geräteprüfung](platform-audit-2026-09-28.md) begründen die verbleibenden Schritte.
Linux bestand heute 23 Offline-Tests, Formatierung, Clippy und Release-Build;
Windows inzwischen 23 Kern-/Ablaufprüfungen und 18 Schutzprüfungen sowie
App-/Browser-Host-Build. Die separat genehmigten Windows-Schutztests und ihre
Bereinigung stehen in der [Plattform-Fortsetzung](platform-continuation-2026-09-28.md). Keine neue
sichtbare Produktabnahme, Aufnahme oder Provideranfrage fand statt.

Die kleine Mac-Bereinigung entfernt fünf ungenutzte Sourcezeilen und korrigiert
zwei Kommentare. Das gewünschte 10–25%-Reduktionsziel blieb unerreicht.
Swift-Coverage: 33,52657 → 33,55899 %, kein relativer Verlust; alle bisherigen
Tests und der Rust-Code blieben unverändert. Einzelwerte und Prüfgrenzen:
[Reduktionsnachweis](code-reduction-2026-09-28.md). Build 8 und sein eingereichtes
Paket bleiben davon getrennt und unverändert.

## Plan 2: Build 8 notarisiert, finales Paket geprüft · 2. Oktober 2026

Apple hat die Einreichung `320efa5c-d9fa-4e3b-980b-1a121ffdd371` akzeptiert
(Abfrage am 2. Oktober; Log ohne Befunde). Aus genau dem eingereichten ZIP
wurde die App entpackt, das Ticket angeheftet und mit
`scripts/package-release-app.sh` aus einem sauberen Worktree auf `b786d4c` das
finale ZIP samt Manifest erzeugt. Das entpackte finale Bundle besteht
Signatur-, Entitlement-, Ticket- und Gatekeeper-Prüfung, auch mit gesetzter
Quarantäne; Produkt-Hashes stimmen mit Build 8 überein, Größe 4,14 MiB.
Finales ZIP (außerhalb des Repositorys) mit SHA-256 `2e994cd8…e335768`:
[Nachweis](release-plans/evidence/2026-10-02-plan2-build8-final.md). Nichts wurde installiert oder gestartet.
Offen: erster Start mit Quarantäne, kontrollierte Migration, vollständiger
Diktat-/Kopierweg und aktiver Beenden-/Recovery-Fall, jeweils mit Bastis Go
am Mac nach der [Migrationsanleitung](release-plans/plan2-migration.md).

### Vorgeschichte: Build 8 eingereicht · 28. September 2026

Basti hat die Fortsetzung von Plan 2 beauftragt. Die am 28. September lesend
geprüfte Apple-Accountseite zeigt jetzt die Apple-Developer-Mitgliedschaft mit
Verlängerung im September 2027; die Zertifikatsverwaltung ist erreichbar.
Der Bearbeitungsstatus vom 25. September ist damit überholt. Nach Bastis
konkreter Freigabe wurde über den macOS-Zertifikatsassistenten ein lokaler
Signierschlüssel mit öffentlicher Zertifikatsanfrage erzeugt. Apple stellte
ein Developer-ID-Application-Zertifikat aus. Dieses und das von Apple bezogene,
gegen die vorhandene Apple-Root-Kette geprüfte G2-Zwischenzertifikat wurden
im Anmeldeschlüsselbund installiert. `security verify-cert -p codeSign`
bestätigt die Zertifikatskette; `security find-identity -v -p codesigning`
meldet jetzt eine gültige Identität. Keine Vertrauenseinstellung wurde geändert
und kein privater Schlüssel exportiert.

Die installierte App und ihr installierter Schlüsselbundhelfer tragen weiterhin
die lokale selbst signierte Identität. Ein getrennter Developer-ID-Kandidat
0.1.0 Build 8 wurde inzwischen aus dem sauberen Commit `b786d4c` gebaut und
signiert. App, Helper und erneut entpacktes ZIP bestehen die Release-Prüfung.
Zwei dabei gefundene Argumentfehler im Prüfer wurden minimal korrigiert;
positive und negative Paketprüfungen sowie beide CI-Jobs bestehen. Der
unabhängige Kritiker hat genau dieses ZIP selbst entpackt und geprüft:
keine wesentlichen Befunde. Der Prüfer-Fix ist über
[PR #31](https://github.com/HerrStolzier/OpenDictate/pull/31) integriert.
Der Schlüsselbundzugriff der laufenden neuen App ist noch nicht geprüft.
Artefaktidentität, Hash, wiederholbare Prüfung und offene Grenzen stehen im
[Build-8-Nachweis](release-plans/evidence/2026-09-28-plan2-build8.md).

Der vorbereitete Paketbau ist über PR #29 in `main` (`dbf48bf`) integriert;
der CI-Lauf dieses Standes ist erfolgreich. Ein notarisierter Betakandidat
ist noch nicht hergestellt oder freigegeben. Die Vorbereitung und
Validierung des lokalen Notarisierungsprofils `OpenDictate-Notary` ist konkret
freigegeben und abgeschlossen. Basti hat das anwendungsspezifische Apple-Passwort
selbst über die verdeckte Terminal-Eingabe gespeichert. Die Werkzeugausgabe
bestätigt Validierung und Speicherung. Der anschließende eigene Aufruf von
`notarytool history` mit dem Profil im Anmeldeschlüsselbund war erfolgreich;
Apple meldete dabei noch keine bisherigen Einreichungen. Nach Bastis separater
Uploadfreigabe „Du hast sie“ wurde genau das geprüfte Build-8-ZIP einmal an
Apple gesendet. Die Einreichung `320efa5c-d9fa-4e3b-980b-1a121ffdd371` vom
28. September, 17:10:08 UTC, stand damals noch auf In Progress und ist seit
der Abfrage am 2. Oktober **Accepted** (siehe oben). Kontrollierte
Installation/Migration, Live-Abnahme und Veröffentlichung bleiben getrennte
Freigabeschritte.

Der Wechsel des lokal installierten Schlüsselbundhelfers benötigt eine eigene
kontrollierte Migration: Der vorhandene Helfer wird nicht automatisch ersetzt
und muss dasselbe Zertifikat wie die App haben. Beim Wechsel von der lokalen
Signatur auf Developer ID darf vorhandener Schlüsselbund- oder Aufnahmedatenbestand
nicht gelöscht werden. Nachweise und nächste Schritte stehen im
[Plan-2-Vorbereitungsbericht](release-plans/evidence/2026-09-25-plan2-vorbereitung.md)
und in der [manuellen Migrationsanleitung](release-plans/plan2-migration.md).
Die Anleitung wurde noch nicht an der installierten App ausgeführt.

Die spätere [20-Prozent-Testbereinigung](test-audit-2026-09-25/README.md)
ist inzwischen über PR #28 in `main`: 109 statt 137 Swift-Testdeklarationen,
vier Opt-in-Prüfungen übersprungen, Gesamt-Zeilenabdeckung 33,89 → 33,53 Prozent.
Der Produktionscode und der installierte Build wurden dabei nicht verändert.

## Dokumentationsstand

Am 24. September wurden die maßgeblichen Gegenwartsquellen `PROJECT.md`,
`README.md`, `PRIVACY.md`, `CHECKS.md`, diese Übergabe, die
Kompatibilitätsmatrix, die fünf Release-Pläne und der lokale Website-Entwurf
gegen den dokumentierten Build-7-Stand abgeglichen. Veraltete Aussagen über
den installierten Build und den ⌘V-Ablauf wurden korrigiert. Datierte
Abnahmeberichte behalten ihren damaligen Kandidaten und werden dadurch nicht
zu Nachweisen für Build 7. Alle lokalen Markdown-Links und Website-Ressourcen
wurden geprüft. Die aktualisierte Website konnte wegen einer Browser-URL-Sperre
nicht erneut visuell abgenommen werden. Die spätere öffentliche
Release-Dokumentation ist damit weiterhin nicht freigegeben.

Die damalige [Testbereinigung](test-signal-audit.md) entfernte 22
schwach aussagekräftige oder redundante Testfunktionen. Die damalige
Swift-Suite mit 138 Testfunktionen (vier Opt-in-Tests übersprungen) sowie die
acht Python-Tests bestanden lokal; die zwei Rust-Testlöschungen
wurden separat auf `omarchy` gegen exakt `ab839fd5ab64ff69cc5a126e859f804b473b59a5`
geprüft: 23 Rust-Tests, Formatter, Clippy mit `-D warnings` und Release-Build
bestanden offline. Der isolierte Quellbaum aus allen 17 committed `linux/`
Dateien stimmte per SHA-256 überein und wurde nach dem Lauf entfernt; das
bestehende Remote-Checkout blieb sauber. Details und reproduzierbare Befehle
stehen im [Testsignal-Audit](test-signal-audit.md). Produktionscode,
installierter Build und E2E-Nachweise bleiben unverändert. Die Plan-1-Arbeit
war damals auf Bastis erneuten Auftrag wieder aufgenommen; der Abschluss des
internen Grundablaufs ist im folgenden Absatz dokumentiert.

Die [Fortsetzung vom 24. September](release-plans/evidence/2026-09-24-plan1-fortsetzung.md)
belegt für den laufenden Build 7 zehn Minuten Leerlauf mit durchschnittlich
0,02833 Prozent CPU und maximal 81,40625 MiB RSS. Eine aktuelle isolierte
UI-Teilprüfung ergänzt Hell/Dunkel, Tastaturfokus und den Rückweg zum Text.
Ein anschließendes echtes Diktat mit physischem Option+Shift+Space wurde von
Basti bestätigt und direkt im vorher leeren TextEdit-Testdokument verifiziert:
„Dieser Test enthält sieben grüne Äpfel.“ Dieser Build-7-Kürzellauf ist bestanden.
Auch „Text ansehen“ → „Text kopieren“ → manuelles ⌘V wurde mit diesem echten
Transkript und kontrollierter vorheriger Zwischenablage erfolgreich geprüft.
Vier synthetische native Positionen (Anfang/Mitte in ein- und mehrzeiligen
Feldern) wurden mit den unveränderten Produktionsquellen von `523cbd2` exakt
bestätigt; Einzelheiten stehen im
[Fortsetzungsbericht vom 24. September](release-plans/evidence/2026-09-24-plan1-fortsetzung.md).
Die frische Ersteinrichtung bleibt auf Bastis ausdrückliche Entscheidung als
offene Grenze bestehen; kein neues Benutzerkonto wird dafür angelegt. Plan 1
ist für den belegten internen Grundablauf abgeschlossen. Reale Störfälle gehen
als Sicherheitsprüfung vor Weitergabe an Tester in Plan 2; gehörtes VoiceOver
bleibt Abnahme des endgültigen Kandidaten in Plan 4. Alle 20 lokalen Wechsel
sind sichtbar aufgezeichnet, aber ihre App-Latenz wurde nicht belastbar gemessen. Die realen Einstellungen wurden
inzwischen am installierten Build 7 in der bestehenden dunklen Darstellung
bei Mindestgröße einschließlich Tastaturfokus, Hilfe und Aufnahmen geprüft;
API-Schlüssel und Vokabular wurden dabei nicht geöffnet oder verändert. Frühere
bestandene Tests werden anhand unveränderter Produktionspfade wiederverwendet,
nicht pauschal verworfen.

Die isolierte Vorschau ergänzt inzwischen alle zehn Panelzustände bei
340 Punkten Mindestbreite in Hell und Dunkel. Der neue Safari-textarea-Fall
am Anfang ist vollständig NFC-gleich, aber nicht rohzeichengleich; die
Akzeptanzentscheidung war zunächst offen und wurde wie unten beschrieben
getroffen. Die anfänglich ausgebliebene automatische
Safari-`contenteditable`-Übergabe trat auch nach Bastis echten Mausklicks auf.
Im anschließend neu gebauten Debug-Testprozess funktionierten dagegen sowohl
die PID-Diagnose als auch der unveränderte globale Produktionsweg am selben
Feldanfang. Alle zwölf Safari-Positionen liefern inzwischen vollständige NFC-Gleichheit.
Die zwölf Brave-Positionen und Obsidian an Anfang, Mitte und Auswahlersetzung
stimmen roh vollständig überein; Obsidian zusätzlich in der gespeicherten Datei.
Damit ist die Feldmatrix ausgeführt. Die Safari-Normalisierung wird für den
internen Grundablauf als vollständiger kanonisch gleicher Text akzeptiert;
der rohe Unterschied und die früheren erfolglosen Läufe bleiben sichtbar.
Die Ursache der früheren Fehlschläge bleibt ungeklärt; ein Wechsel der
Produktions-Zustellart ist durch die Gegenprobe nicht begründet.
[A/B-Nachweis](release-plans/evidence/2026-09-24-safari-pid-versus-global.json),
[kritischer Luna-Max-Review](release-plans/evidence/2026-09-24-critical-plan1-review.md)
und die Einzelwerte stehen im Fortsetzungsbericht. Die Rohabweichungen werden
nicht still als bestanden umgedeutet.

## Neuer Quellcodekandidat: normaler Einfügebefehl

Auf Bastis ausdrücklichen Wunsch ist die automatische Übergabe wieder auf
Zwischenablage, Aktivierung der beim Diktatbeginn aktiven App und ⌘V umgestellt.
Das Feld muss kein setzbares `AXSelectedText` mehr anbieten. Vor dem Tastendruck
werden Accessibility-Freigabe, Vordergrund-App und unveränderter Kopiertext
geprüft. Fenster und Feld sind nicht mehr gebunden: Ein Fokuswechsel kann Text
in ein anderes Feld derselben ursprünglichen App lenken; ein Appwechsel kann
durch die Reaktivierung rückgängig gemacht werden. Der Terminal-Sonderpfad und
seine Zeilenumbruchfilter sind entfallen. Offline-Tests belegen die
Entscheidungslogik. Ein
[begrenzter sichtbarer TextEdit-Test](installed-command-v-2026-09-23.md)
am damaligen Build `bd3630f` bestätigte normales ⌘V ohne Mikrofon, Provider
oder automatischen OpenDictate-Aufruf. Die anschließende
[Plan-1-Liverunde](release-plans/evidence/2026-09-23-plan1-status.md) belegte
am selben installierten Build automatische Einfügung nach fünf echten
Diktaten in TextEdit, Safari, Brave, Obsidian und eine nicht abgeschickte
Terminal-Zeile. Sie belegt diese konkreten Felder, keine allgemeine
Feldkompatibilität. Die historischen Live-Nachweise unten gelten nur für ihre
damaligen Kandidaten.

Die [lokale Plan-1-Matrix](release-plans/evidence/2026-09-23-offline-matrix.md)
zeigt zwei native Feldfälle und beide Fokuswechselarten mit künstlichem Text;
Safari normalisierte im `input` einen kombinierenden Akzent. Für den internen
Grundablauf ist das kanonisch gleiche Ergebnis akzeptiert. Vor dem Betapaket
folgen die noch offenen Fehler- und Beenden-Pfade aus Plan 2; die Zeit bis
zum nutzbaren Text wird in der Eigennutzung (Plan 3) gemessen. Der Abbruch während Aufnahme
bestand; ein echter Providerfehler und tatsächlich unterbrochene Verarbeitung
bleiben als praktische Nachweise offen.
Der erste Live-Testblock mit acht Aufnahmen ist verbraucht. Basti hat die
Fortsetzung von Plan 1 ohne festes Kontingent ausdrücklich freigegeben;
Details stehen im [Freigabe-Archiv](archive/APPROVALS.md).
Die Quellkorrektur zur Aufbewahrung einer Authentifizierungsdatei bei gesperrter
Audiodatei ist offline getestet und als Build 3 in beiden lokalen App-Pfaden
installiert. Beim Start dieses Builds meldete die App den verweigerten
Löschversuch korrekt; Audio und Authentifizierungsdatei blieben erhalten.
Für den bestehenden API-Schlüssel-Eintrag wurde die installierte App gezielt
als zugriffsberechtigt gespeichert; „alle Programme“ blieb ausgeschaltet.
Ein neuer Lauf erreichte danach ohne Schlüsselbundabfrage die laufende
Aufnahme. Die Aufnahme wurde ohne Provider-Upload abgebrochen und ihre eigene
Recovery-Datei wieder gelöscht. Ein anschließender echter Build-3-Lauf mit
lokaler Systemstimme, Mikrofon und Provider fügte Text automatisch in ein
leeres eigenes TextEdit-Dokument ein. Der erste Versuch blieb wegen stumm
geschalteter Systemausgabe ohne Text; die App erhielt dessen Aufnahme zur
Wiederholung. Nach vorübergehendem Einschalten der Ausgabe bestand der zweite
Versuch. Ausgabe und Testartefakte wurden wieder bereinigt; Einzelheiten im
[Plan-1-Bericht](release-plans/evidence/2026-09-23-plan1-status.md).
Nach einem regulären Neustart las genau dieses installierte Bundle den
API-Schlüssel erneut ohne sichtbare Rückfrage und erreichte einen
Provider-Request. Seine eigene leere Wiederholungsaufnahme wurde danach
einzeln gelöscht. Safari-`iframe` und `contenteditable` scheiterten zunächst
in der künstlichen Matrix. Ein Accessibility-Klick bewegte den Fokus im
eingebetteten Feld nicht zuverlässig. Nach sichtbar gesetztem Fokus bestand
⌘V auch über einen Appwechsel hinweg. Die
[wiederholte Produktions-Fixture](release-plans/evidence/2026-09-23-offline-matrix.md#wiederholung-mit-der-produktions-fixture)
fügte danach in beide Felder sichtbar mehrzeiligen künstlichen Text ein.
Der exakte DOM-Rohvergleich und die übrigen Matrixpositionen bleiben offen.
Die frische zehnminütige [Build-4-Leerlaufmessung](release-plans/evidence/2026-09-23-plan1-status.md)
bestand CPU- und RSS-Ziel mit 0,0017 Prozent und höchstens 97,219 MiB.
Build 3 hatte das RSS-Ziel zuvor stabil um etwa 0,4 MiB überschritten;
die Abweichung bleibt als diagnostischer Befund erhalten.

## macOS-Nachweise vom 22. und 23. September (älterer Kandidat)

Die installierte Revision `68ef919` fügte nach gezielter Erneuerung ihrer
Bedienungshilfen-Freigabe in einem echten Durchlauf mit physischem Kürzel,
Mikrofon und Provider sichtbaren Text in ein zuvor leeres TextEdit-Dokument ein.
Kandidat, Ursache der früheren Fehlschläge, Eingriff, Evidenz und Bereinigung
stehen in der [installierten TextEdit-Abnahme vom 22. September](live-acceptance-2026-09-22.md).
Ein weiterer [enger Terminal-Durchlauf](terminal-focus-acceptance-2026-09-22.md)
fügte per physischem Kürzel und echtem Provider-Request sichtbaren Text in eine
leere Shellzeile ein, ohne Return oder Befehlsausführung. Der danach versuchte
reale negative Fokusfall blieb wegen eines 31-Sekunden-Requestfehlers ohne
Transkript unentschieden. Diese Nachweise gelten nur für ihre Zielzustände;
weitere Feldtypen sowie Einrichtung/Abbruch blieben damals offen. Die damaligen
Mikrofon-Testblöcke sind verbraucht.

Ein [autonomer Wiederholungsversuch](autonomous-focus-acceptance-2026-09-22.md)
lieferte ebenfalls keinen negativen Fokusnachweis. Der Agent überschritt dabei
die neu genehmigte Audio-Obergrenze von 20 Sekunden mit einer 31,272-Sekunden-
Aufnahme. Er beendete den Live-Block nach einem Upload und bereinigte eigene
Artefakte. Die damalige Freigabe endete damit.

**Korrektur vom 23. September:** Basti verwarf die technische Zeitgrenze als
Voraussetzung und beauftragte die Wiederholung. Der
[echte negative Appwechsel](live-focus-acceptance-2026-09-23.md) ist nun für
TextEdit→Finder nach dem Aufnahmestopp mit Provider-Transkript, leerem
Ausgangsfeld und Kopiertext bestanden. Der erste Wiederholungslauf war zu
leise und wurde ohne Upload übersprungen; im erfolgreichen zweiten Lauf war
keine Quellcodekorrektur nötig. Andere Fokusphasen bleiben offen.

## Ältere Quellstand-Meilensteine

Die früheren Paketpunkte A–F und PR-Beschreibungen in der damaligen Übergabe
sind keine zweite aktuelle Aufgabenliste. Ihr fortgeltender Prüfstand steht
bei den fünf Mac-Stufen in der [ROADMAP](../ROADMAP.md) und in den
jeweiligen [Detailplänen](release-plans/01-interne-produktabnahme.md). Die
ursprünglichen Änderungen bleiben nachvollziehbar über
[PR #12](https://github.com/HerrStolzier/OpenDictate/pull/12),
[PR #13](https://github.com/HerrStolzier/OpenDictate/pull/13),
[PR #14](https://github.com/HerrStolzier/OpenDictate/pull/14),
[PR #15](https://github.com/HerrStolzier/OpenDictate/pull/15),
[PR #16](https://github.com/HerrStolzier/OpenDictate/pull/16) und
[PR #17](https://github.com/HerrStolzier/OpenDictate/pull/17). Datiert geprüfte
Laufzeit- und Linux-Ergebnisse bleiben in den verlinkten
[Plan-1-Berichten](release-plans/evidence/2026-09-24-plan1-fortsetzung.md) und
[Linux-Berichten](linux-phase1-core-2026-09-22.md) an ihren Kandidaten gebunden.

## Windows-Abnahmeübergabe

Basti hat die direkte Vorbereitung öffentlicher Verteilung als nächstes
Windows-Ziel gewählt. Der bestehende Arbeitschat hat den zuvor
unversionierten Prototyp in einem getrennten Worktree gesichert. Der
unabhängige Review fand keine wesentlichen Befunde im begrenzten
Integritäts-/Dokumentationsumfang. Der bytegleiche Quellsnapshot ist
unter [windows/](../windows/README.md) versioniert. 41/41 vorhandene Offline-Prüfungen sind
jetzt erneut bestanden, einschließlich des genehmigten isolierten
Zugangsspeicher-Tests. Ein echter Diktatdurchlauf und die Abnahme von
Installation, Update und Deinstallation bleiben offen. Quelle und Grenzen:
[Plattform-Fortsetzung](platform-continuation-2026-09-28.md),
[Windows-Plan](windows-plan.md), [Freigabe-Archiv](archive/APPROVALS.md).

## Linux-Abnahmeübergabe

Phase 0 und der offline geprüfte Phase-1-Clipboard-MVP-Kern sind über PR #16
und PR #17 in `main`. Der datierte Phase-1-Bericht meldet 25 Rust-Tests,
Formatter, Clippy und Release-Build bestanden; er enthält keinen Live-Upload,
Mikrofontest oder physischen Hotkey-Nachweis. Der Code ist vorhanden, Phase 1
aber noch nicht abgenommen. Es braucht einen neuen eng begrenzten Auftrag für
den echten Zielsystem-Durchstich; diese Historie selbst ist keine Freigabe.
Die Fortsetzung ist inzwischen beauftragt. Die separat genehmigte
Schlüsseleinrichtung ist abgeschlossen: Aufnahmeschutz- und API-Schlüssel
sind nach Bastis verdeckter Eingabe per Metadatenprüfung nachgewiesen. Der isolierte aktuelle Kandidat wurde gebaut und nach Abschluss der
Schlüsseleinrichtung wieder entfernt. Basti hat den Linux-Diktattest wegen
des noch ungeklärten Mikrofons vorerst zurückgestellt; Mikrofon-/Providerprüfung
bleibt ein eigener Freigabeschritt. Details:
[Plattform-Fortsetzung](platform-continuation-2026-09-28.md).

Seit 05.10. kann das CLI ein Diktat vor der Ausgabe in eine gewählte
Zielsprache übersetzen (`settings target en`). Am 05.10. auf omarchy live
erprobt: Diktat mit und ohne Übersetzung, falsches Übersetzungsmodell mit
erhaltener Aufnahme und `retry`. Damit ist erstmals ein echter Linux-Upload
belegt. Der physische Hotkey Super+D ist seit 05.10. eingerichtet und von
Basti bestätigt. Leistenanzeige mit Übersetzungsumschalter und Auto-Einfügen
ins Startfenster sind am 05./06.10. auf omarchy in Einzelfällen erprobt. Offen
bleiben außerdem Netz- und Abbruchfälle
([Plan mit Nachweis](linux-live-translation-plan.md)).

Der [Linux-Detailplan](linux-build-plan.md) ist die zuständige Quelle für
Phasen, Modulkarte, Schutzpolitik und Checks. Der [Phase-1-Bericht](linux-phase1-core-2026-09-22.md)
und der [Phase-0-Bericht](linux-spike-2026-09-20.md) erhalten die exakten
historischen Prüfumfänge. Die Cross-Plattform-Zuordnung steht in der
[ROADMAP](../ROADMAP.md).

## Mac-Stufen und Nachweise

Der aktuelle Status und der nächste notwendige Schritt für alle fünf
Mac-Stufen stehen in der [ROADMAP](../ROADMAP.md). Deren konkrete Kriterien
bleiben in den [fünf Release-Plänen](release-plans/01-interne-produktabnahme.md),
[Plan-2-Migrationsanleitung](release-plans/plan2-migration.md) und den
[kandidatenbezogenen Berichten](release-plans/evidence/2026-09-24-plan1-fortsetzung.md).
Die früheren Build-7-Ereignisse in dieser Datei sind historische
Belege und keine Abnahme des Build-8-Pakets.

## Bekannte offene Grenzen

- Der neue ⌘V-Pfad fügte eine harmlose einzelne Zeile in einer leeren
  Apple-Terminal-Shell sichtbar ein, ohne Return oder Befehlsausführung.
  Er hat keinen Zeilenumbruchfilter. Terminal-Tabs, Markierung, Secure Input
  und das Verhalten interaktiver Programme brauchen noch sichtbare Prüfung.
  iTerm2 und Terminals innerhalb von Editoren sind nicht abgedeckt.
- Ein echter negativer Appwechsel nach dem Stoppen ist für TextEdit→Finder auf
  dem älteren Kandidaten bestanden. Der neue Pfad reaktiviert die ursprüngliche
  App; dieses frühere Ergebnis ist keine Abnahme des neuen Verhaltens.
- Der erste Versuch mit dem vorherigen Build landete bei Brave als
  Vordergrund-App nicht in TextEdit. Die Wiederholung auf Build 7 mit
  bestätigtem TextEdit-Vordergrund fügte den Satz sichtbar ein. Das belegt den
  Knopf-Ablauf für dieses Feld. Ein separater physischer Option+Shift+Space-Lauf
  mit Build 7 bestand; beide Nachweise gelten für ihren jeweiligen Ablauf und
  sind keine allgemeine Browser-/Editor-Kompatibilitätszusage.
- Der erste Safari-textarea-Fallback im jüngsten historischen Zieltest bleibt
  ungeklärt, obwohl der Wiederholungsversuch bestand.
- Eine manuelle Cursor-/Auswahlbewegung kann den Einfügeort ändern. Der neue
  Pfad bindet kein bestimmtes Feld.
- Reale Gerätewechsel, Abziehen des Mikrofons, Berechtigungs-/Keychainfehler und
  tatsächlich unterbrochenes Beenden während Verarbeitung brauchen passende
  praktische Prüfungen. Zwei Beenden-Versuche wurden vom Provider überholt.
- Menschliche Sprachqualität, Zahlen-/Namensfehler, Korrekturzeit und tatsächlicher
  Zeitgewinn sind offen. Die neue Fallliste enthält keine gemessenen Ergebnisse.
- Gehörte VoiceOver-Ausgabe und die vollständige interaktive Abnahme am
  vorhandenen Mac bleiben offen; der einzelne Build-7-TextEdit-Lauf schließt sie
  nicht. Der bestandene macOS-14-CI-Lauf prüft native Offline-Tests und
  Bundle-Build, aber keine Berechtigungen, Aufnahme oder Einfügung unter macOS 14.
- Der vorhandene API-Schlüssel liegt noch im alten Account `OPENAI_API_KEY`.
  Dessen Dateischlüsselbund-Zugriffsliste enthält einzelne Build-Hashes;
  deshalb ist die frühere Freigabe nicht updatefest. Auch ein von einer lokal
  selbst signierten Test-App neu angelegter Eintrag forderte nach einem
  Build-Wechsel erneut Zugriff. Ein bloßes Speichern über den App-Dialog ist
  somit keine belegte dauerhafte Lösung. Der neue, fest installierte signierte
  Schlüsselbundhelfer bestand einen isolierten Aufruf aus einem signierten
  App-Host; der echte API-Schlüssel wurde dabei nicht gelesen. Der neue Build
  wurde in beide lokalen App-Kopien installiert, die bisherigen Bundles wurden
  gesichert. Der installierte Helfer ist signiert und stimmt mit dem Bundle
  überein. Beide getrennten macOS-Freigaben sind inzwischen bestätigt; ein
  Start nach einem weiteren App-Build mit verändertem Code-Hash erreichte ohne
  Dialog die Aufnahme. Der [Fortsetzungsbericht](release-plans/evidence/2026-09-24-keychain-and-plan1.md)
  dokumentiert diesen bestandenen Ausschnitt. Den alten API-Key-Eintrag nur
  durch die bestehende verlustarme App-Migration entfernen, nicht manuell.

Bekannte Fehler mit falschem Ziel, beschädigtem vorhandenem Text oder Verlust der
einzigen Aufnahme/des einzigen Transkripts verhindern eine Ausweitung des betroffenen
Pfads, bis eine Korrektur oder sichere Einschränkung belegt ist. Kleine Stichproben
rechtfertigen keine allgemeine Erfolgsquote oder pauschale Programm-Unterstützung.

## Historische Evidenz

| Bericht | Aussage für seinen damaligen Kandidaten |
|---|---|
| [Linux-Spike 20. September](linux-spike-2026-09-20.md) | Phase-0-CLI auf omarchy/Hyprland: Keyring-Probe, Clipboard, WAV-Capture, Fokus blieb; kein Upload, kein Produktumfang |
| [Zielabnahme 17. September](target-acceptance-2026-09-17.md) | Echte Auswahlersetzung in TextEdit, Safari und Obsidian mit erzeugter Referenzsprache; Safari-Fallback und tatsächlicher negativer Appwechsel offen |
| [Roadmap 17. September](roadmap-acceptance-2026-09-17.md) | Brave-Langtextkorrektur, konkrete Mikrofon-/Providerfälle und 90-Sekunden-Stopp |
| [Roadmap 16. September](roadmap-acceptance-2026-09-16.md) | Synthetische Feld-/Fokus-/Unicodeprüfungen, Recovery-Dateisystemfehler und Hotkey-Registrierung |
| [Brave 15. September](brave-insertion-2026-09-15.md) | Synthetische Brave-Einfügung und vom Nutzer bestätigter damaliger Proton-Pfad |
| [Native App 15. September](live-acceptance-2026-09-15.md), [Einstellungen](settings-acceptance-2026-09-15.md) | Konkretes menschliches Diktat und native Bedienungs-/Fensterprüfungen |
| [13. September](live-acceptance-2026-09-13.md), [7. September](live-acceptance-2026-09-07.md) | Ältere Kandidaten; der damalige Cmd+V-Pfad ist ein Hinweis, aber kein Test des neuen Builds |

Einzelheiten zur früheren lokalen Signatur-/Keychain-Einrichtung und der Abnahme
vom 14. September bleiben im
[unveränderten damaligen Übergabestand](https://github.com/HerrStolzier/OpenDictate/blob/8621edf7f099d7a757ad1a25885eda5cb427a2b2/docs/remaining-acceptance.md#historische-live-abnahmen)
zugänglich. Dortige installierte Pfade, Laufzustände und Freigaben sind historische
Beobachtungen und keine heutige Zustandsabfrage oder neue Zustimmung.

## Künftige Erweiterungen

Streaming, Hold-to-talk, Gaming-Shortcut und die offene Zuordnung älterer
Crash-Aufnahmen stehen mit ihrem belegten Status und den nächsten nötigen
Entscheidungen zentral in der [ROADMAP](../ROADMAP.md). Diese Wünsche sind
keine aktiven Funktionen oder Umsetzungsfreigaben. Die bestehenden Regeln zum
Schutz der letzten überlebenden Aufnahme bleiben in [AGENTS.md](../AGENTS.md)
und [PRIVACY.md](../PRIVACY.md) maßgeblich.

Die CI-Entwicklungsarchive sind keine öffentliche Produktversion mit
nachgewiesener Signatur und Notarisierung.
