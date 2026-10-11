import AppIntents

/// The stop button of the Live Activity. The system runs a `LiveActivityIntent`
/// in the app's process, where `DictationEntry` stops the recording; the
/// widget extension only needs the type for the button and compiles a stub.
struct StopDictationIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop dictation"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        await DictationEntry.stop()
        return .result()
    }
}
