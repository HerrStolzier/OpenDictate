# OpenDictate for Linux (beta)

English · [Deutsch](README.de.md)

OpenDictate records your voice at the press of a key, has OpenAI (or your own
server, see [Custom server](#custom-server)) transcribe it,
translates it if you want (for example into English) and pastes the text into
the window that was in front when you started. It is a small command-line
program without a window of its own, made for Hyprland.

**Status:** Public beta since 11 October 2026:
[pre-release `linux-v0.1.0-beta.1`](https://github.com/HerrStolzier/OpenDictate/releases/tag/linux-v0.1.0-beta.1).
Tested on a single machine (Omarchy 4 with
Hyprland 0.56, Arch Linux), in daily use there since 7 October 2026. The
[known limits](#known-limits) below apply.

## What it costs

Nothing, if you run a model on your own computer, for example whisper.cpp
(see [Custom server](#custom-server)); your audio then never leaves the
machine. With OpenAI you bring your own API key and pay OpenAI directly for
what you use, no subscription: $0.0045 per minute of speech, so a typical
15-second dictation costs about a tenth of a cent. Translation adds a small
amount for the text model (`gpt-5.4-mini`). That is what OpenAI charged from
July to October 2026; OpenAI sets the prices, and its price list is what
counts. OpenDictate itself is free and
open source (MIT).

## No dictation gets lost

If transcription, translation or pasting fails (network gone, timeout,
cancel), the recording stays on your machine. A recording is only deleted once
its text has reached the clipboard. Normally OpenDictate keeps a secured copy
for this: `opendictate retry` sends it again, and at most five such copies are
kept for 24 hours. If that copy cannot be made (for example because the
keyring is locked), the original file stays in
`~/.local/state/opendictate/pending/`; `retry` does not pick it up then. The
24-hour limit applies to this file too: the next recording after that removes
it. If the microphone fails or is
unplugged during a recording, you get a notification and the audio up to that
point is kept for `retry` the same way. A recording that is too short or
silent is not sent; it is kept too, but plain `retry` passes it over
(see [Flow and safety rules](#flow-and-safety-rules)).

## What you need

- Arch Linux or an Arch-based system with **Hyprland** (for example Omarchy).
  Other distributions and compositors are untested.
- A microphone set as the default input. OpenDictate records from the ALSA
  default device; with PipeWire that needs `pipewire-alsa` (included in
  Omarchy).
- A keyring with Secret Service, for example `gnome-keyring` (included in
  Omarchy). The API key is stored only there, never in a file.
- A normal desktop session that sets `XDG_RUNTIME_DIR` (systemd does). The
  CLI keeps its state there and refuses to fall back to `/tmp`.
- An OpenAI API key with credit
  ([platform.openai.com](https://platform.openai.com/api-keys)), or a
  [custom server](#custom-server) that speaks the OpenAI API, for example a
  model on your own computer.

## Install

Get the build tools once and build the package from source. `makepkg` builds
the program, runs the tests and, after asking, installs it with `pacman` as the
package `opendictate`. Other projects share the name: the Snap package
`opendictate` is not this one, so build from this repository.

```bash
sudo pacman -S --needed base-devel git rust
git clone --branch linux-v0.1.0-beta.1 https://github.com/HerrStolzier/OpenDictate.git
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

**Update:** the clone sits on a release tag, so `git pull` does not apply. In
the `OpenDictate` folder run `git fetch --tags` and `git checkout <tag>` with
the tag of the newest Linux release from the
[releases page](https://github.com/HerrStolzier/OpenDictate/releases), then
`makepkg -sfi` in `linux/packaging/arch`. The `-f` forces a rebuild even when the version number
has not changed; without it `makepkg` installs an older package already lying
there.

**Remove:** `sudo pacman -R opendictate`. Settings, log and secured recordings
stay behind; they are in `~/.config/opendictate/` and
`~/.local/state/opendictate/`. The two keyring entries are removed with
`secret-tool clear service opendictate key api-key` and
`secret-tool clear service opendictate key recording-auth`.

## Set up

**Quickest way:** run `opendictate setup` in a terminal. It asks two things:

1. Who transcribes: OpenAI with your API key (it asks for the key without
   showing it and checks it before saving; only a key that passes the check
   replaces a stored one), or a [custom server](#custom-server).
2. Which shortcut starts and stops a dictation: Super+D, F9, or, on a US
   keyboard layout, the right Alt key alone. It shows which keys Hyprland
   already uses and writes the line into your Hyprland config, after asking
   and with a backup next to the file (`….opendictate-backup-…`; the three
   newest stay, older ones are removed). For Omarchy
   that is `~/.config/hypr/bindings.lua`; a plain Lua config only gets the line
   to copy. If Hyprland does not take the new line, setup puts the file back
   as it was, so the previous shortcut keeps working.

After that, steps 3 to 5 below are optional. `opendictate shortcut status`
shows the current shortcut later, `opendictate shortcut set f9` changes it
without questions.

**By hand instead:**

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

**3. Bar indicator (optional).** Blink, the OpenDictate cursor, shows in the bar
whether OpenDictate is listening or writing, and the selected target language; a
click toggles translation. Setup under
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
   the front in the meantime, nothing is pasted; the text is then in the
   clipboard and a notification says so.

In known terminals (for example Alacritty, foot, kitty) OpenDictate pastes with
Ctrl+Shift+V, elsewhere with Ctrl+V. Text with line breaks is not pasted into a
terminal, because a line break would run the dictated line as a command; it
stays in the clipboard and a notification says so. Control characters in the
transcript are removed before anything is copied. The text is always in the
clipboard afterwards too. `opendictate settings insert off` turns automatic pasting
off. `opendictate cancel` stops a running recording; the recording is kept for
`retry`.

## Custom server

Instead of OpenAI, OpenDictate can send recordings to your own server that
speaks the OpenAI API, for example a speech model on this computer. That
costs nothing per minute and the recording does not leave the machine.

```bash
opendictate settings server http://127.0.0.1:8080/v1
opendictate settings model NAME              # the model name your server expects
opendictate settings translation-model NAME  # only if you translate
opendictate settings server off              # back to OpenAI
```

- The **server address** is the base address including `/v1`. OpenDictate
  appends `/audio/transcriptions` for transcription and `/chat/completions`
  for translation; both go to the same address. A server that only
  transcribes works with translation off.
- `https://` works for any address. Plain `http://` only for this computer
  (`localhost`, `127.0.0.1`, `[::1]`). Addresses with credentials, `?` or `#`
  are rejected.
- A server on this computer is only private on a computer you use alone:
  another local user could start a program on the same port first and would
  then receive your recordings and texts.
- **API key:** an address on this computer gets no key and needs none. Any
  other server gets your stored key (useful for OpenAI-compatible providers),
  even if that key was made for OpenAI; only use servers you trust with it.
- Model names are free-form with a custom server; with OpenAI only the known
  transcription models are accepted. `settings server off` resets a model
  OpenAI does not offer.
- Alternatively the environment variable `OPENAI_BASE_URL` sets the address;
  a stored address wins. Hyprland must see the variable, not just your shell.
  Whoever can set this variable for your session redirects your recordings,
  texts and, for an `https://` address not on this computer, your API key to
  that server.
- Local models on the CPU are slow, so OpenDictate waits up to 2 minutes for a
  custom server (plus upload time) instead of 15 seconds.
- The log names only the server's host, never its path or a key.

Example with [whisper.cpp](https://github.com/ggml-org/whisper.cpp)
(transcription only; it uses the model it was started with via `-m`):

```bash
whisper-server -m models/ggml-base.bin --host 127.0.0.1 --port 8080 \
  --inference-path /v1/audio/transcriptions
opendictate settings server http://127.0.0.1:8080/v1
```

**Only OpenAI is verified.** Custom servers are new in this beta; whether a
given server works is exactly the feedback we are looking for.

## When something goes wrong

- `opendictate status` shows whether it is recording or processing.
- `opendictate retry` sends the last kept recording again.
- "Recording could not start": usually no microphone is available. Check
  with `wpctl status` that a source is listed under Audio → Sources and
  marked as default (`*`); plug in or select the microphone and try again.
- The log `~/.local/state/opendictate/operations.log` contains steps and
  timings, but never your text, your key or audio. Only you can read it; above
  1 MiB it moves to `operations.log.1`, and only that one older file is kept.
- Please report bugs and wishes as a
  [GitHub issue](https://github.com/HerrStolzier/OpenDictate/issues/new?template=linux-beta-feedback.md),
  with `opendictate version`, the Hyprland version (`hyprctl version`), the
  program the text should have gone into, and the matching lines from the
  log. No private texts, no keys, no audio files.

## Known limits

These cases were deliberately not tested in advance; feedback on them helps
most:

- Pasting into Chromium, Electron and Discord windows (only a text editor
  and a terminal are tested).
- Mixed languages within one dictation with translation.
- Cancel or network loss exactly during translation.
- The timeouts (network error after about 20 seconds) are only tested
  offline.
- Hyprland only, Arch-based systems only. No settings window, no
  push-to-talk. Explicit vocabulary is implemented in the CLI; live recognition
  with those hints is not yet accepted. Only OpenAI is verified; custom
  servers are untested.
- At most 90 seconds per dictation.

## Privacy in short

The recording goes to OpenAI over HTTPS for transcription; with translation on,
the text then goes to OpenAI for translation. To no one else. With a
[custom server](#custom-server), both go only to that server instead. Details:
[PRIVACY.md](../PRIVACY.md#linux-cli).

## All commands

```bash
opendictate setup                   # guided setup: key or custom server, shortcut
opendictate toggle                  # start or stop a dictation
opendictate status                  # idle / starting / recording / processing / delivering
opendictate bar                     # status as a JSON line for the bar (`waybar` works too)
opendictate cancel                  # safely cancel recording/processing
opendictate retry                   # send the last kept recording again
opendictate retry --skipped         # send the last too short or silent one anyway
opendictate version                 # show the version
opendictate settings show
opendictate settings model gpt-transcribe
opendictate settings language en    # `auto` to detect the language
opendictate settings target de      # translate dictations into German; `off` to stop
opendictate settings target toggle  # off, or on with the last target language (else en)
opendictate settings insert off     # clipboard only, no auto-paste
opendictate settings translation-model gpt-5.4-mini
opendictate settings server http://127.0.0.1:8080/v1  # custom server; `off` for OpenAI
opendictate shortcut status         # current shortcut, which keys are free
opendictate shortcut set f9         # super-d, f9 or right-alt into the Hyprland config
opendictate secrets status
```

## Bar indicator

`opendictate bar` prints one JSON line in Waybar format per call. The text is
Blink, the OpenDictate block cursor `▮`, followed by `REC` while recording, `…`
while the microphone starts or text is written, and the active target language
(for example `▮ REC EN`). The tooltip names the state: Ready, Listening or
Writing, and briefly "Microphone starting". While recording the line
carries the class `active`. A click should call `settings target toggle`. The
output contains only state and settings, never text. No Nerd
Font is needed. After installing, the example files are also in
`/usr/share/doc/opendictate/`. The pre-release `linux-v0.1.0-beta.1` still shows
the Nerd Font microphone and hourglass; Blink arrives with the next Linux
release.

- Omarchy 4 (Omarchy shell bar): add a command module like
  [omarchy-bar.example.json](omarchy-bar.example.json) to
  `~/.config/omarchy/shell.json` under `bar.layout`. The bar highlights the
  module while recording.
- Waybar: [waybar.example.jsonc](waybar.example.jsonc) and
  [waybar.example.css](waybar.example.css) in the OpenDictate colours; there
  Blink turns red and blinks while recording and turns green while writing.

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
version must match the one in `Cargo.toml`. `linux/target/` does not belong
in Git. The macOS app and its Swift CI are not changed by this.

Development and tests need no real secrets; the HTTP tests only use a local
stub. The key comes in from any trusted source through a pipe
(`trusted-secret-command | opendictate secrets set-api-key`).

### Flow and safety rules

- `toggle` starts a recording without taking focus. While the microphone opens
  the state is `starting`; only then is the recording reported as started, and
  a microphone that fails or takes longer than 5 seconds ends the start with a
  notification. `cancel` during `starting` ends the start, which is then not
  reported as started; audio already captured is kept. The second
  call stops the recording and switches to
  `processing`; further starts during `starting`, `processing` or `delivering`
  are refused.
- Below 1 second, or without a 50 ms window above −45 dBFS, nothing is
  uploaded. The recording is kept with a mark: plain `retry` passes it over,
  and `retry --skipped` sends the last such recording anyway. It counts toward
  the five newest kept recordings like any other. Detected speech keeps a 0.25-second margin; only savings of 0.35
  seconds or more produce a trimmed upload WAV. The 90-second limit stays on.
- With a target language set, the transcript is then translated via
  `/chat/completions` of the same server and only the translation is delivered. If the
  translation fails or is empty, the recording is kept like with any other
  error; `retry` translates again. Tried live on omarchy on 5 October
  ([plan with evidence](../docs/linux-live-translation-plan.md)).
- A non-empty transcript is written only to the Wayland clipboard. The
  recording may be removed only after the copy succeeded. A clipboard history
  manager (for example cliphist, clipman or the one in your desktop shell)
  keeps its own copy of every transcript; OpenDictate cannot prevent or
  remove that.
- Auto-paste (on by default, `settings insert off` turns it off): at start the
  active Hyprland window is captured. After copying, the CLI checks that
  exactly this window is still in front and the clipboard still holds the
  text, then sends Ctrl+V (Ctrl+Shift+V in known terminals) to that window via
  `hyprctl dispatch`. Multi-line text is never sent to a known terminal; it
  stays in the clipboard. It first uses the Lua form `hl.dsp.send_shortcut`
  (Hyprland with Lua config, for example 0.56), and the older `sendshortcut`
  only when Hyprland clearly rejects it. Otherwise the text stays in the
  clipboard with a notice. If the clipboard no longer holds exactly the text
  before pasting, or cannot be read within 2 seconds, the dictation counts as
  not delivered and the recording is kept for `retry`; the same after `cancel`
  during delivery. The paste itself is unconfirmed; otherwise the recording
  counts as delivered once the copy succeeded. `retry` never pastes
  automatically.
- Every request has a time limit from its start, connecting included:
  transcription 15 seconds plus upload time at about 2 Mbit/s (about 50
  seconds for a 90-second recording at 48 kHz), translation 15 seconds plus
  one second per 100 characters (at most 60 seconds). With a custom server the
  base is 2 minutes instead of 15 seconds (translation at most 3 minutes).
  Connecting alone may take at most 10 seconds. If the network drops during a short dictation, the "No connection
  to the service" message comes after about 20 seconds instead of up to two
  minutes; if it breaks in the middle of a long upload, it can take up to twice
  the limit. The limit does not cover a hanging name lookup (DNS).
- Errors, cancel, empty answers or clipboard errors keep the audio. A recovery
  copy is bound with HMAC-SHA256, keyed from the Secret Service, to file name,
  creation time and exact bytes. If the copy fails, the original is kept.
- `retry` only uploads freshly authenticated bytes and removes them only after
  a successful clipboard copy. Unknown, modified or expired files are never
  uploaded. Managed recovery keeps at most five files for 24 hours; whatever
  is past those limits is also removed after the next successful dictation.
- Logs contain states and bounded timings, but no key, no transcript and no
  audio. The captured window class may be included; window titles are never
  read or logged.

State lives in `$XDG_STATE_HOME/opendictate/` (else
`~/.local/state/opendictate/`), settings in `$XDG_CONFIG_HOME/opendictate/`
(else `~/.config/opendictate/`). Empty or relative `XDG_*` values are ignored;
without an absolute `HOME` OpenDictate stops with a message.
App, pending and recovery folders are real directories with mode `0700`; audio
files and proofs `0600`.

### Still open

- Phase 1 is not formally accepted: live upload, translation, shortcut, and
  cancel and network loss during processing are shown on omarchy on 5 and
  7 October in single cases. The shorter timeouts since then are only tested
  offline.
- Bar indicator and auto-paste are tried on one machine in single cases
  (editor, terminal, window switch, translation; as of `fae3dae`,
  [evidence](../docs/linux-live-translation-plan.md)); the later clipboard
  hardening and the Waybar variant are not tested live. No settings window.
- A cancel during a blocking HTTP call is evaluated after it returns or times
  out; it never deletes the only recording.
- The Arch package is installed on one machine (omarchy) and checked with a
  dictation ([evidence](../docs/linux-live-2026-10-05-bis-07.md#live-nachweis-arch-paket--8-oktober-2026));
  not in the AUR, no second distribution.

## Maintainer: local Linux package

From a clean checkout on Linux with Rust/Cargo 1.98.1 already selected and the
ALSA build headers installed:

```bash
bash scripts/package-linux.sh --tag linux-v0.1.0-beta.2 --output /absolute/new/package-dir
bash scripts/package-linux.sh --verify /absolute/new/package-dir/opendictate-linux-v0.1.0-beta.2-x86_64-unknown-linux-gnu.tar.gz
```

The requested tag string must match Cargo.toml and PKGBUILD. The script creates
no Git tag and publishes nothing. The new output directory must be outside
the checkout and must not exist. It contains binary/source archives,
SHA256SUMS and a manifest. Binary files, licenses, notices and examples have
fixed ordering, ownership and commit timestamps. Verification checks the
archive and per-file hashes, then runs only `--version` and `--help` from a
temporary directory. Repeat the build to two different output directories and
compare both archive hashes before release; identical real Linux build hashes
have not yet been established for this script.

## Vocabulary

Add your own words and names with `opendictate vocabulary add "Pull Request"`.
Use `vocabulary list`, `vocabulary remove "Pull Request"` and `vocabulary clear`
to manage them. The list stays in your private settings file and is sent as
`prompt` to your chosen transcription service, including a custom server.
Limits: 64 entries and 800 UTF-8 bytes including separators; no empty entries,
controls or surrounding whitespace. Nothing learns automatically. Settings and
reports show only the number of entries; operational logs never include them.

## Switch services without losing the server

`opendictate settings service openai` keeps the custom address and its models;
`settings service custom` restores them and requires a stored address.
`settings server off` is an alias for the OpenAI choice. Setting the first
custom address selects it; later address edits keep the existing choice.
Each service retains its own transcription and translation models; `settings
model` and `settings translation-model` edit the active service. Existing
settings with a server migrate their model names to the custom side. Legacy
custom model names also migrate when no address or environment override is
present, keeping the settings readable and restoring OpenAI's default model.
After an address edit, the output shows the actual active service. If the
stored address is inactive, it explains how to select it; no key is sent there.

The existing environment precedence remains: a selected stored custom address
wins over `OPENAI_BASE_URL`. Without an active stored address, that variable
still redirects requests, including after `service openai` or `server off`.
Unset it to use OpenAI itself. `settings show` and the bar tooltip show the
actual service; the tooltip includes only a custom host, never its full URL.

## Tap or hold the shortcut

`opendictate setup` asks how to record. Tap remains the default: the existing
`toggle` binding still works. Hold uses `start` on press and `stop` on release,
with the same recording/request lock. Repeated `start` during recording and
`stop` without recording do nothing. A quick release waits for a microphone
start already in progress, rather than losing the stop command. Very short or
silent audio follows the existing retained/skipped recovery path; it is not
silently deleted. Unlike Windows' 300 ms gesture threshold, Linux starts on
press because Hyprland supplies separate commands rather than raw key events.

For automatically edited bindings, the mode is saved only after the binding is
installed/loaded; configuration restoration follows a failed write, load or
settings save. When no editable config is found, or you choose to add the
binding yourself, the chosen mode is saved with the displayed manual binding
instructions. Add those lines before using the shortcut. `settings show`
prints `shortcut-mode`. Omarchy Lua uses the documented `o.bind_hold` helper;
classic config writes a press/release pair. With classic/plain Lua chord
bindings, release the main key before its modifier. Omarchy's helper handles
modifier changes. A live Hyprland keyboard test is still outstanding.

## Report a problem

`opendictate report` previews the whole diagnostic report in your terminal.
Only after you answer `y` does it open the support form in your browser.
The CLI sends nothing to support. You review and submit the form yourself.
Use `opendictate report --print` for just the address. Without a graphical
session or working `xdg-open`, confirmation prints the address instead.
Only known error/warning categories survive from the log, at most 30; raw
messages, free-form model names and server addresses are discarded.

## Local usage estimate

`opendictate usage` shows dictations, audio minutes and estimated USD cost for
today, the last seven local calendar days and the current local month. The
bar tooltip shows today's dictations and estimated US cents. This is a local
counter, not your provider account balance. It counts completed, non-empty
transcription/translation work, even when subsequent clipboard delivery fails.
Cancelled/failed/empty processing is excluded, so a provider may still charge
for work absent from this counter. Retries that succeed count as new requests.

The private `usage.json` under the state directory holds only timestamp,
service kind, model, audio seconds and optional translation token counts.
Entries older than 13 calendar months are pruned at access/write; `usage reset`
clears the counter. Custom servers count minutes with zero estimated provider
cost. Missing token usage and unknown models mean unknown cost. Prices come
from the dated shared `fixtures/pricing/prices.json`; actual invoices, taxes,
regional surcharges and cached-token discounts can differ. A ledger write
failure does not destroy an otherwise delivered dictation; it is logged as
`usage-write-failed` and is not a billing claim.

## Send one kept recording to OpenAI

A custom-server connection failure/timeout offers `opendictate retry --openai`.
It explicitly sends only the newest authenticated, unexpired, non-skipped
recording once to OpenAI itself, ignoring OPENAI_BASE_URL for this one request.
It requires your stored OpenAI key. There is no automatic switch: normal retry
and subsequent dictations keep using your configured service and model pairs.
The OpenAI model is used when known; legacy custom-only settings use the
default OpenAI model. No saved setting is changed. Failed/empty/cancelled
requests retain the recording under the existing recovery rules.
`status` also shows a recent custom network-failure hint (at most 24 hours);
a new processing attempt clears it. HTTP error replies such as 404 do not
produce this network-fallback offer. Short/silent skipped audio still requires
the separate explicit `retry --skipped` command and is never uploaded by this
one-off command.

Explicit OpenAI retry also covers a connection failure during translation; it
uses the default OpenAI translation model for this one request. Saved settings
remain unchanged.

The exact two-build native evidence and repeatable commands are in [Linux packaging](../docs/linux-packaging.md).
