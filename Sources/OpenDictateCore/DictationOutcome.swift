/// Presentation evidence reported by the flow, independent of localized text.
public enum DictationOutcome: Equatable, Sendable {
    case textAvailable
    case deliveryUnconfirmed
    case deliveryUncertain
    case failed
    case cancelled

    public static func delivery(_ result: TranscriptDelivery) -> Self {
        switch result {
        case .empty: .failed
        case .clipboardFailed, .copied(.notAttempted): .textAvailable
        case .copied(.submitted): .deliveryUnconfirmed
        case .copied(.uncertain): .deliveryUncertain
        }
    }
}
