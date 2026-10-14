import Foundation
import Testing

@testable import OpenDictate

@Suite("Bounded logging")
struct LogWriterTests {
    @Test func rotatesAndPreservesCompleteRecords() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("log")
        let writer = LogWriter(url: url, maximumBytes: 500)
        for index in 0..<40 { writer.write("record-\(index)") }
        writer.flush()
        let active = try String(contentsOf: url, encoding: .utf8)
        let previous = try String(contentsOf: url.appendingPathExtension("previous"), encoding: .utf8)
        #expect(active.contains("record-39\n"))
        #expect(active.utf8.count <= 500 && previous.utf8.count <= 500)
        #expect(active.split(separator: "\n").allSatisfy { $0.hasPrefix("[") && $0.contains("] record-") })
    }

    @Test func restrictsAnExistingLogToTheOwner() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("log")
        #expect(FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o644]))
        let writer = LogWriter(url: url)
        writer.write("record")
        writer.flush()
        let permissions = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        #expect(permissions?.intValue == 0o600)
    }

    @Test func restrictsAReadableLogThatRotates() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("log")
        let previous = url.appendingPathExtension("previous")
        let writer = LogWriter(url: url, maximumBytes: 500)
        writer.write("first")
        writer.flush()
        // An active log that is readable by others when it rotates.
        try Data(repeating: 65, count: 490).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
        writer.write("second")
        writer.flush()
        #expect(try Data(contentsOf: previous) == Data(repeating: 65, count: 490))
        for path in [url.path, previous.path] {
            let permissions = try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? NSNumber
            #expect(permissions?.intValue == 0o600)
        }
    }

    @Test func restrictsAnExistingPreviousLogOnce() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("log")
        let previous = url.appendingPathExtension("previous")
        let readable: [FileAttributeKey: Any] = [.posixPermissions: 0o644]
        #expect(FileManager.default.createFile(atPath: previous.path, contents: nil, attributes: readable))
        let writer = LogWriter(url: url)
        writer.write("record")
        writer.flush()
        let attributes = try FileManager.default.attributesOfItem(atPath: previous.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    }
}
