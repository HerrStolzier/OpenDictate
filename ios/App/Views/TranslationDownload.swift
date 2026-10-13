import SwiftUI
// `TranslationSession` is not Sendable in the SDK; the task hands it over only once.
@preconcurrency import Translation

/// Asks iOS to download the languages for translation on this iPhone. Only a
/// view's translation task may show that prompt, so the settings carry this.
struct TranslationDownload: ViewModifier {
    /// nil: nothing to load. Setting it again after nil asks again.
    let target: String?
    let onFinish: @MainActor () -> Void

    func body(content: Content) -> some View {
        let finish = onFinish
        content.translationTask(configuration) { session in
            // A refusal or an error shows as "not ready" in the check after.
            try? await session.prepareTranslation()
            Task { @MainActor in finish() }
        }
    }

    private var configuration: TranslationSession.Configuration? {
        target.map {
            TranslationSession.Configuration(
                source: OnDeviceTranslator.usualSource, target: Locale.Language(identifier: $0))
        }
    }
}
