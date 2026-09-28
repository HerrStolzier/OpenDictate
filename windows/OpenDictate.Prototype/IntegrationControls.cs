using System;
using System.IO;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Threading;
using OpenDictate.Windows;

namespace OpenDictate.Prototype;

internal sealed partial class PrototypeWindow
{
    private readonly CheckBox liveFlow = new() { Content = "OpenAI-Transkription aktivieren (Audio-Upload, kostenpflichtig)" };
    private readonly CheckBox simulateFailure = new() { Content = "Lokalen Anbieterfehler simulieren (ohne Upload)", IsEnabled = false };
    private readonly PasswordBox apiKey = new() { MaxLength = 2048, MinWidth = 250, Margin = new Thickness(0, 4, 8, 4) };
    private readonly Button saveKey = new() { Content = "Schlüssel speichern" };
    private readonly Button deleteKey = new() { Content = "Gespeicherten Schlüssel entfernen" };
    private readonly ComboBox recoveries = new() { MinWidth = 250, DisplayMemberPath = nameof(RecoveryChoice.Label) };
    private readonly Button retry = new() { Content = "Ausgewählte Aufnahme erneut verarbeiten" };
    private readonly Button refreshRecovery = new() { Content = "Wiederherstellungen aktualisieren" };
    private readonly TextBlock recoveryStatus = new() { TextWrapping = TextWrapping.Wrap };
    private readonly DispatcherTimer retentionClock = new() { Interval = TimeSpan.FromMinutes(1) };
    private sealed record RecoveryChoice(Guid Id, string Label);

    private void AddIntegrationControls(Panel panel)
    {
        panel.Children.Add(liveFlow);
        panel.Children.Add(simulateFailure);
        var settings = new StackPanel();
        settings.Children.Add(new TextBlock { Text = "API-Schlüssel nur hier eingeben. Speicherung in der Windows-Anmeldeinformationsverwaltung.", TextWrapping = TextWrapping.Wrap });
        AutomationProperties.SetName(apiKey, "OpenAI API-Schlüssel");
        settings.Children.Add(apiKey);
        var buttons = new WrapPanel(); buttons.Children.Add(saveKey); buttons.Children.Add(deleteKey); settings.Children.Add(buttons);
        panel.Children.Add(new Expander { Header = "API-Schlüssel verwalten", Content = settings, Margin = new Thickness(0, 8, 0, 8) });
        var recoveryPanel = new StackPanel();
        recoveryPanel.Children.Add(recoveryStatus); recoveryPanel.Children.Add(recoveries);
        AutomationProperties.SetName(recoveries, "Geschützte Aufnahmen");
        recoveryPanel.Children.Add(refreshRecovery); recoveryPanel.Children.Add(retry);
        AddText(recoveryPanel, "Lokaler Testmodus zeigt nur künstliche Testkopien. OpenAI-Modus zeigt echte geschützte Aufnahmen. Wiederholen startet keine neue Aufnahme und fügt niemals automatisch ein. Ungültige oder abgelaufene Dateien sind nicht auswählbar.");
        panel.Children.Add(new Expander { Header = "Geschützte Wiederherstellung", Content = recoveryPanel, IsExpanded = true });
        offlineFlow.Checked += async (_, _) => { liveFlow.IsChecked = false; simulateFailure.IsEnabled = true; await RefreshRecoveryAsync(); };
        offlineFlow.Unchecked += async (_, _) => { simulateFailure.IsChecked = false; simulateFailure.IsEnabled = false; await RefreshRecoveryAsync(); };
        liveFlow.Checked += async (_, _) => { offlineFlow.IsChecked = false; await RefreshRecoveryAsync(); };
        liveFlow.Unchecked += async (_, _) => await RefreshRecoveryAsync();
        saveKey.Click += (_, _) =>
        {
            if (gate.IsBusy) return;
            try { new CredentialStore().Save(apiKey.Password); apiKey.Clear(); SetStatus("Schlüssel in Windows gespeichert. Es wurde keine Anfrage gesendet."); }
            catch (ArgumentException) { apiKey.Clear(); SetStatus("Schlüssel nicht gespeichert. Bitte einen gültigen API-Schlüssel ohne Leerzeichen eingeben."); }
            catch (Exception) { apiKey.Clear(); SetStatus("Schlüssel konnte nicht gespeichert werden. Es wurde keine Anfrage gesendet."); }
        };
        deleteKey.Click += (_, _) =>
        {
            if (gate.IsBusy) return;
            try { new CredentialStore().Delete(); apiKey.Clear(); liveFlow.IsChecked = false; SetStatus("OpenDictate-Schlüssel aus Windows entfernt."); }
            catch (Exception) { SetStatus("Schlüssel konnte nicht entfernt werden."); }
        };
        refreshRecovery.Click += async (_, _) => await RefreshRecoveryAsync();
        recoveries.SelectionChanged += (_, _) => retry.IsEnabled = !gate.IsBusy && recoveries.SelectedItem is RecoveryChoice;
        retry.Click += (_, _) =>
        {
            if (gate.IsBusy || recoveries.SelectedItem is not RecoveryChoice selected) return;
            if (offlineFlow.IsChecked != true && liveFlow.IsChecked != true) return;
            dictationOperation = RunDictationAsync(synthetic: offlineFlow.IsChecked == true, recoveryId: selected.Id);
        };
        retentionClock.Tick += async (_, _) => { if (!closing) await RefreshRecoveryAsync(); };
        Closed += (_, _) => { retentionClock.Stop(); apiKey.Clear(); };
        retentionClock.Start();
        retry.IsEnabled = false;
        recoveryStatus.Text = "Für die Liste einen Verarbeitungsmodus auswählen.";
    }

