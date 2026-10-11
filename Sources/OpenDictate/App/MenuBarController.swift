import AppKit
import Foundation
import OpenDictateCore

@MainActor
protocol MenuBarControllerDelegate: AnyObject {
    func menuBarDidConfigureShortcut()
    func menuBarDidConfigureVocabulary()
    func menuBarDidConfigureCustomServer()
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
    var menuBarNeedsAPIKeySetup: Bool { get }
    func menuBarDidTriggerToggleRecording()
    func menuBarDidTriggerRetry()
    func menuBarDidTriggerDeleteSavedRecordings()
    func menuBarDidTriggerSetAPIKey()
    func menuBarDidSelect(trigger: RecordingTrigger)
    func menuBarDidSelect(model: TranscriptionModel)
    func menuBarDidSelect(language: String?)
    func menuBarDidSelect(translationTarget: String?)
    func menuBarDidSelect(indicatorStyle: IndicatorStyle)
    func menuBarDidShowLastText()

    var menuBarIndicatorStyle: IndicatorStyle { get }
    /// The state word for the menu's head ("Bereit", "Hört zu", …).
    var menuBarStateWord: String { get }
    var menuBarTrigger: RecordingTrigger { get }
    var menuBarModel: TranscriptionModel { get }
    var menuBarLanguage: String? { get }
    var menuBarTranslationTarget: String? { get }
}

