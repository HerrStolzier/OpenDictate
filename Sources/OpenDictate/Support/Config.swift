import Foundation
import OpenDictateCore

/// App-wide access to the live settings plus the fixed recording limits.
/// Everything that can change at runtime is a computed property, so a menu
/// change takes effect on the next dictation without a restart.
enum Config {
    static let settings = Settings(
        store: UserDefaults.standard,
        environment: ProcessInfo.processInfo.environment
    )

    static var model: TranscriptionModel { settings.model }
    static var language: String? { settings.language }
    static var prompt: String? { settings.prompt }
    static var shortcut: HotKeyShortcut { settings.shortcut }

    static let minimumRecordingDuration: TimeInterval = 1.0
    static let maximumRecordingDuration: TimeInterval = 90.0
    static let silenceThresholdDb: Float = -45.0
    static let silencePadding: TimeInterval = 0.25

    static var apiKey: String? {
        settings.apiKeyFromEnvironment ?? KeychainAPIKeyStore.read()
    }
}
