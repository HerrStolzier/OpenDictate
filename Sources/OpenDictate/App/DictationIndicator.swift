import AppKit
import OpenDictateCore

/// Sizes in points. The notch values are a first guess from the design board;
/// the final ones are set together with Basti at a real screen.
enum IndicatorMetrics {
    /// The open notch display is about twice as wide as the notch.
    static let notchWidthFactor: CGFloat = 2
    static let notchMinimumWidth: CGFloat = 360
    static let notchOopsMinimumWidth: CGFloat = 440
    /// Height below the camera housing; about 80 pt in total on current MacBooks.
    static let notchContentHeight: CGFloat = 48
    static let notchCorner: CGFloat = 20
    static let notchShoulder: CGFloat = 8
    static let menuBarPillHeight: CGFloat = 22
    static let menuBarPillMinimumWidth: CGFloat = 200
    static let floatingSize = NSSize(width: 340, height: 52)
    static let cardWidth: CGFloat = 340
    /// Distance below the menu bar or the top edge.
    static let gap: CGFloat = 6
}

/// The small display at the top of the screen. It follows the window's
/// display state, never activates OpenDictate and never takes the focus, so
/// Command-V still reaches the app the dictation started in.
@MainActor
final class DictationIndicator {
    /// "Nochmal senden" on an error; the cost confirmation stays in its window.
    var onRetry: (() -> Void)?
    /// Spoken through VoiceOver unless another window already announces it.
    var onAnnounce: ((String) -> Void)?
    /// Text next to the menu bar symbol, nil for none; `alert` marks an error.
    var onStatusItemTitle: ((String?, Bool) -> Void)?
    var style: () -> IndicatorStyle = { .default }
    /// Debug previews draw a notch on screens that have none.
    var simulatedNotch: NSSize?
    /// A recording of the failed attempt can be sent again.
    var canRetry = false {
        didSet { if canRetry != oldValue, phase == .oops { present() } }
    }

