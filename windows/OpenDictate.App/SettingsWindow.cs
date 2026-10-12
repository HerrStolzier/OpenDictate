using System;
using System.Linq;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using OpenDictate.Core;
using OpenDictate.Provider;
using OpenDictate.Windows;

namespace OpenDictate.App;

// Key, shortcut, language, translation, paste and custom server. Choices are
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
    private readonly RadioButton ctrlWin = new() { Content = UiText.T("Strg+Win halten (empfohlen)", "Hold Ctrl+Win (recommended)") };
    private readonly RadioButton rightCtrl = new() { Content = UiText.T("Rechte Strg-Taste halten oder antippen (für Spiele)", "Hold or tap right Ctrl (for games)") };
    private readonly TextBlock detected = new() { TextWrapping = TextWrapping.Wrap };
    private readonly ComboBox spoken = new() { MinWidth = 260 };
    private readonly ComboBox target = new() { MinWidth = 260 };
    private readonly CheckBox autoInsert = new() { Content = UiText.T("Automatisch einfügen (sonst nur Zwischenablage)", "Paste automatically (otherwise clipboard only)") };
    private readonly CheckBox autostart = new() { Content = UiText.T("Mit Windows starten", "Start with Windows") };
    private readonly TextBox server = new() { MinWidth = 260, MaxLength = 512 };
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
        panel.Children.Add(Brand.Text(firstRun
            ? UiText.T("Willkommen. Halte das Kürzel gedrückt, sprich und lass los. Der Text landet dort, wo du gerade schreibst.",
                "Welcome. Hold the shortcut, speak and let go. The text lands where you are typing.")
            : UiText.T("Halte das Kürzel gedrückt, sprich und lass los.", "Hold the shortcut, speak and let go."),
            DesignFont.Small, DesignColor.InkMuted, Theme));

        Section(panel, UiText.T("Tastenkürzel", "Shortcut"));
        panel.Children.Add(ctrlWin); panel.Children.Add(rightCtrl);
        detected.Text = UiText.T("Halte jetzt das Kürzel, um es zu testen.", "Hold the shortcut now to test it.");
        detected.Foreground = Brand.Brush(DesignColor.InkMuted, Theme);
        detected.Margin = new Thickness(0, DesignMetric.Space2, 0, 0);
        AutomationProperties.SetLiveSetting(detected, AutomationLiveSetting.Polite);
        panel.Children.Add(detected);

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
        panel.Children.Add(autoInsert);
        panel.Children.Add(autostart);

        var serverFields = new StackPanel();
        Field(serverFields, UiText.T("Server-Adresse", "Server address"), server);
        var serverHint = Brand.Text(UiText.T($"Leer bedeutet OpenAI (oder {ProviderServer.BaseUrlVariable}, wenn gesetzt). Beispiel: http://127.0.0.1:8080/v1",
            $"Empty means OpenAI (or {ProviderServer.BaseUrlVariable} when set). Example: http://127.0.0.1:8080/v1"), DesignFont.Small, DesignColor.InkMuted, Theme);
        serverHint.Margin = new Thickness(0, DesignMetric.Space1, 0, 0);
        serverFields.Children.Add(serverHint);
        Field(serverFields, UiText.T("Modell für die Erkennung", "Transcription model"), model);
        Field(serverFields, UiText.T("Modell für die Übersetzung", "Translation model"), translationModel);
        var saveServer = new Button { Content = UiText.T("Speichern", "Save"), HorizontalAlignment = HorizontalAlignment.Left, Padding = new Thickness(10, 4, 10, 4) };
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
        Load();
        ctrlWin.Checked += (_, _) => Change(s => s with { Shortcut = ShortcutGesture.SettingsName(ShortcutKey.CtrlWin) });
        rightCtrl.Checked += (_, _) => Change(s => s with { Shortcut = ShortcutGesture.SettingsName(ShortcutKey.RightCtrl) });
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

    private static void Field(Panel panel, string label, Control field)
    {
        panel.Children.Add(new TextBlock { Text = label, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, DesignMetric.Space2, 0, DesignMetric.Space1) });
        AutomationProperties.SetName(field, label);
        panel.Children.Add(field);
    }

    private void Load()
    {
        try { stored = SettingsFile.Load(SettingsFile.DefaultPath); }
        catch (UserFacingException error)
        {
            readable = false;
            status.Text = error.Message + " " + UiText.T("Die Datei bleibt unverändert.", "The file stays unchanged.");
            foreach (var control in new Control[] { ctrlWin, rightCtrl, spoken, target, autoInsert, server, model, translationModel })
                control.IsEnabled = false;
        }
        Display(stored);
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
            spoken.SelectedItem = Choose(spoken, settings.Language);
            target.SelectedItem = Choose(target, settings.TargetLanguage);
            autoInsert.IsChecked = settings.AutoInsert;
            server.Text = settings.Server ?? "";
            model.Text = settings.Model;
            translationModel.Text = settings.TranslationModel;
        }
        finally { showing = false; }
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
            stored = next;
            controller.UseShortcut(stored.ShortcutKey);
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
            var next = stored with
            {
                Server = address.Length == 0 ? null : ProviderServer.Parse(address).Base,
                Model = model.Text.Trim(),
                TranslationModel = translationModel.Text.Trim(),
            };
            var resolved = next.ResolveServer();
            DictationSettings.ValidateModelFor(next.Model, resolved);
            if (!Change(_ => next)) return;
            Display(stored);
            string where = resolved.IsCustom ? UiText.T($"den eigenen Server ({resolved.Host})", $"your server ({resolved.Host})") : "OpenAI";
            status.Text = resolved.LacksPath
                ? UiText.T("Gespeichert. Die Server-Adresse hat keinen Pfad; meist fehlt /v1.", "Saved. The server address has no path; usually /v1 is missing.")
                : UiText.T($"Gespeichert. Diktate gehen an {where}.", $"Saved. Dictations go to {where}.");
        }
        catch (UserFacingException error) { status.Text = error.Message + " " + UiText.T("Nicht gespeichert.", "Not saved."); }
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
            ShortcutGestureKind.Tap => UiText.T($"Erkannt: {name} angetippt.", $"Recognized: {name} tapped."),
            _ => UiText.T("Da kam eine andere Taste dazu – halte nur das Kürzel.", "Another key was pressed – hold only the shortcut."),
        };
    }
}
