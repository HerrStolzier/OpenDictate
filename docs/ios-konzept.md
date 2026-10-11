# iOS: Produktkonzept

Stand: 11. Oktober 2026. Erster Schritt im [Track iOS](../ROADMAP.md#track-ios).
Den Ablauf hat Basti am 11. Oktober gewählt
([Entscheidungs-Log](../PROJECT.md#entscheidungen)). Gebaut ist noch nichts.
Die iOS-Beta folgt nach den Betas für Linux und macOS.

## Versprechen

Auf dem iPhone in jeder App diktieren, ohne sie zu verlassen: auslösen,
sprechen, nochmal auslösen, einfügen. Wahlweise kommt der Text übersetzt an.
Eine Aufnahme geht nie verloren: Scheitert das Senden, bleibt sie auf dem Gerät
und lässt sich mit einem Tipp erneut senden. Es gibt weder eine Tastatur mit
Vollzugriff noch ein Abo. Das iPhone bekommt einen eigenen, kleineren Ablauf
und keine Portierung der Mac-Oberfläche.

## Ablauf

1. In der Ziel-App auslösen: Aktionstaste, „Auf Rückseite tippen“
   (Bedienungshilfen) oder Steuerelement im Kontrollzentrum. OpenDictate geht
   dabei nicht auf.
2. Die Live-Aktivität in der Dynamic Island zeigt „Hört zu“.
3. Erneut auslösen oder auf die Live-Aktivität tippen. Sie zeigt „Schreibt“.
4. Erfolg: Der Text liegt in der Zwischenablage, das iPhone vibriert kurz, die
   Anzeige zeigt „Kopiert“. Der Nutzer fügt mit Apples Tastatur selbst ein.
5. Fehler: Die Anzeige zeigt „Hoppla“, die Aufnahme bleibt, und „Nochmal
   senden“ steht auf dem Start-Bildschirm der App.

## Technischer Weg und Grenzen

- Aufnahme über einen App Intent für Audioaufnahmen (`AudioRecordingIntent`,
  ab iOS 18). Er nimmt nur auf, solange eine Live-Aktivität läuft
  ([Apple](https://developer.apple.com/documentation/appintents/audiorecordingintent)).
- Erster Prüfpunkt: Entwickler berichten, dass der Start aus dem Hintergrund
  teils scheitert ([Apple-Forum](https://developer.apple.com/forums/thread/836958)).
  Ob er auf einem echten iPhone ohne Öffnen der App gelingt, ist nicht belegt.
- Die App kann den Auslöser nicht selbst belegen. Sie zeigt die Einrichtung
  in den iOS-Einstellungen. Vorausgewählt ist die Aktionstaste, auf Geräten
  ohne sie „Auf Rückseite tippen“.
- Ob die App im Hintergrund selbst in die Zwischenablage schreiben darf, ist
  offen. Sonst kopiert ein mitgelieferter Kurzbefehl das Ergebnis.
- Eigene Tastaturen dürfen nicht aufnehmen; Zwischenablage und Netz brauchen
  Vollzugriff ([Richtung](ios-direction.md)). Deshalb gibt es keine Tastatur,
  solange Beta-Nutzer nicht danach fragen.

## Umfang der ersten Beta

Zwei Bildschirme: Start (Blink, Zustand, letzte Diktate zum Kopieren) und
Einstellungen.

- Einrichtung beim ersten Start: Mikrofon und Live-Aktivität erlauben,
  Auslöser wählen.
- Transkription mit eigenem OpenAI-Schlüssel im Schlüsselbund; Einfügen des
  Schlüssels über die geteilte Zwischenablage vom Mac ist möglich.
- Übersetzung nach dem Sprechen (`gpt-5.4-mini`), Zielsprache in den
  Einstellungen.
- Eigene Server-Adresse statt OpenAI, kostenlos wie auf den anderen
  Plattformen.
- Aufnahme bleibt bei Fehlern erhalten; dieselbe 90-Sekunden-Grenze pro Diktat
  wie am Mac.

Nicht in der ersten Beta: eigene Tastatur, automatisches Einfügen, Text während
des Sprechens, iPad und Apple Watch, Verbrauchsanzeige, eigenes Vokabular.

## Abnahme der ersten Testversion

Auf Bastis iPhone 15 mit „Auf Rückseite tippen“:

- In Notizen, Nachrichten und Safari: auslösen, sprechen, auslösen, einfügen;
  OpenDictate geht dabei nicht auf.
- Deutsch gesprochen, Englisch kommt an.
- Flugmodus beim Senden: Die Aufnahme bleibt, „Nochmal senden“ liefert den
  Text.
- Nach dem Stopp ist die Mikrofon-Anzeige aus.
- Mikrofon oder Live-Aktivität abgelehnt: Die App sagt in einem Satz, was
  fehlt.

## Preis, Marke, Datenschutz

- Beta kostenlos über TestFlight, danach App Store als Einmalkauf nach dem
  [Preismodell](../PROJECT.md#preismodell). Der Code bleibt offen.
- Bezahlte Apps zeigen in der EU die Händlerangaben öffentlich; das hängt am
  selben Impressum-Punkt wie Website und Support.
- Blink sitzt in der Live-Aktivität. Die Zustände heißen wie im Designsystem;
  auf dem iPhone heißt „Eingefügt“ „Kopiert“. Farben und Schriften kommen aus
  [`design/`](../design/README.md).
- Das Mikrofon läuft nur bei sichtbarer Live-Aktivität. Audio geht nur an den
  gewählten Dienst, der Schlüssel liegt im Schlüsselbund, es gibt keine
  Analyse. `PRIVACY.md` bekommt mit der Umsetzung einen iOS-Abschnitt.

## Offen

- Apples Spracherkennung auf dem Gerät (`SpeechAnalyzer`, ab iOS 26) als
  kostenlose Wahl ohne Schlüssel: im Prototyp gegen OpenAI vergleichen, dann
  entscheiden. Ohne sie reicht iOS 18 als Mindestversion.
- Draft-PR #40 (Kopplung von App und Tastatur mit Vollzugriff) passt nicht zu
  diesem Weg; ob er geschlossen wird, entscheidet Basti.
