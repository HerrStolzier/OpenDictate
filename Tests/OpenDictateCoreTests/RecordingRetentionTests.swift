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

    @Test("Nothing to prune while at or under the limit")
    func underLimit() {
        #expect(RecordingRetention.expired(from: entries([1, 2, 3, 4, 5]), now: epoch).isEmpty)
    }

    @Test("Input order does not matter")
    func orderIndependent() {
        let shuffled = entries([7, 3, 1, 6, 2, 5, 4])
        let expired = RecordingRetention.expired(from: shuffled, now: epoch)
        #expect(expired.count == 2)
        #expect(Set(expired.map(\.url.lastPathComponent)) == ["1.m4a", "2.m4a"])
    }

    @Test("The newest entry is the retry candidate")
    func newestWins() {
        let newest = RecordingRetention.newest(in: entries([3, 9, 1]))
        #expect(newest?.url.lastPathComponent == "9.m4a")
    }

    @Test("Equal timestamps break ties on the file name, so the result is stable")
    func stableOnTies() {
        let same = ["a", "b", "c"].map {
            RecordingRetention.Entry(url: URL(fileURLWithPath: "/tmp/failed/\($0).m4a"), created: epoch)
        }
        #expect(RecordingRetention.newest(in: same)?.url.lastPathComponent == "c.m4a")
        let expired = RecordingRetention.expired(from: same, now: epoch, keeping: 1)
        #expect(expired.map(\.url.lastPathComponent) == ["a.m4a", "b.m4a"])
    }

    @Test("Recordings expire at the configured age boundary")
    func expiresByAge() {
        let now = epoch.addingTimeInterval(RecordingRetention.maximumAge)
        let expired = RecordingRetention.expired(from: entries([0, 1]), now: now)
        #expect(expired.map(\.url.lastPathComponent) == ["0.m4a"])
    }

    @Test("Age and count expiry are combined without duplicates")
    func combinesAgeAndCount() {
        let old = RecordingRetention.Entry(
            url: URL(fileURLWithPath: "/tmp/failed/old.m4a"),
            created: epoch.addingTimeInterval(-RecordingRetention.maximumAge)
        )
        let recent = entries([1, 2, 3])
        let expired = RecordingRetention.expired(from: [old] + recent, now: epoch, keeping: 2)
        #expect(expired.map(\.url.lastPathComponent) == ["old.m4a", "1.m4a"])
    }
}
