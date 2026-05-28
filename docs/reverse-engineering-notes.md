# Reverse-Engineering Notes

## Selected Reference

The best reference candidate is VoiceScribe:

- Repository: https://github.com/eddmann/VoiceScribe
- License: MIT
- Stack: native Swift/macOS
- Scope: small menu bar app, global hotkey, local audio recording, transcription, clipboard, optional auto-paste

VoiceInk and TypeWhisper are useful references but GPL-licensed and much larger. Astra is smaller, but Electron/Node, which is a less direct fit for a native menu bar dictation helper.

## Architecture Extracted

VoiceScribe's core loop is:

1. Capture the currently focused app.
2. Open a small recording affordance from a global hotkey.
3. Record microphone audio to a temporary file.
4. Transcribe the file.
5. Copy the final text.
6. Refocus the previous app.
7. Simulate `Cmd+V` when Accessibility permission is available.

OpenDictate keeps this loop but strips it down:

- Carbon `RegisterEventHotKey` instead of a hotkey package.
- `AVAudioRecorder` for temporary `.m4a` recording.
- OpenAI `/v1/audio/transcriptions` instead of local WhisperKit for the first MVP.
- `NSPasteboard` plus `CGEvent` for paste.
- Keychain fallback for the OpenAI API key.

## Next Improvements

- Add a real floating UI with waveform/status.
- Add push-to-talk hold behavior instead of toggle-only.
- Add a settings window for hotkey, model, language, and prompt.
- Store user preferences with `UserDefaults`.
- Add local WhisperKit mode after the systemwide shell is stable.
