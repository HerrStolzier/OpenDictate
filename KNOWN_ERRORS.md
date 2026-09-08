# Known errors and limits

- Codec operations can fail inside the agent sandbox even when pure audio-level tests pass. A host-codec run passed in the earlier acceptance. Do not mark a sandbox codec failure as a passing audio test.
- The native UI tool times out when selecting the currently built windowless menu-bar app. Selecting only its bundle identifier is ambiguous because multiple installed/development copies share `local.opendictate.app`. Verify the launch path and signing identity; do not accept a different copy by accident. Attended menu opening is pending.
- In the current UI-automation environment, synthesized `Option+Shift+Space` is delivered to TextEdit as a non-breaking space instead of triggering OpenDictate's Carbon global hotkey. No audio or log event is created. Do not count this as a product failure or keep repeating it; a physical hotkey press is required for the remaining native-duration run.
- The current session requests `scripts/agent_finish.py --auto-claims`, but that script is absent from OpenDictate. The command cannot currently provide a project guard result.
- Prior source fixes and their tests are documented in docs/improvement-plan.md. Real VoiceOver, microphone and target-field behavior must be checked separately from those tests.
