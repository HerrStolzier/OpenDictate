using System;
using System.Linq;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Shapes;
using OpenDictate.Core;
using OpenDictate.Provider;
using OpenDictate.Windows;

namespace OpenDictate.App;

// Shortcut, service, key, language, translation, paste and custom server. Choices are
// saved as soon as they change; a failed save puts the previous value back.
// While this window is in front, the shortcut only shows "recognized" here.
internal sealed class SettingsWindow : Window
{
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
    private readonly PasswordBox apiKey = new() { MaxLength = 2048 };
    private readonly TextBlock keyState = Brand.Text("", DesignFont.Small, DesignColor.Ink);
    private readonly UIElement keyCheck = Check();
    private readonly Button deleteKey = new() { Content = UiText.T("Entfernen", "Remove") };
    private readonly RadioButton ctrlWin = new() { GroupName = "shortcut" };
    private readonly RadioButton rightCtrl = new() { GroupName = "shortcut" };
    private readonly RadioButton holdMode = new() { GroupName = "mode", Content = UiText.T("Gedrückt halten", "Hold") };
    private readonly RadioButton tapMode = new() { GroupName = "mode", Content = UiText.T("Antippen", "Tap") };
    private readonly TextBlock modeHint = Brand.Text("", DesignFont.Small, DesignColor.InkMuted);
    private readonly TextBlock intro = Brand.Text("", DesignFont.Small, DesignColor.InkMuted);
    private readonly Rectangle readyMark = Brand.Mark(DesignColor.Signal);
    private readonly TextBlock ready = Brand.Text("", DesignFont.Heading with { Size = 20, LineHeight = 24 }, DesignColor.Signal);
    private readonly TextBlock readyWhere = Brand.Text("", DesignFont.Label, DesignColor.InkMuted);
    private readonly TextBlock detected = Brand.Text("", DesignFont.Code, DesignColor.InkMuted);
    private readonly RadioButton openAiService = new() { GroupName = "service", Content = "OpenAI" };
    private readonly RadioButton serverService = new() { GroupName = "service" };
    private readonly ComboBox spoken = new();
    private readonly ComboBox target = new();
    private readonly CheckBox autoInsert = new();
    private readonly CheckBox autostart = new();
    private readonly TextBlock autoInsertHint = Brand.Text("", DesignFont.Small, DesignColor.InkMuted);
    private readonly TextBlock autostartHint = Brand.Text("", DesignFont.Small, DesignColor.InkMuted);
    private readonly StackPanel serverPanel = new() { Visibility = Visibility.Collapsed };
    private readonly TextBox server = new() { MaxLength = 512 };
    private readonly TextBox serverModel = new() { MaxLength = 128 };
    private readonly TextBox serverTranslationModel = new() { MaxLength = 128 };
    private readonly TextBox model = new() { MaxLength = 128 };
    private readonly TextBox translationModel = new() { MaxLength = 128 };
    private readonly TextBlock status = Brand.Text("", DesignFont.Small, DesignColor.InkMuted);
    private DictationSettings stored = DictationSettings.Default;
    private bool readable = true;
    private bool showing;
    private bool? keyPresent;

