# OpenDictate

Open-source dictation for Mac and Linux. Hold a key, say what you want to
write, let go. A moment later the text is in the app you were typing in,
translated if you like (say, German into English).

No subscription: with a model running on your own computer, dictation costs
nothing. With OpenAI it costs about a tenth of a cent per dictation, paid
directly to OpenAI with your own key. The beta is free; the finished app will
later be a one-time purchase of a few euros.

OpenDictate is a small open-source menu bar app for Macs with Apple silicon
(macOS 14 or newer). There is also a beta for
[Linux with Hyprland](linux/README.md).

**[Download the Mac beta](https://github.com/HerrStolzier/OpenDictate/releases/tag/v0.1.0-beta.12)** ·
[Install guide (German)](docs/release-plans/installationsanleitung.md) ·
[Website](https://opendictate.app)

## Why OpenDictate

- **Free or almost free.** Run a model such as whisper.cpp on your own
  computer and dictation costs nothing; your audio never leaves the machine.
  Or use your own OpenAI API key and pay OpenAI $0.0045 per minute of speech.
  A typical 15-second dictation is about 0.1 cent, and ten minutes a day add
  up to about $1.35 a month. The Mac beta (from Build 12) and the Linux
  beta both support your own server.
  [How to set up a local model](docs/lokales-modell.md) (German).
- **No dictation gets lost.** If the network drops or the service fails, the
  recording stays on your Mac for up to 24 hours and you can send it again.
- **Your words, not a rewrite.** OpenDictate pastes what you said. It only
  changes the text when you turn on translation.
- **Open and private.** MIT-licensed, your key stays in the macOS Keychain,
  no tracking.

## Getting started

1. Download the ZIP, drag OpenDictate to Applications and open it.
2. Click the menu bar icon (that's Blink), choose **API-Schlüssel einrichten …**
   and paste your OpenAI API key. Saving it costs nothing.
3. Pick your shortcut: hold Fn, hold the right Option key, or press ⌃⌥D.
   The app suggests the one that fits your keyboard.
4. Allow the microphone, and Accessibility for pasting and for single keys
   like Fn. Without Accessibility, use a key combination like ⌃⌥D; the text
   then waits on the clipboard for you to paste.
5. Click into any text field, hold your key, talk, let go. With a key
   combination: press it, talk, press it again.

The app's menus are in German for now.

## Good to know

- Up to 90 seconds per dictation. It's made for messages, mails and notes.
- OpenDictate pastes into the app you started in but can't see whether the
  text arrived, so take a quick look. It also stays on the clipboard.
- Tested in TextEdit, Safari, Brave, Obsidian and Terminal. Other apps should
  work; please [let me know](https://github.com/HerrStolzier/OpenDictate/issues/new?template=beta-rueckmeldung.md)
  if one doesn't.

Everything else, from the settings to your own server and what happens to a
failed recording, is in [the details](docs/mac-details.md). How your audio and
text travel is in [PRIVACY.md](PRIVACY.md).

## Using your own server

With a speech model on your own computer, dictation is free and your audio
stays with you. The Mac beta (from Build 12) and the Linux beta can both do this.
[Step-by-step guide](docs/lokales-modell.md) (German) ·
[Mac settings](docs/mac-details.md#using-your-own-server)

## Build it yourself

With Swift 6 on macOS:

```bash
./scripts/build-app.sh
open .build/OpenDictate.app
```

A local build is not signed and notarized like the beta; see
[development workflows](docs/development.md) and
[signing](docs/accessibility-signing.md) before you share one. Plans and
checks live in [ROADMAP.md](ROADMAP.md) and [CHECKS.md](CHECKS.md) (mostly
German).

## License

The code is under the [MIT License](LICENSE). The name, the logos, Blink and
the app icons are not; see [TRADEMARKS.md](TRADEMARKS.md). The architecture was
inspired by VoiceScribe; its notice is in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
