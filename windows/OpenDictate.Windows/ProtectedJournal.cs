using System.ComponentModel;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
using OpenDictate.Core;

namespace OpenDictate.Windows;

public static class ProtectedJournal
{
    // Only a journal created by the current operation is passed here. Legacy
    // directories are never enumerated, inferred, migrated or recursively deleted.
    public static RecoveredRecording Seal(PcmJournal journal, RecoveryStore store)
    {
        journal.Close();
        PrivateDirectory.RejectLinks(journal.DirectoryPath);
        using var raw = Open(journal.RawPath);
        using var wav = Open(journal.WavePath);
        if (wav.Length is < 46 or > 2880044 || raw.Length != wav.Length - 44)
            throw new InvalidDataException("Journal length mismatch.");
        byte[] wave = new byte[(int)wav.Length]; wav.ReadExactly(wave);
        DictationFlow.ValidateWave(wave);
        byte[] original = new byte[(int)raw.Length]; raw.ReadExactly(original);
        if (!original.AsSpan().SequenceEqual(wave.AsSpan(44))) throw new InvalidDataException("Journal content mismatch.");
        var verified = store.Save(wave);
        // Save returns only after durable, authenticated round-trip verification.
        // Remove exact verified file handles, never whichever file occupies a path.
        Delete(wav); Delete(raw);
        return verified;
    }
    private static FileStream Open(string path)
    {
        var handle = CreateFileW(path, 0x80010000, 0, 0, 3, 0x00200000, 0);
        if (handle.IsInvalid) { int error = Marshal.GetLastWin32Error(); handle.Dispose(); throw new Win32Exception(error); }
        try
        {
            if (!GetFileInformationByHandle(handle, out var info) || (info.Attributes & 0x410) != 0 || info.Links != 1)
                throw new IOException("Linked or invalid journal.");
            return new FileStream(handle, FileAccess.Read);
        }
        catch { handle.Dispose(); throw; }
    }
    private static void Delete(FileStream file)
    {
        var data = new Disposition { Delete = true };
        if (!SetFileInformationByHandle(file.SafeFileHandle, 4, ref data, (uint)Marshal.SizeOf<Disposition>()))
            throw new Win32Exception(Marshal.GetLastWin32Error());
    }
    [StructLayout(LayoutKind.Sequential)] private struct Info
    {
        public uint Attributes; public System.Runtime.InteropServices.ComTypes.FILETIME Creation, Access, Write;
        public uint Volume, SizeHigh, SizeLow, Links, IndexHigh, IndexLow;
    }
    [StructLayout(LayoutKind.Sequential)] private struct Disposition { [MarshalAs(UnmanagedType.Bool)] public bool Delete; }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] private static extern SafeFileHandle CreateFileW(string path, uint access, uint share, nint security, uint creation, uint flags, nint template);
    [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] private static extern bool GetFileInformationByHandle(SafeFileHandle file, out Info info);
    [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] private static extern bool SetFileInformationByHandle(SafeFileHandle file, int kind, ref Disposition data, uint size);
}
