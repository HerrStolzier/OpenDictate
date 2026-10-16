using System.Diagnostics;
using System.Text.Json;

namespace OpenDictate.Core;

public sealed record UsageTranslation(string Model, ulong? InputTokens, ulong? OutputTokens);
public sealed record UsageEntry(long Timestamp, bool Custom, string Model, double AudioSeconds,
    UsageTranslation? Translation = null, string? RequestId = null);
public sealed record UsageTotal(int Dictations, double AudioSeconds, double? CostUsd);
public readonly record struct UsageBounds(long Today, long Week, long Month, long Retention);

// Local metadata and USD estimates only. The price resource is the shared
// checked-in table; this type never contacts an account or stores dictated text.
public sealed class UsageLedger(string path, TimeProvider? clock = null, TimeZoneInfo? zone = null)
{
    private const long MaximumBytes = 16 * 1024 * 1024;
    private readonly TimeProvider clock = clock ?? TimeProvider.System;
    private readonly TimeZoneInfo zone = zone ?? TimeZoneInfo.Local;
    private static readonly JsonSerializerOptions Json = new() { PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower };
    private static readonly JsonElement Prices = ReadPrices();

    private static JsonElement ReadPrices()
    {
        using var stream = typeof(UsageLedger).Assembly.GetManifestResourceStream("UsagePrices")
            ?? throw new InvalidOperationException("Missing usage prices.");
        using var document = JsonDocument.Parse(stream);
        return document.RootElement.Clone();
    }

    public static UsageBounds BoundsFor(DateTimeOffset now, TimeZoneInfo zone)
    {
        DateTime local = TimeZoneInfo.ConvertTime(now, zone).DateTime;
        // Explicit offsets also normalize a skipped local midnight through the
        // forward clock change, rather than refusing the entire estimate.
        long Stamp(DateTime value) => new DateTimeOffset(value, zone.GetUtcOffset(value)).ToUnixTimeSeconds();
        return new(Stamp(local.Date), Stamp(local.Date.AddDays(-6)),
            Stamp(new DateTime(local.Year, local.Month, 1)), Stamp(local.AddMonths(-13)));
    }

    public static UsageTotal[] Calculate(IEnumerable<UsageEntry> entries, long now, UsageBounds bounds)
    {
        var data = entries.ToArray();
        return new[] { bounds.Today, bounds.Week, bounds.Month }.Select(start =>
        {
            var selected = data.Where(e => e.Timestamp >= start && e.Timestamp <= now).ToArray();
            double? total = 0;
            foreach (var entry in selected) total += Cost(entry);
            return new UsageTotal(selected.Length, selected.Sum(e => e.AudioSeconds), total);
        }).ToArray();
    }

    private static double? Cost(UsageEntry entry)
    {
        if (entry.Custom) return 0;
        if (!Prices.GetProperty("transcription").TryGetProperty(entry.Model, out var rate)) return null;
        double total = entry.AudioSeconds / 60 * rate.GetDouble();
        if (entry.Translation is { } translation)
        {
            if (translation.InputTokens is not { } input || translation.OutputTokens is not { } output ||
                !Prices.GetProperty("translation").TryGetProperty(translation.Model, out var price)) return null;
            total += (input * price.GetProperty("input_per_million").GetDouble() +
                output * price.GetProperty("output_per_million").GetDouble()) / 1_000_000;
        }
        return total;
    }

    public async Task<string> RecordAsync(bool custom, string model, double audioSeconds,
        UsageTranslation? translation, CancellationToken token = default)
    {
        DateTimeOffset now = clock.GetUtcNow();
        var entry = new UsageEntry(now.ToUnixTimeSeconds(), custom, model, audioSeconds, translation, Guid.NewGuid().ToString("N"));
        Validate(entry);
        using var lease = await LockAsync(token).ConfigureAwait(false);
        var entries = Read();
        entries.RemoveAll(e => e.Timestamp < BoundsFor(now, zone).Retention);
        token.ThrowIfCancellationRequested();
        entries.Add(entry);
        Write(entries);
        if (token.IsCancellationRequested)
        {
            entries.RemoveAll(e => e.RequestId == entry.RequestId);
            Write(entries);
            token.ThrowIfCancellationRequested();
        }
        return entry.RequestId!;
    }

