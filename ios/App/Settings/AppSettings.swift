import Foundation
import OpenDictateCore

/// UserDefaults keys of the settings screen. Empty means the default, so a
/// cleared field never leaves a broken value behind.
enum AppSettings {
    /// Base address including `/v1`; empty is OpenAI.
    static let serverAddressKey = "serverAddress"
    static let transcriptionModelKey = "transcriptionModel"
    /// Target language code; empty turns translation off.
    static let translationTargetKey = "translationTarget"
    static let translationModelKey = "translationModel"
    /// Set once the shortcut started a dictation: iOS does not tell an app
    /// whether a shortcut, Back Tap or the Action button runs it.
    static let shortcutUsedKey = "shortcutUsed"
    /// `Engine` raw values; empty is the service.
    static let recognitionKey = "recognition"
    static let translationEngineKey = "translationEngine"

    static func string(_ key: String) -> String {
        (UserDefaults.standard.string(forKey: key) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// nil when the stored address is not usable.
    static var endpoint: ServiceEndpoint? {
        let address = string(serverAddressKey)
        return address.isEmpty ? .openAI : ServiceEndpoint(address)
    }

    static var recognition: Engine { Engine(rawValue: string(recognitionKey)) ?? .service }
    /// Parakeet does not translate, so only Apple's translation counts.
    static var translationEngine: Engine {
        Engine(rawValue: string(translationEngineKey)) == .onDevice ? .onDevice : .service
    }

    /// Recognition and translation on this iPhone send nothing.
    static var sendsNothing: Bool {
        recognition != .service && (string(translationTargetKey).isEmpty || translationEngine == .onDevice)
    }

    /// A server on this iPhone takes no key either.
    static var needsAPIKey: Bool { !sendsNothing && !(endpoint?.isLoopback ?? false) }

    /// What "the service" is right now, for the settings.
    /// An address that does not work still names the server: nothing falls back to OpenAI.
    static var serviceName: String {
        string(serverAddressKey).isEmpty ? "OpenAI" : L10n.pick("Your server", "Eigener Server")
    }
}

/// Who turns the recording into text, or the text into another language.
enum Engine: String, Sendable {
    /// OpenAI or the custom server.
    case service = ""
    /// Apple's models on this iPhone, see `OnDeviceTranscriber` and `OnDeviceTranslator`.
    case onDevice = "device"
    /// NVIDIA's Parakeet on this iPhone, for recognition only, see `ParakeetTranscriber`.
    case parakeet
}

/// Everything one dictation needs, read once when it starts or is sent again.
struct DictationConfiguration: Sendable {
    let recognition: Engine
    let translationEngine: Engine
    let endpoint: ServiceEndpoint
    /// nil when nothing is sent or the server is on this iPhone: it gets no
    /// key, and none is required.
    let apiKey: String?
    let model: TranscriptionModel
    let translationTarget: String?
    let translationModel: String

    /// Throws before anything is recorded, so nobody speaks into a dictation
    /// that cannot be sent. A request never falls back to OpenAI from an invalid address.
    static func current() throws -> Self {
        let recognition = AppSettings.recognition
        let translationEngine = AppSettings.translationEngine
        let target = AppSettings.string(AppSettings.translationTargetKey)
        // Without a request no server address matters.
        guard let endpoint = AppSettings.endpoint ?? (AppSettings.sendsNothing ? .openAI : nil) else {
            throw DictationFailure.invalidServerAddress
        }
        let key: String?
        if AppSettings.needsAPIKey {
            guard let stored = KeychainStore.apiKey() else { throw DictationFailure.missingAPIKey }
            key = stored
        } else {
            key = nil
        }
        let modelName = AppSettings.string(AppSettings.transcriptionModelKey)
        let model = modelName.isEmpty ? TranscriptionModel.default : TranscriptionModel(rawValue: modelName)
        if recognition == .service, !model.isUsableForUpload {
            throw DictationFailure.invalidModel
        }
        let translationModelName = AppSettings.string(AppSettings.translationModelKey)
        let translationModel = translationModelName.isEmpty ? Translation.defaultModel : translationModelName
        if !target.isEmpty {
            let modelIsValid = translationEngine == .onDevice || Translation.isValidModel(translationModel)
            guard Translation.isValidLanguageCode(target), modelIsValid else {
                throw DictationFailure.invalidModel
            }
        }
        return Self(
            recognition: recognition, translationEngine: translationEngine, endpoint: endpoint, apiKey: key,
            model: model, translationTarget: target.isEmpty ? nil : target, translationModel: translationModel)
    }

    /// Sets the bearer header only when a key belongs to this request.
    func authorize(_ request: inout URLRequest) {
        guard let apiKey, !endpoint.isLoopback else { return }
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    }
}
