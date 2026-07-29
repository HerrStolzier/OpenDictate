import AppKit
import ApplicationServices
import Carbon
import Foundation
import OpenDictateCore

/// App lifecycle and the dictation flow. UI construction lives in
/// `MenuBarController` / `ApplicationMenu`, modals in `AlertPresenter`.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?
    private var didWarnBluetoothInput = false
    private let hotKey = HotKeyManager()
    private let recorder = AudioRecorder()
    private let transcriber = OpenAITranscriber()
    private let pasteboard = PasteboardInserter()
    private var previousApplication: NSRunningApplication?
    private var isBusy = false
    private var lastHotKeyAt = Date.distantPast
    private var autoStopTask: Task<Void, Never>?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.write("App launched from \(Bundle.main.bundlePath)")
        AppLog.write("Transcription model: \(Config.model.rawValue) (from \(Config.settings.modelSource))")
        verifyHotKeyConstants()
        FailedRecordingStore.prune()
        ApplicationMenu.install()
        configureMenuBar()
        requestAccessibilityPermissionIfNeeded()
        warnAboutUnusableModelIfNeeded()
        registerHotKey(announce: true)
    }

    private func configureMenuBar() {
        let controller = MenuBarController(delegate: self)
        controller.install()
        menuBar = controller
    }

    // MARK: - Hotkey

    private func registerHotKey(announce: Bool) {
        let shortcut = Config.shortcut
        do {
            try hotKey.register(shortcut) { [weak self] in
                Task { @MainActor in
                    await self?.toggleRecording()
                }
            }
            if announce {
                updateStatus("Ready")
            }
            AppLog.write("Global hotkey registered: \(shortcut.displayName)")
        } catch {
            updateStatus("Hotkey failed")
            AppLog.write("Hotkey registration failed: \(error.localizedDescription)")
            AlertPresenter.showWarning(
                title: "OpenDictate could not register \(shortcut.displayName)",
                message: "\(error.localizedDescription)\n\nAnother app is probably using this shortcut. Pick a different one from the Hotkey menu."
            )
        }
    }

    /// The key codes live in OpenDictateCore, which cannot see Carbon. If Apple
    /// ever changed them, the shortcuts would silently register the wrong key.
    private func verifyHotKeyConstants() {
        let matches = HotKeyShortcut.carbonConstantsMatch(
            space: UInt32(kVK_Space),
            d: UInt32(kVK_ANSI_D),
            f5: UInt32(kVK_F5),
            shift: UInt32(shiftKey),
            control: UInt32(controlKey),
            option: UInt32(optionKey)
        )
        if !matches {
            AppLog.write("WARNING: hotkey constants in OpenDictateCore no longer match Carbon")
        }
    }

    // MARK: - Dictation flow

    @MainActor
    private func toggleRecording() async {
        let now = Date()
        guard now.timeIntervalSince(lastHotKeyAt) > 0.35 else {
            AppLog.write("Hotkey ignored because it arrived too quickly after the previous one")
            return
        }
        lastHotKeyAt = now
        AppLog.write("Hotkey triggered. recorder.isRecording=\(recorder.isRecording), isBusy=\(isBusy)")

        if recorder.isRecording {
            cancelAutoStop()
            await stopAndTranscribe()
            return
        }

        guard !isBusy else {
            AppLog.write("Hotkey ignored because transcription is already busy")
            return
        }

        guard hasAPIKey() else { return }

        do {
            previousApplication = currentFrontmostApplication()
            try recorder.start()
            updateStatus("Recording")
            scheduleAutoStop()
            let input = AudioInput.current()
            AppLog.write(
                "Recording started. Previous app=\(previousApplication?.localizedName ?? "none"), input=\(input?.name ?? "unknown"), bluetooth=\(input?.isBluetooth ?? false)"
            )
        } catch {
            updateStatus("Recording failed")
            cancelAutoStop()
            AppLog.write("Recording failed: \(error.localizedDescription)")
            AlertPresenter.showWarning(title: "Recording failed", message: error.localizedDescription)
        }
    }

    @MainActor
    private func stopAndTranscribe() async {
        guard !isBusy else { return }
        isBusy = true
        updateStatus("Processing")
        AppLog.write("Stopping recording")

        // Function-scope so it also runs after the catch block below. Anything
        // still listed here is a temporary file nobody needs; a recording kept
        // for retry has already been moved out of the temporary directory, so
        // removing its old path is a harmless no-op.
        var artifacts: [URL] = []
        defer {
            for url in artifacts {
                try? FileManager.default.removeItem(at: url)
            }
            isBusy = false
        }

        do {
            let audioURL = try recorder.stop()
            artifacts.append(audioURL)
            AppLog.write("Recording stopped: \(audioURL.path)")

            let preparedAudio = try await AudioPreprocessor.prepare(audioURL: audioURL)
            if preparedAudio.url != audioURL {
                artifacts.append(preparedAudio.url)
            }
            AppLog.write(
                "Prepared audio. original=\(preparedAudio.originalDuration.formattedSeconds), upload=\(preparedAudio.uploadDuration.formattedSeconds), trimmed=\(preparedAudio.trimmedDuration.formattedSeconds)"
            )
            updateStatus("Uploading \(preparedAudio.uploadDuration.formattedSeconds)")

            try await transcribeAndPaste(audioURL: preparedAudio.url)
        } catch {
            AppLog.write("Dictation failed: \(error.localizedDescription)")
            if let openDictateError = error as? OpenDictateError, openDictateError.isSkippedRecording {
                handleSkippedRecording(openDictateError)
            } else {
                handleTranscriptionFailure(error, audioToKeep: artifacts.last)
            }
        }
    }

    /// Uploads a file, then copies and pastes whatever came back.
    @MainActor
    private func transcribeAndPaste(audioURL: URL) async throws {
        let text = try await transcriber.transcribe(audioURL: audioURL)
        AppLog.write("Transcription succeeded. characters=\(text.count)")

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            updateStatus("No text")
            AppLog.write("Transcription returned empty text")
            NSSound.beep()
            return
        }

        pasteboard.copy(text)
        let pasted = await pasteboard.pasteIntoPreviousApp(previousApplication)
        if pasted {
            updateStatus("Pasted")
        } else if !AXIsProcessTrusted() {
            updateStatus("Copied - Enable Accessibility")
            AlertPresenter.showAccessibilityRequired()
        } else {
            updateStatus("Copied")
        }
        AppLog.write("Text copied. autoPaste=\(pasted)")
    }

    /// Keeps the audio instead of throwing it away, so a dropped connection does
    /// not cost the user what they just said.
    @MainActor
    private func handleTranscriptionFailure(_ error: Error, audioToKeep: URL?) {
        let kept = audioToKeep.flatMap { FailedRecordingStore.keep($0, recordedAt: Date()) }
        updateStatus(kept == nil ? "Failed" : "Failed - kept for retry")

        var message = error.localizedDescription
        if kept != nil {
            message += "\n\nThe recording was kept. Choose Retry Last Recording from the OpenDictate menu to upload it again."
        }
        AlertPresenter.showWarning(title: "Dictation failed", message: message)
    }

    @MainActor
    private func retryLastRecording() async {
        guard !isBusy else {
            AppLog.write("Retry ignored because a dictation is already running")
            return
        }

        guard let audioURL = FailedRecordingStore.newest() else {
            updateStatus("Nothing to retry")
            AppLog.write("Retry requested but nothing is kept")
            return
        }

        guard hasAPIKey() else { return }

        isBusy = true
        defer { isBusy = false }
        updateStatus("Retrying")
        AppLog.write("Retrying kept recording: \(audioURL.path)")

        do {
            previousApplication = currentFrontmostApplication() ?? previousApplication
            try await transcribeAndPaste(audioURL: audioURL)
            FailedRecordingStore.remove(audioURL)
            AppLog.write("Retry succeeded, kept recording removed")
        } catch {
            AppLog.write("Retry failed: \(error.localizedDescription)")
            updateStatus("Retry failed")
            AlertPresenter.showWarning(
                title: "Retry failed",
                message: "\(error.localizedDescription)\n\nThe recording is still kept, you can try again."
            )
        }
    }

    private func hasAPIKey() -> Bool {
        guard Config.apiKey == nil else { return true }
        updateStatus("Missing API key")
        AppLog.write("Blocked: missing API key")
        AlertPresenter.showWarning(
            title: "OPENAI_API_KEY is missing",
            message: "Choose Set API Key... from the OpenDictate menu bar item."
        )
        return false
    }

    private func scheduleAutoStop() {
        cancelAutoStop()
        autoStopTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(Config.maximumRecordingDuration * 1000)))
            guard !Task.isCancelled, let self, self.recorder.isRecording else {
                return
            }

            AppLog.write("Maximum recording duration reached. Auto-stopping.")
            updateStatus("Auto-stopping")
            await stopAndTranscribe()
        }
    }

    private func cancelAutoStop() {
        autoStopTask?.cancel()
        autoStopTask = nil
    }

    private func currentFrontmostApplication() -> NSRunningApplication? {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let app = NSWorkspace.shared.frontmostApplication
        return app?.processIdentifier == currentPID ? nil : app
    }

    private func requestAccessibilityPermissionIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    /// OPENAI_TRANSCRIBE_MODEL accepts anything, so catch the one mistake that
    /// would otherwise only surface as an API error after the first dictation.
    private func warnAboutUnusableModelIfNeeded() {
        guard let reason = Config.model.uploadRejectionReason else { return }
        AppLog.write("Configured model is not usable: \(reason.replacingOccurrences(of: "\n", with: " "))")
        AlertPresenter.showWarning(title: "The configured model cannot be used", message: reason)
    }

    private func updateStatus(_ value: String) {
        menuBar?.updateStatus(value)
    }

    private func handleSkippedRecording(_ error: OpenDictateError) {
        NSSound.beep()

        guard case .noSpeechDetected(let peakDb) = error else {
            updateStatus("Skipped")
            return
        }

        let input = AudioInput.current()
        if let input {
            updateStatus("Skipped - no speech (peak \(peakDb.formattedDb), in: \(input.name))")
        } else {
            updateStatus("Skipped - no speech (peak \(peakDb.formattedDb))")
        }

        // A Bluetooth headset mic frequently records near-silent audio; warn once
        // per session so the user can switch back to a wired/built-in microphone.
        if let input, input.isBluetooth, !didWarnBluetoothInput {
            didWarnBluetoothInput = true
            AppLog.write("Warning: skipped recording while default input is Bluetooth device '\(input.name)'")
            AlertPresenter.showBluetoothInputWarning(deviceName: input.name)
        }
    }

    private func setAPIKey() {
        switch AlertPresenter.promptForAPIKey(initialValue: Config.apiKey) {
        case .cancelled:
            return
        case .empty:
            AlertPresenter.showWarning(title: "No API key saved", message: "The field was empty.")
        case .key(let key):
            do {
                try KeychainAPIKeyStore.save(key)
                updateStatus("Ready")
                AppLog.write("API key saved to Keychain")
            } catch {
                AppLog.write("Could not save API key: \(error.localizedDescription)")
                AlertPresenter.showWarning(title: "Could not save API key", message: error.localizedDescription)
            }
        }
    }
}

