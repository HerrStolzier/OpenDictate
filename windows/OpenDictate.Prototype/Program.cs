using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Windows;

namespace OpenDictate.Prototype;

internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        using var instance = new Mutex(true, "Local\\OpenDictateWindowsPrototype", out bool first);
        if (!first) return 2;
        if (Process.GetCurrentProcess().SessionId == 0)
        {
            // An SSH build session is not the user's interactive desktop.
            return 3;
        }
        var app = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        app.Run(new PrototypeWindow());
        return 0;
    }
}
