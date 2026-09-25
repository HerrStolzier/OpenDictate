# Test-audit register · 25 September 2026

## Scope and evidence

This is the declaration-level inventory for the OpenDictate Swift tests at base commit
7309c02bdf83a93ab94890b4770dc07f7f8a9178. The checkout was clean at that commit.
It covers all 27 Swift test files: 50 declarations in OpenDictateCoreTests and 87
in OpenDictateSystemTests, 137 total. Parameterized declarations count once in
this inventory. Four opt-in executions were reported skipped by the baseline run.

The baseline full suite passed in the main checkout. Its coverage export instruments
45 production Sources files across the Core, app, and helper targets. The baseline
was 1,754/5,175 lines (33.8937%), 678/2,094 regions (32.3782%), and
227/759 functions (29.9078%). Core line coverage was 328/360 (91.111%);
app line coverage was 1,426/4,720 (30.212%). A separate helper scope reported
0/95 covered lines. Raw baseline files were preserved at
/tmp/opendictate-coverage-baseline-7309c02.json and
/tmp/opendictate-coverage-baseline-7309c02.log.

Those figures are suite-wide source coverage, not causal coverage per test. The
baseline output did not isolate coverage by test file or declaration. The full
suite result establishes that the 27 files were included and passed together;
individual file-level pass logs and per-test coverage are unavailable. The
coverage artifacts came from the main checkout, not this register worktree.
No tests were run in this worktree before the register was committed.

This register proposes exactly 28 removals. It keeps both audio-content guards
SpeechRangeAccumulatorTests.spansFirstToLast and TrimPlannerTests.padsBothSides.
Those prevent loss of later speech and clipping at the start/end padding. They
were replaced in the removal set by the lower-priority configuration edges
SettingsTests.emptyEnvironmentIgnored and SettingsTests.environmentOnlyValues.
The resulting selection is 21 Core and 7 System declarations. This is a
20.4% reduction in declarations, rounded to the requested 20% scope.

The earlier 28-case skip pilot used the uncorrected selection, so its coverage
delta is not evidence for this corrected set. The corrected selection must be
measured separately after the register commit. No production changes are
proposed. No test was reclassified F (repair) or C (merge); the review found no
assertion to repair and no selected contract that needed a new owner.

Disposition key: R = retain with the named contract and plausible regression;
F = repair an ineffective assertion; C = consolidate and name the surviving
owner; D = remove and record the exact lost signal and remaining evidence.
Every declaration below has one disposition.

## Declaration inventory

### Audio preparation · OpenDictateCoreTests/AudioLevelsTests.swift

- D · emptyWindow (line 9): exact floor for a zero-sample window; see D1.
- D · digitalSilence (line 14): finite floor for all-zero samples; see D1.
- D · quietWindow (line 21): quiet input remains under the speech threshold; see D1.
- D · loudWindow (line 31): full-scale input is 0 dBFS and above threshold; see D1.
- D · allSilent (line 46): silent windows produce no speech range; see D1.
- R · spansFirstToLast (line 54): range includes the first and last loud windows across a pause; this is the retained speech-content guard.
- R · thresholdIsInclusive (line 65): a window exactly at threshold counts as speech; catches a strict-greater-than regression.
- D · singleWindow (line 73): one loud window produces a range; see D1.

### Audio preparation · OpenDictateCoreTests/TrimPlannerTests.swift

- R · padsBothSides (line 24): preserves configured audio around speech on both sides; retained as a content-integrity guard.
- D · neverNegativeStart (line 33): lower-clamps padding at time zero; see D2.
- R · clampsToEnd (line 40): upper-clamps the planned range to recording duration.
- D · shorterThanPadding (line 48): returns a sane plan when the source is shorter than padding; see D2.
- R · skipsPointlessExport (line 58): avoids a re-encode when savings are below the threshold.
- R · errorCarriesDurations (line 68): returns the specific too-short error with actual and required durations.

### Audio preparation · OpenDictateSystemTests/AudioPipelineTests.swift

