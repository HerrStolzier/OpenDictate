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
    private lazy var dictationPanel = DictationPanel()
    private var pendingRetryFilename: String?
    private let hotKey = HotKeyManager()
    private let recorder = AudioRecorder()
    private let transcriber = OpenAITranscriber()
    private let pasteboard = PasteboardInserter()
    private var previousApplication: NSRunningApplication?
    private var insertionTarget: InsertionTarget?
    private var latestExternalApplication: NSRunningApplication?
    private var lastHotKeyAt = Date.distantPast
    private var autoStopTask: Task<Void, Never>?
    private var retentionTask: Task<Void, Never>?
    private var permissionRequestPending = false
    // Metadata snapshot for UI rendering; no secret is cached here.
    private var apiKeyNeedsSetup = false
    private var apiKeyPresenceTask: Task<Void, Never>?
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
                    guard Config.settings.autoPaste else { return .notAttempted }
                    return await pasteboard.paste(text, into: insertionTarget)
                }
            ))
    }

    static func main() {
        // Credentials are accepted only through the in-app Keychain flow. Drop
        // an inherited legacy value before settings snapshot the environment.
        unsetenv("OPENAI_API_KEY")
        let app = NSApplication.shared
        #if DEBUG
            let executable = Bundle.main.executableURL?.lastPathComponent
            if ProcessInfo.processInfo.arguments.contains("--matrix-fixture")
                || executable == "OpenDictateMatrixFixture"
            {
                DeliveryMatrixPreview.run(app)
                return
            }
            if ProcessInfo.processInfo.arguments.contains("--matrix-host") || executable == "OpenDictateMatrixHost" {
                DeliveryMatrixPreview.runHost(app)
                return
            }
            if ProcessInfo.processInfo.arguments.contains("--processing-focus-preview") {
                ProcessingFocusPreview.run(app)
                return
            }
            if ProcessInfo.processInfo.arguments.contains("--focus-fixture") || executable == "OpenDictateFocusFixture"
            {
                DesignPreview.runFocusFixture(app)
                return
            }
            if ProcessInfo.processInfo.arguments.contains("--design-preview") || executable == "OpenDictatePreview" {
                DesignPreview.run(app)
                return
            }
            // Renamed debug helpers must never fall through into production
            // services when Launch Services reopens them without arguments.
            guard executable == "OpenDictate" else { return }
        #endif
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
        latestExternalApplication = currentFrontmostApplication()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(applicationActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)
        configureMenuBar()
        configureDictationPanel()
        flow.onStatus = { [weak self] in self?.updateStatus($0) }
        flow.onOutcome = { [weak self] outcome in
            guard let self else { return }
            dictationPanel.update(outcome: outcome, transcript: flow.lastTranscript)
            dictationPanel.show()
        }
        flow.onState = { [weak self] state in
            if state != .recording { self?.cancelAutoStop() }
            self?.menuBar?.updateState(state)
            self?.dictationPanel.update(state: state)
            if state == .idle {
                self?.requestOptions = nil
                self?.insertionTarget = nil
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
        warnAboutUnusableModelIfNeeded()
        registerHotKey(announce: true)
        checkAPIKeySetupAtLaunch()
        if ProcessInfo.processInfo.arguments.contains("--show-window") {
            dictationPanel.showForInteraction()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if menuBar?.reopenSettingsIfVisible() == true { return true }
        dictationPanel.showForInteraction()
        return true
    }

    private func configureMenuBar() {
        let controller = MenuBarController(delegate: self)
        controller.onShowSettings = { [weak self] in self?.dictationPanel.window?.orderOut(nil) }
        controller.onShowDaily = { [weak self] anchor in self?.dictationPanel.showForInteraction(near: anchor) }
        controller.install()
        menuBar = controller
    }

    private func configureDictationPanel() {
        dictationPanel.setShortcut(Config.shortcut.displayName)
        dictationPanel.onRecord = { [weak self] in
            guard let self else { return }
            // Only an explicit panel action may return focus. Passive updates and
            // delivery never reactivate a target after the user switches apps.
            let target = flow.state.canStop ? previousApplication : latestExternalApplication
            if currentFrontmostApplication() == nil,
                let target, !target.isTerminated,
                PanelTargetPolicy.canReturnFocus(
                    target: target.processIdentifier,
                    latestExternal: latestExternalApplication?.processIdentifier)
            {
                target.activate()
            }
            Task { @MainActor in await toggleRecording(target: target) }
        }
        dictationPanel.onCancel = { [weak self] in self?.menuBarDidCancel(discard: false) }
        dictationPanel.onCopy = { [weak self] in self?.menuBarDidCopyLastText() }
        dictationPanel.onSetup = { [weak self] in self?.setAPIKey() }
        dictationPanel.onSettings = { [weak self] in self?.menuBar?.showSettings() }
        dictationPanel.onActions = { [weak self] in self?.menuBar?.showRecordingActions(at: $0) }
        dictationPanel.onRecovery = { [weak self] in
            self?.pendingRetryFilename = nil
            self?.menuBar?.showRecordings()
        }
        dictationPanel.onRetry = { [weak self] in
            guard let self, let filename = pendingRetryFilename else { return }
            pendingRetryFilename = nil
            retryLastRecording(filename: filename)
        }
    }

    private func proposeRetry(filename: String? = nil) {
        guard flow.state.canRetry, !permissionRequestPending,
            let entry = savedRecordings.first(where: { $0.retryable && (filename == nil || $0.filename == filename) })
        else { return }
        pendingRetryFilename = entry.filename
        dictationPanel.confirmRetry(description: entry.created.formatted(date: .abbreviated, time: .shortened))
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
                title: "Tastenkürzel nicht verfügbar",
                message:
                    OpenDictateError.userMessage(for: error)
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

    private func toggleRecording(target: NSRunningApplication? = nil) async {
        let capturedTarget = target ?? currentFrontmostApplication()
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
        let capturedField = pasteboard.captureTarget(in: capturedTarget?.processIdentifier)
        permissionRequestPending = true
        let permitted = await AudioRecorder.requestPermission()
        permissionRequestPending = false
        guard permitted else {
            updateStatus("Mikrofonzugriff fehlt – in den Systemeinstellungen erlauben")
            dictationPanel.showFailure("Mikrofonzugriff fehlt. Öffne die Systemeinstellungen und erlaube den Zugriff.")
            return
        }
        guard flow.state.canStart else { return }
        do {
            requestOptions = try .current()
            previousApplication = capturedTarget
            insertionTarget = capturedField
            if try flow.start() {
                pendingRetryFilename = nil
                scheduleAutoStop()
                dictationPanel.show()
            }
        } catch {
            updateStatus(OpenDictateError.userMessage(for: error))
            dictationPanel.showFailure("Die Aufnahme konnte nicht gestartet werden. Prüfe Mikrofon und Berechtigungen.")
        }
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
            insertionTarget = nil  // Recovery deliberately delivers through the clipboard only.
            _ = flow.retry(payload)
        }
    }

    private func hasAPIKey() -> Bool {
        apiKeyPresenceTask?.cancel()
        apiKeyPresenceTask = nil
        if Config.apiKey != nil {
            if apiKeyNeedsSetup { menuBar?.updateStatus("Bereit") }
            apiKeyNeedsSetup = false
            dictationPanel.updateAPIKeySetup(needsSetup: false, message: "Der API-Schlüssel ist verfügbar.")
            menuBar?.refresh()
            return true
        }
        menuBar?.updateStatus("API-Schlüssel nicht verfügbar")
        let message =
            "Der API-Schlüssel fehlt oder ist nicht zugänglich. "
            + "Prüfe den macOS-Schlüsselbund oder richte den Schlüssel erneut ein."
        dictationPanel.updateAPIKeySetup(needsSetup: true, message: apiKeyNeedsSetup ? nil : message)
        apiKeyNeedsSetup = true
        menuBar?.refresh()
        dictationPanel.show()
        return false
    }

    private func checkAPIKeySetupAtLaunch() {
        apiKeyPresenceTask = Task { @MainActor [weak self] in
            let needsSetup = await Task.detached(priority: .utility) {
                KeychainAPIKeyStore.needsSetup
            }.value
            guard let self, !Task.isCancelled else { return }
            apiKeyPresenceTask = nil
            apiKeyNeedsSetup = needsSetup
            menuBar?.refresh()
            if needsSetup {
                menuBar?.updateStatus("API-Schlüssel einrichten")
                dictationPanel.updateAPIKeySetup(needsSetup: true)
                if menuBar?.hasVisibleSettings != true { dictationPanel.show() }
            } else {
                requestAccessibilityPermissionIfNeeded()
            }
        }
    }

    private func scheduleAutoStop() {
        cancelAutoStop()
        autoStopTask = Task { @MainActor [weak self] in
            let start = ContinuousClock.now
            while !Task.isCancelled {
                guard let self, flow.state == .recording else { return }
                let elapsed = start.duration(to: .now)
                let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
                let level = recorder.level()
                menuBar?.updateState(.recording, elapsed: seconds, level: level)
                dictationPanel.updateRecording(elapsed: seconds, level: level)
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
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        retentionTask?.cancel()
        apiKeyPresenceTask?.cancel()
        flow.clearLastTranscript()
    }

    @objc private func applicationActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
            app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else { return }
        if flow.state != .idle, app.processIdentifier != previousApplication?.processIdentifier {
            insertionTarget = nil
        }
        latestExternalApplication = app
    }

    private func currentFrontmostApplication() -> NSRunningApplication? {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let app = NSWorkspace.shared.frontmostApplication
        return app?.processIdentifier == currentPID ? nil : app
    }

    private func requestAccessibilityPermissionIfNeeded() {
        guard flow.state == .idle, Config.settings.autoPaste, !AXIsProcessTrusted() else { return }
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
        dictationPanel.setStatus(value)
    }

    private func setAPIKey() {
        guard flow.state == .idle, !permissionRequestPending else { return }
        // The modal runs a nested event loop; a hotkey must not start a dictation
        // while credential setup has temporarily moved focus away from its target.
        permissionRequestPending = true
        defer {
            permissionRequestPending = false
            menuBar?.refresh()
        }
        apiKeyPresenceTask?.cancel()
        apiKeyPresenceTask = nil
        let previousKey = Config.apiKey
        let settingUp = previousKey == nil || dictationPanel.display == .setup
        if settingUp {
            apiKeyNeedsSetup = true
            dictationPanel.updateAPIKeySetup(needsSetup: true)
        }
        guard let key = AlertPresenter.promptForAPIKey(initialValue: previousKey) else {
            if settingUp {
                dictationPanel.updateAPIKeySetup(
                    needsSetup: true,
                    message:
                        "Einrichtung abgebrochen. Über „API-Schlüssel einrichten“ "
                        + "kannst du sie jederzeit fortsetzen.")
            }
            return
        }
        guard !key.isEmpty else {
            if settingUp {
                dictationPanel.updateAPIKeySetup(
                    needsSetup: true, message: "Das Feld war leer. Gib deinen eigenen OpenAI-API-Schlüssel ein.")
            }
            AlertPresenter.showWarning(title: "Kein API-Schlüssel gespeichert", message: "Das Feld war leer.")
            return
        }
        do {
            try KeychainAPIKeyStore.save(key)
            apiKeyNeedsSetup = false
            menuBar?.updateStatus("API-Schlüssel gespeichert")
            if settingUp {
                dictationPanel.updateAPIKeySetup(needsSetup: false)
                menuBar?.showDaily()
            }
            AppLog.write("API key saved to Keychain")
            requestAccessibilityPermissionIfNeeded()
        } catch {
            AppLog.write("Could not save API key: \(error.localizedDescription)")
            if settingUp {
                dictationPanel.updateAPIKeySetup(
                    needsSetup: true,
                    message:
                        "Der Schlüssel konnte nicht gespeichert werden. "
                        + "Über „API-Schlüssel einrichten“ kannst du es erneut versuchen.")
            }
            AlertPresenter.showWarning(
                title: "API-Schlüssel konnte nicht gespeichert werden",
                message: OpenDictateError.userMessage(for: error))
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
        guard flow.state == .idle else { return }
        guard let value = AlertPresenter.promptForVocabulary(initialValue: Config.prompt) else { return }
        guard value.count <= 2000 else {
            updateStatus("Vokabular nicht gespeichert: maximal 2.000 Zeichen")
            return
        }
        Config.settings.prompt = value
        updateStatus("Vokabular gespeichert")
    }

    func menuBarDidCancel(discard: Bool) { flow.cancel(discardRecording: discard) }
    func menuBarDidCopyLastText() {
        guard flow.state == .idle else { return }
        _ = flow.copyLastTranscript()
    }
    func menuBarDidClearLastText() {
        guard flow.state == .idle else { return }
        flow.clearLastTranscript()
        dictationPanel.clearText()
    }
    func menuBarDidToggleAutoPaste() {
        guard flow.state == .idle else { return }
        Config.settings.autoPaste.toggle()
        menuBar?.showSettings()
        requestAccessibilityPermissionIfNeeded()
    }
    var menuBarRecordings: [SavedRecording] { savedRecordings }
    func menuBarDidRetry(filename: String) { proposeRetry(filename: filename) }
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
    var menuBarNeedsAPIKeySetup: Bool { apiKeyNeedsSetup }

    func menuBarDidTriggerToggleRecording() {
        AppLog.write("Start/Stop Recording selected from menu")
        Task { @MainActor in
            await toggleRecording()
        }
    }

    func menuBarDidTriggerRetry() {
        proposeRetry()
    }

    func menuBarDidTriggerDeleteSavedRecordings() {
        deleteSavedRecordings()
    }

    func menuBarDidTriggerSetAPIKey() {
        guard flow.state == .idle else { return }
        setAPIKey()
    }

    func menuBarDidSelect(shortcut: HotKeyShortcut) {
        guard flow.state == .idle else { return }
        guard shortcut != Config.shortcut else { return }
        if registerHotKey(announce: false, shortcut: shortcut) {
            Config.settings.shortcut = shortcut
            dictationPanel.setShortcut(shortcut.displayName)
        }
    }

    func menuBarDidSelect(model: TranscriptionModel) {
        guard flow.state == .idle else { return }
        guard model != Config.model else { return }
        Config.settings.model = model
        AppLog.write("Transcription model changed to \(model.rawValue)")
    }

    func menuBarDidSelect(language: String?) {
        guard flow.state == .idle else { return }
        guard language != Config.language else { return }
        Config.settings.language = language
        AppLog.write("Transcription language changed to \(language ?? "auto")")
    }

    var menuBarShortcut: HotKeyShortcut { Config.shortcut }
    var menuBarModel: TranscriptionModel { Config.model }
    var menuBarLanguage: String? { Config.language }
}
