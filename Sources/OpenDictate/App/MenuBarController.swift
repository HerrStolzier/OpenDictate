import AppKit
import Foundation
import OpenDictateCore

@MainActor
protocol MenuBarControllerDelegate: AnyObject {
    func menuBarDidConfigureShortcut()
    func menuBarDidConfigureVocabulary()
    func menuBarDidCancel(discard: Bool)
    func menuBarDidCopyLastText()
    func menuBarDidClearLastText()
    func menuBarDidToggleAutoPaste()
    var menuBarRecordings: [SavedRecording] { get }
    func menuBarDidRetry(filename: String)
    func menuBarDidDelete(filename: String)
    var menuBarState: DictationState { get }
    var menuBarHasTranscript: Bool { get }
    var menuBarAutoPaste: Bool { get }
    func menuBarDidTriggerToggleRecording()
    func menuBarDidTriggerRetry()
    func menuBarDidTriggerDeleteSavedRecordings()
    func menuBarDidTriggerSetAPIKey()
    func menuBarDidSelect(shortcut: HotKeyShortcut)
    func menuBarDidSelect(model: TranscriptionModel)
    func menuBarDidSelect(language: String?)

    var menuBarShortcut: HotKeyShortcut { get }
    var menuBarModel: TranscriptionModel { get }
    var menuBarLanguage: String? { get }
}

