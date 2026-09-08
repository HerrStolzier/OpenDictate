# Performance decisions, 2026-09-06

Local release-mode measurements on this host, seven runs, synthetic 90 s AAC input at 24 kHz mono / nominal 48 kbit/s. No network, microphone or live target application was used. The macOS codec tests failed inside the agent sandbox and passed when explicitly run with host codec access.

| Measurement | Observed |
|---|---|
| Input size | 439,465 bytes |
| Analysis, warm runs | 14.72–15.70 ms |
| Export of 89.5 seconds, warm runs | 5.75–6.33 ms |
| Export size | 416,287 bytes |

Decisions:

- Review 11: retain the current 0.35 s threshold. This fixture does not justify raising it: export is inexpensive locally and the result is smaller. It does not prove that every trim is worthwhile over a real network or improve perceived latency.
- Review 12: retain the sample loop. Total file analysis is about 15 ms for the maximum normal recording here. There is no demonstrated material end-to-end gain that justifies introducing a second analysis path or changing the recorder architecture. Revisit with profiling if real latency identifies analysis as a bottleneck.
- Review 15: retain the in-memory multipart body. This maximum-duration fixture is under 0.5 MB. A file/stream upload would add lifecycle complexity without a demonstrated current memory issue. This is a file-size observation, not a measured peak-RSS assertion.
- Reviews 9/10: remove synchronous whole-library reads from menu opening and load the newest valid candidate lazily. Authentication of exact upload bytes remains mandatory. These are structural reductions of unnecessary work; no measured UI-speedup percentage is claimed.
- Review 14: bounded serial logging removes concurrent append races and unbounded growth; logging is queued away from callers.
- Review 29: log preparation, analysis, export, request, delivery and stop-to-result durations without text/audio payloads. Live request latency remains unmeasured.

Real speech, network latency and total user correction effort remain separate acceptance gates; see `audio-quality-fixtures.md`.
