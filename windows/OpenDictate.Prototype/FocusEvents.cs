using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace OpenDictate.Prototype;

// Out-of-context WinEvent callbacks run on the registering UI/message-loop
// thread. Any foreground or object-focus event invalidates a pending attempt.
internal sealed class FocusEvents : IDisposable
{
    private readonly Callback callback;
    private nint foreground;
    private nint focus;
    private nint edits;
    private nint selection;
    internal nint ObservedEditor { get; set; }
    private uint observedSince = unchecked((uint)Environment.TickCount);
    internal void BeginObservation()
    {
        observedSince = unchecked((uint)Environment.TickCount);
        ObservedEditor = 0;
    }

    internal FocusEvents(Action changed)
    {
        callback = (_, eventId, window, objectId, _, _, time) =>
        {
            // WinEvents can arrive after the input that triggered this attempt.
            // Ignore events generated before the hotkey, not new target changes.
            if (unchecked((int)(time - observedSince)) < 0) return;
            // Scrollbar value/layout changes are not edits. Track the exact
            // captured editor: client text/selection and its caret only.
            bool editorChanged = window == ObservedEditor && ObservedEditor != 0 &&
                ((eventId == 0x800E && objectId == -4) ||
                 (eventId == 0x8014 && objectId == -4) ||
                 (eventId == 0x800B && objectId == -8));
            if (eventId == 0x0003 || eventId == 0x8005 || editorChanged) changed();
        };
        foreground = SetWinEventHook(0x0003, 0x0003, 0, callback, 0, 0, 0);
        focus = SetWinEventHook(0x8005, 0x8005, 0, callback, 0, 0, 0);
        edits = SetWinEventHook(0x800B, 0x800E, 0, callback, 0, 0, 0);
        selection = SetWinEventHook(0x8014, 0x8014, 0, callback, 0, 0, 0);
        if (foreground == 0 || focus == 0 || edits == 0 || selection == 0)
        {
            Dispose();
            throw new Win32Exception("Focus event registration failed.");
        }
    }

    public void Dispose()
    {
        if (foreground != 0) { UnhookWinEvent(foreground); foreground = 0; }
        if (focus != 0) { UnhookWinEvent(focus); focus = 0; }
        if (edits != 0) { UnhookWinEvent(edits); edits = 0; }
        if (selection != 0) { UnhookWinEvent(selection); selection = 0; }
    }

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void Callback(nint hook, uint eventId, nint window, int objectId, int childId, uint thread, uint time);
    [DllImport("user32.dll", SetLastError = true)]
    private static extern nint SetWinEventHook(uint min, uint max, nint module, Callback handler, uint process, uint thread, uint flags);
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWinEvent(nint hook);
}