    internal SettingsWindow(DictationController controller, bool firstRun)
    {
        this.controller = controller;
        this.firstRun = firstRun;
        Title = UiText.T("OpenDictate · Einstellungen", "OpenDictate · Settings");
        // Fits a 1080p laptop at 125 %; the cards scroll, the footer stays.
        Width = 600; Height = Math.Min(780, SystemParameters.WorkArea.Height - 40);
        ResizeMode = ResizeMode.CanMinimize;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        Background = Brand.Brush(DesignColor.Bg);
        Foreground = Brand.Brush(DesignColor.Ink);
        FontFamily = Brand.Font(DesignFont.Sans);
        FontSize = DesignFont.Body.Size;
        SourceInitialized += (_, _) => Brand.DarkTitleBar(this);

        // The bottom margin leaves room for the focus ring of the last control.
        var panel = new StackPanel { Margin = new Thickness(DesignMetric.Space6, DesignMetric.Space4, DesignMetric.Space6, DesignMetric.Space6) };
        panel.Children.Add(Hero());

        var shortcut = Card(panel, UiText.T("Tastenkürzel", "Shortcut"));
        ctrlWin.Content = Tile(["Strg", "Win"], UiText.T("Strg + Win", "Ctrl + Win"), UiText.T("Empfohlen", "Recommended"), DesignColor.Signal);
        rightCtrl.Content = Tile([UiText.T("Strg rechts", "Right Ctrl")], UiText.T("Rechte Strg-Taste", "Right Ctrl"), UiText.T("Für Spiele", "For games"), DesignColor.InkMuted);
        AutomationProperties.SetName(ctrlWin, UiText.T("Strg+Win (empfohlen)", "Ctrl+Win (recommended)"));
        AutomationProperties.SetName(rightCtrl, UiText.T("Rechte Strg-Taste (für Spiele)", "Right Ctrl (for games)"));
        shortcut.Children.Add(OneTabStop(Pair(ctrlWin, rightCtrl, "Tile", DesignMetric.Space3)));
        Label(shortcut, UiText.T("So nimmst du auf", "How you record"));
        shortcut.Children.Add(Segments(holdMode, tapMode, UiText.T("So nimmst du auf", "How you record")));
        modeHint.Margin = new Thickness(0, DesignMetric.Space2, 0, 0);
        shortcut.Children.Add(modeHint);
        shortcut.Children.Add(TestLine());

        var service = Card(panel, UiText.T("Dienst", "Service"));
        service.Children.Add(Segments(openAiService, serverService, UiText.T("Wer macht aus deiner Aufnahme Text?", "Who turns your recording into text?")));
        // The address belongs to the custom server choice and shows with it.
        Label(serverPanel, UiText.T("Server-Adresse", "Server address"));
        AutomationProperties.SetName(server, UiText.T("Server-Adresse", "Server address"));
        var saveAddress = new Button { Content = UiText.T("Speichern", "Save"), Style = Brand.Style("SecondaryButton"), Margin = new Thickness(DesignMetric.Space3, 0, 0, 0) };
        AutomationProperties.SetName(saveAddress, UiText.T("Server-Adresse speichern", "Save server address"));
        serverPanel.Children.Add(FieldWithButton(server, saveAddress));
        Hint(serverPanel, UiText.T("Zum Beispiel http://127.0.0.1:8080/v1. Die Adresse bleibt gespeichert, auch wenn du OpenAI wählst.",
            "For example http://127.0.0.1:8080/v1. The address stays saved when you choose OpenAI."));
        service.Children.Add(serverPanel);
        Label(service, UiText.T("OpenAI-API-Schlüssel", "OpenAI API key"));
        AutomationProperties.SetName(apiKey, UiText.T("OpenAI-API-Schlüssel", "OpenAI API key"));
        var saveKey = new Button { Content = UiText.T("Speichern", "Save"), Style = Brand.Style("SecondaryButton"), Margin = new Thickness(DesignMetric.Space3, 0, 0, 0) };
        AutomationProperties.SetName(saveKey, UiText.T("Schlüssel speichern", "Save key"));
        service.Children.Add(FieldWithButton(apiKey, saveKey));
        deleteKey.Style = Brand.Style("LinkButton");
        var stateRow = new DockPanel { Margin = new Thickness(0, DesignMetric.Space2, 0, 0) };
        DockPanel.SetDock(deleteKey, Dock.Right); DockPanel.SetDock(keyCheck, Dock.Left);
        keyState.VerticalAlignment = VerticalAlignment.Center;
        stateRow.Children.Add(deleteKey); stateRow.Children.Add(keyCheck); stateRow.Children.Add(keyState);
        AutomationProperties.SetLiveSetting(keyState, AutomationLiveSetting.Polite);
        service.Children.Add(stateRow);
        Hint(service, UiText.T("Er wird sicher in der Windows-Anmeldeinformationsverwaltung gespeichert. Die Kosten rechnet OpenAI direkt mit dir ab.",
            "It is stored safely in Windows Credential Manager. OpenAI bills you directly."));

        var language = Card(panel, UiText.T("Sprache", "Language"));
        language.Children.Add(Pair(
            Field(UiText.T("Du sprichst", "You speak"), spoken, UiText.T("Gesprochene Sprache", "Spoken language")),
            Field(UiText.T("Übersetzen in", "Translate into"), target, UiText.T("Übersetzung nach dem Sprechen", "Translation after speaking")),
            null, DesignMetric.Space3));

        var switches = new StackPanel();
        autoInsert.Content = SwitchLabel(UiText.T("Automatisch einfügen", "Paste automatically"), autoInsertHint);
        autostart.Content = SwitchLabel(UiText.T("Mit Windows starten", "Start with Windows"), autostartHint);
        AutomationProperties.SetName(autoInsert, UiText.T("Automatisch einfügen (sonst nur Zwischenablage)", "Paste automatically (otherwise clipboard only)"));
        AutomationProperties.SetName(autostart, UiText.T("Mit Windows starten", "Start with Windows"));
        foreach (var row in new[] { autoInsert, autostart })
        {
            row.Style = Brand.Style("Switch");
            row.Padding = new Thickness(0);
            row.Margin = new Thickness(0, DesignMetric.Space3, 0, DesignMetric.Space3);
        }
        switches.Children.Add(autoInsert);
        switches.Children.Add(new Rectangle { Height = 1, Fill = Brand.Brush(DesignColor.Line) });
        switches.Children.Add(autostart);
        panel.Children.Add(new Border
        {
            Background = Brand.Brush(DesignColor.Surface), CornerRadius = new CornerRadius(DesignMetric.RadiusCard),
            Padding = new Thickness(DesignMetric.Space6, DesignMetric.Space2, DesignMetric.Space6, DesignMetric.Space2),
            Margin = new Thickness(0, 0, 0, DesignMetric.Space4), Child = switches,
        });

        var modelFields = new StackPanel();
        Subsection(modelFields, UiText.T("Eigener Server", "Custom server"));
        modelFields.Children.Add(Field(UiText.T("Modell für die Erkennung", "Transcription model"), serverModel, UiText.T("Eigener Server: Modell für die Erkennung", "Custom server: transcription model")));
        modelFields.Children.Add(Field(UiText.T("Modell für die Übersetzung", "Translation model"), serverTranslationModel, UiText.T("Eigener Server: Modell für die Übersetzung", "Custom server: translation model")));
        Subsection(modelFields, "OpenAI");
        modelFields.Children.Add(Field(UiText.T("Modell für die Erkennung", "Transcription model"), model, UiText.T("OpenAI: Modell für die Erkennung", "OpenAI: transcription model")));
        modelFields.Children.Add(Field(UiText.T("Modell für die Übersetzung", "Translation model"), translationModel, UiText.T("OpenAI: Modell für die Übersetzung", "OpenAI: translation model")));
        var saveModels = new Button { Content = UiText.T("Speichern", "Save"), Style = Brand.Style("SecondaryButton"), HorizontalAlignment = HorizontalAlignment.Left, Margin = new Thickness(0, DesignMetric.Space4, 0, 0) };
        AutomationProperties.SetName(saveModels, UiText.T("Modelle speichern", "Save models"));
        modelFields.Children.Add(saveModels);
        var header = new StackPanel();
        header.Children.Add(Brand.Text(UiText.T("Modelle", "Models"), DesignFont.Strong, DesignColor.Ink));
        header.Children.Add(Brand.Text(UiText.T("Welche Modelle erkennen und übersetzen, je Dienst.", "Which models transcribe and translate, per service."), DesignFont.Small, DesignColor.InkMuted));
        var expander = new Expander { Header = header, Content = modelFields, Style = Brand.Style("Disclosure") };
        AutomationProperties.SetName(expander, UiText.T("Modelle", "Models"));
        panel.Children.Add(expander);

        var done = new Button { Content = UiText.T("Fertig", "Done"), Style = Brand.Style("PrimaryButton"), IsDefault = true };
        done.Click += (_, _) => Close();
        AutomationProperties.SetLiveSetting(status, AutomationLiveSetting.Polite);
        var footer = new DockPanel { Margin = new Thickness(DesignMetric.Space6, DesignMetric.Space4, DesignMetric.Space6, DesignMetric.Space4) };
        DockPanel.SetDock(done, Dock.Right);
        status.VerticalAlignment = VerticalAlignment.Center;
        status.Margin = new Thickness(0, 0, DesignMetric.Space4, 0);
        footer.Children.Add(done); footer.Children.Add(status);
        var bottom = new Border { BorderBrush = Brand.Brush(DesignColor.Line), BorderThickness = new Thickness(0, 1, 0, 0), Child = footer };
        // Rows instead of docking keep the settings first in the tab order.
        var root = new Grid();
        root.RowDefinitions.Add(new RowDefinition());
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        Grid.SetRow(bottom, 1);
        root.Children.Add(new ScrollViewer { Content = panel, VerticalScrollBarVisibility = ScrollBarVisibility.Auto });
        // Scrolling to a focused control also shows its focus ring and the line below it.
        panel.AddHandler(GotKeyboardFocusEvent, new KeyboardFocusChangedEventHandler((_, e) =>
        {
            if (e.NewFocus is not FrameworkElement focused || InputManager.Current.MostRecentInputDevice is not KeyboardDevice) return;
            Dispatcher.BeginInvoke(() => focused.BringIntoView(new Rect(-DesignMetric.Space2, -DesignMetric.Space2,
                focused.ActualWidth + 2 * DesignMetric.Space2, focused.ActualHeight + DesignMetric.Space2 + DesignMetric.Space8)),
                System.Windows.Threading.DispatcherPriority.Input);
        }));
        root.Children.Add(bottom);
        Content = root;

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
        holdMode.Checked += (_, _) => Change(s => s with { ShortcutMode = ShortcutGesture.ModeName(TriggerMode.Hold) });
        tapMode.Checked += (_, _) => Change(s => s with { ShortcutMode = ShortcutGesture.ModeName(TriggerMode.Tap) });
        openAiService.Checked += (_, _) => ChooseService(DictationSettings.OpenAiService);
        serverService.Checked += (_, _) =>
        {
            serverPanel.Visibility = Visibility.Visible;
            if (showing || !readable) return;
            // Without an address the choice waits until one is saved.
            if (ServerHost(stored) is null)
            {
                status.Text = UiText.T("Trag die Adresse deines Servers ein und speichere sie.", "Enter your server's address and save it.");
                ShowReady();
                server.Focus();
            }
            else ChooseService(DictationSettings.ServerService);
        };
        serverService.Unchecked += (_, _) =>
        {
            serverPanel.Visibility = Visibility.Collapsed;
            server.Text = stored.Server ?? "";
            ShowReady();
        };
        server.KeyDown += (_, e) => { if (e.Key == Key.Enter) { e.Handled = true; SaveServer(); } };
        apiKey.KeyDown += (_, e) => { if (e.Key == Key.Enter) { e.Handled = true; SaveKey(); } };
        serverPanel.Visibility = serverService.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        spoken.SelectionChanged += (_, _) => Change(s => s with { Language = (spoken.SelectedItem as Choice)?.Code });
        target.SelectionChanged += (_, _) => Change(s => s.WithTarget((target.SelectedItem as Choice)?.Code));
        // Checked and Unchecked, not Click: screen readers and other assistive
        // tools toggle through UI Automation, which raises no Click.
        autoInsert.Checked += (_, _) => AutoInsertToggled();
        autoInsert.Unchecked += (_, _) => AutoInsertToggled();
        autostart.Checked += (_, _) => AutostartToggled();
        autostart.Unchecked += (_, _) => AutostartToggled();
        saveAddress.Click += (_, _) => SaveServer();
        saveModels.Click += (_, _) => SaveServer();
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

    // Blink, the wordmark, whether dictating works right now and how.
    private UIElement Hero()
    {
        var stage = new Border
        {
            Width = 112, Height = 112, Background = Brand.Brush(DesignColor.SurfaceSunken),
            BorderBrush = Brand.Brush(DesignColor.Line), BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(DesignMetric.RadiusCard), Padding = new Thickness(0, 0, 0, 14),
            Child = new Border { VerticalAlignment = VerticalAlignment.Bottom, HorizontalAlignment = HorizontalAlignment.Center, Child = Brand.Blink(64) },
        };
        var text = new StackPanel { VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(DesignMetric.Space6, 0, 0, 0) };
        text.Children.Add(Brand.Text("opendictate", DesignFont.Heading with { Size = 32, LineHeight = 36 }, DesignColor.Ink));
        var line = new WrapPanel { Margin = new Thickness(0, DesignMetric.Space1, 0, DesignMetric.Space1) };
        readyMark.Margin = new Thickness(0, 0, DesignMetric.Space2, 0);
        ready.TextWrapping = TextWrapping.NoWrap;
        ready.VerticalAlignment = readyWhere.VerticalAlignment = VerticalAlignment.Center;
        readyWhere.Margin = new Thickness(DesignMetric.Space3, 0, 0, 0);
        line.Children.Add(readyMark); line.Children.Add(ready); line.Children.Add(readyWhere);
        AutomationProperties.SetLiveSetting(ready, AutomationLiveSetting.Polite);
        text.Children.Add(line);
        text.Children.Add(intro);
        var hero = new DockPanel { Margin = new Thickness(0, DesignMetric.Space2, 0, DesignMetric.Space6) };
        DockPanel.SetDock(stage, Dock.Left);
        hero.Children.Add(stage); hero.Children.Add(text);
        return hero;
    }

    // "> Hold the shortcut now ..." with a cursor that blinks like Blink at rest.
    private UIElement TestLine()
    {
        var cursor = new Rectangle { Width = 8, Height = 16, Fill = Brand.Brush(DesignColor.Signal), VerticalAlignment = VerticalAlignment.Center };
        if (SystemParameters.ClientAreaAnimation)
        {
            var blink = new DoubleAnimationUsingKeyFrames { Duration = TimeSpan.FromSeconds(1.1), RepeatBehavior = RepeatBehavior.Forever };
            blink.KeyFrames.Add(new DiscreteDoubleKeyFrame(1, KeyTime.FromTimeSpan(TimeSpan.Zero)));
            blink.KeyFrames.Add(new DiscreteDoubleKeyFrame(0, KeyTime.FromTimeSpan(TimeSpan.FromSeconds(0.55))));
            cursor.BeginAnimation(OpacityProperty, blink);
        }
        var prompt = Brand.Text("›", DesignFont.Code, DesignColor.Signal);
        prompt.Margin = new Thickness(0, 0, DesignMetric.Space3, 0);
        detected.VerticalAlignment = VerticalAlignment.Center;
        detected.Margin = new Thickness(0, 0, DesignMetric.Space3, 0);
        AutomationProperties.SetLiveSetting(detected, AutomationLiveSetting.Polite);
        var row = new DockPanel();
        DockPanel.SetDock(prompt, Dock.Left); DockPanel.SetDock(cursor, Dock.Right);
        row.Children.Add(prompt); row.Children.Add(cursor); row.Children.Add(detected);
        return new StepBorder
        {
            Background = Brand.Brush(DesignColor.Bg), Padding = new Thickness(DesignMetric.Space4, DesignMetric.Space3, DesignMetric.Space4, DesignMetric.Space3),
            Margin = new Thickness(0, DesignMetric.Space4, 0, 0), Child = row,
        };
    }

    private static StackPanel Card(Panel parent, string title)
    {
        var body = new StackPanel();
        var head = Brand.Text(title, DesignFont.Heading, DesignColor.Ink);
        head.Margin = new Thickness(0, 0, 0, DesignMetric.Space4);
        body.Children.Add(head);
        parent.Children.Add(new Border
        {
            Background = Brand.Brush(DesignColor.Surface), CornerRadius = new CornerRadius(DesignMetric.RadiusCard),
            Padding = new Thickness(DesignMetric.Space6), Margin = new Thickness(0, 0, 0, DesignMetric.Space4), Child = body,
        });
        return body;
    }

    private static UIElement Tile(string[] keys, string name, string note, DesignColor noteColor)
    {
        var caps = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, DesignMetric.Space3) };
        for (int i = 0; i < keys.Length; i++)
        {
            if (i > 0)
            {
                var plus = Brand.Text("+", DesignFont.Code, DesignColor.InkMuted);
                plus.VerticalAlignment = VerticalAlignment.Center;
                plus.Margin = new Thickness(DesignMetric.Space2, 0, DesignMetric.Space2, 0);
                caps.Children.Add(plus);
            }
            caps.Children.Add(Brand.Keycap(keys[i]));
        }
        var tile = new StackPanel();
        tile.Children.Add(caps);
        tile.Children.Add(Brand.Text(name, DesignFont.Strong, DesignColor.Ink));
        tile.Children.Add(Brand.Text(note, DesignFont.Small, noteColor));
        return tile;
    }

    // Two controls side by side in equal columns.
    private static UIElement Pair(FrameworkElement left, FrameworkElement right, string? style, double gap)
    {
        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition());
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(gap) });
        grid.ColumnDefinitions.Add(new ColumnDefinition());
        if (style is not null) left.Style = right.Style = Brand.Style(style);
        Grid.SetColumn(right, 2);
        grid.Children.Add(left); grid.Children.Add(right);
        return grid;
    }

    // A field and its button in tab order: field first.
    private static UIElement FieldWithButton(Control field, Button button)
    {
        var row = new Grid();
        row.ColumnDefinitions.Add(new ColumnDefinition());
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        Grid.SetColumn(button, 1);
        row.Children.Add(field); row.Children.Add(button);
        return row;
    }

    // One tab stop for a pair of choices; the arrow keys move between them, Space selects.
    private static UIElement OneTabStop(UIElement choices)
    {
        KeyboardNavigation.SetTabNavigation(choices, KeyboardNavigationMode.Once);
        KeyboardNavigation.SetDirectionalNavigation(choices, KeyboardNavigationMode.Cycle);
        return choices;
    }

    // question: read out with each choice, since the track itself has no name for screen readers.
    private static UIElement Segments(RadioButton first, RadioButton second, string question)
    {
        second.Margin = new Thickness(DesignMetric.Space1, 0, 0, 0);
        AutomationProperties.SetHelpText(first, question);
        AutomationProperties.SetHelpText(second, question);
        return new StepBorder
        {
            Background = Brand.Brush(DesignColor.SurfaceSunken), Padding = new Thickness(DesignMetric.Space1),
            Child = OneTabStop(Pair(first, second, "Segment", 0)),
        };
    }

    private static UIElement SwitchLabel(string title, TextBlock hint)
    {
        var label = new StackPanel();
        label.Children.Add(Brand.Text(title, DesignFont.Strong, DesignColor.Ink));
        label.Children.Add(hint);
        return label;
    }

    // The hint under a switch describes what happens in its current position.
    private void ShowSwitchHints()
    {
        autoInsertHint.Text = autoInsert.IsChecked == true
            ? UiText.T("Der Text wird dort eingefügt, wo du gerade schreibst.", "The text is pasted where you are typing.")
            : UiText.T("Der Text liegt nur in der Zwischenablage.", "The text is only put on the clipboard.");
        autostartHint.Text = autostart.IsChecked == true
            ? UiText.T("OpenDictate startet mit Windows und wartet im Infobereich.", "OpenDictate starts with Windows and waits in the notification area.")
            : UiText.T("Du startest OpenDictate selbst.", "You start OpenDictate yourself.");
    }

    private static TextBlock LabelText(string text)
    {
        var label = Brand.Text(text, DesignFont.Label, DesignColor.InkMuted);
        label.Margin = new Thickness(0, DesignMetric.Space4, 0, DesignMetric.Space2);
        return label;
    }

    private static void Label(Panel panel, string text) => panel.Children.Add(LabelText(text));

    private static void Hint(Panel panel, string text)
    {
        var hint = Brand.Text(text, DesignFont.Small, DesignColor.InkMuted);
        hint.Margin = new Thickness(0, DesignMetric.Space2, 0, 0);
        panel.Children.Add(hint);
    }

    private static void Subsection(Panel panel, string title)
    {
        var heading = Brand.Text(title, DesignFont.Strong, DesignColor.Ink);
        heading.Margin = new Thickness(0, DesignMetric.Space4, 0, 0);
        panel.Children.Add(heading);
    }

    // spokenName: what a screen reader announces when the label alone is ambiguous.
    private static FrameworkElement Field(string label, Control field, string? spokenName = null)
    {
        var stack = new StackPanel();
        var text = LabelText(label);
        text.Margin = new Thickness(0, DesignMetric.Space3, 0, DesignMetric.Space2);
        stack.Children.Add(text);
        AutomationProperties.SetName(field, spokenName ?? label);
        stack.Children.Add(field);
        return stack;
    }

    // Pixel check mark from the design system's symbol grid.
    private static UIElement Check()
    {
        var path = new Path
        {
            Data = Geometry.Parse("M1,6h2v2h-2z M3,8h2v2h-2z M5,6h2v2h-2z M7,4h2v2h-2z M9,2h2v2h-2z"),
            Fill = Brand.Brush(DesignColor.Signal), Width = 12, Height = 12,
            Margin = new Thickness(0, 0, DesignMetric.Space2, 0), VerticalAlignment = VerticalAlignment.Center,
        };
        RenderOptions.SetEdgeMode(path, EdgeMode.Aliased);
        return path;
    }

    private void Load()
    {
        try { stored = SettingsFile.Load(SettingsFile.DefaultPath); }
        catch (UserFacingException error)
        {
            readable = false;
            status.Text = error.Message + " " + UiText.T("Die Datei bleibt unverändert.", "The file stays unchanged.");
            foreach (var control in new Control[] { ctrlWin, rightCtrl, holdMode, tapMode, openAiService, serverService, spoken, target, autoInsert, server,
                serverModel, serverTranslationModel, model, translationModel })
                control.IsEnabled = false;
        }
        Display(stored);
        ShowHints();
        autostart.IsChecked = Autostart.IsEnabled;
        ShowSwitchHints();
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
            holdMode.IsChecked = settings.TriggerMode == TriggerMode.Hold;
            tapMode.IsChecked = settings.TriggerMode == TriggerMode.Tap;
            string? host = ServerHost(settings);
            serverService.Content = UiText.T("Eigener Server", "Custom server");
            AutomationProperties.SetName(serverService, host is null
                ? UiText.T("Eigener Server (noch keine Adresse)", "Custom server (no address yet)")
                : UiText.T($"Eigener Server ({host})", $"Custom server ({host})"));
            bool usesServer = settings.UsesServer(Environment.GetEnvironmentVariable(ProviderServer.BaseUrlVariable));
            serverService.IsEnabled = readable;
            openAiService.IsChecked = !usesServer;
            serverService.IsChecked = usesServer;
            spoken.SelectedItem = Choose(spoken, settings.Language);
            target.SelectedItem = Choose(target, settings.TargetLanguage);
            autoInsert.IsChecked = settings.AutoInsert;
            ShowSwitchHints();
            server.Text = settings.Server ?? "";
            serverModel.Text = settings.ServerModel;
            serverTranslationModel.Text = settings.ServerTranslationModel;
            model.Text = settings.Model;
            translationModel.Text = settings.TranslationModel;
        }
        finally { showing = false; }
        ShowReady();
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

    private void ChooseService(string choice)
    {
        // Choosing what is already in effect writes nothing.
        if (stored.UsesServer(Environment.GetEnvironmentVariable(ProviderServer.BaseUrlVariable)) == (choice == DictationSettings.ServerService))
        {
            if (choice == DictationSettings.OpenAiService) status.Text = UiText.T("Diktate gehen an OpenAI.", "Dictations go to OpenAI.");
            return;
        }
        if (Change(s => s with { Service = choice })) ShowDestination();
    }

    private void AutoInsertToggled()
    {
        if (showing) return;
        Change(s => s with { AutoInsert = autoInsert.IsChecked == true });
        ShowSwitchHints();
    }

    private void AutostartToggled()
    {
        if (showing) return;
        try { Autostart.Set(autostart.IsChecked == true); }
        catch (Exception error) when (error is UnauthorizedAccessException or System.Security.SecurityException or System.IO.IOException)
        { status.Text = UiText.T("„Mit Windows starten“ ließ sich nicht ändern.", "“Start with Windows” could not be changed."); }
        showing = true;
        try { autostart.IsChecked = Autostart.IsEnabled; }
        finally { showing = false; }
        ShowSwitchHints();
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
            ShowReady();
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
            // The address field counts only while it is shown; otherwise the stored one stays.
            if (serverPanel.Visibility != Visibility.Visible) address = stored.Server ?? "";
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

    // "Ready" needs a destination that can take the recording: a custom server
    // with a valid address, or OpenAI with a saved key.
    private void ShowReady()
    {
        bool usesServer = stored.UsesServer(Environment.GetEnvironmentVariable(ProviderServer.BaseUrlVariable));
        bool broken = !readable || (usesServer ? !ServerResolves() : keyPresent is null);
        bool isReady = !broken && (usesServer || keyPresent == true);
        string where = usesServer ? UiText.T("Eigener Server", "Custom server") : "OpenAI";
        string state = isReady ? UiText.T("Bereit", "Ready")
            : broken ? UiText.T("Hoppla", "Oops")
            : UiText.T("Schlüssel fehlt", "Key missing");
        // A custom server chosen without an address yet: dictation still goes to OpenAI.
        if (!usesServer && serverService.IsChecked == true)
            where = UiText.T("noch OpenAI", "still OpenAI");
        ready.Text = state;
        readyWhere.Text = where;
        AutomationProperties.SetName(ready, $"{state} · {where}");
        var color = isReady ? DesignColor.Signal : broken ? DesignColor.Rec : DesignColor.InkMuted;
        ready.Foreground = Brand.Brush(color);
        readyMark.Fill = Brand.Brush(color);
    }

    private bool ServerResolves()
    {
        try { stored.ResolveServer(); return true; }
        catch (UserFacingException) { return false; }
    }

    private void ShowHints()
    {
        bool tap = stored.TriggerMode == TriggerMode.Tap;
        string how = tap
            ? UiText.T("Tipp das Kürzel an, sprich und tipp es nochmal an.", "Tap the shortcut, speak and tap it again.")
            : UiText.T("Halte das Kürzel gedrückt, sprich und lass los.", "Hold the shortcut, speak and let go.");
        intro.Text = firstRun
            ? UiText.T($"Willkommen. {how} Der Text landet dort, wo du gerade schreibst.", $"Welcome. {how} The text lands where you are typing.")
            : UiText.T($"{how} Der Text landet dort, wo du gerade schreibst.", $"{how} The text lands where you are typing.");
        modeHint.Text = tap
            ? UiText.T("Einmal antippen startet die Aufnahme, nochmal antippen beendet sie.", "Tap once to start recording, tap again to stop.")
            : UiText.T("Solange du das Kürzel hältst, hört OpenDictate zu. Beim Loslassen endet die Aufnahme.", "OpenDictate listens while you hold the shortcut. Letting go ends the recording.");
        detected.Foreground = Brand.Brush(DesignColor.InkMuted);
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
        try { keyPresent = !string.IsNullOrEmpty(new CredentialStore().Read()); }
        catch (Exception) { keyPresent = null; }
        keyState.Text = keyPresent switch
        {
            true => UiText.T("Ein Schlüssel ist gespeichert.", "A key is saved."),
            false => UiText.T("Noch kein Schlüssel gespeichert. Für einen eigenen Server auf diesem Computer ist keiner nötig.",
                "No key saved yet. A server on this computer needs none."),
            null => UiText.T("Die Windows-Anmeldeinformationsverwaltung ist nicht erreichbar.", "Windows Credential Manager is not available."),
        };
        keyCheck.Visibility = deleteKey.Visibility = keyPresent == true ? Visibility.Visible : Visibility.Collapsed;
        ShowReady();
    }

    private void ShowDetected(ShortcutGestureKind gesture)
    {
        string name = stored.ShortcutKey == ShortcutKey.CtrlWin ? UiText.T("Strg+Win", "Ctrl+Win") : UiText.T("Rechte Strg-Taste", "Right Ctrl");
        detected.Foreground = Brand.Brush(DesignColor.Signal);
        detected.Text = gesture switch
        {
            ShortcutGestureKind.HoldBegan => UiText.T($"Erkannt: {name} wird gehalten. Hier wird nichts aufgenommen.", $"Recognized: {name} is held. Nothing is recorded here."),
            ShortcutGestureKind.HoldEnded => UiText.T($"Erkannt: {name} losgelassen. Das Kürzel funktioniert.", $"Recognized: {name} released. The shortcut works."),
            ShortcutGestureKind.Tap => UiText.T($"Erkannt: {name} angetippt. Das Kürzel funktioniert.", $"Recognized: {name} tapped. The shortcut works."),
            _ => UiText.T("Da kam eine andere Taste dazu – halte nur das Kürzel.", "Another key was pressed – hold only the shortcut."),
        };
    }
}
