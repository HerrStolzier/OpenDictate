import Foundation
import OpenDictateCore
import Testing

@testable import OpenDictate

@Suite("Dictation lifecycle and recovery")
@MainActor
struct DictationFlowTests {
    @MainActor
    final class Harness {
        var starts = 0
        var stops = 0
        var uploads = 0
        var pasted = 0
        var pastedText: String?
        var pasteResult: InsertionSubmission = .submitted
        var pasteOverride: (@MainActor (String) async -> InsertionSubmission)?
        var copiedTexts: [String] = []
        var afterCopy: (() -> Void)?
        var copySucceeds = true
        var keepSucceeds = true
        var text = "dictated text"
        var preparationFails = false
        var stopFails = false
        var uploadFails = false
        var suspendUpload = false
        var kept: [URL] = []
        var cleaned: [URL] = []
        var removed = 0
        let original = URL(fileURLWithPath: "/test/original.m4a")
        let trimmed = URL(fileURLWithPath: "/test/trimmed.m4a")
        lazy var flow = makeFlow()
        func makeFlow() -> DictationFlow {
            DictationFlow(
                operations: .init(
                    start: { self.starts += 1 },
                    stop: {
                        self.stops += 1
                        if self.stopFails { throw OpenDictateError.recordingCouldNotStart }
                        return self.original
                    },
                    prepare: { _ in
                        if self.preparationFails { throw OpenDictateError.noSpeechDetected(peakDb: -60) }
                        return PreparedAudio(url: self.trimmed, uploadDuration: 2)
                    },
                    transcribeFile: { _ in
                        self.uploads += 1
                        if self.uploadFails { throw URLError(.cannotConnectToHost) }
                        if self.suspendUpload { try await Task.sleep(for: .seconds(3600)) }
                        return self.text
                    },
                    transcribeRetry: { _ in
                        self.uploads += 1
                        return self.text
                    },
                    keep: {
                        self.kept.append($0)
                        return self.keepSucceeds
                    },
                    removeRetry: { _ in self.removed += 1 },
                    clean: { self.cleaned.append($0) },
                    copy: {
                        guard self.copySucceeds else { return false }
                        self.copiedTexts.append($0)
                        self.afterCopy?()
                        return true
                    },
                    paste: { text in
                        self.pasted += 1
                        self.pastedText = text
                        if let pasteOverride = self.pasteOverride { return await pasteOverride(text) }
                        return self.pasteResult
                    }
                ))
        }
        var payload: FailedRecordingStore.RetryPayload {
            .init(url: original, data: Data([1]))
        }

        func waitForUploadToStart() async throws -> Bool {
            for _ in 0..<1_000 {
                if uploads > 0 { return true }
                try await Task.sleep(for: .milliseconds(1))
            }
            return false
        }
    }

    @Test func retryCannotOverlapRecordingOrDisableStop() async throws {
        let h = Harness()
        #expect(try h.flow.start())
        #expect(!h.flow.retry(h.payload))
        #expect(h.flow.state == .recording)
        #expect(h.flow.stop())
        #expect(!h.flow.stop())
        await h.flow.task?.value
        #expect(h.stops == 1 && h.uploads == 1)
        #expect(h.flow.state == .idle)
    }

    @Test func emptyRetryKeepsAudio() async {
        let h = Harness()
        h.text = " \n"
        #expect(h.flow.retry(h.payload))
        await h.flow.task?.value
        #expect(h.removed == 0 && h.pasted == 0)
    }

    @Test func recorderStopFailureReportsAnErrorWithoutUploading() throws {
        let h = Harness()
        h.stopFails = true
        var outcomes: [DictationOutcome] = []
        var status = ""
        h.flow.onOutcome = { outcomes.append($0) }
        h.flow.onStatus = { status = $0 }

        #expect(try h.flow.start())
        #expect(h.flow.stop())
        #expect(h.flow.state == .idle)
        #expect(outcomes == [.failed])
        #expect(status.hasPrefix("Aufnahmefehler:"))
        #expect(h.uploads == 0 && h.pasted == 0 && h.cleaned.isEmpty)
    }

    @Test func providerFailurePreservesOriginalForManualRetry() async throws {
        let h = Harness()
        h.uploadFails = true
        var outcomes: [DictationOutcome] = []
        h.flow.onOutcome = { outcomes.append($0) }

        #expect(try h.flow.start())
        #expect(h.flow.stop())
        await h.flow.task?.value
        #expect(h.uploads == 1 && h.pasted == 0)
        #expect(h.kept == [h.original])
        #expect(Set(h.cleaned) == Set([h.original, h.trimmed]))
        #expect(outcomes == [.failed])
    }

