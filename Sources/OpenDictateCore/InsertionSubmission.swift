/// Evidence about commands submitted to a destination, never proof of inserted text.
public enum InsertionSubmission: Equatable, Sendable {
    /// No command reached the submission API.
    case notAttempted
    /// Every requested command was submitted; the destination was not verified.
    case submitted
}
