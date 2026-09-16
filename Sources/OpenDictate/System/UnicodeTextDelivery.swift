import AppKit

/// Sends exact text without consulting the global clipboard. Events stay process-scoped.
@MainActor
struct UnicodeTextDelivery {
    static func chunks(_ text: String, isolateLineBreaks: Bool = false) -> [[UniChar]] {
        var result: [[UniChar]] = []
        var chunk: [UniChar] = []
        for scalar in text.unicodeScalars {
            let units = Array(String(scalar).utf16)
            // WebKit treats a leading newline as a Return command and ignores
            // trailing text in that event. Keep line breaks in their own events.
            if isolateLineBreaks && (scalar == "\n" || scalar == "\r") {
                if scalar == "\n", result.last == [13], chunk.isEmpty {
                    result[result.count - 1].append(10)  // One CRLF is one Return command.
                    continue
                }
                if !chunk.isEmpty { result.append(chunk) }
                result.append(units)
                chunk = []
                continue
            }
            if chunk.count + units.count > 20 {
                result.append(chunk)
                chunk = []
            }
            chunk.append(contentsOf: units)
        }
        if !chunk.isEmpty { result.append(chunk) }
        return result
    }

    static func events(_ units: [UniChar]) -> (CGEvent, CGEvent)? {
        guard let source = CGEventSource(stateID: .privateState),
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else { return nil }
        down.flags = []
        up.flags = []
        down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        return (down, up)
    }

    static func send(
        _ text: String,
        isolateLineBreaks: Bool = false,
        stillFocused: () -> Bool,
        post: ([UniChar]) -> Bool
    ) async -> Bool {
        let parts = chunks(text, isolateLineBreaks: isolateLineBreaks)
        guard !parts.isEmpty else { return false }
        for (index, part) in parts.enumerated() {
            guard !Task.isCancelled, stillFocused(), post(part) else { return false }
            if index < parts.count - 1 {
                do { try await Task.sleep(for: .milliseconds(5)) } catch { return false }
            }
        }
        return true
    }
}
