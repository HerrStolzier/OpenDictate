# Linux-Umfeld: Voxtype und andere Diktier-Tools · Recherche vom 7. Oktober 2026

Anlass: Bei einer Reddit-Recherche fiel auf, dass Omarchy selbst ein
Diktier-Tool anbietet (Voxtype). Diese Notiz hält fest, was Omarchy mitbringt,
was Nutzer über die Linux-Diktier-Tools sagen und was das für OpenDictate
bedeutet. Sie ändert keine Entscheidung im [Linux-Detailplan](linux-build-plan.md)
und keine Priorität in der [ROADMAP](../ROADMAP.md).

## Methode und Grenzen

- **Omarchy-Teil: lokal belegt** auf dem Rig (Omarchy 4.0.4, Voxtype 1.1.0)
  durch Lesen der Dateien unter `/usr/share/omarchy/` und der Paketdaten.
- **Reddit-Teil: Stichprobe.** Drei Suchen über die OpenAI-Websuche
  (nur reddit.com), 12 Threads, 36 Kommentare. Jedes Zitat wurde in einem
  zweiten Durchlauf auf reddit.com gegengeprüft (alle bestätigt). Das sind
  Einzelstimmen, keine repräsentative Umfrage; mehrere Threads stammen von
  Entwicklern, die ihr eigenes Tool vorstellen.

## Was Omarchy mitbringt (lokal belegt)

| Punkt | Befund | Quelle auf dem Rig |
| --- | --- | --- |
| Installation | Menü *Install → AI → Dictation* installiert `voxtype-bin` und `wtype` | `default/omarchy/omarchy-menu.jsonc`, `bin/omarchy-voxtype-install` |
| Werbung beim Start | Beim ersten Start kommt eine Benachrichtigung „Install Dictation with Voxtype“ | `install/user/first-run/install-voxtype.hook` |
| Paket | `voxtype-bin` 1.1.0 aus dem Omarchy-Repo, voxtype.io | `pacman -Si voxtype-bin` |
| Tasten | F9 halten (Push-to-Talk), Super+Ctrl+X umschalten; nur aktiv, wenn Voxtype installiert ist | `default/hypr/bindings/voxtype.lua` |
| Leiste | eigene Diktier-Anzeige in der Omarchy-Leiste | `shell/plugins/bar/indicators/Dictation.qml` |
| Standard-Konfiguration | Modell `base.en`, Sprache `en`, lokal (Whisper), optional GPU über Vulkan | `default/voxtype/config.toml` |
| Ausgabe | `mode = "type"`: tippt den Text als simulierte Tastatur, mit Rückfall auf die Zwischenablage; `type_delay_ms = 1` | `default/voxtype/config.toml` |
| Nachbearbeitung | optionaler Befehl, z. B. ein lokales LLM zum Aufräumen | `default/voxtype/config.toml` (auskommentiert) |

Auf dem Rig ist Voxtype installiert und läuft als User-Dienst (`voxtype`,
aktiv) mit der Omarchy-Standard-Konfiguration, also parallel zu OpenDictate.
Die Tasten kollidieren nicht (OpenDictate: Super+D).

## Was Nutzer sagen (Reddit, 2026)

**Voxtype auf Omarchy**