    private(set) var phase: IndicatorPhase = .closed
    private(set) var placement: IndicatorPlacement = .hidden
    private var reason = ""
    private var elapsed: TimeInterval = 0
    private var translating = false
    private var announcedMilestone: Int?
    private var closeTask: Task<Void, Never>?
    private var animationTask: Task<Void, Never>?
    private lazy var window = IndicatorWindow()
    private lazy var view = IndicatorView()
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        // The variant depends on the screen and on whether the frontmost app
        // covers it, so place it again whenever either changes, for example
        // when Paste brings a full-screen game forward.
        let replace: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.phase != .closed else { return }
                self.present(animated: false)
            }
        }
        observers = [
            center.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main,
                using: replace),
            workspace.addObserver(
                forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main, using: replace),
            workspace.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main, using: replace)
        ]
    }

    var content: IndicatorContent {
        IndicatorContent(
            phase: phase, elapsed: elapsed, limit: Config.maximumRecordingDuration, translating: translating,
            reason: reason)
    }

    /// Mirrors a state the window received from the flow, setup or error paths.
    func follow(_ display: DictationDisplay, detail: String) {
        let next = IndicatorPhase(display)
        if next == .oops { reason = detail }
        transition(to: next)
    }

    /// An error outside the flow, for example a missing API key.
    func showProblem(_ message: String) {
        reason = message
        transition(to: .oops)
    }

    func setTranslating(_ value: Bool) {
        translating = value
        if phase == .writing { view.content = content }
    }

    func updateRecording(elapsed: TimeInterval) {
        guard phase == .listening else { return }
        self.elapsed = elapsed
        view.content = content
        updateStatusItem()
        let milestone = IndicatorText.countdownMilestone(elapsed: elapsed, limit: Config.maximumRecordingDuration)
        if let milestone, milestone != announcedMilestone {
            announcedMilestone = milestone
            let left = IndicatorText.remaining(elapsed: elapsed, limit: Config.maximumRecordingDuration)
            onAnnounce?("Noch \(left) Sekunden bis zum automatischen Stopp.")
        }
    }

    func dismiss() { transition(to: .closed) }

    private func transition(to next: IndicatorPhase) {
        let changed = next != phase
        phase = next
        closeTask?.cancel()
        closeTask = nil
        if changed {
            if next == .listening {
                elapsed = 0
                announcedMilestone = nil
            }
            if next != .closed { onAnnounce?(content.accessibilityLabel) }
        }
        present(animated: changed)
        if let delay = next.closesAfter {
            closeTask = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: delay) } catch { return }
                guard let self, phase == next else { return }
                transition(to: .closed)
            }
        }
    }

    private func updateStatusItem() {
        onStatusItemTitle?(
            IndicatorLayout.statusItemTitle(for: phase, placement: placement, elapsed: elapsed), phase == .oops)
    }

    /// Chooses the screen and the variant again and shows the result.
    private func present(animated: Bool = true) {
        guard let target = IndicatorTarget.current(simulatedNotch: simulatedNotch) else { return }
        let previous = placement
        placement = IndicatorLayout.placement(for: phase, on: target.info, style: style())
        updateStatusItem()
        guard placement != .hidden, placement != .statusItem else {
            close(animated: animated && previous == .notch)
            return
        }
        view.target = target
        view.placement = placement
        view.canRetry = canRetry
        view.onRetry = { [weak self] in self?.onRetry?() }
        view.onClose = { [weak self] in self?.dismiss() }
        let wasVisible = window.isVisible
        if animated || !wasVisible { view.restartMotion() }
        view.content = content
        let frame = view.windowFrame()
        if window.contentView !== view { window.contentView = view }
        view.startMotion()
        view.needsLayout = true
        window.ignoresMouseEvents = !view.hasButtons
        window.hasShadow = placement == .floating
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        animationTask?.cancel()
        if placement == .notch, !wasVisible, animated, !reduceMotion {
            // Grow out of the notch in five steps, like the design's steps(5).
            let start = view.notchFrame()
            window.setFrame(start, display: false)
            window.alphaValue = 1
            window.orderFrontRegardless()
            animationTask = Task { @MainActor [weak self] in
                for step in 1...5 {
                    do { try await Task.sleep(for: .milliseconds(60)) } catch { return }
                    guard let self else { return }
                    window.setFrame(Self.interpolate(start, frame, CGFloat(step) / 5), display: true)
                }
            }
        } else if !wasVisible, animated, !reduceMotion {
            window.setFrame(frame, display: false)
            window.alphaValue = 0
            window.orderFrontRegardless()
            animationTask = Task { @MainActor [weak self] in
                for step in 1...3 {
                    do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                    self?.window.alphaValue = CGFloat(step) / 3
                }
            }
        } else {
            window.setFrame(frame, display: true)
            window.alphaValue = 1
            window.orderFrontRegardless()
        }
        view.needsDisplay = true
        if window.hasShadow { window.invalidateShadow() }
    }

    private func close(animated: Bool) {
        animationTask?.cancel()
        animationTask = nil
        guard window.isVisible else { return }
        guard animated, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            window.orderOut(nil)
            view.stopMotion()
            return
        }
        let start = window.frame
        let end = view.notchFrame()
        animationTask = Task { @MainActor [weak self] in
            for step in 1...5 {
                do { try await Task.sleep(for: .milliseconds(60)) } catch { return }
                guard let self else { return }
                window.setFrame(Self.interpolate(start, end, CGFloat(step) / 5), display: true)
            }
            self?.window.orderOut(nil)
            self?.view.stopMotion()
        }
    }

    private static func interpolate(_ from: NSRect, _ to: NSRect, _ progress: CGFloat) -> NSRect {
        func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat { (a + (b - a) * progress).rounded() }
        let width = mix(from.width, to.width)
        let height = mix(from.height, to.height)
        return NSRect(
            x: (from.midX + (to.midX - from.midX) * progress - width / 2).rounded(),
            y: mix(from.maxY, to.maxY) - height, width: width, height: height)
    }
}

