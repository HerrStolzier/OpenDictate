/// Terminal input is keystroke delivery, not selected-text replacement. Refuse
/// line breaks, control characters and AppKit's private function-key range
/// before sending any chunk. This does not identify the program or prompt
/// running inside the terminal, nor prove that ordinary keys have no effects.
enum TerminalInputPolicy {
    static func permits(_ text: String) -> Bool {
        !text.isEmpty
            && text.unicodeScalars.allSatisfy {
                switch $0.value {
                case 0...0x1F, 0x7F...0x9F, 0x2028...0x2029, 0xF700...0xF8FF: false
                default: true
                }
            }
    }
}
