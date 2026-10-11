# Meter

Aufnahmepegel aus Pixelzellen, der oben in `warn` und `rec` übergeht.

**Was du übergibst:** optional `levels` (eine Zahl 0–10 pro Spalte), `live` (oberste Zelle flackert) und `label`.

**Wann:** Während der Aufnahme im Menüleisten-Panel und als Illustration auf der Website. Immer zusammen mit „● REC“ und der Zeit (`label`-Stil).

**Do**
- Zellen `meter-cell` groß, Lücke `meter-gap`. Grün bis Stufe 6, `warn` 7–8, `rec` 9–10.
- Mit echten Pegelwerten füttern, sonst die Demokurve nur auf der Website.

**Don't**
- Keine weichen Balken oder Wellenlinien; der Pegel bleibt gerastert.
