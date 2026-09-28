using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

namespace OpenDictate.Prototype;

internal enum DeliveryResult { Rejected, Completed, Uncertain }

// A single edit addressed to a verified native control. No clipboard, keyboard
// stream, whole-field replacement or fallback to a different delivery mechanism.
internal static class NativeEditInsertion
{
    internal static bool Supports(string className) =>
        className.Equals("RichEditD2DPT", StringComparison.OrdinalIgnoreCase) ||
        className.Equals("RICHEDIT50W", StringComparison.OrdinalIgnoreCase) ||
        className.Equals("RichEdit20W", StringComparison.OrdinalIgnoreCase) ||
        className.Equals("Edit", StringComparison.OrdinalIgnoreCase);

    internal static string ClassName(nint window)
    {
        var name = new StringBuilder(128);
        return GetClassNameW(window, name, name.Capacity) > 0 ? name.ToString() : string.Empty;
    }

    internal static (uint Start, uint End)? Selection(nint editor)
    {
        nint completed = ReadSelection(editor, 0x00B0, out uint start, out uint end,
            0x0001 | 0x0002 | 0x0020, 500, out _);
        return completed != 0 && start <= end ? (start, end) : null;
    }

    internal static DeliveryResult Replace(FocusTarget target, string text)
    {
        if (target.Editor == 0 || text.Length == 0 || text.Contains('\0') ||
            !Supports(target.EditorClass) || !Native.ModifiersReleased() ||
            Selection(target.Editor) != (target.SelectionStart, target.SelectionEnd) ||
            Native.GetForegroundWindow() != target.Window ||
            !IsWindowEnabled(target.Editor) || !IsWindowVisible(target.Editor) ||
            GetAncestor(target.Editor, 2) != target.Window ||
            !StringComparer.Ordinal.Equals(ClassName(target.Editor), target.EditorClass))
            return DeliveryResult.Rejected;

        uint thread = Native.GetWindowThreadProcessId(target.Editor, out uint processId);
        if (thread == 0 || processId != target.ProcessId) return DeliveryResult.Rejected;
        try
        {
            using var process = Process.GetProcessById(target.ProcessId);
            if (process.StartTime.ToUniversalTime().Ticks != target.ProcessStartTicks)
                return DeliveryResult.Rejected;
        }
        catch (Exception error) when (error is ArgumentException or InvalidOperationException or System.ComponentModel.Win32Exception)
        { return DeliveryResult.Rejected; }

        var info = new GuiThreadInfo { Size = (uint)Marshal.SizeOf<GuiThreadInfo>() };
        if (!GetGUIThreadInfo(thread, ref info) || info.Focus != target.Editor)
            return DeliveryResult.Rejected;
        // ES_PASSWORD and ES_READONLY are shared by these known edit classes.
        long style = GetWindowLongPtrW(target.Editor, -16).ToInt64();
        if ((style & (0x20 | 0x800)) != 0 || Native.GetForegroundWindow() != target.Window)
            return DeliveryResult.Rejected;

        // EM_REPLACESEL is a system message (< WM_USER); Windows marshals the
        // Unicode string across processes. TRUE retains native undo support.
        // A timeout does not prove non-delivery, so it must never cause a retry.
        nint completed = SendMessageTimeoutW(target.Editor, 0x00C2, 1, text,
            0x0001 | 0x0002 | 0x0020, 1000, out _);
        return completed != 0 ? DeliveryResult.Completed : DeliveryResult.Uncertain;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct Rect { internal int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)]
    private struct GuiThreadInfo
    {
        internal uint Size, Flags;
        internal nint Active, Focus, Capture, MenuOwner, MoveSize, Caret;
        internal Rect CaretRect;
    }
    [DllImport("user32.dll", EntryPoint = "SendMessageTimeoutW", SetLastError = true)]
    private static extern nint ReadSelection(nint window, uint message, out uint start,
        out uint end, uint flags, uint timeout, out nuint result);
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern nint SendMessageTimeoutW(nint window, uint message, nint undo,
        string text, uint flags, uint timeout, out nuint result);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetClassNameW(nint window, StringBuilder name, int maxCount);
    [DllImport("user32.dll")] private static extern nint GetAncestor(nint window, uint flags);
    [DllImport("user32.dll")] private static extern nint GetWindowLongPtrW(nint window, int index);
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetGUIThreadInfo(uint thread, ref GuiThreadInfo info);
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool IsWindowEnabled(nint window);
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool IsWindowVisible(nint window);
}
