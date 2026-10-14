import Foundation

/// The slice of `UserDefaults` this app uses, so settings can be tested against
/// an in-memory store.
public protocol KeyValueStore: AnyObject, Sendable {
    func object(forKey defaultName: String) -> Any?
    func set(_ value: Any?, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
}

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
        public static let shortcutCode = "hotKeyCode"
        public static let shortcutModifiers = "hotKeyModifiers"
        public static let shortcutName = "hotKeyName"
        public static let recordingModifier = "recordingModifierKey"
        public static let autoPaste = "autoPaste"
        public static let vocabularyPrompt = "vocabularyPrompt"
        public static let translationTarget = "translationTarget"
        public static let translationModel = "translationModel"
        public static let indicatorStyle = "indicatorStyle"
        public static let serverAddress = "serverAddress"
        public static let service = "service"
        public static let serverModel = "serverTranscriptionModel"
        public static let serverTranslationModel = "serverTranslationModel"
    }

    /// Who turns the recording into text.
    public enum Service: String, Sendable, CaseIterable {
        case openAI = "openai"
        case server
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
            guard let code = store.object(forKey: Key.shortcutCode) as? Int,
                let modifiers = store.object(forKey: Key.shortcutModifiers) as? Int,
                code >= 0, modifiers >= 0, code <= 126, modifiers <= Int(UInt32.max)
            else { return .default }
            if let preset = HotKeyShortcut.preset(keyCode: UInt32(code), modifiers: UInt32(modifiers)) { return preset }
            guard let name = store.object(forKey: Key.shortcutName) as? String,
                let custom = HotKeyShortcut.custom(
                    keyCode: UInt32(code), modifiers: UInt32(modifiers), displayName: name)
            else { return .default }
            return custom
        }
        set {
            store.set(Int(newValue.keyCode), forKey: Key.shortcutCode)
            store.set(Int(newValue.modifiers), forKey: Key.shortcutModifiers)
            store.set(newValue.displayName, forKey: Key.shortcutName)
        }
    }

    /// The active trigger. A stored single key wins; the Carbon combination
    /// stays stored next to it so older builds sharing these defaults still
    /// find the last combination.
    public var trigger: RecordingTrigger {
        get {
            if let raw = store.object(forKey: Key.recordingModifier) as? String, let key = ModifierKey(rawValue: raw) {
                return .modifierKey(key)
            }
            return .combination(shortcut)
        }
        set {
            switch newValue {
            case .combination(let combination):
                shortcut = combination
                store.removeObject(forKey: Key.recordingModifier)
            case .modifierKey(let key):
                store.set(key.rawValue, forKey: Key.recordingModifier)
            }
        }
    }

    /// Whether the user ever chose a trigger, including keeping the default.
    /// The first-launch shortcut question appears only while this is false.
    public var hasStoredTrigger: Bool {
        store.object(forKey: Key.recordingModifier) != nil || store.object(forKey: Key.shortcutCode) != nil
    }

    public var autoPaste: Bool {
        get { store.object(forKey: Key.autoPaste) as? Bool ?? true }
        set { store.set(newValue, forKey: Key.autoPaste) }
    }

    // MARK: - Vocabulary

    /// A stored vocabulary/context hint overrides the legacy environment value.
    public var prompt: String? {
        get {
            let value =
                (store.object(forKey: Key.vocabularyPrompt) as? String) ?? environment["OPENAI_TRANSCRIBE_PROMPT"]
            return (value?.isEmpty ?? true) ? nil : value
        }
        set { store.set(newValue ?? "", forKey: Key.vocabularyPrompt) }
    }

    // MARK: - Translation

    /// Target language for translating the transcript; nil delivers it unchanged.
    public var translationTarget: String? {
        get {
            guard let stored = store.object(forKey: Key.translationTarget) as? String,
                Translation.isValidLanguageCode(stored)
            else { return nil }
            return stored
        }
        set {
            if let newValue, Translation.isValidLanguageCode(newValue) {
                store.set(newValue, forKey: Key.translationTarget)
            } else {
                store.removeObject(forKey: Key.translationTarget)
            }
        }
    }

    /// Text model for the translation. A stored valid value wins.
    public var translationModel: String {
        get {
            if let stored = store.object(forKey: Key.translationModel) as? String, Translation.isValidModel(stored) {
                return stored
            }
            return Translation.defaultModel
        }
        set {
            if Translation.isValidModel(newValue), newValue != Translation.defaultModel {
                store.set(newValue, forKey: Key.translationModel)
            } else {
                store.removeObject(forKey: Key.translationModel)
            }
        }
    }

    // MARK: - Server

    /// The own server's address as configured, for display; nil means none is
    /// set up. It stays stored while OpenAI writes, so switching back needs no
    /// new entry.
    public var serverAddress: String? {
        let value = (store.object(forKey: Key.serverAddress) as? String) ?? environment["OPENAI_BASE_URL"]
        return (value?.isEmpty ?? true) ? nil : value
    }

    /// The service that writes. A stored choice wins; without one, a
    /// configured address means the own server, as before the choice existed.
    public var service: Service {
        if let raw = store.object(forKey: Key.service) as? String, let stored = Service(rawValue: raw) {
            return stored
        }
        return serverAddress == nil ? .openAI : .server
    }

    /// Switches the service and keeps the stored address. The own server
    /// needs an address; returns false and changes nothing without one.
    @discardableResult
    public func select(_ service: Service) -> Bool {
        guard service == .openAI || serverAddress != nil else { return false }
        store.set(service.rawValue, forKey: Key.service)
        return true
    }

    /// Where dictations go. nil means the own server is chosen but its address
    /// is invalid: the caller must stop instead of falling back to OpenAI,
    /// because the user chose not to send audio there.
    public var endpoint: ServiceEndpoint? { endpoint(for: service) }

    public func endpoint(for service: Service) -> ServiceEndpoint? {
        switch service {
        case .openAI: return .openAI
        case .server: return serverAddress.flatMap { ServiceEndpoint($0) }
        }
    }

    /// Stores a validated address. A first address selects the own server; a
    /// changed one keeps the current choice, so editing the server while OpenAI
    /// writes does not switch back. An empty text removes the address, selects
    /// OpenAI and wins over `OPENAI_BASE_URL`. Returns false and keeps the
    /// previous value for an address that is not allowed.
    @discardableResult
    public func setServerAddress(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            store.set("", forKey: Key.serverAddress)
            store.set(Service.openAI.rawValue, forKey: Key.service)
            return true
        }
        guard let endpoint = ServiceEndpoint(trimmed) else { return false }
        let current = service
        let hadAddress = serverAddress != nil
        store.set(endpoint.baseURL.absoluteString, forKey: Key.serverAddress)
        store.set((hadAddress ? current : .server).rawValue, forKey: Key.service)
        return true
    }

    /// Transcription model of the own server. Local servers use their own
    /// names, so it is stored apart from the OpenAI model in `model`.
    public var serverModel: TranscriptionModel {
        get {
            if let stored = store.object(forKey: Key.serverModel) as? String, !stored.isEmpty {
                return TranscriptionModel(rawValue: stored)
            }
            if let fromEnvironment = environment["OPENAI_TRANSCRIBE_MODEL"], !fromEnvironment.isEmpty {
                return TranscriptionModel(rawValue: fromEnvironment)
            }
            return .default
        }
        set {
            if newValue == .default {
                store.removeObject(forKey: Key.serverModel)
            } else {
                store.set(newValue.rawValue, forKey: Key.serverModel)
            }
        }
    }

    /// Text model the own server translates with.
    public var serverTranslationModel: String {
        get {
            if let stored = store.object(forKey: Key.serverTranslationModel) as? String,
                Translation.isValidModel(stored)
            {
                return stored
            }
            return Translation.defaultModel
        }
        set {
            if Translation.isValidModel(newValue), newValue != Translation.defaultModel {
                store.set(newValue, forKey: Key.serverTranslationModel)
            } else {
                store.removeObject(forKey: Key.serverTranslationModel)
            }
        }
    }

    public func model(for service: Service) -> TranscriptionModel {
        service == .openAI ? model : serverModel
    }

    public func translationModel(for service: Service) -> String {
        service == .openAI ? translationModel : serverTranslationModel
    }

    /// Builds before the service choice kept the own server's model names in
    /// the OpenAI fields. Moves them once, so switching to OpenAI does not
    /// send a local model name there. Runs only while no choice is stored.
    public func migrateServiceChoice() {
        guard store.object(forKey: Key.service) == nil,
            let address = store.object(forKey: Key.serverAddress) as? String, !address.isEmpty
        else { return }
        if let stored = store.object(forKey: Key.model) as? String, !stored.isEmpty {
            store.set(stored, forKey: Key.serverModel)
            // A known OpenAI model can stay for OpenAI; anything else was the server's.
            if TranscriptionModel(rawValue: stored).pricePerMinuteUSD == nil {
                store.removeObject(forKey: Key.model)
            }
        }
        if let stored = store.object(forKey: Key.translationModel) as? String {
            store.set(stored, forKey: Key.serverTranslationModel)
            store.removeObject(forKey: Key.translationModel)
        }
        store.set(Service.server.rawValue, forKey: Key.service)
    }

    // MARK: - Indicator

    /// How the indicator appears on screens without a notch.
    public var indicatorStyle: IndicatorStyle {
        get {
            (store.object(forKey: Key.indicatorStyle) as? String).flatMap(IndicatorStyle.init(rawValue:)) ?? .default
        }
        set { store.set(newValue.rawValue, forKey: Key.indicatorStyle) }
    }

    /// Drops every stored choice, so the environment variables take over again.
    public func resetToEnvironment() {
        store.removeObject(forKey: Key.model)
        store.removeObject(forKey: Key.language)
        store.removeObject(forKey: Key.shortcutCode)
        store.removeObject(forKey: Key.shortcutModifiers)
        store.removeObject(forKey: Key.shortcutName)
        store.removeObject(forKey: Key.recordingModifier)
        store.removeObject(forKey: Key.autoPaste)
        store.removeObject(forKey: Key.vocabularyPrompt)
        store.removeObject(forKey: Key.translationTarget)
        store.removeObject(forKey: Key.translationModel)
        store.removeObject(forKey: Key.indicatorStyle)
        store.removeObject(forKey: Key.serverAddress)
        store.removeObject(forKey: Key.service)
        store.removeObject(forKey: Key.serverModel)
        store.removeObject(forKey: Key.serverTranslationModel)
    }
}
