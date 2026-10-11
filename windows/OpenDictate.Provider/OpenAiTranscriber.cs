using System.Text.Json;
using OpenDictate.Core;

namespace OpenDictate.Provider;

// Uploads the exact authenticated bytes once; the caller retains the recovery
// copy. Request format: fixtures/provider/CONTRACT.md.
public sealed class OpenAiTranscriber : IDisposable
{
    private const int ResponseLimit = 131072;
    private readonly HttpClient client;
    private readonly ProviderServer server;

    public OpenAiTranscriber(ProviderServer server) : this(server, ProviderHttp.DefaultHandler(), ownsHandler: true) { }
    // An injected handler serves deterministic offline checks and stays owned by the caller.
    public OpenAiTranscriber(ProviderServer server, HttpMessageHandler handler) : this(server, handler, ownsHandler: false) { }
    private OpenAiTranscriber(ProviderServer server, HttpMessageHandler handler, bool ownsHandler)
    { this.server = server; client = new HttpClient(handler, ownsHandler) { Timeout = Timeout.InfiniteTimeSpan }; }

    // OpenAI answers a 90-second recording within seconds; a local model on
    // the CPU needs far longer.
    public TimeSpan Deadline => server.IsCustom ? TimeSpan.FromSeconds(180) : TimeSpan.FromSeconds(60);

    public async Task<string> TranscribeAsync(ReadOnlyMemory<byte> verifiedWave, string? key, DictationSettings settings, CancellationToken token)
    {
        DictationFlow.ValidateWave(verifiedWave.Span);
        DictationSettings.ValidateModelFor(settings.Model, server);
        if (settings.Language is not null) DictationSettings.ValidateLanguage(settings.Language);
        token.ThrowIfCancellationRequested();
        using var request = new HttpRequestMessage(HttpMethod.Post, server.TranscriptionUri);
        ProviderHttp.Authorize(request, server, key);
        using var form = new MultipartFormDataContent();
        form.Add(new StringContent(settings.Model), "model");
        form.Add(new StringContent("json"), "response_format");
        if (settings.Language is not null)
            form.Add(new StringContent(settings.Language), settings.Model == DictationSettings.DefaultModel ? "languages[]" : "language");
        var audio = new ReadOnlyMemoryContent(verifiedWave);
        audio.Headers.ContentType = new("audio/wav");
        form.Add(audio, "file", "recording.wav");
        request.Content = form;
        using var document = await ProviderHttp.SendAsync(client, request, server, Deadline, ResponseLimit, StatusMessage,
            UiText.T("Netzwerkfehler oder Zeitüberschreitung bei der Transkription.", "Network error or timeout during transcription."), token);
        if (document.RootElement.ValueKind != JsonValueKind.Object ||
            !document.RootElement.TryGetProperty("text", out var value) || value.ValueKind != JsonValueKind.String)
            throw ProviderHttp.InvalidResponse();
        // An empty result is returned as is: the flow keeps the recording.
        string text = value.GetString()!.Trim();
        if (text.Length > 16000) throw ProviderHttp.InvalidResponse();
        return text;
    }

    private string StatusMessage(int status) => status switch
    {
        401 or 403 when !server.SendsApiKey => UiText.T(
            "Der Server verlangt eine Anmeldung; an Adressen auf diesem Computer sendet OpenDictate keinen API-Schlüssel.",
            "The server asks for a login; OpenDictate sends no API key to addresses on this computer."),
        401 => UiText.T("API-Schlüssel ist ungültig.", "API key is invalid."),
        404 when server.IsCustom => UiText.T(
            "Der Server kennt diese Adresse oder dieses Modell nicht. Server-Adresse (mit /v1) und Modellnamen prüfen.",
            "The server does not know this address or model. Check the server address (with /v1) and the model name."),
        413 => UiText.T("Aufnahme ist für den Upload zu groß.", "Recording is too large to upload."),
        429 when server.IsCustom => UiText.T("Der Server ist ausgelastet. Bitte später erneut versuchen.", "The server is busy. Please try again later."),
        429 => UiText.T("OpenAI-Limit erreicht oder Guthaben aufgebraucht. Bitte später erneut versuchen.",
            "OpenAI limit reached or credit used up. Please try again later."),
        >= 500 and <= 599 => UiText.T("Der Dienst ist gerade nicht verfügbar. Bitte später erneut versuchen.",
            "The service is not available right now. Please try again later."),
        _ => UiText.T("Transkription fehlgeschlagen.", "Transcription failed."),
    };

    public void Dispose() => client.Dispose();
}
