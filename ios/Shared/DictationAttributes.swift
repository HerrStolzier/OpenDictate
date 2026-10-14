import ActivityKit
import Foundation
import OpenDictateCore

/// The Live Activity that stays visible while the app records in the
/// background; iOS ends a background recording without it. Only the app
/// process starts, changes and ends it.
struct DictationAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        enum Phase: String, Codable, Hashable, Sendable {
            /// `done`: the text is ready, but only the shortcut or the open app can copy it.
            case listening, writing, copied, done, oops
        }

        var phase: Phase
        /// Start of the recording, for the running clock.
        var startedAt: Date
        /// Automatic stop at the recording limit.
        var endsAt: Date
        /// One short sentence after the dictation, already in the user's language.
        var detail: String?

        var pose: BlinkPose {
            switch phase {
            case .listening: IndicatorPhase.listening.pose
            case .writing: IndicatorPhase.writing.pose
            case .copied, .done: IndicatorPhase.copied.pose
            case .oops: IndicatorPhase.oops.pose
            }
        }
    }
}
