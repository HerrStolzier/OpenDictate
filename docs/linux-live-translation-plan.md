# Linux mit Live-Übersetzung · Plan vom 5. Oktober 2026

Entscheidung von Basti am 05.10.2026: Linux wird die aktive Plattform, der
Mac ruht (seit dem 8. Oktober laufen alle Plattformen parallel, siehe
[Neuordnung](roadmap-neuordnung-2026-10-08.md)). Neuer Schwerpunkt ist eine Übersetzung beim Diktieren: Basti spricht
Deutsch und wählt die Zielsprache (zum Beispiel Englisch); ausgegeben wird der
übersetzte Text auf demselben Weg wie ein normales Diktat. Die zentrale
Feature-/Plattformliste bleibt die [ROADMAP](../ROADMAP.md); der Linux-Ablauf,
die Schutzpolitik und die Phasen stehen im [Linux-Detailplan](linux-build-plan.md).

## Was es schon gibt

| Teil | Stand in `main` | Für die Übersetzung |
| --- | --- | --- |
| Rust-CLI `linux/` | Phase-1-Kern: Aufnahme, Audio-Prüfung, Upload, Zwischenablage, Zustände, Recovery; offline geprüft | Grundlage, wird erweitert |
| Aufnahme (cpal/PipeWire) | vorhanden, fokusneutral, ohne Fenster | unverändert |
| Hotkey | Hyprland-Bind `exec, opendictate toggle` als Beispiel | unverändert |
| Secret Service | API-Key und Recording-Auth im Keyring | derselbe API-Key genügt |
| Transkription | `POST /v1/audio/transcriptions` | bleibt Schritt 1 |
| Ausgabe | Wayland-Zwischenablage über `wl-copy` | bekommt den übersetzten Text |
| Leiste, Einfügen per Ctrl+V | seit PR #47 vorhanden (Stand 8. Oktober; am 5. Oktober fehlten sie) | Leiste zeigt die Zielsprache, Einfügen liefert den übersetzten Text |
| macOS-Swift-Code | belegtes Produkt, Stufe 2 Teil B offen | Übersetzung folgt im Mac-Track der ROADMAP |

Plattformunabhängig ist damit vor allem die Politik (Grenzen, Recovery,
Zustände) und das Provider-Format, nicht der Code: Swift und Rust teilen
keinen Code, sondern dieselben Regeln.

## Übersetzungsweg

Geprüfte Möglichkeiten bei OpenAI (Recherche am 05.10.2026, ohne Live-Test):

| Weg | Was er kann | Bewertung |
| --- | --- | --- |
| **A. Transkribieren, dann Text übersetzen** (`/v1/audio/transcriptions`, danach `/v1/chat/completions`) | Jede Zielsprache, gleicher Aufnahme-, Recovery- und Retry-Pfad, offline testbar | **Empfohlen als erster Schritt.** Ein zusätzlicher kurzer Textaufruf nach dem Diktat. |
| B. `/v1/audio/translations` (Whisper) | Übersetzt nur ins Englische | Zu eng für eine wählbare Zielsprache. |
| C. `gpt-realtime-translate` über die Realtime-API | Übersetzt während des Sprechens, liefert Audio und Text, laut OpenAI 13 Zielsprachen, 0,034 $/Minute | Echtes „Live“, aber WebSocket-Streaming, neue Abhängigkeit und Teilergebnisse. Sinnvoll als zweiter Schritt, wenn A im Alltag zu langsam ist. |

Empfehlung: **A jetzt**, C erst nach gemessener Wartezeit von A. Weg A ändert
keine Schutzregel: Audio wird erst gelöscht, wenn der übersetzte Text in der
Zwischenablage liegt; scheitert die Übersetzung, bleibt die Aufnahme für
`opendictate retry` erhalten, und Retry übersetzt erneut. Es wird nie still
der deutsche Text statt der Übersetzung ausgegeben.

Weg C widerspricht der bestehenden Regel aus der ROADMAP, unbestätigte
Teilergebnisse nicht fortlaufend ins Zielfeld zu schreiben. Er braucht daher
eigene Akzeptanzkriterien (Teil-/Endergebnis, Abbruch, Fehler) und eine
Entscheidung, bevor er gebaut wird.

## Erster Schritt (umgesetzt in PR #45)

- Einstellungen: `opendictate settings target en` schaltet die Übersetzung
  ein, `settings target off` aus. `settings translation-model NAME` wählt das
  Textmodell; Standard ist `gpt-5.4-mini`. Ältere Einstellungsdateien laden
  unverändert ohne Übersetzung.
- Ablauf: Aufnahme → Transkription → Übersetzung → Zwischenablage. Gilt für
  neue Aufnahmen und für `retry`.
- Der Transkripttext geht als Nutzerinhalt an das Modell, die Anweisung als
  Systemnachricht; das Modell soll ihn nur übersetzen, nie ausführen.
- Logs nennen nur `translation-started target=…`, nie Text.
- Offline-Tests gegen einen lokalen HTTP-Stub: Anfrageform, Fehlertext ohne
  Providerdetails, leere Antwort, alte Einstellungsdatei.

## Stand und offene Fragen

Weg A ist gebaut, am 5. bis 7. Oktober 2026 auf omarchy live belegt
([Nachweise](linux-live-2026-10-05-bis-07.md)) und seit dem 7. Oktober in
Bastis Alltag. Leistenanzeige mit Zielsprachen-Umschalter, Hotkey Super+D und
Auto-Einfügen sind ebenfalls belegt. Die nächsten Schritte des Linux-Tracks
stehen in der [ROADMAP](../ROADMAP.md#track-linux); seit dem 8. Oktober
übernehmen Beta-Nutzer die Einzelfalltests.

Offen bleibt die Entscheidung, ob Weg C (Übersetzung während des Sprechens)
nötig ist. Empfehlung: bei A bleiben, solange die Wartezeit im Alltag und in
der Beta nicht stört. Weg C braucht vorher eigene Akzeptanzkriterien
(Teil-/Endergebnis, Abbruch, Fehler), weil er der Regel widerspricht,
unbestätigte Teilergebnisse nicht ins Zielfeld zu schreiben.
