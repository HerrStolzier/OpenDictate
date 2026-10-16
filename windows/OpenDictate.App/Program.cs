using System;
using System.Diagnostics;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Threading;
using OpenDictate.Core;
using OpenDictate.Provider;
using Forms = System.Windows.Forms;

namespace OpenDictate.App;

internal static class Program
{
    private const string InstanceName = "Local\\OpenDictate";
    private const string ShowSignal = "Local\\OpenDictate.ShowSettings";

    [STAThread]
    private static int Main()
    {
        // An SSH or service session is not the user's desktop.
        if (Process.GetCurrentProcess().SessionId == 0) return 3;
        using var instance = new Mutex(true, InstanceName, out bool first);
        using var show = new EventWaitHandle(false, EventResetMode.AutoReset, ShowSignal);
        if (!first)
        {
            // A second start opens the settings of the running app.
            show.Set();
            return 0;
        }
        var app = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        var tray = new TrayApp(app.Dispatcher);
        var wait = ThreadPool.RegisterWaitForSingleObject(show, (_, _) => app.Dispatcher.BeginInvoke(tray.OpenSettings), null, Timeout.Infinite, false);
        app.Startup += (_, _) => tray.Start();
        // An unexpected error in a key event or a finished dictation must not
        // end the app; it shows in the indicator, saved recordings stay.
        // Before the tray icon is up, an error ends the app instead of leaving
        // it running invisibly.
        app.DispatcherUnhandledException += (_, args) => { args.Handled = tray.Started; if (tray.Started) tray.Report(); };
        app.Run();
        wait.Unregister(null);
        return 0;
    }
}

// The app lives in the notification area: no main window, no taskbar button.
internal sealed class TrayApp
{
    private readonly Dispatcher dispatcher;
    private readonly Forms.NotifyIcon icon = new();
    private readonly Forms.ToolStripMenuItem toggle = new();
    private readonly Forms.ToolStripMenuItem copyLast = new(UiText.T("Letzten Text kopieren", "Copy last text"));
    private readonly Forms.ToolStripMenuItem resend = new(UiText.T("Letzte Aufnahme nochmal senden …", "Send last recording again …"));
    private DictationController? controller;
    private SettingsWindow? settings;
    private bool quitting;
    internal bool Started { get; private set; }

    internal TrayApp(Dispatcher dispatcher) => this.dispatcher = dispatcher;

    internal void Start()
    {
        DictationSettings stored;
        try { stored = SettingsFile.Load(SettingsFile.DefaultPath); }
        catch (UserFacingException) { stored = DictationSettings.Default; }
        controller = new DictationController(dispatcher, stored.ShortcutKey, stored.TriggerMode);
        icon.Icon = new System.Drawing.Icon(Application.GetResourceStream(new Uri("pack://application:,,,/OpenDictate;component/OpenDictate.ico")).Stream);
        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add(toggle);
        menu.Items.Add(copyLast);
        menu.Items.Add(resend);
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add(UiText.T("Einstellungen …", "Settings …"), null, (_, _) => OpenSettings());
        menu.Items.Add(UiText.T("Beenden", "Quit"), null, async (_, _) => await QuitAsync());
        menu.Opening += (_, _) => Refresh();
        toggle.Click += (_, _) => Guard(controller.ToggleFromMenu);
        copyLast.Click += async (_, _) =>
        {
            if (controller.LastText is { } text && !await ClipboardPaste.CopyAsync(text))
                controller.Oops(UiText.T("Die Zwischenablage ist gerade belegt. Versuch es gleich nochmal.", "The clipboard is busy. Try again in a moment."));
        };
        resend.Click += async (_, _) =>
        {
            // Reading the protected store decrypts files; never on menu opening.
            if (await Task.Run(LatestRecording) is { } id) Guard(() => controller.Retry(id));
            else controller.Oops(UiText.T("Keine gesicherte Aufnahme aus den letzten 24 Stunden.", "No saved recording from the last 24 hours."));
        };
        icon.ContextMenuStrip = menu;
        icon.DoubleClick += (_, _) => OpenSettings();
        controller.StateChanged += Refresh;
        controller.SettingsNeeded += OpenSettings;
        Refresh();
        icon.Visible = true;
        Started = true;
        // The WinForms menu may install its own synchronization context; every
        // continuation of the app belongs to the WPF dispatcher.
        SynchronizationContext.SetSynchronizationContext(new DispatcherSynchronizationContext(dispatcher));
        _ = ReportShortcutAsync();
        _ = Task.Run(DictationController.RemoveExpiredJournals);
        if (!stored.ShortcutConfirmed) OpenSettings();
    }

    // A menu action must never end the app; its error shows in the indicator.
    private void Guard(Action action)
    {
        try { action(); }
        catch (Exception) { Report(); }
    }

    internal void Report()
    {
        try
        {
            controller?.Oops(UiText.T(
                "Das hat nicht geklappt. Bereits gesicherte Aufnahmen bleiben erhalten.",
                "That did not work. Recordings saved so far are kept."));
        }
        catch (Exception) { /* Showing the error failed too; the app keeps running. */ }
    }

    private async Task ReportShortcutAsync()
    {
        if (!await controller!.ShortcutReady)
            controller.Oops(UiText.T("Das Tastenkürzel ist nicht verfügbar. Starte Diktate über das Symbol im Infobereich.",
                "The shortcut is not available. Start dictations from the tray icon."));
    }

    private static Guid? LatestRecording()
    {
        try { return DictationController.OpenRecovery().List().FirstOrDefault()?.Id; }
        catch (Exception) { return null; }
    }

    private void Refresh()
    {
        if (controller is null) return;
        bool recording = controller.IsRecording;
        toggle.Text = recording ? UiText.T("Diktat beenden", "Stop dictation") : UiText.T("Diktat starten (nur Zwischenablage)", "Start dictation (clipboard only)");
        toggle.Enabled = recording || !controller.IsBusy;
        copyLast.Enabled = controller.LastText is not null;
        resend.Enabled = !controller.IsBusy;
        string word = IndicatorText.Word(recording ? IndicatorPhase.Listening : controller.IsBusy ? IndicatorPhase.Writing : IndicatorPhase.Closed);
        icon.Text = $"OpenDictate · {word}";
    }

    internal void OpenSettings()
    {
        if (quitting || controller is null) return;
        if (settings is not null) { settings.Activate(); return; }
        bool firstRun;
        try { firstRun = !SettingsFile.Load(SettingsFile.DefaultPath).ShortcutConfirmed; }
        catch (UserFacingException) { firstRun = false; }
        settings = new SettingsWindow(controller, firstRun);
        settings.Closed += (_, _) => settings = null;
        settings.Show();
        settings.Activate();
    }

    private async Task QuitAsync()
    {
        if (quitting || controller is null) return;
        quitting = true;
        settings?.Close();
        await controller.ShutdownAsync();
        controller.Dispose();
        icon.Visible = false;
        icon.Dispose();
        Application.Current.Shutdown();
    }
}
