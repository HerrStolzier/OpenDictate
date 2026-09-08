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
        var copySucceeds = true
        var keepSucceeds = true
        var text = "dictated text"
        var preparationFails = false
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
                        return self.original
                    },
                    prepare: { _ in
                        if self.preparationFails { throw OpenDictateError.noSpeechDetected(peakDb: -60) }
                        return PreparedAudio(url: self.trimmed, uploadDuration: 2)
                    },
                    transcribeFile: { _ in
                        self.uploads += 1
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
                    copy: { _ in self.copySucceeds },
                    paste: {
                        self.pasted += 1
                        self.pastedText = $0
                        return true
                    }
                ))
        }
        var payload: FailedRecordingStore.RetryPayload {
            .init(url: original, data: Data([1]))
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

    @Test func successfulRetryRemovesItsSource() async {
        let h = Harness()
        #expect(h.flow.retry(h.payload))
        await h.flow.task?.value
        #expect(h.removed == 1 && h.pasted == 1)
        #expect(h.pastedText == h.text)
    }

    @Test func automaticInsertionReceivesTheExactTrimmedTranscript() async {
        let h = Harness()
        h.text = "  dictated text\n"
        #expect(h.flow.retry(h.payload))
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
}
