# Kompatibilitätsmatrix für Texteingabe und Fokus

Stand: 2026-09-23. Diese Matrix ist der aktuelle produktweite Abnahmeplan für
die Textübergabe. Programme dienen als repräsentative Beispiele ihrer Kategorie;
ein bestandener Lauf ist kein Versprechen für alle Programme derselben Kategorie.
Datierte Berichte bleiben die Quelle für den jeweils tatsächlich geprüften Kandidaten.

**Neuer Kandidat:** Automatisches Einfügen läuft wieder über die allgemeine
Zwischenablage und ⌘V in der zu Beginn erfassten App. Sie wird vor dem
Einfügebefehl aktiviert. Ein Feldwechsel kann den Einfügeort ändern; ein
Appwechsel nach dem Stoppen wird durch die Reaktivierung zurückgenommen.
Der neue Build `bd3630f` ist lokal installiert. Ein
[manueller TextEdit-⌘V-Test](installed-command-v-2026-09-23.md) bestand;
OpenDictates automatischer Diktatpfad ist damit nicht geprüft. Die folgenden
historischen AX-/Unicode-Nachweise gelten für ältere Kandidaten und müssen
für den neuen Einfügeweg sichtbar wiederholt werden.

Die [Terminal- und Fokusabnahme vom 22. September](terminal-focus-acceptance-2026-09-22.md)
belegt die sichtbare Eingabe in einer leeren Apple-Terminal-Shellzeile; der
beabsichtigte negative Fokusfall blieb wegen eines Providerfehlers unentschieden.
Ein späterer [realer TextEdit→Finder-Wechsel](live-focus-acceptance-2026-09-23.md)
nach dem Stoppen bestand mit Provider-Transkript, leerem Ausgangsfeld und
Kopiertext. Er prüft keinen Terminal-spezifischen Fokuswechsel.
Die [Zielabnahme vom 17. September](target-acceptance-2026-09-17.md) ergänzt echte
Auswahlersetzung in TextEdit, Safari und Obsidian. Die vorausgehende synthetische
und reale Abnahme steht im
[Bericht vom 17. September](roadmap-acceptance-2026-09-17.md). Sie ergänzt den
[Ausgangsstand vom 16. September](roadmap-acceptance-2026-09-16.md), dessen
Feldnachweise in der folgenden Tabelle historisch zusammengefasst sind.
Die jeweiligen Einzelfälle belegen keine vollständige Kategorie oder Phasenmatrix.

