using System;
using System.Diagnostics;
using System.Windows.Automation;

namespace OpenDictate.Prototype;

internal sealed record FocusTarget(nint Window, string Identity, int ProcessId,
    long ProcessStartTicks, nint Editor, string EditorClass, uint SelectionStart, uint SelectionEnd);

internal static class FocusProbe
{
    internal static FocusTarget? Capture()
    {
        try
        {
            nint window = Native.GetForegroundWindow();
            if (window == 0) return null;
            Native.GetWindowThreadProcessId(window, out uint windowProcess);
            var element = AutomationElement.FocusedElement;
            var info = element.Current;
            if (!info.HasKeyboardFocus || !info.IsEnabled || info.IsPassword)
                return null;
            using var process = Process.GetProcessById(info.ProcessId);
            if (!process.ProcessName.Equals("notepad", StringComparison.OrdinalIgnoreCase))
                return null;
            if (info.ControlType != ControlType.Edit && info.ControlType != ControlType.Document) return null;
            // Browser accessibility providers may run in a renderer process.
            // Verify the actual UIA ancestry rather than assuming the same PID.
            var root = AutomationElement.FromHandle(window);
            var ancestor = element;
            bool belongsToWindow = false;
            for (int depth = 0; ancestor is not null && depth < 64; depth++)
            {
                if (Automation.Compare(ancestor, root)) { belongsToWindow = true; break; }
                ancestor = TreeWalker.RawViewWalker.GetParent(ancestor);
            }
            if (!belongsToWindow) return null;
            if (element.TryGetCurrentPattern(ValuePattern.Pattern, out object value) && ((ValuePattern)value).Current.IsReadOnly)
                return null;
            var id = element.GetRuntimeId();
            if (id.Length == 0 || Native.GetForegroundWindow() != window) return null;
            // Neither field text nor accessible names leave the target probe.
            nint editor = info.NativeWindowHandle;
            string editorClass = NativeEditInsertion.ClassName(editor);
            if (!NativeEditInsertion.Supports(editorClass)) return null;
            Native.GetWindowThreadProcessId(editor, out uint editorProcess);
            if (editorProcess != info.ProcessId || windowProcess != editorProcess) return null;
            var selection = NativeEditInsertion.Selection(editor);
            if (selection is null) return null;
            long started = process.StartTime.ToUniversalTime().Ticks;
            return new FocusTarget(window, $"{window}:{info.ProcessId}:{started}:{editor}:{selection.Value.Start}:{selection.Value.End}:{string.Join('.', id)}",
                info.ProcessId, started, editor, editorClass, selection.Value.Start, selection.Value.End);
        }
        catch (Exception error) when (error is ElementNotAvailableException or InvalidOperationException or
                                     System.Runtime.InteropServices.COMException or ArgumentException or System.ComponentModel.Win32Exception)
        {
            return null;
        }
    }
}
