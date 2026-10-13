using System.Buffers.Binary;
using OpenDictate.Core;

var tests = new (string Name, Action Run)[]
{
    ("Transcript loses control characters and direction marks but keeps line breaks", () =>
    {
        Check(TranscriptText.Sanitize(" a\u001bb\u0007c\u0000\u0085d\u202ee\u200f ") == "abcde");
        Check(TranscriptText.Sanitize("eins\r\nzwei\rdrei\tvier") == "eins\nzwei\ndrei\tvier");
        Check(TranscriptText.Sanitize("Grüße 🧪") == "Grüße 🧪");
        Check(TranscriptText.IsMultiline("a\nb") && !TranscriptText.IsMultiline("a b"));
    }),
    ("Multi-line text stays on the clipboard for consoles", () =>
    {
        Check(!PastePolicy.MayPasteText("ls\nrm -rf x", "WindowsTerminal") && !PastePolicy.MayPasteText("a\nb", "pwsh"));
        Check(PastePolicy.MayPasteText("one line", "WindowsTerminal") && PastePolicy.MayPasteText("a\nb", "notepad"));
        Check(PastePolicy.MayPasteText("a\nb", null) && PastePolicy.IsConsole("conhost") && !PastePolicy.IsConsole("Code"));
    }),
    ("WAV export has exact sample data and keeps original", () => InTemporaryDirectory(root =>
    {
        using var journal = new PcmJournal(root);
        byte[] synthetic = [0, 0, 255, 127, 0, 128, 123, 0];
        journal.Append(synthetic); var wav = File.ReadAllBytes(journal.ExportWave());
        Check(wav.Length == 44 + synthetic.Length && wav.AsSpan(44).SequenceEqual(synthetic));
        Check(BinaryPrimitives.ReadUInt32LittleEndian(wav.AsSpan(24)) == 16000);
        Check(BinaryPrimitives.ReadUInt32LittleEndian(wav.AsSpan(40)) == synthetic.Length);
        Check(File.ReadAllBytes(journal.RawPath).SequenceEqual(synthetic));
    })),
    ("Failed export preserves original and existing destination", () => InTemporaryDirectory(root =>
    {
        using var journal = new PcmJournal(root); journal.Append([12, 34, 56, 78]);
        File.WriteAllText(journal.WavePath, "existing artifact");
        Throws<IOException>(() => journal.ExportWave());
        Check(File.ReadAllBytes(journal.RawPath).SequenceEqual(new byte[] {12, 34, 56, 78}));
        Check(File.ReadAllText(journal.WavePath) == "existing artifact");
    })),
    ("Disposal keeps durable PCM and format for recovery", () => InTemporaryDirectory(root =>
    {
        string path;
        using (var journal = new PcmJournal(root)) { journal.Append([1, 2]); path = journal.RawPath; }
        Check(File.ReadAllBytes(path).SequenceEqual(new byte[] {1, 2}));
        Check(File.Exists(Path.Combine(Path.GetDirectoryName(path)!, "format.txt")));
    })),
    ("A journal closed after an interruption still exports its WAV", () => InTemporaryDirectory(root =>
    {
        using var journal = new PcmJournal(root); journal.Append([5, 6, 7, 8]); journal.Close();
        var wav = File.ReadAllBytes(journal.ExportWave());
        Check(wav.AsSpan(44).SequenceEqual(new byte[] {5, 6, 7, 8}) && File.ReadAllBytes(journal.RawPath).SequenceEqual(new byte[] {5, 6, 7, 8}));
    })),
    ("Reject malformed samples without changing saved data", () => InTemporaryDirectory(root =>
    {
        using var journal = new PcmJournal(root); journal.Append([1, 2]);
        Throws<ArgumentException>(() => journal.Append([3])); journal.Close();
        Check(File.ReadAllBytes(journal.RawPath).SequenceEqual(new byte[] {1, 2}));
    }))
};
int failures = 0;
foreach (var test in tests)
{
    try { test.Run(); Console.WriteLine($"PASS {test.Name}"); }
    catch (Exception error) { ++failures; Console.WriteLine($"FAIL {test.Name}: {error.GetType().Name}"); }
}
Console.WriteLine($"{tests.Length - failures}/{tests.Length} checks passed; synthetic data only.");
failures += await DictationChecks.RunAsync();
failures += await ProviderChecks.RunAsync(SyntheticWave());
failures += ShortcutChecks.Run();
return failures == 0 ? 0 : 1;

static void Check(bool condition) { if (!condition) throw new InvalidOperationException("Assertion failed."); }
static void Throws<T>(Action action) where T : Exception
{
    try { action(); } catch (T) { return; }
    throw new InvalidOperationException($"Expected {typeof(T).Name}.");
}
static byte[] SyntheticWave()
{
    var directory = Path.Combine(Path.GetTempPath(), "opendictate-wave-" + Guid.NewGuid().ToString("N"));
    Directory.CreateDirectory(directory);
    try { using var journal = new PcmJournal(directory); journal.Append([1, 2, 3, 4]); return File.ReadAllBytes(journal.ExportWave()); }
    finally { Directory.Delete(directory, true); }
}
static void InTemporaryDirectory(Action<string> action)
{
    var directory = Path.Combine(Path.GetTempPath(), "opendictate-offline-" + Guid.NewGuid().ToString("N"));
    Directory.CreateDirectory(directory);
    try { action(directory); }
    finally { Directory.Delete(directory, true); } // Only this test's synthetic files.
}
