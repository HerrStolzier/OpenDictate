# Checks

## Native daily panel

`./script/build_and_run.sh --daily` opens the installed user app without building
or spawning an additional instance. Close it before starting a preview.

`./script/build_and_run.sh --verify` builds and launches the isolated debug
preview, with no real recording, provider request, credential or clipboard
access. Use its controls to inspect display states and light/dark appearance.
This is native rendering evidence, not end-to-end dictation evidence.

Focus regression check (isolated debug apps only):

1. Open preview options with Cmd+0 and select “Passiven Status im Testfenster prüfen”.
2. Run `./script/build_and_run.sh --focus-fixture`. The preview waits for this empty test app, then displays the production panel passively and verifies unchanged foreground process and a non-key status window.
3. Type artificial text into the fixture; it must retain keyboard focus. Inspect the result in preview options.
4. With the preview inactive, click its main action directly without the title bar. It must activate and respond on the first click.
5. Verify Tab/Shift+Tab and Space through ready, recording, processing, cancel and ready; focus must stay on an available control.

These native interaction checks passed on 2026-09-13. Recording states are simulated; this does not prove microphone, API, paste or VoiceOver behavior.

The installed Swift 6.4 default build engine failed to find TestingMacros during
this development pass. Equivalent verification uses
`swift test -Xswiftc -warnings-as-errors -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing`; no compiler or
system installation is changed. Also lint the new run script with
`bash -n script/build_and_run.sh`.

- `swift test`: offline logic, lifecycle, HTTP stubs, recovery, logging and synthetic audio-file tests. Optional benchmark and live API test are skipped by default.
- `swift format lint --configuration .swift-format --recursive Sources Tests Package.swift`: project formatting.
- `./scripts/build-app.sh`: release bundle, Plist and signature verification. Does not launch/install it.
- `git diff --check` and `bash -n scripts/build-app.sh` before handoff.
- Real microphone, hotkeys, target-field paste and VoiceOver require attended native-app acceptance; an accessibility tree alone is not a VoiceOver listening test.

## Explicit live API check

Only after authorization for the existing OpenAI account and the specific fixture. Place a short, non-sensitive `reference.m4a` in an explicitly chosen test directory. The current fixture text is: "Dies ist ein kurzer Test. Bitte schreibe die Zahl sieben und das Wort Apfel."

```
OPENDICTATE_LIVE_API=1 OPENDICTATE_LIVE_TEST_DIRECTORY=/path/to/test-directory swift test --filter LiveTranscriptionTests
```

One request uses `gpt-transcribe` by default, German language and JSON output. Set `OPENDICTATE_LIVE_TEST_MODEL=gpt-4o-mini-transcribe` to check the other offered model separately. Only these two model identifiers are accepted. The existing Keychain key remains in memory; no credentials appear in arguments or evidence. `api-result-<model>.json` contains timing, input size and the test transcript. Synthesized speech is not evidence of human microphone quality. No retries are automatic.

## Processing-time focus integration fixture

Run `./script/build_and_run.sh --processing-focus-preview` only for an explicitly
authorized UI/delivery check. This mode uses real DictationFlow, DictationPanel and
PasteboardInserter with a synthetic 20-second provider delay and fixed text.

1. Prepare a new empty TextEdit document. Ensure the preview's existing Accessibility
   grant is effective; an enabled settings switch alone is insufficient.
2. Click “Test vorbereiten”, then focus the test document. Verify processing appears
   without taking keyboard focus.
3. Stay in TextEdit until delivery: fixed test text must appear exactly once and the
   panel must explain unconfirmed insertion with the neutral wording.
4. Repeat, but switch away during processing: the captured TextEdit document must
   remain unchanged, the other app must retain focus, and the result must be available
   for manual use. Inspect the foreground-switch skip reason, not just absence of text.
5. Quit the fixture normally to restore its clipboard snapshot when unchanged, close
   its test document, and verify no preview, VoiceOver or debugger is left running.

This proves the exercised UI/flow/delivery path with synthetic transcription, not
microphone capture, provider transcription, or general speech accuracy.

Both processing-focus cases passed on 2026-09-13 using the identical short-path
copy described in `docs/live-acceptance-2026-09-13.md`. The normal macOS app launch
reused existing instances for an actual foreground switch; background-only UI
events did not suffice. The daily launcher also passed both duplicate prevention
and repeated-open reuse checks. All helpers were closed afterward.
