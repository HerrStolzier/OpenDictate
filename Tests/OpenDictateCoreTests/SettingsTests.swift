import Foundation
import Testing

@testable import OpenDictateCore

/// Stand-in for UserDefaults. Locked because `KeyValueStore` is Sendable, not
/// because the tests are concurrent.
private final class MemoryStore: KeyValueStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Any] = [:]

    init(_ initial: [String: Any] = [:]) {
        values = initial
    }

    func object(forKey defaultName: String) -> Any? {
        lock.lock()
        defer { lock.unlock() }
        return values[defaultName]
    }

    func set(_ value: Any?, forKey defaultName: String) {
        lock.lock()
        defer { lock.unlock() }
        values[defaultName] = value
    }

    func removeObject(forKey defaultName: String) {
        lock.lock()
        defer { lock.unlock() }
        values.removeValue(forKey: defaultName)
    }
}

@Suite("Settings")
struct SettingsTests {
    private func settings(stored: [String: Any] = [:], env: [String: String] = [:]) -> Settings {
        Settings(store: MemoryStore(stored), environment: env)
    }

    // MARK: - Model

    @Test("A menu choice beats the environment variable")
    func storedModelWinsOverEnvironment() {
        let s = settings(env: ["OPENAI_TRANSCRIBE_MODEL": "whisper-1"])
        s.model = .gpt4oMiniTranscribe
        #expect(s.model == .gpt4oMiniTranscribe)
        #expect(s.modelSource == "menu")
    }

    // MARK: - Language

    @Test("No language configured means automatic detection")
    func languageDefaultsToAuto() {
        #expect(settings().language == nil)
    }

    @Test("Picking Auto overrides an environment language instead of falling through")
    func explicitAutoBeatsEnvironment() {
        let s = settings(env: ["OPENAI_TRANSCRIBE_LANGUAGE": "de"])
        s.language = nil
        #expect(s.language == nil)
    }

    // MARK: - Hotkey

    @Test("A stored shortcut that matches no preset falls back to the default")
    func unknownStoredShortcutFallsBack() {
        let s = settings(stored: ["hotKeyCode": 999, "hotKeyModifiers": 7])
        #expect(s.shortcut == .default)
    }

    @Test("A half-written shortcut falls back instead of registering a stray key")
    func partialStoredShortcutFallsBack() {
        let s = settings(stored: ["hotKeyCode": 96])
        #expect(s.shortcut == .default)
    }

    // MARK: - Translation

    @Test("Translation is off until a target is chosen, and off again when cleared")
    func translationTargetRoundTrip() {
        let s = settings()
        #expect(s.translationTarget == nil)
        s.translationTarget = "en"
        #expect(s.translationTarget == "en")
        s.translationTarget = nil
        #expect(s.translationTarget == nil)
    }

    @Test("A malformed stored target or model is ignored instead of being sent")
    func malformedTranslationValuesFallBack() {
        let s = settings(stored: ["translationTarget": "en; drop", "translationModel": "../model"])
        #expect(s.translationTarget == nil)
        #expect(s.translationModel == Translation.defaultModel)
        #expect(settings(stored: ["translationModel": "gpt-test-1"]).translationModel == "gpt-test-1")
    }

    // MARK: - Reset

    @Test("Resetting clears every stored preference and hands control back to the environment")
    func resetToEnvironment() {
        let s = settings(env: [
            "OPENAI_TRANSCRIBE_MODEL": "whisper-1",
            "OPENAI_TRANSCRIBE_LANGUAGE": "de",
            "OPENAI_TRANSCRIBE_PROMPT": "environment prompt"
        ])
        s.model = .gpt4oMiniTranscribe
        s.language = "en"
        s.shortcut = .f5
        s.autoPaste = false
        s.prompt = "stored prompt"
        s.translationTarget = "fr"
        s.resetToEnvironment()
        #expect(s.model == .whisper1)
        #expect(s.language == "de")
        #expect(s.shortcut == .default)
        #expect(s.autoPaste)
        #expect(s.prompt == "environment prompt")
        #expect(s.translationTarget == nil)
    }

}
