import Darwin
import Foundation
import Testing

@testable import OpenDictate

@Suite("Offline resource benchmarks", .serialized)
struct ResourceBenchmarkTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["OPENDICTATE_RESOURCE_BENCHMARK"] == "1"))
    func recoveryPruning() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let now = try #require(FailedRecordingStore.date(from: "2026-09-08T10-00-00Z-1234ABCD.m4a"))
        var rows = ["files,bytes_per_file,iteration,wall_ms,cpu_ms,process_peak_rss_bytes"]
        for size in [0, 500_000, 16 * 1_024 * 1_024] {
            let directory = root.appendingPathComponent("size-\(size)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if size > 0 {
                for index in 0..<5 {
                    let url = directory.appendingPathComponent("2026-09-08T09-0\(index)-00Z-1234ABCD.m4a")
                    try Data(repeating: 42, count: size).write(to: url)
                    try Data(repeating: 0, count: 32).write(to: url.appendingPathExtension("auth"))
                }
            }
            for iteration in 0..<16 {
                var before = rusage()
                getrusage(RUSAGE_SELF, &before)
                let start = ContinuousClock.now
                FailedRecordingStore.prune(now: now, in: directory)
                let elapsed = start.duration(to: .now)
                var after = rusage()
                getrusage(RUSAGE_SELF, &after)
                let wall = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
                func cpu(_ value: rusage) -> Double {
                    Double(value.ru_utime.tv_sec + value.ru_stime.tv_sec) * 1000
                        + Double(value.ru_utime.tv_usec + value.ru_stime.tv_usec) / 1000
                }
                rows.append(
                    "\(size == 0 ? 0 : 5),\(size),\(iteration),\(wall),\(cpu(after) - cpu(before)),\(after.ru_maxrss)")
            }
            #expect(FailedRecordingStore.candidateAudioURLs(in: directory).count == (size == 0 ? 0 : 5))
        }
        let output = try #require(ProcessInfo.processInfo.environment["OPENDICTATE_RESOURCE_BENCHMARK_OUTPUT"])
        try (rows.joined(separator: "\n") + "\n").write(toFile: output, atomically: true, encoding: .utf8)
    }
}
