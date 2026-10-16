using System.Text.Json;
using OpenDictate.Core;

internal static class ReportChecks
{
    internal static int Run()
    {
        try
        {
            using var document = JsonDocument.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "fixtures", "report", "example.json")));
            var fixture = document.RootElement;
            var settings = new ReportSettings(true, true, false, "gpt-transcribe", false, "tap", true);
            string address = ProblemReport.Build(fixture.GetProperty("product").GetString()!, new Version("0.1.0"), new Version("10.0.26100"), "x64", true, settings,
                fixture.GetProperty("logs").EnumerateArray().Select(item => item.GetString()!));
            Check(address == fixture.GetProperty("address").GetString());
            string[] hostile = ["transcript secret-dictation", "clipboard secret-clipboard", "audio /private/audio.wav", "window Private Chat", "server speech.private.invalid", "sk-secret-fragment", "transcription-failed key=sk-secret-fragment transcript=secret-dictation host=speech.private.invalid"];
            address = ProblemReport.Build("Product", new Version("1.0"), new Version("10.0"), "arm64", false,
                settings with { Model = "speech.private.invalid", ShortcutMode = "secret-mode" }, Enumerable.Repeat(hostile, 50).SelectMany(lines => lines));
            string decoded = Uri.UnescapeDataString(address.Replace('+', ' '));
            foreach (string secret in new[] { "secret-dictation", "secret-clipboard", "private", "Chat", "sk-secret", "secret-mode" }) Check(!decoded.Contains(secret));
            Check(address.Length <= 12000 && decoded.Split("transcription-failed").Length - 1 == 30);
            Check(decoded.Contains("model=custom") && decoded.Contains("shortcut=unknown"));
            string empty = Uri.UnescapeDataString(ProblemReport.Build("Product", new Version("1.0"), new Version("10.0"), "x64", true, settings, []));
            Check(empty.Contains("&fehler=&diagnose="));
            string french = Uri.UnescapeDataString(ProblemReport.Build("Product", new Version("1.0"), new Version("10.0"), "x64", true, settings with { Translation = true, TargetLanguage = "fr" }, []));
            Check(french.Contains("target=fr"));
            Console.WriteLine("PASS report shared address, strict diagnostic allowlist and limits");
            return 0;
        }
        catch (Exception error) { Console.WriteLine($"FAIL report checks: {error.GetType().Name}"); return 1; }
    }

    private static void Check(bool condition) { if (!condition) throw new InvalidOperationException("Report assertion failed."); }
}