/// Owns the status bar item, its daily menu and the settings model. Knows
/// nothing about recording or transcription; it asks the delegate for current
/// state and reports what the user picked.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    var onShowSettings: (() -> Void)?
    /// Backs the settings window; the status item opens `dailyMenu` instead.
    private var settingsMenu: NSMenu?
    let dailyMenu = NSMenu()
    private lazy var settingsWindow = SettingsWindowController(
        needsAPIKeySetup: { [weak self] in self?.delegate?.menuBarNeedsAPIKeySetup ?? false })
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
    private var renderedState: DictationState?
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
    private var translationMenuItem: NSMenuItem?
    private var indicatorStyleMenuItem: NSMenuItem?
    /// Stored value of the "Aus" entry in the translation submenu.
    private static let translationOff = "off"

    init(delegate: MenuBarControllerDelegate) {
        self.delegate = delegate
        super.init()
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = BlinkRenderer.statusBarImage()
            button.imagePosition = .imageLeading
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
        shortcutItem.identifier = NSUserInterfaceItemIdentifier("shortcut")
        menu.addItem(shortcutItem)
        self.shortcutMenuItem = shortcutItem
        let customShortcut = makeActionItem("Eigene Tastenkombination …", action: #selector(configureShortcut))
        shortcutItem.submenu?.addItem(.separator())
        shortcutItem.submenu?.addItem(customShortcut)

        let modelItem = NSMenuItem(title: "Modell", action: nil, keyEquivalent: "")
        modelItem.submenu = makeModelSubmenu()
        modelItem.identifier = NSUserInterfaceItemIdentifier("model")
        menu.addItem(modelItem)
        self.modelMenuItem = modelItem

        let languageItem = NSMenuItem(title: "Sprache", action: nil, keyEquivalent: "")
        languageItem.submenu = makeLanguageSubmenu()
        languageItem.identifier = NSUserInterfaceItemIdentifier("language")
        menu.addItem(languageItem)
        self.languageMenuItem = languageItem

        let translationItem = NSMenuItem(title: "Übersetzen", action: nil, keyEquivalent: "")
        translationItem.submenu = makeTranslationSubmenu()
        translationItem.identifier = NSUserInterfaceItemIdentifier("translation")
        menu.addItem(translationItem)
        self.translationMenuItem = translationItem
        let styleItem = NSMenuItem(title: "Anzeige ohne Notch", action: nil, keyEquivalent: "")
        styleItem.submenu = makeIndicatorStyleSubmenu()
        styleItem.identifier = NSUserInterfaceItemIdentifier("indicatorStyle")
        menu.addItem(styleItem)
        indicatorStyleMenuItem = styleItem
        let vocabulary = makeActionItem("Vokabular und Kontext …", action: #selector(configureVocabulary))
        vocabulary.identifier = NSUserInterfaceItemIdentifier("vocabulary")
        menu.addItem(vocabulary)
        let customServer = makeActionItem("Eigener Server …", action: #selector(configureCustomServer))
        customServer.identifier = NSUserInterfaceItemIdentifier("customServer")
        menu.addItem(customServer)

        menu.addItem(
            NSMenuItem(
                title: "Maximale Aufnahme: \(Int(Config.maximumRecordingDuration)) Sekunden", action: nil,
                keyEquivalent: ""))

        let inputDeviceItem = makeActionItem(
            "Mikrofon: –",
            action: #selector(openSoundSettings),
            toolTip: "Aktuelles Systemmikrofon. Klicken öffnet die Toneinstellungen."
        )
        inputDeviceItem.identifier = NSUserInterfaceItemIdentifier("microphone")
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
        autoPasteMenuItem?.identifier = NSUserInterfaceItemIdentifier("autoPaste")

        let retryItem = makeActionItem(
            "Letzte Aufnahme wiederholen",
            action: #selector(retryLastRecording),
            toolTip: "Die neueste gültige Aufnahme bewusst erneut an den eingestellten Dienst senden."
        )
        menu.addItem(retryItem)
        self.retryMenuItem = retryItem
        let recordingsItem = NSMenuItem(title: "Gespeicherte Aufnahmen", action: nil, keyEquivalent: "")
        recordingsItem.submenu = NSMenu()
        recordingsItem.identifier = NSUserInterfaceItemIdentifier("recordings")
        menu.addItem(recordingsItem)
        recordingsMenuItem = recordingsItem

        let deleteRecordingsItem = makeActionItem(
            "Gespeicherte Aufnahmen löschen …",
            action: #selector(deleteSavedRecordings),
            toolTip: "Aufbewahrte Aufnahmen endgültig löschen."
        )
        deleteRecordingsItem.identifier = NSUserInterfaceItemIdentifier("deleteRecordings")
        menu.addItem(deleteRecordingsItem)
        self.deleteRecordingsMenuItem = deleteRecordingsItem

        let apiKeyItem = makeActionItem("API-Schlüssel einrichten …", action: #selector(setAPIKey))
        apiKeyItem.identifier = NSUserInterfaceItemIdentifier("apiKey")
        menu.addItem(apiKeyItem)
        let accessibilityItem = makeActionItem("Bedienungshilfen öffnen", action: #selector(openAccessibilitySettings))
        accessibilityItem.identifier = NSUserInterfaceItemIdentifier("accessibility")
        menu.addItem(accessibilityItem)
        let logItem = makeActionItem("Protokoll öffnen", action: #selector(openLog))
        logItem.identifier = NSUserInterfaceItemIdentifier("log")
        menu.addItem(logItem)
        let aboutItem = makeActionItem("Über OpenDictate …", action: #selector(showAbout))
        aboutItem.identifier = NSUserInterfaceItemIdentifier("about")
        menu.addItem(aboutItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.identifier = NSUserInterfaceItemIdentifier("quit")
        menu.addItem(quit)

        menu.delegate = self
        settingsMenu = menu
        dailyMenu.autoenablesItems = false
        dailyMenu.delegate = self
        item.menu = dailyMenu
        self.statusMenuItem = statusMenuItem
        refresh()
        statusItem = item
    }

    var hasVisibleSettings: Bool { settingsWindow.window?.isVisible == true }

    /// The menu behind the menu bar symbol, rebuilt each time it opens.
    private func rebuildDailyMenu() {
        dailyMenu.removeAllItems()
        guard let delegate else { return }
        let state = delegate.menuBarState
        let head = NSMenuItem()
        head.view = MenuHeadView(state: delegate.menuBarStateWord)
        dailyMenu.addItem(head)
        dailyMenu.addItem(.separator())
        if delegate.menuBarNeedsAPIKeySetup {
            let setup = makeActionItem("API-Schlüssel einrichten …", action: #selector(setAPIKey))
            setup.isEnabled = state == .idle
            dailyMenu.addItem(setup)
        }
        let dictation: NSMenuItem
        switch state {
        case .idle, .recording:
            dictation = makeActionItem(
                state == .idle ? "Neues Diktat" : "Diktat beenden", action: #selector(toggleRecording))
            dictation.attributedTitle = Self.title(dictation.title, detail: delegate.menuBarTrigger.displayName)
        case .processing, .delivering:
            dictation = makeActionItem("Abbrechen, Aufnahme behalten", action: #selector(cancelOperation))
        }
        dictation.identifier = NSUserInterfaceItemIdentifier("dictation")
        dailyMenu.addItem(dictation)
        let lastText = makeActionItem("Letzten Text ansehen", action: #selector(showLastText))
        lastText.isEnabled = state == .idle && delegate.menuBarHasTranscript
        dailyMenu.addItem(lastText)
        let recordings = makeActionItem("Aufbewahrte Aufnahmen", action: #selector(openRecordings))
        recordings.attributedTitle = Self.title(recordings.title, detail: "\(delegate.menuBarRecordings.count)")
        dailyMenu.addItem(recordings)
        dailyMenu.addItem(.separator())
        let autoPaste = makeActionItem("Automatisch einfügen", action: #selector(toggleAutoPaste))
        autoPaste.state = delegate.menuBarAutoPaste ? .on : .off
        autoPaste.isEnabled = state == .idle
        dailyMenu.addItem(autoPaste)
        let target = delegate.menuBarTranslationTarget
        let translation = NSMenuItem(
            title: "Übersetzen: " + (target.map { Translation.language(code: $0)?.title ?? $0 } ?? "Aus"), action: nil,
            keyEquivalent: "")
        translation.submenu = makeTranslationSubmenu()
        for item in translation.submenu?.items ?? [] {
            item.state = (item.representedObject as? String) == (target ?? Self.translationOff) ? .on : .off
            item.isEnabled = state == .idle
        }
        dailyMenu.addItem(translation)
        dailyMenu.addItem(.separator())
        let settings = makeActionItem("Einstellungen …", action: #selector(openSettings))
        settings.keyEquivalent = ","
        dailyMenu.addItem(settings)
        dailyMenu.addItem(makeActionItem("Hilfe", action: #selector(openHelp)))
        dailyMenu.addItem(.separator())
        let quit = NSMenuItem(
            title: "OpenDictate beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.identifier = NSUserInterfaceItemIdentifier("dailyQuit")
        dailyMenu.addItem(quit)
    }

    /// Menu title with a quiet value on the right, as on the design board.
    private static func title(_ title: String, detail: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = [NSTextTab(textAlignment: .right, location: 260)]
        let result = NSMutableAttributedString(
            string: title, attributes: [.font: NSFont.menuFont(ofSize: 0), .paragraphStyle: paragraph])
        result.append(
            NSAttributedString(
                string: "\t" + detail,
                attributes: [
                    .font: BrandFonts.mono(12), .foregroundColor: NSColor.secondaryLabelColor,
                    .paragraphStyle: paragraph
                ]))
        return result
    }

    /// Text next to the menu bar symbol while the indicator asks for it.
    func setIndicatorTitle(_ title: String?, alert: Bool) {
        guard let button = statusItem?.button else { return }
        guard let title else {
            button.attributedTitle = NSAttributedString(string: "")
            button.imagePosition = .imageOnly
            return
        }
        let theme = DesignTheme.matching(button.effectiveAppearance)
        button.imagePosition = .imageLeading
        button.attributedTitle = NSAttributedString(
            string: " " + title,
            attributes: [
                .font: BrandFonts.mono(11, semibold: true),
                .foregroundColor: alert || title.hasPrefix("REC")
                    ? NSColor(design: .rec, theme: theme) : NSColor.labelColor
            ])
    }

    @objc private func showLastText() { delegate?.menuBarDidShowLastText() }
    @objc private func openSettings() { showSettings() }
    @objc private func openHelp() {
        onShowSettings?()
        refresh()
        if let settingsMenu { settingsWindow.show(menu: settingsMenu, page: .help) }
    }

    func showSettings() {
        onShowSettings?()
        refresh()
        if let settingsMenu { settingsWindow.show(menu: settingsMenu) }
    }

    func showRecordings() {
        onShowSettings?()
        refresh()
        if let settingsMenu { settingsWindow.show(menu: settingsMenu, page: .recordings) }
    }

    func reopenSettingsIfVisible() -> Bool {
        guard let window = settingsWindow.window, window.isVisible else { return false }
        window.makeKeyAndOrderFront(nil)
        return true
    }

    func showRecordingActions(at view: NSView) {
        refresh()
        let menu = NSMenu()
        menu.autoenablesItems = false
        for item in [cancelMenuItem, discardMenuItem, copyLastMenuItem, clearLastMenuItem] {
            if let copy = item?.copy() as? NSMenuItem { menu.addItem(copy) }
        }
        menu.addItem(.separator())
        let recordings = makeActionItem("Aufbewahrte Aufnahmen …", action: #selector(openRecordings))
        menu.addItem(recordings)
        menu.addItem(makeActionItem("Über OpenDictate …", action: #selector(showAbout)))
        menu.addItem(NSMenuItem(title: "Beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.maxY), in: view)
    }

    @objc private func openRecordings() { showRecordings() }

    @objc private func showAbout() {
        let info = AppVersionInfo()
        let details = info.sourceDescription + (info.sourceRevision.map { "\n\($0)" } ?? "")
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "OpenDictate",
            .applicationVersion: info.version,
            .version: info.build,
            .credits: NSAttributedString(string: details)
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    func updateStatus(_ value: String) {
        statusMenuItem?.title = "Status: \(value)"
        statusItem?.button?.toolTip = "OpenDictate: \(value)"
        statusItem?.button?.setAccessibilityLabel("OpenDictate: \(value)")
    }

    /// The symbol stays Blink; the indicator shows the state and sets any text
    /// next to it through `setIndicatorTitle`.
    func updateState(_ state: DictationState, elapsed: Double = 0, level: Float = -160) {
        if renderedState != state {
            renderedState = state
            refreshActions()
            if let settingsMenu { settingsWindow.refresh(menu: settingsMenu) }
        }
        if state == .recording {
            let remaining = max(0, Int(Config.maximumRecordingDuration - elapsed))
            let warning = remaining <= 10 ? " – noch \(remaining) s" : ""
            updateStatus("Aufnahme \(Int(elapsed)) s, Pegel \(Int(level)) dB\(warning)")
        }
    }

    private func refreshActions() {
        let state = delegate?.menuBarState ?? .idle
        for id in ["shortcut", "language", "translation", "model", "apiKey", "vocabulary", "customServer", "autoPaste"]
        {
            settingsMenu?.items.first { $0.identifier?.rawValue == id }?.isEnabled = state == .idle
        }
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
        if let settingsMenu { settingsWindow.refresh(menu: settingsMenu) }
    }

    private func refreshRecordings() {
        guard let menu = recordingsMenuItem?.submenu else { return }
        menu.removeAllItems()
        let available = delegate?.menuBarState == .idle
        for entry in delegate?.menuBarRecordings ?? [] {
            let duration =
                entry.duration.map { " · " + String(format: "%.1f s", locale: Locale(identifier: "de_DE"), $0) } ?? ""
            let item = NSMenuItem(
                title: entry.created.formatted(date: .abbreviated, time: .standard) + duration,
                action: nil,
                keyEquivalent: ""
            )
            item.identifier = NSUserInterfaceItemIdentifier("recording-\(entry.filename)")
            let submenu = NSMenu()
            submenu.delegate = self
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
        submenu.delegate = self
        submenu.autoenablesItems = false
        for (index, trigger) in RecordingTrigger.menuChoices.enumerated() {
            if index == ModifierKey.allCases.count { submenu.addItem(.separator()) }
            let item = makeActionItem(trigger.displayName, action: #selector(selectShortcut(_:)))
            item.representedObject = index
            submenu.addItem(item)
        }
        return submenu
    }

    private func makeModelSubmenu() -> NSMenu {
        let submenu = NSMenu()
        submenu.delegate = self
        submenu.autoenablesItems = false
        for model in Self.offeredModels {
            let approximate = model.isPriceApproximate ? "ca. " : ""
            let price = model.pricePerMinuteUSD.map { String(format: " (\(approximate)$%.4f/min)", $0) } ?? ""
            let item = makeActionItem("\(model.rawValue)\(price)", action: #selector(selectModel(_:)))
            item.representedObject = model.rawValue
            submenu.addItem(item)
        }
        return submenu
    }

    private func makeLanguageSubmenu() -> NSMenu {
        let submenu = NSMenu()
        submenu.delegate = self
        submenu.autoenablesItems = false
        for option in Self.offeredLanguages {
            let item = makeActionItem(option.title, action: #selector(selectLanguage(_:)))
            item.representedObject = option.code ?? Settings.automaticLanguage
            submenu.addItem(item)
        }
        return submenu
    }

    private func makeTranslationSubmenu() -> NSMenu {
        let submenu = NSMenu()
        submenu.delegate = self
        submenu.autoenablesItems = false
        let off = makeActionItem("Aus", action: #selector(selectTranslation(_:)))
        off.representedObject = Self.translationOff
        submenu.addItem(off)
        submenu.addItem(.separator())
        for language in Translation.languages {
            let item = makeActionItem(language.title, action: #selector(selectTranslation(_:)))
            item.representedObject = language.code
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

        let trigger = delegate.menuBarTrigger
        shortcutMenuItem?.title = "Tastenkombination: \(trigger.displayName)"
        for item in shortcutMenuItem?.submenu?.items ?? [] {
            let index = item.representedObject as? Int
            item.state = index.map { RecordingTrigger.menuChoices[$0] == trigger } == true ? .on : .off
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

        let target = delegate.menuBarTranslationTarget
        let targetTitle = target.map { Translation.language(code: $0)?.title ?? $0 } ?? "Aus"
        translationMenuItem?.title = "Übersetzen: \(targetTitle)"
        for item in translationMenuItem?.submenu?.items ?? [] {
            item.state = (item.representedObject as? String) == (target ?? Self.translationOff) ? .on : .off
        }

        let style = delegate.menuBarIndicatorStyle
        indicatorStyleMenuItem?.title = "Anzeige ohne Notch: \(style.title)"
        for item in indicatorStyleMenuItem?.submenu?.items ?? [] {
            item.state = (item.representedObject as? String) == style.rawValue ? .on : .off
        }
    }

    private func makeIndicatorStyleSubmenu() -> NSMenu {
        let submenu = NSMenu()
        submenu.delegate = self
        submenu.autoenablesItems = false
        for style in IndicatorStyle.allCases {
            let item = makeActionItem(style.title, action: #selector(selectIndicatorStyle(_:)))
            item.representedObject = style.rawValue
            submenu.addItem(item)
        }
        return submenu
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
        // A popup owns a snapshot. Rebuilding its parent while it opens would
        // remove the focused control; refresh after closing instead.
        if menu === settingsMenu { refresh() }
        if menu === dailyMenu { rebuildDailyMenu() }
    }

    // MARK: - Actions

    @objc private func configureShortcut() { delegate?.menuBarDidConfigureShortcut() }
    @objc private func configureVocabulary() { delegate?.menuBarDidConfigureVocabulary() }
    @objc private func configureCustomServer() { delegate?.menuBarDidConfigureCustomServer() }
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
        guard let index = sender.representedObject as? Int, RecordingTrigger.menuChoices.indices.contains(index)
        else { return }
        delegate?.menuBarDidSelect(trigger: RecordingTrigger.menuChoices[index])
        refreshSelections()
        if settingsWindow.window?.isVisible == true { showSettings() }
    }

    @objc private func selectModel(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        delegate?.menuBarDidSelect(model: TranscriptionModel(rawValue: raw))
        refreshSelections()
        if settingsWindow.window?.isVisible == true { showSettings() }
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        delegate?.menuBarDidSelect(language: raw == Settings.automaticLanguage ? nil : raw)
        refreshSelections()
        if settingsWindow.window?.isVisible == true { showSettings() }
    }

    @objc private func selectIndicatorStyle(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let style = IndicatorStyle(rawValue: raw) else { return }
        delegate?.menuBarDidSelect(indicatorStyle: style)
        refreshSelections()
        if settingsWindow.window?.isVisible == true { showSettings() }
    }

    @objc private func selectTranslation(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        delegate?.menuBarDidSelect(translationTarget: raw == Self.translationOff ? nil : raw)
        refreshSelections()
        if settingsWindow.window?.isVisible == true { showSettings() }
    }
}

/// Head of the daily menu: the word mark with Blink and the current state.
@MainActor
private final class MenuHeadView: NSView {
    private let state: String

    init(state: String) {
        self.state = state
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 34))
        autoresizingMask = [.width]
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel("OpenDictate: \(state)")
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let theme = DesignTheme.matching(effectiveAppearance)
        let mark = NSAttributedString(
            string: "opendictate",
            attributes: [.font: BrandFonts.pixel(16), .foregroundColor: NSColor(design: .ink, theme: theme)])
        let markSize = mark.size()
        mark.draw(at: NSPoint(x: 14, y: (bounds.height - markSize.height) / 2))
        BlinkRenderer.draw(
            BlinkFigure.small(.bereit), at: CGPoint(x: (16 + markSize.width).rounded(), y: 8), cell: 1, time: 0,
            animated: false, theme: theme)
        let word = NSAttributedString(
            string: state,
            attributes: [.font: BrandFonts.mono(12), .foregroundColor: NSColor(design: .inkMuted, theme: theme)])
        let wordSize = word.size()
        word.draw(at: NSPoint(x: bounds.width - 14 - wordSize.width, y: (bounds.height - wordSize.height) / 2))
    }
}
