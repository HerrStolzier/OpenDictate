@preconcurrency import AVFoundation
import Foundation
import OpenDictateCore

struct SavedRecording: Sendable {
    let filename: String
    let created: Date
    let duration: Double?
    let retryable: Bool
}

/// Disk reads, authentication and audio metadata never run inside menu opening.
actor RecordingLibrary {
    func snapshot() async -> [SavedRecording] {
        FailedRecordingStore.prune()
        var entries: [SavedRecording] = []
        for url in FailedRecordingStore.candidateAudioURLs().sorted(by: { $0.lastPathComponent > $1.lastPathComponent })
        {
            guard let created = FailedRecordingStore.date(from: url.lastPathComponent) else { continue }
            let valid = FailedRecordingStore.payload(filename: url.lastPathComponent) != nil
            var duration: Double?
            if valid {
                let seconds = try? await AVURLAsset(url: url).load(.duration).seconds
                if let seconds, seconds.isFinite { duration = seconds }
            }
            entries.append(
                .init(filename: url.lastPathComponent, created: created, duration: duration, retryable: valid))
        }
        return entries
    }

    func load(filename: String?) -> FailedRecordingStore.RetryPayload? {
        if let filename { return FailedRecordingStore.payload(filename: filename) }
        return FailedRecordingStore.newest()
    }

    func delete(filename: String) {
        guard FailedRecordingStore.isExpectedFilename(filename) else { return }
        let url = FailedRecordingStore.directory.appendingPathComponent(filename)
        _ = FailedRecordingStore.unlinkFile(url)
        _ = FailedRecordingStore.unlinkFile(url.appendingPathExtension("auth"))
    }
}
