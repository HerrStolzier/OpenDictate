using System;
using System.Buffers.Binary;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using NAudio.Wave;
using OpenDictate.Core;

namespace OpenDictate.Windows;

// One microphone recording into a PcmJournal under a private root. The
// journal keeps every sample written, even when capture or export fails.
public sealed class AudioSession
{
    private readonly WasapiRecorder recorder;
    private readonly PcmJournal journal;
    private readonly TaskCompletionSource<string> completion = new(TaskCreationOptions.RunContinuationsAsynchronously);
    private Exception? writeError;
    private int stopping;
    private float peak;
    public PcmJournal Journal => journal;
    public float Peak => Volatile.Read(ref peak);
    public Task<string> Completion => completion.Task;

    public AudioSession(string root)
    {
        PrivateDirectory.Ensure(root);
        recorder = new WasapiRecorderBuilder().WithFormat(new WaveFormat(PcmJournal.SampleRate, 16, 1)).Build();
        if (recorder.WaveFormat.SampleRate != PcmJournal.SampleRate || recorder.WaveFormat.Channels != 1 ||
            recorder.WaveFormat.BitsPerSample != 16 || recorder.WaveFormat.Encoding != WaveFormatEncoding.Pcm)
        {
            recorder.Dispose();
            throw new InvalidOperationException("Unexpected capture format.");
        }
        try { journal = new PcmJournal(root); }
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

    public void Start()
    {
        try { recorder.StartRecording(); }
        catch { journal.Dispose(); recorder.Dispose(); throw; }
    }

    public void Stop()
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
