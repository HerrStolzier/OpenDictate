import UIKit

/// The OpenDictate keyboard: a plain QWERTZ layout for typing, which works
/// without Full Access, and a dictation key. Dictation needs Full Access,
/// because only then may the keyboard reach the app through the App Group.
/// The app records and writes the text; the keyboard only inserts it.
@MainActor
final class KeyboardViewController: UIInputViewController {
    private enum Layout {
        case letters
        case symbols
    }

    private let bridge = KeyboardBridge()
    private let rows = UIStackView()
    private let statusLabel = UILabel()
    private let dictateButton = UIButton(configuration: .filled())
    private var letterButtons: [(UIButton, String)] = []
    private var layout = Layout.letters
    private var isShifted = true
    private var poll: Timer?
    /// The dictation this keyboard started, until its text is in.
    private var jobID: String?
    /// The field the dictation was started in.
    private var startDocument: UUID?
    /// iOS may still deliver notifications to a hidden keyboard.
    private var isShown = false
    /// Between a tap and the app's answer the key shows what was asked for.
    private var pendingState: KeyboardSessionState?
    private var pendingSince: TimeInterval = 0
    private var stoppedAt: TimeInterval?
    private var note: (text: String, until: TimeInterval)?
    #if DEBUG
        /// For the device test: stop-to-text time and memory, never the text.
        private var lastLatency: Int?
    #endif

    /// The extension has no localizations of its own, so it follows the iPhone's language.
    private static let isGerman = Locale.preferredLanguages.first?.lowercased().hasPrefix("de") ?? true
    private static func pick(_ english: String, _ german: String) -> String { isGerman ? german : english }

    override func viewDidLoad() {
        super.viewDidLoad()
        build()
        Self.current = self
        if !Self.observing {
            Self.observing = true
            KeyboardBridge.observe(KeyboardBridge.snapshotNotification) { KeyboardViewController.current?.refresh() }
        }
    }

