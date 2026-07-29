import Foundation

/// The slice of `UserDefaults` this app uses, so settings can be tested against
/// an in-memory store.
public protocol KeyValueStore: AnyObject, Sendable {
    func object(forKey defaultName: String) -> Any?
    func set(_ value: Any?, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
}

extension UserDefaults: KeyValueStore {}

/// Live settings.
///
/// Precedence is stored value, then environment variable, then built-in default.
/// The environment variables stay supported so existing launch scripts keep
/// working, but once a value is picked in the menu that choice wins, otherwise
/// the menu would silently do nothing for anyone who exports them.
public final class Settings: Sendable {
    public enum Key {
        public static let model = "transcriptionModel"
        public static let language = "transcriptionLanguage"
        public static let hotKeyCode = "hotKeyCode"
        public static let hotKeyModifiers = "hotKeyModifiers"
    }

    /// Stored value for "transcribe in whatever language you hear".
    public static let automaticLanguage = "auto"

    private let store: any KeyValueStore
    private let environment: [String: String]

    public init(store: any KeyValueStore, environment: [String: String]) {
        self.store = store
        self.environment = environment
    }

    // MARK: - Model

    public var model: TranscriptionModel {
        get {
            if let stored = store.object(forKey: Key.model) as? String, !stored.isEmpty {
                return TranscriptionModel(rawValue: stored)
            }
            if let fromEnvironment = environment["OPENAI_TRANSCRIBE_MODEL"], !fromEnvironment.isEmpty {
                return TranscriptionModel(rawValue: fromEnvironment)
            }
            return .default
        }
        set {
            store.set(newValue.rawValue, forKey: Key.model)
        }
    }

    /// Where the effective model comes from, for logging.
    public var modelSource: String {
        if let stored = store.object(forKey: Key.model) as? String, !stored.isEmpty {
            return "menu"
        }
        if let fromEnvironment = environment["OPENAI_TRANSCRIBE_MODEL"], !fromEnvironment.isEmpty {
            return "OPENAI_TRANSCRIBE_MODEL"
        }
        return "built-in default"
    }

    // MARK: - Language

    /// nil means let the API detect the language.
    public var language: String? {
        get {
            if let stored = store.object(forKey: Key.language) as? String {
                return stored == Self.automaticLanguage ? nil : stored
            }
            if let fromEnvironment = environment["OPENAI_TRANSCRIBE_LANGUAGE"], !fromEnvironment.isEmpty {
                return fromEnvironment
            }
            return nil
        }
        set {
            store.set(newValue ?? Self.automaticLanguage, forKey: Key.language)
        }
    }

    // MARK: - Hotkey

    public var shortcut: HotKeyShortcut {
        get {
            guard
                let code = store.object(forKey: Key.hotKeyCode) as? Int,
                let modifiers = store.object(forKey: Key.hotKeyModifiers) as? Int,
                let preset = HotKeyShortcut.preset(keyCode: UInt32(truncatingIfNeeded: code), modifiers: UInt32(truncatingIfNeeded: modifiers))
            else {
                return .default
            }
            return preset
        }
        set {
            store.set(Int(newValue.keyCode), forKey: Key.hotKeyCode)
            store.set(Int(newValue.modifiers), forKey: Key.hotKeyModifiers)
        }
    }

    // MARK: - Environment only

    /// Vocabulary hint. No menu for this, it is too long to pick from a menu.
    public var prompt: String? {
        let value = environment["OPENAI_TRANSCRIBE_PROMPT"]
        return (value?.isEmpty ?? true) ? nil : value
    }

    public var apiKeyFromEnvironment: String? {
        let value = environment["OPENAI_API_KEY"]
        return (value?.isEmpty ?? true) ? nil : value
    }

    /// Drops every stored choice, so the environment variables take over again.
    public func resetToEnvironment() {
        store.removeObject(forKey: Key.model)
        store.removeObject(forKey: Key.language)
        store.removeObject(forKey: Key.hotKeyCode)
        store.removeObject(forKey: Key.hotKeyModifiers)
    }
}
