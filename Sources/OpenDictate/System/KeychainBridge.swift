import Foundation
import Security

/// Keeps the Keychain-facing code identity stable while the main app changes.
/// The helper is copied once and replaced on a later launch only when the
/// installed copy no longer carries the app's own signing identity.
enum KeychainBridge {
    enum Operation: String, Codable {
        case ping
        case presence
        case read
        case update
        case add
        case delete
    }

    private struct Request: Codable {
        let version: Int
        let operation: Operation
        let account: String
        let data: Data?
    }

    private struct Response: Codable {
        let version: Int
        let status: OSStatus
        let data: Data?
    }

    private static let appCertificate: Data? = selfCertificate()

    /// How long one request may take before the helper is terminated and the
    /// request fails. Generous, because the helper may be waiting for the user
    /// to answer a macOS Keychain prompt; it only stops a hung helper from
    /// blocking its caller forever.
    static let timeout: TimeInterval = 60

    static var isActive: Bool {
        Bundle.main.bundleIdentifier == "local.opendictate.app"
            && Bundle.main.executableURL?.lastPathComponent == "OpenDictate"
            && appCertificate != nil
    }

    static func perform(_ operation: Operation, account: String, data: Data? = nil) -> (OSStatus, Data?) {
        guard isActive else { return (errSecNotAvailable, nil) }
        let allowedAccounts = [
            "OPENAI_API_KEY_APP", "OPENAI_API_KEY", "FAILED_RECORDING_AUTH_KEY", "TRUSTED_SERVER_ADDRESS"
        ]
        guard allowedAccounts.contains(account),
            let executable = account == "TRUSTED_SERVER_ADDRESS" ? installedServerHelperURL : installedHelperURL,
            let request = try? JSONEncoder().encode(
                Request(version: 1, operation: operation, account: account, data: data))
        else { return (errSecNotAvailable, nil) }

        let process = Process()
        let input = Pipe()
        let output = Pipe()
        process.executableURL = executable
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.environment = [:]
        do {
            try process.run()
            let watchdog = HelperWatchdog(process, timeout: timeout)
            defer { _ = watchdog.finish() }
            guard let certificate = appCertificate,
                let identity = runningIdentity(pid: process.processIdentifier),
                identity.identifier == "OpenDictateKeychainHelper",
                identity.certificate == certificate
            else {
                input.fileHandleForWriting.closeFile()
                process.waitUntilExit()
                return (errSecNotAvailable, nil)
            }
            // A helper that exits before reading its request must cost only
            // this request: no SIGPIPE and no Objective-C exception.
            let writer = input.fileHandleForWriting
            _ = fcntl(writer.fileDescriptor, F_SETNOSIGPIPE, 1)
            do {
                try writer.write(contentsOf: request)
                try writer.close()
            } catch {
                try? writer.close()
                process.waitUntilExit()
                return (errSecNotAvailable, nil)
            }
            let reply = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            if watchdog.finish() {
                AppLog.write("Keychain helper did not answer within \(Int(timeout)) s and was terminated")
                return (errSecNotAvailable, nil)
            }
            guard process.terminationStatus == 0,
                reply.count <= 16_384,
                let response = try? JSONDecoder().decode(Response.self, from: reply),
                response.version == 1
            else { return (errSecNotAvailable, nil) }
            return (response.status, response.data)
        } catch {
            return (errSecNotAvailable, nil)
        }
    }

    private static let installedHelperURL: URL? = installHelperIfNeeded()
    // The existing helper's on-disk copy cannot be updated: its stable code
    // identity protects existing API keys. A separate stable copy handles the
    // new account without changing that Keychain access list.
    private static let installedServerHelperURL: URL? = installHelperIfNeeded(named: "KeychainHelper-server-v1")