/// The screen the user works on, and what the indicator needs to know about it.
struct IndicatorTarget {
    let frame: NSRect
    let info: IndicatorScreen
    /// Width and height of the camera housing.
    let notch: NSSize?
    /// Horizontal centre of the notch, or of the screen.
    let centerX: CGFloat
    let menuBarHeight: CGFloat

    @MainActor
    static func current(simulatedNotch: NSSize? = nil) -> IndicatorTarget? {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return nil }
        // The window server counts from the top-left of the primary screen.
        let flipped = screens.map {
            CGRect(
                x: $0.frame.minX, y: primary.frame.maxY - $0.frame.maxY, width: $0.frame.width, height: $0.frame.height)
        }
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        let windows = ((list as? [[String: Any]]) ?? []).compactMap { info -> ScreenWindow? in
            guard let pid = info[kCGWindowOwnerPID as String] as? Int32,
                let layer = info[kCGWindowLayer as String] as? Int,
                let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                let rect = CGRect(dictionaryRepresentation: bounds)
            else { return nil }
            return ScreenWindow(ownerPID: pid, layer: layer, bounds: rect)
        }
        let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let active = IndicatorLayout.activeScreen(windows: windows, frontmostPID: frontmost, screens: flipped)
        let screen = active.map { screens[$0.index] } ?? NSScreen.main ?? primary
        let frame = screen.frame
        var notch: NSSize?
        var centerX = frame.midX
        if screen.safeAreaInsets.top > 0, let left = screen.auxiliaryTopLeftArea,
            let right = screen.auxiliaryTopRightArea
        {
            let width = frame.width - left.width - right.width
            notch = NSSize(width: width, height: screen.safeAreaInsets.top)
            centerX = frame.minX + left.width + width / 2
        } else if let simulatedNotch {
            notch = simulatedNotch
        }
        let reserved = frame.maxY - screen.visibleFrame.maxY
        return IndicatorTarget(
            frame: frame,
            info: IndicatorScreen(hasNotch: notch != nil, showsMenuBar: !(active?.coveredByWindow ?? false)),
            notch: notch, centerX: centerX,
            menuBarHeight: reserved > 0 ? reserved : NSStatusBar.system.thickness)
    }
}

/// Borderless, non-activating, on every Space and above the menu bar.
private final class IndicatorWindow: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 22), styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        isMovable = false
        animationBehavior = .none
        setAccessibilitySubrole(.floatingWindow)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Draws the indicator for one placement. Layout is computed from the target
/// screen and the content; buttons are real NSButtons for VoiceOver.
@MainActor
final class IndicatorView: NSView {
    var target: IndicatorTarget?
    var placement: IndicatorPlacement = .menuBar
    var canRetry = false {
        didSet { needsLayout = true }
    }
    var onRetry: (() -> Void)?
    var onClose: (() -> Void)?
    var content = IndicatorContent(phase: .closed) {
        didSet {
            guard content != oldValue else { return }
            setAccessibilityLabel(content.accessibilityLabel)
            needsLayout = true
            needsDisplay = true
        }
    }