/// Owns the status bar item and its menu. Knows nothing about recording or
/// transcription; it asks the delegate for current state and reports what the
/// user picked.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    /// The models offered in the menu. Everything else still works through
    /// OPENAI_TRANSCRIBE_MODEL, this is just the short list worth one click.
    private static let offeredModels: [TranscriptionModel] = [.gptTranscribe, .gpt4oMiniTranscribe]

    /// Menu title and stored value. nil means let the API detect the language.
    private static let offeredLanguages: [(title: String, code: String?)] = [
        ("Automatisch", nil),
        ("Deutsch", "de"),
        ("Englisch", "en")
    ]

    private var isMenuOpen = false
    private weak var delegate: MenuBarControllerDelegate?
    private var recordingsMenuItem: NSMenuItem?
    private var recordingMenuItem: NSMenuItem?
    private var cancelMenuItem: NSMenuItem?
    private var discardMenuItem: NSMenuItem?
    private var copyLastMenuItem: NSMenuItem?
    private var clearLastMenuItem: NSMenuItem?
    private var autoPasteMenuItem: NSMenuItem?
    private var statusItem: NSStatusItem?
    private var statusMenuItem: NSMenuItem?
    private var inputDeviceMenuItem: NSMenuItem?
    private var retryMenuItem: NSMenuItem?
    private var deleteRecordingsMenuItem: NSMenuItem?
    private var shortcutMenuItem: NSMenuItem?
    private var modelMenuItem: NSMenuItem?
    private var languageMenuItem: NSMenuItem?

    init(delegate: MenuBarControllerDelegate) {
        self.delegate = delegate
        super.init()
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = Self.makeStatusBarImage()
            button.imagePosition = .imageOnly
            button.toolTip = "OpenDictate: Bereit"
        }

        let menu = NSMenu()
        menu.autoenablesItems = false

        let statusMenuItem = NSMenuItem(title: "Status: Bereit", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        let shortcutItem = NSMenuItem(title: "Tastenkombination", action: nil, keyEquivalent: "")
        shortcutItem.submenu = makeShortcutSubmenu()
        menu.addItem(shortcutItem)
        self.shortcutMenuItem = shortcutItem
        let customShortcut = makeActionItem("Eigene Tastenkombination …", action: #selector(configureShortcut))
        shortcutItem.submenu?.addItem(.separator())
        shortcutItem.submenu?.addItem(customShortcut)

        let modelItem = NSMenuItem(title: "Modell", action: nil, keyEquivalent: "")
        modelItem.submenu = makeModelSubmenu()
        menu.addItem(modelItem)
        self.modelMenuItem = modelItem

        let languageItem = NSMenuItem(title: "Sprache", action: nil, keyEquivalent: "")
        languageItem.submenu = makeLanguageSubmenu()
        menu.addItem(languageItem)
        self.languageMenuItem = languageItem
        let vocabulary = makeActionItem("Vokabular und Kontext …", action: #selector(configureVocabulary))
        menu.addItem(vocabulary)

        menu.addItem(
            NSMenuItem(
                title: "Maximale Aufnahme: \(Int(Config.maximumRecordingDuration)) Sekunden", action: nil,
                keyEquivalent: ""))

        let inputDeviceItem = makeActionItem(
            "Mikrofon: –",
            action: #selector(openSoundSettings),
            toolTip: "Aktuelles Systemmikrofon. Klicken öffnet die Toneinstellungen."
        )
        menu.addItem(inputDeviceItem)
        self.inputDeviceMenuItem = inputDeviceItem

        menu.addItem(.separator())

        let recordingItem = makeActionItem("Aufnahme starten/stoppen", action: #selector(toggleRecording))
        menu.addItem(recordingItem)
        recordingMenuItem = recordingItem
        func actionItem(_ title: String, _ action: Selector) -> NSMenuItem {
            let item = makeActionItem(title, action: action)
            menu.addItem(item)
            return item
        }
        cancelMenuItem = actionItem("Abbrechen und Aufnahme behalten", #selector(cancelOperation))
        discardMenuItem = actionItem("Aktuelle Aufnahme verwerfen", #selector(discardOperation))
        copyLastMenuItem = actionItem("Letzten Text erneut kopieren", #selector(copyLastText))
        clearLastMenuItem = actionItem("Letzten Text aus Speicher löschen", #selector(clearLastText))
        autoPasteMenuItem = actionItem("Automatisch einfügen", #selector(toggleAutoPaste))

        let retryItem = makeActionItem(
            "Letzte Aufnahme wiederholen",
            action: #selector(retryLastRecording),
            toolTip: "Die neueste gültige Aufnahme bewusst erneut an OpenAI senden."
        )
        menu.addItem(retryItem)
        self.retryMenuItem = retryItem
        let recordingsItem = NSMenuItem(title: "Gespeicherte Aufnahmen", action: nil, keyEquivalent: "")
        recordingsItem.submenu = NSMenu()
        menu.addItem(recordingsItem)
        recordingsMenuItem = recordingsItem

        let deleteRecordingsItem = makeActionItem(
            "Gespeicherte Aufnahmen löschen …",
            action: #selector(deleteSavedRecordings),
            toolTip: "Aufbewahrte Aufnahmen endgültig löschen."
        )
        menu.addItem(deleteRecordingsItem)
        self.deleteRecordingsMenuItem = deleteRecordingsItem

        let apiKeyItem = makeActionItem("API-Schlüssel einrichten …", action: #selector(setAPIKey))
        menu.addItem(apiKeyItem)
        let accessibilityItem = makeActionItem("Bedienungshilfen öffnen", action: #selector(openAccessibilitySettings))
        menu.addItem(accessibilityItem)
        let logItem = makeActionItem("Protokoll öffnen", action: #selector(openLog))
        menu.addItem(logItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        menu.delegate = self
        item.menu = menu
        self.statusMenuItem = statusMenuItem
        refresh()
        statusItem = item
    }

    func updateStatus(_ value: String) {
        statusMenuItem?.title = "Status: \(value)"
        statusItem?.button?.toolTip = "OpenDictate: \(value)"
        statusItem?.button?.setAccessibilityLabel("OpenDictate: \(value)")
    }

    func updateState(_ state: DictationState, elapsed: Double = 0, level: Float = -160) {
        let symbol: String
        switch state {
        case .idle: symbol = "mic"
        case .recording: symbol = "record.circle.fill"
        case .processing: symbol = "ellipsis.circle"
        case .delivering: symbol = "doc.on.clipboard"
        }
        statusItem?.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        statusItem?.button?.image?.isTemplate = true
        statusItem?.button?.imagePosition = .imageLeading
        statusItem?.button?.title = state == .recording ? " \(Int(elapsed)) s" : ""
        if state == .recording {
            let remaining = max(0, Int(Config.maximumRecordingDuration - elapsed))
            let warning = remaining <= 10 ? " – noch \(remaining) s" : ""
            updateStatus("Aufnahme \(Int(elapsed)) s, Pegel \(Int(level)) dB\(warning)")
        }
        refreshActions()
    }

    private func refreshActions() {
        let state = delegate?.menuBarState ?? .idle
        recordingMenuItem?.title = state == .recording ? "Aufnahme stoppen" : "Aufnahme starten"
        recordingMenuItem?.isEnabled = state == .idle || state == .recording
        cancelMenuItem?.isEnabled = state != .idle
        discardMenuItem?.isEnabled = state == .recording
        copyLastMenuItem?.isEnabled = delegate?.menuBarHasTranscript ?? false
        clearLastMenuItem?.isEnabled = delegate?.menuBarHasTranscript ?? false
        autoPasteMenuItem?.state = delegate?.menuBarAutoPaste == true ? .on : .off
    }

    /// Re-reads everything that can change while the app runs.
    func refresh() {
        guard !isMenuOpen else { return }
        refreshActions()
        refreshInputDeviceMenuItem()
        refreshRetryMenuItem()
        refreshSelections()
        refreshRecordings()
    }

    private func refreshRecordings() {
        guard let menu = recordingsMenuItem?.submenu else { return }
        menu.removeAllItems()
        let available = delegate?.menuBarState == .idle
        for entry in delegate?.menuBarRecordings ?? [] {
            let duration = entry.duration.map { " · \(Int($0)) s" } ?? ""
            let item = NSMenuItem(
                title: entry.created.formatted(date: .abbreviated, time: .standard) + duration,
                action: nil,
                keyEquivalent: ""
            )
            let submenu = NSMenu()
            submenu.autoenablesItems = false
            let retry = makeActionItem(
                entry.retryable ? "Wiederholen" : "Nicht zur Wiederholung verfügbar",
                action: #selector(retrySelected(_:))
            )
            retry.representedObject = entry.filename
            retry.isEnabled = available && entry.retryable
            submenu.addItem(retry)
            let delete = makeActionItem("Diese Aufnahme löschen …", action: #selector(deleteSelected(_:)))
            delete.representedObject = entry.filename
            delete.isEnabled = available
            submenu.addItem(delete)
            item.submenu = submenu
            menu.addItem(item)
        }
        recordingsMenuItem?.isEnabled = !menu.items.isEmpty
    }

    @objc private func retrySelected(_ sender: NSMenuItem) {
        if let name = sender.representedObject as? String { delegate?.menuBarDidRetry(filename: name) }
    }
    @objc private func deleteSelected(_ sender: NSMenuItem) {
        if let name = sender.representedObject as? String { delegate?.menuBarDidDelete(filename: name) }
    }

    // MARK: - Submenus

    private func makeShortcutSubmenu() -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for preset in HotKeyShortcut.presets {
            let item = makeActionItem(preset.displayName, action: #selector(selectShortcut(_:)))
            item.representedObject = preset.displayName
            submenu.addItem(item)
        }
        return submenu
    }

    private func makeModelSubmenu() -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for model in Self.offeredModels {
            let price = model.pricePerMinuteUSD.map { String(format: " ($%.4f/min)", $0) } ?? ""
            let item = makeActionItem("\(model.rawValue)\(price)", action: #selector(selectModel(_:)))
            item.representedObject = model.rawValue
            submenu.addItem(item)
        }
        return submenu
    }

    private func makeLanguageSubmenu() -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for option in Self.offeredLanguages {
            let item = makeActionItem(option.title, action: #selector(selectLanguage(_:)))
            item.representedObject = option.code ?? Settings.automaticLanguage
            submenu.addItem(item)
        }
        return submenu
    }

    // MARK: - Refresh

    private func refreshInputDeviceMenuItem() {
        guard let inputDeviceMenuItem else { return }
        let input = AudioInput.current()
        let name = input?.name ?? "Unbekannt"
        let suffix = (input?.isBluetooth ?? false) ? " (Bluetooth)" : ""
        inputDeviceMenuItem.title = "Mikrofon: \(name)\(suffix)"
    }

    private func refreshRetryMenuItem() {
        let state = delegate?.menuBarState ?? .idle
        let recordings = delegate?.menuBarRecordings ?? []
        retryMenuItem?.isEnabled = state.canRetry && recordings.contains(where: \.retryable)
        deleteRecordingsMenuItem?.isEnabled = state == .idle && !recordings.isEmpty
    }

    private func refreshSelections() {
        guard let delegate else { return }

        let shortcut = delegate.menuBarShortcut
        shortcutMenuItem?.title = "Tastenkombination: \(shortcut.displayName)"
        for item in shortcutMenuItem?.submenu?.items ?? [] {
            item.state = (item.representedObject as? String) == shortcut.displayName ? .on : .off
        }

        let model = delegate.menuBarModel
        modelMenuItem?.title = "Modell: \(model.rawValue)"
        for item in modelMenuItem?.submenu?.items ?? [] {
            item.state = (item.representedObject as? String) == model.rawValue ? .on : .off
        }

        let language = delegate.menuBarLanguage ?? Settings.automaticLanguage
        let languageTitle =
            Self.offeredLanguages.first { ($0.code ?? Settings.automaticLanguage) == language }?.title ?? language
        languageMenuItem?.title = "Sprache: \(languageTitle)"
        for item in languageMenuItem?.submenu?.items ?? [] {
            item.state = (item.representedObject as? String) == language ? .on : .off
        }
    }

    private static func makeStatusBarImage() -> NSImage? {
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

    private func makeActionItem(
        _ title: String,
        action: Selector,
        toolTip: String? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.toolTip = toolTip
        return item
    }

    func menuWillOpen(_ menu: NSMenu) { isMenuOpen = true }
    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
        refresh()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refresh()
    }

    // MARK: - Actions

    @objc private func configureShortcut() { delegate?.menuBarDidConfigureShortcut() }
    @objc private func configureVocabulary() { delegate?.menuBarDidConfigureVocabulary() }
    @objc private func cancelOperation() { delegate?.menuBarDidCancel(discard: false) }
    @objc private func discardOperation() { delegate?.menuBarDidCancel(discard: true) }
    @objc private func copyLastText() { delegate?.menuBarDidCopyLastText() }
    @objc private func clearLastText() {
        delegate?.menuBarDidClearLastText()
        refreshActions()
    }
    @objc private func toggleAutoPaste() {
        delegate?.menuBarDidToggleAutoPaste()
        refreshActions()
    }

    @objc private func toggleRecording() {
        delegate?.menuBarDidTriggerToggleRecording()
    }

    @objc private func retryLastRecording() {
        delegate?.menuBarDidTriggerRetry()
    }

    @objc private func deleteSavedRecordings() {
        delegate?.menuBarDidTriggerDeleteSavedRecordings()
        refreshRetryMenuItem()
    }

    @objc private func setAPIKey() {
        delegate?.menuBarDidTriggerSetAPIKey()
    }

    @objc private func openAccessibilitySettings() {
        SystemSettings.openAccessibility()
    }

    @objc private func openLog() {
        AppLog.reveal()
    }

    @objc private func openSoundSettings() {
        SystemSettings.openSound()
    }

    @objc private func selectShortcut(_ sender: NSMenuItem) {
        guard
            let name = sender.representedObject as? String,
            let preset = HotKeyShortcut.presets.first(where: { $0.displayName == name })
        else { return }
        delegate?.menuBarDidSelect(shortcut: preset)
        refreshSelections()
    }

    @objc private func selectModel(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        delegate?.menuBarDidSelect(model: TranscriptionModel(rawValue: raw))
        refreshSelections()
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        delegate?.menuBarDidSelect(language: raw == Settings.automaticLanguage ? nil : raw)
        refreshSelections()
    }
}
