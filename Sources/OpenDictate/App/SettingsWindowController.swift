import AppKit

/// Small native settings pages backed by the existing actions and selection state.
@MainActor
final class SettingsWindowController: NSWindowController {
    enum Page { case settings, recordings, help }
    private var page = Page.settings
    private var expanded = false
    private var settingsMenu = NSMenu()
    private var navigation: [NSView] = []

    init() {
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
            addRow("Mikrofon", id: "microphone", to: stack)
            addRow("Tastenkürzel", id: "shortcut", to: stack)
            addRow("Sprache", id: "language", to: stack)
            if let item = item("autoPaste") { addControl(item, to: stack) }
            let disclosure = addButton(
                expanded ? "▾ Erweitert" : "▸ Erweitert", id: "advanced",
                action: #selector(toggleAdvanced), to: stack)
            disclosure.setAccessibilityValue(expanded ? "Geöffnet" : "Geschlossen")
            if expanded {
                addRow("Modell", id: "model", to: stack)
                for id in ["apiKey", "vocabulary"] {
                    if let item = item(id) { addControl(item, to: stack) }
                }
            }
            let links = NSStackView()
            links.spacing = 12
            addButton("Aufnahmen …", id: "recordingsPage", action: #selector(showRecordings), to: links)
            addButton("Hilfe …", id: "helpPage", action: #selector(showHelp), to: links)
            stack.addArrangedSubview(links)
        case .recordings:
            window?.title = "OpenDictate – Aufnahmen"
            addText("Aufbewahrte Aufnahmen", to: stack, heading: true)
            addText(
                "Bis zu fünf Aufnahmen, höchstens 24 Stunden. Erneutes Verarbeiten sendet die gewählte Aufnahme an OpenAI und fragt vorher nach.",
                to: stack)
            if let recordings = item("recordings")?.submenu, !recordings.items.isEmpty {
                for recording in recordings.items { addControl(recording, to: stack) }
                if let item = item("deleteRecordings") { addControl(item, to: stack) }
            } else {
                addText("Keine aufbewahrten Aufnahmen.", to: stack)
            }
        case .help:
            window?.title = "OpenDictate – Hilfe"
            addText("Diktieren im Alltag", to: stack, heading: true)
            addText(
                "Wähle ein Textfeld und starte die Aufnahme über das Tastenkürzel oder das Aufnahmefenster. Nach spätestens 90 Sekunden endet die Aufnahme automatisch.",
                to: stack)
            addText(
                "Der rote Schließknopf blendet nur das Fenster aus. OpenDictate und das Tastenkürzel bleiben aktiv. Das Menüleistensymbol öffnet das Aufnahmefenster wieder.",
                to: stack)
            for id in ["accessibility", "microphone", "log", "quit"] {
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
        label.widthAnchor.constraint(equalToConstant: 88).isActive = true
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

    private func valueTitle(_ item: NSMenuItem) -> String {
        if ["microphone", "shortcut", "language", "model"].contains(item.identifier?.rawValue ?? ""),
            page == .settings, let colon = item.title.firstIndex(of: ":")
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