    private let retryButton = PixelButton(title: "Nochmal senden", primary: true, target: nil, action: #selector(retry))
    private let closeButton = PixelButton(title: "Schließen", primary: false, target: nil, action: #selector(close))
    private var motionStart = Date()
    private var motionTimer: Timer?

    override init(frame: NSRect) {
        super.init(frame: frame)
        retryButton.target = self
        closeButton.target = self
        addSubview(retryButton)
        addSubview(closeButton)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    var hasButtons: Bool { content.phase == .oops }

    // MARK: - Geometry

    private var ink: NSColor { NSColor(design: .ink) }
    private var muted: NSColor { NSColor(design: .inkMuted) }

    private struct Plan {
        var size: NSSize
        /// Black shapes: pills, the notch body or the error card.
        var notchBody = false
        var pill: NSRect?
        var card: NSRect?
        var blink: (scene: BlinkScene, origin: CGPoint, cell: CGFloat)?
        var texts: [(NSAttributedString, NSRect)] = []
        var glyph: (rows: [String], origin: CGPoint, cell: CGFloat, color: NSColor, blinks: Bool)?
        var buttons: NSRect?
    }

    private func text(_ value: String, _ font: NSFont, _ color: NSColor, wraps: Bool = false) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = wraps ? .byWordWrapping : .byTruncatingTail
        return NSAttributedString(
            string: value, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
    }

    private func measure(_ value: NSAttributedString, width: CGFloat = .greatestFiniteMagnitude) -> NSSize {
        let rect = value.boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin])
        return NSSize(width: ceil(rect.width), height: ceil(rect.height))
    }

    private var detailColor: NSColor { content.isRecordingLine ? NSColor(design: .rec) : muted }

    private var buttonRowWidth: CGFloat {
        closeButton.intrinsicContentSize.width + (canRetry ? 8 + retryButton.intrinsicContentSize.width : 0)
    }

    private func plan() -> Plan {
        let target = target
        switch placement {
        case .notch: return notchPlan(notch: target?.notch ?? NSSize(width: 185, height: 32))
        case .floating: return content.phase == .oops ? floatingCardPlan() : floatingPlan()
        default: return menuBarPlan(menuBarHeight: target?.menuBarHeight ?? 24)
        }
    }

    /// B: Blink 16, word and time in a flat pill in the middle of the menu bar.
    /// An error drops a card below it.
    private func menuBarPlan(menuBarHeight: CGFloat) -> Plan {
        let height = IndicatorMetrics.menuBarPillHeight
        let word = text(content.word, BrandFonts.pixel(14), ink)
        let detail = text(content.compactDetail, BrandFonts.mono(11), detailColor)
        let wordSize = measure(word)
        let detailSize = content.compactDetail.isEmpty ? .zero : measure(detail)
        let inner = 16 + 8 + wordSize.width + (detailSize.width > 0 ? 8 + detailSize.width : 0)
        let pillWidth = max(IndicatorMetrics.menuBarPillMinimumWidth, inner + 20)
        var card: NSRect?
        var plan = Plan(size: .zero)
        var width = pillWidth
        var totalHeight = menuBarHeight
        if content.phase == .oops {
            let reason = text(content.detail, BrandFonts.sans(13), ink, wraps: true)
            let reasonSize = measure(reason, width: IndicatorMetrics.cardWidth - 32)
            let cardHeight = 14 + reasonSize.height + 10 + 44 + 14
            width = max(width, IndicatorMetrics.cardWidth)
            card = NSRect(
                x: (width - IndicatorMetrics.cardWidth) / 2, y: menuBarHeight + IndicatorMetrics.gap,
                width: IndicatorMetrics.cardWidth, height: cardHeight)
            totalHeight = menuBarHeight + IndicatorMetrics.gap + cardHeight
            plan.texts.append(
                (
                    reason,
                    NSRect(x: card!.minX + 16, y: card!.minY + 14, width: reasonSize.width, height: reasonSize.height)
                ))
            plan.buttons = NSRect(x: card!.minX + 16, y: card!.maxY - 14 - 44, width: card!.width - 32, height: 44)
        }
        let pill = NSRect(
            x: (width - pillWidth) / 2, y: ((menuBarHeight - height) / 2).rounded(.down), width: pillWidth,
            height: height)
        let left = pill.minX + (pillWidth - inner) / 2
        plan.size = NSSize(width: width, height: totalHeight)
        plan.pill = pill
        plan.card = card
        plan.blink = (BlinkFigure.small(content.phase.pose), CGPoint(x: left.rounded(), y: pill.minY + 3), 1)
        plan.texts.append(
            (
                word,
                NSRect(x: left + 24, y: pill.midY - wordSize.height / 2, width: wordSize.width, height: wordSize.height)
            ))
        if detailSize.width > 0 {
            plan.texts.append(
                (
                    detail,
                    NSRect(
                        x: left + 24 + wordSize.width + 8, y: pill.midY - detailSize.height / 2,
                        width: detailSize.width, height: detailSize.height)
                ))
        }
        return plan
    }

    /// A: a pill of about 340 × 52 below the menu bar.
    private func floatingPlan() -> Plan {
        let size = IndicatorMetrics.floatingSize
        let word = text(content.word, BrandFonts.pixel(20), ink)
        let detail = text(content.compactDetail, BrandFonts.mono(12), detailColor)
        let wordSize = measure(word)
        let detailSize = measure(detail)
        let iconWidth: CGFloat = content.isRecordingLine ? 18 : 0
        let width = max(size.width, 14 + 32 + 12 + wordSize.width + 16 + iconWidth + detailSize.width + 18)
        var plan = Plan(size: NSSize(width: width, height: size.height))
        plan.pill = NSRect(origin: .zero, size: plan.size)
        plan.blink = (BlinkFigure.small(content.phase.pose), CGPoint(x: 14, y: 10), 2)
        plan.texts.append(
            (
                word,
                NSRect(x: 58, y: (size.height - wordSize.height) / 2, width: wordSize.width, height: wordSize.height)
            ))
        let detailX = width - 18 - detailSize.width
        plan.texts.append(
            (
                detail,
                NSRect(
                    x: detailX, y: (size.height - detailSize.height) / 2, width: detailSize.width,
                    height: detailSize.height)
            ))
        if content.isRecordingLine {
            plan.glyph = (
                PixelGlyph.rec, CGPoint(x: detailX - 18, y: (size.height - 12) / 2), 1, NSColor(design: .rec), false
            )
        }
        return plan
    }

    /// A with an error: the pill becomes a card with the reason and the buttons.
    private func floatingCardPlan() -> Plan {
        let width = IndicatorMetrics.cardWidth
        let word = text(content.word, BrandFonts.pixel(20), ink)
        let wordSize = measure(word)
        let reason = text(content.detail, BrandFonts.sans(13), ink, wraps: true)
        let reasonSize = measure(reason, width: width - 32)
        let height = 14 + 32 + 8 + reasonSize.height + 10 + 44 + 14
        var plan = Plan(size: NSSize(width: width, height: height))
        plan.card = NSRect(origin: .zero, size: plan.size)
        plan.blink = (BlinkFigure.small(.hoppla), CGPoint(x: 16, y: 14), 2)
        plan.texts = [
            (word, NSRect(x: 60, y: 30 - wordSize.height / 2, width: wordSize.width, height: wordSize.height)),
            (reason, NSRect(x: 16, y: 54, width: reasonSize.width, height: reasonSize.height))
        ]
        plan.buttons = NSRect(x: 16, y: height - 14 - 44, width: width - 32, height: 44)
        return plan
    }

    /// Notch: grows out of the camera housing; Blink stands beside it, the word
    /// and its line sit below it.
    private func notchPlan(notch: NSSize) -> Plan {
        let oops = content.phase == .oops
        let minimum = oops ? IndicatorMetrics.notchOopsMinimumWidth : IndicatorMetrics.notchMinimumWidth
        let width = max(minimum, (notch.width * IndicatorMetrics.notchWidthFactor).rounded())
        let shoulder = IndicatorMetrics.notchShoulder
        let textX: CGFloat = shoulder + 12 + 44 + 14
        let glyphWidth: CGFloat = oops || content.phase == .copied ? 0 : 24 + 12
        let textWidth = width - textX - shoulder - 12 - glyphWidth
        let word = text(content.word, BrandFonts.pixel(18), ink)
        let wordSize = measure(word)
        let line =
            oops
            ? text(content.detail, BrandFonts.sans(13), ink, wraps: true)
            : text(content.detail, BrandFonts.mono(12), detailColor, wraps: true)
        let lineSize = measure(line, width: textWidth)
        let top = notch.height + 4
        var height = max(
            notch.height + IndicatorMetrics.notchContentHeight, top + wordSize.height + 2 + lineSize.height + 10)
        if oops { height = top + wordSize.height + 4 + lineSize.height + 12 + 44 + 14 }
        var plan = Plan(size: NSSize(width: width, height: height.rounded(.up)))
        plan.notchBody = true
        let blinkY = oops ? 14 : ((plan.size.height - 50) / 2).rounded()
        plan.blink = (BlinkFigure.scene(content.phase.pose, framed: true), CGPoint(x: shoulder + 12, y: blinkY), 1)
        plan.texts = [
            (word, NSRect(x: textX, y: top, width: wordSize.width, height: wordSize.height)),
            (
                line,
                NSRect(
                    x: textX, y: top + wordSize.height + (oops ? 4 : 2), width: lineSize.width, height: lineSize.height)
            )
        ]
        if oops {
            plan.buttons = NSRect(
                x: textX, y: plan.size.height - 14 - 44, width: width - textX - shoulder - 20, height: 44)
        } else if let glyph = glyphForPhase {
            plan.glyph = (
                glyph.rows, CGPoint(x: width - shoulder - 12 - 24, y: ((plan.size.height - 24) / 2).rounded()), 2,
                glyph.color, glyph.blinks
            )
        }
        return plan
    }

    private var glyphForPhase: (rows: [String], color: NSColor, blinks: Bool)? {
        switch content.phase {
        case .listening: (PixelGlyph.rec, NSColor(design: .rec), true)
        case .writing: (PixelGlyph.prompt, NSColor(design: .signal), true)
        case .inserted: (PixelGlyph.check, NSColor(design: .signal), false)
        default: nil
        }
    }

    /// Final window frame in screen coordinates.
    func windowFrame() -> NSRect {
        guard let target else { return .zero }
        let size = plan().size
        let top: CGFloat
        switch placement {
        case .floating:
            top = target.frame.maxY - (target.info.showsMenuBar ? target.menuBarHeight : 0) - IndicatorMetrics.gap
        default: top = target.frame.maxY
        }
        return NSRect(
            x: (target.centerX - size.width / 2).rounded(), y: top - size.height, width: size.width, height: size.height
        )
    }

    /// The notch itself: start and end of the grow animation.
    func notchFrame() -> NSRect {
        guard let target, let notch = target.notch else { return windowFrame() }
        return NSRect(
            x: (target.centerX - notch.width / 2).rounded(), y: target.frame.maxY - notch.height,
            width: notch.width, height: notch.height)
    }

    // MARK: - Drawing

    func restartMotion() { motionStart = Date() }

    func stopMotion() {
        motionTimer?.invalidate()
        motionTimer = nil
    }

    /// Redraws for Blink's stepped motion; nothing moves with "Bewegung reduzieren".
    func startMotion() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, motionTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.window?.isVisible == true else { return }
                self.needsDisplay = true
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        motionTimer = timer
    }

