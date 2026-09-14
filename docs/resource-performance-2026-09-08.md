# Resource performance, 2026-09-08

Scope: reduce redundant recovery-file reads and recording UI mutations, then run offline resource benchmarks. No app replacement, launch, microphone, provider call, credential change, commit or publication. The earlier native-acceptance task is deferred for this resource investigation, not completed by these results.

## Recovery cleanup

Release-mode Swift Testing benchmark on this Mac, 16 sequential passes per case; exclude iteration 0 as warm-up. Synthetic files and dummy sidecars in a temporary directory; no real recovery data or Keychain access. Baseline completed before the product edits. Same harness before and after; fixture creation is outside timed intervals. Medians of the remaining 15 passes:

| Files | Wall before / after | Process CPU before / after |
| --- | --- | --- |
| Empty | 0.055 / 0.060 ms | 0.056 / 0.060 ms |
| 5 × 500,000 bytes | 0.982 / 0.862 ms | 0.983 / 0.863 ms |
| 5 × 16 MiB | 8.389 / 0.847 ms | 8.386 / 0.846 ms |

This is cleanup only, not the full library snapshot or whole-app CPU usage. The ordinary-size absolute saving is small. The 16 MiB case exercises the storage read limit, not a typical 90-second recording. Single ordered before/after comparison; no universal speedup claim.

Cleanup now uses non-following metadata lookup to remove a sidecar only when the corresponding audio entry is absent. It no longer loads complete audio contents for this existence decision. Existing ambiguous, unreadable or symlink entries retain sidecars. Retry authentication, exact-byte upload checks, retention age and count are unchanged. Library snapshots still authenticate recordings; no authentication cache was introduced.

Process peak RSS in the benchmark was approximately 41.4 MiB before and 41.3 MiB after for the largest case. Fixture creation and test-runner allocations are included in this cumulative process high-water mark. These figures do not establish a RAM saving or the running app's peak memory requirement.

## UI changes

Recording updates still sample level every 200 ms. The symbol and action availability are refreshed on state transitions, and the seconds title is assigned only when it changes. Level/status and accessibility information continue updating. This eliminates redundant mutations by code inspection, but no native UI CPU or energy saving has been measured. Existing explicit menu and transcript actions continue refreshing their controls.

## Audio baseline

Existing release-mode synthetic 90-second AAC benchmark, seven iterations, first excluded: analysis median 15.126 ms (14.738–16.198); export median 5.555 ms (5.256–6.827). Input 439,465 bytes. No audio pipeline changes were made. Synthetic tones do not measure microphone behavior or speech quality.

## Verification and remaining measurement gaps

- Required format lint, warnings-as-errors offline suite, both shell syntax checks and diff whitespace check passed. Runner: 99 tests in 21 suites; optional live/resource/audio benchmark tests disabled in the ordinary suite and benchmark cases run separately where described.
- New regression covers valid authenticated data, tampered data, dangling symlink, and genuinely absent audio. Tampering and symlinks remain non-retryable.
- Still unmeasured: native UI/VoiceOver behavior after the UI change; idle CPU/energy over a representative period; peak app memory during recording, request construction and recovery; memory growth over repeated dictations. The older running app cannot validate these source changes. A newly built candidate requires corresponding launch authorization.
- No storage-retention reduction: logs and recovery counts were already bounded. No user data was removed.

Raw samples: `benchmarks/2026-09-08/recovery-before.csv`, `recovery-after.csv`, `audio.csv`.
