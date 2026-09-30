# iOS Tastatur-Prototyp: Prüfplan

## Ziel und Umfang

Dieser Prototyp prüft ausschließlich eine eigene iOS-Tastatur mit einem
bewussten Einfügen über `UITextDocumentProxy` in das aktuell fokussierte Feld.
Der sichtbare Testtext ist vorbereitet und synthetisch. Das Projekt nimmt
nichts auf, sendet keine Anfragen und speichert keine Nutzereingaben.

Die Tastatur fordert keinen Vollzugriff an. Sie bietet neben dem Testknopf eine
kleine QWERTZ-Eingabe, Löschen, Leerzeichen, Zeilenumbruch und den Wechsel zur
nächsten Tastatur. Sie bindet einen Text nicht dauerhaft an eine App oder ein
Feld. Es gibt keine automatische Einfügung.

## Fehler- und Prüffälle vor der Umsetzung

1. **Erweiterung nicht aktiviert:** Safari behält die Systemtastatur; es gibt
   keine Einfügung und keine Aufforderung, Vollzugriff einzuschalten.
2. **Keine aktive Tastaturansicht:** Der Einfügeknopf bleibt deaktiviert.
   Ein Aufruf außerhalb des sichtbaren `UIViewController`-Lebenszyklus darf
   nichts einfügen. Die Erweiterung behauptet damit keine eigenständige
   Erkennung des Zielfelds.
3. **Leeres oder nicht unterstütztes Proxy-Kontextfeld:** Die Tastatur darf
   leere Kontextwerte nicht als Beweis für einen gültigen oder ungültigen
   Fokus missdeuten. Sie zeigt keine behauptete Feldbindung; die Einfügung
   erfolgt nur nach bewusstem Tastendruck in das gerade aktive Feld.
4. **Fokus wechselt von Feld Eins zu Feld Zwei:** Der Testtext darf nur dort
   erscheinen, wo der Einfügeknopf im Moment des Tastendrucks betätigt wird.
   Das erste Feld darf sich dabei nicht nachträglich ändern.
5. **Sicheres Passwortfeld:** iOS zeigt die Systemtastatur; die
   OpenDictate-Tastatur und ihr Testknopf sind nicht verfügbar. Für diesen
   Test kein echtes Passwort verwenden.
6. **Wechsel zur Systemtastatur:** Der Tastaturwechsel muss erreichbar sein;
   normale Eingabe mit der Systemtastatur funktioniert danach weiter.
7. **Normale Eingabe in der Prototyp-Tastatur:** Ein Buchstabe, Rückschritt,
   Leerzeichen und Zeilenumbruch wirken jeweils einmal auf das aktuelle Feld.
8. **Mehrfacher bewusster Testknopfdruck:** Jeder Druck fügt genau einen
   sichtbaren Testtext ein; Erscheinen der Tastatur allein fügt nichts ein.
9. **App- oder Tastaturwechsel währenddessen:** Der Prototyp hat keine
   Hintergrundaufgabe und keine späte Antwort. Nach Rückkehr gilt nur das
   aktuell fokussierte Feld; es wird kein altes Feld wiederhergestellt.

## Lokale Safari-Fixture

`fixtures/keyboard-focus.html` ist eine statische HTML-Datei ohne Skripte,
externe Ressourcen oder Netzwerkanfragen. Die Hauptaufgabe kann sie für die
Simulatorprüfung ausschließlich unter `127.0.0.1` bereitstellen. Sie enthält
zwei benannte mehrzeilige Felder (`field-one`, `field-two`) und ein
Passwortfeld (`password`); das Passwortfeld ist nur zum Prüfen der
Systemtastatur bestimmt.

## Sichtbarer Simulator-Ablauf

Die Hauptaufgabe baut und installiert die App im iOS-Simulator, aktiviert die
Tastatur in den iOS-Einstellungen und lädt die lokale Fixture in Safari. Der
Prototyp-Worker startet keinen Server, installiert nichts und steuert die
Simulatoroberfläche nicht.

1. **Aktivierung:** OpenDictate Testkeyboard lässt sich hinzufügen. Der
   Vollzugriff-Schalter bleibt aus. Es gibt keine Mikrofon- oder
   Netzwerkberechtigung.
2. **Feld Eins:** In Safari Feld Eins fokussieren, die OpenDictate-Tastatur
   auswählen und prüfen, dass beim Anzeigen noch kein Text erscheint.
3. **Synthetische Einfügung:** Den klar als Test markierten Knopf einmal
   drücken. Genau `OpenDictate Testtext (synthetisch)` muss an der aktuellen
   Einfügeposition in Feld Eins erscheinen.
4. **Normale Eingabe und Wechsel:** Einen Buchstaben und ein Leerzeichen mit
   der Prototyp-Tastatur eingeben, zur Systemtastatur wechseln und dort ein
   weiteres harmloses Wort eingeben.
5. **Feldwechsel:** Feld Zwei fokussieren, die Prototyp-Tastatur auswählen und
   erst nach erneutem bewussten Knopfdruck prüfen, dass der Testtext in Feld
   Zwei erscheint. Feld Eins bleibt unverändert.
6. **Sicheres Feld:** Passwortfeld fokussieren. iOS muss die Systemtastatur
   zeigen; der OpenDictate-Testknopf darf nicht verfügbar sein.
7. **Kein sichtbares Feld / geschlossene Tastatur:** Safari-Fokus entfernen
   bzw. Tastatur schließen. Der Knopf darf dann nichts einfügen.

## Abnahmekriterien und Grenzen

Abgenommen werden kann nur der sichtbare Simulatorpfad für diesen Prototyp, die
genannte Simulator-iOS-Version und die statische Safari-Fixture. Die Prüfung
belegt weder Mikrofonaufnahme im Hintergrund noch Diktatqualität, Provider,
Weitergabe von Text, Full-Access-Verhalten, dauerhafte Feldidentität,
Kompatibilität mit anderen Apps oder App-Store-Freigabe.

Das Ergebnis wird erst nach der separat koordinierten sichtbaren
Simulatorprüfung als E2E-Nachweis gewertet. Ein erfolgreicher Build allein ist
kein Nachweis für Einfügung in Safari.
