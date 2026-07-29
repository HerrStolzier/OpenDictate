import Foundation

public enum AudioLevels {
    /// Level reported for an empty window, and the starting point for a peak scan.
    public static let floorDb: Float = -160

    /// RMS of a sample window in dBFS. Clamped at the bottom so a digitally silent
    /// window returns a finite number instead of -infinity.
    public static func decibels(sumSquares: Float, count: Int) -> Float {
        guard count > 0 else {
            return floorDb
        }

        let rms = (sumSquares / Float(count)).squareRoot()
        return 20 * log10(max(rms, 0.000_000_1))
    }
}

/// Walks the recording window by window and remembers where speech started and
/// stopped. Kept separate from the audio file reading so the decision rule can be
/// tested without an audio file.
public struct SpeechRangeAccumulator {
    public let thresholdDb: Float
    private var firstSpeechTime: TimeInterval?
    private var lastSpeechTime: TimeInterval?

    public init(thresholdDb: Float) {
        self.thresholdDb = thresholdDb
    }

    public mutating func add(start: TimeInterval, end: TimeInterval, db: Float) {
        guard db >= thresholdDb else { return }
        firstSpeechTime = firstSpeechTime ?? start
        lastSpeechTime = end
    }

    /// The span from the first to the last window above the threshold, or nil if
    /// no window ever crossed it.
    public var range: SpeechRange? {
        guard let firstSpeechTime, let lastSpeechTime else { return nil }
        return SpeechRange(start: firstSpeechTime, end: lastSpeechTime)
    }
}

public struct SpeechRange: Equatable, Sendable {
    public let start: TimeInterval
    public let end: TimeInterval

    public init(start: TimeInterval, end: TimeInterval) {
        self.start = start
        self.end = end
    }
}
