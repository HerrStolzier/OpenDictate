import AVFoundation
import Foundation
import OpenDictateCore
import Speech

/// Apple's speech recognition on this iPhone (`SpeechTranscriber`, iOS 26 and
/// later) in the iPhone's language. The recording never leaves the device;
/// only the language's model comes from Apple, once and from the foreground.
/// Unlike `SFSpeechRecognizer` it sends no audio to Apple and needs no
/// speech recognition permission.
enum OnDeviceTranscriber {
    enum Readiness: Equatable {
        /// Before iOS 26, or this iPhone or its language is not supported.
        case unavailable
        case needsModel
        case downloading
        case ready
    }

    /// The supported language closest to the iPhone's, nil if there is none.
    static func supportedLanguage() async -> Locale? {
        guard #available(iOS 26.0, *), SpeechTranscriber.isAvailable else { return nil }
        return await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current)
    }

    static func readiness() async -> Readiness {
        guard #available(iOS 26.0, *), let language = await supportedLanguage() else { return .unavailable }
        switch await AssetInventory.status(forModules: [transcriber(for: language)]) {
        case .installed: return .ready
        case .downloading: return .downloading
        case .supported: return .needsModel
        default: return .unavailable
        }
    }

    /// Downloads the model of the iPhone's language; returns at once when it
    /// is already installed.
    static func installModel() async throws {
        guard #available(iOS 26.0, *), let language = await supportedLanguage() else {
            throw DictationFailure.onDeviceUnavailable
        }
        do {
            let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber(for: language)])
            try await request?.downloadAndInstall()
        } catch {
            throw DictationFailure.onDeviceModelMissing
        }
    }

    /// Transcribes the authenticated bytes of a kept recording. Never
    /// downloads: a missing model fails, and the recording stays for "Send again".
    static func transcribe(_ audio: Data) async throws -> String {
        guard !audio.isEmpty else { throw DictationFailure.tooShort }
        guard #available(iOS 26.0, *), let language = await supportedLanguage() else {
            throw DictationFailure.onDeviceUnavailable
        }
        let module = transcriber(for: language)
        guard case .installed = await AssetInventory.status(forModules: [module]) else {
            throw DictationFailure.onDeviceModelMissing
        }
        // `AVAudioFile` reads only from a path, so the checked bytes go to a
        // private temporary file instead of reading the kept file again.
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        defer { try? FileManager.default.removeItem(at: file) }
        do {
            try audio.write(to: file, options: [.completeFileProtectionUntilFirstUserAuthentication])
            async let text = module.results.reduce(into: "") { text, result in
                text += String(result.text.characters)
            }
            let analyzer = SpeechAnalyzer(modules: [module])
            if let end = try await analyzer.analyzeSequence(from: AVAudioFile(forReading: file)) {
                try await analyzer.finalizeAndFinish(through: end)
            } else {
                await analyzer.cancelAndFinishNow()
            }
            return TranscriptText.sanitize(try await text)
        } catch {
            let error = error as NSError
            throw DictationFailure.onDeviceFailed("\(error.domain) \(error.code)")
        }
    }

    @available(iOS 26.0, *)
    private static func transcriber(for language: Locale) -> SpeechTranscriber {
        SpeechTranscriber(locale: language, preset: .transcription)
    }
}
