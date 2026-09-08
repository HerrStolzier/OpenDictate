import AppKit
import Foundation

/// Bounded, ordered logging. Callers enqueue metadata without waiting for I/O.
enum AppLog {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/OpenDictate.log")
    private static let writer = LogWriter(url: url)

    @MainActor
    static func reveal() {
        writer.flush()
        NSWorkspace.shared.open(url)
    }

    static func write(_ message: String) { writer.write(message) }
}

final class LogWriter: @unchecked Sendable {
    private let queue = DispatchQueue(label: "OpenDictate.log", qos: .utility)
    private let url: URL
    private let maximumBytes: Int
    // Confined to queue, including timestamp formatting.
    private let formatter = ISO8601DateFormatter()

    init(url: URL, maximumBytes: Int = 1_048_576) {
        self.url = url
        self.maximumBytes = maximumBytes
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func write(_ message: String) {
        let date = Date()
        queue.async { [self] in
            let line = "[\(formatter.string(from: date))] \(message.replacingOccurrences(of: "\n", with: " ").prefix(4096))\n"
            do {
                let manager = FileManager.default
                try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                let count = (try? manager.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
                if count + line.utf8.count > maximumBytes {
                    let previous = url.appendingPathExtension("previous")
                    if manager.fileExists(atPath: previous.path) { try manager.removeItem(at: previous) }
                    if manager.fileExists(atPath: url.path) { try manager.moveItem(at: url, to: previous) }
                }
                if !manager.fileExists(atPath: url.path) {
                    manager.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
                }
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
            } catch { NSLog("OpenDictate log unavailable") }
        }
    }

    func flush() { queue.sync {} }
}