- R · silentAndQuietFilesAreDistinguishedByMeasuredLevel (line 34): real synthetic WAV analysis distinguishes silence from a quiet signal.
- R · detectsWindowBoundariesAndExportsPlayableAudio (line 47): runs analysis and AAC export over synthetic audio and checks playable output and broad duration.
- D · shortDetectedSpanDoesNotPretendThereWasNoAudio (line 61): detects a short non-silent span instead of classifying it as no speech; see D10.
- R · benchmark (line 69): opt-in audio processing benchmark; retained and disabled unless OPENDICTATE_BENCHMARK=1.

### Settings and shortcuts · OpenDictateCoreTests/CustomShortcutTests.swift

- R · rejectsUnmodifiedTypingAndUnknownModifiers (line 7): rejects shortcut values that would consume ordinary typing or unsupported modifier bits.
- R · acceptsModifiedKeys (line 12): accepts a custom key when it has a supported modifier.

### Settings and shortcuts · OpenDictateCoreTests/SettingsTests.swift

- D · modelFromEnvironment (line 44): initial model falls back to the environment and reports its source; see D3.
- R · storedModelWinsOverEnvironment (line 51): a user's stored model beats the environment value.
- D · emptyEnvironmentIgnored (line 59): an empty model environment value falls back to the default; see D3.
- R · languageDefaultsToAuto (line 67): unset language remains automatic.
- D · languageFromEnvironment (line 72): language uses the environment until a menu choice exists; see D3.
- R · explicitAutoBeatsEnvironment (line 77): an explicit Auto selection does not fall through to the environment.
- D · shortcutRoundTrip (line 86): persists and restores a selected shortcut through Settings; see D3.
- R · unknownStoredShortcutFallsBack (line 93): invalid shortcut pair falls back to default.
- R · partialStoredShortcutFallsBack (line 99): a partially persisted shortcut cannot register a stray key.
- R · resetToEnvironment (line 107): reset clears stored values and restores environment-controlled settings.
- D · environmentOnlyValues (line 129): prompt environment input is passed through and an empty prompt means unset; see D3.
- D · presetsAreDistinct (line 138): offered shortcuts have distinct key/modifier pairs; see D3.

### Settings and shortcuts · OpenDictateCoreTests/TranscriptionModelTests.swift

- R · realtimeModelRejected (line 9): realtime-only model cannot enter the upload path.
- D · uploadModelsAccepted (line 24): four named upload models are accepted by the core policy; see D4.
- R · unknownModelIsAllowed (line 30): new model identifiers remain forward-compatible.

### Settings and shortcuts · OpenDictateSystemTests/UserDefaultsStoreTests.swift

- R · settingsPersistAndRemoveThroughTheAdapter (line 9): the actual UserDefaults adapter writes, reads, and removes values.

### Settings and shortcuts · OpenDictateSystemTests/HotKeyTransactionTests.swift

- R · collisionKeepsPreviousRegistration (line 9): a failed replacement preserves the previous registration and preference.

### Settings and shortcuts · OpenDictateSystemTests/NativeHotKeyRegistrationTests.swift

- R · collisionRetainsOriginalSystemRegistrationAndReleasesBoth (line 11): native registration collision does not lose the old system hotkey and releases the failed candidate.

### Settings and shortcuts · OpenDictateSystemTests/ShortcutCaptureTests.swift

- R · dialogCommandsPreserveCapturedShortcut (line 18): dialog commands do not overwrite the captured shortcut.
- R · navigationKeysWithShortcutModifiersRemainRecordable (line 35): navigation keys remain recordable with supported shortcut modifiers.
- R · unfocusedCaptureDoesNotConsumeWindowKeyEquivalents (line 47): an unfocused field does not steal normal window commands.

### Transcription contract and errors · OpenDictateCoreTests/OpenAIAPIErrorTests.swift

- D · invalidKey (line 13): maps HTTP 401 to the API-key guidance; see D5.
- R · exhaustedQuota (line 22): distinguishes exhausted quota from temporary rate limiting.
- R · rateLimited (line 31): tells the user to wait for a rate limit.
- D · malformedBody (line 39): maps an unparseable HTTP 413 to shorter-recording guidance; see D5.
- D · emptyBody (line 45): maps an empty server-error body to retry-later guidance; see D5.
- R · unknownCodeHidesServerMessage (line 51): unknown provider text is not exposed.
- D · unknownCodeWithoutMessage (line 60): no-message unknown-code case uses the same fallback; see D5.
- R · fallsBackToType (line 66): missing provider code uses the error type.

