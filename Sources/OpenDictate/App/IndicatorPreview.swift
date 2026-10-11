#if DEBUG
    import AppKit
    import OpenDictateCore

    /// Debug-only look at the indicator without hotkeys, recording, Keychain or
    /// providers. `--indicator-preview` cycles the real indicator through every
    /// state on the current screen; `--indicator-snapshots <folder>` writes one
    /// PNG per variant and state and quits.
    @MainActor
    enum IndicatorPreview {
        static func run(_ app: NSApplication, arguments: [String]) {
            BrandFonts.register()
            if let index = arguments.firstIndex(of: "--indicator-snapshots"), arguments.indices.contains(index + 1) {
                writeSnapshots(to: URL(fileURLWithPath: arguments[index + 1]))
                return
            }
            app.setActivationPolicy(.accessory)
            let indicator = DictationIndicator()
            let style = arguments.firstIndex(of: "--style").flatMap {
                arguments.indices.contains($0 + 1) ? IndicatorStyle(rawValue: arguments[$0 + 1]) : nil
            }
            indicator.style = { style ?? .default }
            indicator.canRetry = true
            if arguments.contains("--simulate-notch") { indicator.simulatedNotch = NSSize(width: 185, height: 32) }
            indicator.onStatusItemTitle = { title, _ in print("Status item:", title ?? "–") }
            indicator.onRetry = { print("Nochmal senden") }
            let steps: [(DictationDisplay, String, Double)] = [
                (.recording, "", 4), (.processing, "", 2.5), (.unconfirmed, "", 3), (.recording, "", 2),
                (.processing, "", 1.5), (.manual, "", 5),
                (.failure, "OpenAI ist gerade nicht erreichbar. Deine Aufnahme ist gesichert.", 6), (.ready, "", 2)
            ]
            Task { @MainActor in
                while true {
                    for (display, detail, seconds) in steps {
                        indicator.follow(display, detail: detail)
                        let start = Date()
                        while Date().timeIntervalSince(start) < seconds {
                            indicator.updateRecording(elapsed: Date().timeIntervalSince(start) + (seconds > 3 ? 78 : 2))
                            try? await Task.sleep(for: .milliseconds(200))
                        }
                    }
                }
            }
            withExtendedLifetime(indicator) { app.run() }
        }

        private static func writeSnapshots(to folder: URL) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let reasons =
                "OpenAI ist gerade nicht erreichbar. Prüfe die Internetverbindung. Deine Aufnahme ist gesichert."
            let cases: [(String, IndicatorPlacement, Bool)] = [
                ("notch", .notch, true), ("menubar", .menuBar, true), ("floating", .floating, true),
                ("fullscreen", .floating, false)
            ]
            for (name, placement, menuBar) in cases {
                for phase in IndicatorPhase.allCases where phase != .closed {
                    let view = IndicatorView()
                    view.target = IndicatorTarget(
                        frame: NSRect(x: 0, y: 0, width: 1512, height: 982),
                        info: IndicatorScreen(hasNotch: placement == .notch, showsMenuBar: menuBar),
                        notch: placement == .notch ? NSSize(width: 185, height: 32) : nil, centerX: 756,
                        menuBarHeight: placement == .notch ? 37 : 24)
                    view.placement = placement
                    view.canRetry = true
                    view.content = IndicatorContent(
                        phase: phase, elapsed: phase == .listening ? 3 : 0, translating: false, reason: reasons)
                    view.fitToPlan()
                    view.layoutSubtreeIfNeeded()
                    let size = NSSize(width: view.frame.width + 160, height: view.frame.height + 60)
                    let scale: CGFloat = 2
                    guard
                        let rep = NSBitmapImageRep(
                            bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale),
                            pixelsHigh: Int(size.height * scale), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
                    else { continue }
                    rep.size = size
                    let container = SnapshotBackdrop(
                        frame: NSRect(origin: .zero, size: size), bar: menuBar ? (placement == .notch ? 37 : 24) : 0)
                    view.frame.origin = NSPoint(x: 80, y: 0)
                    container.addSubview(view)
                    container.cacheDisplay(in: container.bounds, to: rep)
                    let name = "\(name)-\(phase.rawValue).png"
                    try? rep.representation(using: .png, properties: [:])?.write(
                        to: folder.appendingPathComponent(name))
                    print("wrote", name)
                }
            }
        }
    }

    /// Light page with a dark menu bar strip behind a snapshot.
    private final class SnapshotBackdrop: NSView {
        let bar: CGFloat
        init(frame: NSRect, bar: CGFloat) {
            self.bar = bar
            super.init(frame: frame)
        }
        required init?(coder: NSCoder) { nil }
        override var isFlipped: Bool { true }
        override func draw(_ dirtyRect: NSRect) {
            NSColor(white: 0.93, alpha: 1).setFill()
            bounds.fill()
            NSColor(srgbRed: 0.17, green: 0.18, blue: 0.19, alpha: 1).setFill()
            NSRect(x: 0, y: 0, width: bounds.width, height: bar).fill()
        }
    }
#endif
