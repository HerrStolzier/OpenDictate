namespace OpenDictate.Provider;

// One dictation's provider work: transcription, then the optional translation
// into the chosen target language. Both go to the same server with the same
// key rule; a failure in either keeps the recording with the caller.
public sealed class ProviderSession : IDisposable
{
    private readonly OpenAiTranscriber transcriber;
    private readonly Translator translator;

    public ProviderSession(ProviderServer server) { transcriber = new(server); translator = new(server); }
    public ProviderSession(ProviderServer server, HttpMessageHandler handler) { transcriber = new(server, handler); translator = new(server, handler); }

    public async Task<string> ProcessAsync(ReadOnlyMemory<byte> verifiedWave, string? key, DictationSettings settings, CancellationToken token)
    {
        string text = await transcriber.TranscribeAsync(verifiedWave, key, settings, token);
        if (text.Length == 0 || settings.TargetLanguage is not { } target) return text;
        token.ThrowIfCancellationRequested();
        return await translator.TranslateAsync(text, target, settings.TranslationModel, key, token);
    }

    public void Dispose() { transcriber.Dispose(); translator.Dispose(); }
}
