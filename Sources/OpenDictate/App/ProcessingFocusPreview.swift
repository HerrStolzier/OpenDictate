#if DEBUG
    import AppKit
    import OpenDictateCore

    /// Explicit offline integration fixture: production flow, panel and delivery;
    /// fixed text replaces microphone and provider. Never reads user credentials.
    @MainActor
    final class ProcessingFocusPreview: NSObject, NSApplicationDelegate {
        private let panel = DictationPanel()
        private let controls = NSWindow(
            contentRect: NSRect(x: 80, y: 80, width: 460, height: 190),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        private let result = NSTextField(wrappingLabelWithString: "Noch nicht gestartet")
        private let startButton = NSButton(title: "Test vorbereiten", target: nil, action: nil)
        private let inserter = PasteboardInserter()
        private var target: NSRunningApplication?
        private var armTask: Task<Void, Never>?
        private var clipboard: [[NSPasteboard.PasteboardType: Data]] = []
        private var fixtureClipboardChange: Int?
        private lazy var flow = makeFlow()

        private func makeFlow() -> DictationFlow {
            DictationFlow(
                operations: .init(
                    start: {}, stop: { URL(fileURLWithPath: "/synthetic/no-audio.m4a") },
                    prepare: { PreparedAudio(url: $0, uploadDuration: 1) },
                    transcribeFile: { _ in
                        try await Task.sleep(for: .seconds(20))
                        return "OpenDictate Verarbeitungstest."
                    },
                    transcribeRetry: { _ in "" }, keep: { _ in true },
                    removeRetry: { _ in }, clean: { _ in },
                    copy: { [unowned self] text in
                        let copied = inserter.copy(text)
                        fixtureClipboardChange = NSPasteboard.general.changeCount
                        return copied
                    },
                    paste: { [unowned self] in await inserter.pasteIntoPreviousApp(target) }))
        }

        static func run(_ app: NSApplication) {
            let fixture = ProcessingFocusPreview()
            app.delegate = fixture
            app.setActivationPolicy(.regular)
            ApplicationMenu.install()
            fixture.show()
            withExtendedLifetime(fixture) { app.run() }
        }

        private func show() {
            clipboard = (NSPasteboard.general.pasteboardItems ?? []).map { item in
                Dictionary(
                    uniqueKeysWithValues: item.types.compactMap { type in
                        item.data(forType: type).map { (type, $0) }
                    })
            }
            controls.title = "OpenDictate – Verarbeitungstest ohne Audio"
            controls.isReleasedWhenClosed = false
            let stack = NSStackView()
            stack.orientation = .vertical
            stack.spacing = 12
            stack.edgeInsets = NSEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
            let detail = NSTextField(
                wrappingLabelWithString:
                    "Nach Start in ein leeres TextEdit-Testdokument wechseln. Dort beginnt eine 20-Sekunden-Verarbeitung. Fester Testtext, echte Zwischenablage und Einfügeprüfung; kein Mikrofon oder Upload."
            )
            startButton.target = self
            startButton.action = #selector(arm)
            for view in [detail, startButton, result] { stack.addArrangedSubview(view) }
            controls.contentView = stack
            controls.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            panel.onCancel = { [weak self] in self?.flow.cancel() }
            flow.onState = { [weak self] state in
                self?.panel.update(state: state)
                self?.startButton.isEnabled = state.canStart
            }
            flow.onStatus = { [weak self] in self?.panel.setStatus($0) }
            flow.onOutcome = { [weak self] outcome in
                guard let self else { return }
                panel.update(outcome: outcome, transcript: flow.lastTranscript)
                panel.window?.title = "OpenDictate – Verarbeitungstest"
                panel.show()
                let unchanged = NSWorkspace.shared.frontmostApplication?.processIdentifier == target?.processIdentifier
                result.stringValue = "Ergebnis: \(outcome). Ursprüngliches Ziel noch aktiv: \(unchanged)."
            }
        }

        @objc private func arm() {
            guard flow.state.canStart else { return }
            armTask?.cancel()
            startButton.isEnabled = false
            result.stringValue = "Warte bis zu 30 Sekunden auf TextEdit …"
            armTask = Task { @MainActor [weak self] in
                guard let self else { return }
                for _ in 0..<150 {
                    if let app = NSWorkspace.shared.frontmostApplication, app.bundleIdentifier == "com.apple.TextEdit" {
                        target = app
                        _ = try? flow.start()
                        _ = flow.stop()
                        panel.window?.title = "OpenDictate – Verarbeitungstest"
                        panel.show()
                        result.stringValue =
                            "Verarbeitung läuft 20 Sekunden. Jetzt im Ziel bleiben oder bewusst die App wechseln."
                        return
                    }
                    do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
                }
                result.stringValue = "Nicht gestartet: kein TextEdit im Vordergrund."
                startButton.isEnabled = true
            }
        }

        func applicationWillTerminate(_ notification: Notification) {
            armTask?.cancel()
            flow.cancel()
            let board = NSPasteboard.general
            guard fixtureClipboardChange == board.changeCount else { return }
            board.clearContents()
            let items = clipboard.map { values in
                let item = NSPasteboardItem()
                for (type, data) in values { item.setData(data, forType: type) }
                return item
            }
            board.writeObjects(items)
        }
    }
#endif
