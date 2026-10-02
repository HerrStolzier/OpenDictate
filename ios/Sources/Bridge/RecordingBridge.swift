import Foundation

struct RecordingSnapshot: Codable, Equatable, Sendable {
    enum Phase: String, Codable, Sendable {
        case recording, ready, failed
    }

    static let groupIdentifier = "group.com.opendictate.ios.keyboarddemo"
    static let recordingLimit: TimeInterval = 15
    static let retention: TimeInterval = 60
    static let testText = "OpenDictate Testtext (synthetisch)"

    var version = 1
    let id: UUID
    let startedAt: Date
    var updatedAt: Date
    var phase: Phase
    var duration: TimeInterval?

    var deadline: Date { startedAt.addingTimeInterval(Self.recordingLimit) }

    func isFresh(at now: Date) -> Bool {
        guard version == 1, startedAt <= updatedAt, updatedAt <= now,
            updatedAt.timeIntervalSince(startedAt) <= Self.recordingLimit + 5,
            now.timeIntervalSince(updatedAt) < Self.retention
        else { return false }
        switch phase {
        case .recording:
            return duration == nil && now < deadline
        case .ready:
            return duration.map { $0.isFinite && $0 > 0 && $0 <= Self.recordingLimit + 0.1 } ?? false
        case .failed:
            return duration == nil
        }
    }
}

/// The host owns the snapshot; the keyboard writes only session-scoped markers.
/// Delivery is synchronous at the deliberate button press, never after an await.
struct RecordingBridge: Sendable {
    enum Action: Equatable, Sendable {
        case stop(UUID)
        case insert(UUID)
    }

    let directory: URL

    func perform(_ action: Action, at now: Date) throws -> String? {
        switch action {
        case .stop(let id):
            _ = try requestStop(id: id, at: now)
            return nil
        case .insert(let id):
            return try claimTestText(id: id, at: now)
        }
    }

    func snapshot(at now: Date) throws -> RecordingSnapshot? {
        let url = directory.appendingPathComponent("session.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        guard let data = try handle.read(upToCount: 4_097), data.count <= 4_096,
            let snapshot = try? JSONDecoder().decode(RecordingSnapshot.self, from: data),
            snapshot.isFresh(at: now)
        else { return nil }
        return snapshot
    }

    func publish(_ snapshot: RecordingSnapshot, at now: Date) throws {
        guard snapshot.isFresh(at: now) else { throw CocoaError(.fileWriteInvalidFileName) }
        try createDirectory()
        var options: Data.WritingOptions = .atomic
        #if os(iOS)
            options.insert(.completeFileProtection)
        #endif
        try JSONEncoder().encode(snapshot).write(to: directory.appendingPathComponent("session.json"), options: options)
    }

    func requestStop(id: UUID, at now: Date) throws -> Bool {
        guard let current = try snapshot(at: now), current.id == id, current.phase == .recording else { return false }
        _ = try createMarker("stop", id: id)
        return true
    }

    func hasStopRequest(id: UUID) -> Bool {
        FileManager.default.fileExists(atPath: marker("stop", id: id).path)
    }

    func hasDeliveryClaim(id: UUID) -> Bool {
        FileManager.default.fileExists(atPath: marker("delivered", id: id).path)
    }

    func claimTestText(id: UUID, at now: Date) throws -> String? {
        guard let current = try snapshot(at: now), current.id == id, current.phase == .ready,
            try createMarker("delivered", id: id),
            let confirmed = try snapshot(at: now), confirmed == current
        else { return nil }
        return RecordingSnapshot.testText
    }

    private func marker(_ kind: String, id: UUID) -> URL {
        directory.appendingPathComponent("\(kind)-\(id.uuidString)")
    }

    private func createDirectory() throws {
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }

    private func createMarker(_ kind: String, id: UUID) throws -> Bool {
        try createDirectory()
        var options: Data.WritingOptions = .withoutOverwriting
        #if os(iOS)
            options.insert(.completeFileProtection)
        #endif
        do {
            try Data().write(to: marker(kind, id: id), options: options)
            return true
        } catch CocoaError.fileWriteFileExists {
            return false
        }
    }
}
