/// `StopDictationIntent` never runs in the widget extension; the system runs
/// it in the app's process. The extension compiles the type for its button.
enum DictationEntry {
    static func stop() async {}
}
