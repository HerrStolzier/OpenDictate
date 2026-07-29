import AppKit
import ApplicationServices
@preconcurrency import AVFoundation
import Carbon
import CoreAudio
import Foundation
import Security

private enum Config {
    static let model = ProcessInfo.processInfo.environment["OPENAI_TRANSCRIBE_MODEL"] ?? "gpt-transcribe"
    static let language = ProcessInfo.processInfo.environment["OPENAI_TRANSCRIBE_LANGUAGE"]
    static let prompt = ProcessInfo.processInfo.environment["OPENAI_TRANSCRIBE_PROMPT"]
    static let minimumRecordingDuration: TimeInterval = 1.0
    static let maximumRecordingDuration: TimeInterval = 90.0
    static let silenceThresholdDb: Float = -45.0
    static let silencePadding: TimeInterval = 0.25
    static var apiKey: String? {
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? KeychainAPIKeyStore.read()
    }
}

private enum AppLog {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/OpenDictate.log")

    static func write(_ message: String) {
        let line = "[\(timestamp())] \(message)\n"
        let data = Data(line.utf8)

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                try data.write(to: url)
            }
        } catch {
            NSLog("OpenDictate log failed: \(error.localizedDescription)")
        }
    }

    private static func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
}

/// Reads the system default audio input device via CoreAudio so we can show
/// which microphone OpenDictate is actually recording from and warn when it is
/// a wireless headset (whose mic often delivers near-silent audio).
private enum AudioInput {
    struct Info {
        let name: String
        let isBluetooth: Bool
    }

    static func current() -> Info? {
        guard let deviceID = defaultInputDeviceID() else { return nil }
        let name = deviceName(deviceID) ?? "Unknown input"
        let transport = transportType(deviceID)
        let isBluetooth = transport == kAudioDeviceTransportTypeBluetooth
            || transport == kAudioDeviceTransportTypeBluetoothLE
        return Info(name: name, isBluetooth: isBluetooth)
    }

    private static func defaultInputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    private static func deviceName(_ deviceID: AudioDeviceID) -> String? {
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name)
        guard status == noErr, let cfName = name?.takeRetainedValue() else { return nil }
        return cfName as String
    }

    private static func transportType(_ deviceID: AudioDeviceID) -> UInt32 {
        var transport = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transport)
        return status == noErr ? transport : 0
    }
}

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

@MainActor
private final class APIKeyInputView: NSView {
    private let secureField = NSSecureTextField()
    private let plainField = NSTextField()
    private let revealCheckbox = NSButton(checkboxWithTitle: "Show API key", target: nil, action: nil)

    var stringValue: String {
        plainField.isHidden ? secureField.stringValue : plainField.stringValue
    }

    init(initialValue: String?) {
        super.init(frame: NSRect(x: 0, y: 0, width: 420, height: 62))
        setup(initialValue: initialValue ?? "")
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func setup(initialValue: String) {
        let fieldContainer = NSView()
        fieldContainer.translatesAutoresizingMaskIntoConstraints = false

        configureTextField(secureField, initialValue: initialValue)
        configureTextField(plainField, initialValue: initialValue)
        plainField.isHidden = true

        fieldContainer.addSubview(secureField)
        fieldContainer.addSubview(plainField)

        revealCheckbox.target = self
        revealCheckbox.action = #selector(toggleReveal)
        revealCheckbox.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [fieldContainer, revealCheckbox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),

            fieldContainer.widthAnchor.constraint(equalToConstant: 420),
            fieldContainer.heightAnchor.constraint(equalToConstant: 24),

            secureField.leadingAnchor.constraint(equalTo: fieldContainer.leadingAnchor),
            secureField.trailingAnchor.constraint(equalTo: fieldContainer.trailingAnchor),
            secureField.topAnchor.constraint(equalTo: fieldContainer.topAnchor),
            secureField.bottomAnchor.constraint(equalTo: fieldContainer.bottomAnchor),

            plainField.leadingAnchor.constraint(equalTo: fieldContainer.leadingAnchor),
            plainField.trailingAnchor.constraint(equalTo: fieldContainer.trailingAnchor),
            plainField.topAnchor.constraint(equalTo: fieldContainer.topAnchor),
            plainField.bottomAnchor.constraint(equalTo: fieldContainer.bottomAnchor)
        ])
    }

    private func configureTextField(_ field: NSTextField, initialValue: String) {
        field.stringValue = initialValue
        field.placeholderString = "sk-..."
        field.translatesAutoresizingMaskIntoConstraints = false
        field.isEditable = true
        field.isSelectable = true
    }

    @objc private func toggleReveal() {
        let shouldReveal = revealCheckbox.state == .on

        if shouldReveal {
            plainField.stringValue = secureField.stringValue
            secureField.isHidden = true
            plainField.isHidden = false
            window?.makeFirstResponder(plainField)
        } else {
            secureField.stringValue = plainField.stringValue
            plainField.isHidden = true
            secureField.isHidden = false
            window?.makeFirstResponder(secureField)
        }
    }
}

