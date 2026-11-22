import XCTest

@testable import OpenDictateiOS

/// What the keyboard does with the app's snapshot and commands: dictate only
/// while the app really holds the microphone, insert each text once and only
/// into the dictation it belongs to.
final class KeyboardBridgeTests: XCTestCase {
    private let now: TimeInterval = 1_000_000

    private func snapshot(_ state: KeyboardSessionState, heartbeatAge: TimeInterval = 0.5) -> KeyboardSnapshot {
        KeyboardSnapshot(state: state, heartbeat: now - heartbeatAge, warmUntil: now + 600)
    }

    func testAWarmSessionIsReady() {
        XCTAssertEqual(snapshot(.ready).effectiveState(at: now), .ready)
    }

    func testAnAppThatStoppedWritingCountsAsOff() {
        // iOS ended or suspended the app: the key must open it instead of waiting.
        XCTAssertEqual(snapshot(.ready, heartbeatAge: 5).effectiveState(at: now), .off)
        XCTAssertEqual(snapshot(.recording, heartbeatAge: 5).effectiveState(at: now), .off)
    }

    func testAnExpiredSessionCountsAsOff() {
        var expired = snapshot(.ready)
        expired.warmUntil = now - 1
        XCTAssertEqual(expired.effectiveState(at: now), .off)
    }

    func testTheTextGoesOnlyToItsOwnDictationAndOnlyOnce() {
        var done = snapshot(.ready)
        done.jobID = "job"
        done.resultID = "result"
        done.text = "Hallo Welt"
        done.resultAt = now - 1
        XCTAssertEqual(done.deliverableText(forJob: "job", insertedResultID: nil, at: now), "Hallo Welt")
        XCTAssertNil(done.deliverableText(forJob: "other", insertedResultID: nil, at: now))
        XCTAssertNil(done.deliverableText(forJob: nil, insertedResultID: nil, at: now))
        XCTAssertNil(done.deliverableText(forJob: "job", insertedResultID: "result", at: now))
    }

    func testAnOldTextIsNotInsertedIntoALaterField() {
        var done = snapshot(.ready)
        done.jobID = "job"
        done.resultID = "result"
        done.text = "Hallo"
        done.resultAt = now - KeyboardSnapshot.resultLifetime - 1
        XCTAssertNil(done.deliverableText(forJob: "job", insertedResultID: nil, at: now))
    }

    func testAnOldCommandDoesNotStartARecording() {
        XCTAssertTrue(KeyboardCommand(kind: .start, jobID: "job", sentAt: now - 1).isFresh(at: now))
        XCTAssertFalse(KeyboardCommand(kind: .start, jobID: "job", sentAt: now - 30).isFresh(at: now))
    }

    func testCommandsAndSnapshotsRoundTripThroughTheGroup() throws {
        let name = "KeyboardBridgeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let bridge = KeyboardBridge(defaults: defaults)
        XCTAssertEqual(bridge.snapshot(), .off)
        XCTAssertEqual(bridge.warmDuration, .fifteenMinutes)
        bridge.warmDuration = .oneHour
        XCTAssertEqual(bridge.warmDuration, .oneHour)
        let command = KeyboardCommand(kind: .stop, jobID: "job")
        bridge.send(command)
        XCTAssertEqual(bridge.command(), command)
        let state = snapshot(.recording)
        bridge.publish(state, notify: false)
        XCTAssertEqual(bridge.snapshot(), state)
    }

    func testTheKeyboardLinkStartsTheSession() {
        XCTAssertTrue(KeyboardLink.isStartSession(KeyboardLink.startSession))
        XCTAssertFalse(KeyboardLink.isStartSession(URL(string: "opendictate://keyboard/other")!))
        XCTAssertFalse(KeyboardLink.isStartSession(URL(string: "https://keyboard/start")!))
    }
}
