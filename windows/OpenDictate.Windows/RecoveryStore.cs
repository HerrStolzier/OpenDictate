using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using Microsoft.Win32.SafeHandles;
using OpenDictate.Core;

namespace OpenDictate.Windows;

public sealed record RecoveryEntry(Guid Id, DateTimeOffset Created);
public sealed record RecoveredRecording(RecoveryEntry Entry, byte[] Wave);

// Only authenticated, purpose-bound envelopes are eligible for access or pruning.
// The original journal is deliberately owned by the caller, never by this store.
public sealed class RecoveryStore
{
    private readonly string root;
    private readonly Func<DateTimeOffset> now;
    private readonly object sync = new();
    public RecoveryStore(string root, Func<DateTimeOffset>? now = null)
    { this.root = Path.GetFullPath(root); this.now = now ?? (() => DateTimeOffset.UtcNow); PrivateDirectory.Ensure(root); }

    public RecoveredRecording Save(byte[] wave)
    {
        lock (sync)
        {
            DictationFlow.ValidateWave(wave); PrivateDirectory.Ensure(root);
            var entry = new RecoveryEntry(Guid.NewGuid(), now().ToUniversalTime());
            byte[] plain;
            using (var buffer = new MemoryStream())
            {
                using var writer = new BinaryWriter(buffer);
                writer.Write("ODRW0001"u8); writer.Write(entry.Id.ToByteArray());
                writer.Write(entry.Created.UtcTicks); writer.Write(wave.Length); writer.Write(wave);
                writer.Flush(); plain = buffer.ToArray();
            }
            byte[] encrypted;
            try { encrypted = WindowsProtection.Protect(plain); }
            finally { CryptographicOperations.ZeroMemory(plain); }
            using (var file = new FileStream(PathFor(entry.Id), FileMode.CreateNew, FileAccess.Write, FileShare.None))
            { file.Write(encrypted); file.Flush(true); }
            var verified = Read(entry.Id);
            if (!verified.Wave.AsSpan().SequenceEqual(wave)) throw new CryptographicException("Recovery verification failed.");
            Prune(entry.Id);
            return verified;
        }
    }

    public RecoveredRecording Read(Guid id)
    {
        lock (sync)
        {
            PrivateDirectory.RejectLinks(root);
            using var file = Open(id, false);
            return Decode(file, id, false);
        }
    }

    public IReadOnlyList<RecoveryEntry> List()
    {
        lock (sync) return Scan().Where(entry => !Expired(entry)).OrderByDescending(entry => entry.Created).ToArray();
    }

    public void Prune() { lock (sync) Prune(null); }
    private void Prune(Guid? keep)
    {
        var entries = Scan();
        var retained = entries.Where(e => !Expired(e) && e.Id != keep).OrderByDescending(e => e.Created)
            .Take(keep is null ? 5 : 4).Select(e => e.Id).ToHashSet();
        if (keep is not null) retained.Add(keep.Value);
        foreach (var entry in entries.Where(e => Expired(e) || !retained.Contains(e.Id)))
        {
            // Authenticate again while holding a non-shareable handle. Deletion
            // targets that verified handle, never a path that could be replaced.
            using var file = Open(entry.Id, true);
            var current = Decode(file, entry.Id, true);
            if (current.Entry != entry) throw new CryptographicException("Recovery identity changed.");
            var disposition = new Disposition { Delete = true };
            if (!SetFileInformationByHandle(file.SafeFileHandle, 4, ref disposition, (uint)Marshal.SizeOf<Disposition>()))
                throw new Win32Exception(Marshal.GetLastWin32Error());
        }
    }

    private List<RecoveryEntry> Scan()
    {
        PrivateDirectory.RejectLinks(root);
        var results = new List<RecoveryEntry>();
        foreach (string path in Directory.EnumerateFiles(root, "*.odr", SearchOption.TopDirectoryOnly))
        {
            if (!Guid.TryParseExact(Path.GetFileNameWithoutExtension(path), "N", out var id)) continue;
            try { using var file = Open(id, false); results.Add(Decode(file, id, true).Entry); }
            catch (Exception error) when (error is IOException or InvalidDataException or CryptographicException or UnauthorizedAccessException or Win32Exception or ArgumentException)
            { /* Unauthenticated artifacts are neither retried nor deleted. */ }
        }
        return results;
    }
    private bool Expired(RecoveryEntry entry) => now() - entry.Created >= TimeSpan.FromHours(24);
    private string PathFor(Guid id) => Path.Combine(root, id.ToString("N") + ".odr");

    private RecoveredRecording Decode(FileStream file, Guid expected, bool allowExpired)
    {
        if (file.Length is < 1 or > 3_500_000) throw new InvalidDataException("Invalid envelope size.");
        var encrypted = new byte[checked((int)file.Length)]; file.ReadExactly(encrypted);
        byte[] plain = WindowsProtection.Unprotect(encrypted);
        try
        {
            using var buffer = new MemoryStream(plain, false); using var reader = new BinaryReader(buffer);
            if (!reader.ReadBytes(8).AsSpan().SequenceEqual("ODRW0001"u8)) throw new InvalidDataException("Invalid recovery purpose.");
            var id = new Guid(reader.ReadBytes(16));
            var created = new DateTimeOffset(reader.ReadInt64(), TimeSpan.Zero);
            int length = reader.ReadInt32();
            if (id != expected || length != buffer.Length - buffer.Position || length is < 46 or > 2_880_044 ||
                created > now().AddMinutes(1)) throw new InvalidDataException("Invalid recovery metadata.");
            var entry = new RecoveryEntry(id, created);
            if (!allowExpired && Expired(entry)) throw new InvalidDataException("Recovery expired.");
            byte[] wave = reader.ReadBytes(length); DictationFlow.ValidateWave(wave);
            return new(entry, wave);
        }
        finally { CryptographicOperations.ZeroMemory(plain); }
    }

    private FileStream Open(Guid id, bool deleteAccess)
    {
        PrivateDirectory.RejectLinks(root);
        var handle = CreateFileW(PathFor(id), 0x80000000u | (deleteAccess ? 0x10000u : 0), 0, 0, 3, 0x00200000, 0);
        if (handle.IsInvalid) { handle.Dispose(); throw new Win32Exception(Marshal.GetLastWin32Error()); }
        try
        {
            if (!GetFileInformationByHandle(handle, out var information) ||
                (information.Attributes & (0x400u | 0x10u)) != 0 || information.Links != 1)
                throw new IOException("Linked or invalid recovery file.");
            return new FileStream(handle, FileAccess.Read);
        }
        catch { handle.Dispose(); throw; }
    }
    [StructLayout(LayoutKind.Sequential)] private struct FileInformation
    {
        public uint Attributes; public System.Runtime.InteropServices.ComTypes.FILETIME Creation, Access, Write;
        public uint Volume, SizeHigh, SizeLow, Links, IndexHigh, IndexLow;
    }
    [StructLayout(LayoutKind.Sequential)] private struct Disposition { [MarshalAs(UnmanagedType.Bool)] public bool Delete; }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern SafeFileHandle CreateFileW(string file, uint access, uint share, nint security, uint creation, uint flags, nint template);
    [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetFileInformationByHandle(SafeFileHandle file, out FileInformation information);
    [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetFileInformationByHandle(SafeFileHandle file, int informationClass, ref Disposition data, uint size);
}
