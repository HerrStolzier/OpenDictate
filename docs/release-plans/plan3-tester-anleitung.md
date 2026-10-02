# OpenDictate-Beta: Anleitung für Tester

Danke fürs Testen. Du brauchst einen Mac mit Apple-Chip (M1 oder neuer),
macOS 14 oder neuer und einen **eigenen OpenAI-API-Schlüssel, der schon
bereitliegt**. Die Transkription läuft über dein OpenAI-Konto und kostet mit
`gpt-transcribe` 0,0045 $ pro Minute, also rund 0,1 Cent für ein Diktat von
15 Sekunden. Diktiere nur unverfängliche Testtexte, nichts Privates.

Bitte richte die App **ohne Hilfe** ein und notiere die Uhrzeit beim ersten
Öffnen. Wenn du hängen bleibst, schreib auf, wo, und melde dich erst dann.

## 1. Installieren

1. Das ZIP aus dem Link öffnen (Doppelklick). Es entsteht `OpenDictate.app`.
2. Die App in den Ordner **Programme** ziehen und von dort öffnen.
3. macOS fragt, ob du eine aus dem Internet geladene App öffnen willst:
   **Öffnen** wählen. Die App ist von Apple notarisiert. Meldet macOS
   stattdessen, die App sei beschädigt oder ihr Entwickler nicht
   verifizierbar: abbrechen und genau diese Meldung zurückmelden.

## 2. Einrichten

1. OpenDictate erscheint oben rechts in der Menüleiste. Panel öffnen und
   **Schlüssel eingeben** wählen, Schlüssel einfügen, **Speichern**. Er liegt
   danach im macOS-Schlüsselbund. Schick ihn niemandem.
2. Beim ersten Diktat fragt macOS nach dem **Mikrofon**: erlauben.
3. Für automatisches Einfügen braucht die App **Bedienungshilfen**
   (Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen →
   OpenDictate einschalten). Ohne diese Freigabe landet der Text nur in der
   Zwischenablage, und du fügst ihn mit ⌘V selbst ein.

## 3. Diktieren

- Ins Zieltextfeld klicken, **⌥ Option + ⇧ Umschalt + Leertaste** drücken,
  sprechen, dieselbe Kombination noch einmal drücken. Höchstens 90 Sekunden
  pro Diktat.
- Der Text erscheint im Feld und liegt zusätzlich in der Zwischenablage.
  Kam nichts an: **Text ansehen** oder **Text kopieren** im Panel.

**Deine ersten drei Diktate:**

1. Eine kurze Nachricht mit zwei Sätzen in ein leeres Feld.
2. Einen kurzen Einschub in die Mitte eines vorhandenen Satzes.
3. Ein Wort oder eine Wendung markieren und per Diktat ersetzen.

Danach bekommst du deine weiteren Aufgaben aus dem Messbogen.

## 4. Was du meldest

Pro Diktat: was du gesagt hast, was angekommen ist, in welcher App, ob der
Text **von selbst** im Feld landete oder du ihn selbst einfügen musstest, und
wie viele Sekunden vom zweiten Tastendruck bis zum fertigen Text vergingen.
Einmalig: Minuten vom ersten Öffnen bis zum ersten brauchbaren Text, jeder
Dialog, der dich überrascht hat, und dein **größter Reibungspunkt**.

Rückmeldung an Basti direkt oder mit der GitHub-Vorlage **Beta-Rückmeldung**.
GitHub-Issues sind öffentlich: dort keine Namen, keine privaten Texte und
niemals Schlüssel oder Audiodateien.
