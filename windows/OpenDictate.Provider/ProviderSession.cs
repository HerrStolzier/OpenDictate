using System.Diagnostics;
using System.Text.Json;
using OpenDictate.Core;

namespace OpenDictate.Provider;

// One dictation's provider work, followed by optional local metadata accounting.
// Failed, empty and cancelled provider work leaves no completed usage entry.
public sealed class ProviderSession : IDisposable
{
    private readonly OpenAiTranscriber transcriber;
    private readonly Translator translator;
    private readonly ProviderServer server;
    private readonly UsageLedger? ledger;

    public ProviderSession(ProviderServer server)
    {
        this.server = server; transcriber = new(server); translator = new(server);
        ledger = new(Path.Combine(Path.GetDirectoryName(SettingsFile.DefaultPath)!, "usage.json"));
    }
    // An injected transport never touches the user's ledger implicitly.
    public ProviderSession(ProviderServer server, HttpMessageHandler handler, UsageLedger? ledger = null)
    { this.server = server; this.ledger = ledger; transcriber = new(server, handler); translator = new(server, handler); }

    public async Task<string> ProcessAsync(ReadOnlyMemory<byte> verifiedWave, string? key, DictationSettings settings, CancellationToken token)
    {
        string text = await transcriber.TranscribeAsync(verifiedWave, key, settings, token);
        UsageTranslation? usage = null;
        if (text.Length > 0 && settings.TargetLanguage is { } target)
        {
            token.ThrowIfCancellationRequested();
            var result = await translator.TranslateWithUsageAsync(text, target, settings.TranslationModel, key, token);
            text = result.Text;
            usage = new(settings.TranslationModel, result.InputTokens, result.OutputTokens);
        }
        token.ThrowIfCancellationRequested();
        string? receipt = null;
        try
        {
            if (ledger is not null && !string.IsNullOrWhiteSpace(TranscriptText.Sanitize(text)))
            {
                try
                {
                    receipt = await ledger.RecordAsync(server.IsCustom, settings.Model,
                        (verifiedWave.Length - 44) / (PcmJournal.SampleRate * 2.0), usage, token).ConfigureAwait(false);
                }
                catch (Exception error) when (error is InvalidDataException or IOException or UnauthorizedAccessException or JsonException)
                { Trace.TraceWarning("usage-write-failed"); } // Accounting failure never loses recognized text.
            }
            token.ThrowIfCancellationRequested();
            return text;
        }
        catch (OperationCanceledException)
        {
            if (receipt is not null && ledger is not null)
            {
                try { await ledger.RemoveAsync(receipt).ConfigureAwait(false); }
                catch (Exception error) when (error is InvalidDataException or IOException or UnauthorizedAccessException or JsonException)
                { Trace.TraceWarning("usage-rollback-failed"); }
            }
            throw;
        }
    }

    public void Dispose() { transcriber.Dispose(); translator.Dispose(); }
}
