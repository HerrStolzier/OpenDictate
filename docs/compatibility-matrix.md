# Kompatibilitätsmatrix für Texteingabe und Fokus

Stand: 2026-09-15. Diese Matrix ist der aktuelle produktweite Abnahmeplan für
die Textübergabe. Programme dienen als repräsentative Beispiele ihrer Kategorie;
ein bestandener Lauf ist kein Versprechen für alle Programme derselben Kategorie.
Datierte Berichte bleiben die Quelle für den jeweils tatsächlich geprüften Kandidaten.

## Abdeckungsziel

| Kategorie | Repräsentative Beispiele | Zu prüfende Felder | Aktuelle Evidenz |
|---|---|---|---|
| Native macOS-App | TextEdit; später ein weiteres übliches natives Schreibfeld | ein- und mehrzeiliges editierbares Feld | Ein echter TextEdit-Durchlauf mit Mikrofon, Transkription und sichtbarer Einfügung ist belegt. Kein zweites natives Programm geprüft. |
| Browser, einfaches Formular | Safari, Firefox oder Chromium-Browser | `input`, `textarea` | Produktionseinfüger synthetisch in einem Brave-`textarea` sichtbar geprüft. Kein allgemeiner Browsernachweis. |
| Browser, Rich-Text | Proton in Brave sowie lokale Testseite | `contenteditable`, Auswahl und mehrzeiliger Inhalt | Synthetischer Produktionseinfüger in Brave sichtbar geprüft; Proton-Diktat vom Nutzer ausdrücklich bestätigt. Exakter Proton-Text und Auswahlverhalten nicht geprüft. |
| Browser, eingebetteter Editor | lokale kontrollierte Testseite | editierbares Feld in einem `iframe` | Offen; der bisherige Versuch sendete wegen der Vordergrundsperre keinen Text und ist weder Erfolg noch Produktfehler. |
| Electron-App | ein verbreiteter Editor oder Messenger mit unkritischem Testfeld | natives oder webbasiertes Editorfeld der App | Offen. Brave-spezifische Unicode-Einfügung belegt Electron nicht. |
| Geschütztes oder nicht unterstütztes Feld | Passwortfeld, schreibgeschütztes Feld, Feld ohne nutzbare Accessibility-Schnittstelle | Ablehnung statt verdeckter Fehleinfügung | Offen. Erwartung: kein Textverlust, Transkript bleibt verständlich als Zwischenablage-Rückweg verfügbar. |

## Gemeinsame Szenarien

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
