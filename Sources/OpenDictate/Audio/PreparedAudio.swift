@preconcurrency import AVFoundation
import Foundation

struct PreparedAudio {
    let url: URL
    let originalDuration: TimeInterval
    let uploadDuration: TimeInterval
    let trimmedDuration: TimeInterval
}

struct AudioAnalysis {
    let speechRange: (start: TimeInterval, end: TimeInterval)?
    let peakDb: Float
    let averageDb: Float
}

final class ExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) {
        self.session = session
    }
}
