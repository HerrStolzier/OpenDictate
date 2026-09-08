import Foundation

extension TimeInterval {
    public var formattedSeconds: String {
        String(format: "%.1fs", self)
    }
}

extension Float {
    public var formattedDb: String {
        String(format: "%.0f dB", self)
    }
}

extension Data {
    public mutating func appendString(_ value: String) {
        append(value.data(using: .utf8)!)
    }
}
