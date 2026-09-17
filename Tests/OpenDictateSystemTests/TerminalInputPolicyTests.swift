import Testing

@testable import OpenDictate

@Suite("Terminal text without command keys")
struct TerminalInputPolicyTests {
    @Test func allControlAndFunctionKeyScalarsAreRejected() throws {
        let values = Array(0...0x1F) + Array(0x7F...0x9F) + Array(0x2028...0x2029) + Array(0xF700...0xF8FF)
        for value in values {
            let scalar = try #require(UnicodeScalar(value))
            #expect(!TerminalInputPolicy.permits("Before" + String(scalar) + "After"))
        }
    }

    @Test func printableUnicodeRemainsExactAndEmptyTextIsRejected() {
        #expect(TerminalInputPolicy.permits("Grüße, 中文, e\u{301} und 👩🏽‍💻 🍏; 42 | text"))
        #expect(TerminalInputPolicy.permits(" \u{7E}\u{A0}\u{F6FF}\u{F900}"))
        #expect(!TerminalInputPolicy.permits(""))
    }
}