    public async Task RemoveAsync(string requestId)
    {
        if (requestId.Length != 32 || !requestId.All(Uri.IsHexDigit)) throw new ArgumentException("Invalid request identifier.", nameof(requestId));
        using var lease = await LockAsync(default).ConfigureAwait(false);
        var entries = Read();
        entries.RemoveAll(e => e.RequestId == requestId);
        Write(entries);
    }

    public async Task<UsageTotal[]> TotalsAsync(CancellationToken token = default)
    {
        using var lease = await LockAsync(token).ConfigureAwait(false);
        DateTimeOffset now = clock.GetUtcNow();
        var entries = Read();
        var bounds = BoundsFor(now, zone);
        if (entries.RemoveAll(e => e.Timestamp < bounds.Retention) > 0) Write(entries);
        return Calculate(entries, now.ToUnixTimeSeconds(), bounds);
    }

    public async Task ResetAsync(CancellationToken token = default)
    {
        using var lease = await LockAsync(token).ConfigureAwait(false);
        token.ThrowIfCancellationRequested();
        Write([]);
    }

    private async Task<FileStream> LockAsync(CancellationToken token)
    {
        string folder = Path.GetDirectoryName(Path.GetFullPath(path))!;
        Directory.CreateDirectory(folder);
        var watch = Stopwatch.StartNew();
        while (true)
        {
            token.ThrowIfCancellationRequested();
            try { return new FileStream(path + ".lock", Options(FileMode.OpenOrCreate, FileAccess.ReadWrite)); }
            catch (IOException) when (watch.Elapsed < TimeSpan.FromSeconds(5))
            { await Task.Delay(20, token).ConfigureAwait(false); }
        }
    }

    private static FileStreamOptions Options(FileMode mode, FileAccess access)
    {
        var options = new FileStreamOptions { Mode = mode, Access = access, Share = FileShare.None };
        if (!OperatingSystem.IsWindows() && mode != FileMode.Open)
            options.UnixCreateMode = UnixFileMode.UserRead | UnixFileMode.UserWrite;
        return options;
    }

    private List<UsageEntry> Read()
    {
        if (!File.Exists(path)) return [];
        using var stream = new FileStream(path, Options(FileMode.Open, FileAccess.Read));
        if (stream.Length > MaximumBytes) throw new InvalidDataException("Usage ledger too large.");
        var entries = JsonSerializer.Deserialize<List<UsageEntry>>(stream, Json)
            ?? throw new InvalidDataException("Invalid usage ledger.");
        foreach (var entry in entries) Validate(entry);
        return entries;
    }

    private static void Validate(UsageEntry entry)
    {
        if (entry is null || !double.IsFinite(entry.AudioSeconds) || entry.AudioSeconds is < 0 or > 3600 ||
            entry.Model is not { Length: > 0 and <= 128 } ||
            entry.Translation is { Model: not { Length: > 0 and <= 128 } })
            throw new InvalidDataException("Invalid usage metadata.");
    }

    private void Write(List<UsageEntry> entries)
    {
        string temporary = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
        bool created = false;
        try
        {
            using (var stream = new FileStream(temporary, Options(FileMode.CreateNew, FileAccess.Write)))
            {
                created = true;
                JsonSerializer.Serialize(stream, entries, Json);
                if (stream.Length > MaximumBytes) throw new InvalidDataException("Usage ledger too large.");
                stream.Flush(flushToDisk: true);
            }
            File.Move(temporary, path, overwrite: true);
        }
        finally { if (created && File.Exists(temporary)) File.Delete(temporary); }
    }
}
