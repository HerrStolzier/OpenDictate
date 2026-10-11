# Button

Knopf mit Stufenecken in Geist Mono; `primary` in `signal` höchstens einmal pro Ansicht.

**Was du übergibst:** `children` (die Beschriftung), optional `variant` (`primary`, `secondary`) und alle üblichen Button-Attribute (`onClick`, `disabled`, `type` …).

**Wann:** `primary` für die eine Sache, um die es in der Ansicht geht („Nochmal senden“, „Für macOS laden“). Alles andere ist `secondary` („Abbrechen“, „Auf GitHub ansehen“).

**Do**
- Verb zuerst, kurz, Satzanfang groß: „Nochmal senden“.
- Höhe 44 px bleibt, damit der Knopf gut zu treffen ist.
- Der Fokusring liegt außerhalb der Stufenecken: 2 px Abstand, 2 px `focus-ring`.

**Don't**
- Keine runden Ecken, keine Verläufe, kein Schatten.
- Nicht zwei `primary` nebeneinander.
