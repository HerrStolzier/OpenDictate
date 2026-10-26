# OpenDictate für Linux (Beta)

[English](README.md) · Deutsch

OpenDictate nimmt auf Tastendruck deine Stimme auf, lässt sie von OpenAI (oder
deinem eigenen Server, siehe [Eigenen Server verwenden](#eigenen-server-verwenden))
abschreiben, übersetzt sie auf Wunsch (zum Beispiel ins Englische) und fügt den
Text in das Fenster ein, das beim Start vorne war. Es ist ein kleines
Kommandozeilenprogramm ohne eigenes Fenster, gedacht für Hyprland.

**Stand:** Öffentliche Beta seit dem 11. Oktober 2026:
[Pre-Release `linux-v0.1.0-beta.1`](https://github.com/HerrStolzier/OpenDictate/releases/tag/linux-v0.1.0-beta.1).
Erprobt auf einem einzigen Rechner
(Omarchy 4 mit Hyprland 0.56, Arch Linux), dort seit dem 7. Oktober 2026 im
Alltag. Die [bekannten Grenzen](#bekannte-grenzen) unten gelten.

## Was es kostet

Nichts, wenn ein Modell auf deinem eigenen Rechner läuft, zum Beispiel
whisper.cpp (siehe [Eigenen Server verwenden](#eigenen-server-verwenden)); deine
Aufnahme verlässt den Rechner dann nicht. Mit OpenAI brauchst du einen eigenen
API-Schlüssel und zahlst OpenAI direkt nach Nutzung, kein Abo: 0,0045 $ pro
Minute Sprache, ein typisches Diktat von 15 Sekunden kostet also rund einen
Zehntel Cent. Die Übersetzung kommt mit einem kleinen Betrag für das Textmodell
(`gpt-5.4-mini`) dazu. So hat OpenAI von Juli bis Oktober 2026 abgerechnet; die
Preise legt OpenAI fest, maßgeblich ist deren Preisliste. OpenDictate selbst ist kostenlos und quelloffen (MIT).

## Kein Diktat geht verloren

Scheitert die Abschrift, die Übersetzung oder das Einfügen (Netz weg,
Zeitüberschreitung, Abbruch), bleibt die Aufnahme auf deinem Rechner erhalten.
Gelöscht wird eine Aufnahme erst, wenn ihr Text in der Zwischenablage
angekommen ist. Normalerweise legt OpenDictate dafür eine gesicherte Kopie an:
`opendictate retry` sendet sie nochmal, aufbewahrt werden höchstens fünf
solcher Kopien für 24 Stunden. Gelingt diese Kopie nicht (zum Beispiel weil der
Schlüsselbund gesperrt ist), bleibt die Originaldatei unter
`~/.local/state/opendictate/pending/` liegen; `retry` greift dann nicht. Auch
diese Datei hält die 24-Stunden-Grenze ein: Die nächste Aufnahme danach räumt
sie weg. Fällt das Mikrofon während der
Aufnahme aus oder wird abgezogen, bekommst du eine Benachrichtigung, und der Ton
bis dahin wird genauso für `retry` gesichert. Eine zu kurze oder stille Aufnahme
wird nicht gesendet; sie wird auch gesichert, aber `retry` übergeht sie
(siehe [Ablauf und Schutzregeln](#ablauf-und-schutzregeln)).

## Was du brauchst

- Arch Linux oder ein Arch-basiertes System mit **Hyprland** (zum Beispiel
  Omarchy). Andere Distributionen und Compositoren sind nicht geprüft.
- Ein Mikrofon, das als Standardeingang eingestellt ist. OpenDictate nimmt
  über das ALSA-Standardgerät auf; mit PipeWire braucht es dafür
  `pipewire-alsa` (bei Omarchy schon dabei).
- Einen Schlüsselbund mit Secret Service, zum Beispiel `gnome-keyring`
  (bei Omarchy schon dabei). Der API-Schlüssel liegt nur dort, nie in einer
  Datei.
- Eine normale Desktop-Sitzung, die `XDG_RUNTIME_DIR` setzt (systemd tut das).
  Das CLI legt seinen Zustand dort ab und weicht nicht auf `/tmp` aus.
- Einen OpenAI-API-Schlüssel mit Guthaben
  ([platform.openai.com](https://platform.openai.com/api-keys)) oder einen
  [eigenen Server](#eigenen-server-verwenden), der die OpenAI-Schnittstelle
  spricht, zum Beispiel ein Modell auf deinem eigenen Rechner.

## Installieren

Einmalig die Bauwerkzeuge holen und das Paket aus dem Quellcode bauen. `makepkg`
baut das Programm, führt die Tests aus und installiert es nach Rückfrage mit
`pacman` als Paket `opendictate`. Auch andere Projekte heißen so: Das
Snap-Paket `opendictate` ist nicht dieses, also bitte aus diesem Repository bauen.

```bash
sudo pacman -S --needed base-devel git rust
git clone --branch linux-v0.1.0-beta.1 https://github.com/HerrStolzier/OpenDictate.git
cd OpenDictate/linux/packaging/arch
makepkg -si
```

Wer Rust über `rustup` verwaltet, installiert statt `rust` das Paket `rustup`
mit einer Stable-Toolchain. Ein nur im Home-Verzeichnis installiertes `rustup`
kennt `pacman` nicht; `makepkg` meldet dann `cargo` als fehlend. In dem Fall
zuerst `sudo pacman -S --needed alsa-lib hyprland libsecret wl-clipboard` und
dann `makepkg -i --nodeps` statt `makepkg -si`. `makepkg` prüft dann keine
Abhängigkeiten mehr; `pacman` verweigert die Installation aber, wenn eines
dieser Pakete fehlt.
Das Paket baut mit der Stable-Toolchain; gebaut auf Omarchy mit Rust 1.98.1. Danach liegt das Programm unter
`/usr/bin/opendictate`; `opendictate version` zeigt die Version.

**Aktualisieren:** Der Klon steht auf einem Release-Tag, `git pull` greift
daher nicht. Im Ordner `OpenDictate` `git fetch --tags` und `git checkout <Tag>`
mit dem Tag des neuesten Linux-Releases von der
[Release-Seite](https://github.com/HerrStolzier/OpenDictate/releases)
ausführen, dann in `linux/packaging/arch` `makepkg -sfi`. Das `-f` erzwingt einen Neubau, auch wenn
die Versionsnummer gleich geblieben ist; ohne es installiert `makepkg` ein dort
schon liegendes älteres Paket.

**Entfernen:** `sudo pacman -R opendictate`. Einstellungen, Protokoll und
gesicherte Aufnahmen bleiben dabei liegen; sie stehen in
`~/.config/opendictate/` und `~/.local/state/opendictate/`. Die beiden
Schlüsselbund-Einträge entfernt
`secret-tool clear service opendictate key api-key` und
`secret-tool clear service opendictate key recording-auth`.

## Einrichten

**Am schnellsten:** `opendictate setup` im Terminal starten. Es fragt zwei
Dinge:

1. Wer abschreibt: OpenAI mit deinem API-Schlüssel (es fragt den Schlüssel
   verdeckt ab und prüft ihn vor dem Speichern; nur ein Schlüssel, der die
   Prüfung besteht, ersetzt einen gespeicherten), oder ein
   [eigener Server](#eigenen-server-verwenden).
2. Mit welchem Kürzel du ein Diktat startest und stoppst: Super+D, F9 oder,
   bei US-Tastaturlayout, die rechte Alt-Taste allein. Es zeigt, welche Tasten
   Hyprland schon belegt, und trägt die Zeile nach Rückfrage in deine
   Hyprland-Konfiguration ein, mit einer Sicherung neben der Datei
   (`….opendictate-backup-…`; die drei neuesten bleiben, ältere werden
   entfernt). Bei Omarchy ist das
   `~/.config/hypr/bindings.lua`; eine reine Lua-Konfiguration bekommt nur die
   Zeile zum Kopieren. Übernimmt Hyprland die neue Zeile nicht, stellt setup
   die Datei wieder her, und das bisherige Kürzel gilt weiter.

Danach sind die Schritte 3 bis 5 unten optional. `opendictate shortcut status`
zeigt später das aktuelle Kürzel, `opendictate shortcut set f9` ändert es ohne
Rückfragen.

**Stattdessen von Hand:**

**1. API-Schlüssel speichern.** Der Schlüssel wird nur über eine Pipe
angenommen, nie als Argument oder Umgebungsvariable. Dieser Befehl fragt ihn
verdeckt ab (Schlüssel einfügen, Enter):

```bash
read -rsp "OpenAI-API-Schlüssel: " key && printf '%s' "$key" | opendictate secrets set-api-key; unset key
opendictate secrets status
```

`secrets status` meldet `api-key=present`, wenn es geklappt hat.

**2. Tastenkürzel festlegen.** OpenDictate bringt kein eigenes Kürzel mit; du
bindest `opendictate toggle` in Hyprland an eine Taste, zum Beispiel Super+D.
Prüfe vorher, dass die Taste frei ist.

Omarchy 4 mit Lua-Konfiguration (Hyprland 0.56): in
`~/.config/hypr/bindings.lua` eine Zeile ergänzen:

```lua
o.bind("SUPER + D", "OpenDictate", "opendictate toggle")
```

Klassische Konfiguration (`~/.config/hypr/hyprland.conf` oder eine dort
eingebundene Datei), siehe [hyprland.conf.example](hyprland.conf.example):

```ini
bind = SUPER, D, exec, opendictate toggle
```

Hyprland lädt die Änderung beim Speichern neu.

**3. Leistenanzeige (optional).** Blink, der Cursor von OpenDictate, zeigt in
der Leiste, ob OpenDictate zuhört oder schreibt, und die eingestellte
Zielsprache; ein Klick schaltet die Übersetzung um. Einrichtung unter [Leistenanzeige](#leistenanzeige).

**4. Sprache.** Meldungen und Hilfe folgen der Systemsprache: Deutsch, wenn
`LC_ALL`, `LC_MESSAGES` oder `LANG` (die erste gesetzte) mit `de` beginnt,
sonst Englisch. Auf einem deutschen System ist auch die gesprochene Sprache
zunächst Deutsch, sonst wird sie erkannt. Umstellen zum Beispiel mit
`opendictate settings language en`, Erkennung mit
`opendictate settings language auto`.

**5. Übersetzung (optional).** `opendictate settings target en` übersetzt jedes
Diktat ins Englische, `opendictate settings target off` schaltet das wieder
aus.

## Benutzen

1. Klicke in das Feld, in das der Text soll.
2. Kürzel drücken, sprechen, Kürzel noch einmal drücken.
3. Nach wenigen Sekunden steht der Text im Feld. Ist inzwischen ein anderes
   Fenster vorne, wird nicht eingefügt; der Text liegt dann in der
   Zwischenablage und eine Meldung sagt das.

In bekannten Terminals (zum Beispiel Alacritty, foot, kitty) fügt OpenDictate
mit Strg+Umschalt+V ein, sonst mit Strg+V. Text mit Zeilenumbruch wird nirgends
automatisch eingefügt, weil auch Editoren und Browser ein Terminal enthalten
können. Er bleibt in der Zwischenablage und eine Meldung sagt
das. Steuerzeichen im Transkript werden entfernt, bevor etwas kopiert wird. Der
Text liegt danach immer auch in der Zwischenablage. `opendictate settings insert
off` schaltet das automatische Einfügen ab. `opendictate cancel` bricht eine
laufende Aufnahme ab; die Aufnahme bleibt für `retry` erhalten.

## Eigenen Server verwenden

Statt an OpenAI kann OpenDictate Aufnahmen an einen eigenen Server schicken,
der die OpenAI-Schnittstelle spricht, zum Beispiel ein Sprachmodell auf diesem
Rechner. Das kostet nichts pro Minute, und die Aufnahme verlässt den Rechner
nicht.

```bash
opendictate settings server http://127.0.0.1:8080/v1
opendictate settings model NAME              # Modellname, den dein Server erwartet
opendictate settings translation-model NAME  # nur, wenn du übersetzt
opendictate settings server off              # zurück zu OpenAI
```

- Die **Server-Adresse** ist die Basisadresse inklusive `/v1`. OpenDictate
  hängt `/audio/transcriptions` für die Abschrift und `/chat/completions` für
  die Übersetzung an; beides geht an dieselbe Adresse. Ein Server, der nur
  abschreibt, funktioniert mit ausgeschalteter Übersetzung.
- `https://` geht für jede Adresse, einfaches `http://` nur für diesen Rechner
  (`localhost`, `127.0.0.1`, `::1`, `[::1]`). Adressen mit Zugangsdaten, `?` oder `#`
  werden abgelehnt.
- Ein Server auf diesem Rechner bleibt nur privat, wenn du den Rechner allein
  nutzt: Ein anderer lokaler Nutzer könnte zuerst ein Programm auf demselben
  Port starten und bekäme dann deine Aufnahmen und Texte.
- **API-Schlüssel:** Eine Adresse auf diesem Rechner bekommt keinen Schlüssel
  und braucht keinen. Jeder andere Server bekommt deinen gespeicherten
  Schlüssel (praktisch für OpenAI-kompatible Anbieter), auch wenn er für OpenAI
  gedacht ist; nutze nur Server, denen du ihn anvertraust.
- Mit eigenem Server sind Modellnamen frei, mit OpenAI gelten nur die bekannten
  Transkriptionsmodelle. `settings server off` setzt ein Modell zurück, das
  OpenAI nicht anbietet.
- Alternativ setzt die Umgebungsvariable `OPENAI_BASE_URL` die Adresse; eine
  gespeicherte Adresse hat Vorrang. Hyprland muss die Variable sehen, nicht
  nur deine Shell. Wer diese Variable für deine Sitzung setzen kann, leitet
  deine Aufnahmen, Texte und, bei einer `https://`-Adresse außerhalb dieses
  Rechners, deinen API-Schlüssel an diesen Server um.
- Lokale Modelle auf dem Prozessor sind langsam, deshalb wartet OpenDictate
  bei einem eigenen Server bis zu 2 Minuten (plus Upload-Zeit) statt
  15 Sekunden.
- Das Protokoll nennt nur den Host des Servers, nie Pfad oder Schlüssel.

Beispiel mit [whisper.cpp](https://github.com/ggml-org/whisper.cpp) (nur
Abschrift; es nutzt das Modell, mit dem es per `-m` gestartet wurde):

```bash
whisper-server -m models/ggml-base.bin --host 127.0.0.1 --port 8080 \
  --inference-path /v1/audio/transcriptions
opendictate settings server http://127.0.0.1:8080/v1
```

**Geprüft ist nur OpenAI.** Eigene Server sind neu in dieser Beta; ob ein
bestimmter Server funktioniert, ist genau die Rückmeldung, die uns hilft.

## Wenn etwas nicht klappt

- `opendictate status` zeigt, ob gerade aufgenommen oder verarbeitet wird.
- `opendictate retry` sendet die letzte gesicherte Aufnahme nochmal.
- „Aufnahme konnte nicht starten“: Meist ist kein Mikrofon verfügbar. Mit
  `wpctl status` prüfen, ob unter Audio → Sources eine Quelle steht und als
  Standard (`*`) markiert ist; Mikrofon anstecken oder wählen und erneut
  versuchen.
- Das Protokoll `~/.local/state/opendictate/operations.log` enthält Abläufe und
  Zeiten, aber nie deinen Text, deinen Schlüssel oder Audio. Nur du kannst es
  lesen; ab 1 MiB wandert es nach `operations.log.1`, und nur diese eine ältere
  Datei bleibt.
- Fehler und Wünsche bitte als
  [GitHub Issue](https://github.com/HerrStolzier/OpenDictate/issues/new?template=linux-beta-feedback.md) melden,
  mit `opendictate version`, Hyprland-Version (`hyprctl version`), dem
  Programm, in das eingefügt werden sollte, und den passenden Zeilen aus dem
  Protokoll. Keine privaten Texte, keine Schlüssel, keine Audiodateien.

## Bekannte Grenzen

Diese Fälle sind bewusst nicht vorab geprüft; Rückmeldungen dazu helfen am
meisten:

- Einfügen in Chromium-, Electron- und Discord-Fenstern (geprüft sind nur ein
  Texteditor und ein Terminal).
- Gemischtes Deutsch und Englisch in einem Diktat mit Übersetzung.
- Abbruch oder Netzausfall genau während der Übersetzung.
- Die Zeitlimits (Netzfehler nach etwa 20 Sekunden) sind nur offline geprüft.
- Nur Hyprland, nur Arch-basierte Systeme. Kein Settings-Fenster, kein
  Halten-zum-Sprechen. Eigenes Vokabular ist im CLI-Code umgesetzt; die
  Erkennung damit ist noch nicht live abgenommen. Geprüft ist nur OpenAI; eigene
  Server sind ungetestet.
- Höchstens 90 Sekunden pro Diktat.

## Datenschutz in Kürze

Die Aufnahme geht per HTTPS an OpenAI zur Abschrift, mit eingeschalteter
Übersetzung danach der Text an OpenAI zur Übersetzung. An niemanden sonst. Mit
[eigenem Server](#eigenen-server-verwenden) geht beides stattdessen nur an
diesen Server. Details: [PRIVACY.md](../PRIVACY.md#linux-cli).

## Alle Befehle

```bash
opendictate setup                   # geführte Einrichtung: Schlüssel oder eigener Server, Kürzel
opendictate toggle                  # Diktat starten oder beenden
opendictate status                  # idle / starting / recording / processing / delivering
opendictate bar                     # Status als JSON-Zeile für die Leiste (`waybar` gleichwertig)
opendictate cancel                  # Aufnahme/Verarbeitung sicher abbrechen
opendictate retry                   # letzte gesicherte Aufnahme nochmal senden
opendictate retry --skipped         # letzte zu kurze oder stille trotzdem senden
opendictate version                 # Version anzeigen
opendictate settings show
opendictate settings model gpt-transcribe
opendictate settings language de    # `auto` für automatische Erkennung
opendictate settings target en      # Diktat ins Englische übersetzen; `off` aus
opendictate settings target toggle  # aus bzw. mit letzter Zielsprache (sonst en) an
opendictate settings insert off     # nur Zwischenablage, kein Auto-Einfügen
opendictate settings translation-model gpt-5.4-mini
opendictate settings server http://127.0.0.1:8080/v1  # eigener Server; `off` für OpenAI
opendictate shortcut status         # aktuelles Kürzel, welche Tasten frei sind
opendictate shortcut set f9         # super-d, f9 oder right-alt in die Hyprland-Konfiguration
opendictate secrets status
```

## Leistenanzeige

`opendictate bar` gibt jede Abfrage eine JSON-Zeile im Waybar-Format aus. Der
Text ist Blink, der Block-Cursor von OpenDictate `▮`, dahinter `REC` während der
Aufnahme, `…` während das Mikrofon startet oder er schreibt, und die aktive
Zielsprache (z. B. `▮ REC EN`). Der Tooltip nennt den Zustand: Bereit, Hört zu
oder Schreibt, kurz auch „Mikrofon startet“.
Während der Aufnahme trägt die Zeile die Klasse `active`. Ein Klick soll
`settings target toggle` aufrufen. Die Ausgabe enthält nur Zustand und
Einstellungen, nie Text. Eine Nerd Font ist nicht nötig. Die Beispieldateien liegen nach der Installation auch unter
`/usr/share/doc/opendictate/`. Das Pre-Release `linux-v0.1.0-beta.1` zeigt noch
Mikrofon und Sanduhr aus der Nerd Font; Blink kommt mit dem nächsten
Linux-Release.

- Omarchy 4 (Omarchy-Shell-Leiste): Befehlsmodul nach
  [omarchy-bar.example.json](omarchy-bar.example.json) in
  `~/.config/omarchy/shell.json` unter `bar.layout` ergänzen. Die Leiste hebt
  das Modul während der Aufnahme hervor.
- Waybar: [waybar.example.jsonc](waybar.example.jsonc) und
  [waybar.example.css](waybar.example.css) in den Farben von OpenDictate;
  dort wird Blink während der Aufnahme rot und blinkt, beim Schreiben grün.

## Technische Details

### Selbst bauen und prüfen

Geprüft mit `rustc 1.98.1` (CI-Skript und Paketbau auf Omarchy). Eine niedrigere
Mindestversion ist nicht verifiziert:

```bash
cargo fmt --manifest-path linux/Cargo.toml -- --check
cargo test --manifest-path linux/Cargo.toml
cargo clippy --manifest-path linux/Cargo.toml --all-targets -- -D warnings
cargo build --release --manifest-path linux/Cargo.toml
```

Das Binary liegt in `linux/target/release/opendictate`. `linux/target/` gehört
nicht ins Git. Die macOS-App und ihre Swift-CI werden davon nicht verändert.
Das Arch-Paket ([PKGBUILD](packaging/arch/PKGBUILD)) baut aus dem Checkout, in
dem es liegt; seine Version muss der in `Cargo.toml` entsprechen.

Für Entwicklung und Tests sind keine echten Secrets nötig; die HTTP-Tests
verwenden nur einen lokalen Stub. Der Schlüssel kommt aus jeder vertrauten
Quelle per Pipe (`trusted-secret-command | opendictate secrets set-api-key`).

### Ablauf und Schutzregeln

- `toggle` startet eine fokusneutrale Aufnahme. Solange das Mikrofon öffnet,
  ist der Zustand `starting`; erst danach gilt die Aufnahme als gestartet, und
  ein Mikrofon, das scheitert oder länger als 5 Sekunden braucht, beendet den
  Start mit einer Benachrichtigung. `cancel` während `starting` beendet den
  Start, der dann nicht als gestartet gemeldet wird; schon aufgenommener Ton
  bleibt erhalten. Der zweite Aufruf beendet die Aufnahme und
  wechselt auf `processing`; weitere Starts während `starting`, `processing`
  oder `delivering` werden abgelehnt.
- Unter 1 Sekunde oder ohne 50-ms-Fenster oberhalb −45 dBFS erfolgt kein Upload.
  Die Aufnahme wird mit Vermerk gesichert: `retry` übergeht sie, und
  `retry --skipped` sendet die letzte solche Aufnahme trotzdem. Sie zählt wie
  jede andere zu den fünf neuesten gesicherten Aufnahmen.
  Erkannte Sprache erhält 0,25 Sekunden Rand; nur Einsparungen ab 0,35 Sekunden
  erzeugen eine zugeschnittene Upload-WAV. Das 90-Sekunden-Limit bleibt aktiv.
- Mit gesetzter Zielsprache wird das Transkript danach über
  `/chat/completions` desselben Servers übersetzt und nur die Übersetzung ausgegeben. Scheitert
  die Übersetzung oder ist sie leer, bleibt die Aufnahme wie bei jedem anderen
  Fehler erhalten; `retry` übersetzt erneut. Am 05.10. auf omarchy live
  erprobt ([Plan mit Nachweis](../docs/linux-live-translation-plan.md)).
- Ein nichtleeres Transkript wird ausschließlich in die Wayland-Zwischenablage
  geschrieben. Erst nach erfolgreichem Copy darf die zugehörige Aufnahme
  entfernt werden. Ein Verlauf für die Zwischenablage (etwa cliphist, clipman
  oder der deiner Desktop-Shell) behält eine eigene Kopie jedes Transkripts;
  das kann OpenDictate weder verhindern noch löschen.
- Auto-Einfügen (Standard an, `settings insert off` schaltet es ab): Beim
  Start wird das aktive Hyprland-Fenster erfasst. Nach dem Kopieren prüft das
  CLI, dass genau dieses Fenster noch vorne ist und die Zwischenablage noch den
  Text enthält, und sendet dann per `hyprctl dispatch` Ctrl+V, in bekannten
  Terminals Ctrl+Shift+V, an dieses Fenster. Mehrzeiliger Text wird in keine
  App automatisch eingefügt; er bleibt in der Zwischenablage. Zuerst wird die Lua-Form
  `hl.dsp.send_shortcut` verwendet (Hyprland mit Lua-Konfiguration, z. B.
  0.56); nur wenn Hyprland sie eindeutig ablehnt, die ältere Form
  `sendshortcut`. Sonst bleibt es bei
  der Zwischenablage mit Hinweis. Enthält die Zwischenablage vor dem Einfügen
  nicht mehr exakt den Text oder lässt sie sich binnen 2 Sekunden nicht lesen,
  gilt das Diktat als nicht geliefert und die Aufnahme bleibt für `retry`
  erhalten; ebenso nach `cancel` während der Auslieferung. Das Einfügen selbst ist unbestätigt;
  sonst gilt die Aufnahme mit dem erfolgreichen Kopieren als geliefert. `retry` fügt nie
  automatisch ein.
- Jede Anfrage hat ein Zeitlimit ab Beginn der Anfrage, Verbindungsaufbau
  eingeschlossen: Transkription 15 Sekunden plus Upload-Zeit
  bei etwa 2 Mbit/s (bei 90 Sekunden Aufnahme mit 48 kHz rund 50 Sekunden),
  Übersetzung 15 Sekunden plus eine Sekunde je 100 Zeichen (höchstens 60
  Sekunden). Mit eigenem Server ist die Grundzeit 2 Minuten statt 15 Sekunden
  (Übersetzung höchstens 3 Minuten). Der Verbindungsaufbau allein darf
  höchstens 10 Sekunden dauern. Fällt das Netz während eines
  kurzen Diktats weg, kommt die Meldung „Keine Verbindung zum
  Dienst“ damit nach etwa 20 Sekunden statt nach bis zu zwei
  Minuten; reißt es mitten in einem langen Upload ab, kann es bis zum Doppelten
  des Limits dauern. Das Zeitlimit greift nicht bei einer hängenden
  Namensauflösung (DNS).
- Fehler, Abbruch, leere Antwort oder Clipboard-Fehler behalten Audio. Eine
  gesicherte Kopie wird mit einem Secret-Service-Schlüssel per HMAC-SHA256 an
  Dateiname, Erstellzeit und exakte Bytes gebunden. Scheitert die Kopie, bleibt
  das Original erhalten.
- `retry` lädt nur frisch authentifizierte Bytes und entfernt sie erst nach
  erfolgreichem Clipboard-Copy. Unbekannte, veränderte oder abgelaufene Dateien
  werden nie hochgeladen. Verwaltete Recovery hält höchstens fünf Dateien und
  24 Stunden; was darüber liegt, wird auch nach dem nächsten erfolgreichen
  Diktat entfernt.
- Logs enthalten Zustände und begrenzte Zeitangaben, aber keinen Key, kein
  Transkript und keine Audioinhalte. Die erfasste Fensterklasse darf enthalten
  sein; Fenstertitel werden nicht gelesen oder geloggt.

Zustand liegt unter `$XDG_STATE_HOME/opendictate/` (sonst
`~/.local/state/opendictate/`), Einstellungen unter
`$XDG_CONFIG_HOME/opendictate/` (sonst `~/.config/opendictate/`). Leere oder
relative `XDG_*`-Werte werden ignoriert; ohne absolutes `HOME` bricht
OpenDictate mit einer Meldung ab. Anwendungs-, Pending- und Recovery-Verzeichnisse
sind echte Verzeichnisse mit Modus `0700`; Audiodateien und Nachweise `0600`.

### Noch offen

- Phase 1 ist nicht abgenommen: Live-Upload, Übersetzung, Hotkey sowie
  Abbruch und Netzausfall während der Verarbeitung sind am 05. und 07.10. auf
  omarchy in Einzelfällen belegt. Die kürzeren Zeitlimits danach sind nur
  offline geprüft.
- Leistenanzeige und Auto-Einfügen sind auf omarchy nur in Einzelfällen
  erprobt (Editor, Terminal, Fensterwechsel, Übersetzung; Stand `fae3dae`,
  [Nachweis](../docs/linux-live-translation-plan.md)); die spätere
  Zwischenablage-Härtung und die Waybar-Variante sind nicht live geprüft. Kein Settings-Fenster.
- Ein Abbruch während des blockierenden HTTP-Aufrufs wird nach dessen Rückkehr
  beziehungsweise Timeout ausgewertet; er löscht die einzige Aufnahme nicht.
- Das Arch-Paket ist auf einem Rechner (omarchy) installiert und mit einem
  Diktat geprüft ([Nachweis](../docs/linux-live-2026-10-05-bis-07.md#live-nachweis-arch-paket--8-oktober-2026));
  nicht im AUR, kein zweites Distro-Ziel.

## Maintainer: lokales Linux-Paket

Aus einem sauberen Checkout unter Linux, mit ausgewähltem Rust/Cargo 1.98.1
und installierten ALSA-Baupaketen:

```bash
bash scripts/package-linux.sh --tag linux-v0.1.0-beta.2 --output /absolut/neuer/paketordner
bash scripts/package-linux.sh --verify /absolut/neuer/paketordner/opendictate-linux-v0.1.0-beta.2-x86_64-unknown-linux-gnu.tar.gz
```

Der gewünschte Tag-Text muss zu Cargo.toml und PKGBUILD passen. Das Skript legt
keinen Git-Tag an und veröffentlicht nichts. Der neue Ausgabeordner liegt
außerhalb des Checkouts und darf noch nicht existieren. Er enthält Binär- und
Quellarchiv, SHA256SUMS und ein Manifest. Dateien, Lizenzen, Hinweise und
Beispiele erhalten feste Reihenfolge, Besitzer und Commit-Zeitstempel.
Die Prüfung kontrolliert Archiv- und Datei-Prüfsummen und startet in einem
temporären Ordner nur `--version` und `--help`. Baue vor einer Veröffentlichung
zweimal in verschiedene neue Ordner und vergleiche beide Archiv-Prüfsummen;
gleiche Prüfsummen echter Linux-Builds sind für dieses Skript noch nicht belegt.

## Vokabular

Eigene Wörter und Namen speicherst du mit
`opendictate vocabulary add "Pull Request"`. Mit `vocabulary list`,
`vocabulary remove "Pull Request"` und `vocabulary clear` verwaltest du sie.
Die Liste liegt in deiner privaten Einstellungsdatei und geht als `prompt` an
deinen gewählten Transkriptionsdienst, auch an einen eigenen Server.
Grenzen: 64 Einträge und 800 UTF-8-Bytes einschließlich Trennzeichen; keine
leeren Einträge, Steuerzeichen oder Leerzeichen am Rand. Die Liste lernt nicht
von selbst. Einstellungen und Berichte zeigen nur die Anzahl; im Protokoll
stehen die Wörter nie.

## Dienst wechseln und Server behalten

`opendictate settings service openai` behält die eigene Adresse und deren
Modelle; `settings service custom` nutzt sie wieder und braucht eine gespeicherte
Adresse. `settings server off` ist ein Alias für die OpenAI-Auswahl. Die erste
eigene Adresse wählt den eigenen Server; spätere Adressänderungen behalten die
Auswahl. Beide Dienste behalten getrennte Abschrift- und Übersetzungsmodelle.
`settings model` und `settings translation-model` ändern den aktiven Dienst.
Alte Einstellungen mit eigener Adresse ziehen ihre Modellnamen dorthin um.
Alte eigene Modellnamen werden auch ohne Adresse oder Umgebungsvariable
übernommen; die Einstellungen bleiben lesbar und OpenAI bekommt sein Standardmodell.
Nach einer Adressänderung nennt die Ausgabe den tatsächlich aktiven Dienst.
Ist die gespeicherte Adresse inaktiv, erklärt sie das Umschalten; dorthin geht kein Schlüssel.

Die bisherige Rangfolge bleibt: Eine aktiv gewählte gespeicherte Server-Adresse
geht vor `OPENAI_BASE_URL`. Ohne aktive gespeicherte Adresse leitet die Variable
Anfragen weiterhin um, auch nach `service openai` oder `server off`. Entferne
sie für OpenAI selbst. `settings show` und der Leisten-Tooltip zeigen den
tatsächlichen Dienst; im Tooltip steht nur der Host, nie die volle Adresse.

## Kürzel antippen oder gedrückt halten

`opendictate setup` fragt die Aufnahmeart ab. Antippen bleibt Standard; die
vorhandene `toggle`-Belegung funktioniert weiter. Halten nutzt `start` beim
Drücken und `stop` beim Loslassen mit derselben Aufnahme-/Anfragesperre.
Wiederholtes `start` während der Aufnahme und `stop` ohne Aufnahme tun nichts.
Sehr kurzes Halten wartet beim Stoppen auf einen bereits laufenden Mikrofonstart.
Zu kurze oder stille Aufnahmen bleiben im bisherigen gesicherten/skipped-Pfad;
sie werden nicht still gelöscht. Anders als bei der 300-ms-Schwelle unter
Windows startet Linux beim Drücken: Hyprland liefert einzelne Befehle statt
roher Tastaturereignisse.

Bei automatisch bearbeiteten Belegungen wird die Aufnahmeart erst nach
erfolgreichem Eintragen/Laden gespeichert; bei fehlgeschlagenem Schreiben,
Laden oder Speichern der Einstellung wird die Konfiguration wiederhergestellt.
Ohne bearbeitbare Konfiguration oder wenn du sie selbst ändern möchtest,
bleibt die gespeicherte Aufnahmeart unverändert; die Abschlussmeldung nennt die
ausstehende manuelle Einrichtung. Ersetze die bisherige OpenDictate-Belegung
durch die angezeigten Zeilen, statt eine zweite hinzuzufügen. Wähle das Kürzel
danach erneut in `setup`: Erst wenn Hyprland die passende Belegung ohne
widersprüchliche Antipp-/Haltebefehle meldet, wird die Aufnahmeart gespeichert.
`settings show` nennt `shortcut-mode`.
Omarchy Lua nutzt den dokumentierten Helfer `o.bind_hold`, klassische
Konfiguration zwei Zeilen. Lass bei klassischen/einfachen Lua-Kombinationen
die Haupttaste vor dem Modifier los. Omarchys Helfer behandelt Modifierwechsel.
Ein echter Tastaturtest unter Hyprland steht noch aus.

## Fehler melden

`opendictate report` zeigt dir den vollständigen Diagnosebericht im Terminal.
Erst nach deiner Antwort `j` öffnet sich das Support-Formular im Browser.
Die CLI sendet nichts an den Support. Du prüfst das Formular und schickst es
selbst ab. `opendictate report --print` gibt nur die Adresse aus. Ohne grafische
Sitzung oder funktionierendes `xdg-open` wird sie nach der Bestätigung ausgegeben.
Aus dem Protokoll bleiben höchstens 30 bekannte Fehler-/Warnkategorien;
freie Meldungen, freie Modellnamen und Server-Adressen werden verworfen.

## Lokale Verbrauchsschätzung

`opendictate usage` zeigt Diktate, Audiominuten und geschätzte USD-Kosten für
heute, die letzten sieben lokalen Kalendertage und den laufenden lokalen Monat.
Der Leisten-Tooltip zeigt heute gezählte Diktate und geschätzte US-Cent. Das ist
ein lokaler Zähler, kein Kontostand beim Anbieter. Er zählt vollständig
abgeschlossene, nicht leere Erkennung/Übersetzung, auch wenn danach das Kopieren
scheitert. Abgebrochene, fehlgeschlagene oder leere Verarbeitung zählt nicht;
der Anbieter kann dafür trotzdem Kosten berechnen. Erfolgreiche Wiederholungen
zählen als neue Anfragen.

Die private `usage.json` im Zustandsordner enthält nur Zeitpunkt, Dienstart,
Modell, Audiosekunden und gegebenenfalls Übersetzungs-Tokenzahlen. Einträge über
13 Kalendermonate werden beim Zugriff/Schreiben entfernt; `usage reset` leert
den Zähler. Eigene Server zählen Minuten mit null geschätzten Anbieterkosten.
Fehlende Tokenzahlen oder unbekannte Modelle bedeuten unbekannte Kosten.
Die Preise stammen aus der datierten gemeinsamen `fixtures/pricing/prices.json`;
Rechnung, Steuern, regionale Zuschläge und Cache-Rabatte können abweichen.
Scheitert das Speichern des Zählers, bleibt das Diktat nutzbar; das Protokoll
nennt `usage-write-failed`. Der Zähler ersetzt keine Abrechnung.

## Eine gesicherte Aufnahme mit OpenAI senden

Bei Verbindungsfehler oder Zeitüberschreitung des eigenen Servers erscheint
`opendictate retry --openai`. Der ausdrückliche Befehl sendet nur die neueste
authentifizierte, nicht abgelaufene und nicht als skipped markierte Aufnahme
einmal an OpenAI selbst. Dafür wird OPENAI_BASE_URL für diese Anfrage ignoriert;
der gespeicherte OpenAI-Schlüssel wird benötigt. Es gibt keinen automatischen
Wechsel. Normales retry und spätere Diktate nutzen weiter den eingestellten
Dienst und dessen Modelle. Ein bekanntes OpenAI-Modell wird übernommen; alte
Einstellungen mit ausschließlich eigenem Modell nutzen den OpenAI-Standard.
Keine gespeicherte Einstellung wird geändert. Bei Fehler, leerem Text oder
Abbruch bleibt die Aufnahme nach den bisherigen Regeln erhalten.
`status` nennt den letzten eigenen Netzwerkfehler höchstens 24 Stunden lang;
ein neuer Verarbeitungsversuch entfernt den Hinweis. HTTP-Fehler wie 404 bieten
diesen Netzwerk-Rückweg nicht an. Zu kurze/stille skipped-Aufnahmen brauchen
weiter `retry --skipped` und werden durch diesen Einmal-Befehl nie hochgeladen.

Die ausdrückliche OpenAI-Wiederholung gilt auch bei einem Verbindungsfehler
während der Übersetzung. Sie nutzt einmal das Standard-Übersetzungsmodell
von OpenAI. Deine gespeicherten Einstellungen bleiben erhalten.

Der echte Zwei-Bau-Nachweis und wiederholbare Befehle stehen unter [Linux-Paketierung](../docs/linux-packaging.md).
