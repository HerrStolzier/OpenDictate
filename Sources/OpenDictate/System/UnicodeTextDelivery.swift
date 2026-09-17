import AppKit

/// Sends exact text without consulting the global clipboard. Events stay process-scoped.
@MainActor
struct UnicodeTextDelivery {
    enum LineBreakPolicy {
        case grouped, isolated, trailing
    }

    static func policy(for bundleID: String?) -> LineBreakPolicy {
        switch bundleID {
        case "com.apple.Safari": .isolated
        case "com.brave.Browser": .trailing
        default: .grouped
        }
    }

    static func chunks(_ text: String, lineBreakPolicy: LineBreakPolicy = .grouped) -> [[UniChar]] {
        if lineBreakPolicy == .trailing { return trailingLineBreakChunks(text) }
        var result: [[UniChar]] = []
        var chunk: [UniChar] = []
        for scalar in text.unicodeScalars {
            let units = Array(String(scalar).utf16)
            // Safari discards trailing text in a newline-leading event, but accepts
            // an isolated newline event. Other editors retain their grouped path.
            if lineBreakPolicy == .isolated && (scalar == "\n" || scalar == "\r") {
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

    /// Brave ignores a newline-leading event, including a standalone newline.
    /// Bind each line-break run to its preceding grapheme before packing. Inputs
    /// that cannot satisfy the 20-unit event bound fall back before posting.
    private static func trailingLineBreakChunks(_ text: String) -> [[UniChar]] {
        var segments: [[UniChar]] = []
        for character in text {
            let units = Array(String(character).utf16)
            let isLineBreak = character.unicodeScalars.allSatisfy { $0 == "\n" || $0 == "\r" }
            if isLineBreak {
                guard !segments.isEmpty, segments[segments.count - 1].count + units.count <= 20 else { return [] }
                segments[segments.count - 1].append(contentsOf: units)
            } else {
                guard units.count <= 20 else { return [] }
                segments.append(units)
            }
        }

        var result: [[UniChar]] = []
        var chunk: [UniChar] = []
        for segment in segments {
            if chunk.count + segment.count > 20 {
                result.append(chunk)
                chunk = []
            }
            chunk.append(contentsOf: segment)
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
        lineBreakPolicy: LineBreakPolicy = .grouped,
        stillFocused: () -> Bool,
        post: ([UniChar]) -> Bool
    ) async -> Bool {
        let parts = chunks(text, lineBreakPolicy: lineBreakPolicy)
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
