# Linux zuerst, mit Live-Übersetzung · Plan vom 5. Oktober 2026

Entscheidung von Basti am 05.10.2026: Linux wird die aktive Plattform, der
Mac ruht. Neuer Schwerpunkt ist eine Übersetzung beim Diktieren: Basti spricht
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
| Tray/Panel, Einfügen per Ctrl+V | fehlen | unabhängig von der Übersetzung |
| macOS-Swift-Code | belegtes Produkt, Stufe 2 Teil B offen | ruht, wird nicht angefasst |

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

## Erster Schritt (in diesem Branch umgesetzt)

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

## Live-Nachweis · 5. Oktober 2026

Mit Bastis Go auf omarchy (Hyprland), Rust 1.98.1, Branch-Stand `68edc00`,
Mikrofon JBL Quantum Stream Talk als Standard-Eingang. `check-linux.sh` war
dort grün (30 Tests). Gemessen vom zweiten `toggle` bis `idle`:

| Fall | Ergebnis | Zeit |
| --- | --- | --- |
| Diktat ohne Übersetzung | Text in der Zwischenablage, laut Basti korrekt | 2,3 s |
| Diktat mit `target en`, `gpt-5.4-mini` | englischer Text in der Zwischenablage, laut Basti gut | 3,6 s |
| Übersetzungsmodell `gibt-es-nicht` | „Übersetzungsmodell ist nicht verfügbar. Aufnahme für Wiederholung behalten.“ | 1,3 s |
| `retry` danach mit `gpt-5.4-mini` | „Wiederholte Übersetzung (en) in Zwischenablage kopiert“ | 1,7 s |

Ein Versuch ohne gesprochene Sprache endete wie vorgesehen mit „Keine Sprache
erkannt; Aufnahme wurde nicht hochgeladen.“ Beim Test fiel auf, dass
`secrets status` vorhandene Schlüssel als fehlend meldete (libsecret 0.21.7
schreibt Treffer von `secret-tool search` nach stderr); behoben in `68edc00`
und live bestätigt. Einstellungen wurden danach zurückgesetzt, Recovery und
Pending waren leer. Das sind Einzelfälle, keine allgemeine Qualitätsaussage.

Nicht live geprüft: Netzabbruch und Abbruch während der Übersetzung.

## Live-Nachweis Leiste und Einfügen · 5./6. Oktober 2026

Mit Bastis Go auf omarchy: Omarchy-Shell 4.0.4 (Befehlsmodul vorne in
`bar.layout.right`), Hyprland 0.56.2 mit Lua-Konfiguration, Branch-Stand
`fae3dae`, `check-linux.sh` dort grün (40 Tests). Die Lua-Form
`hl.dsp.send_shortcut` antwortete wörtlich `ok`.

| Fall | Ergebnis |
| --- | --- |
| Klick auf das Leistensymbol | „EN“ an und wieder aus, per Bildschirmfoto geprüft |
| Diktat in einen Editor (`omawrite`) | Text eingefügt, Protokoll `insert-sent` |
| Diktat in ein Terminal (`foot`) | Text in der Eingabezeile, ohne Enter, `insert-sent` |
| Fensterwechsel direkt nach dem Stopp | nichts eingefügt, Meldung „Zielfenster ist nicht mehr vorne; liegt in der Zwischenablage“, `insert-skipped reason=target-not-frontmost` |
| Mit Übersetzung `en` in den Editor | englischer Text eingefügt |

Bildschirmfotos von Basti vom 06.10. bestätigen Editor, Terminal,
Fensterwechsel und Übersetzung. Wartezeiten wurden nicht gemessen; das
Protokoll hat keine Zeitstempel. Einzelfälle, keine allgemeine Aussage über
alle Programme. Der Nachweis gilt für `fae3dae`. Danach geänderte Prüfungen
(exakter Zwischenablage-Vergleich vor dem Fenstercheck, Zeitlimit für
`wl-paste`, Aufnahme bleibt bei geänderter oder unlesbarer Zwischenablage und
bei Abbruch während der Auslieferung) sind nur offline geprüft.

## Live-Nachweis Fehlerfälle · 7. Oktober 2026

Mit Bastis Go auf omarchy, installierter Stand `f3f0ef9`, Übersetzung `en`,
Einfügen an.

| Fall | Ergebnis |
| --- | --- |
| `opendictate cancel` direkt nach dem Stopp (Transkription lief, Übersetzung noch nicht gestartet) | nichts eingefügt, Meldung „Verarbeitung abgebrochen. Aufnahme für Wiederholung behalten.“, `recording-kept`, danach `idle`; `retry` übersetzte und kopierte in 1,9 s, Recovery-Ordner danach leer |
| Netz am ganzen PC direkt nach dem Stopp aus, nach 36 s wieder an | nichts eingefügt, Aufnahme behalten mit „Netzwerkfehler bei der Transkription. Aufnahme für Wiederholung behalten.“, aber erst rund zwei Minuten nach dem Stopp |

Die Meldung kam so spät, weil der hängende Upload erst am Lese-Zeitlimit von
120 Sekunden scheiterte. Seitdem hat jede Anfrage ein Zeitlimit
(Transkription 15 s plus Upload-Zeit, Übersetzung 15 s plus Textlänge, höchstens
60 s); das ist nur offline geprüft, mit einem Testserver, der nie antwortet.

Nebenwirkung des Testaufbaus, kein Fehler von OpenDictate: Nach
`nmcli networking off/on` blieb die Namensauflösung über Tailscale bis zum
Neustart gestört; ein `retry` in dieser Zeit scheiterte erneut mit
Netzwerkfehler und behielt die Aufnahme. Nach dem Neustart lieferte `retry` die
Übersetzung in 3,7 s. Netzausfälle künftig nur für OpenDictate simulieren,
nicht das ganze Netz abschalten. Ein Abbruch genau während der Übersetzung ist
nicht getrennt geprüft; derselbe Abbruchmarker gilt dort. Einzelfälle, keine
allgemeine Aussage.

## Nächste Schritte auf Linux

1. Fehlerfälle live: am 07.10. während der Transkription belegt (siehe oben).
   Offen: die kürzeren Zeitlimits und einen Ausfall genau während der
   Übersetzung live bestätigen, ohne das ganze Netz abzuschalten.
2. Einige Tage im Alltag nutzen und die Wartezeit mit Übersetzung beobachten.
3. Leistenstatus (Omarchy-Leiste oder Waybar) mit sichtbarer Zielsprache und Klick-Umschalter: gebaut und
   am 05./06.10. live erprobt (siehe oben).
4. Physischer Hyprland-Hotkey: Super+D am 05.10. eingerichtet und bestätigt.
5. Auto-Einfügen (Phase 2): am 05./06.10. in Editor und Terminal live erprobt,
   Fensterwechsel-Schutz bestätigt.
6. Erst danach: Weg C prüfen, Paketierung (Phase 3).

## Offene Entscheidungen für Basti

- **Live heißt:** Übersetzung kommt direkt nach dem Ende der Aufnahme (Weg A,
  gebaut und am 05.10. live erprobt) oder schon während des Sprechens (Weg C).
  Empfehlung: bei A bleiben, solange die Wartezeit im Alltag nicht stört.
