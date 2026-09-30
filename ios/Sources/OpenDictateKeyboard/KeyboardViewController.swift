import UIKit

@MainActor
final class KeyboardViewController: UIInputViewController {
    private let keyboardStack = UIStackView()
    private let availabilityLabel = UILabel()
    private var insertButton: UIButton?
    private var sessionButton: UIButton?
    private var displayedAction: RecordingBridge.Action?
    private var refreshTimer: Timer?
    private var letterButtons: [UIButton] = []
    private var isShifted = false
    private var isKeyboardPresentationActive = false

    override func viewDidLoad() {
        super.viewDidLoad()
        buildKeyboard()
        updateAvailability()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isKeyboardPresentationActive = true
        updateAvailability()
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateAvailability() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        isKeyboardPresentationActive = false
        refreshTimer?.invalidate()
        refreshTimer = nil
        updateAvailability()
        super.viewWillDisappear(animated)
    }

    override func textWillChange(_ textInput: UITextInput?) {
        super.textWillChange(textInput)
        updateAvailability()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updateAvailability()
    }

    private func buildKeyboard() {
        view.backgroundColor = .secondarySystemBackground

        let height = view.heightAnchor.constraint(equalToConstant: 360)
        height.priority = UILayoutPriority(999)
        height.isActive = true

        keyboardStack.axis = .vertical
        keyboardStack.alignment = .fill
        keyboardStack.distribution = .fillEqually
        keyboardStack.spacing = 6
        keyboardStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardStack)

        NSLayoutConstraint.activate([
            keyboardStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            keyboardStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            keyboardStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            keyboardStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])

        availabilityLabel.text = "TEST · keine Transkription"
        availabilityLabel.font = .systemFont(ofSize: 12, weight: .medium)
        availabilityLabel.textAlignment = .center
        availabilityLabel.adjustsFontSizeToFitWidth = true
        availabilityLabel.minimumScaleFactor = 0.8
        availabilityLabel.accessibilityIdentifier = "openDictate.status"
        keyboardStack.addArrangedSubview(availabilityLabel)

        let testButton = makeButton(
            title: "SEPARATER TEXTTEST",
            identifier: "openDictate.insertSyntheticText",
            backgroundColor: .systemBlue
        ) { [weak self] in
            self?.insertSyntheticText()
        }
        insertButton = testButton
        keyboardStack.addArrangedSubview(testButton)

        let couplingButton = makeButton(
            title: "Keine Aufnahmesitzung",
            identifier: "openDictate.recordingSession",
            backgroundColor: .systemOrange
        ) { [weak self] in self?.handleSessionAction() }
        sessionButton = couplingButton
        keyboardStack.addArrangedSubview(couplingButton)

