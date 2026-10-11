using System.Linq;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using OpenDictate.Core;
using OpenDictate.Provider;

namespace OpenDictate.Prototype;

// Spoken language, translation after speaking and custom server, stored in
// %APPDATA%\OpenDictate\settings.json without any secret.
internal sealed partial class PrototypeWindow
{
    private static readonly (string? Code, string Name)[] Languages =
    [
        ("de", "Deutsch"), ("en", "Englisch"), ("fr", "Französisch"), ("es", "Spanisch"), ("it", "Italienisch"),
        ("pt", "Portugiesisch"), ("nl", "Niederländisch"), ("pl", "Polnisch"), ("tr", "Türkisch"), ("uk", "Ukrainisch"),
    ];
    private sealed record LanguageChoice(string? Code, string Label);
    private readonly ComboBox spokenLanguage = new() { MinWidth = 250, DisplayMemberPath = nameof(LanguageChoice.Label), Margin = new Thickness(0, 4, 0, 8) };
    private readonly ComboBox translationTarget = new() { MinWidth = 250, DisplayMemberPath = nameof(LanguageChoice.Label), Margin = new Thickness(0, 4, 0, 8) };
    private readonly TextBox serverAddress = new() { MinWidth = 250, MaxLength = 512, Margin = new Thickness(0, 4, 0, 8) };
    private readonly TextBox transcriptionModel = new() { MinWidth = 250, MaxLength = 128, Margin = new Thickness(0, 4, 0, 8) };
    private readonly TextBox translationModel = new() { MinWidth = 250, MaxLength = 128, Margin = new Thickness(0, 4, 0, 8) };
    private readonly Button saveSettings = new() { Content = "Einstellungen speichern" };
    private DictationSettings storedSettings = DictationSettings.Default;
    private bool settingsReadable = true;

    private void AddDictationSettings(Panel panel)
    {
        spokenLanguage.Items.Add(new LanguageChoice(null, "Automatisch erkennen"));
        translationTarget.Items.Add(new LanguageChoice(null, "Aus"));
        foreach (var (code, name) in Languages)
        { spokenLanguage.Items.Add(new LanguageChoice(code, name)); translationTarget.Items.Add(new LanguageChoice(code, name)); }
        var fields = new StackPanel();
        AddField(fields, "Gesprochene Sprache", spokenLanguage);
        AddField(fields, "Übersetzung nach dem Sprechen", translationTarget);
        AddField(fields, $"Server-Adresse, z. B. http://127.0.0.1:8080/v1 (leer = OpenAI, oder {ProviderServer.BaseUrlVariable}, wenn gesetzt)", serverAddress);
        AddField(fields, "Transkriptionsmodell", transcriptionModel);
        AddField(fields, "Übersetzungsmodell", translationModel);
        fields.Children.Add(saveSettings);
        panel.Children.Add(new Expander { Header = "Sprache, Übersetzung und eigener Server", Content = fields, Margin = new Thickness(0, 0, 0, 8) });
        saveSettings.Click += (_, _) => SaveDictationSettings();
        try { storedSettings = SettingsFile.Load(SettingsFile.DefaultPath); }
        catch (UserFacingException error) { SetStatus(error.Message + " Gespeicherte Datei bleibt unverändert."); settingsReadable = false; saveSettings.IsEnabled = false; }
        ShowDictationSettings(storedSettings);
        // Name where dictations go when the address comes from the environment.
        if (settingsReadable && storedSettings.Server is null)
        {
            try
            {
                if (storedSettings.ResolveServer() is { IsCustom: true } server)
                    SetStatus($"{ProviderServer.BaseUrlVariable} ist gesetzt: Diktate gehen an {ServerName(server)}.");
            }
            catch (UserFacingException error) { SetStatus(error.Message); }
        }
    }

    private static void AddField(Panel panel, string label, Control field)
    {
        panel.Children.Add(new TextBlock { Text = label, TextWrapping = TextWrapping.Wrap });
        AutomationProperties.SetName(field, label);
        panel.Children.Add(field);
    }

    private void ShowDictationSettings(DictationSettings settings)
    {
        spokenLanguage.SelectedItem = Choose(spokenLanguage, settings.Language);
        translationTarget.SelectedItem = Choose(translationTarget, settings.TargetLanguage);
        serverAddress.Text = settings.Server ?? "";
        transcriptionModel.Text = settings.Model;
        translationModel.Text = settings.TranslationModel;
    }

    // A stored code outside the list stays selectable instead of being dropped.
    private static LanguageChoice Choose(ComboBox box, string? code)
    {
        var match = box.Items.OfType<LanguageChoice>().FirstOrDefault(choice => choice.Code == code);
        if (match is not null) return match;
        var added = new LanguageChoice(code, code!);
        box.Items.Add(added);
        return added;
    }

    private void SaveDictationSettings()
    {
        if (gate.IsBusy) return;
        string address = serverAddress.Text.Trim();
        try
        {
            var settings = (storedSettings with
            {
                Language = (spokenLanguage.SelectedItem as LanguageChoice)?.Code,
                Server = address.Length == 0 ? null : ProviderServer.Parse(address).Base,
                Model = transcriptionModel.Text.Trim(),
                TranslationModel = translationModel.Text.Trim(),
            }).WithTarget((translationTarget.SelectedItem as LanguageChoice)?.Code);
            var server = settings.ResolveServer();
            try { DictationSettings.ValidateModelFor(settings.Model, server); }
            catch (UserFacingException error)
            { throw new UserFacingException($"{error.Message} Das Transkriptionsmodell passt nicht zu {ServerName(server)}."); }
            SettingsFile.Save(SettingsFile.DefaultPath, settings);
            storedSettings = settings;
            ShowDictationSettings(settings);
            SetStatus(server.LacksPath
                ? "Einstellungen gespeichert. Die Server-Adresse hat keinen Pfad; meist fehlt /v1."
                : $"Einstellungen gespeichert. Diktate gehen an {ServerName(server)}.");
        }
        catch (UserFacingException error) { SetStatus(error.Message + " Einstellungen nicht gespeichert."); }
    }
}
