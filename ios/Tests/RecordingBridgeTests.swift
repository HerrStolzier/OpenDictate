import Foundation
import Testing

@testable import OpenDictateIOSBridge

struct RecordingBridgeTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func withBridge(_ body: (RecordingBridge) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(RecordingBridge(directory: directory))
    }

    private func recording(id: UUID = UUID()) -> RecordingSnapshot {
        RecordingSnapshot(id: id, startedAt: start, updatedAt: start, phase: .recording)
    }

    @Test func staleStopCannotStopAnotherSession() throws {
        try withBridge { bridge in
            let first = recording()
            let second = recording()
            try bridge.publish(first, at: start)
            #expect(try bridge.requestStop(id: first.id, at: start))
            try bridge.publish(second, at: start)
            #expect(!bridge.hasStopRequest(id: second.id))
            #expect(try !bridge.requestStop(id: first.id, at: start))
            #expect(try bridge.requestStop(id: second.id, at: start))
        }
    }

    @Test func recordingAndResultExpireAtAccess() throws {
        try withBridge { bridge in
            var snapshot = recording()
            try bridge.publish(snapshot, at: start)
            #expect(try bridge.snapshot(at: start.addingTimeInterval(15)) == nil)
            snapshot.phase = .ready
            snapshot.updatedAt = start.addingTimeInterval(5)
            snapshot.duration = 5
            try bridge.publish(snapshot, at: snapshot.updatedAt)
            #expect(try bridge.claimTestText(id: snapshot.id, at: start.addingTimeInterval(65)) == nil)
        }
    }

    @Test func textRequiresACompletedMatchingSessionAndOneClaim() throws {
        try withBridge { bridge in
            var snapshot = recording()
            try bridge.publish(snapshot, at: start)
            #expect(try bridge.claimTestText(id: snapshot.id, at: start) == nil)
            snapshot.phase = .failed
            try bridge.publish(snapshot, at: start)
            #expect(try bridge.claimTestText(id: snapshot.id, at: start) == nil)
            snapshot.phase = .ready
            snapshot.updatedAt = start.addingTimeInterval(4)
            snapshot.duration = 4
            try bridge.publish(snapshot, at: snapshot.updatedAt)
            #expect(try bridge.claimTestText(id: UUID(), at: snapshot.updatedAt) == nil)
            #expect(
                try bridge.claimTestText(id: snapshot.id, at: snapshot.updatedAt)
                    == "OpenDictate Testtext (synthetisch)")
            #expect(try bridge.claimTestText(id: snapshot.id, at: snapshot.updatedAt) == nil)
        }
    }

    @Test func invalidOversizedAndFutureSnapshotsAreRejected() throws {
        try withBridge { bridge in
            var snapshot = recording()
            try bridge.publish(snapshot, at: start)
            let file = bridge.directory.appendingPathComponent("session.json")
            var oversized = try JSONEncoder().encode(snapshot)
            oversized.append(Data(repeating: 0x20, count: 4_097 - oversized.count))
            try oversized.write(to: file)
            #expect(try bridge.snapshot(at: start) == nil)
            snapshot.version = 2
            try JSONEncoder().encode(snapshot).write(to: file)
            #expect(try bridge.snapshot(at: start) == nil)
            snapshot.version = 1
            try JSONEncoder().encode(snapshot).write(to: file)
            #expect(try bridge.snapshot(at: start.addingTimeInterval(-1)) == nil)
        }
    }

    @Test func concurrentConsumersCannotDeliverTwice() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let bridge = RecordingBridge(directory: directory)
        let ready = RecordingSnapshot(id: UUID(), startedAt: start, updatedAt: start, phase: .ready, duration: 1)
        try bridge.publish(ready, at: start)
        let claims = try await withThrowingTaskGroup(of: Bool.self) { group in
            for _ in 0..<8 {
                group.addTask { try bridge.claimTestText(id: ready.id, at: ready.updatedAt) != nil }
            }
            var count = 0
            for try await claimed in group { count += claimed ? 1 : 0 }
            return count
        }
        #expect(claims == 1)
    }

    @Test func displayedActionCannotChangeMeaningOrSessionAtTheTap() throws {
        try withBridge { bridge in
            var first = recording()
            try bridge.publish(first, at: start)
            let displayedStop = RecordingBridge.Action.stop(first.id)
            first.phase = .ready
            first.duration = 1
            try bridge.publish(first, at: start)
            #expect(try bridge.perform(displayedStop, at: start) == nil)
            #expect(!bridge.hasDeliveryClaim(id: first.id))

            let displayedInsert = RecordingBridge.Action.insert(first.id)
            var second = recording()
            try bridge.publish(second, at: start)
            #expect(try bridge.perform(displayedStop, at: start) == nil)
            #expect(!bridge.hasStopRequest(id: second.id))
            second.phase = .ready
            second.duration = 1
            try bridge.publish(second, at: start)
            #expect(try bridge.perform(displayedInsert, at: start) == nil)
            #expect(!bridge.hasDeliveryClaim(id: second.id))
            #expect(try bridge.perform(.insert(second.id), at: start) == "OpenDictate Testtext (synthetisch)")
        }
    }
}
