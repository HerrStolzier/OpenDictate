import CoreGraphics
import Foundation

/// What the dictation UI reports. The flow, setup and error paths set it; the
/// on-demand window and the indicator at the top of the screen both render it.
public enum DictationDisplay: String, CaseIterable, Sendable {
    case ready, setup, recording, processing, confirmed, manual, unconfirmed, failure, retry, cancelling

    public var title: String {
        switch self {
        case .ready: "Bereit zum Diktieren."
        case .setup: "Fast bereit"
        case .recording: "Aufnahme läuft."
        case .processing: "Text wird verarbeitet."
        case .confirmed: "Text eingefügt."
        case .manual: "Text ist verfügbar."
        case .unconfirmed: "Diktat verarbeitet."
        case .failure: "Nicht abgeschlossen"
        case .retry: "Diese Aufnahme erneut verarbeiten?"
        case .cancelling: "Wird abgebrochen …"
        }
    }
}

/// One word per state for the indicator. It never asks for focus.
public enum IndicatorPhase: String, CaseIterable, Sendable {
    case closed, listening, writing, inserted, copied, oops

    /// Setup and the confirmation before a costly resend keep their own window,
    /// so the indicator closes for them.
    public init(_ display: DictationDisplay) {
        switch display {
        case .ready, .setup, .retry: self = .closed
        case .recording: self = .listening
        case .processing, .cancelling: self = .writing
        case .confirmed, .unconfirmed: self = .inserted
        case .manual: self = .copied
        case .failure: self = .oops
        }
    }

    public var word: String {
        switch self {
        case .closed: "Bereit"
        case .listening: "Hört zu"
        case .writing: "Schreibt"
        case .inserted: "Eingefügt"
        case .copied: "Kopiert"
        case .oops: "Hoppla"
        }
    }

    /// Phases that stay visible over a full-screen app: an unnoticed recording
    /// is worse than a briefly covered edge.
    public var needsAttention: Bool { self == .listening || self == .writing || self == .oops }

    /// Successful endings close by themselves. The copied text needs a manual
    /// paste, so its longer sentence stays a little longer.
    public var closesAfter: Duration? {
        switch self {
        case .inserted: .seconds(2)
        case .copied: .seconds(4)
        case .closed, .listening, .writing, .oops: nil
        }
    }

    public var pose: BlinkPose {
        switch self {
        case .closed, .copied: .bereit
        case .listening: .hoert
        case .writing: .schreibt
        case .inserted: .eingefuegt
        case .oops: .hoppla
        }
    }
}

/// The user's choice for screens without a notch ("Anzeige ohne Notch").
public enum IndicatorStyle: String, CaseIterable, Sendable {
    /// A flat pill in the middle of the menu bar; it covers nothing.
    case menuBar
    /// A pill floating just below the menu bar.
    case floating
    /// Only "REC" next to the menu bar symbol; errors still show their card.
    case off

    public static let `default` = IndicatorStyle.menuBar

    public var title: String {
        switch self {
        case .menuBar: "In der Menüleiste"
        case .floating: "Schwebend unter der Menüleiste"
        case .off: "Aus"
        }
    }
}

/// Where the indicator appears on one screen.
public enum IndicatorPlacement: Equatable, Sendable {
    case hidden
    /// Grows out of the camera housing.
    case notch
    /// Flat pill in the middle of the menu bar.
    case menuBar
    /// Pill below the menu bar, or at the top edge when the menu bar is hidden.
    case floating
    /// Only a word next to the menu bar symbol.
    case statusItem
}

public struct IndicatorScreen: Equatable, Sendable {
    public var hasNotch: Bool
    /// False while a full-screen app hides the menu bar.
    public var showsMenuBar: Bool

    public init(hasNotch: Bool, showsMenuBar: Bool) {
        self.hasNotch = hasNotch
        self.showsMenuBar = showsMenuBar
    }
}

/// An on-screen window as the window server lists it, in its top-left based
/// coordinates.
public struct ScreenWindow: Equatable, Sendable {
    public var ownerPID: Int32
    public var layer: Int
    public var bounds: CGRect

    public init(ownerPID: Int32, layer: Int, bounds: CGRect) {
        self.ownerPID = ownerPID
        self.layer = layer
        self.bounds = bounds
    }
}

