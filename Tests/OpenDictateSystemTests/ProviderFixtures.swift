import Foundation

/// Shared provider fixtures in `fixtures/provider/`, the same files the Linux
/// and Windows clients are meant to test against.
enum ProviderFixtures {
    static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("fixtures/provider", isDirectory: true)

    struct Cases: Decodable {
        struct Success: Decodable {
            let file: String
            let status: Int
            let text: String
        }
        struct Failure: Decodable {
            let file: String
            let status: Int
            let macMessageContains: String

            enum CodingKeys: String, CodingKey {
                case file, status
                case macMessageContains = "mac_message_contains"
            }
        }
        let success: Success
        let errors: [Failure]
    }

    static func data(_ name: String) throws -> Data {
        try Data(contentsOf: directory.appendingPathComponent(name))
    }

    static func cases() throws -> Cases {
        try JSONDecoder().decode(Cases.self, from: data("cases.json"))
    }
}
