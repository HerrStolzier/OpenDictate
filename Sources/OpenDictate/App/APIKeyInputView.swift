import AppKit

@MainActor
final class APIKeyInputView: NSView {
    private let secureField = NSSecureTextField()
    private let plainField = NSTextField()
    private let revealCheckbox = NSButton(checkboxWithTitle: "API-Schlüssel anzeigen", target: nil, action: nil)

    var stringValue: String {
        plainField.isHidden ? secureField.stringValue : plainField.stringValue
    }

    init(initialValue: String?) {
        super.init(frame: NSRect(x: 0, y: 0, width: 420, height: 62))
        setup(initialValue: initialValue ?? "")
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func setup(initialValue: String) {
        let fieldContainer = NSView()
        fieldContainer.translatesAutoresizingMaskIntoConstraints = false

        configureTextField(secureField, initialValue: initialValue)
        configureTextField(plainField, initialValue: initialValue)
        plainField.isHidden = true

        fieldContainer.addSubview(secureField)
        fieldContainer.addSubview(plainField)

        revealCheckbox.target = self
        revealCheckbox.action = #selector(toggleReveal)
        revealCheckbox.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [fieldContainer, revealCheckbox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),

            fieldContainer.widthAnchor.constraint(equalToConstant: 420),
            fieldContainer.heightAnchor.constraint(equalToConstant: 24),

            secureField.leadingAnchor.constraint(equalTo: fieldContainer.leadingAnchor),
            secureField.trailingAnchor.constraint(equalTo: fieldContainer.trailingAnchor),
            secureField.topAnchor.constraint(equalTo: fieldContainer.topAnchor),
            secureField.bottomAnchor.constraint(equalTo: fieldContainer.bottomAnchor),

            plainField.leadingAnchor.constraint(equalTo: fieldContainer.leadingAnchor),
            plainField.trailingAnchor.constraint(equalTo: fieldContainer.trailingAnchor),
            plainField.topAnchor.constraint(equalTo: fieldContainer.topAnchor),
            plainField.bottomAnchor.constraint(equalTo: fieldContainer.bottomAnchor)
        ])
    }

    private func configureTextField(_ field: NSTextField, initialValue: String) {
        field.stringValue = initialValue
        field.placeholderString = "sk-..."
        field.setAccessibilityLabel("OpenAI-API-Schlüssel")
        field.translatesAutoresizingMaskIntoConstraints = false
        field.isEditable = true
        field.isSelectable = true
    }

    @objc private func toggleReveal() {
        let shouldReveal = revealCheckbox.state == .on

        if shouldReveal {
            plainField.stringValue = secureField.stringValue
            secureField.isHidden = true
            plainField.isHidden = false
            window?.makeFirstResponder(plainField)
        } else {
            secureField.stringValue = plainField.stringValue
            plainField.isHidden = true
            secureField.isHidden = false
            window?.makeFirstResponder(secureField)
        }
    }
}
