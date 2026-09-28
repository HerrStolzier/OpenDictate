using System.Buffers.Binary;
using OpenDictate.Core;

var tests = new (string Name, Action Run)[]
{
    ("Reject overlapping operations", () =>
    {
        var gate = new AttemptGate(); gate.Begin(AttemptKind.Recording);
        Throws<InvalidOperationException>(() => gate.Begin(AttemptKind.Insertion, "field-a"));
    }),
    ("Reject cancellation and stale completion", () =>
    {
        var gate = new AttemptGate(); var old = gate.Begin(AttemptKind.Insertion, "field-a");
        gate.Cancel(); var current = gate.Begin(AttemptKind.Insertion, "field-a");
        Check(!gate.CanInsert(old, "field-a", true) && !gate.Complete(old));
        Check(gate.CanInsert(current, "field-a", true));
    }),
    ("Reject focus round trip", () =>
    {
        var gate = new AttemptGate(); var ticket = gate.Begin(AttemptKind.Insertion, "field-a");
        gate.ObserveFocus("field-b"); gate.ObserveFocus("field-a");
        Check(!gate.CanInsert(ticket, "field-a", true));
    }),
    ("Reject lost target and held modifiers", () =>
    {
        var gate = new AttemptGate(); var ticket = gate.Begin(AttemptKind.Insertion, "field-a");
        Check(!gate.CanInsert(ticket, null, true));
        Check(!gate.CanInsert(ticket, "field-a", false));
        Check(gate.CanInsert(ticket, "field-a", true));
    }),
    ("Completed attempt cannot deliver twice", () =>
    {
        var gate = new AttemptGate(); var ticket = gate.Begin(AttemptKind.Insertion, "field-a");
        Check(gate.Complete(ticket)); Check(!gate.CanInsert(ticket, "field-a", true));
    }),
    ("Dispatched delivery remains exclusive and cannot replay", () =>
    {
        var gate = new AttemptGate(); var ticket = gate.Begin(AttemptKind.Insertion, "field-a");
        Check(gate.BeginDelivery(ticket) && gate.IsBusy && gate.IsDelivering);
        Check(!gate.BeginDelivery(ticket) && !gate.CanInsert(ticket, "field-a", true) && !gate.Cancel());
        Throws<InvalidOperationException>(() => gate.Begin(AttemptKind.Recording));
        Check(gate.Complete(ticket)); gate.Begin(AttemptKind.Recording);
    }),
    ("Bridge Unicode frame survives fragmented reads", () =>
    {
        using var output = new MemoryStream();
        var expected = new BridgeMessage("insert", "fixture-id", "fixture-token", "Grüße 🧪\nZeile zwei");
        BridgeFrame.WriteAsync(output, expected).GetAwaiter().GetResult();
        using var input = new FragmentedStream(output.ToArray());
        Check(BridgeFrame.ReadAsync(input).GetAwaiter().GetResult() == expected);
        Check(BridgeFrame.ReadAsync(input).GetAwaiter().GetResult() is null);
    }),
    ("Bridge rejects oversized frame before reading a body", () =>
    {
        byte[] prefix = new byte[4]; BinaryPrimitives.WriteUInt32LittleEndian(prefix, BridgeFrame.MaximumBytes + 1u);
        using var input = new MemoryStream(prefix);
        Throws<InvalidDataException>(() => BridgeFrame.ReadAsync(input).GetAwaiter().GetResult());
    }),
    ("Bridge rejects truncated payload", () =>
    {
        using var input = new MemoryStream(new byte[] { 8, 0, 0, 0, 123, 125 });
        Throws<EndOfStreamException>(() => BridgeFrame.ReadAsync(input).GetAwaiter().GetResult());
    }),
    ("Bridge rejects unknown protocol and oversized text", () =>
    {
        foreach (var message in new[] { new BridgeMessage("capture", Protocol: 2), new BridgeMessage("insert", Text: new string('x', 16001)) })
        {
            using var input = new MemoryStream(); BridgeFrame.WriteAsync(input, message).GetAwaiter().GetResult(); input.Position = 0;
            Throws<InvalidDataException>(() => BridgeFrame.ReadAsync(input).GetAwaiter().GetResult());
        }
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
return failures == 0 ? 0 : 1;

static void Check(bool condition) { if (!condition) throw new InvalidOperationException("Assertion failed."); }
static void Throws<T>(Action action) where T : Exception
{
    try { action(); } catch (T) { return; }
    throw new InvalidOperationException($"Expected {typeof(T).Name}.");
}
static void InTemporaryDirectory(Action<string> action)
{
    var directory = Path.Combine(Path.GetTempPath(), "opendictate-offline-" + Guid.NewGuid().ToString("N"));
    Directory.CreateDirectory(directory);
    try { action(directory); }
    finally { Directory.Delete(directory, true); } // Only this test's synthetic files.
}

sealed class FragmentedStream(byte[] bytes) : MemoryStream(bytes)
{
    public override ValueTask<int> ReadAsync(Memory<byte> buffer, CancellationToken cancellationToken = default) =>
        base.ReadAsync(buffer[..Math.Min(3, buffer.Length)], cancellationToken);
}