public enum IndicatorLayout {
    public static func placement(
        for phase: IndicatorPhase, on screen: IndicatorScreen, style: IndicatorStyle
    ) -> IndicatorPlacement {
        guard phase != .closed else { return .hidden }
        // An error always shows its reason and buttons, even with the indicator off.
        if phase == .oops, !screen.hasNotch, style == .off { return .floating }
        guard screen.showsMenuBar else {
            guard phase.needsAttention else { return .hidden }
            if screen.hasNotch { return .notch }
            return style == .off ? .hidden : .floating
        }
        if screen.hasNotch { return .notch }
        switch style {
        case .menuBar: return .menuBar
        case .floating: return .floating
        case .off: return .statusItem
        }
    }

    /// Short text next to the menu bar symbol, or nil for none.
    public static func statusItemTitle(
        for phase: IndicatorPhase, placement: IndicatorPlacement, elapsed: TimeInterval
    ) -> String? {
        switch (phase, placement) {
        case (.listening, .notch): "REC"
        case (.listening, .statusItem): "REC " + IndicatorText.clock(elapsed)
        default: nil
        }
    }

    /// The screen the user works on: the one holding the frontmost app's
    /// topmost normal window. `screens` and the window bounds share the window
    /// server's coordinates. Returns nil when that app shows no window.
    public static func activeScreen(
        windows: [ScreenWindow], frontmostPID: Int32?, screens: [CGRect]
    ) -> (index: Int, coveredByWindow: Bool)? {
        guard let frontmostPID,
            let window = windows.first(where: {
                $0.ownerPID == frontmostPID && $0.layer == 0 && $0.bounds.width > 40 && $0.bounds.height > 40
            })
        else { return nil }
        var best: (index: Int, area: CGFloat)?
        for (index, screen) in screens.enumerated() {
            let overlap = screen.intersection(window.bounds)
            guard !overlap.isNull else { continue }
            let area = overlap.width * overlap.height
            if area > (best?.area ?? 0) { best = (index, area) }
        }
        guard let best else { return nil }
        let screen = screens[best.index]
        let covered =
            window.bounds.minX <= screen.minX + 1 && window.bounds.minY <= screen.minY + 1
            && window.bounds.maxX >= screen.maxX - 1 && window.bounds.maxY >= screen.maxY - 1
        return (best.index, covered)
    }
}

/// The lines under the state word.
public struct IndicatorContent: Equatable, Sendable {
    public var phase: IndicatorPhase
    public var detail: String
    /// Shorter line for the pill inside the menu bar.
    public var compactDetail: String
    /// The line is the running recording ("REC …").
    public var isRecordingLine: Bool

    public var word: String { phase.word }
    public var accessibilityLabel: String {
        detail.isEmpty ? "OpenDictate: \(word)" : "OpenDictate: \(word). \(detail)"
    }

    public init(
        phase: IndicatorPhase, elapsed: TimeInterval = 0, limit: TimeInterval = 90, translating: Bool = false,
        reason: String = ""
    ) {
        self.phase = phase
        isRecordingLine = phase == .listening
        switch phase {
        case .closed:
            detail = ""
            compactDetail = ""
        case .listening:
            detail = IndicatorText.listening(elapsed: elapsed, limit: limit)
            compactDetail = detail
        case .writing:
            detail = translating ? "OpenAI übersetzt" : "OpenAI wandelt um"
            compactDetail = detail
        case .inserted:
            detail = "per ⌘V, kurz prüfen"
            compactDetail = detail
        case .copied:
            detail = "Nicht eingefügt. Der Text liegt in der Zwischenablage."
            compactDetail = "in der Zwischenablage"
        case .oops:
            detail = reason
            compactDetail = ""
        }
    }
}

public enum IndicatorText {
    /// m:ss, rounded down to whole seconds.
    public static func clock(_ seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds))
        return "\(whole / 60):" + String(format: "%02d", whole % 60)
    }

    public static func remaining(elapsed: TimeInterval, limit: TimeInterval) -> Int {
        max(0, Int(ceil(limit - elapsed)))
    }

    /// The recording line counts down during the last ten seconds before the
    /// automatic stop.
    public static func listening(elapsed: TimeInterval, limit: TimeInterval) -> String {
        let left = remaining(elapsed: elapsed, limit: limit)
        return left <= 10 ? "REC · Stopp in \(left) s" : "REC " + clock(elapsed)
    }

    /// Spoken milestones before the automatic stop, as the window announced them.
    public static func countdownMilestone(elapsed: TimeInterval, limit: TimeInterval) -> Int? {
        let left = remaining(elapsed: elapsed, limit: limit)
        return left <= 5 ? 5 : (left <= 10 ? 10 : nil)
    }
}
