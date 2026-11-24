import AppIntents
import Foundation

/// The action for "Back Tap", the Action button and Siri. iOS keeps recording
/// in the background only for an `AudioRecordingIntent` that shows a Live
/// Activity, which `DictationRunner.start()` requests before the microphone;
/// `LiveActivityIntent` lets it start that activity without the app in front.
/// The app comes to the front only when iOS refuses the microphone in the
/// background.
struct ToggleDictationIntent: AudioRecordingIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Dictate"
    static let description = IntentDescription(
        "Starts a dictation. Run it again to stop; it then returns the text for “Copy to Clipboard”.")

    /// Prefers the background; `perform()` may move to the front when iOS
    /// refuses the microphone there.
    @available(iOS 26.0, *)
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String?> {
        // The shortcut runs, even if this dictation fails for another reason.
        UserDefaults.standard.set(true, forKey: AppSettings.shortcutUsedKey)
        let text: String?
        do {
            text = try await DictationRunner.shared.toggle()
        } catch let failure as DictationFailure {
            guard case .recordingFailed = failure else { throw failure }
            // Started from the front, the recording then continues in the
            // background like one started in the app.
            guard #available(iOS 26.0, *), systemContext.currentMode.canContinueInForeground else { throw failure }
            try await continueInForeground(alwaysConfirm: false)
            text = try await DictationRunner.shared.toggle()
        }
        return .result(value: text)
    }
}

/// "Keep microphone warm" for the OpenDictate keyboard, from the Action
/// button, Back Tap or the Shortcuts app, without opening the app. Like
/// "Dictate" it records in the background, so it shows a Live Activity.
struct WarmMicrophoneIntent: AudioRecordingIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Keep Microphone Warm"
    static let description = IntentDescription(
        "Keeps the microphone ready for the OpenDictate keyboard for the time set in the app. Run it again to turn the microphone off.")

    @available(iOS 26.0, *)
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @MainActor
    func perform() async throws -> some IntentResult {
        // Like "Dictate", a second run turns it off (Basti, 24 November):
        // the same Back Tap starts and ends it.
        if KeyboardDictation.shared.phase != .off {
            KeyboardDictation.shared.endSession()
            return .result()
        }
        do {
            try await KeyboardDictation.shared.startSession()
        } catch let failure as DictationFailure {
            guard case .recordingFailed = failure else { throw failure }
            guard #available(iOS 26.0, *), systemContext.currentMode.canContinueInForeground else { throw failure }
            try await continueInForeground(alwaysConfirm: false)
            try await KeyboardDictation.shared.startSession()
        }
        return .result()
    }
}

/// `StopDictationIntent` runs here, in the app's process.
enum DictationEntry {
    /// The stop button of a dictation, or of the warm microphone.
    @MainActor
    static func stop() async {
        // Also while the keyboard records or writes: that dictation finishes, then the microphone closes.
        if KeyboardDictation.shared.phase != .off {
            KeyboardDictation.shared.endSession()
        } else {
            DictationRunner.shared.stopFromLiveActivity()
        }
    }
}

struct OpenDictateShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleDictationIntent(),
            phrases: ["Dictate with \(.applicationName)", "Start \(.applicationName)"],
            shortTitle: "Dictate",
            systemImageName: "waveform")
        AppShortcut(
            intent: WarmMicrophoneIntent(),
            phrases: ["Keep the microphone warm with \(.applicationName)"],
            shortTitle: "Keep Microphone Warm",
            systemImageName: "mic")
    }
}
