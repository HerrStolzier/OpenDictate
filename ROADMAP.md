# OpenDictate Roadmap

Stand: 8. Oktober 2026. Geprüfter Ausgangspunkt: `main`
`cdd4b7f` (7. Oktober). Begründung dieser Ordnung:
[Neuordnung vom 8. Oktober](docs/roadmap-neuordnung-2026-10-08.md).

Diese Datei ist die **einzige laufende Feature- und Plattform-To-do-Liste**.
Sie hält je Plattform den belegten Stand, die nächsten Schritte in Reihenfolge
und die Grenzen fest, die bewusst den Beta-Nutzern überlassen werden. Sie
setzt keinen Termin und erteilt keine technische, Kosten-, Test- oder
Veröffentlichungsfreigabe.

Zuständigkeiten: [PROJECT.md](PROJECT.md) beschreibt Produkt, Anwendungsfälle,
Preismodell und Entscheidungen; [docs/remaining-acceptance.md](docs/remaining-acceptance.md)
hält den belegten Stand je Plattform mit Nachweisen fest; [CHECKS.md](CHECKS.md)
die Prüfwege. Die Detailpläne der Plattformen enthalten ihre konkreten
Arbeitsschritte und Prüfkriterien.

## Grundsätze seit dem 8. Oktober 2026

- **Fünf Tracks parallel.** Linux, macOS, Windows, iOS und Android werden als
  eigene Tracks vorangetrieben, weil alle für eine Beta gebraucht werden. Die
  Regel „eine Plattform zur Zeit“ vom 2. Oktober gilt nicht mehr.
- **Jeder Track endet in einer Beta** mit fremden Nutzern: GitHub Pre-Release
  mit Kennzeichnung „Beta“, GitHub Issues mit der Vorlage „Beta-Rückmeldung“ als
  einziger Feedback-Kanal, ein bis drei Ankündigungsorte je Plattform.
