@preconcurrency import AVFoundation
import Foundation
import OpenDictateCore

struct PreparedAudio {
    let url: URL
    let uploadDuration: TimeInterval
}

enum TemporaryAudioAccess {
    static func restrict(_ url: URL) {
        do {
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            AppLog.write("Could not restrict temporary audio permissions at \(url.path)")
        }
    }
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
