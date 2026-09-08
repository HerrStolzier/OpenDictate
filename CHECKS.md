# Checks

- `swift test`: offline logic, lifecycle, HTTP stubs, recovery, logging and synthetic audio-file tests. Optional benchmark and live API test are skipped by default.
- `./scripts/build-app.sh`: release bundle, Plist and signature verification. Does not launch/install it.
- `git diff --check` and `bash -n scripts/build-app.sh` before handoff.
- Real microphone, hotkeys, target-field paste and VoiceOver require attended native-app acceptance; an accessibility tree alone is not a VoiceOver listening test.

## Explicit live API check

Only after authorization for the existing OpenAI account and the specific fixture. Place a short, non-sensitive `reference.m4a` in an explicitly chosen test directory. The current fixture text is: "Dies ist ein kurzer Test. Bitte schreibe die Zahl sieben und das Wort Apfel."

```
OPENDICTATE_LIVE_API=1 OPENDICTATE_LIVE_TEST_DIRECTORY=/path/to/test-directory swift test --filter LiveTranscriptionTests
```

One request uses `gpt-transcribe` by default, German language and JSON output. Set `OPENDICTATE_LIVE_TEST_MODEL=gpt-4o-mini-transcribe` to check the other offered model separately. Only these two model identifiers are accepted. The existing Keychain key remains in memory; no credentials appear in arguments or evidence. `api-result-<model>.json` contains timing, input size and the test transcript. Synthesized speech is not evidence of human microphone quality. No retries are automatic.

## Requested guard command

`python3 scripts/agent_finish.py --auto-claims` is requested by the current session rules, but `scripts/agent_finish.py` is not present in this repository. This is an unavailable check, not a passing check. Do not run an unrelated project's script as a substitute.
