using System.Text;

namespace OpenDictate.Core;

// Only bounded operational metadata crosses into the report. Raw messages,
// free-form model names and arbitrary log fields are never copied.
public sealed record ReportSettings(bool CustomServer, bool Loopback, bool ApiKeyPresent,
    string Model, bool Translation, string ShortcutMode, bool AutoInsert, int VocabularyEntries = 0, string? TargetLanguage = null);

public static class ProblemReport
{
    private const string SupportAddress = "https://support.opendictate.app/kontakt";
    private static readonly Dictionary<string, string> Errors = new()
    {
        ["transcription-failed"] = "Transkription fehlgeschlagen",
        ["translation-failed"] = "Übersetzung fehlgeschlagen",
        ["recording-failed"] = "Aufnahme fehlgeschlagen",
        ["recording-stop-failed"] = "Aufnahme fehlgeschlagen",
        ["recording-kept"] = "Diktat nicht zugestellt",
        ["insert-skipped"] = "Einfügen nicht bestätigt",
        ["pending-cleanup-failed"] = "Aufnahmebereinigung fehlgeschlagen",
        ["recovery-prune-failed"] = "Sicherungsbereinigung fehlgeschlagen",
    };

    // Display name is supplied from the app's existing branding constant.
    // Version is parsed separately; system is built from typed OS metadata.
    public static string Build(string productName, Version appVersion, Version systemVersion,
        string architecture, bool german, ReportSettings settings, IEnumerable<string> logLines)
    {
        string app = SafeProductName(productName) + " " + appVersion;
        string system = $"Windows {systemVersion} ({(architecture is "x64" or "arm64" or "x86" ? architecture : "unknown")})";
        return BuildFields(app, system, german, settings, logLines);
    }

    private static string SafeProductName(string name) =>
        // A branding label is not a path, URL or credential. Other data must
        // never be passed here; reject unsafe metadata rather than redact it.
        name.Length is > 0 and <= 60 && name.All(c => char.IsAsciiLetter(c) || c is ' ' or '-')
            && !name.Contains("sk-", StringComparison.OrdinalIgnoreCase) ? name : "App";

    private static string BuildFields(string app, string system, bool german, ReportSettings settings, IEnumerable<string> logLines)
    {
        var events = new Queue<string>();
        string error = "";
        foreach (string line in logLines)
        {
            // Existing operational logs may prefix an epoch timestamp. Only
            // a known event token survives, with every detail discarded.
            string[] words = line.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            string? code = words.Length > 0 ? words[0] : null;
            if (code is not null && code.All(char.IsAsciiDigit)) code = words.ElementAtOrDefault(1);
            if (code is null || !Errors.TryGetValue(code, out string? category)) continue;
            events.Enqueue(code);
            if (events.Count > 30) events.Dequeue();
            error = category;
        }
        string yes(bool value) => value ? "yes" : "no";
        string model = settings.Model is "gpt-transcribe" or "gpt-4o-mini-transcribe" or "gpt-4o-transcribe" or "whisper-1" ? settings.Model : "custom";
        string mode = settings.ShortcutMode is "hold" or "tap" ? settings.ShortcutMode : "unknown";
        string target = !settings.Translation ? "off" : settings.TargetLanguage is "de" or "en" or "fr" or "es" or "it" or "pt" or "nl" or "pl" or "ja" or "ko" or "zh" or "ar" or "ru" ? settings.TargetLanguage : "other";
        string summary = $"custom_server={yes(settings.CustomServer)}\nloopback={yes(settings.Loopback)}\napi_key={yes(settings.ApiKeyPresent)}\nmodel={model}\ntranslation={yes(settings.Translation)}\ntarget={target}\nshortcut={mode}\nauto_insert={yes(settings.AutoInsert)}\nvocabulary_entries={Math.Clamp(settings.VocabularyEntries, 0, 64)}";
        while (true)
        {
            string diagnostic = summary + (events.Count > 0 ? "\n" + string.Join('\n', events) : "");
            if (diagnostic.EnumerateRunes().Count() > 4000) { events.Dequeue(); continue; }
            string address = SupportAddress + "?lang=" + (german ? "de" : "en")
                + "#app=" + Encode(Limit(app, 100)) + "&system=" + Encode(Limit(system, 150))
                + "&fehler=" + Encode(Limit(error, 150)) + "&diagnose=" + Encode(diagnostic);
            if (address.Length <= 12000) return address;
            if (events.Count == 0) throw new InvalidOperationException("Report metadata exceeds its fixed bounds.");
            events.Dequeue();
        }
    }

    private static string Limit(string value, int count) => string.Concat(value.EnumerateRunes().Take(count).Select(rune => rune.ToString()));

    // WHATWG form encoding, shared byte-for-byte with Linux; Uri.EscapeDataString
    // has a different safe set and escapes spaces differently.
    private static string Encode(string value)
    {
        var result = new StringBuilder();
        foreach (byte current in Encoding.UTF8.GetBytes(value))
        {
            if (current is >= (byte)'a' and <= (byte)'z' or >= (byte)'A' and <= (byte)'Z'
                or >= (byte)'0' and <= (byte)'9' or (byte)'*' or (byte)'-' or (byte)'.' or (byte)'_') result.Append((char)current);
            else if (current == ' ') result.Append('+');
            else result.Append('%').Append(current.ToString("X2", System.Globalization.CultureInfo.InvariantCulture));
        }
        return result.ToString();
    }
}
