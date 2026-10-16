import AppKit

/// Small native settings pages backed by the existing actions and selection state.
@MainActor
final class SettingsWindowController: NSWindowController {
    enum Page { case settings, recordings, help }
    private var page = Page.settings
    private var expanded = false
    private var settingsMenu = NSMenu()
    private var navigation: [NSView] = []
    private let needsAPIKeySetup: () -> Bool

    init(needsAPIKeySetup: @escaping () -> Bool = { false }) {
        self.needsAPIKeySetup = needsAPIKeySetup
        let window = SettingsUtilityWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 280),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "OpenDictate – Einstellungen"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 380, height: 300)
        super.init(window: window)
        window.center()
    }
    required init?(coder: NSCoder) { nil }

    func show(menu: NSMenu, page: Page = .settings) {
        self.page = page
        self.settingsMenu = menu
        render()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refresh(menu: NSMenu) {
        self.settingsMenu = menu
        guard window?.isVisible == true else { return }
        render()
    }

    private func item(_ id: String) -> NSMenuItem? {
        settingsMenu.items.first { $0.identifier?.rawValue == id }
    }

    private func render() {
        let previousFocus = window?.firstResponder as? NSView
        let focusID = previousFocus?.identifier
        navigation = []
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true
        scroll.backgroundColor = .windowBackgroundColor
        let document = SettingsDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        window?.contentView = scroll
        NSLayoutConstraint.activate([
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -20)
        ])
        if page != .settings {
            addButton("‹ Einstellungen", id: "back", action: #selector(goBack), to: stack)
        }
        switch page {
        case .settings:
            window?.title = "OpenDictate – Einstellungen"
            let needsSetup = needsAPIKeySetup()
            if needsSetup, let apiKey = item("apiKey") {
                addText("Für dein erstes Diktat", to: stack, heading: true)
                addText(
                    "Richte deinen OpenAI-API-Schlüssel ein. Die Kosten rechnet OpenAI direkt mit dir ab.",
                    to: stack)
                addControl(apiKey, to: stack)
            }
            addRow("Mikrofon", id: "microphone", to: stack)
            addRow("Tastenkürzel", id: "shortcut", to: stack)
            addRow("Sprache", id: "language", to: stack)
            addRow("Übersetzen", id: "translation", to: stack)
            addRow("Übersetzen mit", id: "translationEngine", to: stack)
            addRow("Dienst", id: "service", to: stack)
            addRow("Anzeige", id: "indicatorStyle", to: stack)
            if let item = item("autoPaste") { addControl(item, to: stack) }
            let disclosure = addButton(
                expanded ? "▾ Erweitert" : "▸ Erweitert", id: "advanced",
                action: #selector(toggleAdvanced), to: stack)
            disclosure.setAccessibilityValue(expanded ? "Geöffnet" : "Geschlossen")
            if expanded {
                addRow("Modell", id: "model", to: stack)
                for id in ["apiKey", "vocabulary", "customServer"] {
                    if id == "apiKey", needsSetup { continue }
                    if let item = item(id) { addControl(item, to: stack) }
                }
            }
            let links = NSStackView()
            links.spacing = 12
            addButton("Aufnahmen …", id: "recordingsPage", action: #selector(showRecordings), to: links)
            addButton("Hilfe …", id: "helpPage", action: #selector(showHelp), to: links)
            stack.addArrangedSubview(links)
            addText(AppVersionInfo().versionDescription, to: stack)
        case .recordings:
            window?.title = "OpenDictate – Aufnahmen"
            addText("Gesicherte Aufnahmen", to: stack, heading: true)
            addText(
                "OpenDictate sichert bis zu fünf Aufnahmen. Du kannst sie 24 Stunden lang nochmal senden, "
                    + "danach löscht OpenDictate sie, während die App geöffnet ist. "
                    + "Vor dem Senden fragt OpenDictate nach.",
                to: stack)
            if let recordings = item("recordings")?.submenu, !recordings.items.isEmpty {
                for recording in recordings.items { addControl(recording, to: stack) }
                if let item = item("deleteRecordings") { addControl(item, to: stack) }
            } else {
                addText("Keine gesicherten Aufnahmen.", to: stack)
            }
        case .help:
            window?.title = "OpenDictate – Hilfe"
            addText("Diktieren im Alltag", to: stack, heading: true)
            addText(
                "OpenDictate arbeitet in der Menüleiste. Klick in ein Textfeld und starte ein Diktat mit deinem "
                    + "Kürzel. Nach spätestens 90 Sekunden endet die Aufnahme von selbst.",
                to: stack)
            addText(
                "Während du diktierst, zeigt eine kleine Anzeige oben am Bildschirm, was passiert: Hört zu, "
                    + "Schreibt, Eingefügt, Kopiert oder Hoppla. Sie stört nicht beim Tippen und verschwindet bei "
                    + "Erfolg von selbst. Auf Macs ohne Notch schwebt sie unter der Menüleiste. Unter „Anzeige“ "
                    + "kannst du sie in die Menüleiste legen oder ausschalten, Fehler siehst du trotzdem. "
                    + "Im Vollbild erscheint sie nur beim Diktieren und bei Fehlern.",
                to: stack)
            addText(
                "Das Menüleistensymbol öffnet das Menü mit „Diktat starten“, deinem letzten Text, "
                    + "den gesicherten Aufnahmen und „OpenDictate beenden“.",
                to: stack)
            addText(AppVersionInfo().summary, to: stack)
            for id in ["about", "accessibility", "microphone", "log", "quit"] {
                if let item = item(id) { addControl(item, to: stack) }
            }
        }
        for (index, view) in navigation.enumerated() {
            view.nextKeyView = navigation[(index + 1) % navigation.count]
        }
        (window as? SettingsUtilityWindow)?.navigation = navigation
        window?.initialFirstResponder = navigation.first
        if window?.isKeyWindow == true {
            window?.makeFirstResponder(navigation.first { $0.identifier == focusID } ?? navigation.first)
        }
        document.layoutSubtreeIfNeeded()
    }

    private func addText(_ text: String, to stack: NSStackView, heading: Bool = false) {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: heading ? 16 : 13, weight: heading ? .semibold : .regular)
        label.textColor = heading ? .labelColor : .secondaryLabelColor
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        stack.addArrangedSubview(label)
        label.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func addRow(_ title: String, id: String, to stack: NSStackView) {
        guard let item = item(id) else { return }
        let row = NSStackView()
        row.spacing = 12
        row.alignment = .centerY
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 104).isActive = true
        row.addArrangedSubview(label)
        let control = control(for: item)
        row.addArrangedSubview(control)
        control.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func addControl(_ item: NSMenuItem, to stack: NSStackView) {
        let control = control(for: item)
        stack.addArrangedSubview(control)
        control.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func control(for item: NSMenuItem) -> NSControl {
        let control: NSButton
        if let submenu = item.submenu {
            let popup = NSPopUpButton(frame: .zero, pullsDown: true)
            let copy = (submenu.copy() as? NSMenu) ?? NSMenu()
            copy.insertItem(withTitle: valueTitle(item), action: nil, keyEquivalent: "", at: 0)
            popup.menu = copy
            control = popup
        } else {
            let button = NSButton(title: valueTitle(item), target: item.target, action: item.action)
            button.bezelStyle = .rounded
            button.lineBreakMode = .byTruncatingTail
            if item.identifier?.rawValue == "autoPaste" {
                button.setButtonType(.switch)
                button.state = item.state
            }
            control = button
        }
        control.identifier = item.identifier
        control.isEnabled = item.isEnabled
        control.toolTip = item.toolTip ?? item.title
        control.setAccessibilityLabel(item.title)
        if control.isEnabled { navigation.append(control) }
        return control
    }

    /// Rows that show only the value after "Title:" next to their own label.
    private static let valueRows: Set<String> = [
        "microphone", "shortcut", "language", "translation", "translationEngine", "service", "model",
        "indicatorStyle"
    ]

    private func valueTitle(_ item: NSMenuItem) -> String {
        if Self.valueRows.contains(item.identifier?.rawValue ?? ""), page == .settings,
            let colon = item.title.firstIndex(of: ":")
        {
            return String(item.title[item.title.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        }
        return item.title
    }

    @discardableResult
    private func addButton(_ title: String, id: String, action: Selector, to stack: NSStackView) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.identifier = NSUserInterfaceItemIdentifier(id)
        stack.addArrangedSubview(button)
        navigation.append(button)
        return button
    }

    @objc private func toggleAdvanced() {
        expanded.toggle()
        render()
    }
    @objc private func showRecordings() {
        page = .recordings
        render()
    }
    @objc private func showHelp() {
        page = .help
        render()
    }
    @objc private func goBack() {
        page = .settings
        render()
    }
}

private final class SettingsDocumentView: NSView {
    override var isFlipped: Bool { true }
}

private final class SettingsUtilityWindow: NSWindow {
    var navigation: [NSView] = []
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == 48,
            event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
            !navigation.isEmpty
        {
            let current = navigation.firstIndex { $0 === firstResponder }
            let reverse = event.modifierFlags.contains(.shift)
            let index =
                current.map { ($0 + (reverse ? navigation.count - 1 : 1)) % navigation.count }
                ?? (reverse ? navigation.count - 1 : 0)
            makeFirstResponder(navigation[index])
            navigation[index].scrollToVisible(navigation[index].bounds)
            return
        }
        super.sendEvent(event)
    }
}
