import CryptoKit
import Foundation
import OpenDictateCore
import Testing
@testable import OpenDictate

@Suite("Failed recording store security boundaries")
struct FailedRecordingStoreTests {
    @Test("Only generated m4a names are eligible")
    func filenamePolicy() {
        #expect(FailedRecordingStore.isExpectedFilename("2026-09-06T20-00-00Z-ABCDEF12.m4a"))
        #expect(!FailedRecordingStore.isExpectedFilename("2026-09-06T20-00-00Z-ABCDEF12.wav"))
        #expect(!FailedRecordingStore.isExpectedFilename("../2026-09-06T20-00-00Z-ABCDEF12.m4a"))
        #expect(!FailedRecordingStore.isExpectedFilename("2026-09-06T20-00-00Z-abcdef12.m4a"))
    }

    @Test("Secure read accepts a bounded regular file")
    func readsRegularFile() throws {
        let fixture = try Fixture()
        let url = fixture.directory.appendingPathComponent("audio.m4a")
        try Data("audio".utf8).write(to: url)
        #expect(FailedRecordingStore.secureRead(url, maximumBytes: 5) == Data("audio".utf8))
    }

    @Test("Secure read rejects a symbolic link")
    func rejectsSymlink() throws {
        let fixture = try Fixture()
        let target = fixture.directory.appendingPathComponent("target")
        let link = fixture.directory.appendingPathComponent("link")
        try Data("secret".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        #expect(FailedRecordingStore.secureRead(link, maximumBytes: 100) == nil)
    }

    @Test("Secure read rejects directories and oversized files")
    func rejectsWrongTypeAndSize() throws {
        let fixture = try Fixture()
        #expect(FailedRecordingStore.secureRead(fixture.directory, maximumBytes: 100) == nil)

        let large = fixture.directory.appendingPathComponent("large.m4a")
        try Data(repeating: 0x41, count: 5).write(to: large)
        #expect(FailedRecordingStore.secureRead(large, maximumBytes: 4) == nil)
    }

    @Test("Authentication binds both the filename and the exact audio bytes")
    func authenticationBindsPayload() {
        let key = SymmetricKey(data: Data(repeating: 0x42, count: 32))
        let audio = Data("audio".utf8)
        let filename = "2026-09-06T20-00-00Z-ABCDEF12.m4a"
        let code = FailedRecordingStore.authenticationCode(for: audio, filename: filename, key: key)

        #expect(FailedRecordingStore.isValidAuthenticationCode(code, for: audio, filename: filename, key: key))
        #expect(!FailedRecordingStore.isValidAuthenticationCode(code, for: Data("tampered".utf8), filename: filename, key: key))
        #expect(!FailedRecordingStore.isValidAuthenticationCode(code, for: audio, filename: "2026-09-06T20-00-00Z-DEADBEEF.m4a", key: key))
    }

    @Test("Deletion never follows links or recursively removes directories")
    func deletionIsSingleEntryOnly() throws {
        let fixture = try Fixture()
        let target = fixture.directory.appendingPathComponent("target")
        let link = fixture.directory.appendingPathComponent("link")
        try Data("keep".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        #expect(FailedRecordingStore.unlinkFile(link))
        #expect(FileManager.default.fileExists(atPath: target.path))
        #expect(!FailedRecordingStore.unlinkFile(fixture.directory))
        #expect(FileManager.default.fileExists(atPath: target.path))
    }

    @Test("Prune covers legacy and unverifiable files without a Keychain key")
    func prunesLegacyAndOrphans() throws {
        let fixture = try Fixture()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let oldName = timestamp(now.addingTimeInterval(-RecordingRetention.maximumAge)) + "-ABCDEF12.m4a"
        let newName = timestamp(now.addingTimeInterval(-60)) + "-ABCDEF13.m4a"
        let orphanName = timestamp(now.addingTimeInterval(-30)) + "-ABCDEF14.m4a.auth"
        let old = fixture.directory.appendingPathComponent(oldName)
        let recent = fixture.directory.appendingPathComponent(newName)
        let corruptTag = recent.appendingPathExtension("auth")
        let orphanTag = fixture.directory.appendingPathComponent(orphanName)
        for url in [old, recent, corruptTag, orphanTag] {
            try Data("fixture".utf8).write(to: url)
            try FileManager.default.setAttributes([.posixPermissions: 0o666], ofItemAtPath: url.path)
        }

        FailedRecordingStore.prune(now: now, in: fixture.directory)

        #expect(!FileManager.default.fileExists(atPath: old.path))
        #expect(FileManager.default.fileExists(atPath: recent.path))
        #expect(FileManager.default.fileExists(atPath: corruptTag.path))
        #expect(!FileManager.default.fileExists(atPath: orphanTag.path))
        let permissions = try FileManager.default.attributesOfItem(atPath: recent.path)[.posixPermissions] as? NSNumber
        #expect(permissions?.intValue == 0o600)
    }

    private func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss'Z'"
        return formatter.string(from: date)
    }
}

private final class Fixture {
    let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenDictateTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }
}
