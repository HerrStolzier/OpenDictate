using System.Net;
using OpenDictate.Windows;

internal static class ProviderChecks
{
    internal static void Run(byte[] wave, Action<string, Action> test)
    {
        test("Provider request uses exact verified bytes and fixed endpoint", () =>
        {
            var handler = new FixtureHandler(async (request, token) =>
            {
                Check(request.Method == HttpMethod.Post && request.RequestUri!.AbsoluteUri == "https://api.openai.com/v1/audio/transcriptions");
                Check(request.Headers.Authorization?.Scheme == "Bearer" && request.Headers.Authorization.Parameter == "synthetic-not-a-key");
                var parts = ((MultipartFormDataContent)request.Content!).ToArray();
                Check(parts.Length == 3 && await parts[0].ReadAsStringAsync(token) == "gpt-transcribe" && await parts[1].ReadAsStringAsync(token) == "json");
                Check((await parts[2].ReadAsByteArrayAsync(token)).AsSpan().SequenceEqual(wave));
                Check(parts[2].Headers.ContentDisposition!.FileName!.Trim('"') == "recording.wav");
                return Response(200, "{\"text\":\"Künstliche Antwort äöü.\"}");
            });
            using var adapter = new OpenAiTranscriber(handler);
            Check(adapter.TranscribeAsync(wave, "synthetic-not-a-key", default).GetAwaiter().GetResult() == "Künstliche Antwort äöü." && handler.Calls == 1);
        });
        test("Provider failures and redirects never retry or expose response bodies", () =>
        {
            foreach (int status in new[] {301, 401, 429, 500})
            {
                var handler = new FixtureHandler((_, _) => Task.FromResult(Response(status, "private synthetic error body")));
                using var adapter = new OpenAiTranscriber(handler);
                try { adapter.TranscribeAsync(wave, "synthetic-not-a-key", default).GetAwaiter().GetResult(); throw new InvalidOperationException(); }
                catch (TranscriptionException error) { Check(error.StatusCode == status && !error.Message.Contains("private")); }
                Check(handler.Calls == 1);
            }
        });
        test("Provider rejects malformed, empty and oversized replies", () =>
        {
            foreach (string body in new[] { "not json", "{}", "{\"text\":12}", "{\"text\":\" \"}", "{\"text\":\"" + new string('a', 16001) + "\"}", new string('a', 131073) })
            {
                var handler = new FixtureHandler((_, _) => Task.FromResult(Response(200, body)));
                using var adapter = new OpenAiTranscriber(handler);
                Throws(() => adapter.TranscribeAsync(wave, "synthetic-not-a-key", default).GetAwaiter().GetResult()); Check(handler.Calls == 1);
            }
        });
        test("Invalid audio and credential are rejected before any request", () =>
        {
            var handler = new FixtureHandler((_, _) => throw new InvalidOperationException()); using var adapter = new OpenAiTranscriber(handler);
            Throws(() => adapter.TranscribeAsync(new byte[4], "synthetic-not-a-key", default).GetAwaiter().GetResult());
            Throws(() => adapter.TranscribeAsync(wave, "synthetic\r\nkey", default).GetAwaiter().GetResult()); Check(handler.Calls == 0);
        });
        test("Provider cancellation interrupts the request without retry", () =>
        {
            using var cancellation = new CancellationTokenSource();
            var handler = new FixtureHandler(async (_, token) => { cancellation.Cancel(); await Task.Delay(10000, token); return Response(200, "{}"); });
            using var adapter = new OpenAiTranscriber(handler);
            try { adapter.TranscribeAsync(wave, "synthetic-not-a-key", cancellation.Token).GetAwaiter().GetResult(); throw new InvalidOperationException(); }
            catch (OperationCanceledException) { Check(handler.Calls == 1); }
        });
    }
    private static HttpResponseMessage Response(int code, string body) => new((HttpStatusCode)code) { Content = new StringContent(body) };
    private static void Check(bool value) { if (!value) throw new InvalidOperationException("Provider assertion failed."); }
    private static void Throws(Action action) { try { action(); } catch (Exception) { return; } throw new InvalidOperationException("Expected refusal."); }
    private sealed class FixtureHandler(Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> send) : HttpMessageHandler
    {
        internal int Calls { get; private set; }
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken token) { Calls++; return send(request, token); }
    }
}