    @Test func clipboardFailureKeepsAudioAndText() async {
        let h = Harness()
        h.copySucceeds = false
        #expect(h.flow.retry(h.payload))
        await h.flow.task?.value
        #expect(h.removed == 0 && h.pasted == 0)
        #expect(h.flow.lastTranscript == h.text)
        h.copySucceeds = true
        #expect(h.flow.copyLastTranscript())
        #expect(h.uploads == 1)
    }

    @Test func successfulRetryCopiesWithoutPastingAndRemovesItsSource() async {
        let h = Harness()
        #expect(h.flow.retry(h.payload))
        await h.flow.task?.value
        #expect(h.removed == 1 && h.pasted == 0)
    }

    @Test func sentPasteIsReportedAsUnconfirmed() async throws {
        let h = Harness()
        var outcomes: [DictationOutcome] = []
        h.flow.onOutcome = { outcomes.append($0) }
        _ = try h.flow.start()
        _ = h.flow.stop()
        await h.flow.task?.value
        #expect(outcomes == [.deliveryUnconfirmed])
        #expect(h.pasted == 1)
    }

    @Test func retryProvidesManualTextInsteadOfAnUnconfirmedPaste() async {
        let h = Harness()
        var outcomes: [DictationOutcome] = []
        h.flow.onOutcome = { outcomes.append($0) }
        _ = h.flow.retry(h.payload)
        await h.flow.task?.value
        #expect(outcomes == [.textAvailable])
        #expect(h.pasted == 0 && h.flow.lastTranscript == h.text)
    }

    @Test func failedRecoveryCannotAdvertiseSuccess() async throws {
        let h = Harness()
        h.preparationFails = true
        h.keepSucceeds = false
        var outcomes: [DictationOutcome] = []
        h.flow.onOutcome = { outcomes.append($0) }
        _ = try h.flow.start()
        _ = h.flow.stop()
        await h.flow.task?.value
        #expect(outcomes == [.failed])
        #expect(h.cleaned.isEmpty)
    }

    @Test func automaticInsertionReceivesTheExactTrimmedTranscript() async throws {
        let h = Harness()
        h.text = "  dictated text\n"
        _ = try h.flow.start()
        _ = h.flow.stop()
        await h.flow.task?.value
        #expect(h.pastedText == "dictated text")
    }

    @Test func skippedAudioIsKeptWithoutUpload() async throws {
        let h = Harness()
        h.preparationFails = true
        _ = try h.flow.start()
        _ = h.flow.stop()
        await h.flow.task?.value
        #expect(h.uploads == 0)
        #expect(h.kept == [h.original])
        #expect(h.cleaned == [h.original])
    }

    @Test func failedPersistenceNeverDeletesOnlyOriginal() async throws {
        let h = Harness()
        h.preparationFails = true
        h.keepSucceeds = false
        _ = try h.flow.start()
        _ = h.flow.stop()
        await h.flow.task?.value
        #expect(h.cleaned.isEmpty)
    }

    @Test func failedDeliveryKeepsOriginalNotTrimmedAudio() async throws {
        let h = Harness()
        h.copySucceeds = false
        _ = try h.flow.start()
        _ = h.flow.stop()
        await h.flow.task?.value
        #expect(h.kept == [h.original])
        #expect(Set(h.cleaned) == Set([h.original, h.trimmed]))
    }

    @Test func cancelBeforeProcessingPreservesAudio() async throws {
        let h = Harness()
        _ = try h.flow.start()
        _ = h.flow.stop()
        h.flow.cancel()
        await h.flow.task?.value
        #expect(h.uploads == 0)
        #expect(h.kept == [h.original])
        #expect(h.flow.state == .idle)
    }

    @Test func cancellationDuringUploadPreservesOriginalAndCleansTemporaryAudio() async throws {
        let h = Harness()
        h.suspendUpload = true
        var outcomes: [DictationOutcome] = []
        h.flow.onOutcome = { outcomes.append($0) }
        _ = try h.flow.start()
        _ = h.flow.stop()
        #expect(try await h.waitForUploadToStart())

        h.flow.cancel()
        await h.flow.task?.value

        #expect(h.kept == [h.original])
        #expect(Set(h.cleaned) == Set([h.original, h.trimmed]))
        #expect(outcomes == [.cancelled])
        #expect(h.flow.state == .idle)
    }

