# OpenDictate installieren (Beta)

OpenDictate ist eine Beta. Du brauchst einen Mac mit Apple-Chip (M1 oder
neuer), macOS 14 oder neuer und einen **eigenen OpenAI-API-Schlüssel**. Die
Transkription läuft über dein OpenAI-Konto und kostet mit `gpt-transcribe`
0,0045 $ pro Minute, also rund 0,1 Cent für ein Diktat von 15 Sekunden.

## 1. Herunterladen

1. Auf GitHub unter **Releases** die neueste OpenDictate-Version öffnen (als
   „Pre-release“ markiert) und unter **Assets** das ZIP laden.
2. Optional prüfen, ob die Datei unverändert ist: Im Terminal
   `shasum -a 256 ~/Downloads/OpenDictate-*.zip` ausführen und den Wert mit
   dem SHA-256 in den Release-Hinweisen vergleichen.

## 2. Installieren

1. Das ZIP öffnen (Doppelklick). Es entsteht `OpenDictate.app`.
2. Die App in den Ordner **Programme** ziehen und von dort öffnen.
3. macOS fragt, ob du eine aus dem Internet geladene App öffnen willst:
   **Öffnen** wählen. Die App ist von Apple notarisiert. Meldet macOS
   stattdessen, die App sei beschädigt oder ihr Entwickler nicht
   verifizierbar: nicht öffnen und die Meldung als Issue melden.

## 3. Einrichten

1. OpenDictate erscheint oben rechts in der Menüleiste. Panel öffnen,
   **Schlüssel eingeben** wählen, Schlüssel einfügen, **Speichern**. Er liegt
   danach im macOS-Schlüsselbund und wird nur an OpenAI geschickt.
2. Beim ersten Diktat fragt macOS nach dem **Mikrofon**: erlauben.
3. Für automatisches Einfügen braucht die App **Bedienungshilfen**
   (Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen →
   OpenDictate einschalten; unter macOS 27 heißt der Bereich „Gerätesteuerung
   und Datenzugriff“). Ohne diese Freigabe landet der Text nur in der
   Zwischenablage, und du fügst ihn mit ⌘V selbst ein. Hattest du vorher eine
   selbst gebaute OpenDictate-Version: den alten Eintrag mit „–“ entfernen,
   die App mit „+“ neu hinzufügen und OpenDictate neu starten.

## 4. Diktieren

- Ins Zieltextfeld klicken, **⌥ Option + ⇧ Umschalt + Leertaste** drücken,
  sprechen, dieselbe Kombination noch einmal drücken. Höchstens 90 Sekunden
  pro Diktat.
- Der Text erscheint im Feld und liegt zusätzlich in der Zwischenablage.
  Kam nichts an: **Text ansehen** oder **Text kopieren** im Panel. Das
  Kürzel lässt sich in den **Einstellungen** ändern.

**Zum Ausprobieren:** eine kurze Nachricht in ein leeres Feld, ein Einschub in
die Mitte eines Satzes, ein markiertes Wort per Diktat ersetzen.

## 5. Probleme melden

Auf GitHub unter **Issues** die Vorlage **Beta-Rückmeldung** wählen: Build,
macOS, Ziel-App, was du gesagt hast, was angekommen ist und wie lange es
dauerte. Issues sind öffentlich: keine privaten Texte und niemals
API-Schlüssel oder Audiodateien. Wie OpenDictate mit Audio und Text umgeht,
steht in der [Datenschutzerklärung](../../PRIVACY.md).