private final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var action: (() -> Void)?

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) throws {
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard
                    let userData,
                    let event
                else {
                    return noErr
                }

                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard hotKeyID.signature == fourCharCode("ODCT") else {
                    return noErr
                }

                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.action?()
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &handlerRef
        )

        guard status == noErr else {
            throw OpenDictateError.hotKeyRegistrationFailed(status)
        }

        let hotKeyID = EventHotKeyID(signature: fourCharCode("ODCT"), id: 1)
        let registrationStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registrationStatus == noErr else {
            throw OpenDictateError.hotKeyRegistrationFailed(registrationStatus)
        }
    }
}

@MainActor
private final class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private var url: URL?

    var isRecording: Bool {
        recorder?.isRecording == true
    }

    func start() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("opendictate-\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 24_000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 48_000,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true

        guard recorder.record() else {
            throw OpenDictateError.recordingCouldNotStart
        }

        self.recorder = recorder
        self.url = fileURL
    }

    func stop() throws -> URL {
        guard let recorder, let url else {
            throw OpenDictateError.noActiveRecording
        }

        recorder.stop()
        self.recorder = nil
        self.url = nil

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw OpenDictateError.noAudioFile
        }

        return url
    }
}

private struct PreparedAudio {
    let url: URL
    let originalDuration: TimeInterval
    let uploadDuration: TimeInterval
    let trimmedDuration: TimeInterval
}

private struct AudioAnalysis {
    let speechRange: (start: TimeInterval, end: TimeInterval)?
    let peakDb: Float
    let averageDb: Float
}

private final class ExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) {
        self.session = session
    }
}

private enum AudioPreprocessor {
    static func prepare(audioURL: URL) async throws -> PreparedAudio {
        let originalDuration = try await duration(of: audioURL)
        guard originalDuration >= Config.minimumRecordingDuration else {
            throw OpenDictateError.recordingTooShort(actual: originalDuration, minimum: Config.minimumRecordingDuration)
        }

        let analysis = try analyze(audioURL: audioURL)
        AppLog.write(
            "Audio levels. peak=\(analysis.peakDb.formattedDb), avg=\(analysis.averageDb.formattedDb), threshold=\(Config.silenceThresholdDb.formattedDb)"
        )

        guard let speechRange = analysis.speechRange else {
            throw OpenDictateError.noSpeechDetected(peakDb: analysis.peakDb)
        }

        let start = max(0, speechRange.start - Config.silencePadding)
        let end = min(originalDuration, speechRange.end + Config.silencePadding)
        let uploadDuration = max(0, end - start)

        guard uploadDuration >= Config.minimumRecordingDuration else {
            throw OpenDictateError.recordingTooShort(actual: uploadDuration, minimum: Config.minimumRecordingDuration)
        }

        let trimmedDuration = max(0, originalDuration - uploadDuration)
        guard trimmedDuration >= 0.35 else {
            return PreparedAudio(
                url: audioURL,
                originalDuration: originalDuration,
                uploadDuration: originalDuration,
                trimmedDuration: 0
            )
        }

        let trimmedURL = try await exportTrimmedAudio(
            from: audioURL,
            start: start,
            duration: uploadDuration
        )

        return PreparedAudio(
            url: trimmedURL,
            originalDuration: originalDuration,
            uploadDuration: uploadDuration,
            trimmedDuration: trimmedDuration
        )
    }

