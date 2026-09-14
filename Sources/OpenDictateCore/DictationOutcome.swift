/// Presentation evidence reported by the flow, independent of localized text.
public enum DictationOutcome: Equatable, Sendable {
    case textAvailable
    case deliveryUnconfirmed
    case failed
    case cancelled

    public static func delivery(_ result: TranscriptDelivery) -> Self {
        switch result {
        case .empty: .failed
        case .clipboardFailed, .copied: .textAvailable
        case .pasteSent: .deliveryUnconfirmed
        }
    }
}
