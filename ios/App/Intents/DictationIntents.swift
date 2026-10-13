import AppIntents

/// The action for "Back Tap", the Action button and Siri. iOS keeps recording
/// in the background only for an `AudioRecordingIntent` that shows a Live
/// Activity, which `DictationRunner.start()` requests before the microphone;
/// `LiveActivityIntent` lets it start that activity without the app in front.
/// The app comes to the front only when iOS refuses the microphone in the
/// background.
struct ToggleDictationIntent: AudioRecordingIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Dictate"
    static let description = IntentDescription(
        "Starts a dictation. Run it again to stop; the text is then on the clipboard.")

    /// Prefers the background; `perform()` may move to the front when iOS
    /// refuses the microphone there.
    @available(iOS 26.0, *)
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        do {
            return .result(value: try await DictationRunner.shared.toggle())
        } catch let failure as DictationFailure {
            guard case .recordingFailed = failure else { throw failure }
            // Started from the front, the recording then continues in the
            // background like one started in the app.
            if #available(iOS 26.0, *) {
                if systemContext.currentMode.canContinueInForeground {
                    try await continueInForeground(alwaysConfirm: false)
                    return .result(value: try await DictationRunner.shared.toggle())
                }
            }
            throw failure
        }
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
