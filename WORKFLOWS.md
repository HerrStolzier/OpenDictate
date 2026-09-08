# OpenDictate workflows

Build with `./scripts/build-app.sh`; the bundle is `.build/OpenDictate.app`. Use the in-app Keychain dialog for API credentials. Never pass a key in a shell command or environment variable.

Main flow: global hotkey -> microphone recording -> local audio preparation -> OpenAI transcription -> clipboard -> optional paste into the original application if it remains frontmost. Inputs are microphone audio, selected model/language and optional vocabulary. Last transcript stays in RAM; failed/uncertain audio is kept for deliberate manual retry with expiry.

`AppDelegate` binds the UI/hardware; `DictationFlow` owns state and recovery decisions; `RecordingLibrary` handles background library snapshots; `OpenAITranscriber` builds and decodes requests. See README.md and PRIVACY.md for details.

Use CHECKS.md for offline, release and explicitly enabled live tests. See docs/current-status.md for active authorization and docs/remaining-acceptance.md for unverified behavior. Building/signing, starting, installing, committing and pushing are distinct actions.
