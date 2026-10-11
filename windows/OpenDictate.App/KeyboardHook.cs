using System;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;

namespace OpenDictate.App;

// System-wide low-level keyboard hook on its own thread, so a busy window
// never delays typing (Windows drops hooks that answer too slowly). It only
// observes: every key is passed on unchanged. Injected keys, including the
// app's own Ctrl+V and mask key, are not reported.
internal sealed class KeyboardHook : IDisposable
{
    private readonly Action<int, bool, long> report;
    private readonly TaskCompletionSource<bool> ready = new(TaskCreationOptions.RunContinuationsAsynchronously);
    private readonly Native.HookProcedure procedure;
    private readonly Thread thread;
    private uint threadId;
    private nint hook;

    // report: virtual key, true for down, Environment.TickCount64. Called on
    // the hook thread; it must return at once.
    internal KeyboardHook(Action<int, bool, long> report)
    {
        this.report = report;
        procedure = Callback;
        thread = new Thread(Run) { IsBackground = true, Name = "OpenDictate keyboard hook" };
        thread.Start();
    }

    // True once the hook is installed; false if Windows refused it.
    internal Task<bool> Ready => ready.Task;

    private void Run()
    {
        threadId = Native.GetCurrentThreadId();
        // Creates this thread's message queue, so Dispose can always post Quit.
        Native.PeekMessageW(out _, 0, 0, 0, 0);
        hook = Native.SetWindowsHookExW(Native.KeyboardLowLevel, procedure, Native.GetModuleHandleW(null), 0);
        ready.TrySetResult(hook != 0);
        if (hook == 0) return;
        try { while (Native.GetMessageW(out _, 0, 0, 0) > 0) { } }
        finally { Native.UnhookWindowsHookEx(hook); }
    }

    private nint Callback(int code, nint message, nint data)
    {
        if (code >= 0)
        {
            var key = Marshal.PtrToStructure<Native.KeyboardHookData>(data);
            bool down = message is Native.KeyDown or Native.SystemKeyDown;
            bool up = message is Native.KeyUp or Native.SystemKeyUp;
            if ((key.Flags & Native.Injected) == 0 && (down || up))
                report((int)key.VirtualKey, down, Environment.TickCount64);
        }
        return Native.CallNextHookEx(hook, code, message, data);
    }

    public void Dispose()
    {
        if (Ready.IsCompletedSuccessfully && Ready.Result) Native.PostThreadMessageW(threadId, Native.Quit, 0, 0);
        thread.Join(TimeSpan.FromSeconds(1));
        GC.KeepAlive(procedure);
    }
}
