import OpenDictateCore
import SwiftUI

/// Recognition, API key, translation and the custom server. Empty fields
/// mean the default.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.recognitionKey) private var recognition = ""
    @AppStorage(AppSettings.translationTargetKey) private var translationTarget = ""
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
                Text(L10n.pick("OpenAI or your server", "OpenAI oder eigener Server")).tag(Recognition.service.rawValue)
                Text(L10n.pick("On this iPhone", "Auf dem iPhone")).tag(Recognition.onDevice.rawValue)
            }
            if recognition == Recognition.onDevice.rawValue {
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
                            "Die Sprache ließ sich nicht laden. Prüf deine Verbindung und versuch es nochmal."))
                        .foregroundStyle(.red)
                }
                Text(
                    recognition == Recognition.onDevice.rawValue
                        ? L10n.pick(
                            "Free and offline with Apple's speech recognition: the recording stays on this iPhone. "
                                + "Translation still goes to the service.",
                            "Kostenlos und offline mit Apples Spracherkennung: Die Aufnahme bleibt auf diesem "
                                + "iPhone. Übersetzen geht weiter über den Dienst.")
                        : L10n.pick(
                            "The recording goes to OpenAI or to your own server.",
                            "Die Aufnahme geht an OpenAI oder an deinen eigenen Server."))
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
        guard recognition == Recognition.onDevice.rawValue else { return }
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
        } header: {
            Text(L10n.pick("Translation", "Übersetzung"))
        } footer: {
            Text(
                L10n.pick(
                    "After you speak, the text is translated before it is copied.",
                    "Nach dem Sprechen wird der Text übersetzt, bevor er kopiert wird."))
        }
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
