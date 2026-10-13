@preconcurrency import AVFoundation
import CryptoKit
import Foundation
import OpenDictateCore

struct SavedRecording: Sendable {
    let filename: String
    let created: Date
    let duration: Double?
    let retryable: Bool
}

/// Disk reads, authentication and audio metadata never run inside menu opening.
/// Each recording is authenticated once while its file stays unchanged, so the
/// periodic refresh does not ask the Keychain for the recovery key again.
actor RecordingLibrary {
    private struct Checked {
        let size: Int?
        let modified: Date?
        let authenticated: Bool
        let duration: Double?
    }

    private let directory: URL
    private let readKey: @Sendable () -> SymmetricKey?
    private var checked: [String: Checked] = [:]

    init(
        directory: URL = FailedRecordingStore.directory,
        key: @escaping @Sendable () -> SymmetricKey? = { RecordingAuthenticationKeyStore.read() }
    ) {
        self.directory = directory
        self.readKey = key
    }

    func snapshot(now: Date = Date()) async -> [SavedRecording] {
        FailedRecordingStore.prune(now: now, in: directory)
        // Read at most once per snapshot, and only for a new or changed file.
        var key: SymmetricKey?
        var keyRead = false
        var current: [String: Checked] = [:]
        var entries: [SavedRecording] = []
        let urls = FailedRecordingStore.candidateAudioURLs(in: directory).sorted {
            $0.lastPathComponent > $1.lastPathComponent
        }
        for url in urls {
            let filename = url.lastPathComponent
            guard let created = FailedRecordingStore.date(from: filename) else { continue }
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = values?.fileSize
            let modified = values?.contentModificationDate
            let result: Checked
            var remember = true
            if let cached = checked[filename], cached.size == size, cached.modified == modified {
                result = cached
            } else {
                if !keyRead {
                    key = readKey()
                    keyRead = true
                }
                let authenticated = key.map { FailedRecordingStore.payload(at: url, now: now, key: $0) != nil } ?? false
                var duration: Double?
                if authenticated {
                    let seconds = try? await AVURLAsset(url: url).load(.duration).seconds
                    if let seconds, seconds.isFinite { duration = seconds }
                }
                result = Checked(size: size, modified: modified, authenticated: authenticated, duration: duration)
                // Without a key or file metadata nothing is remembered, so the
                // next snapshot checks this file again. A keep writes the audio
                // before its sidecar, so a missing sidecar is not final either.
                let sidecar = url.appendingPathExtension("auth").path
                remember =
                    key != nil && size != nil && modified != nil
                    && (authenticated || FileManager.default.fileExists(atPath: sidecar))
            }
            if remember { current[filename] = result }
            // Expiry is checked on every snapshot, also for remembered results.
            let retryable = result.authenticated && now.timeIntervalSince(created) < RecordingRetention.maximumAge
            entries.append(
                .init(filename: filename, created: created, duration: result.duration, retryable: retryable))
        }
        checked = current
        return entries
    }

    /// Authenticates the bytes again; the snapshot result is only for display.
    func load(filename: String) -> FailedRecordingStore.RetryPayload? {
        guard FailedRecordingStore.isExpectedFilename(filename), let key = readKey() else { return nil }
        let payload = FailedRecordingStore.payload(
            at: directory.appendingPathComponent(filename), now: Date(), key: key)
        if payload == nil { checked[filename] = nil }
        return payload
    }

    func delete(filename: String) {
        guard FailedRecordingStore.isExpectedFilename(filename) else { return }
        checked[filename] = nil
        _ = FailedRecordingStore.removeAudioAndAuthentication(at: directory.appendingPathComponent(filename))
    }
}