    private static func duration(of audioURL: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: audioURL)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else {
            throw OpenDictateError.noAudioFile
        }
        return duration
    }

    /// Scans the recording in 50 ms windows: finds the speech span (windows above
    /// the silence threshold) and, regardless of the outcome, the peak and overall
    /// average level so callers can log them and distinguish "trimmed too hard"
    /// from "the microphone delivered (near) silence".
    private static func analyze(audioURL: URL) throws -> AudioAnalysis {
        let file = try AVAudioFile(forReading: audioURL)
        let format = file.processingFormat
        let sampleRate = format.sampleRate
        let channelCount = max(1, Int(format.channelCount))
        let windowFrameCount = AVAudioFrameCount(max(1, Int(sampleRate * 0.05)))

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: windowFrameCount) else {
            throw OpenDictateError.audioPreprocessingFailed("Could not allocate audio analysis buffer.")
        }

        var cursor: AVAudioFramePosition = 0
        var firstSpeechTime: TimeInterval?
        var lastSpeechTime: TimeInterval?
        var peakDb: Float = -160
        var totalSquares: Float = 0
        var totalSamples = 0

        while file.framePosition < file.length {
            let remaining = AVAudioFrameCount(min(Int64(windowFrameCount), file.length - file.framePosition))
            try file.read(into: buffer, frameCount: remaining)

            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0 else {
                break
            }

            let window = windowPower(buffer: buffer, channelCount: channelCount, frameLength: frameLength)
            totalSquares += window.sumSquares
            totalSamples += window.count

            let db = decibels(sumSquares: window.sumSquares, count: window.count)
            peakDb = max(peakDb, db)

            let start = Double(cursor) / sampleRate
            let end = Double(cursor + AVAudioFramePosition(frameLength)) / sampleRate

            if db >= Config.silenceThresholdDb {
                firstSpeechTime = firstSpeechTime ?? start
                lastSpeechTime = end
            }

            cursor += AVAudioFramePosition(frameLength)
        }

        let averageDb = decibels(sumSquares: totalSquares, count: totalSamples)
        let range: (start: TimeInterval, end: TimeInterval)?
        if let firstSpeechTime, let lastSpeechTime {
            range = (start: firstSpeechTime, end: lastSpeechTime)
        } else {
            range = nil
        }

        return AudioAnalysis(speechRange: range, peakDb: peakDb, averageDb: averageDb)
    }

    private static func windowPower(
        buffer: AVAudioPCMBuffer,
        channelCount: Int,
        frameLength: Int
    ) -> (sumSquares: Float, count: Int) {
        guard let channelData = buffer.floatChannelData else {
            return (0, 0)
        }

        var sum: Float = 0
        var count = 0

        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for frame in 0..<frameLength {
                let sample = samples[frame]
                sum += sample * sample
                count += 1
            }
        }

        return (sum, count)
    }

    private static func decibels(sumSquares: Float, count: Int) -> Float {
        guard count > 0 else {
            return -160
        }

        let rms = sqrt(sumSquares / Float(count))
        return 20 * log10(max(rms, 0.000_000_1))
    }

    private static func exportTrimmedAudio(
        from inputURL: URL,
        start: TimeInterval,
        duration: TimeInterval
    ) async throws -> URL {
        let asset = AVURLAsset(url: inputURL)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("opendictate-trimmed-\(UUID().uuidString).m4a")

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw OpenDictateError.audioPreprocessingFailed("Could not create audio export session.")
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            duration: CMTime(seconds: duration, preferredTimescale: 600)
        )

        let exportBox = ExportSessionBox(exportSession)
        try await withCheckedThrowingContinuation { continuation in
            exportBox.session.exportAsynchronously {
                switch exportBox.session.status {
                case .completed:
                    continuation.resume()
                case .failed, .cancelled:
                    continuation.resume(
                        throwing: OpenDictateError.audioPreprocessingFailed(
                            exportBox.session.error?.localizedDescription ?? "Audio export failed."
                        )
                    )
                default:
                    continuation.resume(
                        throwing: OpenDictateError.audioPreprocessingFailed("Audio export ended unexpectedly.")
                    )
                }
            }
        }

        return outputURL
    }
}

private struct OpenAITranscriber {
    func transcribe(audioURL: URL) async throws -> String {
        guard let apiKey = Config.apiKey else {
            throw OpenDictateError.missingAPIKey
        }

        AppLog.write("Uploading audio to OpenAI. model=\(Config.model)")
        let boundary = "OpenDictateBoundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        appendField(name: "model", value: Config.model, boundary: boundary, body: &body)
        appendField(name: "response_format", value: "text", boundary: boundary, body: &body)

        if let language = Config.language, !language.isEmpty {
            appendField(name: "language", value: language, boundary: boundary, body: &body)
        }

        if let prompt = Config.prompt, !prompt.isEmpty {
            appendField(name: "prompt", value: prompt, boundary: boundary, body: &body)
        }

        let audioData = try Data(contentsOf: audioURL)
        appendFile(
            name: "file",
            filename: audioURL.lastPathComponent,
            mimeType: "audio/m4a",
            data: audioData,
            boundary: boundary,
            body: &body
        )
        body.appendString("--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenDictateError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let message = OpenAIAPIErrorMessage.humanReadableMessage(from: data, statusCode: httpResponse.statusCode)
            AppLog.write("OpenAI API returned HTTP \(httpResponse.statusCode): \(message.replacingOccurrences(of: "\n", with: " "))")
            throw OpenDictateError.apiError(message)
        }

        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func appendField(name: String, value: String, boundary: String, body: inout Data) {
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        body.appendString("\(value)\r\n")
    }

    private func appendFile(
        name: String,
        filename: String,
        mimeType: String,
        data: Data,
        boundary: String,
        body: inout Data
    ) {
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.appendString("\r\n")
    }
}

private struct OpenAIAPIErrorMessage: Decodable {
    struct Body: Decodable {
        let error: Detail
    }

