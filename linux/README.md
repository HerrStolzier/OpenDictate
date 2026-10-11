# OpenDictate for Linux (beta preparation)

English · [Deutsch](README.de.md)

OpenDictate records your voice at the press of a key, has OpenAI transcribe it,
translates it if you want (for example into English) and inserts the text into
the window that was in front when you started. It is a small command-line
program without a window of its own, made for Hyprland.

**Status:** Not released yet. Tested on a single machine (Omarchy 4 with
Hyprland 0.56, Arch Linux), in daily use there since 7 October 2026. Evidence
(German): [live evidence](../docs/linux-live-2026-10-05-bis-07.md),
[verified state](../docs/remaining-acceptance.md#linux). The
[known limits](#known-limits) below apply.

## What it costs

OpenDictate itself is free and open source (MIT). You need your own OpenAI API
key and pay OpenAI directly for what you use, no subscription. From our own
bills (July to October 2026), transcription costs about $0.0045 per minute of
speech, so a typical 15-second dictation is about $0.001. Translation adds a
small amount for the text model (`gpt-5.4-mini`). OpenAI sets the prices; their
price list is what counts.

## No dictation gets lost

If transcription, translation or inserting fails (network gone, timeout,
cancel), the recording stays on your machine. A recording is only deleted once
its text has reached the clipboard. Normally OpenDictate keeps a secured copy
for this: `opendictate retry` sends it again, and at most five such copies are
kept for 24 hours. If that copy cannot be made (for example because the
keyring is locked), the original file stays in
`~/.local/state/opendictate/pending/`; `retry` does not pick it up then, and
the file is not deleted automatically either.

## What you need

- Arch Linux or an Arch-based system with **Hyprland** (for example Omarchy).
  Other distributions and compositors are untested.
- A microphone set as the default input. OpenDictate records from the ALSA
  default device; with PipeWire that needs `pipewire-alsa` (included in
  Omarchy).
- A keyring with Secret Service, for example `gnome-keyring` (included in
  Omarchy). The API key is stored only there, never in a file.
- An OpenAI API key with credit
  ([platform.openai.com](https://platform.openai.com/api-keys)).

## Install

Get the build tools once and build the package from source. `makepkg` builds
the program, runs the tests and, after asking, installs it with `pacman` as the
package `opendictate`:

```bash
sudo pacman -S --needed base-devel git rust
git clone https://github.com/HerrStolzier/OpenDictate.git
cd OpenDictate/linux/packaging/arch
makepkg -si
```

If you manage Rust with `rustup`, install the `rustup` package with a stable
toolchain instead of `rust`. A `rustup` installed only in your home directory
is unknown to `pacman`, so `makepkg` reports `cargo` as missing. In that case
run `sudo pacman -S --needed alsa-lib hyprland libsecret wl-clipboard` first
and then `makepkg -i --nodeps` instead of `makepkg -si`. `makepkg` then no
longer checks dependencies, but `pacman` still refuses to install if one of
those packages is missing.
The package builds with the stable toolchain; it was built on Omarchy with
Rust 1.98.1. Afterwards the program is at `/usr/bin/opendictate`;
`opendictate version` shows the version.

**Update:** run `git pull` in the `OpenDictate` folder, then `makepkg -sfi` in
`linux/packaging/arch`. The `-f` forces a rebuild even when the version number
has not changed; without it `makepkg` installs an older package already lying
there.

**Remove:** `sudo pacman -R opendictate`. Settings, log and secured recordings
stay behind; they are in `~/.config/opendictate/` and
`~/.local/state/opendictate/`. The two keyring entries are removed with
`secret-tool clear service opendictate key api-key` and
`secret-tool clear service opendictate key recording-auth`.

## Set up

**1. Store the API key.** The key is only accepted through a pipe, never as an
argument or environment variable. This command asks for it without showing it
(paste the key, press Enter):

```bash
read -rsp "OpenAI API key: " key && printf '%s' "$key" | opendictate secrets set-api-key; unset key
opendictate secrets status
```

`secrets status` reports `api-key=present` when it worked.

**2. Pick a shortcut.** OpenDictate does not bring its own shortcut; you bind
`opendictate toggle` to a key in Hyprland, for example Super+D. Check first
that the key is free.

Omarchy 4 with Lua config (Hyprland 0.56): add a line to
`~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + D", "OpenDictate", "opendictate toggle")
```

Classic config (`~/.config/hypr/hyprland.conf` or a file sourced from it), see
[hyprland.conf.example](hyprland.conf.example):

```ini
bind = SUPER, D, exec, opendictate toggle
```

Hyprland reloads the change when you save.

**3. Bar indicator (optional).** An icon in the bar shows recording, processing
and the selected target language; a click toggles translation. Setup under
[Bar indicator](#bar-indicator).

**4. Language.** Messages and help follow your system language: German when
`LC_ALL`, `LC_MESSAGES` or `LANG` (the first one set) starts with `de`, English
otherwise. On a German system the spoken language also starts as German;
otherwise it is detected. To set it, use for example
`opendictate settings language en`, or `opendictate settings language auto` to
detect it.

**5. Translation (optional).** `opendictate settings target de` translates every
dictation into German (any language code works, for example `en`, `fr`, `es`),
and `opendictate settings target off` turns it off again.

## Use

1. Click into the field where the text should go.
2. Press the shortcut, speak, press the shortcut again.
3. After a few seconds the text is in the field. If another window has come to
   the front in the meantime, nothing is inserted; the text is then in the
   clipboard and a notification says so.

In known terminals (for example Alacritty, foot, kitty) OpenDictate pastes with
Ctrl+Shift+V, elsewhere with Ctrl+V. The text is always in the clipboard
afterwards too. `opendictate settings insert off` turns automatic inserting
off. `opendictate cancel` stops a running recording; the recording is kept for
`retry`.

## When something goes wrong

- `opendictate status` shows whether it is recording or processing.
- `opendictate retry` sends the last secured recording again.
- The log `~/.local/state/opendictate/operations.log` contains steps and
  timings, but never your text, your key or audio.
- Please report bugs and wishes as a
  [GitHub issue](https://github.com/HerrStolzier/OpenDictate/issues/new?template=linux-beta-feedback.md),
  with `opendictate version`, the Hyprland version (`hyprctl version`), the
  program the text should have gone into, and the matching lines from the
  log. No private texts, no keys, no audio files.

## Known limits

These cases were deliberately not tested in advance; feedback on them helps
most:

- Inserting into Chromium, Electron and Discord windows (only a text editor
  and a terminal are tested).
- Mixed languages within one dictation with translation.
- Cancel or network loss exactly during translation.
- The timeouts (network error after about 20 seconds) are only tested
  offline.
- Hyprland only, Arch-based systems only. No settings window, no
  push-to-talk, no custom vocabulary, no provider other than OpenAI.
- At most 90 seconds per dictation.

## Privacy in short

The recording goes to OpenAI over HTTPS for transcription; with translation on,
the text then goes to OpenAI for translation. To no one else. Details:
[PRIVACY.md](../PRIVACY.md#linux-cli).

## All commands

```bash
opendictate toggle                  # start or stop a recording
opendictate status                  # idle / recording / processing / delivering
opendictate bar                     # status as a JSON line for the bar (`waybar` works too)
opendictate cancel                  # safely cancel recording/processing
opendictate retry                   # send the newest authenticated recording again
opendictate version                 # show the version
opendictate settings show
opendictate settings model gpt-transcribe
opendictate settings language en    # `auto` to detect the language
opendictate settings target de      # translate dictations into German; `off` to stop
opendictate settings target toggle  # off, or on with the last target language (else en)
opendictate settings insert off     # clipboard only, no auto-insert
opendictate settings translation-model gpt-5.4-mini
opendictate secrets status
```

## Bar indicator

`opendictate bar` prints one JSON line in Waybar format per call: a microphone
icon, an hourglass while processing and the active target language (for example
`EN`). While recording it carries the class `active`. A click should call
`settings target toggle`. The output contains only state and settings, never
text. The icons need a Nerd Font, as Omarchy ships. After installing, the
example files are also in `/usr/share/doc/opendictate/`.

- Omarchy 4 (Omarchy shell bar): add a command module like
  [omarchy-bar.example.json](omarchy-bar.example.json) to
  `~/.config/omarchy/shell.json` under `bar.layout`. The bar highlights the
  module while recording.
- Waybar: [waybar.example.jsonc](waybar.example.jsonc) and
  [waybar.example.css](waybar.example.css); there the icon turns red while
  recording.

## Technical details

### Build and check yourself

Tested with `rustc 1.98.1` (CI script and package build on Omarchy). A lower
minimum version is not verified:

```bash
cargo fmt --manifest-path linux/Cargo.toml -- --check
cargo test --manifest-path linux/Cargo.toml
cargo clippy --manifest-path linux/Cargo.toml --all-targets -- -D warnings
cargo build --release --manifest-path linux/Cargo.toml
```

The binary ends up in `linux/target/release/opendictate`. The Arch package
([PKGBUILD](packaging/arch/PKGBUILD)) builds from the checkout it sits in; its
version must match the one in `Cargo.toml`. Development and tests need no real
secrets; the HTTP tests only use a local stub.

### Flow and safety rules

- `toggle` starts a recording without taking focus. The second call stops it
  and switches to `processing`; further starts during `processing` or
  `delivering` are refused.
- Below 1 second, or without a 50 ms window above −45 dBFS, nothing is
  uploaded. Detected speech keeps a 0.25-second margin; only savings of 0.35
  seconds or more produce a trimmed upload WAV. The 90-second limit stays on.
- With a target language set, the transcript is then translated via
  `/v1/chat/completions` and only the translation is delivered. If the
  translation fails or is empty, the recording is kept like with any other
  error; `retry` translates again.
- A non-empty transcript is written only to the Wayland clipboard. The
  recording may be removed only after the copy succeeded.
- Auto-insert (on by default, `settings insert off` turns it off): at start the
  active Hyprland window is captured. After copying, the CLI checks that
  exactly this window is still in front and the clipboard still holds the
  text, then sends Ctrl+V (Ctrl+Shift+V in known terminals) to that window via
  `hyprctl dispatch`. It first uses the Lua form `hl.dsp.send_shortcut`
  (Hyprland with Lua config, for example 0.56), and the older `sendshortcut`
  only when Hyprland clearly rejects it. Otherwise the text stays in the
  clipboard with a notice. If the clipboard no longer holds exactly the text
  before inserting, or cannot be read within 2 seconds, the dictation counts as
  not delivered and the recording is kept for `retry`; the same after `cancel`
  during delivery. The paste itself is unconfirmed; otherwise the recording
  counts as delivered once the copy succeeded. `retry` never inserts
  automatically.
- Every request has a time limit from its start, connecting included:
  transcription 15 seconds plus upload time at about 2 Mbit/s (about 50 seconds
  for a 90-second recording at 48 kHz), translation 15 seconds plus one second
  per 100 characters (at most 60 seconds). Connecting alone may take at most 10
  seconds. If the network drops during a short dictation, the "network error
  or timeout" message comes after about 20 seconds instead of up to two
  minutes; if it breaks in the middle of a long upload, it can take up to twice
  the limit. The limit does not cover a hanging name lookup (DNS).
- Errors, cancel, empty answers or clipboard errors keep the audio. A recovery
  copy is bound with HMAC-SHA256, keyed from the Secret Service, to file name,
  creation time and exact bytes. If the copy fails, the original is kept.
- `retry` only uploads freshly authenticated bytes and removes them only after
  a successful clipboard copy. Unknown, modified or expired files are never
  uploaded. Managed recovery keeps at most five files for 24 hours.
- Logs contain states and bounded timings, but no key, no transcript and no
  audio. The captured window class may be included; window titles are never
  read or logged.

State lives in `$XDG_STATE_HOME/opendictate/` (else
`~/.local/state/opendictate/`), settings in `$XDG_CONFIG_HOME/opendictate/`.
App, pending and recovery folders are real directories with mode `0700`; audio
files and proofs `0600`.

### Still open

- Phase 1 is not formally accepted: live upload, translation, shortcut, and
  cancel and network loss during processing are shown on one machine in single
  cases; the shorter timeouts are only tested offline.
- Bar indicator and auto-insert are tried on one machine in single cases
  (editor, terminal, window switch, translation); the later clipboard
  hardening and the Waybar variant are not tested live. No settings window.
- A cancel during a blocking HTTP call is evaluated after it returns or times
  out; it never deletes the only recording.
- The Arch package is installed on one machine and checked with a dictation;
  not in the AUR, no second distribution.
