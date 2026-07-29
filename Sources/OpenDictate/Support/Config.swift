import Foundation
import OpenDictateCore

enum Config {
    static let model: TranscriptionModel = {
        guard let raw = ProcessInfo.processInfo.environment["OPENAI_TRANSCRIBE_MODEL"], !raw.isEmpty else {
            return .default
        }
        return TranscriptionModel(rawValue: raw)
    }()

    static let language = ProcessInfo.processInfo.environment["OPENAI_TRANSCRIBE_LANGUAGE"]
    static let prompt = ProcessInfo.processInfo.environment["OPENAI_TRANSCRIBE_PROMPT"]
    static let minimumRecordingDuration: TimeInterval = 1.0
    static let maximumRecordingDuration: TimeInterval = 90.0
    static let silenceThresholdDb: Float = -45.0
    static let silencePadding: TimeInterval = 0.25
    static var apiKey: String? {
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? KeychainAPIKeyStore.read()
    }
}
