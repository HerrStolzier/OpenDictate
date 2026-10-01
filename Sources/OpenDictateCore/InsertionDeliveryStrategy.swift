/// Auto-insert path for a captured, still-focused field. Clipboard copy stays
/// outside this type: it always happens first and remains available.
public enum InsertionDeliveryStrategy: Equatable, Sendable {
    case nativeAX
    case unicode(UnicodeLineBreakPolicy)
    case terminalUnicode
    case clipboardOnly(Reason)

    public enum Reason: Equatable, Sendable {
        /// Apple Terminal with Secure Event Input enabled.
        case secureInput
        /// Terminal text contains a control, line-break or function-key scalar.
        case terminalRejectedText
        /// Allowlisted web editor without a captured AXWebArea ancestor.
        case unicodeRequiresWebArea
    }

    /// Editors whose AXSelectedText path can accept a write without inserting.
    public static let unicodeBundleIDs: Set<String> = [
        "com.brave.Browser", "com.apple.Safari", "com.google.Chrome", "md.obsidian"
    ]

    /// Conservative first Chrome assumption: isolate newlines like Safari so a
    /// leading break cannot drop following text. Live evidence may replace this.
    public static let chromeLineBreakPolicy: UnicodeLineBreakPolicy = .isolated

    public static let terminalBundleID = "com.apple.Terminal"
    public static let terminalRole = "AXTextArea"

    public static func isTerminalTarget(
        bundleIdentifier: String?, role: String, hasWebDocument: Bool
    ) -> Bool {
        bundleIdentifier == terminalBundleID && role == terminalRole && !hasWebDocument
    }

    public static func usesUnicodeEvents(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return unicodeBundleIDs.contains(bundleIdentifier)
    }

    public static func lineBreakPolicy(for bundleID: String?) -> UnicodeLineBreakPolicy {
        switch bundleID {
        case "com.apple.Safari": .isolated
        case "com.google.Chrome": chromeLineBreakPolicy
        case "com.brave.Browser": .trailing
        default: .grouped
        }
    }

    public static func choose(
        bundleIdentifier: String?,
        role: String,
        hasWebDocument: Bool,
        text: String,
        isSecureInputEnabled: Bool
    ) -> Self {
        if isTerminalTarget(bundleIdentifier: bundleIdentifier, role: role, hasWebDocument: hasWebDocument) {
            if isSecureInputEnabled { return .clipboardOnly(.secureInput) }
            if !TerminalInputPolicy.permits(text) { return .clipboardOnly(.terminalRejectedText) }
            return .terminalUnicode
        }
        if usesUnicodeEvents(bundleIdentifier) {
            if !hasWebDocument { return .clipboardOnly(.unicodeRequiresWebArea) }
            return .unicode(lineBreakPolicy(for: bundleIdentifier))
        }
        return .nativeAX
    }

    public var logMessage: String {
        switch self {
        case .nativeAX, .unicode, .terminalUnicode:
            return "auto-paste path selected"
        case .clipboardOnly(.secureInput):
            return "terminal secure input is enabled"
        case .clipboardOnly(.terminalRejectedText):
            return "terminal text contains a control or function-key scalar"
        case .clipboardOnly(.unicodeRequiresWebArea):
            return "allowlisted editor has no captured web document"
        }
    }
}

/// How Unicode key events pack line breaks. Safari and the Chrome candidate
/// isolate newline events; Brave binds breaks to the preceding grapheme;
/// others group text.
public enum UnicodeLineBreakPolicy: Equatable, Sendable {
    case grouped, isolated, trailing
}
