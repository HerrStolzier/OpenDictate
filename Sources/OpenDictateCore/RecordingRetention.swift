import Foundation

/// Decides which kept-after-failure recordings to drop. Split out from the file
/// handling so the "keep the newest N" rule can be tested without touching disk.
public enum RecordingRetention {
    /// How many failed recordings to keep around.
    public static let keepCount = 5
    /// Failed recordings are a recovery aid, not an archive.
    public static let maximumAge: TimeInterval = 24 * 60 * 60

    public struct Entry: Equatable, Sendable {
        public let url: URL
        public let created: Date

        public init(url: URL, created: Date) {
            self.url = url
            self.created = created
        }
    }

    /// The entries to delete, oldest first. Ties break on the file name so the
    /// result is stable when two recordings share a timestamp.
    public static func expired(
        from entries: [Entry],
        now: Date = Date(),
        maximumAge: TimeInterval = maximumAge,
        keeping keepCount: Int = keepCount
    ) -> [Entry] {
        guard keepCount >= 0 else { return entries }

        let newestFirst = entries.sorted { left, right in
            if left.created != right.created {
                return left.created > right.created
            }
            return left.url.lastPathComponent > right.url.lastPathComponent
        }

        let overCount = newestFirst.dropFirst(keepCount)
        let tooOld = entries.filter {
            let age = now.timeIntervalSince($0.created)
            return age >= maximumAge && age >= 0
        }
        let expiredURLs = Set(overCount.map(\.url)).union(tooOld.map(\.url))
        return entries
            .filter { expiredURLs.contains($0.url) }
            .sorted { left, right in
                if left.created != right.created { return left.created < right.created }
                return left.url.lastPathComponent < right.url.lastPathComponent
            }
    }

    /// The entry a retry should use, or nil when there is nothing kept.
    public static func newest(in entries: [Entry]) -> Entry? {
        entries.max { left, right in
            if left.created != right.created {
                return left.created < right.created
            }
            return left.url.lastPathComponent < right.url.lastPathComponent
        }
    }
}
