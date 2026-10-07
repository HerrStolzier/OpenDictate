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

## Offene Fragen

- Wie gut ist Voxtype mit einem deutschen Modell (z. B. `large-v3-turbo`,
  `language = "de"`) auf dem Rig? Ein Vergleich mit OpenDictate wäre ein
  eigener Test.
- Verhält sich das OpenDictate-Einfügen in Chromium-, Electron- und
  Discord-Fenstern zuverlässig?
- Soll OpenDictate sich in die Omarchy-Diktier-Anzeige der Leiste einhängen
  statt eine eigene Anzeige zu nutzen?
