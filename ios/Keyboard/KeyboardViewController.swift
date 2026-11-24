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
    /// A finished dictation for another field (or one iOS no longer names the
    /// same): offered with one tap instead of put in by itself.
    private let offerButton = UIButton(configuration: .gray())
    private var offer: (text: String, resultID: String?)?
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
        rows.bubbleText = { [weak self] value in self?.shifted(value) ?? value }
        updateShiftForContext()
        refresh()
        startPolling()
    }

    /// Reads the app's state four times a second, but only while something
    /// runs or waits; the app's notifications wake it again.
    private func startPolling() {
        guard poll == nil else { return }
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
        rows.hideBubble()
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
        // The key area reaches the keyboard's edges, so a tap in the margin
        // still finds the key next to it; the keys keep their inset.
        // iOS hands a keyboard no touches where its pixels are fully clear;
        // a barely visible tint makes the gaps and margins touchable.
        rows.backgroundColor = UIColor.black.withAlphaComponent(0.002)
        rows.isLayoutMarginsRelativeArrangement = true
        rows.layoutMargins = UIEdgeInsets(top: 6, left: 3, bottom: 4, right: 3)
        view.addSubview(rows)
        NSLayoutConstraint.activate([
            rows.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rows.topAnchor.constraint(equalTo: view.topAnchor),
            rows.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        rows.onCharacter = { [weak self] value, tap in self?.typeCharacter(value, tap: tap) }

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
        offerButton.isHidden = true
        offerButton.accessibilityIdentifier = "openDictate.offer"
        offerButton.configuration?.titleLineBreakMode = .byTruncatingTail
        offerButton.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 15, weight: .medium)
            return outgoing
        }
        offerButton.addAction(UIAction { [weak self] _ in self?.insertOffer() }, for: .touchUpInside)
        let top = UIStackView(arrangedSubviews: [statusLabel, strip, offerButton, dictateButton])
        top.spacing = 8
        top.isLayoutMarginsRelativeArrangement = true
        top.layoutMargins = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 3)
        rows.addArrangedSubview(top)
        topRow = top
        rows.topRow = top
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
        rows.characterKeys = [:]
        rows.allKeys = []
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
            // Touches go to the key area (rollover, bubble); this action is VoiceOver's.
            let button = key(value, identifier: "openDictate.key.\(value)") { [weak self] in
                self?.typeCharacter(value, tap: nil)
            }
            rows.characterKeys[value] = button
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
        lastShiftTap = 0
        assistant.deleteBackward(textDocumentProxy)
        updateShiftForContext()
        updateSuggestions()
    }

    private func shiftKey() -> UIButton {
        let shift = key("⇧", identifier: "openDictate.shift", system: true) { [weak self] in
            self?.shiftTapped()
        }
        shift.accessibilityLabel = Self.pick("Shift", "Umschalt")
        shiftButton = shift
        return shift
    }

    /// Caps lock: shift twice in quick succession, as on Apple's keyboard.
    private var capsLocked = false
    private weak var shiftButton: UIButton?
    private var lastShiftTap: TimeInterval = 0
    private static let capsLockInterval: TimeInterval = 0.35

    /// A single tap acts at once; only a second quick one locks.
    private func shiftTapped() {
        let time = now
        if capsLocked {
            capsLocked = false
            isShifted = false
        } else if time - lastShiftTap < Self.capsLockInterval {
            // The second of two quick taps locks, whatever the first did: at a
            // sentence start the first one turned the automatic capital off.
            capsLocked = true
            isShifted = true
        } else {
            isShifted.toggle()
        }
        lastShiftTap = time
        updateLetterTitles()
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
        // The bubble shows the period while the key is down and the comma once it is held.
        period.addTarget(self, action: #selector(periodDown(_:)), for: .touchDown)
        period.addTarget(self, action: #selector(periodUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        periodHold = hold
        return period
    }

    /// The period key's hold, so cancelling its touch for the hold keeps the comma bubble.
    private weak var periodHold: UILongPressGestureRecognizer?

    @objc private func periodDown(_ period: UIButton) { rows.showBubble(".", over: period) }

    @objc private func periodUp() {
        // A recognised hold cancels the button's touch; the comma bubble stays until the hold ends.
        if let periodHold, [.began, .changed].contains(periodHold.state) { return }
        rows.hideBubble()
    }

    @objc private func periodTapped() {
        rows.hideBubble()
        type(".")
    }

    /// Where the last cursor step was taken, along the space bar.
    private var slideAnchor: CGFloat?
    /// Whether this hold moved the cursor; a hold that did not is a space.
    private var slid = false
    private static let slideStep: CGFloat = 9

    @objc private func spaceSlid(_ recognizer: UILongPressGestureRecognizer) {
        let x = recognizer.location(in: view).x
        switch recognizer.state {
        case .began:
            slideAnchor = x
            slid = false
        case .changed:
            guard var anchor = slideAnchor else { return }
            while x - anchor >= Self.slideStep {
                textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
                anchor += Self.slideStep
                slid = true
            }
            while anchor - x >= Self.slideStep {
                textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)
                anchor -= Self.slideStep
                slid = true
            }
            slideAnchor = anchor
        case .ended where !slid:
            // Held without sliding: still a space, as a slow tap is.
            slideAnchor = nil
            assistant.space(textDocumentProxy)
            afterInput()
        default:
            slideAnchor = nil
            assistant.typedOther()
            afterInput()
        }
    }

    @objc private func periodHeld(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            if let period = recognizer.view as? UIButton { rows.showBubble(",", over: period) }
            type(",")
        case .changed:
            break
        default:
            rows.hideBubble()
        }
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
        // Rollover with system keys too: a letter still held is typed before the space.
        button.addAction(UIAction { [weak self] _ in self?.rows.commitHeld() }, for: .touchDown)
        rows.allKeys.append(button)
        return button
    }

    /// A character key's tap; `tap` is where it landed, for Tippen lernen.
    private func typeCharacter(_ value: String, tap: (x: Double, y: Double)?) {
        if layout == .letters, let tap {
            assistant.tapped(key: value, x: tap.x, y: tap.y)
        }
        type(value)
    }

    /// White on light, light gray on dark, like the system keyboard.
    private static let letterKeyColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 0.42, alpha: 1) : .white
    }

    private func type(_ value: String) {
        insert(shifted(value))
        if isShifted, !capsLocked, layout == .letters {
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
        // Two taps on shift lock capitals only when nothing came between them.
        lastShiftTap = 0
        updateShiftForContext()
        scheduleSuggestions()
    }

    // MARK: Suggestions

    private var suggestionsScheduled = false
    /// The text the strip was last built for; unchanged text keeps the strip.
    private var suggestedFor: String?

    /// The letter shows first; the strip follows once the key's work is done,
    /// once for several quick keys.
    private func scheduleSuggestions() {
        guard !suggestionsScheduled else { return }
        suggestionsScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            suggestionsScheduled = false
            updateSuggestions()
        }
    }

    private func updateSuggestions() {
        let context = textDocumentProxy.documentContextBeforeInput ?? ""
        guard context != suggestedFor else { return }
        suggestedFor = context
        let suggestions = assistant.refresh(textDocumentProxy)
        for view in strip.arrangedSubviews {
            strip.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        guard !suggestions.typed.isEmpty else {
            renderTop()
            return
        }
        // As on Apple's keyboard, quotes mark the typed word only when space would replace it.
        let typedTitle = suggestions.replacesOnSpace ? "„\(suggestions.typed)“" : suggestions.typed
        var slots: [(String, String, Bool)] = [(typedTitle, suggestions.typed, false)]
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
        let showsOffer = offer != nil && !dictating
        let showsStrip = !showsOffer && !assistant.current.typed.isEmpty && note == nil && !dictating
        if let offer, offerButton.accessibilityValue != offer.text {
            // One line: what tapping does, then the start of the text.
            let start = offer.text.count > 36 ? offer.text.prefix(36) + "…" : offer.text
            offerButton.configuration?.title = "⤵︎ " + start
            offerButton.accessibilityLabel = Self.pick("Insert dictation", "Diktat einsetzen")
            offerButton.accessibilityValue = offer.text
        }
        offerButton.isHidden = !showsOffer
        strip.isHidden = !showsStrip
        statusLabel.isHidden = showsStrip || showsOffer
    }

    private func insertOffer() {
        guard let offer else { return }
        self.offer = nil
        insert(offer.text)
        bridge.insertedResultID = offer.resultID
        jobID = nil
        renderTop()
    }

    private func updateShiftForContext() {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let trimmed = before.trimmingCharacters(in: .whitespaces)
        // A new line starts a sentence too.
        let shift =
            trimmed.isEmpty || trimmed.hasSuffix("\n") || trimmed.hasSuffix(".") || trimmed.hasSuffix("?")
            || trimmed.hasSuffix("!")
        guard !capsLocked, shift != isShifted,
            textDocumentProxy.autocapitalizationType != UITextAutocapitalizationType.none
        else { return }
        isShifted = shift
        updateLetterTitles()
    }

    private func updateLetterTitles() {
        shiftButton?.configuration?.title = capsLocked ? "⇪" : "⇧"
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
            bridge.send(KeyboardCommand(kind: .start, jobID: job, document: startDocument))
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
        // A keyboard shown anew (iOS may create one per showing), or one still
        // holding an earlier job, takes over a running dictation, so its key
        // can stop it and its text arrives.
        if let running = snapshot.jobID, running != jobID,
            [.recording, .writing].contains(snapshot.effectiveState(at: time))
        {
            jobID = running
            startDocument = snapshot.document.flatMap(UUID.init(uuidString:))
        }
        // Only into the field it was started in; anywhere else, or where iOS
        // names the field anew, it waits for a tap, and the recording stays kept.
        let sameField = KeyboardSnapshot.isSameField(started: startDocument, current: documentID)
        let text = snapshot.deliverableText(forJob: jobID, insertedResultID: bridge.insertedResultID, at: time)
        offer = isShown && !sameField ? text.map { ($0, snapshot.resultID) } : nil
        if isShown, sameField, let text {
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
        let idle = state == .off && jobID == nil && pendingState == nil && offer == nil && note == nil
        if idle {
            poll?.invalidate()
            poll = nil
        } else if isShown {
            startPolling()
        }
    }

    /// The dictation state last shown, so typing never hides "Listening".
    private var shownState = KeyboardSessionState.off

    /// What the key and status showed last; the same again draws nothing.
    private var rendered: (state: KeyboardSessionState, status: String?)?

    private func render(_ state: KeyboardSessionState, snapshot: KeyboardSnapshot) {
        shownState = state
        let status = note.flatMap { $0.until > now ? $0.text : nil } ?? statusText(state, snapshot: snapshot)
        #if DEBUG
            statusLabel.accessibilityValue =
                "state=\(state.rawValue);latencyMs=\(lastLatency ?? -1);memMB=\(Self.memoryMB())"
        #endif
        if let rendered, rendered.state == state, rendered.status == status {
            renderTop()
            return
        }
        rendered = (state, status)
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

        if note.map({ $0.until <= now }) ?? false { note = nil }
        statusLabel.text = status
        renderTop()
    }

    private func statusText(_ state: KeyboardSessionState, snapshot: KeyboardSnapshot) -> String {
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

/// The keys' stack. It takes the touches on character keys itself, so two
/// thumbs type in the order they went down (rollover: a key going down types
/// the one still held), a held key follows the finger, and a bubble shows the
/// key under it. Every point below the top row reaches a key: gaps and the
/// keyboard's margins go to the nearest one. With Tippen lernen on, a key's
/// area moves a little towards where the person really taps it
/// (`TypingModel`). System keys keep their own buttons and gestures, and every
/// key stays a button for VoiceOver.
final class KeyArea: UIStackView {
    var model: TypingModel?
    /// Keys that type a character, by that character.
    var characterKeys: [String: UIButton] = [:]
    /// Every key below the top row, character or not.
    var allKeys: [UIButton] = []
    /// The status, suggestions and dictation key: never reached from a gap.
    weak var topRow: UIView?
    var onCharacter: ((String, (x: Double, y: Double)?) -> Void)?
    var bubbleText: ((String) -> String)?

    private struct Held {
        var key: String
        var point: CGPoint
    }

    private var held: [ObjectIdentifier: Held] = [:]
    /// Touches in the order they went down, for rollover and the bubble.
    private var order: [ObjectIdentifier] = []
    private let bubble = KeyBubble()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        bubble.isHidden = true
        addSubview(bubble)
    }

    required init(coder: NSCoder) { fatalError("not used") }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard self.point(inside: point, with: event) else { return nil }
        let hit = super.hitTest(point, with: event)
        if let topRow, point.y < topRow.frame.maxY { return hit }
        let underPoint = allKeys.first { $0 === hit }
        // Only keys, gaps and margins: the emoji grid and the like keep their touches.
        guard underPoint != nil || hit === self || hit is UIStackView else { return hit }
        // A gap nearer to a row without keys (the emoji panel) belongs to that row.
        if underPoint == nil, let row = nearestRow(to: point),
            !allKeys.contains(where: { $0.isDescendant(of: row) })
        {
            return hit
        }
        if character(at: point, under: underPoint) != nil { return self }
        if let underPoint { return underPoint }
        return nearestKey(to: point) ?? hit
    }

    /// The character key a point belongs to, or nil when the point is on, or
    /// nearer to, a system key. Among character keys the nearest wins, or with
    /// Tippen lernen the one whose learned centre is nearest.
    private func character(at point: CGPoint, under underPoint: UIButton?) -> String? {
        if let underPoint, !isCharacterKey(underPoint) { return nil }
        if underPoint == nil, let nearest = nearestKey(to: point), !isCharacterKey(nearest) { return nil }
        var best: (key: String, score: Double)?
        for (key, button) in characterKeys {
            let frame = frame(of: button)
            guard frame.insetBy(dx: -frame.width / 2, dy: -frame.height / 2).contains(point) else { continue }
            let score: Double
            if let model {
                let offset = Self.offset(of: point, in: frame)
                score = model.distance(fromKey: key, x: offset.x, y: offset.y)
            } else {
                score = Double(distance(from: point, to: frame))
            }
            if let current = best, current.score <= score { continue }
            best = (key, score)
        }
        return best?.key
    }

    private func isCharacterKey(_ button: UIButton) -> Bool {
        characterKeys.values.contains { $0 === button }
    }

    private func nearestRow(to point: CGPoint) -> UIView? {
        arrangedSubviews.filter { !$0.isHidden && $0 !== topRow }.min {
            distance(from: point, to: frame(of: $0)) < distance(from: point, to: frame(of: $1))
        }
    }

    private func nearestKey(to point: CGPoint) -> UIButton? {
        allKeys.min { distance(from: point, to: frame(of: $0)) < distance(from: point, to: frame(of: $1)) }
    }

    // MARK: Touches on character keys

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            // The status row's label passes its touches on; they type nothing.
            if let topRow, point.y < topRow.frame.maxY { continue }
            guard let key = character(at: point, under: nil) else { continue }
            // Rollover: a key going down types every key still held first.
            for id in order { commit(id) }
            let id = ObjectIdentifier(touch)
            held[id] = Held(key: key, point: point)
            order.append(id)
        }
        showBubble()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            guard held[id] != nil else { continue }
            let point = touch.location(in: self)
            // The key follows the finger, as on Apple's keyboard.
            if let key = character(at: point, under: nil) { held[id]?.key = key }
            held[id]?.point = point
        }
        showBubble()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { commit(ObjectIdentifier(touch)) }
        showBubble()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            held[id] = nil
            order.removeAll { $0 == id }
        }
        showBubble()
    }

    /// Types every character still held, for a system key going down.
    func commitHeld() {
        for id in order { commit(id) }
        showBubble()
    }

    private func commit(_ id: ObjectIdentifier) {
        guard let touch = held.removeValue(forKey: id) else { return }
        order.removeAll { $0 == id }
        let tap = characterKeys[touch.key].map { Self.offset(of: touch.point, in: frame(of: $0)) }
        onCharacter?(touch.key, tap)
    }

    /// A key with its own gestures that shows a bubble while down, such as the period key.
    private var ownBubble: (text: String, key: UIButton)?

    /// Shows `text` over `button` until `hideBubble()`; a held character key's bubble comes first.
    func showBubble(_ text: String, over button: UIButton) {
        ownBubble = (text, button)
        showBubble()
    }

    func hideBubble() {
        ownBubble = nil
        showBubble()
    }

    private func showBubble() {
        if let id = order.last, let touch = held[id], let button = characterKeys[touch.key] {
            bubble.show(bubbleText?(touch.key) ?? touch.key, over: frame(of: button))
        } else if let ownBubble, ownBubble.key.window != nil {
            bubble.show(ownBubble.text, over: frame(of: ownBubble.key))
        } else {
            bubble.isHidden = true
            return
        }
        bringSubviewToFront(bubble)
    }

    // MARK: Geometry

    private func frame(of view: UIView) -> CGRect { view.convert(view.bounds, to: self) }

    private func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }

    private static func offset(of point: CGPoint, in frame: CGRect) -> (x: Double, y: Double) {
        (Double((point.x - frame.midX) / frame.width), Double((point.y - frame.midY) / frame.height))
    }
}

/// The enlarged character over a held key, as on Apple's iPhone keyboard.
private final class KeyBubble: UIView {
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        layer.cornerRadius = 8
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 3
        layer.shadowOffset = CGSize(width: 0, height: 1)
        backgroundColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.42, alpha: 1) : .white }
        label.font = .systemFont(ofSize: 34)
        label.textAlignment = .center
        label.textColor = .label
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func show(_ text: String, over key: CGRect) {
        label.text = text
        let width = key.width * 1.5
        let height = key.height * 1.3
        frame = CGRect(x: key.midX - width / 2, y: key.minY - height - 4, width: width, height: height)
        label.frame = bounds
        isHidden = false
    }
}
