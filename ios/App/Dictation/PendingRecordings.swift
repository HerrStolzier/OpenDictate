import Foundation
import OpenDictateCore

/// Audio of dictations that did not reach the clipboard, kept for "Send
/// again". It stays in the app's own container, is excluded from backups and
/// expires by the Mac's rule (`RecordingRetention`), checked whenever it is read.
struct PendingRecordings: Sendable {
    /// Finished recordings waiting for a successful send.
    let keptDirectory: URL
    /// The recording in progress. Anything left here at launch was cut off by
    /// the end of the process or could not be moved; it moves to `Kept` so no
    /// audio is ever deleted unsent.
    let activeDirectory: URL

    init() {
        let base =
            (try? FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        keptDirectory = base.appendingPathComponent("Recordings/Kept", isDirectory: true)
        activeDirectory = base.appendingPathComponent("Recordings/Active", isDirectory: true)
    }

    /// Creates both folders and keeps what an earlier process left in
    /// `Active`. Call only while nothing records.
    func prepare() {
        let manager = FileManager.default
        for directory in [keptDirectory, activeDirectory] {
            try? manager.createDirectory(
                at: directory, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
            var url = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? url.setResourceValues(values)
        }
        for leftover in (try? manager.contentsOfDirectory(at: activeDirectory, includingPropertiesForKeys: nil)) ?? [] {
            _ = keep(leftover)
        }
    }

    func newRecordingURL() -> URL {
        activeDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
    }

    /// Moves a finished recording into the kept folder and returns where the
    /// audio now is. If the move fails, the original stays where it was.
    func keep(_ url: URL) -> URL {
        let stamp = Int(Date().timeIntervalSince1970)
        let target = keptDirectory.appendingPathComponent("\(stamp)-\(url.lastPathComponent)")
        do {
            try FileManager.default.moveItem(at: url, to: target)
            return target
        } catch {
            return url
        }
    }

    func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Deletes expired recordings, then returns the newest one left.
    func newest(now: Date = Date()) -> RecordingRetention.Entry? {
        let entries = self.entries()
        let expired = RecordingRetention.expired(from: entries, now: now)
        for entry in expired { remove(entry.url) }
        return RecordingRetention.newest(in: entries.filter { !expired.contains($0) })
    }

    private func entries() -> [RecordingRetention.Entry] {
        let files =
            (try? FileManager.default.contentsOfDirectory(
                at: keptDirectory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)) ?? []
        return files.filter { $0.pathExtension == "m4a" }.map { url in
            let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return RecordingRetention.Entry(url: url, created: created)
        }
    }
}
