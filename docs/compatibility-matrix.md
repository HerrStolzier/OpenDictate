# Kompatibilitätsmatrix für Texteingabe und Fokus

Stand: 2026-09-16. Diese Matrix ist der aktuelle produktweite Abnahmeplan für
die Textübergabe. Programme dienen als repräsentative Beispiele ihrer Kategorie;
ein bestandener Lauf ist kein Versprechen für alle Programme derselben Kategorie.
Datierte Berichte bleiben die Quelle für den jeweils tatsächlich geprüften Kandidaten.

Die aktuelle synthetische Abnahme und ihre konkreten Grenzen stehen im
[Bericht vom 16. September](roadmap-acceptance-2026-09-16.md). Sie ersetzt keine
neue Mikrofon-/Provider-Abnahme des installierten Kandidaten.

## Abdeckungsziel

| Kategorie | Repräsentative Beispiele | Zu prüfende Felder | Aktuelle Evidenz |
|---|---|---|---|
| Native macOS-App | TextEdit; kontrollierter AppKit-Host | ein- und mehrzeiliges editierbares Feld | Aktuell synthetisch: Cursor in NSTextField, Auswahlersetzung/Unicode in NSTextView; früherer echter TextEdit-Durchlauf bleibt historisch. |
| Browser, einfaches Formular | Safari und Brave | `input`, `textarea` | Aktuell synthetisch beide Feldtypen in beiden Browsern geprüft, mit erhaltenem Umfeld; keine allgemeine Browserzusage. Chrome-Ersteinrichtung unverändert verlassen, Firefox nicht installiert. |
| Browser, Rich-Text | lokale Testseite; historische Proton-Abnahme | `contenteditable`, Auswahl und mehrzeiliger Inhalt | Aktuell synthetische Auswahlersetzung/Unicode in Safari und Brave; echte Proton-Nutzerbestätigung gilt dem älteren Kandidaten. |
| Browser, eingebetteter Editor | lokale kontrollierte Testseite | editierbares Feld in einem `iframe` | Aktuell synthetisch in Safari und Brave: Auswahl exakt ersetzt, Umfeld erhalten. |
| Electron-App | Obsidian 1.13.7, temporärer separater Vault | Editorfeld | Aktuell synthetisch: Anfang/Mitte/Ende und Auswahl/Unicode exakt; gespeicherte Testdatei bytegenau geprüft. Keine Zusage für andere Electron-Apps. |
| Geschütztes oder nicht unterstütztes Feld | native und Brave-Testfelder | Passwortfeld, schreibgeschütztes Feld | Sichtbar abgelehnt, Felder unverändert; vollständiger Text im manuellen Panel und auf isolierter Testzwischenablage. Fehlende Berechtigung zusätzlich offline geprüft, kein TCC-Eingriff. |

## Gemeinsame Szenarien

Aktuell sichtbar belegt: nativer Feldwechsel, Brave-Tabwechsel und Safari-
Fensterwechsel während synthetischer Verarbeitung sowie App-Wechsel während
laufender Safari-Unicode-Chunks, jeweils mit vollständigem Kopiertext.
Anfang/Ende wurden für native Felder, Safari-Feldtypen und Obsidian ergänzt.
Safari-textarea ist zusätzlich mit 28.199 UTF-16-Zeichen sowie CRLF/Leerzeilen
exakt geprüft; führende Zeilenumbrüche benötigen dort eigene Unicode-Events.
Prozess-, Fenster-, Feld-, Dokument- und Selektionswechsel sowie Chunk-Abbruch
sind zusätzlich offline geprüft. Alle Phasen-/Kategorie-Kombinationen sind damit
nicht vollständig abgenommen; reale Aufnahme/Provider wurden nicht erneut geprüft.

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

- [Brave-/Proton-Bericht](brave-insertion-2026-09-15.md): synthetischer
  Produktionseinfüger, Unicode/Auswahl in der lokalen Brave-Testseite und
  ausdrückliche Proton-Nutzerbestätigung samt Grenzen.
- [Native Abnahme vom 15. September](live-acceptance-2026-09-15.md): echter,
  sichtbar geprüfter TextEdit-Durchlauf samt Kandidat und Grenzen.
- [Ältere Live-Abnahme](live-acceptance-2026-09-07.md): historischer `Cmd+V`-Pfad;
  kein Nachweis für die heutige direkte Einfügelogik.
