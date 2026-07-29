import Foundation

extension TimeInterval {
    var formattedSeconds: String {
        String(format: "%.1fs", self)
    }
}

extension Float {
    var formattedDb: String {
        String(format: "%.0f dB", self)
    }
}

extension Data {
    mutating func appendString(_ value: String) {
        append(value.data(using: .utf8)!)
    }
}
