using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Threading;
using OpenDictate.Core;
using OpenDictate.Windows;
using Forms = System.Windows.Forms;

namespace OpenDictate.Prototype;

internal sealed partial class PrototypeWindow : Window
{
    internal const string Fixture = "OpenDictate-Test: Grüße aus Windows – äöü ß.";
    private readonly AttemptGate gate = new();
    private readonly DictationFlow dictation = new();
    private readonly CheckBox offlineFlow = new() { Content = "Ablauf mit lokaler Testantwort prüfen (keine Spracherkennung)" };
    private readonly TextBox resultText = new() { Text = Fixture, IsReadOnly = true, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 8, 0, 8) };
    private Task dictationOperation = Task.CompletedTask;
    private readonly TextBlock status = new() { Text = "Bereit. Keine Aufnahme läuft.", TextWrapping = TextWrapping.Wrap };
    private readonly TextBlock duration = new();
    private readonly ProgressBar meter = new() { Minimum = 0, Maximum = 1, Height = 12 };
    private readonly CheckBox allowInsertion = new() { Content = "Automatisches Einfügen erlauben" };
    private readonly Button record = new() { Content = "Aufnahme starten", Padding = new Thickness(14, 8, 14, 8) };
    private readonly Forms.NotifyIcon tray = new();
    private readonly DispatcherTimer clock = new() { Interval = TimeSpan.FromMilliseconds(100) };
    private readonly Stopwatch elapsed = new();
    private AudioSession? audio;
    private HwndSource? source;
    private nint handle;
    private long focusEpoch;
    private bool closing;
    private bool focusHookReady;
    private bool hotkeysReady;
    private bool deliveryUncertain;
    private AutomationWorker? automation;
    private readonly BrowserBridge browserBridge = new();
    private Task insertionOperation = Task.CompletedTask;
    private readonly CancellationTokenSource shutdown = new();
    private FocusEvents? focusEvents;

    internal PrototypeWindow()
    {
        Title = "OpenDictate · Windows-Prototyp";
        Width = 660; Height = 780; MinWidth = 480; MinHeight = 480;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        var panel = new StackPanel { Margin = new Thickness(28) };
        panel.Children.Add(new TextBlock { Text = "OpenDictate für Windows", FontSize = 25, FontWeight = FontWeights.SemiBold });
        AddText(panel, "Windows-Prototyp · Lokale Prüfung oder ausdrücklich aktivierte OpenAI-Transkription.");
        AddText(panel, "Strg + Umschalt + Leertaste: Aufnahme starten / stoppen\nStrg + Alt + Leertaste: Testtext nach 3 Sekunden einfügen", 16);
        panel.Children.Add(record);
        AddText(panel, "Im verbundenen Ablauf wird die Aufnahme vor der Verarbeitung verschlüsselt gesichert. Bis zu fünf gültige Kopien bleiben für 24 Stunden wiederherstellbar. Reine lokale Aufnahmen und ältere Originale bleiben im Aufnahmeordner.");
        panel.Children.Add(duration);
        panel.Children.Add(meter);
        panel.Children.Add(new Separator { Margin = new Thickness(0, 16, 0, 16) });
        panel.Children.Add(offlineFlow);
        AddIntegrationControls(panel);
        panel.Children.Add(allowInsertion);
        AddText(panel, "Im Windows-Editor direkt, auf der Browser-Testseite über die lokale Erweiterung. Bitte nur in Testfeldern verwenden; weitere Programme sind noch nicht freigegeben.");
        AddText(panel, "Im Ablauf-Test verbindet der Aufnahme-Hotkey die Aufnahme mit einer festen lokalen Antwort. Der Testtext-Hotkey prüft denselben Weg mit künstlichem Audio ohne Mikrofon. Beide Modi erkennen keine Sprache.");
        AutomationProperties.SetName(resultText, "Transkription oder lokale Testantwort");
        panel.Children.Add(resultText);
        var controls = new WrapPanel();
        var copy = new Button { Content = "Text kopieren", Margin = new Thickness(0, 0, 8, 8), Padding = new Thickness(10, 6, 10, 6) };
        copy.Click += (_, _) =>
        {
            try { Clipboard.SetText(resultText.Text); SetStatus("Text kopiert."); }
            catch (Exception) { SetStatus("Zwischenablage gerade nicht verfügbar. Der Text bleibt im Fenster."); }
        };
        controls.Children.Add(copy);
        var folder = new Button { Content = "Aufnahmeordner öffnen", Margin = new Thickness(0, 0, 8, 8), Padding = new Thickness(10, 6, 10, 6) };
        folder.Click += (_, _) =>
        {
            if (Directory.Exists(AudioSession.RecordingRoot))
                Process.Start(new ProcessStartInfo(AudioSession.RecordingRoot) { UseShellExecute = true });
            else SetStatus("Noch keine Aufnahme gespeichert.");
        };
        controls.Children.Add(folder);
        var cancel = new Button { Content = "Einfügeversuch abbrechen", Padding = new Thickness(10, 6, 10, 6), Margin = new Thickness(0, 0, 0, 8) };
        cancel.Click += (_, _) =>
        {
            if (dictation.IsBusy)
            {
                bool cancelled = dictation.Cancel();
                if (cancelled && audio is not null) StopRecording();
                SetStatus(cancelled ? "Ablauf abgebrochen. Aufnahme bleibt erhalten; laufende Verarbeitung wird beendet." : "Übergabe läuft bereits. Ergebnis im Ziel prüfen; es wird nicht erneut eingefügt.");
            }
            else if (gate.Kind == AttemptKind.Insertion)
                SetStatus(gate.Cancel() ? "Einfügeversuch abgebrochen." : "Übergabe läuft bereits. Ergebnis im Ziel prüfen; es wird nicht erneut eingefügt.");
        };
        controls.Children.Add(cancel);
        var quit = new Button { Content = "Beenden", Padding = new Thickness(10, 6, 10, 6), Margin = new Thickness(8, 0, 0, 8) };
        quit.Click += async (_, _) => await QuitAsync();
        controls.Children.Add(quit);
        panel.Children.Add(controls);
        status.Margin = new Thickness(0, 12, 0, 0);
        AutomationProperties.SetLiveSetting(status, AutomationLiveSetting.Polite);
        panel.Children.Add(status);
        Content = new ScrollViewer { Content = panel, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
        record.Click += (_, _) => ToggleRecording();
        clock.Tick += (_, _) =>
        {
            if (audio is null) return;
            duration.Text = $"Aufnahme: {elapsed.Elapsed.TotalSeconds:F0} / 90 Sekunden";
            meter.Value = audio.Peak;
            if (elapsed.Elapsed >= TimeSpan.FromSeconds(90)) StopRecording();
        };
        SourceInitialized += OnSourceInitialized;
        Closing += OnClosing;
    }

    private static void AddText(Panel panel, string text, double fontSize = 13) => panel.Children.Add(
        new TextBlock { Text = text, FontSize = fontSize, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 10, 0, 10) });

    private void OnSourceInitialized(object? sender, EventArgs args)
    {
        // NotifyIcon can install a WinForms synchronization context before WPF
        // starts its dispatcher. All app continuations belong to the WPF thread.
        SynchronizationContext.SetSynchronizationContext(new DispatcherSynchronizationContext(Dispatcher));
        handle = new WindowInteropHelper(this).Handle;
        source = HwndSource.FromHwnd(handle);
        source?.AddHook(WindowMessage);
        const uint noRepeat = 0x4000;
        bool first = Native.RegisterHotKey(handle, 1, noRepeat | 0x0002 | 0x0004, 0x20); // Ctrl+Shift+Space
        bool second = first && Native.RegisterHotKey(handle, 2, noRepeat | 0x0002 | 0x0001, 0x20); // Ctrl+Alt+Space
        hotkeysReady = second;
        if (!second)
        {
            if (first) Native.UnregisterHotKey(handle, 1);
            SetStatus("Tastenkürzel schon belegt. Globale Tests sind nicht bereit; vorhandene Belegungen wurden erhalten.");
            allowInsertion.IsEnabled = false;
        }
        automation = new AutomationWorker();
        _ = RegisterFocusHookAsync();
        tray.Icon = System.Drawing.SystemIcons.Application;
        tray.Text = "OpenDictate · Windows-Prototyp";
        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add("OpenDictate öffnen", null, (_, _) => Dispatcher.Invoke(() => { Show(); Activate(); }));
        menu.Items.Add("Beenden", null, (_, _) => Dispatcher.InvokeAsync(QuitAsync));
        tray.ContextMenuStrip = menu;
        tray.DoubleClick += (_, _) => { Show(); Activate(); };
        tray.Visible = true;
    }

    private async Task RegisterFocusHookAsync()
    {
        try
        {
            focusEvents = new FocusEvents(() => Interlocked.Increment(ref focusEpoch));
            await automation!.Ready.WaitAsync(TimeSpan.FromSeconds(8)).ConfigureAwait(false);
            await Dispatcher.InvokeAsync(() =>
            {
                if (closing) automation.Dispose();
                else
                {
                    focusHookReady = true;
                    if (hotkeysReady) SetStatus("Bereit. Tastenkürzel und Fokusüberwachung aktiv. Keine Aufnahme läuft.");
                }
            });
        }
        catch (Exception error)
        {
            await Dispatcher.InvokeAsync(() => SetStatus($"Fokusüberwachung nicht verfügbar ({error.GetType().Name}). Einfügen bleibt gesperrt."));
        }
    }

    private nint WindowMessage(nint hwnd, int message, nint wParam, nint lParam, ref bool handled)
    {
        if (message != 0x0312 || closing) return 0;
        handled = true;
        if (wParam == 1) ToggleRecording();
        if (wParam == 2 && !gate.IsBusy)
        {
            if (offlineFlow.IsChecked == true) dictationOperation = RunDictationAsync(synthetic: true);
            else insertionOperation = TryInsertionAsync();
        }
        return 0;
    }

    private void ToggleRecording()
    {
        if (audio is not null) { StopRecording(); return; }
        if (gate.IsBusy || closing) { SetStatus("Zuerst den laufenden Versuch abschließen."); return; }
        if (offlineFlow.IsChecked == true || liveFlow.IsChecked == true) { dictationOperation = RunDictationAsync(synthetic: false); return; }
        long ticket = gate.Begin(AttemptKind.Recording);
        try
        {
            audio = new AudioSession();
            audio.Start();
            elapsed.Restart(); clock.Start();
            record.Content = "Aufnahme stoppen";
            SetStatus("Mikrofonaufnahme läuft lokal. Strg + Umschalt + Leertaste stoppt sie.");
            _ = ObserveRecordingAsync(audio, ticket);
        }
        catch (Exception)
        {
            audio = null; gate.Complete(ticket);
            SetStatus("Aufnahme konnte nicht starten. Mikrofonfreigabe, Gerät und freien Speicher prüfen. Vorhandene Dateien bleiben erhalten.");
        }
    }

    private void StopRecording()
    {
        clock.Stop();
        if (audio is null) return;
        record.IsEnabled = false;
        SetStatus("Aufnahme wird abgeschlossen …");
        audio.Stop();
    }

    private async Task ObserveRecordingAsync(AudioSession current, long ticket)
    {
        try
        {
            await current.Completion;
            SetStatus("Aufnahme als WAV gespeichert; PCM-Original erhalten. Bitte im Aufnahmeordner anhören.");
        }
        catch (Exception) { SetStatus("Aufnahme/Export nicht vollständig. Bereits gespeicherte Audiodaten bleiben im Aufnahmeordner erhalten."); }
        finally
        {
            if (ReferenceEquals(audio, current)) audio = null;
            clock.Stop(); elapsed.Stop(); meter.Value = 0;
            gate.Complete(ticket);
            record.IsEnabled = true; record.Content = "Aufnahme starten";
        }
    }

    private async Task RunDictationAsync(bool synthetic, Guid? recoveryId = null)
    {
        if (gate.IsBusy || closing) return;
        bool live = !synthetic && liveFlow.IsChecked == true;
        string? key = null;
        if (live)
        {
            try { key = new CredentialStore().Read(); }
            catch (Exception) { SetStatus("Schlüsselablage nicht verfügbar. Keine Aufnahme und kein Upload gestartet."); return; }
            if (string.IsNullOrWhiteSpace(key)) { SetStatus("Bitte zuerst den API-Schlüssel direkt in der App speichern. Keine Aufnahme und kein Upload gestartet."); return; }
        }
        bool failOffline = !live && simulateFailure.IsChecked == true;
        RecoveryStore store;
        try { store = GetRecoveryStore(synthetic); }
        catch (Exception) { SetStatus("Geschützte Ablage nicht verfügbar. Keine Aufnahme und kein Upload gestartet."); return; }
        long ticket = gate.Begin(AttemptKind.Recording);
        InsertionTarget? target = null;
        focusEvents?.BeginObservation();
        long epoch = Interlocked.Read(ref focusEpoch);
        bool mayDeliver = recoveryId is null && allowInsertion.IsChecked == true && focusHookReady && !deliveryUncertain;
        SetIntegrationBusy(true);
        resultText.Clear();
        try
        {
            var result = await dictation.RunAsync(async token =>
            {
                // Capture belongs to the cancellable lease, before microphone or
                // preparation. Cancelling a slow probe cannot start audio later.
                if (recoveryId is not null)
                    return (await Task.Run(() => store.Read(recoveryId.Value), token)).Wave;
                if (mayDeliver) target = await CaptureInsertionTargetAsync();
                token.ThrowIfCancellationRequested();
                if (Interlocked.Read(ref focusEpoch) != epoch) target = null;
                if (focusEvents is not null) focusEvents.ObservedEditor = target?.Editor?.Editor ?? 0;
                if (synthetic)
                {
                    SetStatus("Künstliche Aufnahme wird vorbereitet. Das Mikrofon bleibt aus.");
                    string root = System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "OpenDictatePrototype", "SyntheticChecks");
                    AudioSession.EnsurePrivateRoot(root);
                    using var journal = new PcmJournal(root);
                    journal.Append(new byte[3200]);
                    string file = journal.ExportWave();
                    return (await Task.Run(() => ProtectedJournal.Seal(journal, store))).Wave;
                }
                var current = new AudioSession();
                audio = current;
                try
                {
                    current.Start(); elapsed.Restart(); clock.Start();
                    record.Content = "Aufnahme stoppen";
                    SetStatus(live ? "Aufnahme läuft. Nach dem Stop wird sie geschützt gesichert und einmal an OpenAI gesendet." : "Aufnahme läuft. Danach folgt eine feste lokale Testantwort ohne Upload.");
                    using var cancellation = token.Register(current.Stop);
                    string file = await current.Completion;
                    SetStatus("Aufnahme wird verschlüsselt und geprüft …");
                    return (await Task.Run(() => ProtectedJournal.Seal(current.Journal, store))).Wave;
                }
                finally
                {
                    if (ReferenceEquals(audio, current)) audio = null;
                    clock.Stop(); elapsed.Stop(); meter.Value = 0;
                    record.IsEnabled = true; record.Content = "Aufnahme starten";
                }
            }, async (bytes, token) =>
            {
                if (live)
                {
                    SetStatus("Geschützte Aufnahme wird einmal an OpenAI übertragen …");
                    using var provider = new OpenAiTranscriber();
                    return await provider.TranscribeAsync(bytes, key!, token);
                }
                SetStatus("Lokale Testantwort wird verarbeitet … Keine Verbindung zu einem Anbieter.");
                await Task.Delay(3000, token);
                if (failOffline) throw new IOException("Synthetic provider failure.");
                return Fixture;
            }, async (text, token) =>
            {
                if (target is null || !mayDeliver || closing || token.IsCancellationRequested ||
                    Interlocked.Read(ref focusEpoch) != epoch) return TextDelivery.Rejected;
                string? identity = target.Editor is not null
                    ? (await automation!.CaptureAsync().WaitAsync(TimeSpan.FromSeconds(2)))?.Identity
                    : BrowserWindowStillMatches(target) ? target.Identity : null;
                if (closing || token.IsCancellationRequested || Interlocked.Read(ref focusEpoch) != epoch ||
                    identity != target.Identity || !Native.ModifiersReleased() || Native.GetForegroundWindow() != target.Window)
                    return TextDelivery.Rejected;
                var delivered = target.Editor is not null
                    ? NativeEditInsertion.Replace(target.Editor, text)
                    : await browserBridge.InsertAsync(target.Browser!, text);
                return delivered switch { DeliveryResult.Completed => TextDelivery.Completed,
                    DeliveryResult.Rejected => TextDelivery.Rejected, _ => TextDelivery.Uncertain };
            }, shutdown.Token);
            if (result.Text is not null) resultText.Text = result.Text;
            if (result.Outcome == DictationOutcome.DeliveryUncertain)
            {
                deliveryUncertain = true; allowInsertion.IsChecked = false; allowInsertion.IsEnabled = false;
            }
            SetStatus(result.Outcome switch
            {
                DictationOutcome.Delivered => live ? "Transkription eingefügt. Geschützte Aufnahme bleibt befristet verfügbar." : "Ablauf-Test erfolgreich: Lokale Testantwort eingefügt. Keine Spracherkennung; Aufnahme geschützt erhalten.",
                DictationOutcome.ManualDelivery => "Text bereit, automatische Übergabe unterdrückt. Text bleibt zum Kopieren verfügbar; Aufnahme geschützt erhalten.",
                DictationOutcome.Cancelled => "Ablauf abgebrochen. Aufnahme erhalten; kein verspäteter Text wird eingefügt.",
                DictationOutcome.EmptyResponse => "Leere Antwort. Aufnahme bleibt erhalten; es wurde nichts eingefügt.",
                DictationOutcome.DeliveryUncertain => "Übergabe nicht bestätigt. Kein automatischer Neuversuch; Text und Aufnahme erhalten. Vor einem neuen Versuch Ziel prüfen und App neu starten.",
                _ => "Ablauf fehlgeschlagen. Bereits gespeicherte Aufnahme bleibt erhalten; kein automatischer Neuversuch."
            });
        }
        catch (Exception) { SetStatus("Ablauf konnte nicht abgeschlossen werden. Vorhandene Aufnahmen bleiben erhalten."); }
        finally
        {
            if (target?.Browser is not null) await browserBridge.CancelAsync(target.Browser);
            gate.Complete(ticket); key = null; SetIntegrationBusy(false); await RefreshRecoveryAsync();
        }
    }

    private async Task TryInsertionAsync()
    {
        if (gate.IsBusy || closing || deliveryUncertain) return;
        if (allowInsertion.IsChecked != true)
        { SetStatus("Einfügeversuch zuerst im OpenDictate-Fenster erlauben; danach ein Testfeld im Windows-Editor wählen."); return; }
        if (!focusHookReady)
        { SetStatus("Die Fokusüberwachung ist noch nicht bereit. Einfügen bleibt gesperrt."); return; }
        // Reserve before awaiting a provider; a second hotkey must not overlap.
        long ticket = gate.Begin(AttemptKind.Insertion);
        InsertionTarget? target = null;
        try
        {
            focusEvents?.BeginObservation();
            long epoch = Interlocked.Read(ref focusEpoch);
            target = await CaptureInsertionTargetAsync();
            if (focusEvents is not null) focusEvents.ObservedEditor = target?.Editor?.Editor ?? 0;
            if (!gate.Complete(ticket)) return;
            if (target is null || Interlocked.Read(ref focusEpoch) != epoch)
            { SetStatus("Kein unterstütztes, eindeutig erkanntes Editorfeld. Testtext bleibt manuell verfügbar."); return; }
            ticket = gate.Begin(AttemptKind.Insertion, target.Identity);
            SetStatus("Einfügeversuch in 3 Sekunden. Feld nicht wechseln; Zusatztasten loslassen.");
            await Task.Delay(3000, shutdown.Token);
            string? currentIdentity = target.Editor is not null
                ? (await automation!.CaptureAsync().WaitAsync(TimeSpan.FromSeconds(2)))?.Identity
                : BrowserWindowStillMatches(target) ? target.Identity : null;
            if (Interlocked.Read(ref focusEpoch) != epoch) gate.ObserveFocus(null);
            if (closing || !gate.CanInsert(ticket, currentIdentity, Native.ModifiersReleased()) ||
                Native.GetForegroundWindow() != target.Window)
            { SetStatus("Einfügen unterdrückt: Fokus, Vorgang oder Tastenstatus hat sich geändert."); return; }
            // Consume delivery once, while keeping other operations excluded until
            // the synchronous edit or asynchronous browser reply has completed.
            if (!gate.BeginDelivery(ticket)) return;
            var delivery = target.Editor is not null
                ? NativeEditInsertion.Replace(target.Editor, Fixture)
                : await browserBridge.InsertAsync(target.Browser!, Fixture);
            if (delivery == DeliveryResult.Uncertain)
            {
                deliveryUncertain = true;
                allowInsertion.IsChecked = false;
                allowInsertion.IsEnabled = false;
            }
            SetStatus(delivery switch
            {
                DeliveryResult.Completed => "Testtext direkt an das Textfeld übergeben. Mit Strg + Z im Ziel rückgängig machen.",
                DeliveryResult.Rejected => "Einfügen unterdrückt: Das ursprüngliche Textfeld ist nicht mehr bereit.",
                _ => "Übergabe nicht bestätigt. Nicht automatisch wiederholt; Testtext bleibt erhalten. Vor einem neuen Versuch Ziel prüfen und App neu starten."
            });
        }
        catch (Exception) { SetStatus("Zielprüfung nicht rechtzeitig oder eindeutig möglich. Es wird nichts eingefügt."); }
        finally
        {
            gate.Complete(ticket);
            if (target?.Browser is not null) await browserBridge.CancelAsync(target.Browser);
        }
    }

    private async Task<InsertionTarget?> CaptureInsertionTargetAsync()
    {
        nint window = Native.GetForegroundWindow();
        Native.GetWindowThreadProcessId(window, out uint pid);
        using var process = Process.GetProcessById((int)pid);
        if (process.ProcessName.Equals("chrome", StringComparison.OrdinalIgnoreCase) ||
            process.ProcessName.Equals("msedge", StringComparison.OrdinalIgnoreCase))
        {
            long started = process.StartTime.ToUniversalTime().Ticks;
            var capture = await browserBridge.CaptureAsync();
            if (capture is null) return null;
            return new InsertionTarget(window, $"browser:{window}:{pid}:{started}:{capture.Token}",
                (int)pid, started, null, capture);
        }
        var editor = await automation!.CaptureAsync().WaitAsync(TimeSpan.FromSeconds(2));
        return editor is null ? null : new InsertionTarget(editor.Window, editor.Identity,
            editor.ProcessId, editor.ProcessStartTicks, editor, null);
    }

    private static bool BrowserWindowStillMatches(InsertionTarget target)
    {
        if (Native.GetForegroundWindow() != target.Window) return false;
        Native.GetWindowThreadProcessId(target.Window, out uint pid);
        if (pid != target.ProcessId) return false;
        try
        {
            using var process = Process.GetProcessById(target.ProcessId);
            return process.StartTime.ToUniversalTime().Ticks == target.ProcessStartTicks;
        }
        catch (Exception) { return false; }
    }

    private sealed record InsertionTarget(nint Window, string Identity, int ProcessId,
        long ProcessStartTicks, FocusTarget? Editor, BrowserCapture? Browser);

    private void SetStatus(string text)
    {
        status.Text = text;
        tray.Text = audio is null ? "OpenDictate · Windows-Prototyp" : "OpenDictate · Aufnahme läuft";
    }

    private void OnClosing(object? sender, CancelEventArgs args)
    {
        if (closing) return;
        args.Cancel = true; Hide();
    }

    private async Task QuitAsync()
    {
        if (closing) return;
        closing = true; dictation.Cancel(); gate.Cancel(); shutdown.Cancel();
        try { await insertionOperation; await dictationOperation; } catch (Exception) { }
        if (audio is not null)
        {
            var pending = audio.Completion;
            StopRecording();
            try { await pending; } catch (Exception) { /* Original remains on disk. */ }
        }
        clock.Stop();
        Native.UnregisterHotKey(handle, 1); Native.UnregisterHotKey(handle, 2);
        source?.RemoveHook(WindowMessage);
        automation?.Dispose();
        focusEvents?.Dispose();
        browserBridge.Dispose();
        shutdown.Dispose();
        tray.Visible = false; tray.Dispose();
        System.Windows.Application.Current.Shutdown();
    }
}
