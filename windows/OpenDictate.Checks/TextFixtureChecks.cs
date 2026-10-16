using System.Text.Json;
using OpenDictate.Core;

internal static class TextFixtureChecks
{
    internal static int Run()
    {
        using var cases = JsonDocument.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "fixtures", "text", "sanitize.json")));
        int failures = 0;
        foreach (var item in cases.RootElement.EnumerateArray())
        {
            string actual = TranscriptText.Sanitize(item.GetProperty("input").GetString()!);
            bool passed = actual == item.GetProperty("expected").GetString()
                && TranscriptText.IsMultiline(actual) == item.GetProperty("multiline").GetBoolean();
            Console.WriteLine($"{(passed ? "PASS" : "FAIL")} shared text: {item.GetProperty("name").GetString()}");
            if (!passed) failures++;
        }
        return failures;
    }
}