    override func layout() {
        super.layout()
        let plan = plan()
        let offset = (bounds.width - plan.size.width) / 2
        let complete = abs(bounds.width - plan.size.width) < 1 && abs(bounds.height - plan.size.height) < 1
        guard let row = plan.buttons, complete else {
            retryButton.isHidden = true
            closeButton.isHidden = true
            return
        }
        let close = closeButton.intrinsicContentSize
        let retry = retryButton.intrinsicContentSize
        retryButton.isHidden = !canRetry
        closeButton.isHidden = false
        var right = row.maxX + offset
        if canRetry {
            retryButton.frame = NSRect(x: right - retry.width, y: row.minY, width: retry.width, height: 44)
            right -= retry.width + 8
        }
        closeButton.frame = NSRect(x: right - close.width, y: row.minY, width: close.width, height: 44)
    }

    override func draw(_ dirtyRect: NSRect) {
        let plan = plan()
        let animated = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let time = Date().timeIntervalSince(motionStart)
        let offset = ((bounds.width - plan.size.width) / 2).rounded()
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let black = NSColor.black
        let hairline = NSColor.white.withAlphaComponent(0.12)
        if plan.notchBody {
            let shape = notchShape(in: bounds)
            black.setFill()
            shape.fill()
            shape.addClip()
        }
        let transform = NSAffineTransform()
        transform.translateX(by: offset, yBy: 0)
        transform.concat()
        if let pill = plan.pill {
            let path = NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2)
            black.setFill()
            path.fill()
            if placement == .floating {
                hairline.setStroke()
                NSBezierPath(
                    roundedRect: pill.insetBy(dx: 0.5, dy: 0.5), xRadius: pill.height / 2, yRadius: pill.height / 2
                ).stroke()
            }
        }
        if let card = plan.card {
            black.setFill()
            NSBezierPath(roundedRect: card, xRadius: 14, yRadius: 14).fill()
            hairline.setStroke()
            NSBezierPath(roundedRect: card.insetBy(dx: 0.5, dy: 0.5), xRadius: 14, yRadius: 14).stroke()
        }
        if let blink = plan.blink {
            BlinkRenderer.draw(blink.scene, at: blink.origin, cell: blink.cell, time: time, animated: animated)
        }
        if let glyph = plan.glyph {
            let visible = !glyph.blinks || BlinkMotion.blink.frame(at: time, animated: animated).opacity > 0
            if visible { BlinkRenderer.drawGlyph(glyph.rows, at: glyph.origin, cell: glyph.cell, color: glyph.color) }
        }
        for (value, rect) in plan.texts {
            value.draw(with: rect.insetBy(dx: 0, dy: 0), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
        }
    }

