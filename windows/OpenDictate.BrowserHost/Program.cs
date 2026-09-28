using System.IO.Pipes;
using System.Security.Principal;
using OpenDictate.Core;

// Chrome passes its extension origin. The installer writes this public origin
// beside the host; no API credential is accepted or exposed through this bridge.
string originPath = Path.Combine(AppContext.BaseDirectory, "allowed-origin.txt");
if (args.Length == 0 || !File.Exists(originPath) ||
    !StringComparer.Ordinal.Equals(args[0], File.ReadAllText(originPath).Trim())) return 2;
using var lifetime = new CancellationTokenSource();
using var pipe = new NamedPipeClientStream(".", "OpenDictatePrototype-" + WindowsIdentity.GetCurrent().User!.Value,
    PipeDirection.InOut, PipeOptions.Asynchronous | PipeOptions.CurrentUserOnly);
try
{
    await pipe.ConnectAsync(2500, lifetime.Token);
    await BridgeFrame.WriteAsync(pipe, new("hello", Kind: "browser"), lifetime.Token);
    using var input = Console.OpenStandardInput();
    using var output = Console.OpenStandardOutput();
    var fromBrowser = Pump(input, pipe, lifetime.Token);
    var toBrowser = Pump(pipe, output, lifetime.Token);
    var finished = await Task.WhenAny(fromBrowser, toBrowser);
    lifetime.Cancel();
    pipe.Dispose();
    // A synchronous stdin pipe read may not honor cancellation. Do not keep
    // the host alive waiting for it after either direction has disconnected.
    return finished.IsFaulted ? 1 : 0;
}
catch (Exception error) when (error is IOException or TimeoutException or UnauthorizedAccessException or System.Text.Json.JsonException)
{ return 1; } // stdout is reserved for framed protocol data; no content logging.

static async Task Pump(Stream input, Stream output, CancellationToken token)
{
    while (true)
    {
        var message = await BridgeFrame.ReadAsync(input, token);
        if (message is null) return;
        await BridgeFrame.WriteAsync(output, message, token);
    }
}
