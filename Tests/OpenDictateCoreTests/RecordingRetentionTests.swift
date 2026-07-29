import Foundation
import Testing
@testable import OpenDictateCore

@Suite("Failed recording retention")
struct RecordingRetentionTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func entries(_ offsets: [Double]) -> [RecordingRetention.Entry] {
        offsets.map {
            RecordingRetention.Entry(
                url: URL(fileURLWithPath: "/tmp/failed/\(Int($0)).m4a"),
                created: epoch.addingTimeInterval($0)
            )
        }
    }

    @Test("Nothing to prune when the folder is empty")
    func emptyFolder() {
        #expect(RecordingRetention.expired(from: []).isEmpty)
        #expect(RecordingRetention.newest(in: []) == nil)
    }

    @Test("Nothing to prune while at or under the limit")
    func underLimit() {
        #expect(RecordingRetention.expired(from: entries([1, 2, 3, 4, 5])).isEmpty)
    }

    @Test("Only the oldest beyond the limit are dropped")
    func dropsOldest() {
        let expired = RecordingRetention.expired(from: entries([1, 2, 3, 4, 5, 6, 7]))
        #expect(expired.count == 2)
        #expect(expired.map(\.created.timeIntervalSince1970) == [
            epoch.addingTimeInterval(1).timeIntervalSince1970,
            epoch.addingTimeInterval(2).timeIntervalSince1970
        ])
    }

    @Test("Input order does not matter")
    func orderIndependent() {
        let shuffled = entries([7, 3, 1, 6, 2, 5, 4])
        let expired = RecordingRetention.expired(from: shuffled)
        #expect(expired.count == 2)
        #expect(Set(expired.map(\.url.lastPathComponent)) == ["1.m4a", "2.m4a"])
    }

    @Test("The newest entry is the retry candidate")
    func newestWins() {
        let newest = RecordingRetention.newest(in: entries([3, 9, 1]))
        #expect(newest?.url.lastPathComponent == "9.m4a")
    }

    @Test("A single kept recording is both newest and safe from pruning")
    func singleEntry() {
        let single = entries([42])
        #expect(RecordingRetention.expired(from: single).isEmpty)
        #expect(RecordingRetention.newest(in: single)?.url.lastPathComponent == "42.m4a")
    }

    @Test("Equal timestamps break ties on the file name, so the result is stable")
    func stableOnTies() {
        let same = ["a", "b", "c"].map {
            RecordingRetention.Entry(url: URL(fileURLWithPath: "/tmp/failed/\($0).m4a"), created: epoch)
        }
        #expect(RecordingRetention.newest(in: same)?.url.lastPathComponent == "c.m4a")
        let expired = RecordingRetention.expired(from: same, keeping: 1)
        #expect(expired.map(\.url.lastPathComponent) == ["a.m4a", "b.m4a"])
    }

    @Test("Keeping zero drops everything")
    func keepNone() {
        #expect(RecordingRetention.expired(from: entries([1, 2]), keeping: 0).count == 2)
    }
}
