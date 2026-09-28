using System;
using System.Collections.Concurrent;
using System.IO;
using System.IO.Pipes;
using System.Linq;
using System.Security.Principal;
using System.Threading;
using System.Threading.Tasks;
using OpenDictate.Core;

namespace OpenDictate.Prototype;

internal sealed record BrowserCapture(BrowserPeer Peer, string Token);

internal sealed class BrowserBridge : IDisposable
{
    internal static string PipeName => "OpenDictatePrototype-" + WindowsIdentity.GetCurrent().User!.Value;
    private readonly CancellationTokenSource lifetime = new();
    private readonly ConcurrentDictionary<BrowserPeer, byte> peers = new();

    internal BrowserBridge() => _ = AcceptAsync();

    private async Task AcceptAsync()
    {
        while (!lifetime.IsCancellationRequested)
        {
            NamedPipeServerStream? pipe = null;
            try
            {
                pipe = new NamedPipeServerStream(PipeName, PipeDirection.InOut, 4,
                    PipeTransmissionMode.Byte, PipeOptions.Asynchronous | PipeOptions.CurrentUserOnly);
                await pipe.WaitForConnectionAsync(lifetime.Token).ConfigureAwait(false);
                var peer = new BrowserPeer(pipe, lifetime.Token);
                peers.TryAdd(peer, 0);
                pipe = null;
                _ = ObserveAsync(peer);
            }
            catch (Exception error) when (error is IOException or OperationCanceledException or UnauthorizedAccessException)
            {
                pipe?.Dispose();
                if (!lifetime.IsCancellationRequested)
                    try { await Task.Delay(1000, lifetime.Token).ConfigureAwait(false); } catch (OperationCanceledException) { }
            }
        }
    }

    private async Task ObserveAsync(BrowserPeer peer)
    {
        try { await peer.ReadLoopAsync().ConfigureAwait(false); }
        finally { peers.TryRemove(peer, out _); peer.Dispose(); }
    }

    internal async Task<BrowserCapture?> CaptureAsync()
    {
        var active = peers.Keys.Where(peer => peer.Ready).ToArray();
        if (active.Length == 0) return null;
        var results = await Task.WhenAll(active.Select(async peer =>
        {
            var reply = await peer.RequestAsync("capture").ConfigureAwait(false);
            return reply.Ok == true && Guid.TryParse(reply.Token, out _) && reply.Kind is "plain" or "rich"
                ? new BrowserCapture(peer, reply.Token!) : null;
        })).ConfigureAwait(false);
        var matches = results.Where(result => result is not null).Cast<BrowserCapture>().ToArray();
        if (matches.Length == 1) return matches[0];
        foreach (var match in matches) await CancelAsync(match).ConfigureAwait(false);
        return null;
    }

    internal async Task<DeliveryResult> InsertAsync(BrowserCapture capture, string text)
    {
        var reply = await capture.Peer.RequestAsync("insert", capture.Token, text).ConfigureAwait(false);
        if (reply.Ok == true) return DeliveryResult.Completed;
        return reply.Reason is "transport_failed" or "delivery_uncertain"
            ? DeliveryResult.Uncertain : DeliveryResult.Rejected;
    }

    internal async Task CancelAsync(BrowserCapture capture) =>
        _ = await capture.Peer.RequestAsync("cancel", capture.Token).ConfigureAwait(false);

    public void Dispose()
    {
        lifetime.Cancel();
        foreach (var peer in peers.Keys) peer.Dispose();
    }
}

internal sealed class BrowserPeer : IDisposable
{
    private readonly NamedPipeServerStream pipe;
    private readonly CancellationToken lifetime;
    private readonly SemaphoreSlim writing = new(1, 1);
    private readonly ConcurrentDictionary<string, TaskCompletionSource<BridgeMessage>> pending = new();
    private int ready;
    private int disposed;
    internal bool Ready => Volatile.Read(ref ready) == 1 && Volatile.Read(ref disposed) == 0;

    internal BrowserPeer(NamedPipeServerStream pipe, CancellationToken lifetime)
    { this.pipe = pipe; this.lifetime = lifetime; }

    internal async Task ReadLoopAsync()
    {
        try
        {
            using var handshake = CancellationTokenSource.CreateLinkedTokenSource(lifetime);
            handshake.CancelAfter(TimeSpan.FromSeconds(3));
            var hello = await BridgeFrame.ReadAsync(pipe, handshake.Token).ConfigureAwait(false);
            if (hello?.Type != "hello" || hello.Kind != "browser") return;
            Volatile.Write(ref ready, 1);
            while (!lifetime.IsCancellationRequested)
            {
                var reply = await BridgeFrame.ReadAsync(pipe, lifetime).ConfigureAwait(false);
                if (reply is null) return;
                // Peers can reply to outstanding requests, never start recording
                // or initiate insertion. Unsolicited/late replies are discarded.
                if (reply.Type == "response" && reply.Id is not null && pending.TryRemove(reply.Id, out var completion))
                    completion.TrySetResult(reply);
            }
        }
        catch (Exception error) when (error is IOException or OperationCanceledException or
            System.Text.Json.JsonException or ObjectDisposedException) { }
        finally { Dispose(); }
    }

    internal async Task<BridgeMessage> RequestAsync(string type, string? token = null, string? text = null)
    {
        string id = Guid.NewGuid().ToString("N");
        if (!Ready) return new("response", id, Ok: false, Reason: "transport_failed");
        var completion = new TaskCompletionSource<BridgeMessage>(TaskCreationOptions.RunContinuationsAsynchronously);
        pending[id] = completion;
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(lifetime);
        timeout.CancelAfter(TimeSpan.FromSeconds(3));
        try
        {
            await writing.WaitAsync(timeout.Token).ConfigureAwait(false);
            try { await BridgeFrame.WriteAsync(pipe, new(type, id, token, text), timeout.Token).ConfigureAwait(false); }
            finally { writing.Release(); }
            return await completion.Task.WaitAsync(timeout.Token).ConfigureAwait(false);
        }
        catch (Exception error) when (error is IOException or OperationCanceledException or ObjectDisposedException)
        { return new("response", id, Ok: false, Reason: "transport_failed"); }
        finally { pending.TryRemove(id, out _); }
    }

    public void Dispose()
    {
        if (Interlocked.Exchange(ref disposed, 1) != 0) return;
        pipe.Dispose();
        foreach (var pair in pending)
            pair.Value.TrySetResult(new("response", pair.Key, Ok: false, Reason: "transport_failed"));
        pending.Clear();
    }
}