- **Einzelfall-Live-Tests übernehmen Beta-Nutzer.** Wir prüfen selbst nur den
  Weg, den jeder Nutzer durchläuft: Installation und ein echtes Diktat. Alles
  Weitere (einzelne Programme, Randfälle, Sprachmischungen) steht als bekannte
  Grenze in der jeweiligen Anleitung und wird nach Rückmeldung behoben. Die
  Go-Regel für Live-Tests in [AGENTS](AGENTS.md#required-verification) bleibt.
- **Jede Veröffentlichung und jede Ankündigung braucht Bastis ausdrückliches
  Go.** Nichts in dieser Datei ist eine solche Freigabe.
- **Erledigtes wandert ins [Log](#erledigt) am Ende**, mit Datum und Link,
  statt in den Tracks stehen zu bleiben.

## Track Linux

**Ziel der Beta:** Omarchy-/Hyprland-Nutzer installieren das CLI, diktieren
mit Super+D in ihr aktives Fenster, wahlweise mit Übersetzung, und melden
Probleme über GitHub Issues.

**Stand:** Phase 1 (Clipboard-MVP) ist seit dem 5. bis 7. Oktober auf omarchy
belegt: Aufnahme, Keyring, Upload, Übersetzung, Zwischenablage, Fehler- und
Abbruchfälle mit erhaltener Aufnahme und `retry`, physischer Hotkey Super+D,
Leistenanzeige mit Zielsprachen-Umschalter. Phase 2 (Auto-Einfügen in das beim
Start erfasste Fenster, mit Fokus- und Zwischenablage-Prüfung) ist Standard und
in Editor und Terminal erprobt. Basti nutzt es seit dem 7. Oktober im Alltag.
Nachweise: [Live-Nachweise 5. bis 7. Oktober](docs/linux-live-2026-10-05-bis-07.md),
[Linux-Detailplan](docs/linux-build-plan.md).

**Nächste Schritte:**

1. Ehrliche Anleitung in [linux/README.md](linux/README.md): Preis pro Minute,
   „fehlgeschlagene Diktate bleiben für `retry` erhalten“, und die bekannten
   Grenzen unten. Reine Doku.
2. Paketierung (Phase 3 des Detailplans): ein installierbarer Weg auf
   Arch/omarchy, dokumentiert und einmal von Basti nachvollzogen. Ohne das kann
   niemand testen.
3. Linux-Beta: Pre-Release, Issue-Vorlage, Ankündigung (Kandidaten: r/omarchy,
   r/hyprland). Go je Veröffentlichung und Ankündigung.
4. Beta laufen lassen: Issues zeitnah beantworten, Rückmeldungen sammeln,
   danach entscheiden, was gebaut wird (Kandidaten: konfigurierbarer Endpunkt,
   Vokabular, Echtzeit-Übersetzung, Feinjustierung der Zeitlimits).

**Bekannte Grenzen, den Beta-Nutzern überlassen:** Einfügen in Chromium-,
Electron- und Discord-Fenstern; gemischtes Deutsch/Englisch mit Übersetzung;
Abbruch und Netzausfall genau während der Übersetzung; die seit PR #51
kürzeren Zeitlimits (nur offline geprüft); nur Hyprland, kein anderer
Compositor; nur Arch/omarchy.

## Track macOS

**Ziel der Beta:** Mac-Nutzer (Apple Silicon, macOS 14+) laden das notarisierte
Paket, richten ihren Schlüssel ein, diktieren mit Option+Shift+Leertaste,
wahlweise mit Übersetzung, und melden Probleme über GitHub Issues.

**Stand:** Stufe 1 (interne Funktionsabnahme) am 24. September abgeschlossen.
Stufe 2: Build 8 aus `b786d4c` ist von Apple notarisiert, das finale ZIP samt
Manifest geprüft (SHA-256 `2e994cd8…e335768`) und in der privaten
Release-Draft `v0.1.0-beta.8` hinterlegt. Teil B am 8. Oktober: installiert,
erster Start mit Quarantäne und ein Diktat mit automatischem Einfügen bestanden
([Nachweis](docs/release-plans/evidence/2026-10-08-plan2-teil-b.md)). Übersetzung und die kleinen Punkte vom 7. Oktober sind im Code und
offline geprüft ([Stand](docs/remaining-acceptance.md#macos)); ein echtes
Diktat damit fehlt. Die Stufenpläne unter
[docs/release-plans/](docs/release-plans/01-interne-produktabnahme.md) bleiben
die Quelle der Prüfkriterien; ihr Umfang ist am 8. Oktober wie unten verkleinert.

**Nächste Schritte:**

1. Übersetzung und die kleinen Punkte vom 7. Oktober: umgesetzt und offline
   geprüft. Offen ist nur der Live-Nachweis im nächsten Kandidaten: ein Diktat
   mit Übersetzung nach Englisch und die Dateirechte `0600` der
   Originalaufnahme während der Aufnahme.
2. Neuen Kandidaten bauen, signieren, notarisieren und einfrieren (Stufe 4 im
   verkleinerten Umfang: Hash, Installation und Update geprüft, Produkttexte in
   README, Website und App stimmen überein). Stufe 3 (Eigennutzung) schrumpft
   auf: Basti nutzt den Kandidaten so lange selbst, bis er ihm vertraut; der
   Messbogen ist optional. Die vollständige UX- und VoiceOver-Prüfung wird zur
   bekannten Grenze der Beta.
3. Mac-Beta (bisher Stufen 5 und 6): Pre-Release, Website mit „Beta“,
   [Installationsanleitung](docs/release-plans/installationsanleitung.md),
   Ankündigung (Kandidaten: Show HN, r/macapps, Mastodon/X).
4. Beta laufen lassen und antworten.

**Bekannte Grenzen, den Beta-Nutzern überlassen:** Feldtypen und Programme
jenseits der [Kompatibilitätsmatrix](docs/compatibility-matrix.md); gehörte
VoiceOver-Ausgabe; frische Ersteinrichtung in einem neuen macOS-Konto;
Beenden der App, während OpenAI noch transkribiert (nur ohne Netz geprüft;
live antwortete OpenAI in zwei Versuchen vor der Bestätigung); Intel-Macs sind
nicht Teil der ersten Beta.

## Track Windows

**Ziel der Beta:** Windows-Nutzer installieren eine signierte App, diktieren
mit einem Zwei-Tasten-Kürzel in Editor, Browser und Spielchat (siehe
Anwendungsfall Gaming in [PROJECT](PROJECT.md#anwendungsfälle)) und melden
Probleme über GitHub Issues.

**Stand:** Der Prototyp unter [windows/](windows/README.md) besteht 41 von 41
Offline-Prüfungen und beide Builds (28. September). Modell ist fest
`gpt-transcribe`, ohne Sprache, Prompt und Übersetzung. Kein echtes Diktat,
keine Paketierung, keine Signatur. Details: [Windows-Plan](docs/windows-plan.md),
[Releaseplan](windows/RELEASE-PLAN.md).

**Nächste Schritte:**

1. Modell und Sprache aus den Einstellungen statt fest; Übersetzung wie auf
   Linux; Provider-Tests gegen die gemeinsamen Fixtures (siehe
   Plattformübergreifend).
2. Ein echtes Diktat auf dem Windows-PC mit Bastis Go: Installation, Mikrofon,
   Upload, Einfügen in den Editor und in den Spielchat im Vollbild. Einmal,
   als Installationsprüfung.
3. Paketierung und Signatur nach dem Releaseplan. Abhängigkeit: ein
   Signierzugang für Windows ist noch nicht vorhanden; ohne Signatur warnt
   Windows jeden Nutzer beim Start.
4. Windows-Beta: Pre-Release, Issue-Vorlage, Ankündigung.

**Bekannte Grenzen, den Beta-Nutzern überlassen:** Programme jenseits von
Editor, Chrome-Testprofil und dem einen geprüften Spiel; Update- und
Deinstallationsweg; Verhalten mit anderen Spracheingaben wie Voice Access.

## Track iOS

**Ziel der Beta:** iPhone-Nutzer starten die Aufnahme über die Aktionstaste
oder die App, bekommen den (wahlweise übersetzten) Text in die Zwischenablage
und fügen ihn in der Ziel-App ein. Verteilung über TestFlight.

**Stand:** Der Tastatur-Prototyp besteht den synthetischen Safari-Textpfad auf
Simulator und iPhone 15 (29./30. September, [Nachweis](docs/ios-device-2026-09-30.md));
echte Aufnahme und Transkription sind nicht belegt. Draft-PR #40 bleibt
erhalten. Die Einschätzung vom 2. Oktober gilt weiter: Tastatur-Erweiterungen
dürfen nicht aufnehmen, eine Vollzugriff-Tastatur mit Netzwerk und Schlüssel
ist ein Review- und Vertrauensrisiko; die Nutzerrecherche vom 8. Oktober
bestätigt beides und zeigt den Zwischenablage-Weg als gangbar
([Richtung](docs/ios-direction.md), [Neuordnung](docs/roadmap-neuordnung-2026-10-08.md)).

**Nächste Schritte:**

1. Produktkonzept auf einer Seite festlegen: Host-App mit Aufnahme, Start über
   Aktionstaste oder Kurzbefehl, Ergebnis in die Zwischenablage, Hinweis per
   Live-Aktivität; keine Vollzugriff-Tastatur. Übersetzung als Merkmal.
2. Echte Aufnahme und Transkription in der Host-App auf dem iPhone 15 mit
   Bastis Go.
3. TestFlight-Beta. Abhängigkeit: Apple-Developer-Mitgliedschaft (vorhanden,
   Verlängerung September 2027) und Xcode auf dem Mac.

**Bekannte Grenzen, den Beta-Nutzern überlassen:** Einfügen in einzelne Apps,
Hintergrundverhalten, Datenschutz-Dialoge in iOS-Versionen, die nicht
getestet wurden.

## Track Android

**Ziel der Beta:** Android-Nutzer installieren eine Tastatur mit Mikrofon-Taste,
diktieren in jede App, wahlweise mit Übersetzung, und melden Probleme über
GitHub Issues. Verteilung als interner Test in Google Play oder als APK.

**Stand:** Kein Code, kein Plan. Android erlaubt eigene Tastaturen mit
Mikrofon, anders als iOS; die Nutzerrecherche vom 8. Oktober zeigt Bedarf an
Mehrsprachigkeit ohne Umschalten, Datenschutz und schnellem Zugriff.

**Nächste Schritte:**

1. Produktkonzept auf einer Seite: Tastatur mit Mikrofon-Taste oder schwebende
   Blase, Übersetzung, Schlüssel im Android-Keystore, dieselben
   Audio-/Recovery-Regeln wie überall.
2. Prototyp: Aufnahme, Upload, Einfügen über die Tastatur in eine beliebige App.
3. Android-Beta. Abhängigkeit: Google-Play-Entwicklerkonto (nicht vorhanden)
   oder APK-Verteilung mit Anleitung.

## Plattformübergreifend

| Punkt | Stand | Nächster Schritt |
| --- | --- | --- |
| Preismodell | Am 8. Oktober entschieden ([PROJECT](PROJECT.md#preismodell)): offener Code, CLI-Builds gratis, fertige App mit UI einmalig bezahlt; bis zur Firmengründung bleibt alles kostenlos. | Vor der ersten bezahlten Version: Firmengründung, Bezahlweg, Preis festlegen. Keine Beta hängt daran. |
| Gaming | Ursprungs-Anwendungsfall ([PROJECT](PROJECT.md#anwendungsfälle)). Belegt: Textchat in World of Warcraft mit der Mac-App. Offen: Einfügen im exklusiven Vollbild, Zwei-Tasten-Kürzel auf jeder Plattform, Einzeltaste oder Halten-zum-Sprechen. | Im Windows-Track Schritt 2 prüfen. Vor einer Gaming-Botschaft per Blizzard-Ticket klären, dass externe Diktier-Software geduldet ist. Hold-to-talk und Einzeltaste nach Beta-Rückmeldung bauen. |
| Konfigurierbarer Endpunkt | Am 2. Oktober für macOS spezifiziert ([Plan-4-Notiz](docs/plan4-aenderungen-2026-10-02.md)); seit dem 8. Oktober für alle Plattformen gewünscht, als Antwort auf den Wunsch nach lokaler Verarbeitung. | Mac mit dem nächsten Kandidaten; Linux und Windows nach ihrer ersten Beta. Nur die Adresse, `http://` nur für Loopback; eine Fremd-URL wird nicht abgenommen. |
| Provider-Vertrag | Am 2. Oktober entschieden: gemeinsame Fixtures unter `fixtures/provider/` für Swift, Rust und C#. Nicht begonnen. | Mac-Teil mit dem nächsten Kandidaten; Linux `validate_model` wie Mac; Windows mit Schritt 1 seines Tracks. |
| Markenidentität 1.1 | Langfristiges Ziel vom 29. September ([PROJECT](PROJECT.md#marken--und-gestaltungsrichtung)). | Beginnt nach der ersten Beta (Linux oder Mac) und blockiert keine Beta. Richtung mit Basti anhand echter App-Zustände und eines Marketingbeispiels festlegen. |
| Vokabular | Mac hat „Vokabular und Kontext“; Linux und Windows nicht. Laut Recherche häufiger Wunsch. | Nach der ersten Beta-Rückmeldung je Plattform nachziehen. |
| Echtzeit-Übersetzung und Streaming | Weg C (`gpt-realtime-translate`) ist recherchiert, nicht gebaut ([Plan](docs/linux-live-translation-plan.md)). Streaming beim Diktieren ist seit dem 26. September gewünscht. Beides widerspricht der Regel, unbestätigte Teilergebnisse nicht ins Zielfeld zu schreiben, und braucht eigene Akzeptanzkriterien. | Erst nach Beta-Rückmeldung, dass die Wartezeit von Weg A stört. |
| Zielsprache je Anwendung | Idee aus der Recherche, nicht beauftragt. | Keiner. |
| Verbrauchsanzeige in der App | Wunsch von Basti vom 8. Oktober: Nutzer sollen ihren Verbrauch (zum Beispiel pro Tag) direkt in der App sehen, ohne sich im Dashboard des Anbieters anzumelden, ähnlich den Verbrauchsmodulen anderer Plattformen. Nicht beauftragt. Zwei Wege sind denkbar: lokal mitzählen (Audiosekunden je Diktat mal Listenpreis des gewählten Modells, Übersetzungs-Tokens aus der `usage`-Antwort) oder die Verbrauchs- und Kostenschnittstelle des Anbieters abfragen, die nach aktuellem Stand einen Admin-Schlüssel statt des normalen API-Schlüssels verlangt. | Nach der ersten Beta je Plattform entscheiden; lokales Mitzählen ist der wahrscheinlichere Weg, weil es mit dem vorhandenen Schlüssel auskommt. Preise als änderbare Tabelle, Zähler lokal und ohne Transkripte; Datenfluss in `PRIVACY.md` nachziehen. |
| Support-Backend | Am 8. Oktober entschieden ([PROJECT](PROJECT.md#entscheidungen)): eigenes kleines Backend statt fertiger Ticketsoftware. Die erste Version ist als Entwurf in einem eigenen privaten Repository gebaut und offline getestet; der Livegang wartet auf die neue Marke. Kontaktformular und Supportadresse werden Tickets, ein Dashboard nur für Basti, ein Agent sortiert und schreibt nur Entwürfe, Basti entscheidet und versendet. Die Website bleibt statisch; das Formular schickt nur an das Backend. | Vor dem Livegang fehlen Domain und Supportadresse, Impressum und Datenschutzerklärung auf der Website, Auftragsverarbeitung mit dem KI-Anbieter und ein Abschnitt zum Supportweg in `PRIVACY.md`. KI-Chatbot später als weiterer Eingang. |
| Alte verwaiste Audiooriginale nach Absturz | Sichere Zuordnung und Wiederherstellung historischer temporärer Dateien sind offen. Regel: die einzige überlebende Aufnahme nie blind löschen. | Eigentum, Erkennung, Ablauf und Wiederherstellung festlegen, bevor Bereinigung automatisiert wird; mit Verlust- und Manipulationsfällen abnehmen. |

## Erledigt

| Datum | Ergebnis | Nachweis |
| --- | --- | --- |
| 8. Oktober 2026 | macOS Stufe 2 Teil B: Build 8 installiert, erster Start mit Quarantäne, Diktat mit Einfügen. Beenden während der Transkription als bekannte Grenze eingetragen. | [Nachweis](docs/release-plans/evidence/2026-10-08-plan2-teil-b.md) |
| 7. Oktober 2026 | Linux: Abbruch und Netzausfall während der Transkription behalten die Aufnahme; Zeitlimits auf Sekunden statt zwei Minuten (PR #51). | [Live-Nachweise](docs/linux-live-2026-10-05-bis-07.md) |
| 7. Oktober 2026 | macOS: temporäre Aufnahmen tragen `0600`, live geprüft (PR #49); Löschfehler nur einmal pro Start geloggt (PR #50); die alte Aufnahme vom 15. September ist gelöscht. | [Stand macOS](docs/remaining-acceptance.md#macos) |
| 5. bis 6. Oktober 2026 | Linux: Übersetzung nach dem Sprechen, Leistenanzeige, Auto-Einfügen, Hotkey Super+D (PR #45, #47). Phase 1 damit belegt. | [Live-Nachweise](docs/linux-live-2026-10-05-bis-07.md) |
| 5. Oktober 2026 | Aus dem Branch `rescue/grok-clone-2026-09` drei Härtungen übernommen (PR #46); Rest bleibt liegen. | [PROJECT](PROJECT.md#entscheidungen) |
| 2. Oktober 2026 | Zielgruppe und Kostenargument in PROJECT, README und Website festgeschrieben. Offen bleibt nur das „ca.“ im Modellmenü (Mac-Track). | [Plan-4-Notiz](docs/plan4-aenderungen-2026-10-02.md) |
| 2. Oktober 2026 | macOS Build 8 notarisiert, finales Paket geprüft. | [Nachweis](docs/release-plans/evidence/2026-10-02-plan2-build8-final.md) |
| 28. September 2026 | Code-Reduktionsversuch: fünf Zeilen weniger, Coverage ohne Verlust; das 10%-Ziel wurde nicht erreicht und nicht erzwungen. | [Bewertung](docs/code-reduction-2026-09-28.md), [Projekt-Audit](docs/project-audit-2026-09-28.md) |
| 24. September 2026 | macOS Stufe 1 (interne Funktionsabnahme) abgeschlossen. | [Plan-1-Bericht](docs/release-plans/evidence/2026-09-24-plan1-fortsetzung.md) |