        keyboardStack.addArrangedSubview(makeEqualRow("qwertzuiop"))
        keyboardStack.addArrangedSubview(makeEqualRow("asdfghjkl"))
        keyboardStack.addArrangedSubview(makeLetterAndControlRow())
        keyboardStack.addArrangedSubview(makeBottomRow())
    }

    private func makeEqualRow(_ letters: String) -> UIStackView {
        let row = makeRow(distribution: .fillEqually)
        for letter in letters {
            let button = makeButton(title: String(letter), identifier: "openDictate.key.\(letter)") { [weak self] in
                self?.insertLetter(letter)
            }
            letterButtons.append(button)
            row.addArrangedSubview(button)
        }
        return row
    }

    private func makeLetterAndControlRow() -> UIStackView {
        let row = makeRow(distribution: .fillEqually)
        row.addArrangedSubview(
            makeButton(title: "⇧", identifier: "openDictate.shift") { [weak self] in
                self?.toggleShift()
            })

        for letter in "yxcvbnm" {
            let button = makeButton(title: String(letter), identifier: "openDictate.key.\(letter)") { [weak self] in
                self?.insertLetter(letter)
            }
            letterButtons.append(button)
            row.addArrangedSubview(button)
        }

        row.addArrangedSubview(
            makeButton(title: "⌫", identifier: "openDictate.delete") { [weak self] in
                self?.deleteBackward()
            })
        return row
    }

    private func makeBottomRow() -> UIStackView {
        let row = makeRow(distribution: .fill)
        let nextKeyboardButton = makeButton(
            title: "🌐",
            identifier: "openDictate.nextKeyboard"
        ) { [weak self] in
            self?.advanceToNextInputMode()
        }
        nextKeyboardButton.widthAnchor.constraint(equalToConstant: 48).isActive = true
        row.addArrangedSubview(nextKeyboardButton)

        let spaceButton = makeButton(title: "Leerzeichen", identifier: "openDictate.space") { [weak self] in
            self?.insertText(" ")
        }
        spaceButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spaceButton)

        let returnButton = makeButton(title: "↵", identifier: "openDictate.return") { [weak self] in
            self?.insertText("\n")
        }
        returnButton.widthAnchor.constraint(equalToConstant: 56).isActive = true
        row.addArrangedSubview(returnButton)
        return row
    }

    private func makeRow(distribution: UIStackView.Distribution) -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .fill
        row.distribution = distribution
        row.spacing = 4
        return row
    }

    private func makeButton(
        title: String,
        identifier: String,
        backgroundColor: UIColor = .tertiarySystemFill,
        action: @escaping () -> Void
    ) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.cornerStyle = .medium
        configuration.baseBackgroundColor = backgroundColor
        configuration.baseForegroundColor = .label

        let button = UIButton(configuration: configuration)
        button.accessibilityIdentifier = identifier
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.65
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func insertSyntheticText() {
        guard isKeyboardPresentationActive else {
            availabilityLabel.text = "Tastatur nicht aktiv"
            return
        }

        textDocumentProxy.insertText(RecordingSnapshot.testText)
        availabilityLabel.text = "Synthetischer Testtext eingefügt"
    }

    private func insertLetter(_ letter: Character) {
        guard isKeyboardPresentationActive else {
            updateAvailability()
            return
        }

        let value = isShifted ? String(letter).uppercased() : String(letter)
        insertText(value)
        if isShifted {
            isShifted = false
            updateLetterTitles()
        }
    }

    private func toggleShift() {
        isShifted.toggle()
        updateLetterTitles()
    }

    private func insertText(_ text: String) {
        guard isKeyboardPresentationActive else {
            updateAvailability()
            return
        }

        textDocumentProxy.insertText(text)
    }

    private func deleteBackward() {
        guard isKeyboardPresentationActive else {
            updateAvailability()
            return
        }

        textDocumentProxy.deleteBackward()
    }

    private func updateLetterTitles() {
        for button in letterButtons {
            guard let identifier = button.accessibilityIdentifier,
                let letter = identifier.split(separator: ".").last
            else {
                continue
            }
            let value = String(letter)
            button.setTitle(isShifted ? value.uppercased() : value, for: .normal)
        }
    }

    private func updateAvailability() {
        let available = isKeyboardPresentationActive
        insertButton?.isEnabled = available
        guard available else {
            sessionButton?.isEnabled = false
            displayedAction = nil
            availabilityLabel.text = "Tastatur nicht aktiv"
            return
        }
        // Keep the displayed meaning stable while a finger is holding this button.
        guard sessionButton?.isTracking != true else { return }
        sessionButton?.isEnabled = false
        displayedAction = nil
        guard let bridge else {
            availabilityLabel.text = "TEST · normale Tasten ohne Vollzugriff"
            sessionButton?.setTitle("Kopplung braucht vollen Zugriff", for: .normal)
            return
        }
        guard let current = try? bridge.snapshot(at: Date()) else {
            availabilityLabel.text = "TEST · keine aktuelle Aufnahmesitzung"
            sessionButton?.setTitle("Keine Aufnahmesitzung", for: .normal)
            return
        }
        switch current.phase {
        case .recording:
            let requested = bridge.hasStopRequest(id: current.id)
            availabilityLabel.text = "Aufnahme in Haupt-App · maximal 15 Sekunden"
            sessionButton?.setTitle(requested ? "Stopp angefordert" : "AUFNAHME STOPPEN", for: .normal)
            sessionButton?.isEnabled = !requested
            if !requested { displayedAction = .stop(current.id) }
        case .ready:
            let claimed = bridge.hasDeliveryClaim(id: current.id)
            availabilityLabel.text = "Aufnahme beendet · nur synthetischer Text"
            sessionButton?.setTitle(
                claimed ? "Texttest bereits verwendet" : "TESTTEXT NACH STOPP EINFÜGEN", for: .normal)
            sessionButton?.isEnabled = !claimed
            if !claimed { displayedAction = .insert(current.id) }
        case .failed:
            availabilityLabel.text = "Aufnahmesitzung fehlgeschlagen oder abgebrochen"
            sessionButton?.setTitle("Kein Ergebnis dieser Sitzung", for: .normal)
        }
    }

    private var bridge: RecordingBridge? {
        guard hasFullAccess else { return nil }
        return FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: RecordingSnapshot.groupIdentifier
        )
        .map { RecordingBridge(directory: $0.appendingPathComponent("recording-coupling-v1")) }
    }

    private func handleSessionAction() {
        guard isKeyboardPresentationActive, let bridge, let action = displayedAction else { return }
        do {
            // The displayed action owns its ID and meaning; a stop tap can never become an insertion.
            // No suspended work and no retained text proxy: insertion belongs to this tap.
            if let text = try bridge.perform(action, at: Date()) {
                textDocumentProxy.insertText(text)
            }
            updateAvailability()
        } catch {
            sessionButton?.isEnabled = false
            availabilityLabel.text = "Kopplung nicht verfügbar · normale Tasten bleiben nutzbar"
        }
    }
}