    /// One observer per process; iOS may create a new controller for every showing.
    private static weak var current: KeyboardViewController?
    private static var observing = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateShiftForContext()
        refresh()
        poll = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isShown = true
        refresh()
    }

    override func viewWillDisappear(_ animated: Bool) {
        isShown = false
        poll?.invalidate()
        poll = nil
        super.viewWillDisappear(animated)
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updateShiftForContext()
    }

    // MARK: Layout

    private func build() {
        view.backgroundColor = .clear
        let height = view.heightAnchor.constraint(equalToConstant: 270)
        height.priority = UILayoutPriority(999)
        height.isActive = true

        rows.axis = .vertical
        rows.distribution = .fillEqually
        rows.spacing = 8
        rows.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rows)
        NSLayoutConstraint.activate([
            rows.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 3),
            rows.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -3),
            rows.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            rows.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4)
        ])

        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.adjustsFontSizeToFitWidth = true
        statusLabel.minimumScaleFactor = 0.7
        statusLabel.accessibilityIdentifier = "openDictate.status"

        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .medium
        configuration.imagePadding = 4
        configuration.titleLineBreakMode = .byClipping
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 15, weight: .semibold)
            return outgoing
        }
        dictateButton.configuration = configuration
        dictateButton.accessibilityIdentifier = "openDictate.dictate"
        dictateButton.addAction(UIAction { [weak self] _ in self?.dictateTapped() }, for: .touchUpInside)
        dictateButton.widthAnchor.constraint(equalToConstant: 128).isActive = true

        let top = UIStackView(arrangedSubviews: [statusLabel, dictateButton])
        top.spacing = 8
        top.isLayoutMarginsRelativeArrangement = true
        top.layoutMargins = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 3)
        rows.addArrangedSubview(top)
        rebuildKeys()
    }

    private func rebuildKeys() {
        while rows.arrangedSubviews.count > 1 {
            let row = rows.arrangedSubviews[1]
            rows.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        letterButtons = []
        switch layout {
        case .letters:
            rows.addArrangedSubview(row("qwertzuiopü"))
            rows.addArrangedSubview(row("asdfghjklöä"))
            rows.addArrangedSubview(row("yxcvbnmß", leading: shiftKey(), delete: true))
        case .symbols:
            rows.addArrangedSubview(row("1234567890"))
            rows.addArrangedSubview(row("-/:;()€&@\""))
            rows.addArrangedSubview(row(".,?!'%+=#", delete: true))
        }
        rows.addArrangedSubview(bottomRow())
        updateLetterTitles()
    }

    private func row(_ characters: String, leading: UIButton? = nil, delete: Bool = false) -> UIStackView {
        let letters = UIStackView()
        letters.spacing = 5
        letters.distribution = .fillEqually
        for character in characters {
            let value = String(character)
            let button = key(value, identifier: "openDictate.key.\(value)") { [weak self] in self?.type(value) }
            letterButtons.append((button, value))
            letters.addArrangedSubview(button)
        }
        let outer = UIStackView()
        outer.spacing = 8
        if let leading {
            outer.addArrangedSubview(leading)
            leading.widthAnchor.constraint(equalToConstant: 42).isActive = true
        }
        outer.addArrangedSubview(letters)
        if delete {
            let delete = key("⌫", identifier: "openDictate.delete", system: true) { [weak self] in
                self?.textDocumentProxy.deleteBackward()
            }
            delete.accessibilityLabel = Self.pick("Delete", "Löschen")
            delete.widthAnchor.constraint(equalToConstant: 42).isActive = true
            outer.addArrangedSubview(delete)
        }
        return outer
    }

    private func shiftKey() -> UIButton {
        let shift = key("⇧", identifier: "openDictate.shift", system: true) { [weak self] in
            guard let self else { return }
            isShifted.toggle()
            updateLetterTitles()
        }
        shift.accessibilityLabel = Self.pick("Shift", "Umschalt")
        return shift
    }

    private func bottomRow() -> UIStackView {
        let bottom = UIStackView()
        bottom.spacing = 5
        let modeKey = key(layout == .letters ? "123" : "ABC", identifier: "openDictate.mode", system: true) {
            [weak self] in
            guard let self else { return }
            layout = layout == .letters ? .symbols : .letters
            rebuildKeys()
        }
        modeKey.widthAnchor.constraint(equalToConstant: 48).isActive = true
        bottom.addArrangedSubview(modeKey)
        // The Home-button-less iPhones show their own globe below the keyboard.
        if needsInputModeSwitchKey {
            let globe = key("🌐", identifier: "openDictate.nextKeyboard", system: true) {}
            globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
            globe.accessibilityLabel = Self.pick("Next keyboard", "Nächste Tastatur")
            globe.widthAnchor.constraint(equalToConstant: 44).isActive = true
            bottom.addArrangedSubview(globe)
        }
        let space = key(Self.pick("space", "Leerzeichen"), identifier: "openDictate.space") { [weak self] in
            self?.type(" ")
        }
        space.setContentHuggingPriority(.defaultLow, for: .horizontal)
        bottom.addArrangedSubview(space)
        if layout == .letters {
            let period = key(".", identifier: "openDictate.key.period") { [weak self] in self?.type(".") }
            period.widthAnchor.constraint(equalToConstant: 40).isActive = true
            bottom.addArrangedSubview(period)
        }
        let enter = key("↵", identifier: "openDictate.return", system: true) { [weak self] in
            self?.textDocumentProxy.insertText("\n")
        }
        enter.accessibilityLabel = Self.pick("Return", "Zeilenumbruch")
        enter.widthAnchor.constraint(equalToConstant: 84).isActive = true
        bottom.addArrangedSubview(enter)
        return bottom
    }

    private func key(_ title: String, identifier: String, system: Bool = false, action: @escaping () -> Void)
        -> UIButton
    {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.cornerStyle = .medium
        configuration.baseBackgroundColor = system ? .systemGray3 : Self.letterKeyColor
        configuration.baseForegroundColor = .label
        configuration.contentInsets = .zero
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: system ? 16 : 22)
            return outgoing
        }
        let button = UIButton(configuration: configuration)
        button.accessibilityIdentifier = identifier
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    /// White on light, light gray on dark, like the system keyboard.
    private static let letterKeyColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 0.42, alpha: 1) : .white
    }

    private func type(_ value: String) {
        textDocumentProxy.insertText(shifted(value))
        if isShifted, layout == .letters {
            isShifted = false
            updateLetterTitles()
        }
    }

    private func updateShiftForContext() {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let trimmed = before.trimmingCharacters(in: .whitespaces)
        let shift = trimmed.isEmpty || trimmed.hasSuffix(".") || trimmed.hasSuffix("?") || trimmed.hasSuffix("!")
        guard shift != isShifted, textDocumentProxy.autocapitalizationType != UITextAutocapitalizationType.none
        else { return }
        isShifted = shift
        updateLetterTitles()
    }

    private func updateLetterTitles() {
        for (button, value) in letterButtons {
            button.configuration?.title = shifted(value)
        }
    }

    /// "ß" has no single capital on a German keyboard.
    private func shifted(_ value: String) -> String {
        isShifted && layout == .letters && value != "ß" ? value.uppercased() : value
    }

    // MARK: Dictation

    private var now: TimeInterval { Date().timeIntervalSince1970 }

    /// The field's identifier. The SDK declares it non-optional, but a hidden
    /// keyboard's proxy returns nil, and bridging that crashed the keyboard.
    private var documentID: UUID? {
        let proxy = textDocumentProxy as AnyObject
        let getter = NSSelectorFromString("documentIdentifier")
        guard proxy.responds(to: getter) else { return nil }
        return (proxy.perform(getter)?.takeUnretainedValue() as? NSUUID) as UUID?
    }

    private func dictateTapped() {
        guard hasFullAccess, bridge.isAvailable else {
            show(Self.pick("Turn on Full Access to dictate", "Zum Diktieren „Vollen Zugriff“ erlauben"))
            return
        }
        switch displayedState() {
        case .off:
            // Starts the warm session in the app; back with a swipe.
            if !ContainingAppOpener.open(KeyboardLink.startSession, from: self) {
                show(Self.pick("Open OpenDictate to start", "Öffne OpenDictate zum Starten"))
            }
        case .ready:
            let job = UUID().uuidString
            jobID = job
            startDocument = documentID
            stoppedAt = nil
            bridge.send(KeyboardCommand(kind: .start, jobID: job))
            expect(.recording)
        case .recording:
            guard let jobID else { return }
            stoppedAt = now
            bridge.send(KeyboardCommand(kind: .stop, jobID: jobID))
            expect(.writing)
        case .writing:
            break
        }
    }

    private func expect(_ state: KeyboardSessionState) {
        pendingState = state
        pendingSince = now
        refresh()
    }

    private func show(_ text: String) {
        note = (text, now + 4)
        refresh()
    }

    private func displayedState() -> KeyboardSessionState {
        guard hasFullAccess else { return .off }
        let actual = bridge.snapshot().effectiveState(at: now)
        if let pendingState {
            // The app answers within a heartbeat; after that its state counts.
            if actual == pendingState || now - pendingSince > 1.5 {
                self.pendingState = nil
            } else {
                return pendingState
            }
        }
        return actual
    }

    private func refresh() {
        let snapshot = hasFullAccess ? bridge.snapshot() : .off
        let time = now
        // A keyboard shown anew (iOS may create one per showing) takes over a
        // running dictation, so its key can stop it and its text arrives.
        if jobID == nil, let running = snapshot.jobID,
            [.recording, .writing].contains(snapshot.effectiveState(at: time))
        {
            jobID = running
            startDocument = nil
        }
        let sameField = startDocument == nil || startDocument == documentID
        if isShown, sameField,
            let text = snapshot.deliverableText(forJob: jobID, insertedResultID: bridge.insertedResultID, at: time)
        {
            textDocumentProxy.insertText(text)
            bridge.insertedResultID = snapshot.resultID
            jobID = nil
            #if DEBUG
                if let stoppedAt { lastLatency = Int((time - stoppedAt) * 1000) }
            #endif
            stoppedAt = nil
        }
        if let message = snapshot.currentMessage(forJob: jobID, at: time) {
            note = (message, time + 4)
            jobID = nil
        }
        let state = displayedState()
        render(state, snapshot: snapshot)
    }

    private func render(_ state: KeyboardSessionState, snapshot: KeyboardSnapshot) {
        var configuration = dictateButton.configuration ?? .filled()
        let title: String
        let symbol: String
        switch state {
        case .off, .ready:
            title = Self.pick("Dictate", "Diktieren")
            symbol = "mic.fill"
            configuration.baseBackgroundColor = state == .ready ? .systemGreen : .systemGray3
            configuration.baseForegroundColor = state == .ready ? .white : .label
        case .recording:
            title = Self.pick("Done", "Fertig")
            symbol = "stop.fill"
            configuration.baseBackgroundColor = .systemRed
            configuration.baseForegroundColor = .white
        case .writing:
            title = "…"
            symbol = "hourglass"
            configuration.baseBackgroundColor = .systemGray3
            configuration.baseForegroundColor = .label
        }
        configuration.title = title
        configuration.image = UIImage(systemName: symbol)
        dictateButton.configuration = configuration
        dictateButton.isEnabled = state != .writing

        if let note, note.until > now {
            statusLabel.text = note.text
        } else {
            note = nil
            statusLabel.text = status(state, snapshot: snapshot)
        }
        #if DEBUG
            statusLabel.accessibilityValue =
                "state=\(state.rawValue);latencyMs=\(lastLatency ?? -1);memMB=\(Self.memoryMB())"
        #endif
    }

    private func status(_ state: KeyboardSessionState, snapshot: KeyboardSnapshot) -> String {
        guard hasFullAccess else {
            return Self.pick("Dictation needs Full Access", "Diktat braucht „Vollen Zugriff“")
        }
        switch state {
        case .off: return Self.pick("Microphone off · tap to start", "Mikro aus · tippen zum Starten")
        case .ready:
            let minutes = max(1, Int(((snapshot.warmUntil - now) / 60).rounded(.up)))
            return Self.pick("Microphone warm · \(minutes) min", "Mikro warm · noch \(minutes) min")
        case .recording: return Self.pick("Listening …", "Hört zu …")
        case .writing: return Self.pick("Writing …", "Schreibt …")
        }
    }

    #if DEBUG
        private static func memoryMB() -> Int {
            var info = task_vm_info_data_t()
            var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
            let result = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
                }
            }
            return result == KERN_SUCCESS ? Int(info.phys_footprint / 1_048_576) : -1
        }
    #endif
}
