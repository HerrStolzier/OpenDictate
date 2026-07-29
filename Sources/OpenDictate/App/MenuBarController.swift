import AppKit
import Foundation
import OpenDictateCore

@MainActor
protocol MenuBarControllerDelegate: AnyObject {
    func menuBarDidTriggerToggleRecording()
    func menuBarDidTriggerRetry()
    func menuBarDidTriggerSetAPIKey()
    func menuBarDidSelect(shortcut: HotKeyShortcut)
    func menuBarDidSelect(model: TranscriptionModel)
    func menuBarDidSelect(language: String?)

    var menuBarShortcut: HotKeyShortcut { get }
    var menuBarModel: TranscriptionModel { get }
    var menuBarLanguage: String? { get }
    var menuBarHasRetryableRecording: Bool { get }
}

/// Owns the status bar item and its menu. Knows nothing about recording or
/// transcription; it asks the delegate for current state and reports what the
/// user picked.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    /// The models offered in the menu. Everything else still works through
    /// OPENAI_TRANSCRIBE_MODEL, this is just the short list worth one click.
    static let offeredModels: [TranscriptionModel] = [.gptTranscribe, .gpt4oMiniTranscribe]

    /// Menu title and stored value. nil means let the API detect the language.
    static let offeredLanguages: [(title: String, code: String?)] = [
        ("Auto", nil),
        ("German", "de"),
        ("English", "en")
    ]

    private weak var delegate: MenuBarControllerDelegate?
    private var statusItem: NSStatusItem?
    private var statusMenuItem: NSMenuItem?
    private var inputDeviceMenuItem: NSMenuItem?
    private var retryMenuItem: NSMenuItem?
    private var shortcutMenuItem: NSMenuItem?
    private var modelMenuItem: NSMenuItem?
    private var languageMenuItem: NSMenuItem?

    init(delegate: MenuBarControllerDelegate) {
        self.delegate = delegate
        super.init()
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = Self.makeStatusBarImage()
            button.imagePosition = .imageOnly
            button.toolTip = "OpenDictate: Ready"
        }

        let menu = NSMenu()

        let statusMenuItem = NSMenuItem(title: "Status: Ready", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        let shortcutItem = NSMenuItem(title: "Hotkey", action: nil, keyEquivalent: "")
        shortcutItem.submenu = makeShortcutSubmenu()
        menu.addItem(shortcutItem)
        self.shortcutMenuItem = shortcutItem

        let modelItem = NSMenuItem(title: "Model", action: nil, keyEquivalent: "")
        modelItem.submenu = makeModelSubmenu()
        menu.addItem(modelItem)
        self.modelMenuItem = modelItem

        let languageItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        languageItem.submenu = makeLanguageSubmenu()
        menu.addItem(languageItem)
        self.languageMenuItem = languageItem

        menu.addItem(NSMenuItem(title: "Max recording: \(Int(Config.maximumRecordingDuration)) seconds", action: nil, keyEquivalent: ""))

        let inputDeviceItem = NSMenuItem(title: "Input: -", action: #selector(openSoundSettings), keyEquivalent: "")
        inputDeviceItem.target = self
        inputDeviceItem.toolTip = "Microphone OpenDictate records from. Click to open Sound settings."
        menu.addItem(inputDeviceItem)
        self.inputDeviceMenuItem = inputDeviceItem

        menu.addItem(.separator())

        let recordingItem = NSMenuItem(title: "Start/Stop Recording", action: #selector(toggleRecording), keyEquivalent: "")
        recordingItem.target = self
        menu.addItem(recordingItem)

        let retryItem = NSMenuItem(title: "Retry Last Recording", action: #selector(retryLastRecording), keyEquivalent: "")
        retryItem.target = self
        retryItem.toolTip = "Upload the most recent recording whose transcription failed."
        menu.addItem(retryItem)
        self.retryMenuItem = retryItem

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
        refresh()
        statusItem = item
    }

    func updateStatus(_ value: String) {
        statusMenuItem?.title = "Status: \(value)"
        statusItem?.button?.toolTip = "OpenDictate: \(value)"
    }

    /// Re-reads everything that can change while the app runs.
    func refresh() {
        refreshInputDeviceMenuItem()
        refreshRetryMenuItem()
        refreshSelections()
    }

    // MARK: - Submenus

    private func makeShortcutSubmenu() -> NSMenu {
        let submenu = NSMenu()
        for preset in HotKeyShortcut.presets {
            let item = NSMenuItem(title: preset.displayName, action: #selector(selectShortcut(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset.displayName
            submenu.addItem(item)
        }
        return submenu
    }

    private func makeModelSubmenu() -> NSMenu {
        let submenu = NSMenu()
        for model in Self.offeredModels {
            let price = model.pricePerMinuteUSD.map { String(format: " ($%.4f/min)", $0) } ?? ""
            let item = NSMenuItem(title: "\(model.rawValue)\(price)", action: #selector(selectModel(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = model.rawValue
            submenu.addItem(item)
        }
        return submenu
    }

    private func makeLanguageSubmenu() -> NSMenu {
        let submenu = NSMenu()
        for option in Self.offeredLanguages {
            let item = NSMenuItem(title: option.title, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = option.code ?? Settings.automaticLanguage
            submenu.addItem(item)
        }
        return submenu
    }

    // MARK: - Refresh

    private func refreshInputDeviceMenuItem() {
        guard let inputDeviceMenuItem else { return }
        let input = AudioInput.current()
        let name = input?.name ?? "Unknown"
        let suffix = (input?.isBluetooth ?? false) ? " (Bluetooth)" : ""
        inputDeviceMenuItem.title = "Input: \(name)\(suffix)"
    }

    private func refreshRetryMenuItem() {
        retryMenuItem?.isEnabled = delegate?.menuBarHasRetryableRecording ?? false
    }

    private func refreshSelections() {
        guard let delegate else { return }

        let shortcut = delegate.menuBarShortcut
        shortcutMenuItem?.title = "Hotkey: \(shortcut.displayName)"
        for item in shortcutMenuItem?.submenu?.items ?? [] {
            item.state = (item.representedObject as? String) == shortcut.displayName ? .on : .off
        }

        let model = delegate.menuBarModel
        modelMenuItem?.title = "Model: \(model.rawValue)"
        for item in modelMenuItem?.submenu?.items ?? [] {
            item.state = (item.representedObject as? String) == model.rawValue ? .on : .off
        }

        let language = delegate.menuBarLanguage ?? Settings.automaticLanguage
        let languageTitle = Self.offeredLanguages.first { ($0.code ?? Settings.automaticLanguage) == language }?.title ?? language
        languageMenuItem?.title = "Language: \(languageTitle)"
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

    func menuNeedsUpdate(_ menu: NSMenu) {
        refresh()
    }

    // MARK: - Actions

    @objc private func toggleRecording() {
        delegate?.menuBarDidTriggerToggleRecording()
    }

    @objc private func retryLastRecording() {
        delegate?.menuBarDidTriggerRetry()
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
