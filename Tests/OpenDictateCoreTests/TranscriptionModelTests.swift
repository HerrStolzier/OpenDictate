import Foundation
import Testing

@testable import OpenDictateCore

@Suite("Transcription model")
struct TranscriptionModelTests {
    @Test("The realtime model is rejected for the upload flow")
    func realtimeModelRejected() {
        #expect(!TranscriptionModel.gptLiveTranscribe.isUsableForUpload)
        let reason = TranscriptionModel.gptLiveTranscribe.uploadRejectionReason
        #expect(reason?.contains("Echtzeitmodell") == true)
        #expect(reason?.contains("gpt-transcribe") == true)
    }

    @Test("An unknown identifier is passed through, so new models need no release")
    func unknownModelIsAllowed() {
        let future = TranscriptionModel(rawValue: "gpt-transcribe-2")
        #expect(future.isUsableForUpload)
        #expect(future.uploadRejectionReason == nil)
        #expect(future.pricePerMinuteUSD == nil)
    }

    @Test("A malformed name is rejected without repeating it, like on the iPhone")
    func malformedNameRejected() {
        for name in ["", "gpt transcribe", "gpt-transcribe\r\nX-Injected: 1", "a\"b", "../model", "modell-ä"] {
            let model = TranscriptionModel(rawValue: name)
            #expect(!model.isUsableForUpload)
            let reason = model.uploadRejectionReason
            #expect(reason?.contains("ungültig") == true)
            #expect(reason?.contains("gpt-transcribe") == true)
            if !name.isEmpty { #expect(reason?.contains(name) == false) }
        }
        for name in ["Systran/faster-whisper-small", "llama3:8b", "whisper-1"] {
            #expect(TranscriptionModel(rawValue: name).isUsableForUpload)
        }
    }

    @Test("Only the token-billed mini model shows an approximate price")
    func miniModelPriceIsApproximate() {
        #expect(TranscriptionModel.gpt4oMiniTranscribe.isPriceApproximate)
        #expect(!TranscriptionModel.gptTranscribe.isPriceApproximate)
    }

}
