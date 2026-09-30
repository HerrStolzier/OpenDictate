# iOS Tastatur-Prototyp: Prüfplan

## Ziel und Umfang

Dieser Kandidat prüft die Aufnahme-/Tastaturkopplung. Der sichtbare Text
`OpenDictate Testtext (synthetisch)` ist weiterhin vorbereitet, keine
Transkription. Nur die Haupt-App kann lokal aufnehmen. Keine Anbieteranfrage,
kein API-Schlüssel, keine Speicherung von Tastatureingaben, kein automatisches
Öffnen einer anderen App aus der Tastatur.

Die Tastatur benötigt Vollzugriff für die schreibende Kopplung über den
App-Gruppencontainer. Normale QWERTZ-Eingabe, Löschen, Leerzeichen, Zeilenumbruch,
Tastaturwechsel und der separate Texttest bleiben ohne Vollzugriff nutzbar.
Es gibt keine dauerhafte App-/Feldbindung und keine automatische Einfügung.
Ein Ergebnis wird nur synchron beim bewussten Knopfdruck im dann aktuellen
Feld eingefügt, höchstens einmal pro Sitzung.

## Freigabe und Abschlussprüfung

Zielgerät ist Bastis iPhone 15 / iOS 27.0.1. Vor der Live-Prüfung sind die
konkrete App-Group-Registrierung bei Apple, Profile mit der bestehenden
Entwicklungsidentität, Installation dieses geänderten Kandidaten und höchstens
drei lokale Mikrofonaufnahmen à maximal 15 Sekunden separat freizugeben.
Kein Provider-Upload oder Veröffentlichungsauftrag. Die frühere reine
Texttest-Freigabe deckt diese Aufnahmeprüfung nicht ab.

Vorher: unsigned Simulator-/Gerätebuild, Bridge-Fixtures, Plist-/Entitlement-
Prüfung und unabhängiger Review des genauen Stands. Nachher: Kandidat/Hashes,
Sitzungszeiten, beobachteter Mikrofonstart/-stopp, tatsächliche WAV-Dauer und
Dateischutz, Feld-Endzustände sowie Testbereinigung protokollieren. Keine
Audiodateien oder gesprochenen Inhalte ins Repository übernehmen.

Nur ein Ende-zu-Ende-Lauf auf dem iPhone kann die Kopplung belegen. Der
synthetische Text sagt nichts über Diktatqualität oder die spätere Anbieter-
Integration. Unterbrechungs-/Absturzfälle bleiben offen, falls sie nicht
kontrolliert und im freigegebenen Umfang ausführbar sind.

## Fehler- und Prüffälle vor der Umsetzung

1. **Erweiterung nicht aktiviert / Vollzugriff aus:** Safari behält die
   Systemtastatur bzw. die Kopplung ist gesperrt. Normale Eingabe und der
   separate Texttest bleiben nutzbar. Die Haupt-App kann stets selbst stoppen;
   die native Aufnahmegrenze bleibt 15 Sekunden.
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
8. **Mehrfacher Druck:** Der separate Texttest fügt je Druck einmal ein.
   Das Ergebnis einer Aufnahmesitzung darf nur einmal beansprucht werden,
   auch bei konkurrierenden Tastaturinstanzen. Anzeigen/Statuswechsel fügt nichts ein.
9. **App-, Feld- oder Tastaturwechsel:** Stopp kann einen Status aktualisieren,
   aber keine spätere Einfügung auslösen. Erst ein erneuter bewusster Druck
   wirkt auf das dann aktuelle Feld. Es wird kein altes Feld wiederhergestellt.
10. **Veraltete oder ungültige Sitzung:** Stoppmarker tragen eine Sitzungs-ID;
    Marker einer alten Sitzung dürfen keine neuere stoppen. Aufnahme nach 15
    Sekunden, Ergebnis nach 60 Sekunden, zu große/metadatenfremde Dateien oder
    Zeitpunkte aus der Zukunft sind nicht als aktive Ergebnisse verwendbar.
11. **Abbruch, Ablehnung, Unterbrechung, Schreib-/Encoderfehler:** Kein
    Einfügeergebnis, kein automatischer Neustart und kein Löschen der einzigen
    WAV-Datei. Selbst nach fehlgeschlagener Einrichtung wird eine aktivierte
    Audio-Sitzung deaktiviert; Deaktivierungsfehler bleiben sichtbar.

