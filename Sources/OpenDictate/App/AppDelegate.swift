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
    private var modifierMonitor: ModifierKeyMonitor?
    /// Listens only while the first-launch question checks a single key.
    private var testMonitor: ModifierKeyMonitor?
    private var keyPermissionWatch: Task<Void, Never>?
    private var holdControl = HoldControl.none
    private let recorder = AudioRecorder()
    private let transcriber = OpenAITranscriber()
    private let translator = OpenAITranslator()
    private let pasteboard = PasteboardInserter()
    private var previousApplication: NSRunningApplication?
    private var latestExternalApplication: NSRunningApplication?
    private var lastHotKeyAt = Date.distantPast
    private var autoStopTask: Task<Void, Never>?
    private var retentionTask: Task<Void, Never>?
    private let lifecycle = AppLifecycle()
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
                    return await pasteboard.paste(text, into: previousApplication)
                },
                translationTarget: { [unowned self] in requestOptions?.translationTarget },
                translate: { [unowned self] in
                    try await translator.translate($0, into: $1, options: requestOptions)
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
        AppLog.write("Build identity: \(AppVersionInfo().summary)")
        AppLog.write("Transcription model: \(Config.model.rawValue) (from \(Config.settings.modelSource))")
        AppLog.write(
            "Translation: \(Config.settings.translationTarget ?? "off") (model \(Config.settings.translationModel))")
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
            guard let self, !lifecycle.isTerminating else { return }
            dictationPanel.update(outcome: outcome, transcript: flow.lastTranscript)
        }
        flow.onState = { [weak self] state in
            guard let self else { return }
            if state != .recording { cancelAutoStop() }
            if state == .idle {
                requestOptions = nil
                refreshSavedRecordings()
            }
            guard !lifecycle.isTerminating else { return }
            menuBar?.updateState(state)
            dictationPanel.update(state: state)
        }
        recorder.onUnexpectedStop = { [weak self] in
            self?.stopRecordingAutomatically()
        }
        retentionTask = Task { @MainActor in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) } catch { break }
                refreshSavedRecordings()
            }
        }
        refreshSavedRecordings()
        warnAboutUnusableModelIfNeeded()
        activateTrigger(Config.trigger, announce: true)
        checkAPIKeySetupAtLaunch()
        if ProcessInfo.processInfo.arguments.contains("--show-window") {
            dictationPanel.showForInteraction()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard lifecycle.acceptsActions else { return true }
        if menuBar?.reopenSettingsIfVisible() == true { return true }
        dictationPanel.showForInteraction()
        return true
    }

    private func configureMenuBar() {
        let controller = MenuBarController(delegate: self)
        controller.onShowSettings = { [weak self] in self?.dictationPanel.window?.orderOut(nil) }
        controller.onShowDaily = { [weak self] anchor in
            guard let self, lifecycle.acceptsActions else { return }
            dictationPanel.showForInteraction(near: anchor)
        }
        controller.install()
        menuBar = controller
    }

    private func configureDictationPanel() {
        dictationPanel.setShortcut(Config.trigger.displayName)
        dictationPanel.onRecord = { [weak self] in
            guard let self, lifecycle.canBeginOperation else { return }
            let target = flow.state.canStop ? previousApplication : latestExternalApplication
            toggleRecording(target: target, returnPanelFocus: true)
        }
        dictationPanel.onCancel = { [weak self] in self?.menuBarDidCancel(discard: false) }
        dictationPanel.onCopy = { [weak self] in self?.menuBarDidCopyLastText() }
        dictationPanel.onSetup = { [weak self] in self?.setAPIKey() }
        dictationPanel.onSettings = { [weak self] in
            guard let self, lifecycle.acceptsActions else { return }
            menuBar?.showSettings()
        }
        dictationPanel.onActions = { [weak self] view in
            guard let self, lifecycle.acceptsActions else { return }
            menuBar?.showRecordingActions(at: view)
        }
        dictationPanel.onRecovery = { [weak self] in
            guard let self, lifecycle.acceptsActions else { return }
            lifecycle.cancelPreparation()
            pendingRetryFilename = nil
            menuBar?.showRecordings()
        }
        dictationPanel.onRetry = { [weak self] in
            guard let self, flow.state.canRetry, let filename = pendingRetryFilename,
                let operation = lifecycle.beginOperation()
            else { return }
            pendingRetryFilename = nil
            Task { @MainActor in await retryLastRecording(filename: filename, operation: operation) }
        }
    }

    private func proposeRetry(filename: String? = nil) {
        guard flow.state.canRetry, lifecycle.canBeginOperation,
            let entry = savedRecordings.first(where: { $0.retryable && (filename == nil || $0.filename == filename) })
        else { return }
        pendingRetryFilename = entry.filename
        dictationPanel.confirmRetry(description: entry.created.formatted(date: .abbreviated, time: .shortened))
    }

    // MARK: - Hotkey

    /// What a hold of the single-key trigger is responsible for.
    private enum HoldControl {
        case none
        /// The hold began this dictation; the operation is set while it prepares.
        case starting(AppLifecycle.Operation)
        /// A dictation was already running; releasing the key stops it.
        case stopsRecording
    }

    /// Makes `trigger` the active way to start and stop dictation. The working
    /// registration stays in place when the new one cannot be installed.
    @discardableResult
    private func activateTrigger(_ trigger: RecordingTrigger, announce: Bool) -> Bool {
        // A pending watch means the status still warns about the replaced
        // single key's missing permission.
        let replacesKeyWarning = keyPermissionWatch != nil
        switch trigger {
        case .combination(let shortcut):
            guard registerHotKey(announce: announce, shortcut: shortcut) else { return false }
            stopModifierMonitor()
            if replacesKeyWarning, !announce, flow.state == .idle { updateStatus("Bereit") }
        case .modifierKey(let key):
            let monitor = ModifierKeyMonitor(key: key) { [weak self] in self?.handleModifierGesture($0) }
            guard monitor.start() else {
                updateStatus("Tastenkombination nicht verfügbar")
                AppLog.write("Single-key monitor could not be installed: \(key.rawValue)")
                AlertPresenter.showWarning(
                    title: "Tastenkürzel nicht verfügbar",
                    message: "OpenDictate kann „\(key.displayName)“ gerade nicht überwachen. "
                        + "Die bisherige Einstellung bleibt aktiv.")
                return false
            }
            stopModifierMonitor()
            modifierMonitor = monitor
            hotKey.unregisterCurrent()
            AppLog.write("Single-key trigger active: \(key.rawValue)")
            if ModifierKeyMonitor.hasPermission {
                if announce || (replacesKeyWarning && flow.state == .idle) { updateStatus("Bereit") }
            } else {
                updateStatus("Freigabe für Bedienungshilfen fehlt – Taste wird nicht erkannt")
                watchForKeyPermission()
            }
        }
        return true
    }

    private func stopModifierMonitor() {
        modifierMonitor?.stop()
        modifierMonitor = nil
        keyPermissionWatch?.cancel()
        keyPermissionWatch = nil
        holdControl = .none
    }

    /// Key events reach a global monitor only once the app is trusted. Re-arm
    /// as soon as the permission appears, since monitors installed before the
    /// grant may stay silent.
    private func watchForKeyPermission() {
        keyPermissionWatch?.cancel()
        keyPermissionWatch = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                guard let self, let monitor = modifierMonitor else { return }
                guard ModifierKeyMonitor.hasPermission else { continue }
                keyPermissionWatch = nil
                monitor.start()
                AppLog.write("Accessibility granted; single-key trigger re-armed")
                if flow.state == .idle { updateStatus("Bereit") }
                return
            }
        }
    }

    private func handleModifierGesture(_ gesture: ModifierKeyGesture.Gesture) {
        guard lifecycle.acceptsActions else { return }
        switch gesture {
        case .tap:
            toggleRecording()
        case .holdBegan:
            if flow.state.canStop {
                holdControl = .stopsRecording
            } else if let operation = startRecording(target: currentFrontmostApplication()) {
                lastHotKeyAt = Date()
                holdControl = .starting(operation)
            } else {
                holdControl = .none
            }
        case .holdEnded, .holdInterrupted:
            let control = holdControl
            holdControl = .none
            switch control {
            case .none:
                return
            case .starting(let operation):
                if lifecycle.isCurrent(operation) {
                    // Released before the recorder started: drop the preparation.
                    lifecycle.cancelPreparation()
                    return
                }
                guard flow.state == .recording else { return }
                if gesture == .holdInterrupted {
                    // Another key joined the hold, so it was not meant as dictation.
                    // Cancelling keeps the audio for a manual retry.
                    AppLog.write("Hold interrupted by another input; recording cancelled")
                    menuBarDidCancel(discard: false)
                } else {
                    stopRecording()
                }
            case .stopsRecording:
                if gesture == .holdEnded, flow.state == .recording { stopRecording() }
            }
        }
    }

    @discardableResult
    private func registerHotKey(announce: Bool, shortcut: HotKeyShortcut) -> Bool {
        do {
            try hotKey.register(shortcut) { [weak self] in
                // Carbon dispatches the application event target on the main
                // event loop. Admit the action before a modal can finish.
                MainActor.assumeIsolated {
                    self?.toggleRecording()
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

    private func toggleRecording(target: NSRunningApplication? = nil, returnPanelFocus: Bool = false) {
        guard lifecycle.canBeginOperation else { return }
        let capturedTarget = target ?? currentFrontmostApplication()
        let now = Date()
        guard now.timeIntervalSince(lastHotKeyAt) > 0.35 else { return }
        lastHotKeyAt = now
        if flow.state.canStop {
            if returnPanelFocus { returnFocusFromPanel(to: capturedTarget) }
            stopRecording()
            return
        }
        startRecording(target: capturedTarget, returnPanelFocus: returnPanelFocus)
    }

    /// Begins preparing a dictation for `target`. Returns the operation while it
    /// prepares, or nil when nothing could start.
    @discardableResult
    private func startRecording(
        target: NSRunningApplication?, returnPanelFocus: Bool = false
    ) -> AppLifecycle.Operation? {
        guard flow.state.canStart, let operation = lifecycle.beginOperation() else { return nil }
        guard lifecycle.isCurrent(operation) else { return nil }
        if returnPanelFocus { returnFocusFromPanel(to: target) }
        Task { @MainActor in
            await prepareRecording(target: target, operation: operation)
        }
        return operation
    }

    private func stopRecording() {
        if flow.stop() { cancelAutoStop() }
    }

    private func returnFocusFromPanel(to target: NSRunningApplication?) {
        // Only an explicit panel action uses this focus-return path. Delivery
        // applies its separate activation and validation rules in PasteboardInserter.
        guard currentFrontmostApplication() == nil, let target, !target.isTerminated,
            PanelTargetPolicy.canReturnFocus(
                target: target.processIdentifier,
                latestExternal: latestExternalApplication?.processIdentifier)
        else { return }
        target.activate()
    }

    private func prepareRecording(
        target: NSRunningApplication?, operation: AppLifecycle.Operation
    ) async {
        defer { lifecycle.finish(operation) }
        guard lifecycle.isCurrent(operation), !Task.isCancelled, flow.state.canStart else { return }
        guard hasAPIKey(for: operation) else { return }
        guard Config.model.isUsableForUpload else {
            warnAboutUnusableModelIfNeeded()
            return
        }
        let permitted = await AudioRecorder.requestPermission()
        guard lifecycle.isCurrent(operation), !Task.isCancelled else { return }
        guard permitted else {
            AppLog.write("Recording did not start: microphone access denied")
            updateStatus("Mikrofonzugriff fehlt – in den Systemeinstellungen erlauben")
            dictationPanel.updateFailure(
                "Mikrofonzugriff fehlt. Öffne die Systemeinstellungen und erlaube den Zugriff.")
            return
        }
        do {
            let options = try TranscriptionOptions.current()
            try lifecycle.commit(operation) {
                guard flow.state.canStart else { return }
                requestOptions = options
                previousApplication = target
                if try flow.start() {
                    pendingRetryFilename = nil
                    scheduleAutoStop()
                }
            }
        } catch {
            if flow.state == .idle {
                requestOptions = nil
            }
            AppLog.write("Recording did not start: \(error.localizedDescription)")
            guard lifecycle.isCurrent(operation), !Task.isCancelled else { return }
            updateStatus(OpenDictateError.userMessage(for: error))
            dictationPanel.updateFailure(
                "Die Aufnahme konnte nicht gestartet werden. Prüfe Mikrofon und Berechtigungen.")
        }
    }

    private func refreshSavedRecordings() {
        guard !lifecycle.isTerminating else { return }
        guard snapshotTask == nil else {
            snapshotNeedsRefresh = true
            return
        }
        snapshotTask = Task { @MainActor in
            let recordings = await recordingLibrary.snapshot()
            snapshotTask = nil
            guard !Task.isCancelled, !lifecycle.isTerminating else { return }
            savedRecordings = recordings
            menuBar?.refresh()
            if snapshotNeedsRefresh {
                snapshotNeedsRefresh = false
                refreshSavedRecordings()
            }
        }
    }

    private func retryLastRecording(filename: String, operation: AppLifecycle.Operation) async {
        defer { lifecycle.finish(operation) }
        guard lifecycle.isCurrent(operation), !Task.isCancelled, flow.state.canRetry else { return }
        guard hasAPIKey(for: operation) else { return }
        let target = currentFrontmostApplication()
        let loaded = await recordingLibrary.load(filename: filename)
        guard lifecycle.isCurrent(operation), !Task.isCancelled else { return }
        guard let payload = loaded else {
            updateStatus("Keine gültige Aufnahme zum Wiederholen")
            refreshSavedRecordings()
            return
        }
        do {
            let options = try TranscriptionOptions.current()
            lifecycle.commit(operation) {
                guard flow.state.canRetry else { return }
                requestOptions = options
                previousApplication = target
                _ = flow.retry(payload)
            }
        } catch {
            guard lifecycle.isCurrent(operation), !Task.isCancelled else { return }
            updateStatus(OpenDictateError.userMessage(for: error))
        }
    }

    private func hasAPIKey(for operation: AppLifecycle.Operation) -> Bool {
        apiKeyPresenceTask?.cancel()
        apiKeyPresenceTask = nil
        let available = Config.apiKey != nil
        guard lifecycle.isCurrent(operation) else { return false }
        if available {
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
        return false
    }

    private func checkAPIKeySetupAtLaunch() {
        apiKeyPresenceTask = Task { @MainActor [weak self] in
            let needsSetup = await Task.detached(priority: .utility) {
                KeychainAPIKeyStore.needsSetup
            }.value
            guard let self, !Task.isCancelled, lifecycle.acceptsActions else { return }
            apiKeyPresenceTask = nil
            apiKeyNeedsSetup = needsSetup
            menuBar?.refresh()
            if needsSetup {
                menuBar?.updateStatus("API-Schlüssel einrichten")
                dictationPanel.updateAPIKeySetup(needsSetup: true)
            } else {
                if !Config.settings.hasStoredTrigger, flow.state == .idle, let operation = lifecycle.beginOperation() {
                    defer { lifecycle.finish(operation) }
                    askForTrigger(operation: operation)
                }
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
                    stopRecordingAutomatically()
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

    private func stopRecordingAutomatically() {
        lifecycle.automaticStop { [weak self] in _ = self?.flow.stop() }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let result = lifecycle.requestTermination(
            hasActiveDictation: flow.state != .idle,
            confirm: AlertPresenter.confirmQuitWithActiveDictation,
            cancel: {
                self.cancelAutoStop()
                self.flow.cancel()
                return self.flow.task
            }, reply: { sender.reply(toApplicationShouldTerminate: true) })
        if lifecycle.isTerminating { stopBackgroundCallbacks() }
        switch result {
        case .now: return .terminateNow
        case .later: return .terminateLater
        case .cancel: return .terminateCancel
        }
    }

    private func stopBackgroundCallbacks() {
        cancelAutoStop()
        retentionTask?.cancel()
        retentionTask = nil
        apiKeyPresenceTask?.cancel()
        apiKeyPresenceTask = nil
        snapshotTask?.cancel()
        snapshotTask = nil
        snapshotNeedsRefresh = false
        pendingRetryFilename = nil
        recorder.onUnexpectedStop = nil
        stopModifierMonitor()
    }

    func applicationWillTerminate(_ notification: Notification) {
        lifecycle.finishTermination()
        stopBackgroundCallbacks()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        flow.clearLastTranscript()
    }

    @objc private func applicationActivated(_ notification: Notification) {
        guard !lifecycle.isTerminating,
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
            app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else { return }
        latestExternalApplication = app
    }

    private func currentFrontmostApplication() -> NSRunningApplication? {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let app = NSWorkspace.shared.frontmostApplication
        return app?.processIdentifier == currentPID ? nil : app
    }

    private func requestAccessibilityPermissionIfNeeded() {
        guard lifecycle.acceptsActions, flow.state == .idle,
            Config.settings.autoPaste || Config.trigger.needsAccessibility, !AXIsProcessTrusted()
        else {
            return
        }
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
        guard !lifecycle.isTerminating else { return }
        menuBar?.updateStatus(value)
        dictationPanel.setStatus(value)
    }

    private func setAPIKey() {
        guard flow.state == .idle, let operation = lifecycle.beginOperation() else { return }
        // The modal runs a nested event loop; a hotkey must not start a dictation
        // while credential setup has temporarily moved focus away from its target.
        defer {
            lifecycle.finish(operation)
            if !lifecycle.isTerminating { menuBar?.refresh() }
        }
        apiKeyPresenceTask?.cancel()
        apiKeyPresenceTask = nil
        let previousKey = Config.apiKey
        guard lifecycle.isCurrent(operation) else { return }
        let settingUp = previousKey == nil || dictationPanel.display == .setup
        if settingUp {
            apiKeyNeedsSetup = true
            dictationPanel.updateAPIKeySetup(needsSetup: true)
        }
        let entered = AlertPresenter.promptForAPIKey(initialValue: previousKey)
        guard lifecycle.isCurrent(operation) else { return }
        guard let key = entered else {
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
            let result = try KeychainAPIKeyStore.save(key)
            guard lifecycle.isCurrent(operation) else { return }
            apiKeyNeedsSetup = false
            menuBar?.updateStatus("API-Schlüssel gespeichert")
            if settingUp {
                dictationPanel.updateAPIKeySetup(needsSetup: false)
                menuBar?.showDaily()
            }
            AppLog.write("API key saved to Keychain")
            if case .savedWithLegacyCleanupPending(let status) = result {
                AppLog.write("API key legacy cleanup pending: \(status)")
                AlertPresenter.showWarning(
                    title: "API-Schlüssel gespeichert",
                    message:
                        "Der neue Schlüssel ist gespeichert. Der alte Keychain-Eintrag konnte "
                        + "noch nicht entfernt werden. Speichere den Schlüssel erneut über diesen "
                        + "Dialog, um die Bereinigung zu wiederholen.")
                guard lifecycle.isCurrent(operation) else { return }
            }
            if settingUp, !Config.settings.hasStoredTrigger { askForTrigger(operation: operation) }
            requestAccessibilityPermissionIfNeeded()
        } catch {
            guard lifecycle.isCurrent(operation) else { return }
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
        guard flow.state == .idle, let operation = lifecycle.beginOperation() else { return }
        defer { lifecycle.finish(operation) }
        let count = FailedRecordingStore.storedFileCount
        guard count > 0, AlertPresenter.confirmDeleteSavedRecordings(count: count),
            lifecycle.isCurrent(operation)
        else { return }
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
        guard flow.state == .idle, let operation = lifecycle.beginOperation() else { return }
        defer { lifecycle.finish(operation) }
        if let shortcut = ShortcutCaptureView.prompt(), lifecycle.isCurrent(operation) {
            applyTrigger(.combination(shortcut), operation: operation)
            menuBar?.refresh()
        }
    }

    func menuBarDidConfigureVocabulary() {
        guard flow.state == .idle, let operation = lifecycle.beginOperation() else { return }
        defer { lifecycle.finish(operation) }
        guard let value = AlertPresenter.promptForVocabulary(initialValue: Config.prompt),
            lifecycle.isCurrent(operation)
        else { return }
        guard value.count <= 2000 else {
            updateStatus("Vokabular nicht gespeichert: maximal 2.000 Zeichen")
            return
        }
        Config.settings.prompt = value
        updateStatus("Vokabular gespeichert")
    }

    func menuBarDidCancel(discard: Bool) {
        lifecycle.cancelDictation {
            pendingRetryFilename = nil
            flow.cancel(discardRecording: discard)
        }
    }
    func menuBarDidCopyLastText() {
        guard lifecycle.canBeginOperation, flow.state == .idle else { return }
        _ = flow.copyLastTranscript()
    }
    func menuBarDidClearLastText() {
        guard lifecycle.canBeginOperation, flow.state == .idle else { return }
        flow.clearLastTranscript()
        dictationPanel.clearText()
    }
    func menuBarDidToggleAutoPaste() {
        guard flow.state == .idle, let operation = lifecycle.beginOperation() else { return }
        defer { lifecycle.finish(operation) }
        Config.settings.autoPaste.toggle()
        menuBar?.showSettings()
        requestAccessibilityPermissionIfNeeded()
    }
    var menuBarRecordings: [SavedRecording] { savedRecordings }
    func menuBarDidRetry(filename: String) { proposeRetry(filename: filename) }
    func menuBarDidDelete(filename: String) {
        guard flow.state == .idle, let operation = lifecycle.beginOperation() else { return }
        Task { @MainActor in
            defer { lifecycle.finish(operation) }
            guard lifecycle.isCurrent(operation), !Task.isCancelled else { return }
            guard AlertPresenter.confirmDeleteSavedRecordings(count: 1), lifecycle.isCurrent(operation) else { return }
            await recordingLibrary.delete(filename: filename)
            guard lifecycle.isCurrent(operation), !Task.isCancelled else { return }
            refreshSavedRecordings()
        }
    }
    var menuBarState: DictationState { flow.state }
    var menuBarHasTranscript: Bool { flow.lastTranscript != nil }
    var menuBarAutoPaste: Bool { Config.settings.autoPaste }
    var menuBarNeedsAPIKeySetup: Bool { apiKeyNeedsSetup }

    func menuBarDidTriggerToggleRecording() {
        guard lifecycle.acceptsActions else { return }
        AppLog.write("Start/Stop Recording selected from menu")
        toggleRecording()
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

    func menuBarDidSelect(trigger: RecordingTrigger) {
        guard flow.state == .idle, let operation = lifecycle.beginOperation() else { return }
        defer { lifecycle.finish(operation) }
        if trigger.needsAccessibility, !ModifierKeyMonitor.hasPermission {
            // Switching now would leave no working key until the permission arrives.
            AlertPresenter.explainMissingKeyPermission(for: trigger, keeping: Config.trigger)
            return
        }
        applyTrigger(trigger, operation: operation)
    }

    private func applyTrigger(_ trigger: RecordingTrigger, operation: AppLifecycle.Operation) {
        guard trigger != Config.trigger else { return }
        if activateTrigger(trigger, announce: false), lifecycle.isCurrent(operation) {
            Config.settings.trigger = trigger
            dictationPanel.setShortcut(trigger.displayName)
            AppLog.write("Recording trigger changed to \(trigger.displayName)")
        }
    }

    /// First-launch question. Closing it keeps and stores the current trigger,
    /// so it is asked only once.
    private func askForTrigger(operation: AppLifecycle.Operation) {
        let previous = Config.trigger
        let tester = ShortcutSetupPrompt.Tester(
            arm: { [unowned self] trigger, arrived in armForTest(trigger, arrived: arrived) },
            disarm: { [unowned self] in
                testMonitor?.stop()
                testMonitor = nil
                // The check may have borrowed the hotkey manager; give it back.
                switch Config.trigger {
                case .combination(let shortcut): registerHotKey(announce: false, shortcut: shortcut)
                case .modifierKey: hotKey.unregisterCurrent()
                }
            })
        let chosen = ShortcutSetupPrompt.run(tester: tester)
        guard lifecycle.isCurrent(operation) else { return }
        guard let chosen, chosen != previous else {
            Config.settings.trigger = previous
            AppLog.write("First-launch shortcut question closed; keeping \(previous.displayName)")
            return
        }
        applyTrigger(chosen, operation: operation)
        if Config.trigger != chosen {
            // Activation failed and already explained itself; keep the previous one.
            Config.settings.trigger = previous
        }
        menuBar?.refresh()
    }

    /// Listens for `trigger` without starting a dictation. A combination is
    /// registered on the real hotkey manager so a conflict shows up exactly as
    /// it would in daily use.
    private func armForTest(
        _ trigger: RecordingTrigger, arrived: @escaping () -> Void
    ) -> ShortcutSetupPrompt.ArmResult {
        testMonitor?.stop()
        testMonitor = nil
        switch trigger {
        case .combination(let shortcut):
            do {
                try hotKey.register(shortcut) { MainActor.assumeIsolated { arrived() } }
                return .listening
            } catch {
                AppLog.write("Shortcut check could not register: \(error.localizedDescription)")
                return .failed("Diese Kombination ist belegt oder nicht verfügbar.")
            }
        case .modifierKey(let key):
            let monitor = ModifierKeyMonitor(key: key) { _ in }
            // This window's own events arrive even without the permission; only
            // count a press once other apps would deliver it too.
            monitor.onPress = { if ModifierKeyMonitor.hasPermission { arrived() } }
            guard monitor.start() else { return .failed("OpenDictate kann diese Taste gerade nicht überwachen.") }
            testMonitor = monitor
            guard ModifierKeyMonitor.hasPermission else {
                ModifierKeyMonitor.requestPermission()
                return .needsPermission
            }
            return .listening
        }
    }

    func menuBarDidSelect(model: TranscriptionModel) {
        guard lifecycle.canBeginOperation, flow.state == .idle else { return }
        guard model != Config.model else { return }
        Config.settings.model = model
        AppLog.write("Transcription model changed to \(model.rawValue)")
    }

    func menuBarDidSelect(language: String?) {
        guard lifecycle.canBeginOperation, flow.state == .idle else { return }
        guard language != Config.language else { return }
        Config.settings.language = language
        AppLog.write("Transcription language changed to \(language ?? "auto")")
    }

    func menuBarDidSelect(translationTarget: String?) {
        guard lifecycle.canBeginOperation, flow.state == .idle else { return }
        guard translationTarget != Config.settings.translationTarget else { return }
        Config.settings.translationTarget = translationTarget
        AppLog.write("Translation target changed to \(translationTarget ?? "off")")
    }

    var menuBarTrigger: RecordingTrigger { Config.trigger }
    var menuBarModel: TranscriptionModel { Config.model }
    var menuBarLanguage: String? { Config.language }
    var menuBarTranslationTarget: String? { Config.settings.translationTarget }
}
