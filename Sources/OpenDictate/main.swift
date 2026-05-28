import AppKit
import ApplicationServices
import AVFoundation
import Carbon
import Foundation
import Security

private enum Config {
    static let model = ProcessInfo.processInfo.environment["OPENAI_TRANSCRIBE_MODEL"] ?? "gpt-4o-mini-transcribe"
    static let language = ProcessInfo.processInfo.environment["OPENAI_TRANSCRIBE_LANGUAGE"]
    static let prompt = ProcessInfo.processInfo.environment["OPENAI_TRANSCRIBE_PROMPT"]
    static var apiKey: String? {
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? KeychainAPIKeyStore.read()
    }
}

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var statusMenuItem: NSMenuItem?
    private let hotKey = HotKeyManager()
    private let recorder = AudioRecorder()
    private let transcriber = OpenAITranscriber()
    private let pasteboard = PasteboardInserter()
    private var previousApplication: NSRunningApplication?
    private var isBusy = false

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenuBar()
        requestAccessibilityPermissionIfNeeded()

        do {
            try hotKey.register(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey | shiftKey)) { [weak self] in
                Task { @MainActor in
                    await self?.toggleRecording()
                }
            }
            updateStatus("Ready")
        } catch {
            updateStatus("Hotkey failed")
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
        let apiKeyItem = NSMenuItem(title: "Set API Key...", action: #selector(setAPIKey), keyEquivalent: "")
        apiKeyItem.target = self
        menu.addItem(apiKeyItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        self.statusMenuItem = statusMenuItem
        statusItem = item
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
        if recorder.isRecording {
            await stopAndTranscribe()
            return
        }

        guard !isBusy else { return }

        guard Config.apiKey != nil else {
            updateStatus("Missing API key")
            showAlert(
                title: "OPENAI_API_KEY is missing",
                message: "Launch OpenDictate with OPENAI_API_KEY set in the environment."
            )
            return
        }

        do {
            previousApplication = currentFrontmostApplication()
            try recorder.start()
            updateStatus("Recording")
        } catch {
            updateStatus("Recording failed")
            showAlert(title: "Recording failed", message: error.localizedDescription)
        }
    }

    @MainActor
    private func stopAndTranscribe() async {
        guard !isBusy else { return }
        isBusy = true
        updateStatus("Processing")

        do {
            let audioURL = try recorder.stop()
            let text = try await transcriber.transcribe(audioURL: audioURL)
            try? FileManager.default.removeItem(at: audioURL)

            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                updateStatus("No text")
                NSSound.beep()
                isBusy = false
                return
            }

            pasteboard.copy(text)
            let pasted = await pasteboard.pasteIntoPreviousApp(previousApplication)
            updateStatus(pasted ? "Pasted" : "Copied")
        } catch {
            updateStatus("Failed")
            showAlert(title: "Dictation failed", message: error.localizedDescription)
        }

        isBusy = false
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

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    @objc private func setAPIKey() {
        let alert = NSAlert()
        alert.messageText = "Set OpenAI API Key"
        alert.informativeText = "The key is stored in your macOS Keychain under the OpenDictate service."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 420, height: 24))
        field.placeholderString = "sk-..."
        alert.accessoryView = field

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            showAlert(title: "No API key saved", message: "The field was empty.")
            return
        }

        do {
            try KeychainAPIKeyStore.save(key)
            updateStatus("Ready")
        } catch {
            showAlert(title: "Could not save API key", message: error.localizedDescription)
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
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
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

private struct OpenAITranscriber {
    func transcribe(audioURL: URL) async throws -> String {
        guard let apiKey = Config.apiKey else {
            throw OpenDictateError.missingAPIKey
        }

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
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
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

@MainActor
private struct PasteboardInserter {
    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func pasteIntoPreviousApp(_ app: NSRunningApplication?) async -> Bool {
        guard AXIsProcessTrusted(), let app else {
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
    case apiError(String)
    case hotKeyRegistrationFailed(OSStatus)
    case invalidResponse
    case keychainStatus(OSStatus)
    case missingAPIKey
    case noActiveRecording
    case noAudioFile
    case recordingCouldNotStart

    var errorDescription: String? {
        switch self {
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
        case .recordingCouldNotStart:
            return "AVAudioRecorder could not start recording."
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

private extension Data {
    mutating func appendString(_ value: String) {
        append(value.data(using: .utf8)!)
    }
}
