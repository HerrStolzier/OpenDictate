import AppKit
import Foundation

/// Owns the status bar item and its menu. Knows nothing about recording or
/// transcription; it reports user intent through `Actions` and renders whatever
/// status text it is handed.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    struct Actions {
        var toggleRecording: () -> Void
        var setAPIKey: () -> Void
        var openAccessibilitySettings: () -> Void
        var openLog: () -> Void
        var openSoundSettings: () -> Void
    }

    private let actions: Actions
    private var statusItem: NSStatusItem?
    private var statusMenuItem: NSMenuItem?
    private var inputDeviceMenuItem: NSMenuItem?

    init(actions: Actions) {
        self.actions = actions
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
        menu.addItem(NSMenuItem(title: "Hotkey: Option+Shift+Space", action: nil, keyEquivalent: ""))
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

    func updateStatus(_ value: String) {
        statusMenuItem?.title = "Status: \(value)"
        statusItem?.button?.toolTip = "OpenDictate: \(value)"
    }

    func refreshInputDeviceMenuItem() {
        guard let inputDeviceMenuItem else { return }
        let input = AudioInput.current()
        let name = input?.name ?? "Unknown"
        let suffix = (input?.isBluetooth ?? false) ? " (Bluetooth)" : ""
        inputDeviceMenuItem.title = "Input: \(name)\(suffix)"
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
        refreshInputDeviceMenuItem()
    }

    @objc private func toggleRecording() {
        actions.toggleRecording()
    }

    @objc private func setAPIKey() {
        actions.setAPIKey()
    }

    @objc private func openAccessibilitySettings() {
        actions.openAccessibilitySettings()
    }

    @objc private func openLog() {
        actions.openLog()
    }

    @objc private func openSoundSettings() {
        actions.openSoundSettings()
    }
}
