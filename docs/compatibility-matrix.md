# Kompatibilitätsmatrix für Texteingabe und Fokus

Stand: 2026-09-17. Diese Matrix ist der aktuelle produktweite Abnahmeplan für
die Textübergabe. Programme dienen als repräsentative Beispiele ihrer Kategorie;
ein bestandener Lauf ist kein Versprechen für alle Programme derselben Kategorie.
Datierte Berichte bleiben die Quelle für den jeweils tatsächlich geprüften Kandidaten.

Die ergänzende synthetische und reale Mikrofon-/Provider-Abnahme steht im
[Bericht vom 17. September](roadmap-acceptance-2026-09-17.md). Sie ergänzt den
[Ausgangsstand vom 16. September](roadmap-acceptance-2026-09-16.md), dessen
Feldnachweise in der folgenden Tabelle historisch zusammengefasst sind.
Die reale Kette ist für vier Brave-Feldtypen belegt, nicht für jede Kategorie.

## Abdeckungsziel

| Kategorie | Repräsentative Beispiele | Zu prüfende Felder | Aktuelle Evidenz |
|---|---|---|---|
| Native macOS-App | TextEdit; kontrollierter AppKit-Host | ein- und mehrzeiliges editierbares Feld | Aktuell synthetisch: Cursor in NSTextField, Auswahlersetzung/Unicode in NSTextView; früherer echter TextEdit-Durchlauf bleibt historisch. |
| Browser, einfaches Formular | Safari und Brave | `input`, `textarea` | Am 17. September echte Mikrofon-/Provider-/automatische Auswahlersetzung in Brave bestanden, textarea einschließlich 90-Sekunden-Autostopp. Safari bisher synthetisch; Chrome-Ersteinrichtung unverändert, Firefox fehlt. Keine allgemeine Browserzusage. |
| Browser, Rich-Text | lokale Testseite; historische Proton-Abnahme | `contenteditable`, Auswahl und mehrzeiliger Inhalt | Am 17. September echte Mikrofon-/Provider-/automatische Auswahlersetzung in Brave bestanden. Safari synthetisch geprüft; echte Proton-Bestätigung gilt dem älteren Kandidaten. |
| Browser, eingebetteter Editor | lokale kontrollierte Testseite | editierbares Feld in einem `iframe` | Am 17. September echte Mikrofon-/Provider-/automatische Auswahlersetzung in Brave bestanden. Safari synthetisch: Auswahl exakt ersetzt, Umfeld erhalten. |
| Electron-App | Obsidian 1.13.7, temporärer separater Vault | Editorfeld | Aktuell synthetisch: Anfang/Mitte/Ende und Auswahl/Unicode exakt; gespeicherte Testdatei bytegenau geprüft. Keine Zusage für andere Electron-Apps. |
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
Native E2E-Versuche lieferten keinen Nachweis: einmal manueller Rückweg, einmal
blieb tatsächlich Brave im Vordergrund und erhielt korrekt den Text. Safari und
Electron bleiben ohne neue reale Abnahme dieses Kandidaten.

Jede unterstützte Feldkategorie wird nicht nur mit einem leeren Feld geprüft:

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

1. Breite der Eingabefelder und Fokuswechsel anhand der Matrix schließen.
2. Aufnahme-, Abbruch-, Geräte-, Fehler- und Recoveryfälle robust live prüfen.
3. VoiceOver, Tastaturbedienung sowie Sprachqualität, Latenz und Korrekturaufwand messen.

Streaming und Hold-to-talk bleiben zurückgestellt. Diese Matrix sagt keine
Windows-/Linux-Version und keine öffentliche Veröffentlichung zu.

## Bestehende Nachweise

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
