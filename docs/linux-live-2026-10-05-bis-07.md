# Linux: Live-Nachweise vom 5. bis 7. Oktober 2026

Datierte Belege für die Linux-Phasen 1 und 2 auf Bastis omarchy-Rechner
(Hyprland). Sie gelten für die genannten Branch- und Installationsstände und
sind Einzelfälle, keine allgemeine Qualitätsaussage. Der Plan dazu:
[Übersetzung](linux-live-translation-plan.md); die Phasen:
[Linux-Detailplan](linux-build-plan.md); der belegte Stand:
[remaining-acceptance](remaining-acceptance.md#linux).

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
