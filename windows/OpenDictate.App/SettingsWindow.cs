using System;
using System.Linq;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using OpenDictate.Core;
using OpenDictate.Provider;
using OpenDictate.Windows;

namespace OpenDictate.App;

// Shortcut, service, key, language, translation, paste and custom server. Choices are
// saved as soon as they change; a failed save puts the previous value back.
// While this window is in front, the shortcut only shows "recognized" here.
internal sealed class SettingsWindow : Window
{
    private const DesignTheme Theme = DesignTheme.Papier;
    private static readonly (string Code, string German, string English)[] Languages =
    [
        ("de", "Deutsch", "German"), ("en", "Englisch", "English"), ("fr", "Französisch", "French"),
        ("es", "Spanisch", "Spanish"), ("it", "Italienisch", "Italian"), ("pt", "Portugiesisch", "Portuguese"),
        ("nl", "Niederländisch", "Dutch"), ("pl", "Polnisch", "Polish"), ("tr", "Türkisch", "Turkish"),
        ("uk", "Ukrainisch", "Ukrainian"),
    ];
    private sealed record Choice(string? Code, string Label) { public override string ToString() => Label; }

    private readonly DictationController controller;
    private readonly bool firstRun;
    private readonly PasswordBox apiKey = new() { MaxLength = 2048, MinWidth = 260 };
    private readonly TextBlock keyState = new() { TextWrapping = TextWrapping.Wrap };
    private readonly RadioButton ctrlWin = new() { Content = UiText.T("Strg+Win (empfohlen)", "Ctrl+Win (recommended)") };
    private readonly RadioButton rightCtrl = new() { Content = UiText.T("Rechte Strg-Taste (für Spiele)", "Right Ctrl (for games)") };
    private readonly ComboBox shortcutMode = new() { MinWidth = 260 };
    private readonly TextBlock intro;
    private readonly TextBlock detected = new() { TextWrapping = TextWrapping.Wrap };
    private readonly ComboBox service = new() { MinWidth = 260 };
    private readonly ComboBoxItem openAiService = new() { Content = "OpenAI", Tag = DictationSettings.OpenAiService };
    private readonly ComboBoxItem serverService = new() { Tag = DictationSettings.ServerService };
    private readonly ComboBox spoken = new() { MinWidth = 260 };
    private readonly ComboBox target = new() { MinWidth = 260 };
    private readonly CheckBox autoInsert = new() { Content = UiText.T("Automatisch einfügen (sonst nur Zwischenablage)", "Paste automatically (otherwise clipboard only)") };
    private readonly CheckBox autostart = new() { Content = UiText.T("Mit Windows starten", "Start with Windows") };
    private readonly TextBox server = new() { MinWidth = 260, MaxLength = 512 };
    private readonly TextBox serverModel = new() { MinWidth = 260, MaxLength = 128 };
    private readonly TextBox serverTranslationModel = new() { MinWidth = 260, MaxLength = 128 };
    private readonly TextBox model = new() { MinWidth = 260, MaxLength = 128 };
    private readonly TextBox translationModel = new() { MinWidth = 260, MaxLength = 128 };
    private readonly TextBlock status = new() { TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, DesignMetric.Space3, 0, 0) };
    private DictationSettings stored = DictationSettings.Default;
    private bool readable = true;
    private bool showing;

    internal SettingsWindow(DictationController controller, bool firstRun)
    {
        this.controller = controller;
        this.firstRun = firstRun;
        Title = UiText.T("OpenDictate · Einstellungen", "OpenDictate · Settings");
        Width = 520; SizeToContent = SizeToContent.Height; MaxHeight = SystemParameters.WorkArea.Height - 40;
        ResizeMode = ResizeMode.CanMinimize;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        Background = Brand.Brush(DesignColor.Bg, Theme);
        Foreground = Brand.Brush(DesignColor.Ink, Theme);
        FontFamily = Brand.Font(DesignFont.Sans);
        FontSize = DesignFont.Body.Size;
        var panel = new StackPanel { Margin = new Thickness(DesignMetric.Space6) };
        panel.Children.Add(Brand.Text("opendictate", DesignFont.Heading, DesignColor.Ink, Theme));
        intro = Brand.Text("", DesignFont.Small, DesignColor.InkMuted, Theme);
        panel.Children.Add(intro);

        Section(panel, UiText.T("Tastenkürzel", "Shortcut"));
        Option(panel, ctrlWin); Option(panel, rightCtrl);
        Field(panel, UiText.T("So nimmst du auf", "How you record"), shortcutMode);
        detected.Margin = new Thickness(0, DesignMetric.Space2, 0, 0);
        AutomationProperties.SetLiveSetting(detected, AutomationLiveSetting.Polite);
        panel.Children.Add(detected);

        Section(panel, UiText.T("Dienst", "Service"));
        Field(panel, UiText.T("Wer macht aus deiner Aufnahme Text?", "Who turns your recording into text?"), service);
        var serviceHint = Brand.Text(UiText.T("Einen eigenen Server trägst du unten unter „Eigener Server und Modelle“ ein. Die Adresse bleibt gespeichert, auch wenn du OpenAI wählst.",
            "Enter a custom server below under “Custom server and models”. Its address stays saved when you choose OpenAI."), DesignFont.Small, DesignColor.InkMuted, Theme);
        serviceHint.Margin = new Thickness(0, DesignMetric.Space1, 0, 0);
        panel.Children.Add(serviceHint);

        Section(panel, UiText.T("OpenAI-API-Schlüssel", "OpenAI API key"));
        panel.Children.Add(Brand.Text(UiText.T("Er wird sicher in der Windows-Anmeldeinformationsverwaltung gespeichert. Die Kosten rechnet OpenAI direkt mit dir ab.",
            "It is stored safely in Windows Credential Manager. OpenAI bills you directly."), DesignFont.Small, DesignColor.InkMuted, Theme));
        AutomationProperties.SetName(apiKey, UiText.T("OpenAI-API-Schlüssel", "OpenAI API key"));
        var keyRow = new WrapPanel { Margin = new Thickness(0, DesignMetric.Space2, 0, 0) };
        var saveKey = new Button { Content = UiText.T("Speichern", "Save"), Margin = new Thickness(DesignMetric.Space2, 0, 0, 0), Padding = new Thickness(10, 4, 10, 4) };
        var deleteKey = new Button { Content = UiText.T("Entfernen", "Remove"), Margin = new Thickness(DesignMetric.Space2, 0, 0, 0), Padding = new Thickness(10, 4, 10, 4) };
        keyRow.Children.Add(apiKey); keyRow.Children.Add(saveKey); keyRow.Children.Add(deleteKey);
        panel.Children.Add(keyRow); panel.Children.Add(keyState);

        Section(panel, UiText.T("Sprache und Übersetzung", "Language and translation"));
        Field(panel, UiText.T("Gesprochene Sprache", "Spoken language"), spoken);
        Field(panel, UiText.T("Übersetzung nach dem Sprechen", "Translation after speaking"), target);
        Section(panel, UiText.T("Einfügen", "Pasting"));
        Option(panel, autoInsert);
        Section(panel, UiText.T("Start", "Startup"));
        Option(panel, autostart);

        var serverFields = new StackPanel();
        Subsection(serverFields, UiText.T("Eigener Server", "Custom server"));
        Field(serverFields, UiText.T("Server-Adresse", "Server address"), server);
        var serverHint = Brand.Text(UiText.T($"Beispiel: http://127.0.0.1:8080/v1. Leer heißt: kein eigener Server (oder {ProviderServer.BaseUrlVariable}, wenn gesetzt).",
            $"Example: http://127.0.0.1:8080/v1. Empty means no custom server (or {ProviderServer.BaseUrlVariable} when set)."), DesignFont.Small, DesignColor.InkMuted, Theme);
        serverHint.Margin = new Thickness(0, DesignMetric.Space1, 0, 0);
        serverFields.Children.Add(serverHint);
        Field(serverFields, UiText.T("Modell für die Erkennung", "Transcription model"), serverModel, UiText.T("Eigener Server: Modell für die Erkennung", "Custom server: transcription model"));
        Field(serverFields, UiText.T("Modell für die Übersetzung", "Translation model"), serverTranslationModel, UiText.T("Eigener Server: Modell für die Übersetzung", "Custom server: translation model"));
        Subsection(serverFields, "OpenAI");
        Field(serverFields, UiText.T("Modell für die Erkennung", "Transcription model"), model, UiText.T("OpenAI: Modell für die Erkennung", "OpenAI: transcription model"));
        Field(serverFields, UiText.T("Modell für die Übersetzung", "Translation model"), translationModel, UiText.T("OpenAI: Modell für die Übersetzung", "OpenAI: translation model"));
        var saveServer = new Button { Content = UiText.T("Speichern", "Save"), HorizontalAlignment = HorizontalAlignment.Left, Padding = new Thickness(10, 4, 10, 4), Margin = new Thickness(0, DesignMetric.Space3, 0, 0) };
        serverFields.Children.Add(saveServer);
        panel.Children.Add(new Expander { Header = UiText.T("Eigener Server und Modelle", "Custom server and models"), Content = serverFields, Margin = new Thickness(0, DesignMetric.Space4, 0, 0) });

        var done = new Button { Content = UiText.T("Fertig", "Done"), HorizontalAlignment = HorizontalAlignment.Right, Padding = new Thickness(16, 6, 16, 6), Margin = new Thickness(0, DesignMetric.Space4, 0, 0), IsDefault = true };
        done.Click += (_, _) => Close();
        AutomationProperties.SetLiveSetting(status, AutomationLiveSetting.Polite);
        panel.Children.Add(status);
        panel.Children.Add(done);
        Content = new ScrollViewer { Content = panel, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };

        spoken.Items.Add(new Choice(null, UiText.T("Automatisch erkennen", "Detect automatically")));
        target.Items.Add(new Choice(null, UiText.T("Aus", "Off")));
        foreach (var (code, german, english) in Languages)
        {
            spoken.Items.Add(new Choice(code, UiText.T(german, english)));
            target.Items.Add(new Choice(code, UiText.T(german, english)));
        }
        shortcutMode.Items.Add(new Choice(ShortcutGesture.ModeName(TriggerMode.Hold), UiText.T("Gedrückt halten, solange du sprichst", "Hold while you speak")));
        shortcutMode.Items.Add(new Choice(ShortcutGesture.ModeName(TriggerMode.Tap), UiText.T("Antippen: einmal zum Starten, einmal zum Stoppen", "Tap: once to start, once to stop")));
        service.Items.Add(openAiService);
        service.Items.Add(serverService);
        Load();
        ctrlWin.Checked += (_, _) => Change(s => s with { Shortcut = ShortcutGesture.SettingsName(ShortcutKey.CtrlWin) });
        rightCtrl.Checked += (_, _) => Change(s => s with { Shortcut = ShortcutGesture.SettingsName(ShortcutKey.RightCtrl) });
        shortcutMode.SelectionChanged += (_, _) =>
        {
            if (shortcutMode.SelectedItem is Choice { Code: { } mode }) Change(s => s with { ShortcutMode = mode });
        };
        service.SelectionChanged += (_, _) =>
        {
            if (service.SelectedItem is ComboBoxItem { Tag: string choice } && Change(s => s with { Service = choice })) ShowDestination();
        };
        spoken.SelectionChanged += (_, _) => Change(s => s with { Language = (spoken.SelectedItem as Choice)?.Code });
        target.SelectionChanged += (_, _) => Change(s => s.WithTarget((target.SelectedItem as Choice)?.Code));
        autoInsert.Click += (_, _) => Change(s => s with { AutoInsert = autoInsert.IsChecked == true });
        autostart.Click += (_, _) =>
        {
            try { Autostart.Set(autostart.IsChecked == true); }
            catch (Exception error) when (error is UnauthorizedAccessException or System.Security.SecurityException or System.IO.IOException)
            { status.Text = UiText.T("„Mit Windows starten“ ließ sich nicht ändern.", "“Start with Windows” could not be changed."); }
            autostart.IsChecked = Autostart.IsEnabled;
        };
        saveServer.Click += (_, _) => SaveServer();
        saveKey.Click += (_, _) => SaveKey();
        deleteKey.Click += (_, _) =>
        {
            try { new CredentialStore().Delete(); status.Text = UiText.T("Schlüssel entfernt.", "Key removed."); }
            catch (Exception) { status.Text = UiText.T("Schlüssel konnte nicht entfernt werden.", "The key could not be removed."); }
            ShowKeyState();
        };
        Activated += (_, _) => controller.GestureTest = ShowDetected;
        Deactivated += (_, _) => controller.GestureTest = null;
        Closed += (_, _) =>
        {
            controller.GestureTest = null;
            apiKey.Clear();
            // The first start counts as confirmed once the user has seen it.
            if (this.firstRun && readable && !stored.ShortcutConfirmed) Change(s => s with { ShortcutConfirmed = true });
        };
    }

    private void Section(Panel panel, string title)
    {
        var heading = Brand.Text(title, DesignFont.Strong, DesignColor.Ink, Theme);
        heading.Margin = new Thickness(0, DesignMetric.Space6, 0, DesignMetric.Space2);
        panel.Children.Add(heading);
    }

    private void Subsection(Panel panel, string title)
    {
        var heading = Brand.Text(title, DesignFont.Strong, DesignColor.Ink, Theme);
        heading.Margin = new Thickness(0, DesignMetric.Space4, 0, 0);
        panel.Children.Add(heading);
    }

    private static void Option(Panel panel, Control option)
    {
        option.Margin = new Thickness(0, DesignMetric.Space1, 0, DesignMetric.Space1);
        panel.Children.Add(option);
    }

    // spokenName: what a screen reader announces when the label alone is ambiguous.
    private static void Field(Panel panel, string label, Control field, string? spokenName = null)
    {
        panel.Children.Add(new TextBlock { Text = label, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, DesignMetric.Space2, 0, DesignMetric.Space1) });
        AutomationProperties.SetName(field, spokenName ?? label);
        panel.Children.Add(field);
    }

    private void Load()
    {
        try { stored = SettingsFile.Load(SettingsFile.DefaultPath); }
        catch (UserFacingException error)
        {
            readable = false;
            status.Text = error.Message + " " + UiText.T("Die Datei bleibt unverändert.", "The file stays unchanged.");
            foreach (var control in new Control[] { ctrlWin, rightCtrl, shortcutMode, service, spoken, target, autoInsert, server,
                serverModel, serverTranslationModel, model, translationModel })
                control.IsEnabled = false;
        }
        Display(stored);
        ShowHints();
        autostart.IsChecked = Autostart.IsEnabled;
        ShowKeyState();
        if (readable && stored.Server is null)
        {
            try
            {
                if (stored.ResolveServer() is { IsCustom: true } fromEnvironment)
                    status.Text = UiText.T($"{ProviderServer.BaseUrlVariable} ist gesetzt: Diktate gehen an {fromEnvironment.Host}.",
                        $"{ProviderServer.BaseUrlVariable} is set: dictations go to {fromEnvironment.Host}.");
            }
            catch (UserFacingException error) { status.Text = error.Message; }
        }
    }

    private void Display(DictationSettings settings)
    {
        showing = true;
        try
        {
            ctrlWin.IsChecked = settings.ShortcutKey == ShortcutKey.CtrlWin;
            rightCtrl.IsChecked = settings.ShortcutKey == ShortcutKey.RightCtrl;
            shortcutMode.SelectedItem = Choose(shortcutMode, ShortcutGesture.ModeName(settings.TriggerMode));
            // The custom server can only be chosen once an address is known.
            string? host = ServerHost(settings);
            serverService.Content = host is null
                ? UiText.T("Eigener Server (noch keine Adresse)", "Custom server (no address yet)")
                : UiText.T($"Eigener Server ({host})", $"Custom server ({host})");
            bool usesServer = settings.UsesServer(Environment.GetEnvironmentVariable(ProviderServer.BaseUrlVariable));
            serverService.IsEnabled = host is not null || usesServer;
            service.SelectedItem = usesServer ? serverService : openAiService;
            spoken.SelectedItem = Choose(spoken, settings.Language);
            target.SelectedItem = Choose(target, settings.TargetLanguage);
            autoInsert.IsChecked = settings.AutoInsert;
            server.Text = settings.Server ?? "";
            serverModel.Text = settings.ServerModel;
            serverTranslationModel.Text = settings.ServerTranslationModel;
            model.Text = settings.Model;
            translationModel.Text = settings.TranslationModel;
        }
        finally { showing = false; }
    }

    // The stored address, else OPENAI_BASE_URL; a broken one still shows as set.
    private static string? ServerHost(DictationSettings settings)
    {
        string? address = settings.Server ?? Environment.GetEnvironmentVariable(ProviderServer.BaseUrlVariable);
        if (string.IsNullOrWhiteSpace(address)) return null;
        try { return ProviderServer.Parse(address).Host; }
        catch (UserFacingException) { return UiText.T("Adresse ungültig", "invalid address"); }
    }

    // A stored code outside the list stays selectable instead of being dropped.
    private static Choice Choose(ComboBox box, string? code)
    {
        var match = box.Items.OfType<Choice>().FirstOrDefault(choice => choice.Code == code);
        if (match is not null) return match;
        var added = new Choice(code, code!);
        box.Items.Add(added);
        return added;
    }

    private bool Change(Func<DictationSettings, DictationSettings> edit)
    {
        if (showing || !readable) return false;
        var next = edit(stored);
        if (next == stored) return true;
        try
        {
            SettingsFile.Save(SettingsFile.DefaultPath, next);
            bool shortcutChanged = next.ShortcutKey != stored.ShortcutKey || next.TriggerMode != stored.TriggerMode;
            stored = next;
            controller.UseShortcut(stored.ShortcutKey, stored.TriggerMode);
            if (shortcutChanged) ShowHints();
            status.Text = UiText.T("Gespeichert.", "Saved.");
            return true;
        }
        catch (UserFacingException error)
        {
            status.Text = error.Message + " " + UiText.T("Nicht gespeichert.", "Not saved.");
            Display(stored);
            return false;
        }
    }

    private void SaveServer()
    {
        string address = server.Text.Trim();
        try
        {
            string? saved = address.Length == 0 ? null : ProviderServer.Parse(address).Base;
            var next = stored.WithServerAddress(saved, Environment.GetEnvironmentVariable(ProviderServer.BaseUrlVariable)) with
            {
                ServerModel = serverModel.Text.Trim(),
                ServerTranslationModel = serverTranslationModel.Text.Trim(),
                Model = model.Text.Trim(),
                TranslationModel = translationModel.Text.Trim(),
            };
            DictationSettings.ValidateModelFor(next.Model, ProviderServer.OpenAi);
            var (request, resolved) = next.ForDictation();
            DictationSettings.ValidateModelFor(request.Model, resolved);
            if (!Change(_ => next)) return;
            Display(stored);
            ShowDestination();
        }
        catch (UserFacingException error) { status.Text = error.Message + " " + UiText.T("Nicht gespeichert.", "Not saved."); }
    }

    private void ShowDestination()
    {
        try
        {
            var resolved = stored.ResolveServer();
            string where = resolved.IsCustom ? UiText.T($"den eigenen Server ({resolved.Host})", $"your server ({resolved.Host})") : "OpenAI";
            status.Text = resolved.LacksPath
                ? UiText.T("Gespeichert. Die Server-Adresse hat keinen Pfad; meist fehlt /v1.", "Saved. The server address has no path; usually /v1 is missing.")
                : UiText.T($"Gespeichert. Diktate gehen an {where}.", $"Saved. Dictations go to {where}.");
        }
        catch (UserFacingException error) { status.Text = UiText.T("Gespeichert. ", "Saved. ") + error.Message; }
    }

    private void ShowHints()
    {
        bool tap = stored.TriggerMode == TriggerMode.Tap;
        string how = tap
            ? UiText.T("Tipp das Kürzel an, sprich und tipp es nochmal an.", "Tap the shortcut, speak and tap it again.")
            : UiText.T("Halte das Kürzel gedrückt, sprich und lass los.", "Hold the shortcut, speak and let go.");
        intro.Text = firstRun
            ? UiText.T($"Willkommen. {how} Der Text landet dort, wo du gerade schreibst.", $"Welcome. {how} The text lands where you are typing.")
            : how;
        detected.Foreground = Brand.Brush(DesignColor.InkMuted, Theme);
        detected.Text = tap
            ? UiText.T("Tipp jetzt das Kürzel an, um es zu testen.", "Tap the shortcut now to test it.")
            : UiText.T("Halte jetzt das Kürzel, um es zu testen.", "Hold the shortcut now to test it.");
    }

    private void SaveKey()
    {
        try
        {
            new CredentialStore().Save(apiKey.Password);
            status.Text = UiText.T("Schlüssel gespeichert.", "Key saved.");
        }
        catch (ArgumentException) { status.Text = UiText.T("Gib einen gültigen API-Schlüssel ohne Leerzeichen ein.", "Enter a valid API key without spaces."); }
        catch (Exception) { status.Text = UiText.T("Schlüssel konnte nicht gespeichert werden.", "The key could not be saved."); }
        finally { apiKey.Clear(); }
        ShowKeyState();
    }

    private void ShowKeyState()
    {
        bool present;
        try { present = !string.IsNullOrEmpty(new CredentialStore().Read()); }
        catch (Exception) { keyState.Text = UiText.T("Die Windows-Anmeldeinformationsverwaltung ist nicht erreichbar.", "Windows Credential Manager is not available."); return; }
        keyState.Text = present
            ? UiText.T("Ein Schlüssel ist gespeichert.", "A key is saved.")
            : UiText.T("Noch kein Schlüssel gespeichert. Für einen eigenen Server auf diesem Computer ist keiner nötig.",
                "No key saved yet. A server on this computer needs none.");
    }

    private void ShowDetected(ShortcutGestureKind gesture)
    {
        string name = stored.ShortcutKey == ShortcutKey.CtrlWin ? UiText.T("Strg+Win", "Ctrl+Win") : UiText.T("Rechte Strg-Taste", "Right Ctrl");
        detected.Foreground = Brand.Brush(DesignColor.SignalInk, Theme);
        detected.Text = gesture switch
        {
            ShortcutGestureKind.HoldBegan => UiText.T($"Erkannt: {name} wird gehalten. Hier wird nichts aufgenommen.", $"Recognized: {name} is held. Nothing is recorded here."),
            ShortcutGestureKind.HoldEnded => UiText.T($"Erkannt: {name} losgelassen. Das Kürzel funktioniert.", $"Recognized: {name} released. The shortcut works."),
            ShortcutGestureKind.Tap => UiText.T($"Erkannt: {name} angetippt. Das Kürzel funktioniert.", $"Recognized: {name} tapped. The shortcut works."),
            _ => UiText.T("Da kam eine andere Taste dazu – halte nur das Kürzel.", "Another key was pressed – hold only the shortcut."),
        };
    }
}