## Lokale Safari-Fixture

`fixtures/keyboard-focus.html` ist eine statische HTML-Datei ohne Skripte,
externe Ressourcen oder Netzwerkanfragen. Die Hauptaufgabe kann sie für die
Simulatorprüfung ausschließlich unter `127.0.0.1` bereitstellen. Sie enthält
zwei benannte mehrzeilige Felder (`field-one`, `field-two`) und ein
Passwortfeld (`password`); das Passwortfeld ist nur zum Prüfen der
Systemtastatur bestimmt.

## Sichtbarer Ablauf nach konkreter Freigabe

Die Hauptaufgabe bereitet den geprüften Kandidaten und die kontrollierte
Safari-Fixture vor. Basti bedient sein iPhone. Nur eigene Testfelder verwenden;
vor dem Start muss der Rückweg zu Safari bereits klar sein. Die drei Aufnahmen
verbrauchen insgesamt höchstens 45 Sekunden. Die Kategorie `.record` kann
während der Aufnahme andere Wiedergabe stummschalten; nach Ende muss sie
deaktiviert werden. Keine TCC-Rücksetzung oder fingierten Anrufe.

1. **Aktivierung:** OpenDictate Testkeyboard lässt sich hinzufügen. Der
   Vollzugriff-Schalter bleibt zunächst aus; normale Eingabe und separaten
   Texttest prüfen. Danach schaltet Basti ihn für den Kopplungstest selbst ein.
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

8. **Aufnahme 1, Kopplung:** Bewusst in OpenDictate starten, Mikrofonfreigabe
   selbst bestätigen, manuell zu Safari wechseln und in der OpenDictate-
   Tastatur „Aufnahme stoppen“ drücken. Aufnahme muss enden. Feld bleibt bis
   „Testtext nach Stopp einfügen“ leer; einmaliger Druck fügt den markierten
   Text exakt ein. Wiederholter Druck fügt nichts nach.
9. **Aufnahme 2, Grenze/Fokus:** In der Haupt-App starten, zu Safari wechseln,
   vor Ende das zweite Feld wählen und den Stoppknopf gedrückt halten. Finger
   aus dem Knopf herausziehen, die native 15-Sekunden-Grenze abwarten, Finger
   zurückziehen und erst dann loslassen. Derselbe Stoppdruck darf auch jetzt
   keinen Text einfügen; die Bedeutung bleibt während der gesamten Berührung
   gebunden. Danach die aktualisierte Ergebnisaktion bewusst neu drücken.
   Keine automatische Einfügung in irgendein Feld. Nach bewusstem Druck darf
   nur das jetzt aktuelle Feld den markierten Text erhalten. Mikrofon endet
   auch ohne Stoppmarker. Nach 60 Sekunden ist das Ergebnis nicht mehr nutzbar.
10. **Aufnahme 3, Abbruch:** In der Haupt-App starten und nach wenigen Sekunden
    abbrechen. Mikrofon endet, WAV bleibt lokal, Kopplung bietet kein Ergebnis.
11. **Bereinigung:** Nach freigegebener Prüfung genau diese Test-App samt
    selbst erzeugten WAV-Dateien/Gruppenmetadaten deinstallieren und nur eigene
    Safari-Testtabs schließen. Apple-Gruppe/Profile sind dauerhafte, benannte
    Entwicklungsressourcen; keine fremden Profile/Zertifikate entfernen.

## Abnahmekriterien und Grenzen

Abgenommen werden kann nur die sichtbare lokale Aufnahme-/Tastaturkopplung
dieses Kandidaten auf dem genannten Gerät und der statischen Safari-Fixture.
Die Prüfung belegt keine Diktatqualität, Anbieterintegration, dauerhafte
Feldidentität, Kompatibilität mit weiteren Apps oder App-Store-Freigabe.

Das Ergebnis wird erst nach der separat koordinierten sichtbaren
Geräteprüfung als E2E-Nachweis gewertet. Ein erfolgreicher Build allein ist
kein Nachweis für Einfügung in Safari.
