# Audio quality and latency evidence

The `AudioPipelineTests` generate synthetic tones and silence locally. They verify window boundaries, low levels, playable exports and reproducible phase timings. They contain no microphone recordings and make no provider calls. They do not measure speech-recognition accuracy, word error rate (WER), accents, proper nouns or user correction effort.

## Reproduce

Run `swift test` for ordinary checks. For measurements use a release build:

```sh
OPENDICTATE_BENCHMARK=1 OPENDICTATE_BENCHMARK_OUTPUT=/tmp/opendictate-audio.csv swift test -c release --filter AudioPipelineTests
```

On constrained agent hosts the macOS AAC codecs may require permission to run outside the agent sandbox. Do not treat codec unavailability as a passed or skipped audio test. The current tests use seven measurements of a synthetic 90-second mono 24 kHz / 48 kbit/s AAC file. Compare the same machine, power conditions, build and fixture. Exclude the first measurement when comparing warm medians, and keep raw data.

## Real speech corpus still required

A representative local corpus should include at least: short German words, quiet German sentences, sentence beginnings/endings, numbers and dates, personal and product names, English, German/English switches, background noise and microphone variants. Each case needs a consented audio file, exact reference transcript, duration, microphone, language and expected terms. Store these separately from the public repo unless explicitly licensed for distribution.

For each candidate report WER, number/name errors, unwanted added terms, correction time, time to first visible text and stop-to-final-text latency. Live uploads require explicit authorization; do not upload local recordings automatically during tests or CI. Model/keyword/streaming changes remain unproven for real speech until this evaluation is performed.
