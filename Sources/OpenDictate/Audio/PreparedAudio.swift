@preconcurrency import AVFoundation
import Foundation
import OpenDictateCore

struct PreparedAudio {
    let url: URL
    let uploadDuration: TimeInterval
}

struct AudioAnalysis {
    let speechRange: SpeechRange?
    let peakDb: Float
    let averageDb: Float
}

final class ExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) {
        self.session = session
    }
}