    private RecoveryStore GetRecoveryStore(bool offline) => new(Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "OpenDictatePrototype",
        offline ? "SyntheticRecovery" : "Recovery"));

    private Task RefreshRecoveryAsync()
    {
        if (gate.IsBusy || closing) return Task.CompletedTask;
        var previous = recoveries.SelectedItem as RecoveryChoice;
        recoveries.Items.Clear();
        if (offlineFlow.IsChecked != true && liveFlow.IsChecked != true)
        { recoveryStatus.Text = "Für die Liste einen Verarbeitungsmodus auswählen."; retry.IsEnabled = false; return Task.CompletedTask; }
        try
        {
            var store = GetRecoveryStore(offlineFlow.IsChecked == true);
            store.Prune();
            foreach (var entry in store.List())
            {
                var item = new RecoveryChoice(entry.Id, entry.Created.ToLocalTime().ToString("dd.MM.yyyy HH:mm:ss"));
                recoveries.Items.Add(item); if (item.Id == previous?.Id) recoveries.SelectedItem = item;
            }
            if (recoveries.SelectedIndex < 0 && recoveries.Items.Count > 0) recoveries.SelectedIndex = 0;
            recoveryStatus.Text = $"{recoveries.Items.Count} gültige geschützte Aufnahme(n) · maximal 5 · Zugriff bis 24 Stunden";
        }
        catch (Exception) { recoveryStatus.Text = "Wiederherstellung nicht verfügbar. Vorhandene Originale bleiben erhalten."; }
        retry.IsEnabled = recoveries.SelectedItem is RecoveryChoice;
        return Task.CompletedTask;
    }

    private void SetIntegrationBusy(bool busy)
    {
        offlineFlow.IsEnabled = liveFlow.IsEnabled = apiKey.IsEnabled = saveKey.IsEnabled = deleteKey.IsEnabled = !busy;
        simulateFailure.IsEnabled = !busy && offlineFlow.IsChecked == true;
        recoveries.IsEnabled = refreshRecovery.IsEnabled = !busy;
        retry.IsEnabled = !busy && recoveries.SelectedItem is RecoveryChoice;
    }
}
