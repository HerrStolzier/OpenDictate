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

    @Test(
        "Upload models are accepted and carry no rejection reason",
        arguments: [
            TranscriptionModel.gptTranscribe,
            .gpt4oMiniTranscribe,
            .gpt4oTranscribe,
            .whisper1
        ])
    func uploadModelsAccepted(model: TranscriptionModel) {
        #expect(model.isUsableForUpload)
        #expect(model.uploadRejectionReason == nil)
    }

    @Test("An unknown identifier is passed through, so new models need no release")
    func unknownModelIsAllowed() {
        let future = TranscriptionModel(rawValue: "gpt-transcribe-2")
        #expect(future.isUsableForUpload)
        #expect(future.uploadRejectionReason == nil)
        #expect(future.pricePerMinuteUSD == nil)
    }

}
