using System.Net.Http.Headers;
using System.Text.Json;
using OpenDictate.Core;

namespace OpenDictate.Windows;

// No retries, redirects, cookies or provider response bodies in diagnostics.
// The caller supplies the exact authenticated bytes and retains the recovery copy.
public sealed class OpenAiTranscriber : IDisposable
{
    private readonly HttpClient client;
    public OpenAiTranscriber() : this(new HttpClientHandler { AllowAutoRedirect = false, UseCookies = false }) { }
    // Injection is for deterministic offline checks, never an alternate endpoint.
    public OpenAiTranscriber(HttpMessageHandler handler)
    { client = new HttpClient(handler) { Timeout = TimeSpan.FromSeconds(60) }; }

    public async Task<string> TranscribeAsync(ReadOnlyMemory<byte> verifiedWave, string key, CancellationToken token)
    {
        DictationFlow.ValidateWave(verifiedWave.Span);
        if (key.Length is < 8 or > 2048 || key.Any(c => c < 33 || c > 126))
            throw new ArgumentException("Invalid credential format.");
        token.ThrowIfCancellationRequested();
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(token);
        timeout.CancelAfter(TimeSpan.FromSeconds(60));
        using var request = new HttpRequestMessage(HttpMethod.Post, "https://api.openai.com/v1/audio/transcriptions");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", key);
        using var form = new MultipartFormDataContent();
        form.Add(new StringContent("gpt-transcribe"), "model");
        form.Add(new StringContent("json"), "response_format");
        var audio = new ReadOnlyMemoryContent(verifiedWave);
        audio.Headers.ContentType = new MediaTypeHeaderValue("audio/wav");
        form.Add(audio, "file", "recording.wav"); request.Content = form;
        using var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, timeout.Token);
        if (!response.IsSuccessStatusCode) throw new TranscriptionException((int)response.StatusCode);
        const int limit = 131072;
        if (response.Content.Headers.ContentLength > limit) throw new InvalidDataException("Response too large.");
        using var stream = await response.Content.ReadAsStreamAsync(timeout.Token);
        using var buffer = new MemoryStream(); var chunk = new byte[8192];
        int count;
        while ((count = await stream.ReadAsync(chunk, timeout.Token)) != 0)
        {
            if (buffer.Length + count > limit) throw new InvalidDataException("Response too large.");
            buffer.Write(chunk, 0, count);
        }
        timeout.Token.ThrowIfCancellationRequested();
        using var document = JsonDocument.Parse(buffer.ToArray(), new JsonDocumentOptions { MaxDepth = 16 });
        if (document.RootElement.ValueKind != JsonValueKind.Object ||
            !document.RootElement.TryGetProperty("text", out var value) || value.ValueKind != JsonValueKind.String)
            throw new InvalidDataException("Invalid transcription response.");
        string text = value.GetString()!;
        if (string.IsNullOrWhiteSpace(text) || text.Length > 16000) throw new InvalidDataException("Empty or oversized transcription.");
        return text;
    }
    public void Dispose() => client.Dispose();
}

public sealed class TranscriptionException(int statusCode) : Exception("Transcription request failed.")
{ public int StatusCode { get; } = statusCode; }
