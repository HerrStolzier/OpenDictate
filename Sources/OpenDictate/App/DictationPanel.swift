import AppKit
import OpenDictateCore

/// UI-only state. A submitted paste command never maps to confirmed success.
@MainActor
final class DictationPanel: NSWindowController {
    enum Display: String, CaseIterable {
        case ready, recording, processing, confirmed, manual, unconfirmed, failure, retry, cancelling

        var title: String {
            switch self {
            case .ready: "Bereit zum Diktieren."
            case .recording: "Aufnahme läuft."
            case .processing: "Text wird verarbeitet."
            case .confirmed: "Text eingefügt."
            case .manual: "Text ist verfügbar."
            case .unconfirmed: "Diktat verarbeitet."
            case .failure: "Vorgang nicht abgeschlossen."
            case .retry: "Diese Aufnahme erneut verarbeiten?"
            case .cancelling: "Wird abgebrochen …"
            }
        }

        var symbol: String {
            switch self {
            case .ready, .recording: "mic"
            case .processing, .cancelling: "text.alignleft"
            case .confirmed: "checkmark"
            case .manual: "doc.text"
            case .unconfirmed: "arrow.right.doc.on.clipboard"
            case .failure: "exclamationmark.triangle"
            case .retry: "arrow.clockwise"
            }
        }

        @MainActor var color: NSColor {
            switch self {
            case .recording: PanelColors.pair(0xA53B25, 0xFFB09B)
            case .processing, .manual: PanelColors.pair(0x245DC1, 0x99BFFF)
            case .confirmed: PanelColors.pair(0x216444, 0x91DFB3)
            case .unconfirmed: PanelColors.pair(0x245DC1, 0x99BFFF)
            case .failure: PanelColors.pair(0xAF293B, 0xFFADB7)
            default: PanelColors.ink
            }
        }
    }

    private static let pasteDetail = "Automatisches Einfügen wurde ausgelöst. Prüfe den Text im Zielprogramm."

    var onRecord: (() -> Void)?
    var onCancel: (() -> Void)?
    var onCopy: (() -> Void)?
    var onSettings: (() -> Void)?
    var onRecovery: (() -> Void)?
    var onRetry: (() -> Void)?
    var onActions: ((NSView) -> Void)?
    private(set) var display: Display = .ready
    private var busy = false
    private var showingText = false
    private var keyViews: [NSView] = []
    private let content = PanelSurface()
    private let iconSurface = PanelSurface(raised: true)
    private let icon = NSImageView()
    private let headline = NSTextField(wrappingLabelWithString: "")
    private let detail = NSTextField(wrappingLabelWithString: "")
    private let shortcut = NSTextField(wrappingLabelWithString: "")
    private let textView = NSTextView()
    private let textScroll = NSScrollView()
    private let primary = TactileButton(title: "Aufnahme starten", target: nil, action: nil)
    private let secondary = TactileButton(title: "Abbrechen", target: nil, action: nil)
    private let actions = NSButton(title: "Weitere Aktionen", target: nil, action: nil)
    private let settings = TactileButton(title: "Einstellungen", target: nil, action: nil)
    private var textHeight: NSLayoutConstraint!
    private var currentDetail = "Starte die Aufnahme oder nutze dein Tastenkürzel."

