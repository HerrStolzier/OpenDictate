using System.Net.Http.Headers;
using System.Text.Json;
using OpenDictate.Core;

namespace OpenDictate.Provider;

// Shared transport rules for transcription and translation: no retries,
// redirects or cookies, bounded replies, and messages that never contain a
// provider body.
internal static class ProviderHttp
{
    internal static HttpMessageHandler DefaultHandler() =>
        new SocketsHttpHandler { AllowAutoRedirect = false, UseCookies = false, ConnectTimeout = TimeSpan.FromSeconds(10) };

    // The key for this server: required for OpenAI and other remote servers,
    // never sent to an address on this computer.
    internal static void Authorize(HttpRequestMessage request, ProviderServer server, string? key)
    {
        if (!server.SendsApiKey) return;
        if (string.IsNullOrEmpty(key)) throw new UserFacingException(UiText.T("API-Schlüssel fehlt.", "API key is missing."));
        if (key.Length is < 8 or > 2048 || key.Any(c => c < 33 || c > 126))
            throw new UserFacingException(UiText.T("Der gespeicherte API-Schlüssel hat ein ungültiges Format.", "The stored API key has an invalid format."));
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", key);
    }

    // Sends once within an overall deadline. The caller's cancellation stays
    // a cancellation; the deadline and transport failures become a message.
    internal static async Task<JsonDocument> SendAsync(HttpClient client, HttpRequestMessage request, ProviderServer server,
        TimeSpan deadline, int limit, Func<int, string> statusMessage, string networkMessage, CancellationToken token)
    {
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(token);
        timeout.CancelAfter(deadline);
        try
        {
            using var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, timeout.Token);
            if (!response.IsSuccessStatusCode) throw new ProviderStatusException((int)response.StatusCode, statusMessage((int)response.StatusCode));
            if (response.Content.Headers.ContentLength > limit) throw InvalidResponse();
            using var stream = await response.Content.ReadAsStreamAsync(timeout.Token);
            using var buffer = new MemoryStream(); var chunk = new byte[8192];
            int count;
            while ((count = await stream.ReadAsync(chunk, timeout.Token)) != 0)
            {
                if (buffer.Length + count > limit) throw InvalidResponse();
                buffer.Write(chunk, 0, count);
            }
            try { return JsonDocument.Parse(buffer.ToArray(), new JsonDocumentOptions { MaxDepth = 16 }); }
            catch (JsonException) { throw InvalidResponse(); }
        }
        catch (OperationCanceledException) when (!token.IsCancellationRequested) { throw Network(server, networkMessage); }
        catch (HttpRequestException) { throw Network(server, networkMessage); }
        catch (IOException) when (!token.IsCancellationRequested) { throw Network(server, networkMessage); }
    }

    internal static UserFacingException InvalidResponse() =>
        new(UiText.T("Ungültige Antwort vom Server.", "Invalid response from the server."));

    private static UserFacingException Network(ProviderServer server, string message) => server.IsCustom
        ? new(UiText.T($"Dein Server ({server.Host}) ist nicht erreichbar oder zu langsam. Prüf, ob er läuft, und versuch es nochmal.",
            $"Your server ({server.Host}) is unreachable or too slow. Check that it is running and try again."))
        : new(message);
}

// A non-2xx reply. The message is chosen by status code and server kind.
public sealed class ProviderStatusException(int statusCode, string message) : UserFacingException(message)
{
    public int StatusCode { get; } = statusCode;
}