### Transcription contract and errors · OpenDictateCoreTests/FormattingTests.swift

- R · skippedClassification (line 9): skipped audio is not formatted as a real failure.
- D · tooShortMessage (line 18): user message includes actual and minimum durations; see D6.
- D · noSpeechMessage (line 25): no-speech guidance avoids exposing raw measurements; see D6.
- R · frameworkMessage (line 31): framework errors receive a safe next action without raw details.

### Transcription contract and errors · OpenDictateSystemTests/TranscriptionRequestTests.swift

- R · languageFieldMatchesModel (line 10): request language field follows model policy for each argument.
- R · parsesTypedResponseAndRejectsMalformedSuccess (line 21): accepts the typed success response and rejects malformed success data.

### Transcription contract and errors · OpenDictateSystemTests/TranscriptionTransportTests.swift

- R · successAndNetworkFailures (line 28): the URLSession transport handles successful and failed stubbed network responses.

### User-facing status and setup · OpenDictateSystemTests/APIKeySetupTests.swift

- R · presenceQueryCannotReturnASecretOrPromptForAccess (line 11): presence checks reveal neither a credential nor an access prompt.
- R · existingOrInaccessibleItemsDoNotTriggerFirstRunSetup (line 25): uncertain Keychain state does not incorrectly launch first-run setup.
- D · setupActionAndSavingDoNotStartARecording (line 50): setup/save action does not enter recording; see D9.
- D · cancelledOrFailedSetupKeepsItsActionAvailable (line 73): retry action remains available after cancel/failure; see D9.
- R · configuredUsersKeepTheirExistingTranscriptAction (line 89): API setup does not displace the configured transcript action.
- R · setupRefreshCannotReplaceAnActiveRecording (line 101): setup refresh does not replace active recording state.

### User-facing status and setup · OpenDictateSystemTests/DictationPanelTests.swift

- R · fullDictationCycleStaysHiddenAndRetainsItsTranscript (line 22): passive panel updates remain hidden and keep the transcript.
- R · permissionFailureKeepsItsMessageAndRecoveryActionWithoutOpening (line 54): later-opened panel exposes recovery after permission failure.
- R · setupUpdatesKeepTheirActionAvailableWithoutOpeningOrRecording (line 77): setup action remains visible while the panel stays hidden and no recording begins.
- R · uncertainInsertionShowsCompleteTextAndCopyWithoutClaimingNoInsertion (line 110): uncertain insertion retains complete text and copy without claiming failure.
- R · completeSubmissionStaysUnconfirmedAndTextRemainsAccessible (line 140): submission is not overstated as confirmed delivery.
- R · noSubmissionShowsCompleteTranscriptForManualCopy (line 159): a transcript remains available for manual copy when no insertion was submitted.

### Dictation lifecycle and delivery · OpenDictateSystemTests/AppLifecycleTests.swift

- D · activeOperationRejectsRepeatedNestedBegins (line 98): a second begin is rejected while a token is active; see D7.
- R · lateMicrophoneAnswerCannotStartOrReleaseANewerPreparation (line 115): stale permission callback cannot start or release a newer operation.
- R · backDuringRetryLoadingInvalidatesTheUpload (line 138): navigating back invalidates a pending retry upload.
- D · cancelledOperationIsRejectedByQueuedCurrentnessCheck (line 157): a queued callback checks and rejects a cancelled token; see D7.
- R · quitDuringPreparationRejectsLateSuccessAndErrorCallbacks (line 175): quit invalidates both late success and failure callbacks.
- D · setupModalCannotAdmitAHotkeyOrSaveAfterNestedQuit (line 199): nested quit excludes a setup hotkey and a fake save counter; see D7.
- R · finishingFlowInsideQuitDialogDoesNotAllowASecondQuit (line 212): reentrant completion cannot create a second quit.
- R · automaticStopsWaitForTheQuitDecision (line 228): automatic recording stops wait for the user's quit decision.
- R · declinedQuitKeepsTheExistingUploadAlive (line 252): declining quit leaves an in-flight upload intact.
- R · repeatedQuitDrainsOnceBeforeItsSingleReply (line 267): repeated quit drains once and replies once.
- R · reentrantQuitDuringRecoveryCannotCancelOrReplyTwice (line 284): reentrant quit during recovery cannot cancel twice or duplicate the reply.
- R · normalCancellationFinishesRecoveryBeforeQuitCanProceed (line 298): normal cancellation completes recovery before quit proceeds.

