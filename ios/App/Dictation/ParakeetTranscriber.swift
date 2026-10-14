import FluidAudio
import Foundation
import Observation
import OpenDictateCore

/// NVIDIA's Parakeet TDT 0.6B v3 on this iPhone through FluidAudio, a trial
/// beside Apple's recognition. The recording never leaves the device; only
/// the model (about 500 MB, CC BY 4.0) comes once from Hugging Face, from the
/// foreground. FluidAudio runs it on the CPU and the Neural Engine, never on
/// the GPU, which iOS refuses an app in the background.
enum ParakeetTranscriber {
    static var isInstalled: Bool { AsrModels.modelsExist(at: directory, version: .v3) }

    /// Loads the model ahead, while the app is open or the person speaks.
    static func prepare() {
        Task { _ = try? await LoadedModel.shared.manager() }
    }

    /// Whether a dictation now waits for the one-time setup: the first load
    /// of each installed copy of the app compiles the model for the Neural
    /// Engine (20 to 40 seconds on an iPhone 15); later launches reuse that.
    static func setsUpModel() async -> Bool {
        await !LoadedModel.shared.isLoaded && UserDefaults.standard.string(forKey: setUpKey) != setUpCopy
    }

    /// iOS gives every install and update of the app a new folder.
    fileprivate static var setUpCopy: String { Bundle.main.bundlePath }
    fileprivate static let setUpKey = "parakeetSetUpFor"

    /// Transcribes the authenticated bytes of a kept recording. Never
    /// downloads: a missing model fails, and the recording stays for "Send again".
    static func transcribe(_ audio: Data) async throws -> String {
        guard !audio.isEmpty else { throw DictationFailure.tooShort }
        guard isInstalled else { throw DictationFailure.localModelMissing }
        // FluidAudio reads only from a path, so the checked bytes go to a
        // private temporary file instead of reading the kept file again.
        removeLeftovers()
        let file = scratch.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        defer { try? FileManager.default.removeItem(at: file) }
        do {
            try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
            try audio.write(to: file, options: [.completeFileProtectionUntilFirstUserAuthentication])
            let manager = try await LoadedModel.shared.manager()
            var state = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
            // Only a hint for the script; Parakeet finds the language itself.
            let language = Locale.current.language.languageCode.flatMap { Language(rawValue: $0.identifier) }
            let result = try await manager.transcribe(file, decoderState: &state, language: language)
            return TranscriptText.sanitize(result.text)
        } catch let failure as DictationFailure {
            throw failure
        } catch {
            let error = error as NSError
            throw DictationFailure.localModelFailed("\(error.domain) \(error.code)")
        }
    }

    /// Only one recognition runs at a time, so anything in here was left by
    /// one that iOS ended; the kept recording itself is elsewhere.
    static func removeLeftovers() {
        try? FileManager.default.removeItem(at: scratch)
    }

    fileprivate static var directory: URL { AsrModels.defaultCacheDirectory(for: .v3) }

    private static var scratch: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("ParakeetRecognition", isDirectory: true)
    }
}

/// The model's download, shared by every settings screen, so closing and
/// reopening the settings shows the running download instead of starting
/// a second one into the same folder.
@MainActor
@Observable
final class ParakeetModel {
    static let shared = ParakeetModel()

    private(set) var isInstalled = ParakeetTranscriber.isInstalled
    /// The share loaded so far, nil while no download runs.
    private(set) var progress: Double?
    private(set) var failed = false

    private init() {}

    func refresh() {
        guard progress == nil else { return }
        isInstalled = ParakeetTranscriber.isInstalled
    }

    /// Downloads the model; with `again`, first removes a copy that does not
    /// load. iOS stops the download when the app goes to the background; the
    /// next tap continues it.
    func install(again: Bool = false) {
        guard progress == nil else { return }
        failed = false
        progress = 0
        Task {
            if again {
                await LoadedModel.shared.forget()
                try? FileManager.default.removeItem(at: ParakeetTranscriber.directory)
            }
            // New files need the one-time setup again.
            UserDefaults.standard.removeObject(forKey: ParakeetTranscriber.setUpKey)
            ModelHub.offlineMode = false
            defer { ModelHub.offlineMode = true }
            do {
                try await AsrModels.download(version: .v3) { share in
                    Task { @MainActor in
                        if ParakeetModel.shared.progress != nil {
                            ParakeetModel.shared.progress = share.fractionCompleted
                        }
                    }
                }
                // Half a gigabyte that can be loaded again does not belong in a backup.
                var folder = ParakeetTranscriber.directory
                var values = URLResourceValues()
                values.isExcludedFromBackup = true
                try? folder.setResourceValues(values)
                // The one-time setup now, while the app is still open.
                ParakeetTranscriber.prepare()
            } catch {
                failed = true
            }
            progress = nil
            isInstalled = ParakeetTranscriber.isInstalled
        }
    }
}

/// Keeps the loaded model between dictations, and loads it only once when
/// a dictation asks while `prepare` still loads it.
private actor LoadedModel {
    static let shared = LoadedModel()
    private var loading: Task<AsrManager, Error>?
    private(set) var isLoaded = false

    func manager() async throws -> AsrManager {
        if let loading, let manager = try? await loading.value { return manager }
        isLoaded = false
        let task = Task {
            // FluidAudio would otherwise download a missing or broken file
            // again, even during a dictation in the background.
            ModelHub.offlineMode = true
            let models = try await AsrModels.load(from: ParakeetTranscriber.directory, version: .v3)
            // In memory only: the streaming path keeps a raw copy of a long
            // recording in a temporary file that iOS could leave behind.
            let manager = AsrManager(config: ASRConfig(streamingEnabled: false))
            try await manager.loadModels(models)
            return manager
        }
        loading = task
        let manager = try await task.value
        if loading == task {
            isLoaded = true
            UserDefaults.standard.set(ParakeetTranscriber.setUpCopy, forKey: ParakeetTranscriber.setUpKey)
        }
        return manager
    }

    func forget() {
        loading = nil
        isLoaded = false
    }
}
