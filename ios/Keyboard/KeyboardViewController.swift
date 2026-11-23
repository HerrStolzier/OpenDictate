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
        case emoji
    }

    private let bridge = KeyboardBridge()
    private let rows = KeyArea()
    private let statusLabel = UILabel()
    private let dictateButton = UIButton(configuration: .filled())
    /// Suggestions for the word being typed, in place of the status while typing.
    private let strip = UIStackView()
    private let assistant = TypingAssistant()
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
        requestLexicon()
        Self.current = self
        if !Self.observing {
            Self.observing = true
            KeyboardBridge.observe(KeyboardBridge.snapshotNotification) { KeyboardViewController.current?.refresh() }
        }
    }

    /// iOS calls the completion handler off the main queue, but the SDK
    /// declares it main-actor, so a Swift closure traps on the isolation check
    /// (seen in the simulator). The block is handed over through Objective-C
    /// and moves to the main queue itself.
    private func requestLexicon() {
        let selector = NSSelectorFromString("requestSupplementaryLexiconWithCompletion:")
        guard responds(to: selector) else { return }
        perform(selector, with: Self.lexiconHandler())
    }

    /// Made outside the main actor, so the block carries no isolation check.
    private nonisolated static func lexiconHandler() -> @convention(block) @Sendable (UILexicon) -> Void {
        { lexicon in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { KeyboardViewController.current?.assistant.load(lexicon) }
            }
        }
    }

    /// One observer per process; iOS may create a new controller for every showing.
    private static weak var current: KeyboardViewController?
    private static var observing = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        assistant.loadModel(hasFullAccess: hasFullAccess)
        rows.model = assistant.model
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
        assistant.saveModel()
        deleteRepeat?.invalidate()
        deleteRepeat = nil
        poll?.invalidate()
        poll = nil
        super.viewWillDisappear(animated)
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updateShiftForContext()
        updateSuggestions()
    }

    // MARK: Layout

    private func build() {
        view.backgroundColor = .clear
        let height = view.heightAnchor.constraint(equalToConstant: 270)
        height.priority = UILayoutPriority(999)
        height.isActive = true

        rows.axis = .vertical
        rows.distribution = .fill
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

        strip.distribution = .fillEqually
        strip.spacing = 1
        strip.isHidden = true
        strip.accessibilityIdentifier = "openDictate.suggestions"
        let top = UIStackView(arrangedSubviews: [statusLabel, strip, dictateButton])
        top.spacing = 8
        top.isLayoutMarginsRelativeArrangement = true
        top.layoutMargins = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 3)
        rows.addArrangedSubview(top)
        topRow = top
        rebuildKeys()
    }

    private weak var topRow: UIView?

    private func rebuildKeys() {
        while rows.arrangedSubviews.count > 1 {
            let row = rows.arrangedSubviews[1]
            rows.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        letterButtons = []
        rows.letterKeys = [:]
        switch layout {
        case .letters:
            addRow(row("qwertzuiopü"))
            addRow(row("asdfghjklöä"))
            addRow(row("yxcvbnmß", leading: shiftKey(), delete: true))
        case .symbols:
            addRow(row("1234567890"))
            addRow(row("-/:;()€&@\""))
            addRow(row(".,?!'%+=#", delete: true))
        case .emoji:
            let panel = EmojiPanel()
            panel.onPick = { [weak self] emoji in self?.insert(emoji) }
            // As tall as the three key rows it replaces.
            addRow(panel, rows: 3)
        }
        addRow(bottomRow())
        updateLetterTitles()
    }

    /// Every key row as tall as the top row, so the layout keeps its height.
    private func addRow(_ row: UIView, rows count: CGFloat = 1) {
        rows.addArrangedSubview(row)
        guard let topRow else { return }
        row.heightAnchor.constraint(
            equalTo: topRow.heightAnchor, multiplier: count, constant: (count - 1) * rows.spacing
        )
        .isActive = true
    }

    private func row(_ characters: String, leading: UIButton? = nil, delete: Bool = false) -> UIStackView {
        let letters = UIStackView()
        letters.spacing = 5
        letters.distribution = .fillEqually
        for character in characters {
            let value = String(character)
            let button = key(value, identifier: "openDictate.key.\(value)") { [weak self] in
                guard let self else { return }
                if layout == .letters, let tap = rows.lastTap(on: value) {
                    assistant.tapped(key: value, x: tap.x, y: tap.y)
                }
                type(value)
            }
            rows.letterKeys[value] = button
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
            outer.addArrangedSubview(deleteKey())
        }
        return outer
    }

    private func deleteKey() -> UIButton {
        let delete = key("⌫", identifier: "openDictate.delete", system: true) { [weak self] in
            self?.deleteOnce()
        }
        delete.accessibilityLabel = Self.pick("Delete", "Löschen")
        delete.widthAnchor.constraint(equalToConstant: 42).isActive = true
        // Held: deletes on, a character every tenth of a second, as on Apple's keyboard.
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(deleteHeld(_:)))
        hold.minimumPressDuration = 0.4
        delete.addGestureRecognizer(hold)
        return delete
    }

    private var deleteRepeat: Timer?

    @objc private func deleteHeld(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            deleteOnce()
            deleteRepeat = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.deleteOnce() }
            }
        case .changed:
            break
        default:
            deleteRepeat?.invalidate()
            deleteRepeat = nil
        }
    }

    private func deleteOnce() {
        assistant.deleteBackward(textDocumentProxy)
        updateShiftForContext()
        updateSuggestions()
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
        if layout != .emoji {
            let emojiKey = key("😊", identifier: "openDictate.emojiKey", system: true) { [weak self] in
                guard let self else { return }
                layout = .emoji
                rebuildKeys()
            }
            emojiKey.accessibilityLabel = "Emoji"
            emojiKey.widthAnchor.constraint(equalToConstant: 40).isActive = true
            bottom.addArrangedSubview(emojiKey)
        }
        // The Home-button-less iPhones show their own globe below the keyboard.
        if needsInputModeSwitchKey {
            let globe = key("🌐", identifier: "openDictate.nextKeyboard", system: true) {}
            globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
            globe.accessibilityLabel = Self.pick("Next keyboard", "Nächste Tastatur")
            globe.widthAnchor.constraint(equalToConstant: 44).isActive = true
            bottom.addArrangedSubview(globe)
        }
        if layout == .letters { bottom.addArrangedSubview(periodKey()) }
        let space = key(Self.pick("space", "Leerzeichen"), identifier: "openDictate.space") { [weak self] in
            guard let self else { return }
            assistant.space(textDocumentProxy)
            afterInput()
        }
        space.setContentHuggingPriority(.defaultLow, for: .horizontal)
        // Hold and slide: the cursor moves a character per step, as on Apple's keyboard.
        let slide = UILongPressGestureRecognizer(target: self, action: #selector(spaceSlid(_:)))
        slide.minimumPressDuration = 0.3
        space.addGestureRecognizer(slide)
        bottom.addArrangedSubview(space)
        if layout == .emoji { bottom.addArrangedSubview(deleteKey()) }
        let enter = key("↵", identifier: "openDictate.return", system: true) { [weak self] in
            self?.insert("\n")
        }
        enter.accessibilityLabel = Self.pick("Return", "Zeilenumbruch")
        enter.widthAnchor.constraint(equalToConstant: 84).isActive = true
        bottom.addArrangedSubview(enter)
        return bottom
    }

    /// Left of the space bar; a tap types a period, holding it a comma.
    private func periodKey() -> UIButton {
        let period = key(".", identifier: "openDictate.key.period") {}
        period.accessibilityHint = Self.pick("Hold for a comma", "Halten für ein Komma")
        period.widthAnchor.constraint(equalToConstant: 40).isActive = true
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(periodHeld(_:)))
        hold.minimumPressDuration = 0.35
        let tap = UITapGestureRecognizer(target: self, action: #selector(periodTapped))
        // A hold types only the comma, never the period as well.
        tap.require(toFail: hold)
        period.addGestureRecognizer(hold)
        period.addGestureRecognizer(tap)
        return period
    }

    @objc private func periodTapped() { type(".") }

    /// Where the last cursor step was taken, along the space bar.
    private var slideAnchor: CGFloat?
    private static let slideStep: CGFloat = 9

    @objc private func spaceSlid(_ recognizer: UILongPressGestureRecognizer) {
        let x = recognizer.location(in: view).x
        switch recognizer.state {
        case .began:
            slideAnchor = x
        case .changed:
            guard var anchor = slideAnchor else { return }
            while x - anchor >= Self.slideStep {
                textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
                anchor += Self.slideStep
            }
            while anchor - x >= Self.slideStep {
                textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)
                anchor -= Self.slideStep
            }
            slideAnchor = anchor
        default:
            slideAnchor = nil
            assistant.typedOther()
            afterInput()
        }
    }

    @objc private func periodHeld(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        type(",")
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
        insert(shifted(value))
        if isShifted, layout == .letters {
            isShifted = false
            updateLetterTitles()
        }
    }

    private func insert(_ text: String) {
        assistant.typedOther()
        textDocumentProxy.insertText(text)
        afterInput()
    }

    private func afterInput() {
        updateShiftForContext()
        updateSuggestions()
    }

    // MARK: Suggestions

    private func updateSuggestions() {
        let suggestions = assistant.refresh(textDocumentProxy)
        for view in strip.arrangedSubviews {
            strip.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        guard !suggestions.typed.isEmpty else {
            renderTop()
            return
        }
        var slots: [(String, String, Bool)] = [("„\(suggestions.typed)“", suggestions.typed, false)]
        if let best = suggestions.best { slots.append((best, best, suggestions.replacesOnSpace)) }
        if let second = suggestions.second { slots.append((second, second, false)) }
        for (index, slot) in slots.enumerated() {
            var configuration = UIButton.Configuration.plain()
            configuration.title = slot.0
            configuration.baseForegroundColor = .label
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 2)
            configuration.titleLineBreakMode = .byTruncatingTail
            configuration.background.backgroundColor = slot.2 ? Self.letterKeyColor : .clear
            configuration.background.cornerRadius = 6
            let bold = slot.2
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = .systemFont(ofSize: 16, weight: bold ? .semibold : .regular)
                return outgoing
            }
            let button = UIButton(configuration: configuration)
            button.accessibilityIdentifier = "openDictate.suggestion.\(index)"
            let word = slot.1
            button.addAction(
                UIAction { [weak self] _ in
                    guard let self else { return }
                    assistant.pick(word, in: textDocumentProxy)
                    afterInput()
                }, for: .touchUpInside)
            strip.addArrangedSubview(button)
        }
        renderTop()
    }

    /// While a word is typed the strip shows instead of the status, unless the
    /// status has something to say about a dictation.
    private func renderTop() {
        let dictating = shownState == .recording || shownState == .writing
        let showsStrip = !assistant.current.typed.isEmpty && note == nil && !dictating
        strip.isHidden = !showsStrip
        statusLabel.isHidden = showsStrip
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
            insert(text)
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

    /// The dictation state last shown, so typing never hides "Listening".
    private var shownState = KeyboardSessionState.off

    private func render(_ state: KeyboardSessionState, snapshot: KeyboardSnapshot) {
        shownState = state
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
        renderTop()
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

/// The keys' stack. With Tippen lernen on, a touch between keys goes to the
/// key whose learned centre (`TypingModel`) is nearest, which moves each key's
/// touch area a little towards where the person really taps it.
final class KeyArea: UIStackView {
    var model: TypingModel?
    var letterKeys: [String: UIButton] = [:]
    private var touch: (point: CGPoint, key: String)?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        let hitKey = letterKeys.first(where: { $0.value === hit })?.key
        // Without the model only a key's own area counts; with it, gaps too.
        guard hitKey != nil || (model != nil && !(hit is UIButton)) else { return hit }
        var chosen = hitKey ?? ""
        if let model {
            var best = Double.infinity
            for (key, button) in letterKeys {
                let frame = button.convert(button.bounds, to: self)
                // Inside a key its neighbours compete; in a gap only keys right next to it.
                let reach =
                    hitKey != nil
                    ? CGSize(width: frame.width / 2, height: frame.height / 2) : CGSize(width: 4, height: 4)
                guard frame.insetBy(dx: -reach.width, dy: -reach.height).contains(point) else { continue }
                let offset = Self.offset(of: point, in: frame)
                let distance = model.distance(fromKey: key, x: offset.x, y: offset.y)
                if distance < best {
                    best = distance
                    chosen = key
                }
            }
        }
        guard let button = letterKeys[chosen] else { return hit }
        touch = (point, chosen)
        return button
    }

    /// Where the last touch landed on `key`, from its centre in key sizes.
    func lastTap(on key: String) -> (x: Double, y: Double)? {
        guard let touch, touch.key == key, let button = letterKeys[key] else { return nil }
        return Self.offset(of: touch.point, in: button.convert(button.bounds, to: self))
    }

    private static func offset(of point: CGPoint, in frame: CGRect) -> (x: Double, y: Double) {
        (Double((point.x - frame.midX) / frame.width), Double((point.y - frame.midY) / frame.height))
    }
}
