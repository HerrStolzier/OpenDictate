import Foundation

/// Recording files the macOS app writes to the temporary directory while it
/// records (`opendictate-<UUID>.m4a`) and trims (`opendictate-trimmed-<UUID>.m4a`).
/// A crash, or a recovery copy that could not be written, leaves them behind.
/// They follow the recovery age limit: removed once 24 hours old, never earlier,
/// because a younger one may be the only surviving copy of a dictation.
public enum TemporaryRecordings {
    public static func isRecordingName(_ name: String) -> Bool {
        guard name.hasSuffix(".m4a") else { return false }
        let stem = name.dropLast(".m4a".count)
        for prefix in ["opendictate-trimmed-", "opendictate-"] where stem.hasPrefix(prefix) {
            return UUID(uuidString: String(stem.dropFirst(prefix.count))) != nil
        }
        return false
    }

    /// The entries to delete: generated recording names whose newest known date
    /// is at least `maximumAge` in the past. A date in the future keeps the file.
    public static func expired(
        from entries: [RecordingRetention.Entry],
        now: Date = Date(),
        maximumAge: TimeInterval = RecordingRetention.maximumAge
    ) -> [RecordingRetention.Entry] {
        entries.filter { entry in
            isRecordingName(entry.url.lastPathComponent) && now.timeIntervalSince(entry.created) >= maximumAge
        }
    }
}
