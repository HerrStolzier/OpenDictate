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

    static func string(_ key: String) -> String {
        (UserDefaults.standard.string(forKey: key) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// nil when the stored address is not usable.
    static var endpoint: ServiceEndpoint? {
        let address = string(serverAddressKey)
        return address.isEmpty ? .openAI : ServiceEndpoint(address)
    }
}

/// Everything one dictation needs, read once when it starts or is sent again.
struct DictationConfiguration: Sendable {
    let endpoint: ServiceEndpoint
    /// nil for a server on this iPhone: it gets no key, and none is required.
    let apiKey: String?
    let model: TranscriptionModel
    let translationTarget: String?
    let translationModel: String

    /// Throws before anything is recorded, so nobody speaks into a dictation
    /// that cannot be sent. An invalid address never falls back to OpenAI.
    static func current() throws -> Self {
        guard let endpoint = AppSettings.endpoint else { throw DictationFailure.invalidServerAddress }
        let key: String?
        if endpoint.isLoopback {
            key = nil
        } else {
            guard let stored = KeychainStore.apiKey() else { throw DictationFailure.missingAPIKey }
            key = stored
        }
        let modelName = AppSettings.string(AppSettings.transcriptionModelKey)
        let model = modelName.isEmpty ? TranscriptionModel.default : TranscriptionModel(rawValue: modelName)
        guard ModelName.isValid(model.rawValue), model.isUsableForUpload else { throw DictationFailure.invalidModel }
        let target = AppSettings.string(AppSettings.translationTargetKey)
        let translationModelName = AppSettings.string(AppSettings.translationModelKey)
        let translationModel = translationModelName.isEmpty ? Translation.defaultModel : translationModelName
        if !target.isEmpty {
            guard Translation.isValidLanguageCode(target), Translation.isValidModel(translationModel) else {
                throw DictationFailure.invalidModel
            }
        }
        return Self(
            endpoint: endpoint, apiKey: key, model: model, translationTarget: target.isEmpty ? nil : target,
            translationModel: translationModel)
    }

    /// Sets the bearer header only when a key belongs to this request.
    func authorize(_ request: inout URLRequest) {
        guard let apiKey, !endpoint.isLoopback else { return }
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    }
}