    struct Detail: Decodable {
        let message: String?
        let type: String?
        let code: String?
    }

    static func humanReadableMessage(from data: Data, statusCode: Int) -> String {
        let fallback = "OpenAI returned HTTP \(statusCode). Please try again in a moment."

        guard
            let body = try? JSONDecoder().decode(Body.self, from: data)
        else {
            return fallback
        }

        switch body.error.code ?? body.error.type {
        case "insufficient_quota":
            return """
            Your OpenAI API quota is exhausted.

            OpenAI accepted the request, but the API account or project behind this key has no remaining credit or has reached its usage limit.

            Check your OpenAI billing, project budget, or usage limits, then try again.
            """
        case "invalid_api_key":
            return """
            The OpenAI API key is not valid.

            Open the OpenDictate menu, choose Set API Key..., and paste a valid API key.
            """
        case "billing_not_active":
            return """
            OpenAI API billing is not active for this account or project.

            Add a billing method or choose an API key from a project with billing enabled.
            """
        case "rate_limit_exceeded":
            return """
            OpenAI is rate limiting this API key right now.

            Wait a moment and try again.
            """
        default:
            if let message = body.error.message, !message.isEmpty {
                return "OpenAI could not transcribe this recording.\n\n\(message)"
            }
            return fallback
        }
    }
}

@MainActor
private struct PasteboardInserter {
    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func pasteIntoPreviousApp(_ app: NSRunningApplication?) async -> Bool {
        guard AXIsProcessTrusted(), let app else {
            AppLog.write("Auto-paste unavailable. accessibility=\(AXIsProcessTrusted()), previousApp=\(app?.localizedName ?? "none")")
            return false
        }

        app.activate()
        try? await Task.sleep(for: .milliseconds(250))
        return simulateCommandV()
    }

    private func simulateCommandV() -> Bool {
        let virtualVKey: CGKeyCode = 0x09

        guard
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: virtualVKey, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: virtualVKey, keyDown: false)
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}

private enum OpenDictateError: LocalizedError {
    case audioPreprocessingFailed(String)
    case apiError(String)
    case hotKeyRegistrationFailed(OSStatus)
    case invalidResponse
    case keychainStatus(OSStatus)
    case missingAPIKey
    case noActiveRecording
    case noAudioFile
    case noSpeechDetected(peakDb: Float)
    case recordingCouldNotStart
    case recordingTooShort(actual: TimeInterval, minimum: TimeInterval)

    var isSkippedRecording: Bool {
        switch self {
        case .noSpeechDetected, .recordingTooShort:
            return true
        default:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .audioPreprocessingFailed(let message):
            return "Could not prepare the recording for transcription.\n\n\(message)"
        case .apiError(let message):
            return message
        case .hotKeyRegistrationFailed(let status):
            return "RegisterEventHotKey failed with status \(status)."
        case .invalidResponse:
            return "The transcription service returned an invalid response."
        case .keychainStatus(let status):
            return "Keychain operation failed with status \(status)."
        case .missingAPIKey:
            return "OPENAI_API_KEY is not set."
        case .noActiveRecording:
            return "There is no active recording to stop."
        case .noAudioFile:
            return "The recording finished, but no audio file was written."
        case .noSpeechDetected(let peakDb):
            return "No speech was detected (peak \(peakDb.formattedDb)), so nothing was sent to OpenAI."
        case .recordingCouldNotStart:
            return "AVAudioRecorder could not start recording."
        case .recordingTooShort(let actual, let minimum):
            return "Recording skipped: \(actual.formattedSeconds) is too short. Speak for at least \(minimum.formattedSeconds)."
        }
    }
}

private enum KeychainAPIKeyStore {
    private static let service = "OpenDictate"
    private static let account = "OPENAI_API_KEY"

    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard
            status == errSecSuccess,
            let data = result as? Data,
            let key = String(data: data, encoding: .utf8),
            !key.isEmpty
        else {
            return nil
        }

        return key
    }

    static func save(_ key: String) throws {
        let data = Data(key.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let update: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw OpenDictateError.keychainStatus(updateStatus)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw OpenDictateError.keychainStatus(addStatus)
        }
    }
}

private func fourCharCode(_ value: String) -> FourCharCode {
    value.utf8.reduce(0) { ($0 << 8) + FourCharCode($1) }
}

private extension TimeInterval {
    var formattedSeconds: String {
        String(format: "%.1fs", self)
    }
}

private extension Float {
    var formattedDb: String {
        String(format: "%.0f dB", self)
    }
}

private extension Data {
    mutating func appendString(_ value: String) {
        append(value.data(using: .utf8)!)
    }
}
