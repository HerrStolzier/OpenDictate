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
    /// `Recognition` raw value; empty is the service.
    static let recognitionKey = "recognition"

    static func string(_ key: String) -> String {
        (UserDefaults.standard.string(forKey: key) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// nil when the stored address is not usable.
    static var endpoint: ServiceEndpoint? {
        let address = string(serverAddressKey)
        return address.isEmpty ? .openAI : ServiceEndpoint(address)
    }

    static var recognition: Recognition { Recognition(rawValue: string(recognitionKey)) ?? .service }

    /// Speech recognition on this iPhone without translation sends nothing,
    /// and a server on this iPhone takes no key.
    static var needsAPIKey: Bool {
        let sendsNothing = recognition == .onDevice && string(translationTargetKey).isEmpty
        return !sendsNothing && !(endpoint?.isLoopback ?? false)
    }
}

/// Who turns the recording into text.
enum Recognition: String, Sendable {
    /// OpenAI or the custom server.
    case service = ""
    /// Apple's speech recognition on this iPhone, see `OnDeviceTranscriber`.
    case onDevice = "device"
}

/// Everything one dictation needs, read once when it starts or is sent again.
struct DictationConfiguration: Sendable {
    let recognition: Recognition
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
        let target = AppSettings.string(AppSettings.translationTargetKey)
        // Recognition on this iPhone without translation reaches no server.
        let sendsNothing = recognition == .onDevice && target.isEmpty
        guard let endpoint = AppSettings.endpoint ?? (sendsNothing ? .openAI : nil) else {
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
        if recognition == .service, !ModelName.isValid(model.rawValue) || !model.isUsableForUpload {
            throw DictationFailure.invalidModel
        }
        let translationModelName = AppSettings.string(AppSettings.translationModelKey)
        let translationModel = translationModelName.isEmpty ? Translation.defaultModel : translationModelName
        if !target.isEmpty {
            guard Translation.isValidLanguageCode(target), Translation.isValidModel(translationModel) else {
                throw DictationFailure.invalidModel
            }
        }
        return Self(
            recognition: recognition, endpoint: endpoint, apiKey: key, model: model,
            translationTarget: target.isEmpty ? nil : target, translationModel: translationModel)
    }

    /// Sets the bearer header only when a key belongs to this request.
    func authorize(_ request: inout URLRequest) {
        guard let apiKey, !endpoint.isLoopback else { return }
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    }
}