    init() {
        let panel = DictationUtilityPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 370),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        panel.title = "OpenDictate"
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.level = .floating
        panel.collectionBehavior = [.fullScreenAuxiliary]
        panel.minSize = NSSize(width: 340, height: 390)
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = PanelColors.background
        super.init(window: panel)
        panel.navigateFocus = { [weak self] reverse in self?.moveKeyboardFocus(reverse: reverse) ?? false }
        build()
        panel.center()
        render()
    }

    required init?(coder: NSCoder) { nil }

    func show(near anchor: NSRect? = nil) {
        guard let window else { return }
        if !window.isVisible, let anchor {
            let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
            let visible = screen?.visibleFrame ?? anchor
            window.setFrameOrigin(
                NSPoint(
                    x: max(visible.minX, min(anchor.maxX - window.frame.width, visible.maxX - window.frame.width)),
                    y: max(visible.minY, anchor.minY - window.frame.height - 8)))
        }
        // This must not activate OpenDictate or change the target application.
        window.orderFrontRegardless()
    }

    /// Explicit user entry points may activate the app. Automatic flow updates
    /// always use show(), which only orders the window without taking focus.
    func showForInteraction(near anchor: NSRect? = nil) {
        show(near: anchor)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(keyViews.first(where: { $0 === primary }) ?? keyViews.first)
    }

    func update(state: DictationState) {
        busy = state != .idle
        switch state {
        case .recording:
            showingText = false
            set(.recording, detail: "Sprich in deinem Tempo.")
        case .processing:
            set(.processing, detail: "Bitte warte einen Moment.")
        case .delivering:
            set(.processing, detail: "Die Übergabe wird vorbereitet.")
        case .idle: render()
        }
    }

    func update(outcome: DictationOutcome, transcript: String?) {
        showingText = false
        textView.string = transcript ?? ""
        switch outcome {
        case .textAvailable:
            showingText = true
            set(.manual, detail: "Nicht automatisch eingefügt. Du kannst den Text kopieren.")
        case .deliveryUnconfirmed:
            set(.unconfirmed, detail: Self.pasteDetail)
        case .failed:
            set(.failure, detail: currentDetail)
        case .cancelled:
            set(.ready, detail: currentDetail)
        }
    }

    func setStatus(_ value: String) {
        currentDetail = value
        detail.stringValue = value
    }

    func setShortcut(_ value: String) { shortcut.stringValue = value }

    func showFailure(_ message: String) {
        set(.failure, detail: message)
        show()
    }

    func clearText() {
        textView.string = ""
        showingText = false
        if display == .manual || display == .unconfirmed { set(.ready, detail: "Text aus dem Speicher gelöscht.") }
        render()
    }

    func confirmRetry(description: String) {
        showingText = false
        set(
            .retry,
            detail: description
                + "\nErneuter Versand an OpenAI kann erneut Kosten verursachen. Ergebnis nur zum Kopieren.")
        showForInteraction()
    }

    /// Used by the isolated debug preview, never by production delivery logic.
    func preview(_ value: Display) {
        busy = value == .recording || value == .processing || value == .cancelling
        showingText = value == .manual
        textView.string = "Wir besprechen den Entwurf am Montag."
        window?.title = "OpenDictate – Vorschau"
        set(
            value,
            detail: value == .unconfirmed
                ? Self.pasteDetail : "Gestaltungsvorschau · kein Mikrofon, kein Upload, kein Kopieren.")
    }

    private func set(_ value: Display, detail text: String) {
        let changed = display != value
        display = value
        currentDetail = text
        render()
        if changed, window?.isVisible == true {
            if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                icon.alphaValue = 0.65
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.16
                    icon.animator().alphaValue = 1
                }
            }
            NSAccessibility.post(
                element: headline, notification: .announcementRequested,
                userInfo: [.announcement: value.title, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
        }
    }

    private func build() {
        window?.contentView = content
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20)
        ])
        settings.target = self
        settings.action = #selector(openSettings)
        settings.prominent = false
        settings.setAccessibilityLabel("Einstellungen öffnen")
        stack.addArrangedSubview(settings)
        settings.widthAnchor.constraint(equalToConstant: 150).isActive = true
        settings.heightAnchor.constraint(equalToConstant: 36).isActive = true
        iconSurface.translatesAutoresizingMaskIntoConstraints = false
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconSurface.addSubview(icon)
        icon.setAccessibilityElement(false)
        iconSurface.setAccessibilityElement(false)
        NSLayoutConstraint.activate([
            iconSurface.widthAnchor.constraint(equalToConstant: 64),
            iconSurface.heightAnchor.constraint(equalToConstant: 64),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),
            icon.centerXAnchor.constraint(equalTo: iconSurface.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconSurface.centerYAnchor)
        ])
        stack.addArrangedSubview(iconSurface)
        headline.font = .systemFont(ofSize: 20, weight: .semibold)
        headline.alignment = .center
        detail.font = .systemFont(ofSize: 14)
        detail.textColor = PanelColors.secondary
        detail.alignment = .center
        shortcut.font = .systemFont(ofSize: 13)
        shortcut.textColor = PanelColors.secondary
        shortcut.alignment = .center
        for field in [headline, detail] {
            field.setContentCompressionResistancePriority(.required, for: .vertical)
            stack.addArrangedSubview(field)
            field.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.font = .systemFont(ofSize: 15)
        textView.textColor = PanelColors.ink
        textView.backgroundColor = PanelColors.inset
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.setAccessibilityLabel("Verfügbarer Text")
        textScroll.documentView = textView
        textScroll.hasVerticalScroller = true
        textScroll.borderType = .bezelBorder
        stack.addArrangedSubview(textScroll)
        textScroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        textHeight = textScroll.heightAnchor.constraint(equalToConstant: 130)
        textHeight.isActive = true
        primary.target = self
        primary.action = #selector(primaryAction)
        primary.font = .systemFont(ofSize: 14, weight: .medium)
        primary.setAccessibilityIdentifier("dictation-primary")
        secondary.target = self
        secondary.action = #selector(secondaryAction)
        secondary.prominent = false
        for button in [primary, secondary] {
            stack.addArrangedSubview(button)
            button.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        }
        stack.addArrangedSubview(shortcut)
        shortcut.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        actions.target = self
        actions.action = #selector(openActions)
        actions.bezelStyle = .rounded
        actions.setAccessibilityIdentifier("dictation-actions")
        stack.addArrangedSubview(actions)
        window?.initialFirstResponder = primary
    }

    private func render() {
        headline.stringValue = display.title
        headline.textColor = display.color
        detail.stringValue = currentDetail
        icon.image = NSImage(systemSymbolName: display.symbol, accessibilityDescription: nil)
        icon.contentTintColor = display.color
        settings.isEnabled = !busy
        primary.isHidden = display == .processing || display == .cancelling
        primary.isEnabled = !busy || display == .recording
        secondary.isHidden = ![.recording, .processing, .retry, .manual, .unconfirmed, .failure].contains(display)
        secondary.isEnabled = display != .cancelling && (!busy || display == .recording || display == .processing)
        textScroll.isHidden = !showingText
        switch display {
        case .ready, .confirmed: primary.title = "Aufnahme starten"
        case .recording: primary.title = "Aufnahme beenden"
        case .manual: primary.title = "Text kopieren"
        case .unconfirmed: primary.title = showingText ? "Text kopieren" : "Text ansehen"
        case .failure: primary.title = "Aufbewahrte Aufnahmen"
        case .retry: primary.title = "Erneut verarbeiten"
        case .processing, .cancelling: break
        }
        secondary.title = display == .retry ? "Zurück" : busy ? "Abbrechen" : "Neues Diktat"
        // Keep our small custom control set keyboard reachable independently of
        // the system's optional Tab navigation to all standard controls.
        keyViews = []
        if settings.isEnabled { keyViews.append(settings) }
        if showingText { keyViews.append(textView) }
        if !primary.isHidden && primary.isEnabled { keyViews.append(primary) }
        if !secondary.isHidden && secondary.isEnabled { keyViews.append(secondary) }
        keyViews.append(actions)
        for (index, view) in keyViews.enumerated() {
            view.nextKeyView = keyViews[(index + 1) % keyViews.count]
        }
        if window?.isKeyWindow == true, !keyViews.contains(where: { $0 === window?.firstResponder }) {
            window?.makeFirstResponder(keyViews.first(where: { $0 === primary }) ?? keyViews.first)
        }
        content.layoutSubtreeIfNeeded()
        if let window {
            let desired = max(370, content.subviews.first?.fittingSize.height ?? 370) + 16
            let available = (window.screen ?? NSScreen.main)?.visibleFrame.height ?? 800
            let height = min(available - 40, desired + (window.frame.height - window.contentLayoutRect.height))
            if abs(window.frame.height - height) > 1 {
                var frame = window.frame
                frame.origin.y += frame.height - height
                frame.size.height = height
                window.setFrame(frame, display: true, animate: false)
            }
        }
    }

    @objc private func openSettings() { onSettings?() }
    @objc private func openActions() { onActions?(actions) }

    private func moveKeyboardFocus(reverse: Bool) -> Bool {
        guard !keyViews.isEmpty, let window else { return false }
        let current = keyViews.firstIndex { $0 === window.firstResponder }
        let next =
            current.map { ($0 + (reverse ? keyViews.count - 1 : 1)) % keyViews.count }
            ?? (reverse ? keyViews.count - 1 : 0)
        return window.makeFirstResponder(keyViews[next])
    }
    @objc private func primaryAction() {
        switch display {
        case .ready, .confirmed, .recording: onRecord?()
        case .manual: onCopy?()
        case .unconfirmed:
            if showingText {
                onCopy?()
            } else {
                showingText = true
                currentDetail = "Möglicherweise bereits eingefügt. Prüfe das Ziel, um eine Doppelung zu vermeiden."
                render()
                window?.makeFirstResponder(textView)
            }
        case .failure: onRecovery?()
        case .retry: onRetry?()
        case .processing, .cancelling: break
        }
    }

    @objc private func secondaryAction() {
        if busy {
            set(.cancelling, detail: "Die laufende Arbeit wird beendet. Bitte warte.")
            onCancel?()
        } else if display == .retry {
            onRecovery?()
        } else {
            showingText = false
            set(.ready, detail: "Starte die Aufnahme oder nutze dein Tastenkürzel.")
        }
    }
}

