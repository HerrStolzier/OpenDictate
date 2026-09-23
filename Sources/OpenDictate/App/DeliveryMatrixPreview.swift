#if DEBUG
    import AppKit
    import OpenDictateCore

    /// Explicit offline harness. No AppDelegate instance, audio, credentials,
    /// preferences, hotkeys or network. Only known local fixture windows qualify.
    @MainActor
    final class DeliveryMatrixPreview: NSObject, NSApplicationDelegate {
        static let sample = "Äpfel 🍏 und Grüße.\nZweite Zeile: e\u{301}, 👩🏽‍💻."
        private let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 500, height: 570),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        private let panel = DictationPanel()
        private let result = NSTextField(wrappingLabelWithString: "Bereit; nur lokale Matrix-Testfenster.")
        private let delay = NSButton(checkboxWithTitle: "5 Sekunden Verarbeitung simulieren", target: nil, action: nil)
        private let recordingDelay = NSButton(
            checkboxWithTitle: "10 Sekunden Aufnahme simulieren (ohne Mikrofon)", target: nil, action: nil)
        private let singleLine = NSButton(checkboxWithTitle: "Einzeiligen Testtext verwenden", target: nil, action: nil)
        private let longProbe = NSButton(
            checkboxWithTitle: "Lange Unicode-Probe (600 Wiederholungen)", target: nil, action: nil)
        private let lineProbe = NSButton(checkboxWithTitle: "CRLF und Leerzeilen prüfen", target: nil, action: nil)
        private let start = NSButton(title: "Lokales Testfeld erfassen", target: nil, action: nil)
        private let captureOnly = NSButton(
            checkboxWithTitle: "Nur Ziel prüfen (ohne Texteingabe)", target: nil, action: nil)
        private let targetApp = NSPopUpButton(frame: .zero, pullsDown: false)
        private let targetIDs = [
            "local.opendictate.matrixhost", "com.apple.Safari", "com.brave.Browser", "md.obsidian",
            "com.apple.TextEdit"
        ]
        private let board = NSPasteboard.general
        private let inserter = PasteboardInserter()
        private var target: NSRunningApplication?
        private var clipboard: [[NSPasteboard.PasteboardType: Data]] = []
        private var fixtureClipboardChange: Int?
        private var armTask: Task<Void, Never>?
        private var simulateDelay = false
        private var progressElapsed: Double = 80
        private var sampleText = DeliveryMatrixPreview.sample
        private var captureDetail = ""
        private lazy var flow = makeFlow()

        static func run(_ app: NSApplication) {
            let fixture = DeliveryMatrixPreview()
            app.delegate = fixture
            app.setActivationPolicy(.accessory)
            fixture.show()
            withExtendedLifetime(fixture) { app.run() }
        }

        private func makeFlow() -> DictationFlow {
            DictationFlow(
                operations: .init(
                    start: {}, stop: { URL(fileURLWithPath: "/synthetic/not-an-audio-file") },
                    prepare: { PreparedAudio(url: $0, uploadDuration: 1) },
                    transcribeFile: { [unowned self] _ in
                        if simulateDelay { try await Task.sleep(for: .seconds(5)) }
                        return sampleText
                    },
                    transcribeRetry: { _ in Self.sample }, keep: { _ in true }, removeRetry: { _ in }, clean: { _ in },
                    copy: { [unowned self] text in
                        let copied = inserter.copy(text, to: board)
                        if copied { fixtureClipboardChange = board.changeCount }
                        return copied
                    },
                    paste: { [unowned self] in await inserter.paste($0, into: target, board: board) }))
        }

        private func show() {
            clipboard = (board.pasteboardItems ?? []).map { item in
                Dictionary(
                    uniqueKeysWithValues: item.types.compactMap { type in
                        item.data(forType: type).map { (type, $0) }
                    })
            }
            window.title = "OpenDictate – isolierte Übergabeprüfung"
            window.isReleasedWhenClosed = false
            let stack = NSStackView()
            stack.orientation = .vertical
            stack.spacing = 12
            stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
            start.target = self
            start.action = #selector(arm)
            let quit = NSButton(title: "Prüfung beenden", target: NSApp, action: #selector(NSApplication.terminate(_:)))
            let shortcut = NSButton(title: "Tastaturdialog prüfen", target: self, action: #selector(checkShortcut))
            targetApp.addItems(withTitles: ["Native Testfelder", "Safari", "Brave", "Obsidian", "TextEdit"])
            targetApp.setAccessibilityLabel("Erwartete Test-App")
            let progress = NSButton(title: "Aufnahmestatus simulieren", target: self, action: #selector(checkProgress))
            let inspect = NSButton(title: "Ergebnis ansehen", target: self, action: #selector(inspectResult))
            for view in [
                targetApp, captureOnly, singleLine, longProbe, lineProbe, recordingDelay, delay, start, shortcut,
                progress,
                inspect, result, quit
            ] {
                stack.addArrangedSubview(view)
            }
            window.contentView = stack
            window.orderFrontRegardless()
            panel.onCancel = { [weak self] in self?.flow.cancel() }
            panel.onCopy = { [weak self] in _ = self?.flow.copyLastTranscript() }
            flow.onState = { [weak self] in self?.panel.update(state: $0) }
            flow.onStatus = { [weak self] in self?.panel.setStatus($0) }
            flow.onOutcome = { [weak self] outcome in
                guard let self else { return }
                result.stringValue =
                    "Ergebnis: \(outcome); Test-Zwischenablage vollständig: \(board.string(forType: .string) == sampleText)\n\(captureDetail)"
                panel.update(outcome: outcome, transcript: flow.lastTranscript)
                panel.window?.title = "OpenDictate – synthetisches Übergabeergebnis"
            }
        }

        @objc private func checkShortcut() {
            let shortcut = ShortcutCaptureView.prompt()
            result.stringValue =
                shortcut.map { "Testkombination: \($0.displayName); nicht gespeichert." }
                ?? "Tastaturdialog abgebrochen; nichts gespeichert."
        }

        @objc private func inspectResult() { panel.showForInteraction() }

        @objc private func checkProgress() {
            if let window = panel.window {
                var frame = window.frame
                frame.size.width = window.minSize.width
                window.setFrame(frame, display: true)
            }
            panel.update(state: .recording)
            panel.showForInteraction()
            panel.updateRecording(elapsed: progressElapsed, level: -70)
            panel.window?.title = "OpenDictate – synthetischer Aufnahmestatus"
            result.stringValue = "\(Int(progressElapsed)) Sekunden / −70 dB simuliert; keine Aufnahme."
            progressElapsed = progressElapsed == 80 ? 85 : 80
        }

        @objc private func arm() {
            guard flow.state.canStart, armTask == nil else { return }
            start.isEnabled = false
            simulateDelay = delay.state == .on
            let simulateRecording = recordingDelay.state == .on
            let inspectOnly = captureOnly.state == .on
            sampleText = singleLine.state == .on ? Self.sample.replacingOccurrences(of: "\n", with: " ") : Self.sample
            if lineProbe.state == .on { sampleText = "Erste\r\n\r\nZweite\n\nDritte" }
            if longProbe.state == .on { sampleText = Array(repeating: sampleText, count: 600).joined(separator: " ") }
            let expectedID = targetIDs[targetApp.indexOfSelectedItem]
            result.stringValue = "Warte höchstens 60 Sekunden auf ein lokales Matrix-Fenster …"
            armTask = Task { @MainActor in
                defer {
                    armTask = nil
                    start.isEnabled = true
                }
                let deadline = ContinuousClock.now.advanced(by: .seconds(60))
                while !Task.isCancelled && ContinuousClock.now < deadline {
                    if let app = NSWorkspace.shared.frontmostApplication,
                        app.bundleIdentifier == expectedID, Self.isLocalFixture(app.processIdentifier)
                    {
                        target = app
                        captureDetail = "App erfasst: \(expectedID); normales Einfügen über ⌘V."
                        if inspectOnly {
                            result.stringValue =
                                "Vordergrund bestätigt: \(expectedID)\n\(captureDetail)\nKeine Texteingabe."
                            return
                        }
                        _ = try? flow.start()
                        if simulateRecording {
                            result.stringValue = "Ziel erfasst: \(target != nil). 10 Sekunden synthetische Aufnahme."
                            do { try await Task.sleep(for: .seconds(10)) } catch { return }
                        }
                        result.stringValue = "Ziel erfasst: \(target != nil). Verarbeitung läuft."
                        _ = flow.stop()
                        await flow.task?.value
                        return
                    }
                    do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                }
                result.stringValue = "Kein lokales Matrix-Fenster im Vordergrund; keine Eingabe."
            }
        }

        private static func isLocalFixture(_ pid: pid_t) -> Bool {
            let app = AXUIElementCreateApplication(pid)
            var window: CFTypeRef?
            guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &window) == .success,
                let window, CFGetTypeID(window) == AXUIElementGetTypeID()
            else { return false }
            var title: CFTypeRef?
            _ = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title)
            return (title as? String)?.hasPrefix("OpenDictate Matrix") == true
        }

        func applicationWillTerminate(_ notification: Notification) {
            armTask?.cancel()
            flow.cancel()
            guard fixtureClipboardChange == board.changeCount else { return }
            board.clearContents()
            let items = clipboard.map { values in
                let item = NSPasteboardItem()
                for (type, data) in values { item.setData(data, forType: type) }
                return item
            }
            board.writeObjects(items)
        }

        static func runHost(_ app: NSApplication) {
            app.setActivationPolicy(.regular)
            ApplicationMenu.install()
            let host = NSWindow(
                contentRect: NSRect(x: 100, y: 400, width: 540, height: 350),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            host.title = "OpenDictate Matrix Native"
            host.isReleasedWhenClosed = false
            let stack = NSStackView()
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 12
            stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
            let first = NSTextField(string: "Anfang. Ende.")
            first.setAccessibilityLabel("Matrix Eingabe A")
            let second = NSTextField(string: "Unverändert.")
            second.setAccessibilityLabel("Matrix Eingabe B")
            let secure = NSSecureTextField(string: "")
            secure.setAccessibilityLabel("Matrix Passwort")
            let readonly = NSTextField(string: "Schreibgeschützt.")
            readonly.isEditable = false
            readonly.setAccessibilityLabel("Matrix Nur Lesen")
            for field in [first, second, secure, readonly] {
                stack.addArrangedSubview(field)
                field.widthAnchor.constraint(equalToConstant: 490).isActive = true
            }
            let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 490, height: 100))
            editor.string = "Anfang. MARKIERUNG Ende."
            editor.setAccessibilityLabel("Matrix Mehrzeilig")
            let scroll = NSScrollView()
            scroll.documentView = editor
            scroll.hasVerticalScroller = true
            stack.addArrangedSubview(scroll)
            scroll.widthAnchor.constraint(equalToConstant: 490).isActive = true
            scroll.heightAnchor.constraint(equalToConstant: 100).isActive = true
            host.contentView = stack
            host.makeKeyAndOrderFront(nil)
            host.makeFirstResponder(first)
            app.activate(ignoringOtherApps: true)
            withExtendedLifetime(host) { app.run() }
        }
    }
#endif
