import AppIntents

/// The action for "Back Tap", the Action button and Siri. iOS keeps recording
/// in the background only for an `AudioRecordingIntent` that shows a Live
/// Activity, which `DictationRunner.start()` requests before the microphone.
/// The app never comes to the front.
struct ToggleDictationIntent: AudioRecordingIntent {
    static let title: LocalizedStringResource = "Dictate"
    static let description = IntentDescription(
        "Starts a dictation. Run it again to stop; the text is then on the clipboard.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: try await DictationRunner.shared.toggle())
    }
}

/// `StopDictationIntent` runs here, in the app's process.
enum DictationEntry {
    @MainActor
    static func stop() async {
        DictationRunner.shared.stopFromLiveActivity()
    }
}

struct OpenDictateShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleDictationIntent(),
            phrases: ["Dictate with \(.applicationName)", "Start \(.applicationName)"],
            shortTitle: "Dictate",
            systemImageName: "waveform")
    }
}
