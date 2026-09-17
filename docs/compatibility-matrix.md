# Kompatibilitätsmatrix für Texteingabe und Fokus

Stand: 2026-09-17. Diese Matrix ist der aktuelle produktweite Abnahmeplan für
die Textübergabe. Programme dienen als repräsentative Beispiele ihrer Kategorie;
ein bestandener Lauf ist kein Versprechen für alle Programme derselben Kategorie.
Datierte Berichte bleiben die Quelle für den jeweils tatsächlich geprüften Kandidaten.

Die neueste [Zielabnahme](target-acceptance-2026-09-17.md) ergänzt echte
Auswahlersetzung in TextEdit, Safari und Obsidian; der negative reale Appwechsel
bleibt unbelegt. Die vorausgehende synthetische und reale Abnahme steht im
[Bericht vom 17. September](roadmap-acceptance-2026-09-17.md). Sie ergänzt den
[Ausgangsstand vom 16. September](roadmap-acceptance-2026-09-16.md), dessen
Feldnachweise in der folgenden Tabelle historisch zusammengefasst sind.
Die jeweiligen Einzelfälle belegen keine vollständige Kategorie oder Phasenmatrix.

Die Stabilisierung in [PR #12](https://github.com/HerrStolzier/OpenDictate/pull/12)
ändert Rückmeldungen zu versuchter/unterbrochener Texteingabe und die Einrichtung.
Für diesen neuen Quellcodestand liegen noch keine neuen sichtbaren Mac-Abnahmen
vor. Eine begrenzte erste Runde und ein früher menschlicher Pilot sind in den
[vorbereiteten Fällen](audio-quality-fixtures.md#prepared-first-human-pilot)
beschrieben. Die historische Tabelle unten bleibt auf die dortigen Kandidaten
begrenzt; diese Vorbereitung erweitert ihre Nachweise nicht.

## Abdeckungsziel

| Kategorie | Repräsentative Beispiele | Zu prüfende Felder | Aktuelle Evidenz |
|---|---|---|---|
| Native macOS-App | TextEdit; kontrollierter AppKit-Host | ein- und mehrzeiliges editierbares Feld | Neue echte Auswahlersetzung in TextEdit AXTextArea bestanden. Einzeilige native Felder und weitere Positionen bleiben synthetisch belegt. |
| Browser, einfaches Formular | Safari und Brave | `input`, `textarea` | Echte Auswahlersetzung in beiden Browsern bestanden; Brave textarea einschließlich 90-Sekunden-Autostopp. Safari textarea zunächst verlustfreier Fallback ungeklärter Ursache, Wiederholung bestanden. Chrome-Ersteinrichtung unverändert, Firefox fehlt. |
| Browser, Rich-Text | lokale Testseite; historische Proton-Abnahme | `contenteditable`, Auswahl und mehrzeiliger Inhalt | Echte Auswahlersetzung in Safari und Brave bestanden; Unicode-/Mehrzeilenfälle zusätzlich synthetisch. Echte Proton-Bestätigung gilt dem älteren Kandidaten. |
| Browser, eingebetteter Editor | lokale kontrollierte Testseite | editierbares Feld in einem `iframe` | Echte Auswahlersetzung in Safari und Brave bestanden; synthetisch auch Unicode/Umfeld geprüft. |
| Electron-App | Obsidian 1.13.7, temporärer separater Vault | Editorfeld | Neue echte Auswahlersetzung in Obsidian CodeMirror mit erhaltenem Anfang/Ende bestanden. Anfang/Mitte/Ende und Unicode zusätzlich synthetisch belegt. Keine Zusage für andere Electron-Apps. |
| Apple Terminal, enger Unicode-Pfad | macOS Terminal (`com.apple.Terminal`) | Fokussierte `AXTextArea` ohne erfassten `AXWebArea`-Vorfahren; keine nichtleere Display-Auswahl | Implementierung und zwölf neue Offline-Testfälle vorhanden. Tatsächliche AX-Struktur, Unicode-Eventannahme und native Fokus-/Tabfälle noch offen; kein neuer Terminal-Laufzeitnachweis. Keine Zusage für iTerm2 oder Editor-Terminals. |
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

Die normalen editierbaren Feldkategorien werden nicht nur mit einem leeren Feld
geprüft. Für Apple Terminal gelten die gesonderten Grenzen im nächsten Abschnitt;
Auswahlersetzung und mehrzeilige Eingabe sind dort keine Abnahmekriterien.

1. Einfügen an Anfang, Mitte und Ende der aktuellen Cursorposition.
2. Eine bestehende Auswahl ersetzen, ohne Text davor oder danach zu verändern.
3. Mehrzeiligen Unicode-Text mit Umlauten, kombinierenden Zeichen und Emoji exakt
   übernehmen. Lange Texte müssen ihre Chunk-Grenzen unverändert überstehen.
4. Während Aufnahme, Verarbeitung und mehrteiliger Übergabe App, Fenster oder
   Browser-Tab wechseln. Text darf nur das für dieses Diktat erfasste und weiterhin
   gültige Ziel erreichen; nach Zielverlust werden keine weiteren Chunks gesendet.
5. Ablehnung, fehlende Accessibility-Berechtigung oder nicht unterstütztes Feld:
   kein stiller Verlust und keine Einfügung in ein anderes Ziel. Das vollständige
   Transkript bleibt auf der Zwischenablage und die Oberfläche erklärt den manuellen
   Rückweg verständlich.

## Apple Terminal

Die Anwendung ist Apple Terminal; die installierte Revision des gemeldeten
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

Die neue native Abnahme bleibt offen und führt **keine Befehle aus**. In einem
eigens vorbereiteten lokalen Terminal-Fenster an einer bekannten leeren
Eingabezeile nur einen unkritischen einzeiligen Text wie „OpenDictate Probe
Apfel 42“ verwenden; keine Return-Taste drücken und den Text nicht absenden.
Zuerst Kandidat/Version und die tatsächliche AX-Zielstruktur feststellen, danach
sichtbare Eingabe und verlustfreien Rückweg prüfen. Eine Kontrollprobe in einem
neuen TextEdit-Dokument kann den allgemeinen Diktierweg eingrenzen, belegt aber
keine Terminal-Unterstützung. Den begrenzten Ablauf und seine Voraussetzungen
beschreibt [CHECKS](../CHECKS.md#apple-terminal). Die bisherige Matrix-Fixture hat
Apple Terminal nicht als auswählbares Ziel; sie ist kein fertiger Terminal-Test.

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

1. Auf dem neuen Kandidaten vollständige und unterbrochene Texteingabe gezielt sichtbar prüfen; danach früh menschliche Diktate samt physischem Tastenkürzel und Korrekturaufwand auswerten.
2. Eine begrenzte Runde der offenen Fokus-, Aufnahme-, Abbruch-, Geräte- und Recoveryfälle nach Risiko und Pilotbefund durchführen.
3. Die breitere Matrix einschließlich VoiceOver und verbleibender Plattform-/Feldkombinationen systematisch ergänzen; fehlende Fälle bleiben ausdrücklich offen.

Streaming und Hold-to-talk bleiben zurückgestellt. Diese Matrix sagt keine
Windows-/Linux-Version und keine öffentliche Veröffentlichung zu.

## Bestehende Nachweise

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
