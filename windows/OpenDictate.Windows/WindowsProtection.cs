using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Security.Cryptography;
using System.Security.Principal;

namespace OpenDictate.Windows;

public static class PrivateDirectory
{
    public static void Ensure(string path)
    {
        RejectLinks(path);
        var owner = WindowsIdentity.GetCurrent().User ?? throw new InvalidOperationException();
        var acl = new DirectorySecurity(); acl.SetOwner(owner); acl.SetAccessRuleProtection(true, false);
        foreach (var sid in new[] {owner, new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null)})
            acl.AddAccessRule(new FileSystemAccessRule(sid, FileSystemRights.FullControl,
                InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit, PropagationFlags.None, AccessControlType.Allow));
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(path))!);
        var directory = new DirectoryInfo(path);
        if (!directory.Exists) directory.Create(acl);
        RejectLinks(path); directory.Refresh(); directory.SetAccessControl(acl);
    }
    public static void RejectLinks(string path)
    {
        for (var directory = new DirectoryInfo(Path.GetFullPath(path)); directory is not null; directory = directory.Parent)
            if (directory.Exists && (directory.Attributes & FileAttributes.ReparsePoint) != 0)
                throw new IOException("Directory link refused.");
    }
}

public static class WindowsProtection
{
    [StructLayout(LayoutKind.Sequential)] private struct Blob { public int Length; public nint Data; }
    public static byte[] Protect(byte[] bytes) => Transform(bytes, true);
    public static byte[] Unprotect(byte[] bytes) => Transform(bytes, false);
    private static byte[] Transform(byte[] bytes, bool protect)
    {
        var input = new Blob { Length = bytes.Length, Data = Marshal.AllocHGlobal(bytes.Length) };
        Blob output = default;
        try
        {
            Marshal.Copy(bytes, 0, input.Data, bytes.Length);
            bool success = protect ? CryptProtectData(ref input, null, 0, 0, 0, 1, out output)
                : CryptUnprotectData(ref input, 0, 0, 0, 0, 1, out output);
            if (!success) throw new CryptographicException("Windows data protection failed.");
            if (output.Length < 0 || output.Length > 4_000_000) throw new CryptographicException("Invalid protected payload.");
            var result = new byte[output.Length]; Marshal.Copy(output.Data, result, 0, result.Length); return result;
        }
        finally
        {
            if (input.Data != 0) { Marshal.Copy(new byte[bytes.Length], 0, input.Data, bytes.Length); Marshal.FreeHGlobal(input.Data); }
            if (output.Data != 0) { if (output.Length > 0 && output.Length <= 4_000_000) Marshal.Copy(new byte[output.Length], 0, output.Data, output.Length); LocalFree(output.Data); }
        }
    }
    [DllImport("crypt32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)] private static extern bool CryptProtectData(ref Blob input, string? description, nint entropy, nint reserved, nint prompt, uint flags, out Blob output);
    [DllImport("crypt32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)] private static extern bool CryptUnprotectData(ref Blob input, nint description, nint entropy, nint reserved, nint prompt, uint flags, out Blob output);
    [DllImport("kernel32.dll")] private static extern nint LocalFree(nint data);
}

public sealed class CredentialStore(string target = "OpenDictate.Windows.OpenAI")
{
    public void Save(string key)
    {
        if (key.Length < 8 || key.Length > 2048 || key.Any(c => c < 33 || c > 126)) throw new ArgumentException("Invalid key format.");
        byte[] bytes = System.Text.Encoding.UTF8.GetBytes(key);
        nint blob = Marshal.AllocHGlobal(bytes.Length);
        try
        {
            Marshal.Copy(bytes, 0, blob, bytes.Length);
            var credential = new Credential { Type = 1, TargetName = target, BlobSize = (uint)bytes.Length,
                Blob = blob, Persist = 2, UserName = "OpenDictate" };
            if (!CredWriteW(ref credential, 0)) throw new Win32Exception(Marshal.GetLastWin32Error());
        }
        finally { Marshal.Copy(new byte[bytes.Length], 0, blob, bytes.Length); Marshal.FreeHGlobal(blob); CryptographicOperations.ZeroMemory(bytes); }
    }
    public string? Read()
    {
        if (!CredReadW(target, 1, 0, out nint pointer))
        { if (Marshal.GetLastWin32Error() == 1168) return null; throw new Win32Exception(Marshal.GetLastWin32Error()); }
        try
        {
            var credential = Marshal.PtrToStructure<Credential>(pointer);
            if (credential.BlobSize > 2048 || credential.Type != 1) throw new InvalidDataException("Invalid credential.");
            var bytes = new byte[credential.BlobSize];
            try { Marshal.Copy(credential.Blob, bytes, 0, bytes.Length); return System.Text.Encoding.UTF8.GetString(bytes); }
            finally { CryptographicOperations.ZeroMemory(bytes); }
        }
        finally { CredFree(pointer); }
    }
    public void Delete()
    { if (!CredDeleteW(target, 1, 0) && Marshal.GetLastWin32Error() != 1168) throw new Win32Exception(Marshal.GetLastWin32Error()); }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct Credential
    {
        public uint Flags, Type;
        public string? TargetName, Comment;
        public long LastWritten;
        public uint BlobSize;
        public nint Blob;
        public uint Persist, AttributeCount;
        public nint Attributes;
        public string? TargetAlias, UserName;
    }
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)] private static extern bool CredWriteW(ref Credential credential, uint flags);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)] private static extern bool CredReadW(string target, uint type, uint flags, out nint credential);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)] private static extern bool CredDeleteW(string target, uint type, uint flags);
    [DllImport("advapi32.dll")] private static extern void CredFree(nint credential);
}
