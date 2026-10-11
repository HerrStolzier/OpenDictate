using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Threading;
using OpenDictate.Core;
using OpenDictate.Provider;
using OpenDictate.Windows;
using TriggerAction = OpenDictate.Core.TriggerAction;

namespace OpenDictate.App;

// Wires the shortcut, the microphone, the protected recovery copy, the
// provider and the paste into one dictation at a time. Everything here runs
// on the UI thread; the hook thread only posts key events to it.
internal sealed class DictationController : IDisposable
{
    private static readonly string LocalRoot = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "OpenDictate");
    internal static readonly string RecordingRoot = Path.Combine(LocalRoot, "Recordings");
    private static readonly string RecoveryRoot = Path.Combine(LocalRoot, "Recovery");
    // Shorter audio holds no dictation; it is kept, never uploaded.
    private const int MinimumAudioBytes = PcmJournal.SampleRate * 2 / 2;

    private readonly Dispatcher dispatcher;
    private readonly DictationFlow flow = new();
    private readonly TriggerControl trigger = new();
    private readonly IndicatorWindow indicator = new();
    private readonly DispatcherTimer clock = new() { Interval = TimeSpan.FromMilliseconds(200) };
    private readonly Stopwatch elapsed = new();
    private readonly CancellationTokenSource shutdown = new();
    private readonly KeyboardHook hook;
    private ShortcutGesture gesture;
    private AudioSession? audio;
    private Task operation = Task.CompletedTask;
    private Guid? retryable;
    private bool closing;

    internal DictationController(Dispatcher dispatcher, ShortcutKey key)
    {
        this.dispatcher = dispatcher;
        gesture = NewGesture(key);
        indicator.RetryRequested += () => { if (retryable is { } id) Retry(id); };
        clock.Tick += (_, _) =>
        {
            if (audio is { } current) indicator.UpdateLine(IndicatorText.Detail(IndicatorPhase.Listening, elapsed.Elapsed), current.Peak);
        };
        hook = new KeyboardHook((virtualKey, down, time) =>
            dispatcher.BeginInvoke(DispatcherPriority.Input, () => OnKey(virtualKey, down, time)));
    }

    internal Task<bool> ShortcutReady => hook.Ready;
    internal string? LastText { get; private set; }
    internal bool IsRecording => audio is not null;
    internal bool IsBusy => flow.IsBusy;
    // Set while the settings window is in front: gestures only show there,
    // unless a recording is running.
    internal Action<ShortcutGestureKind>? GestureTest { get; set; }
    internal event Action? StateChanged;
    internal event Action? SettingsNeeded;

    internal static RecoveryStore OpenRecovery() => new(RecoveryRoot);

    private static ShortcutGesture NewGesture(ShortcutKey key) => new(key, Native.IsDown);

    // Called only after the new choice was saved, so a failed save keeps the
    // working shortcut and the stored preference together.
    internal void UseShortcut(ShortcutKey key)
    {
        if (gesture.Key == key) return;
        gesture = NewGesture(key);
        trigger.Reset();
    }

    private void OnKey(int virtualKey, bool down, long time)
    {
        if (closing) return;
        Apply(gesture, down ? gesture.KeyDown(virtualKey, time) : gesture.KeyUp(virtualKey, time));
    }

    private void Apply(ShortcutGesture owner, ShortcutStep step)
    {
        if (!ReferenceEquals(owner, gesture) || closing) return;
        if (step.MaskStartMenu) Native.MaskStartMenu();
        if (step.HoldDeadline is { } id)
        {
            var timer = new DispatcherTimer(DispatcherPriority.Input, dispatcher) { Interval = ShortcutGesture.HoldThreshold };
            timer.Tick += (_, _) => { timer.Stop(); Apply(owner, owner.HoldDeadlineReached(id)); };
            timer.Start();
        }
        if (step.Gesture is not { } kind) return;
        // A running recording keeps its stop and cancel gestures.
        if (GestureTest is { } test && !IsRecording) { test(kind); return; }
        switch (trigger.Handle(kind, IsRecording, IsBusy))
        {
            case TriggerAction.Start: Start(Native.ForegroundTarget()); break;
            case TriggerAction.Stop: audio?.Stop(); break;
            case TriggerAction.CancelKeepingAudio: flow.Cancel(); break;
        }
    }

    // From the tray menu: the front window is the taskbar, so the text only
    // goes to the clipboard.
    internal void ToggleFromMenu()
    {
        if (IsRecording) audio?.Stop();
        else if (!IsBusy) Start(null);
    }

    private (DictationSettings Settings, ProviderServer Server, string? Key)? Prepare()
    {
        DictationSettings settings;
        ProviderServer server;
        try
        {
            settings = SettingsFile.Load(SettingsFile.DefaultPath);
            server = settings.ResolveServer();
            DictationSettings.ValidateModelFor(settings.Model, server);
        }
        catch (UserFacingException error) { Oops(error.Message); return null; }
        string? key = null;
        // A server on this computer gets no key and needs none.
        if (server.SendsApiKey)
        {
            try { key = new CredentialStore().Read(); }
            catch (Exception) { Oops(UiText.T("Die Windows-Anmeldeinformationsverwaltung ist nicht erreichbar.", "Windows Credential Manager is not available.")); return null; }
            if (string.IsNullOrWhiteSpace(key))
            {
                Oops(UiText.T("Noch kein API-Schlüssel. Bitte in den Einstellungen eintragen.", "No API key yet. Please add it in the settings."));
                SettingsNeeded?.Invoke();
                return null;
            }
        }
        return (settings, server, key);
    }

    private void Start(WindowTarget? target)
    {
        if (closing || IsBusy || Prepare() is not { } prepared) return;
        RecoveryStore store;
        try { store = OpenRecovery(); }
        catch (Exception) { Oops(UiText.T("Die geschützte Ablage ist nicht verfügbar. Es wurde nichts aufgenommen.", "Protected storage is not available. Nothing was recorded.")); return; }
        indicator.Anchor = target?.Window ?? 0;
        operation = RunAsync(prepared.Settings, prepared.Server, prepared.Key, store, target);
    }

    private async Task RunAsync(DictationSettings settings, ProviderServer server, string? key, RecoveryStore store, WindowTarget? target)
    {
        Guid? saved = null;
        var clipboard = ClipboardPaste.Result.ClipboardOnly;
        bool tooShort = false;
        retryable = null;
        var result = await flow.RunAsync(async token =>
        {
            // Runs synchronously up to the first await, so the microphone is
            // on before the gesture that started it returns.
            AudioSession? current = null;
            try { current = new AudioSession(RecordingRoot); current.Start(); }
            catch (Exception)
            {
                if (current is not null) RemoveSilentJournal(current.Journal);
                throw new UserFacingException(MicrophoneMessage);
            }
            audio = current;
            elapsed.Restart(); clock.Start();
            indicator.Show(IndicatorPhase.Listening, IndicatorText.Detail(IndicatorPhase.Listening));
            StateChanged?.Invoke();
            try
            {
                using (token.Register(current.Stop)) await current.Completion;
            }
            // Released before the first samples arrived: nothing was recorded.
            catch (Exception) when (current.Journal.BytesWritten == 0)
            {
                RemoveSilentJournal(current.Journal);
                token.ThrowIfCancellationRequested();
                tooShort = true;
                throw new UserFacingException(TooShortMessage);
            }
            catch (Exception)
            {
                throw new UserFacingException(UiText.T(
                    "Die Aufnahme wurde unterbrochen. Was aufgenommen wurde, liegt im Aufnahmeordner.",
                    "The recording was interrupted. What was recorded is in the recordings folder."));
            }
            finally { audio = null; clock.Stop(); elapsed.Stop(); StateChanged?.Invoke(); }
            if (!token.IsCancellationRequested)
                indicator.Show(IndicatorPhase.Writing, IndicatorText.Detail(IndicatorPhase.Writing, translating: settings.TargetLanguage is not null));
            RecoveredRecording recording;
            // A cancelled dictation is sealed too: cancelling keeps the audio.
            try { recording = await Task.Run(() => ProtectedJournal.Seal(current.Journal, store)); }
            catch (Exception)
            {
                throw new UserFacingException(UiText.T(
                    "Die Aufnahme konnte nicht geschützt gesichert werden. Das Original liegt im Aufnahmeordner.",
                    "The recording could not be saved in protected form. The original is in the recordings folder."));
            }
            saved = recording.Entry.Id;
            RemoveEmptyJournal(current.Journal);
            token.ThrowIfCancellationRequested();
            // Kept for 24 hours like every recording, but never sent; a
            // resend refuses it as well.
            if (recording.Wave.Length - 44 < MinimumAudioBytes) { tooShort = true; throw new UserFacingException(TooShortMessage); }
            return recording.Wave;
        }, (wave, token) => TranscribeAsync(server, wave, key, settings, token), async (text, _) =>
        {
            LastText = text;
            clipboard = await ClipboardPaste.DeliverAsync(text, target, settings.AutoInsert);
            return clipboard switch
            {
                ClipboardPaste.Result.Pasted => TextDelivery.Completed,
                ClipboardPaste.Result.PasteUncertain => TextDelivery.Uncertain,
                _ => TextDelivery.Rejected,
            };
        }, shutdown.Token);
        Finish(result, saved, clipboard, canResend: !tooShort);
    }

    private static async Task<string> TranscribeAsync(ProviderServer server, ReadOnlyMemory<byte> wave, string? key, DictationSettings settings, CancellationToken token)
    {
        using var provider = new ProviderSession(server);
        return await provider.ProcessAsync(wave, key, settings, token);
    }

    private void Finish(DictationResult result, Guid? saved, ClipboardPaste.Result clipboard, bool canResend = true)
    {
        StateChanged?.Invoke();
        if (closing) return;
        if (result.Outcome == DictationOutcome.ManualDelivery && clipboard == ClipboardPaste.Result.ClipboardUnavailable)
        {
            Oops(UiText.T("Die Zwischenablage war belegt. Der Text liegt unter „Letzten Text kopieren“ im Symbol.",
                "The clipboard was busy. The text is under “Copy last text” in the tray icon."));
            return;
        }
        var ending = IndicatorText.Ending(result, saved is not null);
        if (ending is not { } shown) { indicator.Show(IndicatorPhase.Closed, ""); return; }
        // A failure keeps its recording one click away from a resend.
        retryable = canResend && shown.Phase == IndicatorPhase.Oops && result.Outcome is DictationOutcome.Failed or DictationOutcome.EmptyResponse ? saved : null;
        indicator.Show(shown.Phase, shown.Phase == IndicatorPhase.Oops ? shown.Reason : IndicatorText.Detail(shown.Phase), retryable is not null);
    }

    // After a resend confirmation: the stored recording goes out once more,
    // and the text only reaches the clipboard, never an automatic paste.
    internal void Retry(Guid id)
    {
        if (closing || IsBusy) return;
        string where = SettingsTarget();
        var answer = MessageBox.Show(
            UiText.T($"Diese Aufnahme nochmal an {where} senden? Bei OpenAI kostet das erneut.",
                $"Send this recording to {where} again? With OpenAI this costs again."),
            "OpenDictate", MessageBoxButton.YesNo, MessageBoxImage.Question, MessageBoxResult.No);
        if (answer != MessageBoxResult.Yes || IsBusy || Prepare() is not { } prepared) return;
        indicator.Anchor = 0;
        operation = RetryAsync(id, prepared.Settings, prepared.Server, prepared.Key);
    }

    private async Task RetryAsync(Guid id, DictationSettings settings, ProviderServer server, string? key)
    {
        var clipboard = ClipboardPaste.Result.ClipboardOnly;
        bool readable = false, tooShort = false;
        retryable = null;
        var result = await flow.RunAsync(async token =>
        {
            indicator.Show(IndicatorPhase.Writing, IndicatorText.Detail(IndicatorPhase.Writing, translating: settings.TargetLanguage is not null));
            StateChanged?.Invoke();
            try
            {
                byte[] wave = (await Task.Run(() => OpenRecovery().Read(id), token)).Wave;
                readable = true;
                if (wave.Length - 44 < MinimumAudioBytes) { tooShort = true; throw new UserFacingException(TooShortMessage); }
                return wave;
            }
            catch (UserFacingException) { throw; }
            catch (Exception error) when (error is not OperationCanceledException)
            { throw new UserFacingException(UiText.T("Diese Aufnahme ist abgelaufen oder nicht mehr lesbar.", "This recording has expired or can no longer be read.")); }
        }, (wave, token) => TranscribeAsync(server, wave, key, settings, token), async (text, _) =>
        {
            LastText = text;
            clipboard = await ClipboardPaste.DeliverAsync(text, null, autoInsert: false);
            return TextDelivery.Rejected;
        }, shutdown.Token);
        Finish(result, readable ? id : null, clipboard, canResend: !tooShort);
    }

    private static string SettingsTarget()
    {
        try
        {
            var server = SettingsFile.Load(SettingsFile.DefaultPath).ResolveServer();
            return server.IsCustom ? UiText.T($"den eigenen Server ({server.Host})", $"your server ({server.Host})") : "OpenAI";
        }
        catch (UserFacingException) { return "OpenAI"; }
    }

    // Sealing removed the journal's audio; its format note and folder are
    // all that is left of this operation's own journal.
    private static void RemoveEmptyJournal(PcmJournal journal)
    {
        try
        {
            File.Delete(Path.Combine(journal.DirectoryPath, "format.txt"));
            Directory.Delete(journal.DirectoryPath, recursive: false);
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException) { }
    }

    // A journal of this operation that never received a sample holds no
    // audio: an empty audio.pcm next to its format note.
    private static void RemoveSilentJournal(PcmJournal journal)
    {
        try
        {
            journal.Close();
            if (journal.BytesWritten != 0 || File.Exists(journal.WavePath) || new FileInfo(journal.RawPath).Length != 0) return;
            File.Delete(journal.RawPath);
            RemoveEmptyJournal(journal);
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException) { }
    }

    private static string TooShortMessage => UiText.T("Zu kurz. Halte das Kürzel, solange du sprichst.", "Too short. Hold the shortcut while you speak.");

    private static string MicrophoneMessage => UiText.T(
        "Kein Mikrofon verfügbar. Unter Einstellungen > Datenschutz > Mikrofon den Zugriff für Desktop-Apps erlauben und das Mikrofon prüfen.",
        "No microphone available. Allow desktop apps under Settings > Privacy > Microphone and check the microphone.");

    internal void Oops(string reason)
    {
        if (closing) return;
        retryable = null;
        indicator.Show(IndicatorPhase.Oops, reason);
    }

    internal async Task ShutdownAsync()
    {
        if (closing) return;
        closing = true;
        flow.Cancel();
        audio?.Stop();
        shutdown.Cancel();
        try { await operation; } catch (Exception) { /* The recording stays on disk. */ }
        clock.Stop();
        indicator.Close();
    }

    public void Dispose()
    {
        hook.Dispose();
        shutdown.Dispose();
    }
}