- Der Voxtype-Entwickler verweist in r/omarchy auf die Installation über das
  Omarchy-Menü ([Kommentar](https://www.reddit.com/r/omarchy/comments/1tkffin/comment/onc5925/)).
- Tempo: Ein Nutzer meldet für kurze Diktate 12–75 s ohne Vulkan und etwa
  4–6 s mit Vulkan und vorgeladenem Modell
  ([Kommentar](https://www.reddit.com/r/omarchy/comments/1tkffin/comment/p6d8mbj/)).
- Die Zwei-Tasten-Kombination zum Umschalten gilt als hakelig; empfohlen wird
  eine einzelne Taste
  ([Thread](https://www.reddit.com/r/omarchy/comments/1qazbi5/voxtype_toggle_is_quite_buggy/)).
- Sprache: Nutzer hielten Voxtype für „nur Englisch“; tatsächlich muss man
  Modell und Sprache ändern und den Dienst neu starten
  ([Thread](https://www.reddit.com/r/omarchy/comments/1qnqom0/want_to_use_voice_dictation_with_ai_for_text/)).
  Der Standard (`base.en`, `en`) ist für Deutsch also ungeeignet.
- Es gibt schon Zusatzprojekte (eigenes Overlay/HUD, Alternativen wie OSTT und
  hyprwhspr)
  ([Thread](https://www.reddit.com/r/omarchy/comments/1vsc7yi/omarchy_voxtype_osd_hud_a_floating_clickthrough/)).

**Text ins aktive Feld bringen (Wayland/Hyprland)**

- Simuliertes Tippen mit `wtype`/`ydotool` ist die Standardlösung und die
  häufigste Klage: Zeichen fallen weg oder doppeln, Sonderzeichen und
  Umlaute machen Probleme, manche Apps (z. B. Discord, Chromium) reagieren
  anders
  ([Thread 1](https://www.reddit.com/r/hyprland/comments/1l9zcet/is_it_possible_to_map_a_special_character_to_a/),
  [Thread 2](https://www.reddit.com/r/hyprland/comments/1ovcpgj/how_hard_could_it_be_to_create_a_simple/)).
- Als Umweg nutzen Leute Zwischenablage plus `hyprctl dispatch sendshortcut`
  Ctrl+V, also denselben Weg wie OpenDictate
  ([Thread 2](https://www.reddit.com/r/hyprland/comments/1ovcpgj/how_hard_could_it_be_to_create_a_simple/)).
- Weitere Wege in der Diskussion: Wayland-Protokoll `zwp_virtual_keyboard_v1`
  (z. B. „wdotool“) und Eingabemethoden über IBus/Fcitx5. Fcitx5 gilt als
  mühsam einzurichten
  ([Thread](https://www.reddit.com/r/archlinux/comments/1vgstmw/rethinking_speechtotext_in_linux/)).

**Andere Tools**

- Genannt werden Handy, nerd-dictation, Numen (Wayland, auch Befehle) und
  Speech Note (mit Übersetzung, aber große Sprachpakete)
  ([Thread 1](https://www.reddit.com/r/linuxquestions/comments/1qvz2o4/linux_voice_dictation_software/),
  [Thread 2](https://www.reddit.com/r/linuxquestions/comments/1tv3q3q/offline_desktop_linux_speech_to_text_software/)).
- Wiederkehrender Punkt: Viele lokale Tools transkribieren gut, schreiben aber
  nicht zuverlässig ins gerade aktive Feld.
- Für Deutsch empfehlen Nutzer Handy, Whisper large-v2 und Qwen3-ASR; die
  Meinungen zu Whisper v2 gegen v3 gehen auseinander
  ([Thread](https://www.reddit.com/r/LocalLLaMA/comments/1wylbmt/are_there_any_speech_to_text_options_with_focus/)).

## Einordnung für OpenDictate

- **Voxtype ist der Standard-Konkurrent auf Omarchy.** Er ist vorinstalliert
  erreichbar, wird beim ersten Start beworben und läuft lokal ohne Kosten.
  OpenDictate muss sich daran messen, nicht an einem leeren Feld.
- **Einfügen ist ein echter Unterschied.** OpenDictate fügt über die
  Zwischenablage und Ctrl+V nur in das beim Start erfasste Fenster ein und
  prüft vorher Fokus und Zwischenablage ([Linux-README](../linux/README.md)).
  Damit entfallen die typischen `wtype`-Probleme mit Umlauten und
  verlorenen Zeichen. Ungeprüft ist, wie sich das in Chromium-Apps und
  Discord verhält.
- **Deutsch und Übersetzung sind ein zweiter Unterschied.** Voxtype steht ab
  Werk auf Englisch; die geplante Live-Übersetzung
  ([Plan](linux-live-translation-plan.md)) bietet Voxtype in dieser Form nicht
  (nur „translate to English“ in Whisper).
- **Nachteil von OpenDictate:** braucht einen OpenAI-Schlüssel und kostet pro
  Diktat; Voxtype ist offline und gratis. Das gehört ehrlich in jede
  Beschreibung.
- **Nebeneinander:** Auf einem Omarchy-Rechner können beide Tools aktiv sein.
  Die Tasten stören sich nicht, beide nutzen aber das Mikrofon.

## Lehren aus dem Wettbewerb

Ergänzende Stichprobe vom selben Tag: zwei weitere Suchen zu Gründen für
Wechsel und Kündigung (Wispr Flow, SuperWhisper, MacWhisper, Aqua Voice) und
zu gewünschten Funktionen; 9 Threads, 27 Kommentare, alle gegengeprüft.
Gleiche Grenzen wie oben.

| Lehre | Was Nutzer sagen | Folge für OpenDictate |
| --- | --- | --- |
| Abo-Müdigkeit ist der stärkste Wechselgrund | Rund 12–15 $ im Monat für Diktieren gilt als zu teuer; Leute suchen Einmalkauf oder lokal ([Thread](https://www.reddit.com/r/macapps/comments/1qjnqss/wispr_flow_is_solid_but_is_there_any_alternatives/), [Thread](https://www.reddit.com/r/WisprFlow/comments/1u0egnx/longtime_user_honestly_the_quality_has_been_going/)) | Bestätigt das Verkaufsargument „pro Minute statt Pauschale“ ([PROJECT](../PROJECT.md)). Den Preis pro Diktat sichtbar und konkret nennen. |
| Misstrauen gegen „Hülle um dieselbe Technik“ | Viele Apps verpacken dieselben Modelle und verlangen ein Abo dafür ([Thread](https://www.reddit.com/r/macapps/comments/1s5xot8/os_typewhisper_10_free_opensource_dictation_app/)) | Offen damit umgehen: MIT-Quellcode, eigener Schlüssel, kein Aufschlag. Das ist ein Vorteil, kein Makel. |
| Ungefragtes Umschreiben verärgert | Wispr Flow verändere Satzbau und setze falsche Wörter ein, auch mit abgeschalteten „Transforms“ ([Thread](https://www.reddit.com/r/WisprFlow/comments/1u0egnx/longtime_user_honestly_the_quality_has_been_going/)) | Standard bleibt eine treue Transkription. Jede Umformung (auch Übersetzung) nur bewusst eingeschaltet und sichtbar, wie heute mit dem Umschalter in der Leiste. |
| Automatische Spracherkennung irrt | Englisch gesprochen, Text kam in einer anderen Sprache ([Thread](https://www.reddit.com/r/macapps/comments/1qg73sx/wispr_flow_vs_aqua_voice/)); Wechsel zwischen Deutsch und Englisch ist ein eigener Wunsch ([Thread](https://www.reddit.com/r/macapps/comments/1w3ljff/what_is_the_best_ondevice_voice_transcription_app/)) | Feste Sprechsprache und feste Zielsprache sind ein Pluspunkt. Gemischtes Deutsch/Englisch gezielt prüfen, bevor wir Qualität behaupten. |
| „Deutsch sprechen, Englisch ausgeben“ ist ein echter Anwendungsfall | Profile je App, z. B. Deutsch sprechen und für einen X-Post Englisch ausgeben ([Thread](https://www.reddit.com/r/macapps/comments/1s5xot8/os_typewhisper_10_free_opensource_dictation_app/)); fehlende Echtzeit-Übersetzung ist ein Rückgabegrund bei SuperWhisper ([Thread](https://www.reddit.com/r/superwhisper/comments/1s7k6f3/struggling_with_the_new_superwhisper_pricing/)) | Stützt den Schwerpunkt [Live-Übersetzung](linux-live-translation-plan.md). Mögliche spätere Erweiterung: Zielsprache je Anwendung merken (nicht beauftragt). |
| Text muss im aktiven Feld ankommen | Lokale Tools transkribieren gut, schreiben aber oft nicht zuverlässig ins Feld; Linux-Nutzer fragen gezielt danach ([Thread](https://www.reddit.com/r/linux/comments/1tc17yf/i_built_an_open_source_terminal_first_voicetotext/), [Thread](https://www.reddit.com/r/linuxquestions/comments/1tv3q3q/offline_desktop_linux_speech_to_text_software/)) | Einfügen mit Fokus- und Zwischenablage-Prüfung zur Hauptbotschaft für Linux machen. Vorher Chromium-, Electron- und Discord-Fenster prüfen. |
| Lokal und offline zählt, besonders unter Linux | Misstrauen gegen Apps, die die Kernfunktion an Dritte auslagern; Offline-Ausfall bei schlechtem Netz ([Thread](https://www.reddit.com/r/linux/comments/1tc17yf/i_built_an_open_source_terminal_first_voicetotext/), [Thread](https://www.reddit.com/r/macapps/comments/1qg73sx/wispr_flow_vs_aqua_voice/)) | Größte Schwäche von OpenDictate. Der geplante [konfigurierbare Endpunkt](../ROADMAP.md) (lokaler Whisper-Server) ist die passende Antwort; bis dahin im Datenschutztext klar sagen, dass Audio zu OpenAI geht. |
| Eigenes Wörterbuch | Wiederkehrender Wunsch nach eigenem Vokabular und Ersetzungen ([Thread](https://www.reddit.com/r/macapps/comments/1w3ljff/what_is_the_best_ondevice_voice_transcription_app/), [Thread](https://www.reddit.com/r/LocalLLaMA/comments/1srcoso/anyone_here_actually_using_voice_input_in_their/)) | Kandidat für die ROADMAP (nicht beauftragt). |
| Tastenkombinationen | Zwei-Tasten-Akkorde gelten als hakelig; eine einzelne Taste oder Halten-zum-Sprechen wird empfohlen ([Thread](https://www.reddit.com/r/omarchy/comments/1qazbi5/voxtype_toggle_is_quite_buggy/)) | Stützt die ROADMAP-Punkte Hold-to-talk und Gaming-Shortcut. |
| Support entscheidet mit | Unbeantwortete Anfragen führten zum Wechsel ([Thread](https://www.reddit.com/r/macapps/comments/1t0vqm6/macwhisper_support/)) | Im öffentlichen Betatest (Stufe 6) schnelle Antworten auf GitHub-Issues einplanen. |

## Offene Fragen

- Verhält sich das OpenDictate-Einfügen in Chromium-, Electron- und
  Discord-Fenstern zuverlässig?
- Soll OpenDictate sich in die Omarchy-Diktier-Anzeige der Leiste einhängen
  statt eine eigene Anzeige zu nutzen?
