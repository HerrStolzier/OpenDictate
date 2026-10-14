import Foundation
import Testing

@testable import OpenDictateCore

@Suite("Temporary recordings left after a crash")
struct TemporaryRecordingsTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let uuid = "0F1E2D3C-4B5A-6978-8796-A5B4C3D2E1F0"

    private func entry(_ name: String, age: TimeInterval) -> RecordingRetention.Entry {
        RecordingRetention.Entry(url: URL(fileURLWithPath: "/tmp/\(name)"), created: now.addingTimeInterval(-age))
    }

    @Test("Only names the recorder and the trimmer generate are recognised")
    func recognisesGeneratedNames() {
        #expect(TemporaryRecordings.isRecordingName("opendictate-\(uuid).m4a"))
        #expect(TemporaryRecordings.isRecordingName("opendictate-trimmed-\(uuid).m4a"))
        #expect(TemporaryRecordings.isRecordingName("opendictate-\(uuid.lowercased()).m4a"))
        for name in [
            "opendictate-.m4a", "opendictate-notes.m4a", "opendictate-\(uuid).m4a.auth",
            "opendictate-\(uuid).wav", "other-\(uuid).m4a", "opendictate-trimmed-\(uuid)-x.m4a",
            "OpenDictate-tests.log"
        ] {
            #expect(!TemporaryRecordings.isRecordingName(name), "\(name)")
        }
    }

    @Test("A recording is removed at 24 hours, never earlier, and unknown files stay")
    func removesOnlyOldGeneratedRecordings() {
        let maximumAge = RecordingRetention.maximumAge
        let entries = [
            entry("opendictate-\(uuid).m4a", age: maximumAge),
            entry("opendictate-trimmed-\(uuid).m4a", age: maximumAge + 3_600),
            entry("opendictate-00000000-0000-0000-0000-000000000001.m4a", age: maximumAge - 1),
            entry("opendictate-00000000-0000-0000-0000-000000000002.m4a", age: -3_600),
            entry("someone-elses.m4a", age: maximumAge * 10)
        ]
        let expired = TemporaryRecordings.expired(from: entries, now: now)
        #expect(
            expired.map(\.url.lastPathComponent) == [
                "opendictate-\(uuid).m4a", "opendictate-trimmed-\(uuid).m4a"
            ])
    }
}
