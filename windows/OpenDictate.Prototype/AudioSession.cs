using System;
using System.Buffers.Binary;
using System.IO;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Threading;
using System.Threading.Tasks;
using NAudio.Wave;
using OpenDictate.Core;

namespace OpenDictate.Prototype;

internal sealed class AudioSession
{
    private readonly WasapiRecorder recorder;
    private readonly PcmJournal journal;
    private readonly TaskCompletionSource<string> completion = new(TaskCreationOptions.RunContinuationsAsynchronously);
    private Exception? writeError;
    private int stopping;
    private float peak;
    internal PcmJournal Journal => journal;
    internal float Peak => Volatile.Read(ref peak);
    internal Task<string> Completion => completion.Task;

    internal static string RecordingRoot => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "OpenDictatePrototype", "Recordings");

    internal AudioSession()
    {
        EnsurePrivateRoot(RecordingRoot);
        recorder = new WasapiRecorderBuilder().WithFormat(new WaveFormat(PcmJournal.SampleRate, 16, 1)).Build();
        if (recorder.WaveFormat.SampleRate != PcmJournal.SampleRate || recorder.WaveFormat.Channels != 1 ||
            recorder.WaveFormat.BitsPerSample != 16 || recorder.WaveFormat.Encoding != WaveFormatEncoding.Pcm)
        {
            recorder.Dispose();
            throw new InvalidOperationException("Unexpected capture format.");
        }
        try { journal = new PcmJournal(RecordingRoot); }
        catch { recorder.Dispose(); throw; }
        recorder.DataAvailable += (buffer, flags, _, _) =>
        {
            if (writeError is not null || Volatile.Read(ref stopping) != 0) return;
            try
            {
                long remaining = PcmJournal.SampleRate * 2L * 90 - journal.BytesWritten;
                int count = (int)Math.Min(buffer.Length, remaining);
                journal.Append(buffer[..count]);
                float max = 0;
                for (int i = 0; i + 1 < buffer.Length; i += 2)
                    max = Math.Max(max, Math.Abs((float)BinaryPrimitives.ReadInt16LittleEndian(buffer[i..])) / 32768);
                Volatile.Write(ref peak, max);
                if (journal.BytesWritten >= PcmJournal.SampleRate * 2L * 90) _ = Task.Run(Stop);
            }
            catch (Exception error)
            {
                writeError = error;
                // Stop outside the capture callback to avoid joining its own thread.
                _ = Task.Run(Stop);
            }
        };
        recorder.RecordingStopped += (_, args) =>
        {
            try
            {
                journal.Close();
                if (writeError is not null || args.Exception is not null)
                    completion.TrySetException(new IOException("Recording stopped; original retained.", writeError ?? args.Exception));
                else completion.TrySetResult(journal.ExportWave());
            }
            catch (Exception error) { completion.TrySetException(error); }
            finally { recorder.Dispose(); }
        };
    }

    internal static void EnsurePrivateRoot(string directory)
    {
        var security = new DirectorySecurity();
        var owner = WindowsIdentity.GetCurrent().User ?? throw new InvalidOperationException("No Windows user.");
        security.SetOwner(owner);
        security.SetAccessRuleProtection(true, false);
        foreach (var sid in new[] { owner, new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null) })
            security.AddAccessRule(new FileSystemAccessRule(sid, FileSystemRights.FullControl,
                InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit, PropagationFlags.None, AccessControlType.Allow));
        Directory.CreateDirectory(Path.GetDirectoryName(directory)!);
        var root = new DirectoryInfo(directory);
        if (!root.Exists) FileSystemAclExtensions.Create(root, security);
        // Exists caches missing-directory metadata; ACL creation does not refresh it.
        root.Refresh();
        if (!root.Exists) throw new IOException("Recording directory unavailable.");
        if ((root.Attributes & FileAttributes.ReparsePoint) != 0) throw new IOException("Unexpected recording directory link.");
        FileSystemAclExtensions.SetAccessControl(root, security);
    }

    internal void Start()
    {
        try { recorder.StartRecording(); }
        catch { journal.Dispose(); recorder.Dispose(); throw; }
    }

    internal void Stop()
    {
        if (completion.Task.IsCompleted || Interlocked.Exchange(ref stopping, 1) != 0) return;
        try { recorder.StopRecording(); }
        catch (Exception error)
        {
            // Preserve the journal even if the capture backend fails to stop.
            try { recorder.Dispose(); } catch (Exception) { }
            try { journal.Close(); } catch (Exception) { }
            completion.TrySetException(error);
        }
    }
}
