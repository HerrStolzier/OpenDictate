# Plan 4: Release-Kandidat und Freigabeentscheidung

**Ziel:** Ein einziger, unveränderter Kandidat ist technisch und inhaltlich
für die öffentliche Mac-Ausgabe freigegeben. Sein ZIP, SHA-256-Wert,
Quellrevision, Version und Buildnummer sind festgehalten. Der Kandidat wird
hier noch nicht veröffentlicht.

**Voraussetzung:** [Interne Abnahme](01-interne-produktabnahme.md),
[verteilbares Paket](02-verteilbares-mac-paket.md) und
[Betatest](03-begrenzter-betatest.md) sind abgeschlossen.

## Arbeit

1. Pilotbefunde schließen. Nach jeder Codeänderung die betroffenen
   Quellenchecks und realen Nutzungspfade erneut prüfen. Bekannte Grenzen
   schriftlich festlegen; weder „jedes Textfeld“ noch automatische
   Zielbestätigung versprechen.
2. Version und Git-Revision festlegen, daraus einen neuen Release-Build über
   Plan 2 erzeugen und den Build danach nicht mehr verändern. Die Tests aus
   [CHECKS.md](../../CHECKS.md), Bundle- und Archivprüfung sowie die
   Notarisierungsprüfung für genau diese Revision protokollieren.
3. Das **endgültige ZIP** auf dem vorhandenen unterstützten Mac aus dem
   Archiv installieren. Dort Start,
   Berechtigungen, Schlüsselbund, ein echtes Diktat, manuellen Kopierweg,
   Beenden und erneuten Start prüfen. Den Updateweg von der vorigen lokalen
   Installation einmal gesondert prüfen. Den nativen macOS-14-CI-Nachweis
   gesondert dokumentieren; ein interaktiver macOS-14-Test ist nicht verfügbar.
4. [README.md](../../README.md), [PRIVACY.md](../../PRIVACY.md),
   [PROJECT.md](../../PROJECT.md), Website-Text und Release-Hinweise mit dem
   Kandidaten vergleichen. Der lokale Website-Entwurf beschreibt den heutigen
   ⌘V-Pfad; vor Veröffentlichung muss er mit dem Release-Kandidaten erneut
   abgeglichen werden. API-Gebühren,
   lokaler Zwischenablagezugriff, Aufbewahrung und der Feldwechsel innerhalb
   der Start-App müssen verständlich genannt sein.
   Das [App-Design- und UX-Kapitel aus Plan 1](01-interne-produktabnahme.md#app-design-und-ux)
   am endgültigen Paket noch einmal sichtbar prüfen: Hierarchie von
   Menüleiste und Panel, heller und dunkler Modus, kleinste Panelgröße,
   Tastaturweg und gehörte VoiceOver-Ausgabe. Jeder Fehlertext gibt eine
   konkrete nächste Handlung statt technischer Innensicht. Den tatsächlichen
   Build mit der in Plan 1 gewählten Mockup-Richtung und den UX-Befunden aus
   Plan 3 vergleichen; notwendige Abweichungen kurz begründen.
5. Ein Freigabeprotokoll mit Ergebnissen, offenen Grenzen und identischem
   SHA-256-Wert für das zur Veröffentlichung vorgesehene ZIP erstellen.

## Abnahme

- Keine offenen Blocker: Verlust der einzigen Aufnahme oder des einzigen
  Transkripts, Beschädigung vorhandenen Textes, falsche Beschreibung des
  Datenflusses, nicht installierbares Paket oder nicht reproduzierbarer
  Release-Build. Andere Grenzen sind ausdrücklich beschrieben.
- Der signierte und notarisierte Kandidat besteht die Installation und den
  Updateweg auf dem vorhandenen Mac.
  Sämtliche öffentlichen Texte stimmen mit seiner tatsächlichen Funktion
  überein; der endgültige Archiv-Hash steht im Freigabeprotokoll.
- Der Abschlussvergleich bestätigt die Schlankheitskriterien aus Plan 1 und 2:
  zwei Tastendrücke im Normalweg, keine ungefragten Fenster, schneller Status,
  ein einzelnes App-Bundle ohne zusätzlichen Dienst und höchstens 8 MiB. Die
  im Betatest getrennt gemessene automatische Eingabe und der Zeitwert bis
  zum nutzbaren Text erfüllen die Kriterien aus Plan 3.
- Jede Änderung nach diesem Protokoll erzeugt einen **neuen** Kandidaten und
  wiederholt die betroffenen Prüfungen. Ein bloßer grüner CI-Lauf genügt nicht.

**Freigabegrenze:** Dieses technische Go/No-Go ersetzt nicht Bastis konkrete
Zustimmung zur öffentlichen Veröffentlichung. Live-Diktate, Signierung und
Notarisierung brauchen die jeweils passende Autorisierung.

**Übergabe an [Plan 5](05-oeffentlicher-release.md):** Ein eingefrorenes ZIP
und ein Freigabeprotokoll, auf die alle öffentlichen Links zeigen sollen.
