using System.Text;

namespace OpenDictate.Core;

// A transcript is text the user wants to type, never a stream of key codes.
// Control characters and invisible direction marks are removed before the
// text is copied, so a provider response cannot carry escape sequences or
// hidden characters into the clipboard. Line breaks and tabs stay.
public static class TranscriptText
{
    public static string Sanitize(string text)
    {
        var cleaned = new StringBuilder(text.Length);
        for (int index = 0; index < text.Length; index++)
        {
            char current = text[index];
            if (current == '\r')
            {
                if (index + 1 < text.Length && text[index + 1] == '\n') index++;
                cleaned.Append('\n');
                continue;
            }
            if (current is '\u2028' or '\u2029') { cleaned.Append('\n'); continue; }
            if (current is '\n' or '\t') { cleaned.Append(current); continue; }
            if (current is '\u2028' or '\u2029') { cleaned.Append('\n'); continue; }
            if (char.IsControl(current) || IsDirectionControl(current)) continue;
            cleaned.Append(current);
        }
        return cleaned.ToString().Trim();
    }

    public static bool IsMultiline(string text) =>
        text.Contains('\n') || text.Contains('\r') || text.Contains('\u2028') || text.Contains('\u2029');

    // Bidirectional embeddings, overrides and isolates plus the marks, which
    // can reorder how pasted text reads without being visible.
    private static bool IsDirectionControl(char current) =>
        current is (>= '\u202A' and <= '\u202E') or (>= '\u2066' and <= '\u2069') or '\u200E' or '\u200F' or '\u061C';
}
