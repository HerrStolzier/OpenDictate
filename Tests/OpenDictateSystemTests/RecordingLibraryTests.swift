import CryptoKit
import Foundation
import OpenDictateCore
import Testing
import os

@testable import OpenDictate

@Suite("Recording library")
struct RecordingLibraryTests {
    @Test func unchangedRecordingsAskForTheRecoveryKeyOnlyOnce() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let keyData = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        let key = SymmetricKey(data: keyData)
        let reads = OSAllocatedUnfairLock(initialState: 0)
        let library = RecordingLibrary(directory: directory) {
            reads.withLock { $0 += 1 }
            return SymmetricKey(data: keyData)
        }
        let older = "2026-09-06T10-00-00Z-1234ABCD.m4a"
        let newer = "2026-09-06T11-00-00Z-ABCD1234.m4a"
        for name in [older, newer] {
            let bytes = Data([1, 2, 3])
            try bytes.write(to: directory.appendingPathComponent(name))
            try FailedRecordingStore.authenticationCode(for: bytes, filename: name, key: key).write(
                to: directory.appendingPathComponent(name).appendingPathExtension("auth"))
        }
        let now = try #require(FailedRecordingStore.date(from: newer)).addingTimeInterval(60)

        let first = await library.snapshot(now: now)
        #expect(first.map(\.filename) == [newer, older])
        #expect(first.map(\.retryable) == [true, true])
        let second = await library.snapshot(now: now.addingTimeInterval(60))
        #expect(second.map(\.retryable) == [true, true])
        #expect(reads.withLock { $0 } == 1)

        // A changed file is authenticated again and is no longer offered.
        try Data([9]).write(to: directory.appendingPathComponent(older))
        let changed = await library.snapshot(now: now.addingTimeInterval(120))
        #expect(changed.map(\.retryable) == [true, false])
        #expect(reads.withLock { $0 } == 2)

        // Expired recordings leave the list without another key read.
        let created = try #require(FailedRecordingStore.date(from: newer))
        let expired = await library.snapshot(now: created.addingTimeInterval(RecordingRetention.maximumAge))
        #expect(expired.isEmpty)
        #expect(reads.withLock { $0 } == 2)
    }

    @Test func aMissingKeyIsAskedForAgainOnTheNextSnapshot() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let reads = OSAllocatedUnfairLock(initialState: 0)
        let library = RecordingLibrary(directory: directory) {
            reads.withLock { $0 += 1 }
            return nil
        }
        let name = "2026-09-06T10-00-00Z-1234ABCD.m4a"
        try Data([1, 2, 3]).write(to: directory.appendingPathComponent(name))
        let now = try #require(FailedRecordingStore.date(from: name)).addingTimeInterval(60)

        #expect(await library.snapshot(now: now).map(\.retryable) == [false])
        #expect(await library.snapshot(now: now).map(\.retryable) == [false])
        #expect(reads.withLock { $0 } == 2)
    }
}
