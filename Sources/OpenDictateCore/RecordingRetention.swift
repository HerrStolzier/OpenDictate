import Foundation

/// Decides which kept-after-failure recordings to drop. Split out from the file
/// handling so the "keep the newest N" rule can be tested without touching disk.
public enum RecordingRetention {
    /// How many failed recordings to keep around.
    public static let keepCount = 5

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
    public static func expired(from entries: [Entry], keeping keepCount: Int = keepCount) -> [Entry] {
        guard keepCount >= 0 else { return entries }
        guard entries.count > keepCount else { return [] }

        let newestFirst = entries.sorted { left, right in
            if left.created != right.created {
                return left.created > right.created
            }
            return left.url.lastPathComponent > right.url.lastPathComponent
        }

        return Array(newestFirst.dropFirst(keepCount)).reversed()
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
