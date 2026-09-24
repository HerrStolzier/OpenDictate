#if DEBUG
    import AppKit

    /// Explicit, isolated native UI preview: bypasses AppDelegate construction,
    /// hotkeys, recording, Keychain, user settings, clipboard and all providers.
    @MainActor
    final class DesignPreview: NSObject {
        private let panel = DictationPanel()
        private let controls = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 190),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        private let states = NSPopUpButton()
        private let appearance = NSPopUpButton()
        private let settings = SettingsWindowController()
        private let focusResult = NSTextField(wrappingLabelWithString: "Fokusprüfung noch nicht gestartet")
        private var focusTask: Task<Void, Never>?

        static func runFocusFixture(_ app: NSApplication) {
            app.setActivationPolicy(.regular)
            ApplicationMenu.install()
            let window = NSWindow(
                contentRect: NSRect(x: 80, y: 400, width: 420, height: 180),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Leeres Fokus-Testfenster"
            window.isReleasedWhenClosed = false
            let field = NSTextField(string: "")
            field.placeholderString = "Nur künstlichen Testtext eingeben"
            field.setAccessibilityLabel("Fokus-Testtext")
            field.frame = NSRect(x: 20, y: 60, width: 380, height: 36)
            window.contentView?.addSubview(field)
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(field)
            app.activate(ignoringOtherApps: true)
            withExtendedLifetime(window) { app.run() }
        }

        static func run(_ app: NSApplication) {
            let preview = DesignPreview()
            app.setActivationPolicy(.regular)
            ApplicationMenu.install()
            let options = NSMenuItem(title: "Vorschauoptionen …", action: #selector(showOptions), keyEquivalent: "0")
            options.target = preview
            app.mainMenu?.items.first?.submenu?.insertItem(options, at: 0)
            preview.show()
            withExtendedLifetime(preview) { app.run() }
        }

        private func show() {
            controls.title = "OpenDictate – isolierte Gestaltungsvorschau"
            controls.isReleasedWhenClosed = false
            let stack = NSStackView()
            stack.orientation = .vertical
            stack.spacing = 12
            stack.edgeInsets = NSEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
            let label = NSTextField(wrappingLabelWithString: "Nur Beispieldaten · keine Aufnahme oder Übertragung")
            let passive = NSButton(
                title: "Passiven Status im Testfenster prüfen", target: self, action: #selector(testPassiveFocus))
            let minimumWidth = NSButton(
                title: "Mindestbreite prüfen", target: self, action: #selector(checkMinimumWidth))
            states.addItems(withTitles: DictationPanel.Display.allCases.map(\.title))
            states.target = self
            states.action = #selector(selectState)
            states.setAccessibilityLabel("Vorschauzustand")
            appearance.addItems(withTitles: ["System", "Hell", "Dunkel"])
            appearance.target = self
            appearance.action = #selector(selectAppearance)
            appearance.setAccessibilityLabel("Vorschaudarstellung")
            for view in [label, states, appearance, passive, minimumWidth, focusResult] {
                stack.addArrangedSubview(view)
            }
            controls.contentView = stack
            controls.center()
            controls.setFrameOrigin(NSPoint(x: 100, y: 100))
            controls.makeKeyAndOrderFront(nil)
            panel.setShortcut("⌥ ⇧ Leertaste · Beispiel")
            panel.onRecord = { [weak self] in
                guard let self else { return }
                panel.preview(panel.display == .recording ? .processing : .recording)
            }
            panel.onCancel = { [weak self] in self?.panel.preview(.ready) }
            panel.onRetry = { [weak self] in self?.panel.preview(.processing) }
            panel.onCopy = { [weak self] in self?.panel.setStatus("Kopieren nur simuliert. Zwischenablage unverändert.")
            }
            let showSettings: () -> Void = { [weak self] in
                let menu = NSMenu()
                menu.addItem(
                    withTitle: "Vorschau – keine gespeicherten Einstellungen gelesen", action: nil, keyEquivalent: "")
                menu.addItem(withTitle: "Mikrofon, Sprache, Modell und Tastenkürzel", action: nil, keyEquivalent: "")
                menu.addItem(withTitle: "Zugang und Wiederherstellung separat", action: nil, keyEquivalent: "")
                self?.settings.show(menu: menu)
            }
            panel.onSettings = showSettings
            panel.onRecovery = showSettings
            panel.preview(.ready)
            panel.showForInteraction()
        }

        @objc private func selectState() {
            panel.preview(DictationPanel.Display.allCases[states.indexOfSelectedItem])
            panel.showForInteraction()
        }
        @objc private func showOptions() { controls.makeKeyAndOrderFront(nil) }

        @objc private func checkMinimumWidth() {
            guard let window = panel.window else { return }
            var frame = window.frame
            let centerX = frame.midX
            frame.size.width = window.minSize.width
            frame.origin.x = centerX - frame.width / 2
            if let visibleFrame = (window.screen ?? NSScreen.main)?.visibleFrame {
                if frame.width <= visibleFrame.width {
                    frame.origin.x = min(max(frame.origin.x, visibleFrame.minX), visibleFrame.maxX - frame.width)
                }
                if frame.height <= visibleFrame.height {
                    frame.origin.y = min(max(frame.origin.y, visibleFrame.minY), visibleFrame.maxY - frame.height)
                }
            }
            window.setFrame(frame, display: true)
            panel.show()
        }

        @objc private func testPassiveFocus() {
            focusTask?.cancel()
            panel.window?.orderOut(nil)
            focusResult.stringValue = "Warte auf das Fokus-Testfenster …"
            focusTask = Task { @MainActor [weak self] in
                for _ in 0..<150 {
                    if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "local.opendictate.focusfixture" {
                        break
                    }
                    do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
                }
                guard let self else { return }
                let before = NSWorkspace.shared.frontmostApplication
                panel.show()
                do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
                let after = NSWorkspace.shared.frontmostApplication
                let passed =
                    before?.bundleIdentifier == "local.opendictate.focusfixture"
                    && before?.processIdentifier == after?.processIdentifier
                    && panel.window?.isKeyWindow == false
                focusResult.stringValue =
                    passed
                    ? "Bestanden: Ziel-App blieb aktiv; Status ohne Tastaturfokus."
                    : "Nicht bestätigt: Testfenster vorher aktiv: \(before?.bundleIdentifier == "local.opendictate.focusfixture"); Ziel unverändert: \(before?.processIdentifier == after?.processIdentifier); Status hat Tastaturfokus: \(panel.window?.isKeyWindow == true)."
            }
        }
        @objc private func selectAppearance() {
            panel.window?.appearance =
                switch appearance.indexOfSelectedItem {
                case 1: NSAppearance(named: .aqua)
                case 2: NSAppearance(named: .darkAqua)
                default: nil
                }
            panel.showForInteraction()
        }
    }
#endif
