/// A target application can contain a terminal even when its bundle ID says
/// editor or browser. A line break may execute a command there, so multi-line
/// text always stays in the clipboard for deliberate manual insertion.
public enum AutoPastePolicy {
    public static func allowsPaste(of text: String) -> Bool {
        !TranscriptText.isMultiline(text)
    }
}
