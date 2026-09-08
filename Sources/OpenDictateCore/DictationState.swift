import Foundation

public enum DictationState: String, Sendable {
    case idle, recording, processing, delivering

    public var canStart: Bool { self == .idle }
    public var canRetry: Bool { self == .idle }
    public var canStop: Bool { self == .recording }
    public var isBusy: Bool { self == .processing || self == .delivering }
}

public enum TranscriptDelivery: Sendable, Equatable {
    case empty, clipboardFailed, copied, pasteSent

    public var canRemoveRecoveryAudio: Bool {
        self == .copied || self == .pasteSent
    }
}
