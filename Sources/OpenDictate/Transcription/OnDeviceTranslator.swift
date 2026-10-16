import Foundation
import NaturalLanguage
import OpenDictateCore

#if compiler(>=6.2)
    import Translation
#endif

/// Apple's translation on this Mac (`TranslationSession` without a view,
/// macOS 26 and later). The text never leaves the Mac; the languages come
/// from Apple once, through System Settings. A build made with an SDK older
/// than macOS 26 never translates on the Mac and says so.
enum OnDeviceTranslator {
    enum Readiness: Equatable, Sendable {
        /// Before macOS 26, or Apple does not translate this pair.
        case unavailable
        case needsLanguages
        case ready
    }

    /// True when this build on this macOS can translate on the Mac at all.
    static var isSupported: Bool {
        #if compiler(>=6.2)
            if #available(macOS 26.0, *) { return true }
        #endif
        return false
    }

    /// The language dictations are usually in: the chosen dictation language,
    /// else the Mac's.
    static func usualSource(dictationLanguage: String?) -> Locale.Language {
        dictationLanguage.map { Locale.Language(identifier: $0) } ?? Locale.current.language
    }

    /// Checks the usual pair, so the settings can say early what is missing.
    static func readiness(into target: String, dictationLanguage: String?) async -> Readiness {
        #if compiler(>=6.2)
            guard #available(macOS 26.0, *) else { return .unavailable }
            let source = usualSource(dictationLanguage: dictationLanguage)
            let target = Locale.Language(identifier: target)
            // Dictations in the target language need no translation.
            guard source.languageCode != target.languageCode else { return .ready }
            return await readiness(from: source, to: target)
        #else
            return .unavailable
        #endif
    }

    /// Translates a dictation from its language: the chosen dictation
    /// language, else the one recognized in the text, else the Mac's. A pair
    /// that is not installed fails, and the recording stays for "Nochmal
    /// senden".
    static func translate(_ text: String, into target: String, dictationLanguage: String?) async throws -> String {
        #if compiler(>=6.2)
            guard #available(macOS 26.0, *) else { throw OpenDictateError.translationUnavailable }
            let target = Locale.Language(identifier: target)
            let source = language(of: text, dictationLanguage: dictationLanguage)
            // Apple refuses a pair of one language; the text needs nothing then.
            guard source.languageCode != target.languageCode else { return text }
            switch await readiness(from: source, to: target) {
            case .ready: break
            case .needsLanguages: throw OpenDictateError.translationLanguagesMissing
            case .unavailable: throw OpenDictateError.translationUnavailable
            }
            do {
                let session = TranslationSession(installedSource: source, target: target)
                return TranscriptText.sanitize(try await session.translate(text).targetText)
            } catch {
                // Domain and code only; the text never goes to the log.
                let error = error as NSError
                AppLog.write("Translation on this Mac failed: \(error.domain) \(error.code)")
                throw OpenDictateError.translationFailed
            }
        #else
            throw OpenDictateError.translationUnavailable
        #endif
    }

    #if compiler(>=6.2)
        @available(macOS 26.0, *)
        private static func readiness(from source: Locale.Language, to target: Locale.Language) async -> Readiness {
            switch await LanguageAvailability().status(from: source, to: target) {
            case .installed: return .ready
            case .supported: return .needsLanguages
            default: return .unavailable
            }
        }
    #endif

    private static func language(of text: String, dictationLanguage: String?) -> Locale.Language {
        if let dictationLanguage { return Locale.Language(identifier: dictationLanguage) }
        guard let language = NLLanguageRecognizer.dominantLanguage(for: text) else {
            return usualSource(dictationLanguage: nil)
        }
        return Locale.Language(identifier: language.rawValue)
    }
}
