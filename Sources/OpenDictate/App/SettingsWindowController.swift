import AppKit

/// A separate native surface reusing the existing menu's actions and submenus.
/// This preserves settings, recovery and diagnostic capabilities without adding
/// them to the daily dictation panel or duplicating their application policy.
@MainActor
final class SettingsWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 560),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "OpenDictate – Einstellungen und Hilfe"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 320)
        super.init(window: window)
        window.center()
    }
    required init?(coder: NSCoder) { nil }

    func show(menu: NSMenu) {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = true
        scroll.backgroundColor = PanelColors.background
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = stack
        window?.contentView = scroll
        stack.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        for item in menu.items {
            if item.isSeparatorItem {
                let rule = NSBox()
                rule.boxType = .separator
                stack.addArrangedSubview(rule)
                rule.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48).isActive = true
            } else if let submenu = item.submenu {
                let popup = NSPopUpButton(frame: .zero, pullsDown: true)
                let copy = (submenu.copy() as? NSMenu) ?? NSMenu()
                copy.insertItem(withTitle: item.title, action: nil, keyEquivalent: "", at: 0)
                popup.menu = copy
                popup.isEnabled = item.isEnabled
                popup.setAccessibilityLabel(item.title)
                stack.addArrangedSubview(popup)
                popup.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48).isActive = true
            } else if item.action != nil {
                let button = NSButton(title: item.title, target: item.target, action: item.action)
                button.bezelStyle = .rounded
                if item.identifier?.rawValue == "autoPaste" {
                    button.setButtonType(.switch)
                    button.state = item.state
                }
                button.isEnabled = item.isEnabled
                button.toolTip = item.toolTip
                stack.addArrangedSubview(button)
            } else {
                let label = NSTextField(wrappingLabelWithString: item.title)
                label.textColor = PanelColors.secondary
                label.font = .systemFont(ofSize: 13)
                stack.addArrangedSubview(label)
                label.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48).isActive = true
            }
        }
        stack.layoutSubtreeIfNeeded()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