### Dictation lifecycle and delivery · OpenDictateSystemTests/DictationFlowTests.swift

- R · retryCannotOverlapRecordingOrDisableStop (line 88): retry and recording are mutually exclusive and Stop remains actionable.
- R · emptyRetryKeepsAudio (line 100): empty retry preserves recoverable audio.
- R · recorderStopFailureReportsAnErrorWithoutUploading (line 108): stop failure is reported and does not upload.
- R · providerFailurePreservesOriginalForManualRetry (line 124): provider failure leaves the original available for retry.
- R · clipboardFailureKeepsAudioAndText (line 139): copy failure does not lose audio or transcript.
- R · successfulRetryCopiesWithoutPastingAndRemovesItsSource (line 151): successful retry copies text and removes only the recovered source.
- R · retryProvidesManualTextInsteadOfAnUnconfirmedPaste (line 158): retry offers manual text without implying paste confirmation.
- R · failedRecoveryCannotAdvertiseSuccess (line 168): failed recovery cannot claim success or delete the only source.
- D · automaticInsertionReceivesTheExactTrimmedTranscript (line 181): insertion receives the trimmed transcript; see D8.
- R · skippedAudioIsKeptWithoutUpload (line 190): skipped analysis keeps audio and never uploads it.
- R · failedDeliveryKeepsOriginalNotTrimmedAudio (line 201): failed delivery retains the original rather than a trimmed derivative.
- R · cancelBeforeProcessingPreservesAudio (line 211): early cancellation preserves the source.
- R · cancellationDuringUploadPreservesOriginalAndCleansTemporaryAudio (line 222): upload cancellation preserves original and removes temporary export.
- R · failedRecoveryDuringUploadCancellationKeepsOnlyOriginal (line 240): failed recovery copy during cancellation preserves the only original.
- R · explicitDiscardDuringUploadDeletesOriginalWithoutRecoveryCopy (line 259): explicit discard deletes only after the user chose it.
- R · explicitDiscardDoesNotUploadOrKeep (line 274): explicit discard neither uploads nor retains the recording.
- R · cancelledRetryDoesNotUpload (line 282): cancelled retry does not issue a provider request.
- R · secondStartIsRejectedDuringProcessing (line 291): processing rejects overlapping recording starts.
- R · insertionEvidenceReachesStatusWithoutChangingClipboardRecoveryPolicy (line 301): insertion evidence is surfaced without weakening clipboard recovery.
- R · cancellationAfterCopyBeforeInsertionLeavesTextAvailable (line 330): cancellation after copy leaves text available to the user.

### Dictation lifecycle and delivery · OpenDictateSystemTests/PasteboardInserterTests.swift

- R · ordinaryPasteDoesNotRequireAXFieldMetadata (line 35): ordinary paste does not require accessibility field metadata.
- R · changedForegroundAppDoesNotReceivePasteCommand (line 44): paste is not sent after the foreground application changes.
- R · changedClipboardDoesNotPasteUnrelatedContents (line 54): paste is blocked when clipboard contents changed.
- R · unavailablePermissionOrTargetDoesNotActivate (line 63): unavailable permission or target does not cause activation.

### Dictation lifecycle and delivery · OpenDictateCoreTests/PanelTargetPolicyTests.swift

- R · returnsOnlyToUnchangedTarget (line 6): focus return is permitted only to the captured, unchanged application.

### Recovery, authentication, and retention · OpenDictateSystemTests/FailedRecordingStoreTests.swift

