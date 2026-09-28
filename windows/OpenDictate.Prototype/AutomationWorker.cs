using System;
using System.Collections.Concurrent;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;

namespace OpenDictate.Prototype;

// UIA queries share one long-lived COM MTA. No UIA object crosses apartments,
// and the worker owns no windows. WinEvent hooks observe focus separately.
internal sealed class AutomationWorker : IDisposable
{
    private readonly BlockingCollection<Action> work = new();
    private readonly TaskCompletionSource ready = new(TaskCreationOptions.RunContinuationsAsynchronously);
    internal Task Ready => ready.Task;

    internal AutomationWorker()
    {
        var thread = new Thread(Run) { IsBackground = true, Name = "OpenDictate UI Automation" };
        thread.SetApartmentState(ApartmentState.MTA);
        thread.Start();
    }

    private void Run()
    {
        int initialized = CoInitializeEx(0, 0);
        try
        {
            Marshal.ThrowExceptionForHR(initialized);
            ready.TrySetResult();
            foreach (var action in work.GetConsumingEnumerable()) action();
        }
        catch (Exception error) { ready.TrySetException(error); }
        finally
        {
            if (initialized >= 0) CoUninitialize();
        }
    }

    internal Task<FocusTarget?> CaptureAsync()
    {
        var completion = new TaskCompletionSource<FocusTarget?>(TaskCreationOptions.RunContinuationsAsynchronously);
        work.Add(() =>
        {
            try { completion.TrySetResult(FocusProbe.Capture()); }
            catch (Exception error) { completion.TrySetException(error); }
        });
        return completion.Task;
    }

    public void Dispose() => work.CompleteAdding();
    [DllImport("ole32.dll")] private static extern int CoInitializeEx(nint reserved, uint mode);
    [DllImport("ole32.dll")] private static extern void CoUninitialize();
}
