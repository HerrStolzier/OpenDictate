# Kritische Gegenprüfung von Plan 1

Am 24. September 2026 auf ausdrücklichen Wunsch von Basti parallel durch
einen Subagenten mit **GPT-6 Luna, Reasoning Max** durchgeführt. Nur lesend:
Quellen, aktuelle Übergabe, A/B-JSON und Screenshot; keine eigenen Builds,
GUI-Aktionen oder Änderungen. Ausgangspunkt: `153da2d` mit den anschließend
entstandenen lokalen Safari-Nachweisen.

## Befunde und Konsequenzen

1. **Kein begründeter Produktionsfix:** Im gleichen neu gebauten Testprozess
   fügte sowohl PID-Versand als auch der unveränderte globale Einfügeweg den
   vollständigen Text ein. Der [A/B-Nachweis](2026-09-24-safari-pid-versus-global.json)
   erklärt frühere Fehlschläge nicht. Die Produktion wird deshalb nicht auf
   PID-Versand umgestellt.
2. **Prozesszustellung ist keine Feldbestätigung:** `postToPid` benennt nur
   einen Prozess. Die bestehenden Prüfungen in
   [PasteboardInserter](../../../Sources/OpenDictate/System/PasteboardInserter.swift)
   bestätigen Berechtigung, laufende Ziel-App, Vordergrund-App und unveränderte
   Zwischenablage. Weder Versandart bestätigt die tatsächliche Einfügung.
   Maßgeblich bleibt der vollständige sichtbare Feldwert.
3. **Übergabe war veraltet:** Der echte Mausklickversuch war schon beendet,
   wurde im Bericht aber noch als vorbereitet beschrieben. Außerdem fehlte
   zunächst der globale Rohvergleich im A/B-JSON. Beides wird mit den aktuellen
   Beobachtungen ergänzt; die erfolglosen Läufe bleiben als solche erhalten.
4. **Unicode separat bewerten:** 69 statt 70 UTF-16-Einheiten bei vollständiger
   NFC-Gleichheit belegen die beobachtete Normalisierung des Akzents, keinen
   Verlust eines Wortes oder einen Beleg für benötigten PID-Versand. Rohvergleich
   und NFC-Vergleich bleiben getrennt. Eine Abnahmeentscheidung wird nicht
   durch Umbenennen eines Testergebnisses vorweggenommen.
5. **Gesamtabnahme bleibt offen:** Synthetische Safari-Fälle ersetzen weder
   gehörtes VoiceOver noch reale Einstellungen, Störfälle oder die Messung
   der lokalen Zustandswechsel. Die akzeptierte offene Ersteinrichtung bleibt
   erhalten. Die temporäre PID-Diagnose kann nach Sicherung der Belege entfernt
   werden.

Die Hauptaufgabe hat die genannten Quellen und das tatsächliche Safari-Ergebnis
selbst geprüft. Dieser Review ersetzt keine der noch fehlenden Abnahmen.