- R · realRecoveryCopyAuthenticatesAndPreservesOriginal (line 11): authenticated copy is created while the original survives.
- R · filesystemRecoveryFailurePreservesOriginalOnBothCancellationPaths (line 28): failed copy preserves original on both cancellation paths.
- R · filenamePolicy (line 72): only generated audio names qualify for recovery.
- R · readsRegularFile (line 80): authenticated read is limited to a regular bounded file.
- R · rejectsSymlink (line 88): secure read rejects symbolic links.
- R · rejectsWrongTypeAndSize (line 98): secure read rejects directories and oversized files.
- R · authenticationBindsPayload (line 108): authentication covers both filename and exact audio bytes.
- R · deletionIsSingleEntryOnly (line 124): deletion does not follow links or recurse.
- R · prunesLegacyAndOrphans (line 138): pruning handles legacy and unverifiable files without a Keychain key.
- R · protectedAudioKeepsAuthentication (line 164): pruning keeps the authentication sidecar for protected audio.

### Recovery, authentication, and retention · OpenDictateSystemTests/RecoveryExpiryTests.swift

- R · exactExpiryAndFallbackToNextValidCandidate (line 10): expiry is enforced at the exact boundary and selection falls back.
- R · pruningOnlyRemovesSidecarsForAbsentAudio (line 31): pruning never removes a sidecar while its audio remains.

### Recovery, authentication, and retention · OpenDictateCoreTests/RecordingRetentionTests.swift

- R · underLimit (line 20): no item is pruned within the limit.
- R · orderIndependent (line 25): ordering inputs does not change age/count retention decisions.
- R · newestWins (line 33): newest valid recording is selected.
- R · stableOnTies (line 39): equal timestamps use a deterministic filename tie-break.
- R · expiresByAge (line 49): an item expires at the configured age boundary.
- R · combinesAgeAndCount (line 56): age/count pruning combines without duplicate results.

### Recovery, authentication, and retention · OpenDictateSystemTests/KeychainAPIKeyStoreTests.swift

- R · migratingLegacyCreatesTheReplacementBeforeDeletingTheOldItem (line 15): migration creates canonical credential before removing legacy data.
- R · failedCreationLeavesTheLegacyCredentialUntouched (line 25): failed canonical create preserves legacy credential.
- R · failedUpdatePreservesBothExistingCredentials (line 36): failed update preserves existing items.
- R · existingCanonicalCredentialIsUpdatedWithoutRecreatingItsACL (line 45): update preserves the established access control list.
- R · failedLegacyCleanupReportsThatTheReplacementWasSaved (line 54): migration reports save success even if legacy cleanup fails.
- R · aCompetingCreateIsNotOverwrittenOrDeleted (line 67): a concurrent create is not overwritten or deleted.
- R · onlyConfirmedCanonicalAbsenceAllowsTheLegacyRead (line 77): uncertain lookup never falls through to legacy credential.
- R · emptyOrMalformedCanonicalDataDoesNotUseAnOlderCredential (line 90): corrupt current data does not silently use stale credentials.
- R · setupRequiresConfirmedAbsenceOfBothAccountsWithoutReadingSecrets (line 98): setup requires confirmed absence without reading the secret.
- R · readDistinguishesAbsenceAccessFailureAndInvalidResultData (line 136): absence, ACL denial, and malformed result are distinct.
- R · writesKeepTheAccountAndOnlyUpdateTheData (line 150): update addresses the expected account and mutates only data.

### Operational logging and opt-in checks · OpenDictateSystemTests/LogWriterTests.swift

- R · rotatesAndPreservesCompleteRecords (line 8): rotation is bounded and preserves complete log records.

### Operational logging and opt-in checks · OpenDictateSystemTests/LiveTranscriptionTests.swift

- R · syntheticReference (line 11): explicit live-provider integration remains opt-in; its fixture and request contract are documented separately.

### Operational logging and opt-in checks · OpenDictateSystemTests/ResourceBenchmarkTests.swift

- R · recoveryPruning (line 10): explicit recovery-pruning resource benchmark remains opt-in.

## D candidate evidence

