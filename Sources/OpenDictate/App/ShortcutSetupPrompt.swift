import AppKit
import OpenDictateCore

/// First-launch question "how do you want to start recording?", followed by a
/// live check that the chosen key actually reaches OpenDictate.
@MainActor
enum ShortcutSetupPrompt {
    enum ArmResult {
        case listening
        /// Listening, but key events arrive only after the Accessibility permission.
        case needsPermission
        case failed(String)
    }

    /// Connects the prompt to the app's real registration so the check uses
    /// the same path as daily use.
    struct Tester {
        /// Starts listening for `trigger` and calls `arrived` on every press.
        /// Calling it again re-arms, for example after a permission change.
        let arm: @MainActor (RecordingTrigger, @escaping @MainActor () -> Void) -> ArmResult
        let disarm: @MainActor () -> Void
    }

    private enum TestOutcome { case accepted, otherOption, cancelled }

    private static let customTitle = "Eigenes Kürzel …"

    /// Returns the confirmed trigger, or nil when the user closed the question.
    /// `recommended` comes first and is preselected.
    static func run(tester: Tester, recommended: ModifierKey) -> RecordingTrigger? {
        let choices = RecordingTrigger.setupChoices(recommending: recommended)
        var selection = 0
        while true {
            guard let index = choose(choices, recommended: recommended, selected: selection) else { return nil }
            let trigger: RecordingTrigger
            if index == choices.count {
                guard let custom = ShortcutCaptureView.prompt() else {
                    selection = index
                    continue
                }
                trigger = .combination(custom)
            } else {
                trigger = choices[index]
            }
            switch test(trigger, tester: tester) {
            case .accepted: return trigger
            case .cancelled: return nil
            case .otherOption: selection = (index + 1) % (choices.count + 1)
            }
        }
    }

    private static func title(for trigger: RecordingTrigger, recommended: ModifierKey) -> String {
        let title =
            switch trigger {
            case .modifierKey(.fn): "Fn halten"
            case .modifierKey(.rightOption): "Rechte Wahltaste"
            case .combination(let shortcut) where shortcut == .controlOptionD: "⌃⌥D"
            case .combination(let shortcut): shortcut.displayName
            }
        return trigger == .modifierKey(recommended) ? "\(title) (Empfehlung)" : title
    }

    static let fnSystemHint =
        "Stell in den Systemeinstellungen unter Tastatur „🌐 drücken für“ auf „Nichts“. "
        + "Sonst öffnet Fn zusätzlich Emoji oder Apples Diktat."

    private static func hint(for trigger: RecordingTrigger?) -> String {
        switch trigger {
        case .modifierKey(.fn):
            "Halte Fn/🌐 gedrückt, solange du sprichst. Beim Loslassen wird transkribiert. " + fnSystemHint
        case .modifierKey(.rightOption):
            "Kurz antippen startet und stoppt die Aufnahme. Gedrückt halten nimmt auf, bis du loslässt. "
                + "Kombinationen wie ⌥L für @ funktionieren weiter."
        case .combination(let shortcut):
            "\(shortcut.displayName) startet und stoppt die Aufnahme. Dafür braucht OpenDictate keine weitere Freigabe."
        case nil:
            "Im nächsten Schritt drückst du eine eigene Kombination mit ⌘, ⌥ oder ⌃."
        }
    }

    // MARK: - Choice

    private static func choose(
        _ choices: [RecordingTrigger], recommended: ModifierKey, selected: Int
    ) -> Int? {
        let alert = NSAlert()
        alert.messageText = "Wie willst du die Aufnahme starten?"
        alert.informativeText =
            (recommended == .rightOption
                ? "Erkannt ist eine Tastatur mit Ziffernblock oder eines anderen Herstellers. Dort liegt "
                    + "Fn oft weit weg oder kommt bei macOS nicht an, deshalb ist die rechte Wahltaste "
                    + "vorausgewählt. "
                : "") + "Du kannst das später im Menü unter „Tastenkombination“ ändern."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Weiter")
        alert.addButton(withTitle: "Später").keyEquivalent = "\u{1b}"
        let titles = choices.map { title(for: $0, recommended: recommended) } + [customTitle]
        let hints = choices.map { hint(for: $0) } + [hint(for: nil)]
        let view = ChoiceView(titles: titles, hints: hints, selected: selected)
        alert.accessoryView = view
        alert.window.initialFirstResponder = view.radios[selected]
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return view.selected
    }

    // MARK: - Live check

    private static func test(_ trigger: RecordingTrigger, tester: Tester) -> TestOutcome {
        let check = LiveCheck(trigger: trigger, tester: tester)
        defer { check.finish() }
        switch check.alert.runModal() {
        case .alertFirstButtonReturn: return check.arrived ? .accepted : .cancelled
        case .alertSecondButtonReturn: return .otherOption
        default: return .cancelled
        }
    }
}

/// The "press it once" step: listens through the tester and tells the user
/// whether the key arrives, is taken, or still needs a permission.
@MainActor
private final class LiveCheck {
    let alert = NSAlert()
    private(set) var arrived = false
    private let trigger: RecordingTrigger
    private let tester: ShortcutSetupPrompt.Tester
    private let accept: NSButton
    private let status = NSTextField(wrappingLabelWithString: "Warte auf die Taste …")
    private let stack = NSStackView()
    private let permissionButton = ActionButton(title: "Bedienungshilfen öffnen") {
        SystemSettings.openAccessibility()
    }
    private var waitingForPermission = false
    private var listeningSince: Date?
    private var reportedSilence = false
    private var timer: Timer?

