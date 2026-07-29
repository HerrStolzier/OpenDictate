import Foundation

/// What to cut from a recording before uploading it.
public struct TrimPlan: Equatable, Sendable {
    /// Offset of the first kept sample, in seconds.
    public let start: TimeInterval
    /// Length of the kept span, and what gets billed by the API.
    public let uploadDuration: TimeInterval
    /// How much silence the plan removes in total.
    public let trimmedDuration: TimeInterval
    /// False when the saving is too small to be worth a re-encode.
    public let shouldExport: Bool

    public init(start: TimeInterval, uploadDuration: TimeInterval, trimmedDuration: TimeInterval, shouldExport: Bool) {
        self.start = start
        self.uploadDuration = uploadDuration
        self.trimmedDuration = trimmedDuration
        self.shouldExport = shouldExport
    }
}

public enum TrimPlanner {
    /// Re-encoding costs time and quality, so skip it unless it saves at least this much.
    public static let minimumSavingToExport: TimeInterval = 0.35

    /// Pads the detected speech span, clamps it to the recording, and decides
    /// whether trimming is worth it.
    ///
    /// - Throws: `OpenDictateError.recordingTooShort` when what is left after
    ///   trimming is below `minimumDuration`.
    public static func plan(
        originalDuration: TimeInterval,
        speechRange: SpeechRange,
        padding: TimeInterval,
        minimumDuration: TimeInterval
    ) throws -> TrimPlan {
        let start = max(0, speechRange.start - padding)
        let end = min(originalDuration, speechRange.end + padding)
        let uploadDuration = max(0, end - start)

        guard uploadDuration >= minimumDuration else {
            throw OpenDictateError.recordingTooShort(actual: uploadDuration, minimum: minimumDuration)
        }

        let trimmedDuration = max(0, originalDuration - uploadDuration)
        guard trimmedDuration >= minimumSavingToExport else {
            // Not worth a re-encode: upload the original file untouched.
            return TrimPlan(
                start: 0,
                uploadDuration: originalDuration,
                trimmedDuration: 0,
                shouldExport: false
            )
        }

        return TrimPlan(
            start: start,
            uploadDuration: uploadDuration,
            trimmedDuration: trimmedDuration,
            shouldExport: true
        )
    }
}