These notes supplement the inventory. Each D row names the exact lost assertion,
the stronger surviving check or the fact that no equivalent remains, the
production path, relevant history, helper effect, risk, and focused command.
A focused command is a repeatable check after the change; no command was run
from this worktree before the register commit.

### D1 · AudioLevelsTests and SpeechRangeAccumulatorTests

Source: Tests/OpenDictateCoreTests/AudioLevelsTests.swift lines 9, 14, 21,
31, 46, and 73. Production caller: AudioPreprocessor.analyze uses
AudioLevels.decibels and SpeechRangeAccumulator for each analyzed window.
History: the declarations date to e052c0d, when OpenDictateCore and its tests
were introduced. The candidates assert the exact zero-count floor, all-zero
finite floor, quiet-below-threshold value, full-scale 0 dBFS, all-silent nil
range, and one-window range. The remaining silent/quiet WAV pipeline test
uses the production analysis path; thresholdIsInclusive retains an exact
threshold boundary. It does not preserve every numeric helper assertion.
spansFirstToLast remains because the broad pipeline fixture does not protect
speech on both sides of a pause. No production helper is made unused and no
test-only helper is removed. Risk: regressions in helper boundary values can
escape until the synthetic WAV path or an installed-app recording exposes
them. Check with swift test --filter 'AudioLevelsTests|AudioPipelineTests'.

### D2 · TrimPlannerTests

Source: Tests/OpenDictateCoreTests/TrimPlannerTests.swift lines 33 and 48.
Production caller: AudioPreprocessor.plan calls TrimPlanner.plan before AAC
export. History: both declarations date to e052c0d. neverNegativeStart asserts
the lower clamp at recording start; shorterThanPadding asserts a sane plan
when duration is below padding. padsBothSides remains to protect both padding
margins for interior speech, clampsToEnd protects the upper bound, and
errorCarriesDurations protects the too-short error contract. None proves the
lower clamp or the short-source plan exactly. The pipeline fixture exercises
actual synthetic analysis/export but checks broad duration and playability.
No production helper becomes unused. Risk: altered start clamping or short
recording arithmetic could create an invalid export range. Check with
swift test --filter TrimPlannerTests.

### D3 · SettingsTests

Source: Tests/OpenDictateCoreTests/SettingsTests.swift lines 44, 59, 72,
86, 129, and 138. Production callers: Config exposes settings to AppDelegate,
MenuBarController and OpenAITranscriber; the app reads model/language/shortcut
preferences in the corresponding flows. History: these cases were introduced
with the live settings and hotkey presets in 747669f. modelFromEnvironment
loses the direct initial environment-source assertion; resetToEnvironment
still verifies that reset returns control to environment values. emptyEnvironmentIgnored
loses the exact blank-model fallback edge. languageFromEnvironment loses its
direct simple getter assertion; resetToEnvironment covers environment
precedence after reset. shortcutRoundTrip loses the Settings-level valid
shortcut write/read check; UserDefaultsStoreTests only checks the generic
adapter, while unknownStoredShortcutFallsBack and partialStoredShortcutFallsBack
cover invalid persisted forms. environmentOnlyValues loses prompt pass-through
and empty-means-unset assertions; no remaining test asserts that prompt
configuration. presetsAreDistinct loses unique key/modifier pairs for all
offered presets; HotKeyTransactionTests protects replacement rollback, not
preset uniqueness. The presets themselves are consumed by MenuBarController
and Settings. No production helper becomes unused; SettingsTests helpers are
still used by retained cases. Risk: environment edges, valid preference
round-trip, prompt handling, or duplicate menu presets can regress without a
focused failure. Check with swift test --filter SettingsTests.

### D4 · TranscriptionModelTests.uploadModelsAccepted

Source: Tests/OpenDictateCoreTests/TranscriptionModelTests.swift line 24.
Production caller: OpenAITranscriber rejects models marked realtime-only;
MenuBarController offers the current upload choices. History: introduced with
OpenDictateCore tests in e052c0d. One parameterized declaration accepts four
named upload models. realtimeModelRejected, unknownModelIsAllowed and the
request tests for the two language-sensitive models remain, but they do not
assert that all four named identifiers are accepted. No production or
test-only helper is removed. Risk: a supported identifier can be rejected by
the upload policy without this exact regression being caught. Check with
swift test --filter TranscriptionModelTests.

