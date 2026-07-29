import Foundation

public extension TimeInterval {
    var formattedSeconds: String {
        String(format: "%.1fs", self)
    }
}

public extension Float {
    var formattedDb: String {
        String(format: "%.0f dB", self)
    }
}

public extension Data {
    mutating func appendString(_ value: String) {
        append(value.data(using: .utf8)!)
    }
}
