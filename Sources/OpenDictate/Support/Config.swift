import Foundation

enum Config {
    static let model = ProcessInfo.processInfo.environment["OPENAI_TRANSCRIBE_MODEL"] ?? "gpt-transcribe"
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
