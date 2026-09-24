import Foundation
import Security

/// Keeps the Keychain-facing code identity stable while the main app changes.
/// The helper is copied once and never silently replaced on later launches.
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

    static var isActive: Bool {
        Bundle.main.bundleIdentifier == "local.opendictate.app"
            && Bundle.main.executableURL?.lastPathComponent == "OpenDictate"
            && appCertificate != nil
    }

    static func perform(_ operation: Operation, account: String, data: Data? = nil) -> (OSStatus, Data?) {
        guard isActive else { return (errSecNotAvailable, nil) }
        guard ["OPENAI_API_KEY_APP", "OPENAI_API_KEY", "FAILED_RECORDING_AUTH_KEY"].contains(account),
            let executable = installedHelperURL,
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
            guard let certificate = appCertificate,
                let identity = runningIdentity(pid: process.processIdentifier),
                identity.identifier == "OpenDictateKeychainHelper",
                identity.certificate == certificate
            else {
                input.fileHandleForWriting.closeFile()
                process.waitUntilExit()
                return (errSecNotAvailable, nil)
            }
            input.fileHandleForWriting.write(request)
            input.fileHandleForWriting.closeFile()
            let reply = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
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

    private static func installHelperIfNeeded() -> URL? {
        let manager = FileManager.default
        guard let appCertificate,
            let support = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        let directory = support.appendingPathComponent("OpenDictate", isDirectory: true)
        let installed = directory.appendingPathComponent("KeychainHelper-v1")
        let bundled = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/OpenDictateKeychainHelper")
        guard hasExpectedSignature(bundled, certificate: appCertificate) else { return nil }

        do {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            guard try directory.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
                return nil
            }
            if !manager.fileExists(atPath: installed.path) {
                let temporary = directory.appendingPathComponent(".KeychainHelper-\(UUID().uuidString)")
                defer { try? manager.removeItem(at: temporary) }
                try manager.copyItem(at: bundled, to: temporary)
                try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: temporary.path)
                do {
                    try manager.moveItem(at: temporary, to: installed)
                } catch {
                    guard manager.fileExists(atPath: installed.path) else { return nil }
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