    @Test func failedRecoveryDuringUploadCancellationKeepsOnlyOriginal() async throws {
        let h = Harness()
        h.suspendUpload = true
        h.keepSucceeds = false
        var outcomes: [DictationOutcome] = []
        h.flow.onOutcome = { outcomes.append($0) }
        _ = try h.flow.start()
        _ = h.flow.stop()
        #expect(try await h.waitForUploadToStart())

        h.flow.cancel()
        await h.flow.task?.value

        #expect(h.kept == [h.original])
        #expect(h.cleaned == [h.trimmed])
        #expect(outcomes == [.failed])
        #expect(h.flow.state == .idle)
    }

    @Test func explicitDiscardDuringUploadDeletesOriginalWithoutRecoveryCopy() async throws {
        let h = Harness()
        h.suspendUpload = true
        _ = try h.flow.start()
        _ = h.flow.stop()
        #expect(try await h.waitForUploadToStart())

        h.flow.cancel(discardRecording: true)
        await h.flow.task?.value

        #expect(h.kept.isEmpty)
        #expect(Set(h.cleaned) == Set([h.original, h.trimmed]))
        #expect(h.flow.state == .idle)
    }

    @Test func explicitDiscardDoesNotUploadOrKeep() async throws {
        let h = Harness()
        _ = try h.flow.start()
        h.flow.cancel(discardRecording: true)
        #expect(h.kept.isEmpty && h.uploads == 0)
        #expect(h.cleaned == [h.original])
    }

    @Test func cancelledRetryDoesNotUpload() async {
        let h = Harness()
        _ = h.flow.retry(h.payload)
        h.flow.cancel()
        await h.flow.task?.value
        #expect(h.uploads == 0 && h.removed == 0)
        #expect(h.flow.state == .idle)
    }

    @Test func secondStartIsRejectedDuringProcessing() async throws {
        let h = Harness()
        _ = try h.flow.start()
        _ = h.flow.stop()
        #expect(try !h.flow.start())
        #expect(!h.flow.retry(h.payload))
        await h.flow.task?.value
        #expect(h.starts == 1)
    }

    @Test func insertionEvidenceReachesStatusWithoutChangingClipboardRecoveryPolicy() async throws {
        let cases: [(InsertionSubmission, DictationOutcome, String)] = [
            (.notAttempted, .textAvailable, "nicht automatisch eingefügt"),
            (.submitted, .deliveryUnconfirmed, "Einfügebefehl gesendet"),
            (.uncertain, .deliveryUncertain, "Einfügeversuch unbestätigt")
        ]
        for (submission, outcome, status) in cases {
            let h = Harness()
            h.pasteResult = submission
            var outcomes: [DictationOutcome] = []
            var statuses: [String] = []
            h.flow.onOutcome = { outcomes.append($0) }
            h.flow.onStatus = { statuses.append($0) }
            _ = try h.flow.start()
            _ = h.flow.stop()
            await h.flow.task?.value

            #expect(outcomes == [outcome])
            #expect(statuses.last?.contains(status) == true)
            #expect(h.copiedTexts == [h.text])
            #expect(h.flow.lastTranscript == h.text)
            #expect(h.kept.isEmpty)
            #expect(Set(h.cleaned) == Set([h.original, h.trimmed]))
            #expect(h.pasted == 1)
            #expect(h.flow.copyLastTranscript())
            #expect(h.copiedTexts == [h.text, h.text])
        }
    }

    @Test func cancellationAfterCopyBeforeInsertionLeavesTextAvailable() async throws {
        let h = Harness()
        var outcomes: [DictationOutcome] = []
        var statuses: [String] = []
        h.afterCopy = { h.flow.cancel() }
        h.flow.onOutcome = { outcomes.append($0) }
        h.flow.onStatus = { statuses.append($0) }
        _ = try h.flow.start()
        _ = h.flow.stop()
        await h.flow.task?.value

        #expect(h.pasted == 0)
        #expect(outcomes == [.textAvailable])
        #expect(statuses.last == "Text kopiert – automatisches Einfügen abgebrochen")
        #expect(h.copiedTexts == [h.text])
        #expect(h.flow.lastTranscript == h.text)
        #expect(h.kept.isEmpty)
        #expect(Set(h.cleaned) == Set([h.original, h.trimmed]))
        #expect(h.flow.state == .idle)
    }

}
