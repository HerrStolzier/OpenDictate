import Darwin
import Foundation
import LocalAuthentication
import Security

// This executable is deliberately small. The installed copy is kept across
// OpenDictate updates so its file-based Keychain partition ID stays stable.
private enum KeychainRequest: String, Codable {
    case ping
    case presence
    case read
    case update
    case add
    case delete
}

private enum KeychainAccount: String, Codable {
    case apiKey = "OPENAI_API_KEY_APP"
    case legacyAPIKey = "OPENAI_API_KEY"
    case recordingAuthentication = "FAILED_RECORDING_AUTH_KEY"
}

private struct Request: Codable {
    let version: Int
    let operation: KeychainRequest
    let account: KeychainAccount
    let data: Data?
}

private struct Response: Codable {
    let version: Int
    let status: OSStatus
    let data: Data?
}

@main
private enum KeychainHelper {
    static func main() {
        // A direct launch from Terminal or an unrelated app must never become
        // a way to read the user's API key through this trusted executable.
        guard parentIsSignedOpenDictate() else { exit(EXIT_FAILURE) }
        let input = FileHandle.standardInput.readDataToEndOfFile()
        guard input.count <= 16_384,
            let request = try? JSONDecoder().decode(Request.self, from: input),
            request.version == 1
        else { exit(EXIT_FAILURE) }

        let response = perform(request)
        guard let output = try? JSONEncoder().encode(response) else { exit(EXIT_FAILURE) }
        FileHandle.standardOutput.write(output)
    }

    private static func parentIsSignedOpenDictate() -> Bool {
        let parentPID = getppid()
        guard parentPID > 1,
            let ownIdentity = codeIdentity(pid: getpid()),
            let parentIdentity = codeIdentity(pid: parentPID)
        else { return false }
        return ownIdentity.identifier == "OpenDictateKeychainHelper"
            && parentIdentity.identifier == "local.opendictate.app"
            && ownIdentity.certificate == parentIdentity.certificate
    }

    private static func codeIdentity(pid: pid_t) -> (identifier: String, certificate: Data)? {
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
        var information: CFDictionary?
        guard
            SecCodeCopySigningInformation(
                staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
            let values = information as? [String: Any],
            let identifier = values[kSecCodeInfoIdentifier as String] as? String,
            let certificate = (values[kSecCodeInfoCertificates as String] as? [SecCertificate])?.first
        else { return nil }
        return (identifier, SecCertificateCopyData(certificate) as Data)
    }

    private static func perform(_ request: Request) -> Response {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "OpenDictate",
            kSecAttrAccount as String: request.account.rawValue
        ]
        let status: OSStatus
        var data: Data?
        switch request.operation {
        case .ping:
            guard request.data == nil else { return Response(version: 1, status: errSecParam, data: nil) }
            status = errSecSuccess
        case .presence:
            guard request.data == nil else { return Response(version: 1, status: errSecParam, data: nil) }
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            let context = LAContext()
            context.interactionNotAllowed = true
            query[kSecUseAuthenticationContext as String] = context
            status = SecItemCopyMatching(query as CFDictionary, nil)
        case .read:
            guard request.data == nil else { return Response(version: 1, status: errSecParam, data: nil) }
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var result: CFTypeRef?
            status = SecItemCopyMatching(query as CFDictionary, &result)
            if status == errSecSuccess {
                guard let value = result as? Data else {
                    return Response(version: 1, status: errSecDecode, data: nil)
                }
                data = value
            }
        case .update:
            guard let value = request.data else { return Response(version: 1, status: errSecParam, data: nil) }
            status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: value] as CFDictionary)
        case .add:
            guard let value = request.data else { return Response(version: 1, status: errSecParam, data: nil) }
            query[kSecValueData as String] = value
            if request.account == .recordingAuthentication {
                query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            }
            status = SecItemAdd(query as CFDictionary, nil)
        case .delete:
            guard request.data == nil else { return Response(version: 1, status: errSecParam, data: nil) }
            status = SecItemDelete(query as CFDictionary)
        }
        return Response(version: 1, status: status, data: data)
    }
}
