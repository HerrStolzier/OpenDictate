namespace OpenDictate.Core;

// The window that was in front when a dictation started. Handles are reused,
// so the process and its start time identify the window's owner as well.
public sealed record WindowTarget(nint Window, int ProcessId, long ProcessStartTicks);

// Ctrl+V reaches whichever field is focused in the front window. It is sent
// only into the window captured for this dictation, only while it is still in
// front, only when the clipboard still holds the transcript and only after the
// user has let go of every modifier (a held Ctrl+Win would turn Ctrl+V into a
// different shortcut). Otherwise the text stays on the clipboard.
public static class PastePolicy
{
    public static bool MayPaste(bool autoInsert, WindowTarget? captured, WindowTarget? current,
        string? clipboard, string transcript, bool modifiersReleased, int ownProcessId) =>
        autoInsert && captured is not null && captured.Window != 0 && captured.ProcessId != ownProcessId &&
        captured == current && modifiersReleased && StringComparer.Ordinal.Equals(clipboard, transcript);

    // Editors and browsers can contain a terminal. Do not auto-paste a line
    // break into any target; the user can paste it deliberately from the clipboard.
    public static bool MayPasteText(string transcript) => !TranscriptText.IsMultiline(transcript);
}
