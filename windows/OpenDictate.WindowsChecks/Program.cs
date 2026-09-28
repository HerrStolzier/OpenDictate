using System.Security.Cryptography;
using OpenDictate.Core;
using OpenDictate.Windows;

string root = Path.Combine(Path.GetTempPath(), "OpenDictate-WindowsChecks-" + Guid.NewGuid().ToString("N"));
PrivateDirectory.Ensure(root);
int failures = 0, total = 0;
try
{
    using var journal = new PcmJournal(root); journal.Append([1, 2, 3, 4]);
    byte[] wave = File.ReadAllBytes(journal.ExportWave());
    ProviderChecks.Run(wave, Test);
    Test("Sealing removes only verified new plaintext after durable recovery", () =>
    {
        using var owned = new PcmJournal(root); owned.Append([1, 2, 3, 4]); owned.ExportWave();
        var store = new RecoveryStore(Path.Combine(root, "seal"));
        var saved = ProtectedJournal.Seal(owned, store);
        Check(!File.Exists(owned.RawPath) && !File.Exists(owned.WavePath));
        Check(store.Read(saved.Entry.Id).Wave.AsSpan().SequenceEqual(wave) && File.Exists(journal.RawPath));
    });
    Test("Failed durable recovery preserves both new originals", () =>
    {
        using var owned = new PcmJournal(root); owned.Append([1, 2, 3, 4]); owned.ExportWave();
        string folder = Path.Combine(root, "blocked-store"); var store = new RecoveryStore(folder);
        Directory.Delete(folder); File.WriteAllText(folder, "synthetic obstruction");
        Throws(() => ProtectedJournal.Seal(owned, store));
        Check(File.Exists(owned.RawPath) && File.Exists(owned.WavePath));
    });
    Test("Mismatched journal cannot replace the original with recovery", () =>
    {
        using var owned = new PcmJournal(root); owned.Append([1, 2, 3, 4]); owned.ExportWave();
        File.WriteAllBytes(owned.RawPath, [5, 6, 7, 8]);
        var store = new RecoveryStore(Path.Combine(root, "mismatch"));
        Throws(() => ProtectedJournal.Seal(owned, store));
        Check(File.Exists(owned.RawPath) && File.Exists(owned.WavePath) && store.List().Count == 0);
    });
    Test("Windows encryption round trip and tamper rejection", () =>
    {
        var encrypted = WindowsProtection.Protect(wave);
        Check(!encrypted.AsSpan().SequenceEqual(wave) && WindowsProtection.Unprotect(encrypted).AsSpan().SequenceEqual(wave));
        encrypted[encrypted.Length / 2] ^= 1;
        Throws(() => WindowsProtection.Unprotect(encrypted));
    });
    Test("Protected recovery verifies identical audio and preserves original", () =>
    {
        var store = new RecoveryStore(Path.Combine(root, "roundtrip"));
        var saved = store.Save(wave); var loaded = store.Read(saved.Entry.Id);
        Check(loaded.Wave.AsSpan().SequenceEqual(wave) && store.List().Count == 1 && File.Exists(journal.RawPath));
    });
    Test("Recovery expiry enforced during access, with no retry", () =>
    {
        var time = DateTimeOffset.UtcNow; var store = new RecoveryStore(Path.Combine(root, "expiry"), () => time);
        var saved = store.Save(wave); time += TimeSpan.FromHours(24);
        Throws(() => store.Read(saved.Entry.Id)); Check(store.List().Count == 0);
        store.Prune(); Check(Directory.GetFiles(Path.Combine(root, "expiry")).Length == 0 && File.Exists(journal.RawPath));
    });
    Test("Recovery retains only five authenticated copies", () =>
    {
        var time = DateTimeOffset.UtcNow; var store = new RecoveryStore(Path.Combine(root, "count"), () => time);
        for (int i = 0; i < 7; i++) { time += TimeSpan.FromSeconds(1); store.Save(wave); }
        Check(store.List().Count == 5 && Directory.GetFiles(Path.Combine(root, "count")).Length == 5);
    });
    Test("Renamed and tampered recovery files are refused and not deleted", () =>
    {
        string folder = Path.Combine(root, "invalid"); var store = new RecoveryStore(folder); var saved = store.Save(wave);
        string good = Path.Combine(folder, saved.Entry.Id.ToString("N") + ".odr");
        var other = Guid.NewGuid(); string renamed = Path.Combine(folder, other.ToString("N") + ".odr");
        File.Copy(good, renamed); Throws(() => store.Read(other));
        var bad = File.ReadAllBytes(good); bad[bad.Length / 2] ^= 1; File.WriteAllBytes(good, bad);
        Throws(() => store.Read(saved.Entry.Id)); store.Prune();
        Check(File.Exists(good) && File.Exists(renamed) && store.List().Count == 0);
    });
    Test("Invalid audio cannot become a recovery candidate", () =>
    {
        var store = new RecoveryStore(Path.Combine(root, "bad-wave")); Throws(() => store.Save([1, 2, 3, 4]));
        Check(store.List().Count == 0 && File.Exists(journal.RawPath));
    });
    Test("Provider failure retains authenticated audio for an explicit retry", () =>
    {
        var store = new RecoveryStore(Path.Combine(root, "failed-provider"));
        RecoveredRecording? saved = null; int requests = 0, deliveries = 0;
        var result = new DictationFlow().RunAsync(
            _ => Task.FromResult((saved = store.Save(wave)).Wave),
            (bytes, _) => { requests++; Check(bytes.Span.SequenceEqual(wave)); throw new IOException("Synthetic provider failure."); },
            (_, _) => { deliveries++; return Task.FromResult(TextDelivery.Completed); }).GetAwaiter().GetResult();
        Check(result.Outcome == DictationOutcome.Failed && requests == 1 && deliveries == 0 && saved is not null);
        Check(store.Read(saved!.Entry.Id).Wave.AsSpan().SequenceEqual(wave) && File.Exists(journal.RawPath));
    });
    Test("Expired retry is blocked before provider and delivery", () =>
    {
        var time = DateTimeOffset.UtcNow; var store = new RecoveryStore(Path.Combine(root, "expired-retry"), () => time);
        var saved = store.Save(wave); time += TimeSpan.FromHours(24); int requests = 0, deliveries = 0;
        var result = new DictationFlow().RunAsync(
            _ => Task.FromResult(store.Read(saved.Entry.Id).Wave),
            (_, _) => { requests++; return Task.FromResult("synthetic response"); },
            (_, _) => { deliveries++; return Task.FromResult(TextDelivery.Completed); }).GetAwaiter().GetResult();
        Check(result.Outcome == DictationOutcome.Failed && requests == 0 && deliveries == 0 && File.Exists(journal.RawPath));
    });
    Test("Credential Manager isolated dummy entry round trip", () =>
    {
        var store = new CredentialStore("OpenDictate.Windows.Test." + Guid.NewGuid().ToString("N"));
        try { Check(store.Read() is null); store.Save("synthetic-fixture-not-an-api-key"); Check(store.Read() == "synthetic-fixture-not-an-api-key"); store.Delete(); Check(store.Read() is null); }
        finally { store.Delete(); }
    });
    Test("Credential header control characters rejected before storage", () =>
    {
        var store = new CredentialStore("OpenDictate.Windows.Test." + Guid.NewGuid().ToString("N"));
        Throws(() => store.Save("synthetic\r\nfixture")); Check(store.Read() is null);
    });
}
finally { Directory.Delete(root, true); }
Console.WriteLine($"{total - failures}/{total} Windows protection checks passed; synthetic files and isolated dummy credential only.");
return failures == 0 ? 0 : 1;
void Test(string name, Action action)
{ total++; try { action(); Console.WriteLine("PASS " + name); } catch (Exception error) { failures++; Console.WriteLine("FAIL " + name + ": " + error.GetType().Name); } }
static void Check(bool value) { if (!value) throw new InvalidOperationException("Assertion failed."); }
static void Throws(Action action) { try { action(); } catch (Exception) { return; } throw new InvalidOperationException("Expected rejection."); }
