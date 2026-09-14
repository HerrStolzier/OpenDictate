import CryptoKit
import Foundation
import OpenDictateCore
import Testing

@testable import OpenDictate

@Suite("Recovery access expiry")
struct RecoveryExpiryTests {
    @Test func exactExpiryAndFallbackToNextValidCandidate() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let key = SymmetricKey(size: .bits256)
        let name = "2026-09-06T10-00-00Z-1234ABCD.m4a"
        let url = directory.appendingPathComponent(name)
        let bytes = Data([1, 2, 3])
        try bytes.write(to: url)
        try FailedRecordingStore.authenticationCode(for: bytes, filename: name, key: key).write(
            to: url.appendingPathExtension("auth"))
        let created = try #require(FailedRecordingStore.date(from: name))
        #expect(FailedRecordingStore.payload(at: url, now: created.addingTimeInterval(86399), key: key) != nil)
        #expect(FailedRecordingStore.payload(at: url, now: created.addingTimeInterval(86400), key: key) == nil)
        #expect(FailedRecordingStore.payload(at: url, now: created.addingTimeInterval(86401), key: key) == nil)
        let invalid = directory.appendingPathComponent("2026-09-06T11-00-00Z-ABCD1234.m4a")
        try Data([9]).write(to: invalid)
        let newest = FailedRecordingStore.newest(now: created.addingTimeInterval(7200), in: directory, key: key)
        #expect(newest?.url.lastPathComponent == name)
        #expect(newest?.data == bytes)
    }
    @Test func pruningOnlyRemovesSidecarsForAbsentAudio() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let name = "2026-09-08T09-00-00Z-1234ABCD.m4a"
        let now = try #require(FailedRecordingStore.date(from: name))
        let audio = directory.appendingPathComponent(name)
        let auth = audio.appendingPathExtension("auth")
        let bytes = Data([1, 2, 3])
        let key = SymmetricKey(size: .bits256)
        try bytes.write(to: audio)
        try FailedRecordingStore.authenticationCode(for: bytes, filename: name, key: key).write(to: auth)
        FailedRecordingStore.prune(now: now, in: directory)
        #expect(FailedRecordingStore.payload(at: audio, now: now, key: key)?.data == bytes)
        // A present but modified file must keep its sidecar without becoming retryable.
        try Data([9]).write(to: audio)
        FailedRecordingStore.prune(now: now, in: directory)
        #expect(FileManager.default.fileExists(atPath: auth.path))
        #expect(FailedRecordingStore.payload(at: audio, now: now, key: key) == nil)
        try FileManager.default.removeItem(at: audio)
        try FileManager.default.createSymbolicLink(atPath: audio.path, withDestinationPath: "missing-target")
        FailedRecordingStore.prune(now: now, in: directory)
        #expect(FileManager.default.fileExists(atPath: auth.path))
        #expect(FailedRecordingStore.payload(at: audio, now: now, key: key) == nil)
        try FileManager.default.removeItem(at: audio)
        FailedRecordingStore.prune(now: now, in: directory)
        #expect(!FileManager.default.fileExists(atPath: auth.path))
    }

}