### D5 · OpenAIAPIErrorTests

Source: Tests/OpenDictateCoreTests/OpenAIAPIErrorTests.swift lines 13, 39,
45, and 60. Production caller: OpenAITranscriber maps provider HTTP errors to
the user-facing status. History: these cases date to e052c0d. invalidKey
asserts the 401-specific API-key guidance; malformedBody checks 413 fallback
when provider JSON is invalid; emptyBody checks a server-error fallback;
unknownCodeWithoutMessage checks the unknown-code fallback without a message.
The retained quota/rate-limit cases preserve their distinct wording;
unknownCodeHidesServerMessage preserves the no-provider-text safety boundary;
fallsBackToType preserves missing-code handling. No retained test checks the
exact 401, malformed-413, or empty-5xx wording. The unknown-code/no-message
case shares the same fallback branch as the retained unknown-code case; the
decoded message is not used for display. No helper becomes unused. Risk:
those normal error messages can change or fall back incorrectly without a
focused assertion. Check with swift test --filter OpenAIAPIErrorTests.

### D6 · FormattingTests.tooShortMessage and noSpeechMessage

Source: Tests/OpenDictateCoreTests/FormattingTests.swift lines 18 and 25.
Production caller: DictationFlow turns OpenDictateError into the German status
shown by the panel and menu. History: both cases date to e052c0d. tooShortMessage
checks the formatted actual/minimum durations; errorCarriesDurations retains
the underlying typed values but does not assert the localized string.
noSpeechMessage checks microphone guidance without raw measurements; the audio
pipeline tests exercise no-speech classification, not this user-facing text.
frameworkMessage retains the safe-framework-error style boundary. No formatting
helper becomes unused and no other assertion preserves these exact messages.
Risk: the user can receive less actionable or overly revealing status text.
Check with swift test --filter FormattingTests.

### D7 · AppLifecycleTests

Source: Tests/OpenDictateSystemTests/AppLifecycleTests.swift lines 98, 157,
and 199. Production callers: AppDelegate uses beginOperation, isCurrent and
commit around asynchronous microphone, retry, setup and menu flows. History:
the first two declarations were renamed in ae55a1d; setupModalCannot... dates
to 23cae39. activeOperationRejectsRepeatedNestedBegins directly checks a
second begin returns nil. cancelledOperationIsRejectedByQueuedCurrentnessCheck
checks a stale queued token. setupModalCannotAdmitAHotkeyOrSaveAfterNestedQuit
increments a test-owned fake save counter inside lifecycle.commit; it does not
invoke the real AppDelegate Keychain-save closure. The remaining lifecycle
tests exercise stale callbacks, repeated/reentrant quit, drain ordering and
retry invalidation. In particular, quitDuringPreparationRejectsLateSuccessAndErrorCallbacks
retains token invalidation, but no remaining test asserts this exact nested
setup fake-save scenario. The AppDelegate source checks remain unchanged.
No production helper is removed. Risk: a generic begin/currentness regression
may have less direct detection; the most dramatic setup test name implies
stronger real-Keychain evidence than its fake callback proves. The successful
Build 7 installed TextEdit path in
docs/release-plans/evidence/2026-09-24-keychain-and-plan1.md covers normal
setup and insertion only, not nested quit. DictationPanel.swift is unchanged
between c92cbc9 and this base commit. Check with swift test --filter AppLifecycleTests.

### D8 · DictationFlowTests.automaticInsertionReceivesTheExactTrimmedTranscript

Source: Tests/OpenDictateSystemTests/DictationFlowTests.swift line 181.
Production callers: AppDelegate.makeFlow supplies OpenAITranscriber and the
inserter to DictationFlow.deliver. History: added in 8fcd480 during credential
and text-delivery hardening. The fake transcriber returns surrounding
whitespace and the test checks that insertion receives the trimmed text.
OpenAITranscriber also trims decoded provider text, and the insertion/status
tests retain evidence handling, but no remaining test checks DictationFlow's
own trim when a different Transcriber implementation supplies text. No helper
becomes unused. Risk: whitespace could reach the insertion boundary if the
flow contract changes or another transcriber is supplied. Check with
swift test --filter 'DictationFlowTests|TranscriptionRequestTests'.

