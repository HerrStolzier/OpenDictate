import Foundation
import Testing

@testable import OpenDictateCore

@Suite("Transcription model")
struct TranscriptionModelTests {
    @Test("The default is the accuracy-focused async model")
    func defaultModel() {
        #expect(TranscriptionModel.default == .gptTranscribe)
        #expect(TranscriptionModel.default.rawValue == "gpt-transcribe")
    }

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

    @Test("Known prices match OpenAI's published per-minute rates")
    func prices() {
        #expect(TranscriptionModel.gptTranscribe.pricePerMinuteUSD == 0.0045)
        #expect(TranscriptionModel.gpt4oMiniTranscribe.pricePerMinuteUSD == 0.003)
        #expect(TranscriptionModel.gptLiveTranscribe.pricePerMinuteUSD == 0.017)
    }
}