// MARK: - MenuBarControllerDelegate

extension AppDelegate: MenuBarControllerDelegate {
    func menuBarDidTriggerToggleRecording() {
        AppLog.write("Start/Stop Recording selected from menu")
        Task { @MainActor in
            await toggleRecording()
        }
    }

    func menuBarDidTriggerRetry() {
        Task { @MainActor in
            await retryLastRecording()
        }
    }

    func menuBarDidTriggerSetAPIKey() {
        setAPIKey()
    }

    func menuBarDidSelect(shortcut: HotKeyShortcut) {
        guard shortcut != Config.shortcut else { return }
        Config.settings.shortcut = shortcut
        AppLog.write("Hotkey changed to \(shortcut.displayName)")
        registerHotKey(announce: false)
    }

    func menuBarDidSelect(model: TranscriptionModel) {
        guard model != Config.model else { return }
        Config.settings.model = model
        AppLog.write("Transcription model changed to \(model.rawValue)")
    }

    func menuBarDidSelect(language: String?) {
        guard language != Config.language else { return }
        Config.settings.language = language
        AppLog.write("Transcription language changed to \(language ?? "auto")")
    }

    var menuBarShortcut: HotKeyShortcut { Config.shortcut }
    var menuBarModel: TranscriptionModel { Config.model }
    var menuBarLanguage: String? { Config.language }
    var menuBarHasRetryableRecording: Bool { FailedRecordingStore.hasAny }
}
