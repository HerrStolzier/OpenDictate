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
}
