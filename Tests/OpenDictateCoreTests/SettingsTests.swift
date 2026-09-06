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
        lock.lock(); defer { lock.unlock() }
        return values[defaultName]
    }

    func set(_ value: Any?, forKey defaultName: String) {
        lock.lock(); defer { lock.unlock() }
        values[defaultName] = value
    }

    func removeObject(forKey defaultName: String) {
        lock.lock(); defer { lock.unlock() }
        values.removeValue(forKey: defaultName)
    }
}

@Suite("Settings")
struct SettingsTests {
    private func settings(stored: [String: Any] = [:], env: [String: String] = [:]) -> Settings {
        Settings(store: MemoryStore(stored), environment: env)
    }

    // MARK: - Model

    @Test("With nothing configured the built-in default wins")
    func modelDefault() {
        let s = settings()
        #expect(s.model == .gptTranscribe)
        #expect(s.modelSource == "built-in default")
    }

    @Test("The environment variable is used when nothing was picked in the menu")
    func modelFromEnvironment() {
        let s = settings(env: ["OPENAI_TRANSCRIBE_MODEL": "whisper-1"])
        #expect(s.model == .whisper1)
        #expect(s.modelSource == "OPENAI_TRANSCRIBE_MODEL")
    }

    @Test("A menu choice beats the environment variable")
    func storedModelWinsOverEnvironment() {
        let s = settings(env: ["OPENAI_TRANSCRIBE_MODEL": "whisper-1"])
        s.model = .gpt4oMiniTranscribe
        #expect(s.model == .gpt4oMiniTranscribe)
        #expect(s.modelSource == "menu")
    }

    @Test("An empty environment variable is ignored")
    func emptyEnvironmentIgnored() {
        let s = settings(env: ["OPENAI_TRANSCRIBE_MODEL": ""])
        #expect(s.model == .gptTranscribe)
    }

    // MARK: - Language

    @Test("No language configured means automatic detection")
    func languageDefaultsToAuto() {
        #expect(settings().language == nil)
    }

    @Test("The environment language is used until something is picked")
    func languageFromEnvironment() {
        #expect(settings(env: ["OPENAI_TRANSCRIBE_LANGUAGE": "de"]).language == "de")
    }

    @Test("Picking Auto overrides an environment language instead of falling through")
    func explicitAutoBeatsEnvironment() {
        let s = settings(env: ["OPENAI_TRANSCRIBE_LANGUAGE": "de"])
        s.language = nil
        #expect(s.language == nil)
    }

    @Test("A picked language round-trips")
    func languageRoundTrip() {
        let s = settings()
        s.language = "en"
        #expect(s.language == "en")
    }

    // MARK: - Hotkey

    @Test("The default shortcut is Option+Shift+Space")
    func shortcutDefault() {
        #expect(settings().shortcut == .optionShiftSpace)
    }

    @Test("A picked shortcut round-trips")
    func shortcutRoundTrip() {
        let s = settings()
        s.shortcut = .f5
        #expect(s.shortcut == .f5)
    }

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

    // MARK: - Reset

    @Test("Resetting hands control back to the environment")
    func resetToEnvironment() {
        let s = settings(env: ["OPENAI_TRANSCRIBE_MODEL": "whisper-1"])
        s.model = .gpt4oMiniTranscribe
        s.shortcut = .f5
        s.resetToEnvironment()
        #expect(s.model == .whisper1)
        #expect(s.shortcut == .default)
    }

    // MARK: - Environment only

    @Test("Prompt comes from the environment, empty means unset")
    func environmentOnlyValues() {
        #expect(settings(env: ["OPENAI_TRANSCRIBE_PROMPT": "OpenDictate"]).prompt == "OpenDictate")
        #expect(settings(env: ["OPENAI_TRANSCRIBE_PROMPT": ""]).prompt == nil)
    }
}

@Suite("Hotkey shortcuts")
struct HotKeyShortcutTests {
    @Test("The presets are the three the menu offers")
    func presets() {
        #expect(HotKeyShortcut.presets.count == 3)
        #expect(HotKeyShortcut.presets.contains(.optionShiftSpace))
        #expect(HotKeyShortcut.presets.contains(.controlOptionD))
        #expect(HotKeyShortcut.presets.contains(.f5))
    }

    @Test("Every preset carries a label the menu can show")
    func presetsHaveNames() {
        for preset in HotKeyShortcut.presets {
            #expect(!preset.displayName.isEmpty)
        }
    }

    @Test("Presets are distinct, so no two menu entries register the same key")
    func presetsAreDistinct() {
        let pairs = HotKeyShortcut.presets.map { "\($0.keyCode)-\($0.modifiers)" }
        #expect(Set(pairs).count == pairs.count)
    }

    @Test("A known pair maps back to its preset")
    func lookupSucceeds() {
        let found = HotKeyShortcut.preset(keyCode: 49, modifiers: 2048 | 512)
        #expect(found == .optionShiftSpace)
    }

    @Test("An unknown pair maps to nothing")
    func lookupFails() {
        #expect(HotKeyShortcut.preset(keyCode: 1, modifiers: 1) == nil)
    }

    @Test("The Carbon cross-check accepts the real constants and rejects wrong ones")
    func carbonCrossCheck() {
        #expect(HotKeyShortcut.carbonConstantsMatch(space: 49, d: 2, f5: 96, shift: 512, control: 4096, option: 2048))
        #expect(!HotKeyShortcut.carbonConstantsMatch(space: 50, d: 2, f5: 96, shift: 512, control: 4096, option: 2048))
    }
}
