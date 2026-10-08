# OpenDictate für Linux (Beta-Vorbereitung)

OpenDictate nimmt auf Tastendruck deine Stimme auf, lässt sie von OpenAI
abschreiben, übersetzt sie auf Wunsch (zum Beispiel ins Englische) und fügt den
Text in das Fenster ein, das beim Start vorne war. Es ist ein kleines
Kommandozeilenprogramm ohne eigenes Fenster, gedacht für Hyprland.

**Stand:** Noch nicht veröffentlicht. Erprobt auf einem einzigen Rechner
(Omarchy 4 mit Hyprland 0.56, Arch Linux), dort seit dem 7. Oktober 2026 im
Alltag. Nachweise: [Live-Nachweise](../docs/linux-live-2026-10-05-bis-07.md),
[belegter Stand](../docs/remaining-acceptance.md#linux). Die
[bekannten Grenzen](#bekannte-grenzen) unten gelten ausdrücklich.

## Was es kostet

OpenDictate selbst ist kostenlos und quelloffen (MIT). Du brauchst einen
eigenen OpenAI-API-Schlüssel und zahlst OpenAI direkt nach Nutzung, kein Abo.
Nach unserer eigenen Abrechnung (Juli bis Oktober 2026) kostet die Abschrift
rund 0,0045 $ pro Minute Sprache, ein typisches Diktat von 15 Sekunden also
rund 0,1 Cent. Die Übersetzung kommt mit
einem kleinen Betrag für das Textmodell (`gpt-5.4-mini`) dazu. Preise legt
OpenAI fest; maßgeblich ist deren Preisliste.

## Kein Diktat geht verloren

Scheitert die Abschrift, die Übersetzung oder das Einfügen (Netz weg,
Zeitüberschreitung, Abbruch), bleibt die Aufnahme auf deinem Rechner erhalten.
Gelöscht wird eine Aufnahme erst, wenn ihr Text in der Zwischenablage
angekommen ist. Normalerweise legt OpenDictate dafür eine gesicherte Kopie an:
`opendictate retry` schickt sie erneut, aufbewahrt werden höchstens fünf
solcher Kopien für 24 Stunden. Gelingt diese Kopie nicht (zum Beispiel weil der
Schlüsselbund gesperrt ist), bleibt die Originaldatei unter
`~/.local/state/opendictate/pending/` liegen; `retry` greift dann nicht, und die
Datei wird auch nicht automatisch gelöscht.

## Was du brauchst

- Arch Linux oder ein Arch-basiertes System mit **Hyprland** (zum Beispiel
  Omarchy). Andere Distributionen und Compositoren sind nicht geprüft.
- Ein Mikrofon, das als Standardeingang eingestellt ist. OpenDictate nimmt
  über das ALSA-Standardgerät auf; mit PipeWire braucht es dafür
  `pipewire-alsa` (bei Omarchy schon dabei).
- Einen Schlüsselbund mit Secret Service, zum Beispiel `gnome-keyring`
  (bei Omarchy schon dabei). Der API-Schlüssel liegt nur dort, nie in einer
  Datei.
- Einen OpenAI-API-Schlüssel mit Guthaben
  ([platform.openai.com](https://platform.openai.com/api-keys)).

## Installieren

Einmalig die Bauwerkzeuge holen und das Paket aus dem Quellcode bauen. `makepkg`
baut das Programm, führt die Tests aus und installiert es nach Rückfrage mit
`pacman` als Paket `opendictate`:

```bash
sudo pacman -S --needed base-devel git rust
git clone https://github.com/HerrStolzier/OpenDictate.git
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

**Aktualisieren:** im Ordner `OpenDictate` `git pull`, dann in
`linux/packaging/arch` `makepkg -sfi`. Das `-f` erzwingt einen Neubau, auch wenn
die Versionsnummer gleich geblieben ist; ohne es installiert `makepkg` ein dort
schon liegendes älteres Paket.

**Entfernen:** `sudo pacman -R opendictate`. Einstellungen, Protokoll und
gesicherte Aufnahmen bleiben dabei liegen; sie stehen in
`~/.config/opendictate/` und `~/.local/state/opendictate/`. Die beiden
Schlüsselbund-Einträge entfernt
`secret-tool clear service opendictate key api-key` und
`secret-tool clear service opendictate key recording-auth`.

## Einrichten

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

**3. Leistenanzeige (optional).** Ein Symbol in der Leiste zeigt Aufnahme,
Verarbeitung und die eingestellte Zielsprache; ein Klick schaltet die
Übersetzung um. Einrichtung unter [Leistenanzeige](#leistenanzeige).

**4. Sprache.** Voreingestellt ist Deutsch als gesprochene Sprache. Wer anders
spricht, stellt sie um, zum Beispiel `opendictate settings language en`, oder
lässt sie mit `opendictate settings language auto` erkennen.

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
mit Strg+Umschalt+V ein, sonst mit Strg+V. Der
Text liegt danach immer auch in der Zwischenablage. `opendictate settings insert
off` schaltet das automatische Einfügen ab. `opendictate cancel` bricht eine
laufende Aufnahme ab; die Aufnahme bleibt für `retry` erhalten.

## Wenn etwas nicht klappt

- `opendictate status` zeigt, ob gerade aufgenommen oder verarbeitet wird.
- `opendictate retry` schickt die letzte gesicherte Aufnahme erneut.
- Das Protokoll `~/.local/state/opendictate/operations.log` enthält Abläufe und
  Zeiten, aber nie deinen Text, deinen Schlüssel oder Audio.
- Fehler und Wünsche bitte als
  [GitHub Issue](https://github.com/HerrStolzier/OpenDictate/issues) melden,
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
  Halten-zum-Sprechen, kein eigenes Vokabular, kein anderer Anbieter als
  OpenAI.
- Höchstens 90 Sekunden pro Diktat.

## Datenschutz in Kürze

Die Aufnahme geht per HTTPS an OpenAI zur Abschrift, mit eingeschalteter
Übersetzung danach der Text an OpenAI zur Übersetzung. An niemanden sonst.
Details: [PRIVACY.md](../PRIVACY.md#linux-cli).

## Alle Befehle

```bash
opendictate toggle                  # Aufnahme starten oder stoppen
opendictate status                  # idle / recording / processing / delivering
opendictate bar                     # Status als JSON-Zeile für die Leiste (`waybar` gleichwertig)
opendictate cancel                  # Aufnahme/Verarbeitung sicher abbrechen
opendictate retry                   # neueste authentifizierte Aufnahme erneut senden
opendictate version                 # Version anzeigen
opendictate settings show
opendictate settings model gpt-transcribe
opendictate settings language de    # `auto` für automatische Erkennung
opendictate settings target en      # Diktat ins Englische übersetzen; `off` aus
opendictate settings target toggle  # aus bzw. mit letzter Zielsprache (sonst en) an
opendictate settings insert off     # nur Zwischenablage, kein Auto-Einfügen
opendictate settings translation-model gpt-5.4-mini
opendictate secrets status
```

## Leistenanzeige

`opendictate bar` gibt jede Abfrage eine JSON-Zeile im Waybar-Format aus:
Mikrofon-Symbol, Sanduhr während der Verarbeitung und die aktive Zielsprache
(z. B. `EN`). Während der Aufnahme trägt sie die Klasse `active`. Ein Klick soll
`settings target toggle` aufrufen. Die Ausgabe enthält nur Zustand und
Einstellungen, nie Text. Die Symbole brauchen eine Nerd Font, wie sie Omarchy
mitbringt. Die Beispieldateien liegen nach der Installation auch unter
`/usr/share/doc/opendictate/`.

- Omarchy 4 (Omarchy-Shell-Leiste): Befehlsmodul nach
  [omarchy-bar.example.json](omarchy-bar.example.json) in
  `~/.config/omarchy/shell.json` unter `bar.layout` ergänzen. Die Leiste hebt
  das Modul während der Aufnahme hervor.
- Waybar: [waybar.example.jsonc](waybar.example.jsonc) und
  [waybar.example.css](waybar.example.css); dort wird das Symbol während der
  Aufnahme rot.

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

- `toggle` startet eine fokusneutrale Aufnahme. Der zweite Aufruf beendet sie
  und wechselt auf `processing`; weitere Starts während `processing` oder
  `delivering` werden abgelehnt.
- Unter 1 Sekunde oder ohne 50-ms-Fenster oberhalb −45 dBFS erfolgt kein Upload.
  Erkannte Sprache erhält 0,25 Sekunden Rand; nur Einsparungen ab 0,35 Sekunden
  erzeugen eine zugeschnittene Upload-WAV. Das 90-Sekunden-Limit bleibt aktiv.
- Mit gesetzter Zielsprache wird das Transkript danach über
  `/v1/chat/completions` übersetzt und nur die Übersetzung ausgegeben. Scheitert
  die Übersetzung oder ist sie leer, bleibt die Aufnahme wie bei jedem anderen
  Fehler erhalten; `retry` übersetzt erneut. Am 05.10. auf omarchy live
  erprobt ([Plan mit Nachweis](../docs/linux-live-translation-plan.md)).
- Ein nichtleeres Transkript wird ausschließlich in die Wayland-Zwischenablage
  geschrieben. Erst nach erfolgreichem Copy darf die zugehörige Aufnahme
  entfernt werden.
- Auto-Einfügen (Standard an, `settings insert off` schaltet es ab): Beim
  Start wird das aktive Hyprland-Fenster erfasst. Nach dem Kopieren prüft das
  CLI, dass genau dieses Fenster noch vorne ist und die Zwischenablage noch den
  Text enthält, und sendet dann per `hyprctl dispatch` Ctrl+V, in bekannten
  Terminals Ctrl+Shift+V, an dieses Fenster. Zuerst wird die Lua-Form
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
  Sekunden). Der Verbindungsaufbau allein darf höchstens 10 Sekunden dauern. Fällt das Netz während eines
  kurzen Diktats weg, kommt die Meldung „Netzwerkfehler oder
  Zeitüberschreitung“ damit nach etwa 20 Sekunden statt nach bis zu zwei
  Minuten; reißt es mitten in einem langen Upload ab, kann es bis zum Doppelten
  des Limits dauern. Das Zeitlimit greift nicht bei einer hängenden
  Namensauflösung (DNS).
- Fehler, Abbruch, leere Antwort oder Clipboard-Fehler behalten Audio. Eine
  Recovery-Kopie wird mit einem Secret-Service-Schlüssel per HMAC-SHA256 an
  Dateiname, Erstellzeit und exakte Bytes gebunden. Scheitert die Kopie, bleibt
  das Original erhalten.
- `retry` lädt nur frisch authentifizierte Bytes und entfernt sie erst nach
  erfolgreichem Clipboard-Copy. Unbekannte, veränderte oder abgelaufene Dateien
  werden nie hochgeladen. Verwaltete Recovery hält höchstens fünf Dateien und
  24 Stunden.
- Logs enthalten Zustände und begrenzte Zeitangaben, aber keinen Key, kein
  Transkript und keine Audioinhalte. Die erfasste Fensterklasse darf enthalten
  sein; Fenstertitel werden nicht gelesen oder geloggt.

Zustand liegt unter `$XDG_STATE_HOME/opendictate/` (sonst
`~/.local/state/opendictate/`), Einstellungen unter
`$XDG_CONFIG_HOME/opendictate/`. Anwendungs-, Pending- und Recovery-Verzeichnisse
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
