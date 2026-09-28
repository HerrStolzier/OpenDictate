using System;
using System.Runtime.InteropServices;

namespace OpenDictate.Prototype;

internal static class Native
{
    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool RegisterHotKey(nint window, int id, uint modifiers, uint key);
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool UnregisterHotKey(nint window, int id);
    [DllImport("user32.dll")] internal static extern nint GetForegroundWindow();
    [DllImport("user32.dll")] internal static extern short GetAsyncKeyState(int key);
    [DllImport("user32.dll")] internal static extern uint GetWindowThreadProcessId(nint window, out uint process);
    internal static bool ModifiersReleased() =>
        GetAsyncKeyState(0x10) >= 0 && GetAsyncKeyState(0x11) >= 0 &&
        GetAsyncKeyState(0x12) >= 0 && GetAsyncKeyState(0x5B) >= 0 && GetAsyncKeyState(0x5C) >= 0;

}