### D9 · APIKeySetupTests

Source: Tests/OpenDictateSystemTests/APIKeySetupTests.swift lines 50 and 73.
Production path: AppDelegate routes setup and save actions through the panel
and DictationFlow state. History: both declarations were introduced with
direct API-key setup in 54dfb25. setupActionAndSavingDoNotStartARecording
checks that setup/save does not begin recording and that the ready-state
record action still works after setup. cancelledOrFailedSetupKeepsItsActionAvailable
checks action availability after a cancelled or failed attempt. The retained
setupRefreshCannotReplaceAnActiveRecording covers interaction with active
state. DictationPanelTests.setupUpdatesKeepTheirActionAvailableWithoutOpeningOrRecording
retains the no-recording/setup-action check while setup is visible. The
post-success ready-state click has no equivalent automated assertion after
removal; it has historical Build 7 installed TextEdit evidence in
docs/release-plans/evidence/2026-09-24-keychain-and-plan1.md, under
Build7 echterTextEditEinfügeweg. That report is a past candidate's evidence,
not a new run. The source diff for DictationPanel.swift from c92cbc9 to the
base is empty. cancelledOrFailedSetupKeepsItsActionAvailable overlaps the
panel action-availability path, but no remaining test clicks again after an
error callback. No production helper becomes unused. Risk: a setup action can
disappear after a failure, or a ready action can fail to start the expected
recording, without an exact automated check. Check with
swift test --filter 'APIKeySetupTests|DictationPanelTests'.

### D10 · AudioPipelineTests.shortDetectedSpanDoesNotPretendThereWasNoAudio

Source: Tests/OpenDictateSystemTests/AudioPipelineTests.swift line 61.
Production caller: AudioPreprocessor.analyze uses a nil speech range to
classify a recording as no speech. History: introduced in 536cf3f during
dictation reliability and recovery work. The test uses a short synthetic tone
and asserts that a positive short span is still detected. The retained pipeline
tests cover silence, quiet audio, a longer continuous speech segment, and
playable export, but none asserts detection for a short segment. DictationFlow
tests use predetermined audio results and do not exercise threshold analysis.
No fixture helper becomes unused because the other audio tests use it. Risk:
very short speech can be mistaken for silence and withheld from transcription.
Check with swift test --filter AudioPipelineTests.

## Ownership, cut effects, and open limits

Primary responsibility is assigned by production behavior, not test filename:
Core audio analysis/planning and the synthetic audio pipeline belong to Audio
Preprocessing; settings, shortcuts, model choice and request/transport/error
mapping belong to Configuration and Transcription; AppLifecycle and DictationFlow
belong to App Lifecycle and Delivery; panel rendering and API-key setup belong
to User-facing Setup; recovery store, expiry, retention and Keychain belong to
Recovery and Credential Storage; logging and explicit benchmarks/live calls
belong to Operational Checks. The scenario notes above divide DictationFlow
and error formatting at their actual contracts. Every Swift test file and
declaration is listed exactly once.

The retained recovery, credential, clipboard-target, transactional hotkey,
cancellation, failed-delivery and quit/drain cases are deliberate. None is
removed to meet the quota. Their remaining production paths are unchanged.
The candidate removals delete assertions, not production code. The only
possible helper cleanup is in test source; inspect the final patch for any
helper left with no caller. No empty test suite is intended.

This is an inventory and evidence assessment, not an installed-app acceptance
claim. It does not prove microphone quality, Keychain ACL behavior, target
field delivery or VoiceOver. The app-level release evidence cited above applies
only to its recorded candidate and flow. A separate critic reviewed the
corrected selection and reported no further material safety or data-integrity
finding; that review outcome was relayed by the main task and is not an attached
review artifact here. The corrected coverage result remains pending in the main
checkout.
