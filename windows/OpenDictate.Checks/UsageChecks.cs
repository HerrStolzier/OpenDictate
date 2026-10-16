using System.Net;
using System.Text;
using System.Text.Json;
using OpenDictate.Core;
using OpenDictate.Provider;

// Fixed clocks, temporary files and in-process HTTP answers only.
internal static class UsageChecks
{
    private static readonly JsonSerializerOptions Json = new() { PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower };
    internal static async Task<int> RunAsync(byte[] wave)
    {
        var tests = new (string, Func<string, Task>)[]
        {
            ("Shared Linux examples have identical totals and unknown costs", _ =>
            {
                using var fixture = JsonDocument.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "fixtures", "pricing", "examples.json")));
                var root = fixture.RootElement;
                var entries = root.GetProperty("entries").Deserialize<UsageEntry[]>(Json)!;
                var bounds = root.GetProperty("bounds").Deserialize<UsageBounds>(Json);
                var totals = UsageLedger.Calculate(entries, root.GetProperty("now").GetInt64(), bounds);
                var expected = root.GetProperty("expected").EnumerateArray().ToArray();
                for (int i = 0; i < totals.Length; i++)
                {
                    Check(totals[i].Dictations == expected[i].GetProperty("dictations").GetInt32());
                    Check(totals[i].AudioSeconds == expected[i].GetProperty("audio_seconds").GetDouble());
                    var cost = expected[i].GetProperty("cost_usd");
                    Check(cost.ValueKind == JsonValueKind.Null ? totals[i].CostUsd is null : Math.Abs(totals[i].CostUsd!.Value - cost.GetDouble()) < 1e-12);
                }
                var missing = new UsageEntry(9000, false, "gpt-transcribe", 60, new("gpt-5.4-mini", null, 20));
                Check(UsageLedger.Calculate([missing], 10000, bounds)[0].CostUsd is null);
                Check(UsageLedger.Calculate([missing with { Custom = true }], 10000, bounds)[0].CostUsd == 0);
                return Task.CompletedTask;
            }),
            ("Calendar windows, month clamping and strict retention use the injected clock", async root =>
            {
                var now = new DateTimeOffset(2026, 3, 31, 12, 30, 0, TimeSpan.Zero);
                var clock = new FixedClock(now);
                string path = Path.Combine(root, "usage.json");
                var ledger = new UsageLedger(path, clock, TimeZoneInfo.Utc);
                long stamp = now.ToUnixTimeSeconds();
                var bounds = UsageLedger.BoundsFor(now, TimeZoneInfo.Utc);
                Check(bounds.Retention == new DateTimeOffset(2025, 2, 28, 12, 30, 0, TimeSpan.Zero).ToUnixTimeSeconds());
                Check(bounds.Today == stamp - 12 * 3600 - 30 * 60 && bounds.Week == bounds.Today - 6 * 86400);
                File.WriteAllText(path, JsonSerializer.Serialize(new[] {
                    new UsageEntry(bounds.Retention - 1, false, "whisper-1", 60),
                    new UsageEntry(bounds.Retention, false, "whisper-1", 60),
                    new UsageEntry(bounds.Today - 1, false, "whisper-1", 60),
                    new UsageEntry(stamp + 1, false, "whisper-1", 60) }, Json));
                await ledger.RecordAsync(false, "gpt-transcribe", 30, null);
                var totals = await ledger.TotalsAsync();
                Check(totals[0].Dictations == 1 && totals[1].Dictations == 2 && totals[2].Dictations == 2);
                var kept = JsonSerializer.Deserialize<UsageEntry[]>(File.ReadAllText(path), Json)!;
                Check(kept.Length == 4 && kept.Any(e => e.Timestamp == bounds.Retention));
                var east = TimeZoneInfo.CreateCustomTimeZone("Fixture+2", TimeSpan.FromHours(2), "Fixture", "Fixture");
                Check(UsageLedger.BoundsFor(new DateTimeOffset(2026, 3, 31, 23, 0, 0, TimeSpan.Zero), east).Today ==
                    new DateTimeOffset(2026, 3, 31, 22, 0, 0, TimeSpan.Zero).ToUnixTimeSeconds());
                var midnightRule = TimeZoneInfo.AdjustmentRule.CreateAdjustmentRule(new DateTime(2020, 1, 1), new DateTime(2030, 12, 31), TimeSpan.FromHours(1),
                    TimeZoneInfo.TransitionTime.CreateFloatingDateRule(new DateTime(1, 1, 1), 3, 2, DayOfWeek.Sunday),
                    TimeZoneInfo.TransitionTime.CreateFloatingDateRule(new DateTime(1, 1, 1), 11, 1, DayOfWeek.Sunday));
                var midnightZone = TimeZoneInfo.CreateCustomTimeZone("Fixture-midnight-DST", TimeSpan.Zero, "Fixture", "Fixture", "Fixture DST", [midnightRule]);
                Check(UsageLedger.BoundsFor(new DateTimeOffset(2026, 3, 8, 0, 30, 0, TimeSpan.Zero), midnightZone).Today ==
                    new DateTimeOffset(2026, 3, 8, 0, 0, 0, TimeSpan.Zero).ToUnixTimeSeconds());
                await ledger.ResetAsync(); Check((await ledger.TotalsAsync()).All(t => t.Dictations == 0 && t.CostUsd == 0));
            }),
            ("Independent ledger instances serialize writes and rollback only their receipt", async root =>
            {
                string path = Path.Combine(root, "usage.json");
                var one = new UsageLedger(path); var two = new UsageLedger(path);
                Task<string>[] pending;
                using (var blocker = new FileStream(path + ".lock", FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None))
                {
                    pending = Enumerable.Range(0, 20).Select(i => (i % 2 == 0 ? one : two).RecordAsync(true, "local", 1, null)).ToArray();
                    Check(pending.All(task => !task.IsCompleted));
                }
                var receipts = await Task.WhenAll(pending);
                Check((await one.TotalsAsync())[0].Dictations == 20);
                await two.RemoveAsync(receipts[3]);
                Check((await one.TotalsAsync())[0].Dictations == 19);
                Check(Directory.GetFiles(root, "*.tmp").Length == 0);
                if (!OperatingSystem.IsWindows()) Check(File.GetUnixFileMode(path) == (UnixFileMode.UserRead | UnixFileMode.UserWrite));
            }),
            ("Damaged ledgers survive refused writes", async root =>
            {
                string path = Path.Combine(root, "usage.json");
                foreach (string damaged in new[] { "broken", "[null]", "[{\"timestamp\":0,\"model\":\"x\",\"audio_seconds\":-1}]" })
                {
                    File.WriteAllText(path, damaged);
                    await Refused(() => new UsageLedger(path).RecordAsync(false, "gpt-transcribe", 1, null));
                    Check(File.ReadAllText(path) == damaged);
                }
            }),
            ("Provider counts successful transcription and translation usage, never dictated contents", async root =>
            {
                string path = Path.Combine(root, "usage.json");
                var ledger = new UsageLedger(path);
                var handler = new Answers(_ => Reply("{\"text\":\"Private fixture sentence\"}"), _ => Reply("{\"choices\":[{\"message\":{\"content\":\"Private translation\"}}],\"usage\":{\"prompt_tokens\":1000,\"completion_tokens\":200}}"));
                using var session = new ProviderSession(ProviderServer.OpenAi, handler, ledger);
                Check(await session.ProcessAsync(wave, "synthetic-not-a-key", new DictationSettings { TargetLanguage = "en" }, default) == "Private translation");
                var total = (await ledger.TotalsAsync())[0];
                double seconds = (wave.Length - 44) / 32000.0;
                Check(total.Dictations == 1 && total.AudioSeconds == seconds && Math.Abs(total.CostUsd!.Value - (seconds / 60 * .0045 + .00165)) < 1e-12);
                string saved = File.ReadAllText(path);
                Check(!saved.Contains("Private") && !saved.Contains("synthetic") && !saved.Contains("recording.wav") && !saved.Contains("https"));
                foreach (string usage in new[] { "", ",\"usage\":{\"prompt_tokens\":\"bad\",\"completion_tokens\":1}" })
                {
                    await ledger.ResetAsync();
                    using var missing = new ProviderSession(ProviderServer.OpenAi, new Answers(_ => Reply("{\"text\":\"Hallo\"}"), _ => Reply("{\"choices\":[{\"message\":{\"content\":\"Hello\"}}]" + usage + "}")), ledger);
                    await missing.ProcessAsync(wave, "synthetic-not-a-key", new DictationSettings { TargetLanguage = "en" }, default);
                    Check((await ledger.TotalsAsync())[0].CostUsd is null);
                }
            }),
            ("Failed, empty and cancelled provider work never counts; custom work costs zero", async root =>
            {
                var ledger = new UsageLedger(Path.Combine(root, "usage.json"));
                foreach (var response in new[] { Reply("{\"text\":\"\"}"), Reply("{}", 503) })
                {
                    using var session = new ProviderSession(ProviderServer.OpenAi, new Answers(_ => response), ledger);
                    try { await session.ProcessAsync(wave, "synthetic-not-a-key", new(), default); } catch (UserFacingException) { }
                    Check((await ledger.TotalsAsync())[0].Dictations == 0);
                }
                using (var failed = new ProviderSession(ProviderServer.OpenAi, new Answers(_ => Reply("{\"text\":\"Hallo\"}"), _ => Reply("{}", 503)), ledger))
                    await Refused(() => failed.ProcessAsync(wave, "synthetic-not-a-key", new() { TargetLanguage = "en" }, default));
                using var cancellation = new CancellationTokenSource();
                using (var cancelled = new ProviderSession(ProviderServer.OpenAi, new Answers(_ => { cancellation.Cancel(); throw new OperationCanceledException(cancellation.Token); }), ledger))
                    await Refused(() => cancelled.ProcessAsync(wave, "synthetic-not-a-key", new(), cancellation.Token));
                Check((await ledger.TotalsAsync())[0].Dictations == 0);
                using var local = new ProviderSession(ProviderServer.Parse("http://127.0.0.1:8080/v1"), new Answers(_ => Reply("{\"text\":\"Lokal\"}")), ledger);
                await local.ProcessAsync(wave, null, new() { Model = "local-model" }, default);
                Check((await ledger.TotalsAsync())[0] is { Dictations: 1, CostUsd: 0 });
            }),
            ("Accounting failure keeps text and cancellation while waiting for the ledger adds nothing", async root =>
            {
                string path = Path.Combine(root, "usage.json");
                var ledger = new UsageLedger(path);
                foreach (string damaged in new[] { "broken", "[null]", "[{\"timestamp\":0,\"model\":\"x\",\"audio_seconds\":-1}]" })
                {
                    File.WriteAllText(path, damaged);
                    using var session = new ProviderSession(ProviderServer.OpenAi, new Answers(_ => Reply("{\"text\":\"Hello\"}")), ledger);
                    Check(await session.ProcessAsync(wave, "synthetic-not-a-key", new(), default) == "Hello");
                    Check(File.ReadAllText(path) == damaged);
                }
                File.Delete(path);
                using var blocker = new FileStream(path + ".lock", FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
                using var cancellation = new CancellationTokenSource();
                using var cancelled = new ProviderSession(ProviderServer.OpenAi, new Answers(_ => Reply("{\"text\":\"Hello\"}")), ledger);
                var pending = cancelled.ProcessAsync(wave, "synthetic-not-a-key", new(), cancellation.Token);
                cancellation.Cancel(); await Refused(() => pending);
                Check(!File.Exists(path));
            }),
        };
        int failures = 0;
        foreach (var (name, run) in tests)
        {
            string root = Path.Combine(Path.GetTempPath(), "usage-check-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(root);
            try { await run(root); Console.WriteLine("PASS " + name); }
            catch (Exception error) { failures++; Console.Error.WriteLine($"FAIL {name}: {error.GetType().Name}: {error.Message}"); }
            finally { Directory.Delete(root, true); }
        }
        Console.WriteLine($"{tests.Length - failures}/{tests.Length} usage checks passed; synthetic data only.");
        return failures;
    }
    private static void Check(bool condition) { if (!condition) throw new InvalidOperationException("Usage check failed."); }
    private static async Task Refused(Func<Task> run)
    {
        try { await run(); } catch (Exception error) when (error is InvalidDataException or IOException or JsonException or UserFacingException or OperationCanceledException) { return; }
        throw new InvalidOperationException("Expected refusal.");
    }
    private sealed class FixedClock(DateTimeOffset now) : TimeProvider { public override DateTimeOffset GetUtcNow() => now; }
    private static HttpResponseMessage Reply(string body, int status = 200) => new((HttpStatusCode)status) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
    private sealed class Answers(params Func<CancellationToken, HttpResponseMessage>[] answers) : HttpMessageHandler
    {
        private int index;
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
            => Task.FromResult(answers[index++](cancellationToken));
    }
}
