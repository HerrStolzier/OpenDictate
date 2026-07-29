import Foundation

/// A transcription model identifier. Free-form on purpose: `OPENAI_TRANSCRIBE_MODEL`
/// must keep working for models this build has never heard of. The known list only
/// exists so the app can warn about the one mistake that is easy to make, picking a
/// realtime-only model for the upload flow.
public struct TranscriptionModel: RawRepresentable, Sendable, Equatable, Hashable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Accuracy-focused async model. Default since 2026-07-29.
    public static let gptTranscribe = TranscriptionModel(rawValue: "gpt-transcribe")
    /// Cheapest option, lower accuracy on accents, numbers and noise.
    public static let gpt4oMiniTranscribe = TranscriptionModel(rawValue: "gpt-4o-mini-transcribe")
    public static let gpt4oTranscribe = TranscriptionModel(rawValue: "gpt-4o-transcribe")
    public static let whisper1 = TranscriptionModel(rawValue: "whisper-1")
    /// Low-latency streaming model. Needs the realtime endpoint, not this app's flow.
    public static let gptLiveTranscribe = TranscriptionModel(rawValue: "gpt-live-transcribe")

    public static let `default` = TranscriptionModel.gptTranscribe

    /// Models that will not work against `POST /v1/audio/transcriptions`.
    public static let realtimeOnly: Set<TranscriptionModel> = [.gptLiveTranscribe]

    /// False only for models this build knows are realtime-only. Unknown
    /// identifiers are assumed usable so new models need no code change.
    public var isUsableForUpload: Bool {
        !Self.realtimeOnly.contains(self)
    }

    /// USD per minute of audio, for the models this build knows about.
    public var pricePerMinuteUSD: Double? {
        switch self {
        case .gptTranscribe: return 0.0045
        case .gpt4oMiniTranscribe: return 0.003
        case .gpt4oTranscribe: return 0.006
        case .whisper1: return 0.006
        case .gptLiveTranscribe: return 0.017
        default: return nil
        }
    }

    /// Reason this model cannot be used for the record-then-upload flow, or nil.
    public var uploadRejectionReason: String? {
        guard !isUsableForUpload else { return nil }
        return """
        \(rawValue) is a realtime model. It is served from the realtime transcription \
        endpoint, not from /v1/audio/transcriptions, so OpenDictate cannot use it. \
        Unset OPENAI_TRANSCRIBE_MODEL to fall back to \(Self.default.rawValue).
        """
    }
}
