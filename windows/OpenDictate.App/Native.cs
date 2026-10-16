using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using OpenDictate.Core;

namespace OpenDictate.App;

internal static class Native
{
    internal const int KeyboardLowLevel = 13;
    internal const int KeyDown = 0x0100, KeyUp = 0x0101, SystemKeyDown = 0x0104, SystemKeyUp = 0x0105;
    internal const uint Injected = 0x10;
    internal const uint Quit = 0x0012;
    private const uint InputKeyboard = 1, KeyEventUp = 0x0002, KeyEventScanCode = 0x0008, MapToScanCode = 0;
    internal const int ExStyle = -20;
    internal const long NoActivate = 0x08000000, ToolWindow = 0x00000080, Transparent = 0x00000020;
    internal const int DwmUseImmersiveDarkMode = 20, DwmBorderColor = 34, DwmCaptionColor = 35;

    [StructLayout(LayoutKind.Sequential)]
    internal struct KeyboardHookData { public uint VirtualKey, ScanCode, Flags, Time; public nuint ExtraInfo; }
    [StructLayout(LayoutKind.Sequential)]
    internal struct Message { public nint Window; public uint Id; public nint WParam, LParam; public uint Time; public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] private struct Input { public uint Type; public InputData Data; }
    // The union is as large as its mouse member; SendInput checks the size.
    [StructLayout(LayoutKind.Explicit)] private struct InputData { [FieldOffset(0)] public MouseInput Mouse; [FieldOffset(0)] public KeyboardInput Keyboard; }
    [StructLayout(LayoutKind.Sequential)] private struct MouseInput { public int X, Y; public uint Data, Flags, Time; public nuint ExtraInfo; }
    [StructLayout(LayoutKind.Sequential)] private struct KeyboardInput { public ushort VirtualKey, ScanCode; public uint Flags, Time; public nuint ExtraInfo; }

    internal delegate nint HookProcedure(int code, nint message, nint data);
    [DllImport("user32.dll", SetLastError = true)] internal static extern nint SetWindowsHookExW(int kind, HookProcedure procedure, nint module, uint thread);
    [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] internal static extern bool UnhookWindowsHookEx(nint hook);
    [DllImport("user32.dll")] internal static extern nint CallNextHookEx(nint hook, int code, nint message, nint data);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] internal static extern nint GetModuleHandleW(string? name);
    [DllImport("kernel32.dll")] internal static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] internal static extern bool PeekMessageW(out Message message, nint window, uint first, uint last, uint remove);
    [DllImport("user32.dll")] internal static extern int GetMessageW(out Message message, nint window, uint first, uint last);
    [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] internal static extern bool PostThreadMessageW(uint thread, uint message, nint wParam, nint lParam);
    [DllImport("user32.dll")] internal static extern nint GetForegroundWindow();
    [DllImport("dwmapi.dll")] internal static extern int DwmSetWindowAttribute(nint window, int attribute, ref int value, int size);
    [DllImport("user32.dll")] internal static extern short GetAsyncKeyState(int key);
    [DllImport("user32.dll")] internal static extern uint GetWindowThreadProcessId(nint window, out uint process);
    [DllImport("user32.dll", SetLastError = true)] private static extern uint SendInput(uint count, Input[] inputs, int size);
    [DllImport("user32.dll")] private static extern uint MapVirtualKeyExW(uint code, uint mapType, nint layout);
    [DllImport("user32.dll")] private static extern nint GetKeyboardLayout(uint thread);
    [DllImport("user32.dll")] internal static extern nint GetWindowLongPtrW(nint window, int index);
    [DllImport("user32.dll")] internal static extern nint SetWindowLongPtrW(nint window, int index, nint value);

    internal static bool IsDown(int key) => GetAsyncKeyState(key) < 0;

    // Shift, Ctrl, Alt and both Win keys.
    internal static bool ModifiersReleased() =>
        !IsDown(0x10) && !IsDown(0x11) && !IsDown(0x12) && !IsDown(VirtualKey.LeftWin) && !IsDown(VirtualKey.RightWin);

    internal static WindowTarget? ForegroundTarget()
    {
        nint window = GetForegroundWindow();
        if (window == 0 || GetWindowThreadProcessId(window, out uint id) == 0) return null;
        try
        {
            using var process = Process.GetProcessById((int)id);
            return new WindowTarget(window, (int)id, process.StartTime.ToUniversalTime().Ticks);
        }
        // An elevated or exited owner cannot be identified, so nothing is pasted.
        catch (Exception error) when (error is ArgumentException or InvalidOperationException or System.ComponentModel.Win32Exception)
        { return null; }
    }

    // The image name of a window's owner, without extension; null when the
    // owner cannot be read, which PastePolicy treats as an ordinary program.
    internal static string? ProcessName(int id)
    {
        try { using var process = Process.GetProcessById(id); return process.ProcessName; }
        catch (Exception error) when (error is ArgumentException or InvalidOperationException or System.ComponentModel.Win32Exception)
        { return null; }
    }

    // Down and up of the unassigned mask key; see VirtualKey.StartMenuMask.
    internal static void MaskStartMenu() =>
        Send([Key(VirtualKey.StartMenuMask, false, 0), Key(VirtualKey.StartMenuMask, true, 0)]);

    // Returns how many of the four Ctrl+V events Windows accepted. A partial
    // send still releases both keys, so no key stays held.
    internal static int SendPaste(nint window)
    {
        // Windows reads scan codes with the target window's layout, not ours.
        nint layout = GetKeyboardLayout(GetWindowThreadProcessId(window, out _));
        int sent = Send([Key(VirtualKey.LeftCtrl, false, layout), Key(VirtualKey.V, false, layout), Key(VirtualKey.V, true, layout), Key(VirtualKey.LeftCtrl, true, layout)]);
        if (sent is > 0 and < 4) Send([Key(VirtualKey.V, true, layout), Key(VirtualKey.LeftCtrl, true, layout)]);
        return sent;
    }

    // Games that read raw input or DirectInput ignore the virtual key and
    // look only at the scan code, so keys with one are sent in scan-code mode.
    // The scan code comes from the target's layout (0 = no layout, virtual-key
    // mode), so it still means Ctrl or V on QWERTZ or Dvorak. The mask key
    // has none and stays a virtual key.
    private static Input Key(int key, bool up, nint layout)
    {
        ushort scanCode = layout == 0 ? (ushort)0 : (ushort)MapVirtualKeyExW((uint)key, MapToScanCode, layout);
        uint flags = (up ? KeyEventUp : 0) | (scanCode != 0 ? KeyEventScanCode : 0);
        return new()
        {
            Type = InputKeyboard,
            Data = new InputData { Keyboard = new KeyboardInput { VirtualKey = (ushort)key, ScanCode = scanCode, Flags = flags } },
        };
    }

    private static int Send(Input[] inputs) => (int)SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<Input>());
}
