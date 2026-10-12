import Foundation

/// A transcript is text the user wants to type, never a stream of key codes.
/// Control characters and invisible direction marks are removed before the
/// text reaches the clipboard, so a provider response cannot carry escape
/// sequences or hidden characters into the target. Line breaks and tabs stay.
public enum TranscriptText {
    public static func sanitize(_ text: String) -> String {
        var cleaned = String.UnicodeScalarView()
        var previousWasCarriageReturn = false
        for scalar in text.unicodeScalars {
            defer { previousWasCarriageReturn = scalar == "\r" }
            if scalar == "\r" {
                cleaned.append("\n")
            } else if scalar == "\n" {
                if !previousWasCarriageReturn { cleaned.append(scalar) }
            } else if scalar == "\t" {
                cleaned.append(scalar)
            } else if scalar.properties.generalCategory == .control || isDirectionControl(scalar) {
                continue
            } else {
                cleaned.append(scalar)
            }
        }
        return String(cleaned).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Some servers, such as whisper.cpp, cut a recording at speaking pauses
    /// and end every segment with a line break. In a dictation those breaks are
    /// not spoken content, so each whitespace run that contains a line break
    /// becomes a single space. Apply after `sanitize`, which trims the ends;
    /// whitespace at the end without a line break is dropped here.
    public static func joiningSegments(_ text: String) -> String {
        var joined = ""
        var pendingWhitespace = ""
        var pendingHasLineBreak = false
        for character in text {
            if character.isWhitespace {
                pendingWhitespace.append(character)
                if character.isNewline { pendingHasLineBreak = true }
                continue
            }
            joined += pendingHasLineBreak ? " " : pendingWhitespace
            pendingWhitespace = ""
            pendingHasLineBreak = false
            joined.append(character)
        }
        return joined
    }

    public static func isMultiline(_ text: String) -> Bool {
        text.unicodeScalars.contains("\n")
    }

    /// Bidirectional embeddings, overrides and isolates plus the marks, which
    /// can reorder how pasted text reads without being visible.
    private static func isDirectionControl(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x202A...0x202E, 0x2066...0x2069, 0x200E, 0x200F, 0x061C: true
        default: false
        }
    }
}