Die Stabilisierung in [PR #12](https://github.com/HerrStolzier/OpenDictate/pull/12)
ändert Rückmeldungen zu versuchter/unterbrochener Texteingabe und die Einrichtung.
Auf dem installierten Kandidaten `68ef919` wurden inzwischen die
[TextEdit-Einfügung](live-acceptance-2026-09-22.md) und der oben genannte enge
Terminal-Fall sowie der negative Appwechsel sichtbar geprüft. Eine begrenzte
erste Runde und ein früher
menschlicher Pilot sind in den
[vorbereiteten Fällen](audio-quality-fixtures.md#prepared-first-human-pilot)
beschrieben. Die historische Tabelle unten bleibt auf die dortigen Kandidaten
begrenzt; diese Vorbereitung erweitert ihre Nachweise nicht.

## Abdeckungsziel

| Kategorie | Repräsentative Beispiele | Zu prüfende Felder | Historische Evidenz, neuer Pfad offen |
|---|---|---|---|
| Native macOS-App | TextEdit; kontrollierter AppKit-Host | ein- und mehrzeiliges editierbares Feld | Neue echte Auswahlersetzung in TextEdit AXTextArea bestanden. Einzeilige native Felder und weitere Positionen bleiben synthetisch belegt. |
| Browser, einfaches Formular | Safari und Brave | `input`, `textarea` | Echte Auswahlersetzung in beiden Browsern bestanden; Brave textarea einschließlich 90-Sekunden-Autostopp. Safari textarea zunächst verlustfreier Fallback ungeklärter Ursache, Wiederholung bestanden. Chrome-Ersteinrichtung unverändert, Firefox fehlt. |
| Browser, Rich-Text | lokale Testseite; historische Proton-Abnahme | `contenteditable`, Auswahl und mehrzeiliger Inhalt | Echte Auswahlersetzung in Safari und Brave bestanden; Unicode-/Mehrzeilenfälle zusätzlich synthetisch. Echte Proton-Bestätigung gilt dem älteren Kandidaten. |
| Browser, eingebetteter Editor | lokale kontrollierte Testseite | editierbares Feld in einem `iframe` | Echte Auswahlersetzung in Safari und Brave bestanden; synthetisch auch Unicode/Umfeld geprüft. |
| Electron-App | Obsidian 1.13.7, temporärer separater Vault | Editorfeld | Neue echte Auswahlersetzung in Obsidian CodeMirror mit erhaltenem Anfang/Ende bestanden. Anfang/Mitte/Ende und Unicode zusätzlich synthetisch belegt. Keine Zusage für andere Electron-Apps. |
| Apple Terminal, enger Unicode-Pfad | macOS Terminal (`com.apple.Terminal`) | Fokussierte `AXTextArea` ohne erfassten `AXWebArea`-Vorfahren; keine nichtleere Display-Auswahl | Ein echter Hotkey-/Mikrofon-/Provider-Lauf fügte eine harmlose Zeile sichtbar und ohne Return ein; AX-Ziel und leere Auswahl geprüft. Tabs, Auswahl und Fokuswechsel bleiben offen. Keine Zusage für iTerm2 oder Editor-Terminals. |
| Geschütztes oder nicht unterstütztes Feld | native und Brave-Testfelder | Passwortfeld, schreibgeschütztes Feld | Sichtbar abgelehnt, Felder unverändert; vollständiger Text im manuellen Panel und auf isolierter Testzwischenablage. Fehlende Berechtigung zusätzlich offline geprüft, kein TCC-Eingriff. |

## Gemeinsame Szenarien

Am 17. September zusätzlich exakt geprüft: Brave-`textarea` mit 28.199
UTF-16-Einheiten nach Behebung verlorener, mit Zeilenumbruch beginnender Chunks
(1.500 Events). Ein nativer Feldwechsel während zehn Sekunden simulierter
Aufnahme verhindert die automatische Eingabe und erhält den vollständigen
Kopiertext. Kurze Brave-LF- und CRLF-/Leerzeilenproben bestanden nach ungestörter
GUI-Prüfung exakt (46 UTF-16-Einheiten/3 Chunks beziehungsweise 21 DOM-normalisierte
UTF-16-Einheiten/2 Chunks). Frühere durch parallele Bedienung beeinflusste Läufe
werden nicht als Fehler oder Erfolg gewertet.

Aktuell sichtbar belegt: nativer Feldwechsel, Brave-Tabwechsel und Safari-
Fensterwechsel während synthetischer Verarbeitung sowie App-Wechsel während
laufender Safari-Unicode-Chunks, jeweils mit vollständigem Kopiertext.
Anfang/Ende wurden für native Felder, Safari-Feldtypen und Obsidian ergänzt.
Safari-textarea ist zusätzlich mit 28.199 UTF-16-Zeichen sowie CRLF/Leerzeilen
exakt geprüft; führende Zeilenumbrüche benötigen dort eigene Unicode-Events.
Prozess-, Fenster-, Feld-, Dokument- und Selektionswechsel sowie Chunk-Abbruch
sind zusätzlich offline geprüft. Alle Phasen-/Kategorie-Kombinationen sind damit
nicht vollständig abgenommen. Reale Aufnahme/Provider sind am 17. September für
die vier Brave-Feldtypen mit erzeugter Referenz über Lautsprecher und Mikrofon
belegt; damit ist weder ein menschlicher Sprachkorpus noch jede Fokusphase belegt.
Die damaligen nativen Fehlversuche sind durch eine spätere echte TextEdit-Abnahme
ergänzt; ebenso bestehen nun konkrete reale Safari- und Obsidian-Fälle. Der neue
beabsichtigte Safari→TextEdit-Wechsel während Aufnahme war dagegen nicht als
tatsächlicher Vordergrundwechsel nachweisbar: Safari erhielt Text, TextEdit blieb
unverändert. Das schließt den negativen Fokusfall nicht und belegt keinen
Produktfehler. Zusätzlich bestanden zwei synthetische Safari-Tabwechsel zur
sichtbaren Startseite während zehn Sekunden simulierter Aufnahme und fünf
Sekunden Verarbeitung: `textAvailable`, vollständiger Kopiertext, 0/4 Chunks und
unverändertes Ausgangsfeld. Weitere versuchte synthetische Appwechsel waren nicht
zuverlässig aktiviert und werden nicht als bestanden gewertet.

Am 23. September bestand ein echter TextEdit→Finder-Wechsel nach dem
Aufnahmestopp: Finder war während der Provider-Verarbeitung und zur
Einfügeentscheidung vorne, TextEdit blieb leer und das Transkript wurde
kopiert. Der erste, zu leise Lauf wurde ohne Upload übersprungen. Der
[Bericht](live-focus-acceptance-2026-09-23.md) begrenzt diesen Nachweis auf
genau diese Phase und den installierten Kandidaten.

Die normalen editierbaren Feldkategorien werden nicht nur mit einem leeren Feld
geprüft. Für Apple Terminal gelten die gesonderten Grenzen im nächsten Abschnitt;
Auswahlersetzung und mehrzeilige Eingabe sind dort keine Abnahmekriterien.

1. Einfügen an Anfang, Mitte und Ende der aktuellen Cursorposition.
2. Eine bestehende Auswahl ersetzen, ohne Text davor oder danach zu verändern.
3. Mehrzeiligen Unicode-Text mit Umlauten, kombinierenden Zeichen und Emoji exakt
   übernehmen. Lange Texte müssen ihre Chunk-Grenzen unverändert überstehen.
4. Während Aufnahme und Verarbeitung App, Fenster, Feld oder Browser-Tab
   wechseln. Prüfen, welches Feld nach der Reaktivierung der ursprünglichen App
   den ⌘V-Befehl erhält. Die Änderung des Einfügeorts ist eine bewusste Grenze.
5. Fehlende Accessibility-Berechtigung, fehlende App oder zwischenzeitlich
   geänderte Zwischenablage: kein Einfügebefehl. Das vollständige Transkript
   bleibt verfügbar, sofern die Zwischenablage nicht von außen überschrieben wurde.

## Apple Terminal (historischer Sonderpfad)

Die folgenden Details beschreiben den entfernten Unicode-Sonderpfad und gelten
nicht für den neuen ⌘V-Kandidaten. Dessen Terminal-Verhalten und insbesondere
Zeilenumbrüche sind ungetestet. Die Anwendung ist Apple Terminal; die installierte Revision des gemeldeten
Fehlers ist weiterhin unbekannt. Die neue Ausnahme lockert ausschließlich hier
die sonstige Voraussetzung eines setzbaren `AXSelectedText`. Sie verwendet
Unicode-Events, auch wenn das Attribut setzbar wäre. Ein als deaktiviert oder
geschützt gemeldetes Feld, nichtleere Display-Auswahl und aktives Secure Input
verhindern diese Übergabe. Vor dem ersten Event wird eine bei Aufnahmebeginn
erfasste Auswahlposition erneut verglichen; während der Übergabe darf sich eine
leere Display-Position bewegen, eine nichtleere Auswahl stoppt weitere Chunks.
App, Fenster, AX-Feld, Berechtigung und Secure Input werden weiter geprüft.
Ob Terminal seine Tabs durch unterscheidbare AX-Felder abbildet, ist noch offen.

Der vollständige einzufügende Text wird vor dem ersten Chunk auf Zeilenumbrüche,
Steuerzeichen und AppKit-Funktionstastenzeichen geprüft und gegebenenfalls
abgelehnt. Das ist keine Erkennung eines Shell-Prompts oder laufenden Programms:
Auch gewöhnliche Zeichen können in interaktiven Programmen Aktionen auslösen.
Gesendete Events bestätigen noch keine sichtbare Eingabe.

Der [echte Ein-Zeilen-Lauf](terminal-focus-acceptance-2026-09-22.md) prüfte
Kandidat, fokussierte `AXTextArea`, leere Auswahl und sichtbare Eingabe ohne
Return. Er führte **keinen Befehl aus**. Weitere Terminal-Fälle wie Tabs,
markierter Text und verlustfreier Rückweg bleiben offen. Dafür gilt weiterhin
der begrenzte Ablauf in [CHECKS](../CHECKS.md#apple-terminal); die bisherige
Matrix-Fixture bietet Apple Terminal nicht als Ziel an.

## Abnahmekriterium je Zelle

Eine Zelle gilt erst als produktnah belegt, wenn der installierte Kandidat den
gesamten Ablauf Mikrofon → Transkription → Zielübergabe mit unkritischem Testtext
durchlaufen hat und das sichtbare Endergebnis geprüft wurde. Feldinhalt vorher und
nachher, Cursor/Auswahl, Vordergrundziel und Rückweg werden festgehalten. Offline-
Tests oder ein synthetischer Produktionseinfüger belegen nur ihre eigene Schicht.

Private Entwürfe, Kontoinhalte und echte Nachrichten sind keine Testfixtures.
Fehlschläge werden nach Feldtyp und Situation dokumentiert, nicht als pauschale
Inkompatibilität eines ganzen Programms. Eine Kategorie erhält keine allgemeine
Supportaussage aus einem einzelnen Beispiel.

## Priorität

1. Auf dem neuen Kandidaten normale ⌘V-Eingabe in repräsentativen Feldern und die Wirkung von Fokuswechseln sichtbar prüfen; danach menschliche Diktate samt physischem Tastenkürzel und Korrekturaufwand auswerten.
2. Eine begrenzte Runde der offenen Fokus-, Aufnahme-, Abbruch-, Geräte- und Recoveryfälle nach Risiko und Pilotbefund durchführen.
3. Die breitere Matrix einschließlich VoiceOver und verbleibender Plattform-/Feldkombinationen systematisch ergänzen; fehlende Fälle bleiben ausdrücklich offen.

Streaming und Hold-to-talk bleiben zurückgestellt. Diese Matrix sagt keine
Windows-/Linux-Version und keine öffentliche Veröffentlichung zu.

## Bestehende Nachweise

- [Negativer Appwechsel vom 23. September](live-focus-acceptance-2026-09-23.md):
  echter TextEdit→Finder-Wechsel nach dem Stoppen, Provider-Transkript kopiert,
  Ausgangsfeld leer, ohne neue Quellcodeänderung.
- [Ergänzende Zielabnahme vom 17. September](target-acceptance-2026-09-17.md):
  TextEdit, vier Safari-Feldtypen und Obsidian real geprüft, samt ungeklärtem
  Safari-Fallback und nicht nachgewiesenem echten Appwechsel.
- [Abnahme vom 17. September](roadmap-acceptance-2026-09-17.md): Brave-Langtextkorrektur,
  synthetischer Feldwechsel in der Aufnahmephase, vier reale Brave-Feldtypen,
  90-Sekunden-Autostopp und begrenzte CPU-/RSS-Messungen samt offenen Grenzen.
- [Brave-/Proton-Bericht](brave-insertion-2026-09-15.md): synthetischer
  Produktionseinfüger, Unicode/Auswahl in der lokalen Brave-Testseite und
  ausdrückliche Proton-Nutzerbestätigung samt Grenzen.
- [Native Abnahme vom 15. September](live-acceptance-2026-09-15.md): echter,
  sichtbar geprüfter TextEdit-Durchlauf samt Kandidat und Grenzen.
- [Ältere Live-Abnahme](live-acceptance-2026-09-07.md): historischer `Cmd+V`-Pfad;
  kein Nachweis für die heutige direkte Einfügelogik.