    init(trigger: RecordingTrigger, tester: ShortcutSetupPrompt.Tester) {
        self.trigger = trigger
        self.tester = tester
        alert.messageText = "Drück es jetzt einmal"
        alert.informativeText =
            "Teste „\(trigger.displayName)“, solange dieses Fenster offen ist. Eine Aufnahme startet dabei nicht."
        alert.alertStyle = .informational
        accept = alert.addButton(withTitle: "Übernehmen")
        accept.isEnabled = false
        alert.addButton(withTitle: "Andere Option")
        alert.addButton(withTitle: "Abbrechen").keyEquivalent = "\u{1b}"

        status.preferredMaxLayoutWidth = 360
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.addArrangedSubview(status)
        if trigger == .modifierKey(.fn) {
            let note = NSTextField(wrappingLabelWithString: ShortcutSetupPrompt.fnSystemHint)
            note.preferredMaxLayoutWidth = 360
            note.textColor = .secondaryLabelColor
            stack.addArrangedSubview(note)
            stack.addArrangedSubview(
                ActionButton(title: "Tastatur-Einstellungen öffnen") { SystemSettings.openKeyboard() })
        }
        permissionButton.isHidden = true
        stack.addArrangedSubview(permissionButton)
        resize()
        alert.accessoryView = stack

        arm()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func finish() {
        timer?.invalidate()
        timer = nil
        tester.disarm()
    }

    private func arm() {
        switch tester.arm(trigger, { [weak self] in self?.markArrived() }) {
        case .listening:
            waitingForPermission = false
            listeningSince = Date()
            permissionButton.isHidden = true
        case .needsPermission:
            waitingForPermission = true
            permissionButton.isHidden = false
            show(
                "Dafür braucht OpenDictate die Freigabe für Bedienungshilfen in den Systemeinstellungen, "
                    + "dieselbe wie fürs automatische Einfügen. Schalte OpenDictate dort ein und drück "
                    + "die Taste dann hier. Kommt sie danach nicht an, beende OpenDictate und starte es neu.")
        case .failed(let message):
            show("\(message) Wähle „Andere Option“.")
        }
    }

    private func markArrived() {
        guard !arrived else { return }
        arrived = true
        permissionButton.isHidden = true
        accept.isEnabled = true
        show("✓ Kommt an. Mit „Übernehmen“ speicherst du die Wahl.")
    }

    private func tick() {
        guard !arrived else { return }
        if waitingForPermission {
            guard ModifierKeyMonitor.hasPermission else { return }
            arm()
            if listeningSince != nil { show("Freigabe erteilt. Drück die Taste jetzt einmal.") }
        } else if let listeningSince, !reportedSilence, Date().timeIntervalSince(listeningSince) > 10 {
            reportedSilence = true
            show(
                "Noch nichts angekommen. Die Taste ist vielleicht belegt oder kommt nicht bei "
                    + "OpenDictate an. Wähle „Andere Option“.")
        }
    }

    private func show(_ text: String) {
        status.stringValue = text
        status.setAccessibilityValue(text)
        NSAccessibility.post(element: status, notification: .valueChanged)
        resize()
        alert.layout()
    }

    private func resize() {
        stack.frame = NSRect(x: 0, y: 0, width: 360, height: stack.fittingSize.height)
    }
}

/// Radio choices with a hint that follows the selection.
@MainActor
private final class ChoiceView: NSStackView {
    private(set) var radios: [NSButton] = []
    private let hints: [String]
    private let hintLabel = NSTextField(wrappingLabelWithString: "")
    private(set) var selected: Int

    init(titles: [String], hints: [String], selected: Int) {
        self.hints = hints
        self.selected = selected
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = 6
        for (index, title) in titles.enumerated() {
            let radio = NSButton(radioButtonWithTitle: title, target: self, action: #selector(select(_:)))
            radio.tag = index
            radio.state = index == selected ? .on : .off
            radios.append(radio)
            addArrangedSubview(radio)
        }
        hintLabel.preferredMaxLayoutWidth = 360
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.stringValue = hints[selected]
        setCustomSpacing(12, after: radios[radios.count - 1])
        addArrangedSubview(hintLabel)
        setAccessibilityLabel("Aufnahme starten mit")
        frame = NSRect(x: 0, y: 0, width: 360, height: fittingSize.height)
        // Reserve the tallest hint so the alert does not jump while choosing.
        let tallest =
            hints.map { hint -> CGFloat in
                hintLabel.stringValue = hint
                return hintLabel.fittingSize.height
            }.max() ?? 0
        hintLabel.stringValue = hints[selected]
        frame.size.height = fittingSize.height - hintLabel.fittingSize.height + tallest
    }

    required init?(coder: NSCoder) { nil }

    @objc private func select(_ sender: NSButton) {
        selected = sender.tag
        hintLabel.stringValue = hints[selected]
    }
}

/// A push button that runs a closure; NSAlert accessory views have no
/// controller to target.
@MainActor
private final class ActionButton: NSButton {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
        self.title = title
        bezelStyle = .rounded
        target = self
        action = #selector(run)
    }

    required init?(coder: NSCoder) { nil }

    @objc private func run() { handler() }
}
