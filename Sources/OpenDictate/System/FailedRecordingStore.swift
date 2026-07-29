import Foundation
import OpenDictateCore

/// Keeps recordings whose transcription failed, so a dropped connection does not
/// throw away what the user just said. Retention policy lives in
/// `RecordingRetention`; this type only does the file handling.
enum FailedRecordingStore {
    static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/OpenDictate/failed", isDirectory: true)
    }

    /// Moves the audio out of the temporary directory, where the caller is about
    /// to delete it. Returns the new location, or nil if it could not be kept.
    @discardableResult
    static func keep(_ audioURL: URL, recordedAt: Date) -> URL? {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let destination = directory.appendingPathComponent(
                "\(Self.timestamp(recordedAt))-\(UUID().uuidString.prefix(8)).\(audioURL.pathExtension)"
            )
            try FileManager.default.moveItem(at: audioURL, to: destination)
            AppLog.write("Kept the failed recording at \(destination.path)")
            return destination
        } catch {
            AppLog.write("Could not keep the failed recording: \(error.localizedDescription)")
            return nil
        }
    }

    static func entries() -> [RecordingRetention.Entry] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return contents.compactMap { url in
            let created = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
            return RecordingRetention.Entry(url: url, created: created ?? .distantPast)
        }
    }

    static func newest() -> URL? {
        RecordingRetention.newest(in: entries())?.url
    }

    static var hasAny: Bool {
        newest() != nil
    }

    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Drops everything past the newest `RecordingRetention.keepCount` files.
    static func prune() {
        let expired = RecordingRetention.expired(from: entries())
        guard !expired.isEmpty else { return }
        for entry in expired {
            try? FileManager.default.removeItem(at: entry.url)
        }
        AppLog.write("Pruned \(expired.count) old failed recording(s)")
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss'Z'"
        return formatter.string(from: date)
    }
}
