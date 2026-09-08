import AppKit
import ApplicationServices
import Carbon
import Darwin
import Foundation
import OpenDictateCore

/// App lifecycle and the dictation flow. UI construction lives in
/// `MenuBarController` / `ApplicationMenu`, modals in `AlertPresenter`.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?
    private let hotKey = HotKeyManager()
    private let recorder = AudioRecorder()
    private let transcriber = OpenAITranscriber()
    private let pasteboard = PasteboardInserter()
    private var previousApplication: NSRunningApplication?
    private var lastHotKeyAt = Date.distantPast
    private var autoStopTask: Task<Void, Never>?
    private var retentionTask: Task<Void, Never>?
    private var permissionRequestPending = false
    private let recordingLibrary = RecordingLibrary()
    private var savedRecordings: [SavedRecording] = []
    private var snapshotNeedsRefresh = false
    private var snapshotTask: Task<Void, Never>?
    private var requestOptions: TranscriptionOptions?
    private lazy var flow = makeFlow()

    private func makeFlow() -> DictationFlow {
        DictationFlow(
            operations: .init(
                start: { [unowned self] in try recorder.start() },
                stop: { [unowned self] in try recorder.stop() },
                prepare: { try await AudioPreprocessor.prepare(audioURL: $0) },
                transcribeFile: { [unowned self] in
                    try await transcriber.transcribe(audioURL: $0, options: requestOptions)
                },
                transcribeRetry: { [unowned self] in
                    try await transcriber.transcribe(audioData: $0.data, options: requestOptions)
                },
                keep: { FailedRecordingStore.keep($0, recordedAt: Date()) != nil },
                removeRetry: { _ = FailedRecordingStore.remove($0) },
                clean: { try? FileManager.default.removeItem(at: $0) },
                copy: { [unowned self] in pasteboard.copy($0) },
                paste: { [unowned self] text in
                    guard Config.settings.autoPaste else { return false }
                    return await pasteboard.pasteIntoPreviousApp(previousApplication, text: text)
                }
            ))
    }

    static func main() {
        // Credentials are accepted only through the in-app Keychain flow. Drop
        // an inherited legacy value before settings snapshot the environment.
        unsetenv("OPENAI_API_KEY")
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
        ApplicationMenu.install()
        configureMenuBar()
        flow.onStatus = { [weak self] in self?.updateStatus($0) }
        flow.onState = { [weak self] state in
            if state != .recording { self?.cancelAutoStop() }
            self?.menuBar?.updateState(state)
            if state == .idle {
                self?.requestOptions = nil
                self?.refreshSavedRecordings()
            }
        }
        recorder.onUnexpectedStop = { [weak self] in
            guard let self else { return }
            _ = flow.stop()
        }
        retentionTask = Task { @MainActor in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) } catch { break }
                refreshSavedRecordings()
            }
        }
        refreshSavedRecordings()
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

    @discardableResult
    private func registerHotKey(announce: Bool, shortcut: HotKeyShortcut? = nil) -> Bool {
        let shortcut = shortcut ?? Config.shortcut
        do {
            try hotKey.register(shortcut) { [weak self] in
                Task { @MainActor in
                    await self?.toggleRecording()
                }
            }
            if announce {
                updateStatus("Bereit")
            }
            AppLog.write("Global hotkey registered: \(shortcut.displayName)")
            return true
        } catch {
            updateStatus("Tastenkombination nicht verfügbar")
            AppLog.write("Hotkey registration failed: \(error.localizedDescription)")
            AlertPresenter.showWarning(
                title: "OpenDictate could not register \(shortcut.displayName)",
                message:
                    "\(error.localizedDescription)\n\nAnother app is probably using this shortcut. Pick a different one from the Hotkey menu."
            )
            return false
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

    private func toggleRecording() async {
        let now = Date()
        guard now.timeIntervalSince(lastHotKeyAt) > 0.35 else { return }
        lastHotKeyAt = now
        if flow.state.canStop {
            if flow.stop() { cancelAutoStop() }
            return
        }
        guard flow.state.canStart, !permissionRequestPending else { return }
        guard hasAPIKey(), Config.model.isUsableForUpload else {
            warnAboutUnusableModelIfNeeded()
            return
        }
        permissionRequestPending = true
        let permitted = await AudioRecorder.requestPermission()
        permissionRequestPending = false
        guard permitted else {
            updateStatus("Mikrofonzugriff fehlt – in den Systemeinstellungen erlauben")
            return
        }
        guard flow.state.canStart else { return }
        do {
            requestOptions = try .current()
            previousApplication = currentFrontmostApplication()
            if try flow.start() { scheduleAutoStop() }
        } catch { updateStatus("Aufnahme fehlgeschlagen: \(error.localizedDescription)") }
    }

    private func refreshSavedRecordings() {
        guard snapshotTask == nil else {
            snapshotNeedsRefresh = true
            return
        }
        snapshotTask = Task { @MainActor in
            savedRecordings = await recordingLibrary.snapshot()
            snapshotTask = nil
            menuBar?.refresh()
            if snapshotNeedsRefresh {
                snapshotNeedsRefresh = false
                refreshSavedRecordings()
            }
        }
    }

    private func retryLastRecording(filename: String? = nil) {
        guard flow.state.canRetry, !permissionRequestPending, hasAPIKey() else { return }
        permissionRequestPending = true
        let target = currentFrontmostApplication()
        Task { @MainActor in
            defer { permissionRequestPending = false }
            guard let payload = await recordingLibrary.load(filename: filename) else {
                updateStatus("Keine gültige Aufnahme zum Wiederholen")
                refreshSavedRecordings()
                return
            }
            guard flow.state.canRetry, let options = try? TranscriptionOptions.current() else { return }
            requestOptions = options
            previousApplication = target
            _ = flow.retry(payload)
        }
    }

    private func hasAPIKey() -> Bool {
        guard Config.apiKey == nil else { return true }
        updateStatus("API-Schlüssel fehlt – über das Menü einrichten")
        return false
    }

    private func scheduleAutoStop() {
        cancelAutoStop()
        autoStopTask = Task { @MainActor [weak self] in
            let start = ContinuousClock.now
            while !Task.isCancelled {
                guard let self, flow.state == .recording else { return }
                let elapsed = start.duration(to: .now)
                let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
                menuBar?.updateState(.recording, elapsed: seconds, level: recorder.level())
                if seconds >= Config.maximumRecordingDuration {
                    _ = flow.stop()
                    return
                }
                do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
            }
        }
    }

    private func cancelAutoStop() {
        autoStopTask?.cancel()
        autoStopTask = nil
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard flow.state != .idle else { return .terminateNow }
        guard AlertPresenter.confirmQuitWithActiveDictation() else { return .terminateCancel }
        cancelAutoStop()
        flow.cancel()
        let activeTask = flow.task
        Task { @MainActor in
            await activeTask?.value
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        cancelAutoStop()
        retentionTask?.cancel()
        flow.clearLastTranscript()
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
        AlertPresenter.showWarning(title: "Das eingestellte Modell ist nicht geeignet", message: reason)
    }

    private func updateStatus(_ value: String) {
        menuBar?.updateStatus(value)
    }

    private func setAPIKey() {
        guard let key = AlertPresenter.promptForAPIKey(initialValue: Config.apiKey) else { return }
        guard !key.isEmpty else {
            AlertPresenter.showWarning(title: "Kein API-Schlüssel gespeichert", message: "Das Feld war leer.")
            return
        }
        do {
            try KeychainAPIKeyStore.save(key)
            updateStatus("Bereit")
            AppLog.write("API key saved to Keychain")
        } catch {
            AppLog.write("Could not save API key: \(error.localizedDescription)")
            AlertPresenter.showWarning(
                title: "API-Schlüssel konnte nicht gespeichert werden", message: error.localizedDescription)
        }
    }

    private func deleteSavedRecordings() {
        guard flow.state == .idle else { return }
        let count = FailedRecordingStore.storedFileCount
        guard count > 0, AlertPresenter.confirmDeleteSavedRecordings(count: count) else { return }
        let removed = FailedRecordingStore.removeAll()
        refreshSavedRecordings()
        updateStatus(
            removed == count ? "Gespeicherte Aufnahmen gelöscht" : "Einige Aufnahmen konnten nicht gelöscht werden")
        AppLog.write("User deleted \(removed) of \(count) saved recording(s)")
    }
}

// MARK: - MenuBarControllerDelegate

extension AppDelegate: MenuBarControllerDelegate {
    func menuBarDidConfigureShortcut() {
        guard flow.state == .idle else { return }
        if let shortcut = ShortcutCaptureView.prompt() {
            menuBarDidSelect(shortcut: shortcut)
            menuBar?.refresh()
        }
    }

    func menuBarDidConfigureVocabulary() {
        guard let value = AlertPresenter.promptForVocabulary(initialValue: Config.prompt) else { return }
        guard value.count <= 2000 else {
            updateStatus("Vokabular nicht gespeichert: maximal 2.000 Zeichen")
            return
        }
        Config.settings.prompt = value
        updateStatus("Vokabular gespeichert")
    }

    func menuBarDidCancel(discard: Bool) { flow.cancel(discardRecording: discard) }
    func menuBarDidCopyLastText() { _ = flow.copyLastTranscript() }
    func menuBarDidClearLastText() { flow.clearLastTranscript() }
    func menuBarDidToggleAutoPaste() { Config.settings.autoPaste.toggle() }
    var menuBarRecordings: [SavedRecording] { savedRecordings }
    func menuBarDidRetry(filename: String) { retryLastRecording(filename: filename) }
    func menuBarDidDelete(filename: String) {
        guard flow.state == .idle, AlertPresenter.confirmDeleteSavedRecordings(count: 1) else { return }
        Task { @MainActor in
            await recordingLibrary.delete(filename: filename)
            refreshSavedRecordings()
        }
    }
    var menuBarState: DictationState { flow.state }
    var menuBarHasTranscript: Bool { flow.lastTranscript != nil }
    var menuBarAutoPaste: Bool { Config.settings.autoPaste }

    func menuBarDidTriggerToggleRecording() {
        AppLog.write("Start/Stop Recording selected from menu")
        Task { @MainActor in
            await toggleRecording()
        }
    }

    func menuBarDidTriggerRetry() {
        Task { @MainActor in
            retryLastRecording()
        }
    }

    func menuBarDidTriggerDeleteSavedRecordings() {
        deleteSavedRecordings()
    }

    func menuBarDidTriggerSetAPIKey() {
        setAPIKey()
    }

    func menuBarDidSelect(shortcut: HotKeyShortcut) {
        guard shortcut != Config.shortcut else { return }
        if registerHotKey(announce: false, shortcut: shortcut) {
            Config.settings.shortcut = shortcut
        }
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
}
