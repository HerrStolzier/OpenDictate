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
        AppLog.write("Default transcription model: \(Config.model.rawValue)")
        ApplicationMenu.install()
        configureMenuBar()
        requestAccessibilityPermissionIfNeeded()
        warnAboutUnusableModelIfNeeded()

        do {
            try hotKey.register(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey | shiftKey)) { [weak self] in
                Task { @MainActor in
                    await self?.toggleRecording()
                }
            }
            updateStatus("Ready")
            AppLog.write("Global hotkey registered: Option+Shift+Space")
        } catch {
            updateStatus("Hotkey failed")
            AppLog.write("Hotkey registration failed: \(error.localizedDescription)")
            AlertPresenter.showWarning(title: "OpenDictate could not register its hotkey", message: error.localizedDescription)
        }
    }

    private func configureMenuBar() {
        let actions = MenuBarController.Actions(
            toggleRecording: { [weak self] in self?.toggleRecordingFromMenu() },
            setAPIKey: { [weak self] in self?.setAPIKey() },
            openAccessibilitySettings: { SystemSettings.openAccessibility() },
            openLog: { Self.openLog() },
            openSoundSettings: { SystemSettings.openSound() }
        )
        let controller = MenuBarController(actions: actions)
        controller.install()
        menuBar = controller
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

        guard Config.apiKey != nil else {
            updateStatus("Missing API key")
            AppLog.write("Recording blocked: missing API key")
            AlertPresenter.showWarning(
                title: "OPENAI_API_KEY is missing",
                message: "Choose Set API Key... from the OpenDictate menu bar item."
            )
            return
        }

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

        do {
            let audioURL = try recorder.stop()
            var cleanupURLs = [audioURL]
            defer {
                for url in cleanupURLs {
                    try? FileManager.default.removeItem(at: url)
                }
            }

            AppLog.write("Recording stopped: \(audioURL.path)")
            let preparedAudio = try await AudioPreprocessor.prepare(audioURL: audioURL)
            if preparedAudio.url != audioURL {
                cleanupURLs.append(preparedAudio.url)
            }
            AppLog.write(
                "Prepared audio. original=\(preparedAudio.originalDuration.formattedSeconds), upload=\(preparedAudio.uploadDuration.formattedSeconds), trimmed=\(preparedAudio.trimmedDuration.formattedSeconds)"
            )
            updateStatus("Uploading \(preparedAudio.uploadDuration.formattedSeconds)")

            let text = try await transcriber.transcribe(audioURL: preparedAudio.url)
            AppLog.write("Transcription succeeded. characters=\(text.count)")

            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                updateStatus("No text")
                AppLog.write("Transcription returned empty text")
                NSSound.beep()
                isBusy = false
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
        } catch {
            AppLog.write("Dictation failed: \(error.localizedDescription)")
            if let openDictateError = error as? OpenDictateError, openDictateError.isSkippedRecording {
                handleSkippedRecording(openDictateError)
            } else {
                updateStatus("Failed")
                AlertPresenter.showWarning(title: "Dictation failed", message: error.localizedDescription)
            }
        }

        isBusy = false
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

    /// OPENAI_TRANSCRIBE_MODEL accepts anything, so catch the one mistake that
    /// would otherwise only surface as an API error after the first dictation.
    private func warnAboutUnusableModelIfNeeded() {
        guard let reason = Config.model.uploadRejectionReason else { return }
        AppLog.write("Configured model is not usable: \(reason.replacingOccurrences(of: "\n", with: " "))")
        AlertPresenter.showWarning(title: "OPENAI_TRANSCRIBE_MODEL cannot be used", message: reason)
    }

    private func requestAccessibilityPermissionIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
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

    // MARK: - Menu actions

    private func toggleRecordingFromMenu() {
        AppLog.write("Start/Stop Recording selected from menu")
        Task { @MainActor in
            await toggleRecording()
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

    private static func openLog() {
        AppLog.write("Opening log")
        NSWorkspace.shared.open(AppLog.url)
    }
}
