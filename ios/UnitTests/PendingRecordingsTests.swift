import XCTest

@testable import OpenDictateiOS

/// The rules for kept audio: only tagged, unchanged recordings are offered for
/// "Send again", nothing is deleted before the recovery limits remove it, and
/// the limits apply when the recordings are read.
final class PendingRecordingsTests: XCTestCase {
    private var base: URL!
    private var store: PendingRecordings!

    override func setUpWithError() throws {
        try XCTSkipIf(KeychainStore.recordingKey(create: true) == nil, "No Keychain in this run")
        base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        store = PendingRecordings(base: base)
        store.prepare()
    }

    override func tearDownWithError() throws {
        if let base { try? FileManager.default.removeItem(at: base) }
    }

    func testKeptRecordingIsOfferedWithItsBytes() throws {
        let audio = Data("first dictation".utf8)
        let kept = store.keep(try recording(audio))
        XCTAssertEqual(store.newest()?.url.lastPathComponent, kept.lastPathComponent)
        XCTAssertEqual(store.authenticatedAudio(at: kept), audio)
    }

    func testChangedAudioIsKeptButNotOffered() throws {
        let kept = store.keep(try recording(Data("original".utf8)))
        try Data("changed".utf8).write(to: kept)
        XCTAssertNil(store.authenticatedAudio(at: kept))
        XCTAssertNil(store.newest())
        XCTAssertTrue(FileManager.default.fileExists(atPath: kept.path))
    }

    func testUntaggedRecordingIsKeptButNotOffered() throws {
        let kept = store.keep(try recording(Data("too short".utf8)), retryable: false)
        XCTAssertNil(store.newest())
        XCTAssertTrue(FileManager.default.fileExists(atPath: kept.path))
    }

    func testRecordingOlderThanADayIsDeletedWhenRead() throws {
        let kept = store.keep(try recording(Data("old".utf8)))
        XCTAssertNil(store.newest(now: Date() + 25 * 60 * 60))
        XCTAssertFalse(FileManager.default.fileExists(atPath: kept.path))
    }

    func testOnlyTheFiveNewestStay() throws {
        var kept: [URL] = []
        for index in 0..<6 {
            let url = store.keep(try recording(Data("dictation \(index)".utf8)))
            try created(url, secondsAgo: Double(60 - index))
            kept.append(url)
        }
        XCTAssertEqual(store.newest()?.url.lastPathComponent, kept[5].lastPathComponent)
        XCTAssertFalse(FileManager.default.fileExists(atPath: kept[0].path))
        for url in kept.dropFirst() { XCTAssertTrue(FileManager.default.fileExists(atPath: url.path)) }
    }

    func testExcludedRecordingDoesNotHideAnOlderOne() throws {
        let older = store.keep(try recording(Data("older".utf8)))
        try created(older, secondsAgo: 30)
        let newer = store.keep(try recording(Data("newer".utf8)))
        XCTAssertEqual(store.newest(excluding: newer)?.url.lastPathComponent, older.lastPathComponent)
    }

    func testLeftoverOfAnEndedProcessIsKeptWithoutTag() throws {
        let leftover = try recording(Data("cut off".utf8))
        store.prepare()
        XCTAssertFalse(FileManager.default.fileExists(atPath: leftover.path))
        let kept = try FileManager.default.contentsOfDirectory(atPath: store.keptDirectory.path)
        XCTAssertEqual(kept.filter { $0.hasSuffix(".m4a") }.count, 1)
        XCTAssertNil(store.newest())
    }

    // MARK: Helpers

    /// A finished recording in the folder the recorder writes to.
    private func recording(_ audio: Data) throws -> URL {
        let url = store.newRecordingURL()
        try audio.write(to: url)
        return url
    }

    private func created(_ url: URL, secondsAgo: TimeInterval) throws {
        try FileManager.default.setAttributes([.creationDate: Date() - secondsAgo], ofItemAtPath: url.path)
    }
}
