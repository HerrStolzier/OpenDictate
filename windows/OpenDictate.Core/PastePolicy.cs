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

    // A line break pasted into a console runs the dictated line as a command.
    // Multi-line text therefore stays on the clipboard for these programs.
    private static readonly string[] ConsoleProcesses =
    [
        "windowsterminal", "conhost", "openconsole", "cmd", "powershell", "pwsh", "powershell_ise",
        "mintty", "alacritty", "wezterm-gui", "putty", "kitty", "hyper", "tabby", "cmder", "conemu64", "conemu",
    ];

    public static bool IsConsole(string? processName) =>
        processName is not null && Array.Exists(ConsoleProcesses, name => string.Equals(name, processName, StringComparison.OrdinalIgnoreCase));

    public static bool MayPasteText(string transcript, string? processName) =>
        !(IsConsole(processName) && TranscriptText.IsMultiline(transcript));
}