    private static func installHelperIfNeeded(named name: String = "KeychainHelper-v1") -> URL? {
        let manager = FileManager.default
        guard let appCertificate,
            let support = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        let directory = support.appendingPathComponent("OpenDictate", isDirectory: true)
        let installed = directory.appendingPathComponent(name)
        let bundled = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/OpenDictateKeychainHelper")
        guard hasExpectedSignature(bundled, certificate: appCertificate) else { return nil }

        do {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            guard try directory.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
                return nil
            }
            let present = manager.fileExists(atPath: installed.path)
            if present {
                guard try installed.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
                    return nil
                }
            }
            if !present || !hasExpectedSignature(installed, certificate: appCertificate) {
                let temporary = directory.appendingPathComponent(".KeychainHelper-\(UUID().uuidString)")
                defer { try? manager.removeItem(at: temporary) }
                try manager.copyItem(at: bundled, to: temporary)
                try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: temporary.path)
                if present {
                    // A helper signed with an earlier certificate can no longer
                    // prove its identity, so the current one takes its place.
                    _ = try manager.replaceItemAt(installed, withItemAt: temporary)
                    AppLog.write("Replaced the Keychain helper after a signing identity change")
                } else {
                    do {
                        try manager.moveItem(at: temporary, to: installed)
                    } catch {
                        guard manager.fileExists(atPath: installed.path) else { return nil }
                    }
                }
            }
            guard try installed.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true,
                hasExpectedSignature(installed, certificate: appCertificate)
            else { return nil }
            return installed
        } catch {
            return nil
        }
    }

    private static func selfCertificate() -> Data? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess,
            let code,
            SecCodeCheckValidity(code, [], nil) == errSecSuccess
        else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
            let staticCode
        else { return nil }
        return signingIdentity(staticCode)?.certificate
    }

    private static func runningIdentity(pid: Int32) -> (identifier: String, certificate: Data)? {
        var code: SecCode?
        let attributes: [String: Any] = [kSecGuestAttributePid as String: NSNumber(value: pid)]
        guard SecCodeCopyGuestWithAttributes(nil, attributes as CFDictionary, [], &code) == errSecSuccess,
            let code,
            SecCodeCheckValidity(code, [], nil) == errSecSuccess
        else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
            let staticCode
        else { return nil }
        return signingIdentity(staticCode)
    }

    private static func hasExpectedSignature(_ url: URL, certificate: Data) -> Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess,
            let code,
            SecStaticCodeCheckValidity(code, [], nil) == errSecSuccess,
            let identity = signingIdentity(code)
        else { return false }
        return identity.identifier == "OpenDictateKeychainHelper" && identity.certificate == certificate
    }

    private static func signingIdentity(_ code: SecStaticCode) -> (identifier: String, certificate: Data)? {
        var information: CFDictionary?
        guard
            SecCodeCopySigningInformation(
                code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
            let values = information as? [String: Any],
            let identifier = values[kSecCodeInfoIdentifier as String] as? String,
            let certificate = (values[kSecCodeInfoCertificates as String] as? [SecCertificate])?.first
        else { return nil }
        return (identifier, SecCertificateCopyData(certificate) as Data)
    }
}

/// Terminates a helper that does not answer in time. The caller blocks on the
/// helper's output and exit, so without this a hung helper would block it
/// forever. A helper that ignores SIGTERM gets SIGKILL after `killDelay`.
final class HelperWatchdog: @unchecked Sendable {
    // Both properties are guarded by `lock`.
    private let lock = NSLock()
    private var process: Process?
    private var didTerminate = false
    private let killDelay: TimeInterval

    init(_ process: Process, timeout: TimeInterval, killDelay: TimeInterval = 5) {
        self.process = process
        self.killDelay = killDelay
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) { [self] in
            terminateIfRunning()
        }
    }

    private func terminateIfRunning() {
        lock.lock()
        defer { lock.unlock() }
        guard let process, process.isRunning else { return }
        didTerminate = true
        process.terminate()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + killDelay) { [self] in
            killIfRunning()
        }
    }

    private func killIfRunning() {
        lock.lock()
        defer { lock.unlock() }
        // `finish()` clears `process` only after the caller saw the exit, so a
        // process still held here has not been reaped and its PID is its own.
        guard let process, process.isRunning else { return }
        kill(process.processIdentifier, SIGKILL)
    }

    /// Disarms the watchdog; true when it had to terminate the helper.
    func finish() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        process = nil
        return didTerminate
    }
}
