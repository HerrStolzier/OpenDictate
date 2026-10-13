import Foundation

/// User-facing text in English or German, following the language iOS picked
/// for this app (system language or the per-app choice in Settings), like the
/// Mac and Linux apps. The app, its intents and the Live Activity share it.
enum L10n {
    static let isGerman = Bundle.main.preferredLocalizations.first?.lowercased().hasPrefix("de") ?? false

    static func pick(_ english: String, _ german: String) -> String { isGerman ? german : english }

    /// The design system's state words.
    static let ready = pick("Ready", "Bereit")

    static func word(_ phase: DictationAttributes.ContentState.Phase) -> String {
        switch phase {
        case .listening: pick("Listening", "Hört zu")
        case .writing: pick("Writing", "Schreibt")
        case .copied: pick("Copied", "Kopiert")
        case .done: pick("Done", "Fertig")
        case .oops: pick("Oops", "Hoppla")
        }
    }

    static let stop = pick("Stop", "Stopp")
    static let copiedDetail = pick("Paste the text wherever you like.", "Füge den Text ein, wo du möchtest.")
    static let shortcutCopiesDetail = pick(
        "With “Copy to Clipboard” in your shortcut, paste the text wherever you like.",
        "Mit „In Zwischenablage kopieren“ im Kurzbefehl kannst du den Text jetzt einfügen.")
    static let handOverDetail = pick(
        "Run your shortcut again or open OpenDictate, then the text is on the clipboard.",
        "Starte deinen Kurzbefehl nochmal oder öffne OpenDictate, dann liegt der Text in der Zwischenablage.")
    static let keptDetail = pick(
        "Recording kept. Open OpenDictate to send it again.",
        "Aufnahme gesichert. Öffne OpenDictate, um sie nochmal zu senden.")

    static func stopsIn(_ seconds: Int) -> String { pick("Stops in \(seconds) s", "Stopp in \(seconds) s") }
}