    /// Flush with the top edge, with small inward curves where it meets the
    /// menu bar and round corners below.
    private func notchShape(in rect: NSRect) -> NSBezierPath {
        let shoulder = min(IndicatorMetrics.notchShoulder, rect.width / 4)
        let corner = min(IndicatorMetrics.notchCorner, rect.height / 2, (rect.width - 2 * shoulder) / 2)
        let (w, h) = (rect.width, rect.height)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 0, y: 0))
        path.curve(
            to: NSPoint(x: shoulder, y: shoulder), controlPoint1: NSPoint(x: shoulder * 0.6, y: 0),
            controlPoint2: NSPoint(x: shoulder, y: shoulder * 0.4))
        path.line(to: NSPoint(x: shoulder, y: h - corner))
        path.curve(
            to: NSPoint(x: shoulder + corner, y: h), controlPoint1: NSPoint(x: shoulder, y: h - corner * 0.45),
            controlPoint2: NSPoint(x: shoulder + corner * 0.45, y: h))
        path.line(to: NSPoint(x: w - shoulder - corner, y: h))
        path.curve(
            to: NSPoint(x: w - shoulder, y: h - corner), controlPoint1: NSPoint(x: w - shoulder - corner * 0.45, y: h),
            controlPoint2: NSPoint(x: w - shoulder, y: h - corner * 0.45))
        path.line(to: NSPoint(x: w - shoulder, y: shoulder))
        path.curve(
            to: NSPoint(x: w, y: 0), controlPoint1: NSPoint(x: w - shoulder, y: shoulder * 0.4),
            controlPoint2: NSPoint(x: w - shoulder * 0.6, y: 0))
        path.close()
        return path
    }

    @objc private func retry() { onRetry?() }
    @objc private func close() { onClose?() }

    /// For snapshots in the debug preview.
    func fitToPlan() { setFrameSize(plan().size) }
}
