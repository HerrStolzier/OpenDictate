import Foundation
import Testing

@testable import OpenDictate

@Suite("Keychain helper watchdog")
struct HelperWatchdogTests {
    private func run(_ executable: String, _ arguments: [String], timeout: TimeInterval, killDelay: TimeInterval = 5)
        throws -> (terminated: Bool, running: Bool)
    {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        let watchdog = HelperWatchdog(process, timeout: timeout, killDelay: killDelay)
        process.waitUntilExit()
        return (watchdog.finish(), process.isRunning)
    }

    @Test("A helper that does not answer is terminated")
    func hungHelperIsTerminated() throws {
        let result = try run("/bin/sleep", ["5"], timeout: 0.2)
        #expect(result.terminated)
        #expect(!result.running)
    }

    @Test("A helper that ignores SIGTERM is killed")
    func helperIgnoringTerminateIsKilled() throws {
        let start = Date()
        let result = try run("/bin/sh", ["-c", "trap '' TERM; exec /bin/sleep 30"], timeout: 0.2, killDelay: 0.2)
        #expect(result.terminated)
        #expect(!result.running)
        #expect(Date().timeIntervalSince(start) < 10)
    }

    @Test("A helper that answers in time is left alone")
    func promptHelperIsNotTerminated() throws {
        let result = try run("/usr/bin/true", [], timeout: 5)
        #expect(!result.terminated)
        #expect(!result.running)
    }
}
