import Foundation

public enum DictationState: String, Sendable {
    case idle, recording, processing, delivering

    public var canStart: Bool { self == .idle }
    public var canRetry: Bool { self == .idle }
    public var canStop: Bool { self == .recording }
    public var isBusy: Bool { self == .processing || self == .delivering }
}

public enum TranscriptDelivery: Sendable, Equatable {
    case empty, clipboardFailed
    case copied(InsertionSubmission)

    public var canRemoveRecoveryAudio: Bool {
        // A successful copy preserves the whole transcript even if insertion stops.
        if case .copied = self { return true }
        return false
    }
}