private final class DictationUtilityPanel: NSPanel {
    var navigateFocus: ((Bool) -> Bool)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == 48,
            event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
            navigateFocus?(event.modifierFlags.contains(.shift)) == true
        {
            return
        }
        super.sendEvent(event)
    }
}

@MainActor
enum PanelColors {
    static func hex(_ value: Int) -> NSColor {
        NSColor(
            srgbRed: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255,
            blue: CGFloat(value & 255) / 255, alpha: 1)
    }
    static func pair(_ light: Int, _ dark: Int) -> NSColor {
        NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(
                srgbRed: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255,
                blue: CGFloat(value & 255) / 255, alpha: 1)
        }
    }
    static var background: NSColor { pair(0xF3F5F8, 0x20252D) }
    static var raised: NSColor { pair(0xFFFFFF, 0x2C3440) }
    static var inset: NSColor { pair(0xE7ECF2, 0x171D25) }
    static var ink: NSColor { pair(0x202936, 0xF2F5FA) }
    static var secondary: NSColor { pair(0x536174, 0xB6C1D1) }
}

@MainActor
private final class PanelSurface: NSView {
    private let raised: Bool
    init(raised: Bool = false) {
        self.raised = raised
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { nil }
    override func draw(_ dirtyRect: NSRect) {
        if raised {
            let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 3), xRadius: 20, yRadius: 20)
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
            shadow.shadowBlurRadius = 5
            shadow.shadowOffset = NSSize(width: 0, height: -2)
            if !NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast { shadow.set() }
            PanelColors.raised.setFill()
            shape.fill()
            NSGraphicsContext.restoreGraphicsState()
            NSGradient(starting: PanelColors.raised, ending: PanelColors.inset)?.draw(in: shape, angle: -90)
            PanelColors.secondary.withAlphaComponent(0.4).setStroke()
            shape.stroke()
        } else {
            PanelColors.background.setFill()
            bounds.fill()
        }
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

/// Native NSButton semantics, keyboard handling and focus ring; custom paint only.
@MainActor
private final class TactileButton: NSButton {
    var prominent = true
    override var acceptsFirstResponder: Bool { isEnabled && !isHidden }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { isEnabled }
    override var focusRingMaskBounds: NSRect { bounds.insetBy(dx: 3, dy: 3) }
    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: focusRingMaskBounds, xRadius: 14, yRadius: 14).fill()
    }
    override func draw(_ dirtyRect: NSRect) {
        let pressed = cell?.isHighlighted == true
        let rect = bounds.insetBy(dx: 3, dy: 3).offsetBy(dx: 0, dy: pressed ? -1 : 0)
        let shape = NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14)
        let highContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        if prominent, !pressed && !highContrast {
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
            shadow.shadowBlurRadius = 4
            shadow.shadowOffset = NSSize(width: 0, height: -2)
            shadow.set()
            PanelColors.ink.setFill()
            shape.fill()
            NSGraphicsContext.restoreGraphicsState()
        }
        if prominent {
            if highContrast {
                PanelColors.pair(0x253145, 0xEDF2FA).setFill()
                shape.fill()
            } else {
                NSGradient(
                    starting: PanelColors.pair(0x414D60, 0xEDF2FA), ending: PanelColors.pair(0x253145, 0xCAD5E5)
                )?.draw(in: shape, angle: -90)
            }
        }
        if pressed, prominent {
            NSColor.black.withAlphaComponent(0.08).setFill()
            shape.fill()
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: prominent
                ? PanelColors.pair(0xFFFFFF, 0x202936)
                : (isEnabled ? PanelColors.ink : PanelColors.secondary), .paragraphStyle: paragraph
        ]
        let size = (title as NSString).size(withAttributes: attributes)
        (title as NSString).draw(
            in: NSRect(x: rect.minX + 8, y: rect.midY - size.height / 2, width: rect.width - 16, height: size.height),
            withAttributes: attributes)
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}
