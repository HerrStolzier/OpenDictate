import AppKit
import ApplicationServices
import Carbon
import Foundation

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var statusMenuItem: NSMenuItem?
    private var inputDeviceMenuItem: NSMenuItem?
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
        AppLog.write("Default transcription model: \(Config.model)")
        configureApplicationMenu()
        configureMenuBar()
        requestAccessibilityPermissionIfNeeded()

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
            showAlert(title: "OpenDictate could not register its hotkey", message: error.localizedDescription)
        }
    }

    private func configureMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = makeStatusBarImage()
            button.imagePosition = .imageOnly
            button.toolTip = "OpenDictate: Ready"
        }

        let menu = NSMenu()
        let statusMenuItem = NSMenuItem(title: "Status: Ready", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Hotkey: Option+Shift+Space", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Max recording: \(Int(Config.maximumRecordingDuration)) seconds", action: nil, keyEquivalent: ""))
        let inputDeviceItem = NSMenuItem(title: "Input: -", action: #selector(openSoundSettings), keyEquivalent: "")
        inputDeviceItem.target = self
        inputDeviceItem.toolTip = "Microphone OpenDictate records from. Click to open Sound settings."
        menu.addItem(inputDeviceItem)
        self.inputDeviceMenuItem = inputDeviceItem
        menu.addItem(.separator())
        let recordingItem = NSMenuItem(title: "Start/Stop Recording", action: #selector(toggleRecordingFromMenu), keyEquivalent: "")
        recordingItem.target = self
        menu.addItem(recordingItem)
        let apiKeyItem = NSMenuItem(title: "Set API Key...", action: #selector(setAPIKey), keyEquivalent: "")
        apiKeyItem.target = self
        menu.addItem(apiKeyItem)
        let accessibilityItem = NSMenuItem(title: "Open Accessibility Settings", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)
        let logItem = NSMenuItem(title: "Open Log", action: #selector(openLog), keyEquivalent: "")
        logItem.target = self
        menu.addItem(logItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.delegate = self
        item.menu = menu
        self.statusMenuItem = statusMenuItem
        refreshInputDeviceMenuItem()
        statusItem = item
    }

    private func configureApplicationMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit OpenDictate", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func makeStatusBarImage() -> NSImage? {
        let image: NSImage?
        if let url = Bundle.main.url(forResource: "OpenDictateIcon", withExtension: "png") {
            image = NSImage(contentsOf: url)
        } else {
            image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "OpenDictate")
            image?.isTemplate = true
        }

        image?.size = NSSize(width: 18, height: 18)
        return image
    }

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
            showAlert(
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
            showAlert(title: "Recording failed", message: error.localizedDescription)
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
                showAccessibilityRequiredAlert()
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
                showAlert(title: "Dictation failed", message: error.localizedDescription)
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

    private func requestAccessibilityPermissionIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    private func updateStatus(_ value: String) {
        statusMenuItem?.title = "Status: \(value)"
        statusItem?.button?.toolTip = "OpenDictate: \(value)"
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
            showBluetoothInputWarning(deviceName: input.name)
        }
    }

    private func showBluetoothInputWarning(deviceName: String) {
        let alert = NSAlert()
        alert.messageText = "No speech detected from \(deviceName)"
        alert.informativeText = """
        OpenDictate recorded, but the audio was (near) silent, so nothing was sent for transcription.

        Your microphone is currently set to \(deviceName), a Bluetooth device. Bluetooth headset mics often deliver almost no signal. Switch the input to the built-in microphone in Sound settings, then try dictating again.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Sound Settings")
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .alertFirstButtonReturn {
            openSoundSettings()
        }
    }

    private func refreshInputDeviceMenuItem() {
        guard let inputDeviceMenuItem else { return }
        let input = AudioInput.current()
        let name = input?.name ?? "Unknown"
        let suffix = (input?.isBluetooth ?? false) ? " (Bluetooth)" : ""
        inputDeviceMenuItem.title = "Input: \(name)\(suffix)"
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func showAccessibilityRequiredAlert() {
        let alert = NSAlert()
        alert.messageText = "Text copied, but OpenDictate cannot paste yet"
        alert.informativeText = """
        macOS is blocking automatic paste. OpenDictate needs Accessibility permission to send Cmd+V into the app you were using.

        Grant access in Privacy & Security > Accessibility, then try dictating again.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "OK")

        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }

    @objc private func toggleRecordingFromMenu() {
        AppLog.write("Start/Stop Recording selected from menu")
        Task { @MainActor in
            await toggleRecording()
        }
    }

    @objc private func setAPIKey() {
        let alert = NSAlert()
        alert.messageText = "Set OpenAI API Key"
        alert.informativeText = "The key is stored in your macOS Keychain under the OpenDictate service."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let inputView = APIKeyInputView(initialValue: Config.apiKey)
        alert.accessoryView = inputView

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        let key = inputView.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            showAlert(title: "No API key saved", message: "The field was empty.")
            return
        }

        do {
            try KeychainAPIKeyStore.save(key)
            updateStatus("Ready")
            AppLog.write("API key saved to Keychain")
        } catch {
            AppLog.write("Could not save API key: \(error.localizedDescription)")
            showAlert(title: "Could not save API key", message: error.localizedDescription)
        }
    }

    @objc private func openLog() {
        AppLog.write("Opening log")
        NSWorkspace.shared.open(AppLog.url)
    }

    @objc private func openAccessibilitySettings() {
        AppLog.write("Opening Accessibility settings")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshInputDeviceMenuItem()
    }

    @objc private func openSoundSettings() {
        AppLog.write("Opening Sound settings")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.sound") {
            NSWorkspace.shared.open(url)
        }
    }
}
