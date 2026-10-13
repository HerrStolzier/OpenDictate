import Foundation
import NaturalLanguage
import OpenDictateCore
import Translation

/// Apple's translation on this iPhone (`TranslationSession`, iOS 26 and later
/// without a view). The text never leaves the device; the languages come from
/// Apple once, from the settings (`TranslationDownload`). Apple may count
/// usage with the language pair, never the text.
enum OnDeviceTranslator {
    enum Readiness: Equatable {
        /// Before iOS 26, or Apple does not translate this pair.
        case unavailable
        case needsLanguages
        case ready
    }

    /// The language the settings prepare: dictations are usually in the iPhone's.
    static var usualSource: Locale.Language { Locale.current.language }

    static func readiness(into target: String) async -> Readiness {
        guard #available(iOS 26.0, *) else { return .unavailable }
        let target = Locale.Language(identifier: target)
        // Dictations in the target language need no translation.
        guard usualSource.languageCode != target.languageCode else { return .ready }
        return await readiness(from: usualSource, to: target)
    }

    /// Translates a dictation. Its language is recognized on the device; a short
    /// text may be guessed wrong, so the iPhone's language is tried next. A pair
    /// that is not installed fails, and the recording stays for "Send again".
    static func translate(_ text: String, into target: String) async throws -> String {
        guard #available(iOS 26.0, *) else { throw DictationFailure.translationUnavailable }
        let target = Locale.Language(identifier: target)
        var source: Locale.Language?
        var missing = false
        for candidate in [language(of: text), usualSource] {
            // Apple refuses a pair of one language; the text needs nothing then.
            guard candidate.languageCode != target.languageCode else { return text }
            switch await readiness(from: candidate, to: target) {
            case .ready: source = candidate
            case .needsLanguages: missing = true
            case .unavailable: break
            }
            if source != nil { break }
        }
        guard let source else {
            throw missing ? DictationFailure.translationLanguagesMissing : DictationFailure.translationUnavailable
        }
        do {
            let session = TranslationSession(installedSource: source, target: target)
            return TranscriptText.sanitize(try await session.translate(text).targetText)
        } catch {
            let error = error as NSError
            throw DictationFailure.translationFailed("\(error.domain) \(error.code)")
        }
    }

    private static func readiness(from source: Locale.Language, to target: Locale.Language) async -> Readiness {
        guard #available(iOS 26.0, *) else { return .unavailable }
        switch await LanguageAvailability().status(from: source, to: target) {
        case .installed: return .ready
        case .supported: return .needsLanguages
        default: return .unavailable
        }
    }

    /// The iPhone's language when the text is too short to tell.
    private static func language(of text: String) -> Locale.Language {
        guard let language = NLLanguageRecognizer.dominantLanguage(for: text) else { return usualSource }
        return Locale.Language(identifier: language.rawValue)
    }
}
