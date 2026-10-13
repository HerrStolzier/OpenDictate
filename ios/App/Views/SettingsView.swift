import OpenDictateCore
import SwiftUI

/// Recognition, API key, translation and the custom server. Empty fields
/// mean the default.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.recognitionKey) private var recognition = ""
    @AppStorage(AppSettings.translationTargetKey) private var translationTarget = ""
    @AppStorage(AppSettings.translationEngineKey) private var translationEngine = ""
    @AppStorage(AppSettings.serverAddressKey) private var serverAddress = ""
    @AppStorage(AppSettings.transcriptionModelKey) private var transcriptionModel = ""
    @AppStorage(AppSettings.translationModelKey) private var translationModel = ""
    @State private var keyInput = ""
    @State private var hasKey = KeychainStore.apiKey() != nil
    @State private var keyRefused = false
    /// nil while the check runs.
    @State private var onDevice: OnDeviceTranscriber.Readiness?
    @State private var language: Locale?
    @State private var loadFailed = false
    /// nil while the check runs.
    @State private var translationReadiness: OnDeviceTranslator.Readiness?
    /// Set to ask iOS for the languages; cleared when it answered.
    @State private var translationDownload: String?

    var body: some View {
        NavigationStack {
            Form {
                recognitionSection
                keySection
                translationSection
                serverSection
                aboutSection
            }
            .navigationTitle(L10n.pick("Settings", "Einstellungen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.pick("Done", "Fertig")) { dismiss() }
                }
            }
        }
    }

    private var recognitionSection: some View {
        Section {
            Picker(L10n.pick("Recognition", "Erkennung"), selection: $recognition) {
                engineOptions
            }
            .accessibilityIdentifier("recognition")
            if recognition == Engine.onDevice.rawValue {
                onDeviceState
            }
        } header: {
            Text(L10n.pick("Recognition", "Erkennung"))
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if loadFailed {
                    Text(
                        L10n.pick(
                            "The language could not be loaded. Check your connection and try again.",
                            "Die Sprache ließ sich nicht laden. Prüf deine Verbindung und versuch es nochmal.")
                    )
                    .foregroundStyle(.red)
                }
                Text(
                    recognition == Engine.onDevice.rawValue
                        ? L10n.pick(
                            "Free and offline with Apple's speech recognition: the recording stays on this iPhone.",
                            "Kostenlos und offline mit Apples Spracherkennung: Die Aufnahme bleibt auf diesem "
                                + "iPhone.")
                        : L10n.pick(
                            "The recording goes to \(AppSettings.serviceName). Change the server below.",
                            "Die Aufnahme geht an \(AppSettings.serviceName). Den Server stellst du unten ein."))
            }
        }
        .task(id: recognition) { await checkOnDevice() }
    }

    @ViewBuilder private var onDeviceState: some View {
        switch onDevice {
        case nil:
            ProgressView()
        case .unavailable:
            Text(DictationFailure.onDeviceUnavailable.message)
                .foregroundStyle(.red)
        case .needsModel:
            Button(L10n.pick("Load language (once, from Apple)", "Sprache laden (einmalig, von Apple)")) {
                Task { await loadLanguage() }
            }
        case .downloading:
            HStack(spacing: 8) {
                ProgressView()
                Text(L10n.pick("Loading the language …", "Sprache wird geladen …"))
            }
        case .ready:
            LabeledContent(L10n.pick("Language", "Sprache"), value: languageName)
        }
    }

    private var languageName: String {
        guard let language else { return "?" }
        let locale = Locale(identifier: L10n.isGerman ? "de" : "en")
        return locale.localizedString(forIdentifier: language.identifier) ?? language.identifier
    }

    private func checkOnDevice() async {
        guard recognition == Engine.onDevice.rawValue else { return }
        language = await OnDeviceTranscriber.supportedLanguage()
        onDevice = await OnDeviceTranscriber.readiness()
    }

    private func loadLanguage() async {
        loadFailed = false
        onDevice = .downloading
        do {
            try await OnDeviceTranscriber.installModel()
        } catch {
            loadFailed = true
        }
        await checkOnDevice()
    }

    private var keySection: some View {
        Section {
            if hasKey {
                LabeledContent(
                    L10n.pick("API key", "API-Schlüssel"),
                    value: L10n.pick("Saved on this iPhone", "Auf diesem iPhone gespeichert"))
                Button(L10n.pick("Remove API key", "API-Schlüssel entfernen"), role: .destructive) {
                    KeychainStore.deleteAPIKey()
                    hasKey = false
                }
            } else {
                SecureField(text: $keyInput, prompt: Text(verbatim: "sk-…")) {
                    Text(L10n.pick("API key", "API-Schlüssel"))
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                Button(L10n.pick("Save", "Speichern")) {
                    keyRefused = !KeychainStore.save(apiKey: keyInput)
                    hasKey = !keyRefused
                    keyInput = ""
                }
                .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } header: {
            Text(L10n.pick("OpenAI API key", "OpenAI-API-Schlüssel"))
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if keyRefused {
                    Text(L10n.pick("The key could not be saved.", "Der Schlüssel konnte nicht gespeichert werden."))
                        .foregroundStyle(.red)
                }
                Text(
                    L10n.pick(
                        "Stays in this iPhone's Keychain and goes only to the service. OpenAI bills you directly.",
                        "Bleibt im Schlüsselbund dieses iPhones und geht nur an den Dienst. "
                            + "Die Kosten rechnet OpenAI direkt mit dir ab."))
                Link(
                    L10n.pick("Create a key at OpenAI", "Schlüssel bei OpenAI anlegen"),
                    destination: URL(string: "https://platform.openai.com/api-keys")!)
            }
        }
    }

    private var translationSection: some View {
        Section {
            Picker(L10n.pick("Translate into", "Übersetzen nach"), selection: $translationTarget) {
                Text(L10n.pick("Off", "Aus")).tag("")
                ForEach(Translation.languages, id: \.code) { language in
                    Text(Self.name(of: language)).tag(language.code)
                }
            }
            .accessibilityIdentifier("translationTarget")
            if !translationTarget.isEmpty {
                Picker(L10n.pick("Translate with", "Übersetzen mit"), selection: $translationEngine) {
                    engineOptions
                }
                .accessibilityIdentifier("translationEngine")
                if translationEngine == Engine.onDevice.rawValue {
                    translationState
                }
            }
        } header: {
            Text(L10n.pick("Translation", "Übersetzung"))
        } footer: {
            Text(
                translationEngine == Engine.onDevice.rawValue && !translationTarget.isEmpty
                    ? L10n.pick(
                        "After you speak, Apple's translation on this iPhone translates the text before it is "
                            + "copied: free, offline, and the text stays here.",
                        "Nach dem Sprechen übersetzt Apples Übersetzung auf diesem iPhone den Text, bevor er "
                            + "kopiert wird: kostenlos, offline, und der Text bleibt hier.")
                    : L10n.pick(
                        "After you speak, the text is translated before it is copied.",
                        "Nach dem Sprechen wird der Text übersetzt, bevor er kopiert wird."))
        }
        .task(id: "\(translationTarget) \(translationEngine)") {
            translationReadiness = nil
            await checkTranslation()
        }
        .modifier(
            TranslationDownload(target: translationDownload) {
                translationDownload = nil
                Task { await checkTranslation() }
            })
    }

    /// The service as it is set right now, then this iPhone.
    @ViewBuilder private var engineOptions: some View {
        Text(AppSettings.serviceName).tag(Engine.service.rawValue)
        Text(L10n.pick("On this iPhone", "Auf dem iPhone")).tag(Engine.onDevice.rawValue)
    }

    @ViewBuilder private var translationState: some View {
        switch translationReadiness {
        case nil:
            ProgressView()
        case .unavailable:
            Text(DictationFailure.translationUnavailable.message)
                .foregroundStyle(.red)
        case .needsLanguages where translationDownload != nil:
            HStack(spacing: 8) {
                ProgressView()
                Text(L10n.pick("Loading the languages …", "Sprachen werden geladen …"))
            }
        case .needsLanguages:
            Button(L10n.pick("Load languages (once, from Apple)", "Sprachen laden (einmalig, von Apple)")) {
                translationDownload = translationTarget
            }
        case .ready:
            LabeledContent(L10n.pick("Languages", "Sprachen"), value: L10n.pick("Ready", "Bereit"))
        }
    }

    private func checkTranslation() async {
        guard !translationTarget.isEmpty, translationEngine == Engine.onDevice.rawValue else { return }
        translationReadiness = await OnDeviceTranslator.readiness(into: translationTarget)
    }

    private var serverSection: some View {
        Section {
            TextField(
                L10n.pick("Server address", "Server-Adresse"), text: $serverAddress,
                prompt: Text(verbatim: ServiceEndpoint.openAI.baseURL.absoluteString)
            )
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            TextField(
                L10n.pick("Transcription model", "Modell für die Erkennung"), text: $transcriptionModel,
                prompt: Text(verbatim: TranscriptionModel.default.rawValue)
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            TextField(
                L10n.pick("Translation model", "Modell für die Übersetzung"), text: $translationModel,
                prompt: Text(verbatim: Translation.defaultModel)
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        } header: {
            Text(L10n.pick("Custom server", "Eigener Server"))
        } footer: {
            if !Self.isUsable(serverAddress) {
                Text(
                    L10n.pick(
                        "This address does not work. Use https:// (http:// only for a server on this iPhone).",
                        "Diese Adresse geht nicht. Nutze https:// (http:// nur für einen Server auf diesem iPhone).")
                )
                .foregroundStyle(.red)
            } else {
                Text(
                    L10n.pick(
                        "Empty means OpenAI. For your own OpenAI-compatible server, enter its address including /v1.",
                        "Leer bedeutet OpenAI. Für einen eigenen OpenAI-kompatiblen Server trag seine Adresse "
                            + "mit /v1 ein."))
            }
        }
    }

    private var aboutSection: some View {
        Section {
            Link(
                L10n.pick("Privacy", "Datenschutz"),
                destination: URL(string: "https://support.opendictate.app/datenschutz")!)
            Link(L10n.pick("Contact", "Kontakt"), destination: URL(string: "https://support.opendictate.app/kontakt")!)
            LabeledContent(L10n.pick("Version", "Version"), value: Self.version)
        }
    }

    private static func isUsable(_ address: String) -> Bool {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || ServiceEndpoint(trimmed) != nil
    }

    private static func name(of language: Translation.Language) -> String {
        let locale = Locale(identifier: L10n.isGerman ? "de" : "en")
        return locale.localizedString(forLanguageCode: language.code)?.capitalized(with: locale) ?? language.title
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
