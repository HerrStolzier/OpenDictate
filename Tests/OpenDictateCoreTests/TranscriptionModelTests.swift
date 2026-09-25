import Foundation
import Testing

@testable import OpenDictateCore

@Suite("Transcription model")
struct TranscriptionModelTests {
    @Test("The realtime model is rejected for the upload flow")
    func realtimeModelRejected() {
        #expect(!TranscriptionModel.gptLiveTranscribe.isUsableForUpload)
        let reason = TranscriptionModel.gptLiveTranscribe.uploadRejectionReason
        #expect(reason?.contains("realtime") == true)
        #expect(reason?.contains("gpt-transcribe") == true)
    }

    @Test("An unknown identifier is passed through, so new models need no release")
    func unknownModelIsAllowed() {
        let future = TranscriptionModel(rawValue: "gpt-transcribe-2")
        #expect(future.isUsableForUpload)
        #expect(future.uploadRejectionReason == nil)
        #expect(future.pricePerMinuteUSD == nil)
    }

}
