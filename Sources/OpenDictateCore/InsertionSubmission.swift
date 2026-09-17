/// Evidence about commands submitted to a destination, never proof of inserted text.
public enum InsertionSubmission: Equatable, Sendable {
    /// No command reached the submission API.
    case notAttempted
    /// Some Unicode commands were submitted before the remaining commands stopped.
    case interrupted
    /// Every requested command was submitted; the destination was not verified.
    case submitted
    /// A native insertion was attempted, but its result could not be confirmed.
    case uncertain
}
