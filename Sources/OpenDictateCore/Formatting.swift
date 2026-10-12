import Foundation

extension TimeInterval {
    /// German user-facing duration: one decimal with a comma and a space before
    /// the unit, a whole number without ",0" ("0,4 s", "1 s"). Independent of the
    /// system locale because all user-facing text is German.
    public var formattedSeconds: String {
        let tenths = (self * 10).rounded()
        if tenths.truncatingRemainder(dividingBy: 10) == 0 {
            return String(format: "%.0f s", tenths / 10)
        }
        return String(format: "%.1f s", tenths / 10).replacingOccurrences(of: ".", with: ",")
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
