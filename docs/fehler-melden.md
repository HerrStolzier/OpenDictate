# Fehler melden aus der App

Entschieden am 13. Oktober 2026 ([PROJECT](../PROJECT.md#entscheidungen)): OpenDictate
bekommt kein automatisches Fehlersammeln und keine zentrale Fehlerdatenbank. „Kein
Tracking“ bleibt. Stattdessen öffnet „Fehler melden …“ in der App das Kontaktformular
des Supports mit einem kurzen Bericht, den die Person sieht, ändern oder löschen kann
und selbst abschickt. Der Bericht landet als Ticket in der Support-Datenbank; das
Dashboard zeigt, welcher Fehler wie oft kommt.

Die App selbst stellt dabei keine Verbindung zum Support her. Sie öffnet nur eine
Adresse im Standardbrowser.

## Adresse

```
https://support.opendictate.app/kontakt?lang=de#app=…&system=…&fehler=…&diagnose=…
```

Der Bericht steht hinter `#`. Diesen Teil der Adresse schickt der Browser nie an einen
Server; das Formular liest ihn auf dem Gerät, zeigt ihn an und nimmt ihn danach aus
der Adresszeile. Beim Support kommt der Bericht deshalb erst an, wenn die Person das
Formular abschickt. Ein Bericht im Abfrageteil (`?app=…`) wird nicht übernommen.

Alle Werte sind URL-kodiert (`application/x-www-form-urlencoded`). Fehlt ein Wert,
bleibt das Feld leer. Das Formular kürzt auf die Grenzen unten; das Support-Backend
kürzt beim Speichern noch einmal und entfernt Werte, die wie ein OpenAI-Schlüssel
aussehen (`sk-…`), als zweite Sicherung.

| Feld | Inhalt | Grenze | Beispiel |
| --- | --- | --- | --- |
| `lang` | `de`, wenn die Systemsprache Deutsch ist, sonst `en` | – | `de` |
| `app` | Name, Version und Build | 100 Zeichen, eine Zeile | `OpenDictate 0.1.0-beta.12 (12)` |
| `system` | Betriebssystem, Version, Architektur; unter Linux Distribution und Compositor | 150 Zeichen, eine Zeile | `macOS 15.1 (arm64)` |
| `fehler` | Der letzte Fehler als kurze, stabile Beschreibung ohne Einzelheiten, damit gleiche Fehler zusammenfallen | 150 Zeichen, eine Zeile | `Transkription: Zeitüberschreitung` |
| `diagnose` | Einstellungen und die letzten Warn- und Fehlerzeilen des Protokolls | 4000 Zeichen (Grenze des Backends), dazu die Grenze der ganzen Adresse unten | siehe unten |

`fehler` ist der Schlüssel, nach dem das Dashboard gruppiert. Er nennt Schritt und Art
(„Einfügen: Bedienungshilfen fehlen“, „Aufnahme: kein Mikrofon“), keine Zeiten,
Pfade, Dateinamen oder Zahlen, die sich bei jedem Auftreten ändern.

Die fertige, kodierte Adresse ist höchstens 12 000 Zeichen lang; Umlaute brauchen
kodiert sechs Zeichen, deshalb misst die App die kodierte Länge und lässt in `diagnose`
die ältesten Protokollzeilen weg, bis die Adresse passt.

## Was in `diagnose` steht

- Einstellungen, die das Verhalten erklären: Anbieter (OpenAI oder eigener Server,
  beim eigenen Server nur „ja“ und ob Loopback, nie Adresse oder Host),
  Transkriptionsmodell, Übersetzung an oder aus mit Zielsprache, Kürzelart,
  Einfügen oder nur Zwischenablage.
- Berechtigungen: Mikrofon, Bedienungshilfen (macOS), Schlüsselbund erreichbar.
- Die letzten Warn- und Fehlerzeilen des lokalen Protokolls mit Uhrzeit, höchstens
  30 Zeilen.

## Was nie hinein darf

- Diktierter oder übersetzter Text, Inhalt der Zwischenablage, Audio.
- Der API-Schlüssel oder Teile davon.
- Adresse oder Host eines eigenen Servers.
- Namen der Programme, in die diktiert wurde, und Fenstertitel.
- Der Benutzername: das Home-Verzeichnis in Pfaden wird zu `~`.

Ein Test je Plattform belegt, dass der Bericht diese Dinge nicht enthält, auch wenn
das Protokoll sie enthielte, und dass die fertige Adresse die Grenzen einhält.

## Je Plattform

- **macOS:** Menüpunkt „Fehler melden …“ und ein Knopf „Fehler melden“ in der
  Fehlermeldung der Diktatanzeige. Öffnet die Adresse mit `NSWorkspace.open`.
- **Linux:** `opendictate report` zeigt den Bericht im Terminal und öffnet die
  Adresse mit `xdg-open`; `opendictate report --print` gibt nur die Adresse aus.
  Meldungen über `tr!` auf Deutsch und Englisch. Der vollständige Bericht erscheint
  vor der Rückfrage; Standard ist Nein. Aus Protokollen werden nur bekannte
  Kategorien ohne freie Details übernommen (höchstens 30).
- **Windows, iOS:** mit ihrem Track, nach demselben Muster.

`PRIVACY.md` wird im selben Änderungssatz wie die App-Funktion nachgezogen. Die
Datenschutzerklärung des Supports nennt den Bericht seit dem 13. Oktober 2026.

## Stand

- Support-Backend: nimmt die Felder an, zeigt den Bericht im Ticket und unter
  „Berichte“ eine Übersicht nach Häufigkeit; ein Klick zeigt alle Tickets mit
  diesem Fehler (live seit 13. Oktober 2026, Prüfskript von außen grün). Den
  Bericht übernimmt es nur aus dem Teil hinter `#`; im Browser
  geprüft.
- Linux: `report` und `report --print` umgesetzt; offline geprüft, Browser-Live-Test offen.
- macOS: nicht gebaut.

### Windows-Kern

Der plattformneutrale Kern baut die Adresse mit Versionen, Architektur und
begrenzten Einstellungen. Aus Protokollzeilen übernimmt er nur bekannte
Fehler-/Warnkategorien und verwirft alle freien Details. Unbekannte Modellnamen
werden durch `custom` ersetzt. Das gemeinsame Beispiel liegt unter
[`fixtures/report/`](../fixtures/report/). Menüpunkt, Browser-Aufruf und
Bestätigung sind noch nicht angeschlossen; der Kern sendet nichts.
