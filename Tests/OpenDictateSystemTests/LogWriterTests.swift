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
}
