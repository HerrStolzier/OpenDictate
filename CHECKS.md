# Checks

- `swift test`: offline logic, lifecycle, HTTP stubs, recovery, logging and synthetic audio-file tests. Optional benchmark and live API test are skipped by default.
- `swift format lint --configuration .swift-format --recursive Sources Tests Package.swift`: project formatting.
- `./scripts/build-app.sh`: release bundle, Plist, signature and Hardened Runtime verification. Does not launch/install it.
- `git diff --check` and `bash -n scripts/build-app.sh` before handoff.
- Real microphone, hotkeys, direct target-field insertion, clipboard fallback and VoiceOver require attended native-app acceptance; an accessibility tree alone is not a VoiceOver listening test.
- After changing the insertion mechanism, recheck one native text control and one actually used browser or Electron control. A successful historical `Cmd+V` test does not validate direct `AXSelectedText` insertion.
- For a legacy API-key item, save the key once through the in-app dialog and inspect or test its resulting ACL separately; never use a real credential in automated checks.

## Explicit live API check

Only after authorization for the existing OpenAI account and the specific fixture. Place a short, non-sensitive `reference.m4a` in an explicitly chosen test directory. The current fixture text is: "Dies ist ein kurzer Test. Bitte schreibe die Zahl sieben und das Wort Apfel."

```
OPENDICTATE_LIVE_API=1 OPENDICTATE_LIVE_TEST_DIRECTORY=/path/to/test-directory swift test --filter LiveTranscriptionTests
```

One request uses `gpt-transcribe` by default, German language and JSON output. Set `OPENDICTATE_LIVE_TEST_MODEL=gpt-4o-mini-transcribe` to check the other offered model separately. Only these two model identifiers are accepted. The existing Keychain key remains in memory; no credentials appear in arguments or evidence. `api-result-<model>.json` contains timing, input size and the test transcript. Synthesized speech is not evidence of human microphone quality. No retries are automatic.
