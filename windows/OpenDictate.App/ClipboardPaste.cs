using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows;
using OpenDictate.Core;

namespace OpenDictate.App;

// Delivery for every program, games included: the transcript goes to the
// clipboard, and Ctrl+V follows only under PastePolicy. The text stays on the
// clipboard either way, so it can always be pasted by hand.
internal static class ClipboardPaste
{
    private static readonly TimeSpan ModifierWait = TimeSpan.FromSeconds(1.5);

    internal enum Result { Pasted, PasteUncertain, ClipboardOnly, ClipboardUnavailable }

    // Runs on the UI thread, which owns the clipboard (STA).
    internal static async Task<Result> DeliverAsync(string text, WindowTarget? captured, bool autoInsert)
    {
        if (!await RetryAsync(() => { Clipboard.SetDataObject(text, copy: true); return true; })) return Result.ClipboardUnavailable;
        if (!autoInsert || captured is null) return Result.ClipboardOnly;
        // The shortcut may still be held after a tap; Ctrl+V must not merge
        // with it into another shortcut.
        var waited = Stopwatch.StartNew();
        while (!Native.ModifiersReleased() && waited.Elapsed < ModifierWait) await Task.Delay(20);
        string? clipboard = await ReadAsync();
        if (!PastePolicy.MayPaste(autoInsert, captured, Native.ForegroundTarget(), clipboard, text,
                Native.ModifiersReleased(), Environment.ProcessId)) return Result.ClipboardOnly;
        int sent = Native.SendPaste();
        return sent == 4 ? Result.Pasted : sent == 0 ? Result.ClipboardOnly : Result.PasteUncertain;
    }

    internal static async Task<bool> CopyAsync(string text) =>
        await RetryAsync(() => { Clipboard.SetDataObject(text, copy: true); return true; });

    private static async Task<string?> ReadAsync()
    {
        string? text = null;
        return await RetryAsync(() => { text = Clipboard.ContainsText() ? Clipboard.GetText() : null; return true; }) ? text : null;
    }

    // Another program can hold the clipboard open for a moment.
    private static async Task<bool> RetryAsync(Func<bool> action)
    {
        for (int attempt = 0; attempt < 10; attempt++)
        {
            try { return action(); }
            catch (ExternalException) { await Task.Delay(30); }
        }
        return false;
    }
}
