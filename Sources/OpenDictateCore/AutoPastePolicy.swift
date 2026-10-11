/// A line break pasted into a terminal runs the dictated line as a command.
/// Multi-line text therefore stays in the clipboard for terminal applications
/// and is pasted automatically only into ordinary programs.
public enum AutoPastePolicy {
    public static let terminalBundleIdentifiers: Set<String> = [
        "com.apple.Terminal", "com.googlecode.iterm2", "io.alacritty", "org.alacritty", "net.kovidgoyal.kitty",
        "com.mitchellh.ghostty", "dev.warp.Warp-Stable", "dev.warp.Warp-Preview", "co.zeit.hyper",
        "com.github.wez.wezterm", "org.tabby", "com.apple.dt.Xcode.terminal"
    ]

    public static func isTerminal(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return terminalBundleIdentifiers.contains(bundleIdentifier)
    }

    public static func allowsPaste(of text: String, intoBundleIdentifier bundleIdentifier: String?) -> Bool {
        !(isTerminal(bundleIdentifier: bundleIdentifier) && TranscriptText.isMultiline(text))
    }
}
