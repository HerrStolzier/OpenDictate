using System.Buffers.Binary;

namespace OpenDictate.Core;

// Fixed-format prototype journal: mono PCM16, 16 kHz. The raw original is never
// removed by export, cancellation, disposal or a failed write. A interrupted WAV
// export is an additional file, not the sole surviving recording.
public sealed class PcmJournal : IDisposable
{
    public const int SampleRate = 16000;
    private readonly FileStream stream;
    private bool closed;
    private long bytes;

    public string DirectoryPath { get; }
    public string RawPath => Path.Combine(DirectoryPath, "audio.pcm");
    public string WavePath => Path.Combine(DirectoryPath, "audio.wav");
    public long BytesWritten => bytes;

    public PcmJournal(string privateRoot)
    {
        DirectoryPath = Path.Combine(privateRoot, Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(DirectoryPath);
        // This metadata is sufficient to recover complete samples after an
        // interrupted process, without a mutable WAV header or filename guess.
        using (var metadata = new FileStream(Path.Combine(DirectoryPath, "format.txt"),
                   FileMode.CreateNew, FileAccess.Write, FileShare.Read))
        {
            metadata.Write("OpenDictate prototype PCM\nSampleRate=16000\nChannels=1\nBitsPerSample=16\nEndian=Little\n"u8);
            metadata.Flush(true);
        }
        stream = new FileStream(RawPath, FileMode.CreateNew, FileAccess.Write, FileShare.Read);
    }

    public void Append(ReadOnlySpan<byte> samples)
    {
        ObjectDisposedException.ThrowIf(closed, this);
        if (samples.Length % 2 != 0) throw new ArgumentException("Incomplete PCM16 sample.");
        if (bytes + samples.Length > SampleRate * 2L * 90)
            throw new InvalidOperationException("Recording duration limit reached.");
        stream.Write(samples);
        stream.Flush(true);
        bytes += samples.Length;
    }

    public void Close()
    {
        if (closed) return;
        closed = true;
        try { stream.Flush(true); }
        finally { stream.Dispose(); }
    }

    public string ExportWave()
    {
        Close();
        using var input = new FileStream(RawPath, FileMode.Open, FileAccess.Read, FileShare.Read);
        long completeBytes = input.Length - input.Length % 2;
        if (completeBytes == 0) throw new InvalidOperationException("No complete samples recorded.");
        if (completeBytes > SampleRate * 2L * 90) throw new InvalidDataException("Recording exceeds prototype limit.");
        using var output = new FileStream(WavePath, FileMode.CreateNew, FileAccess.Write, FileShare.Read);
        Span<byte> header = stackalloc byte[44];
        header.Clear();
        "RIFF"u8.CopyTo(header);
        BinaryPrimitives.WriteUInt32LittleEndian(header[4..], checked((uint)completeBytes + 36));
        "WAVEfmt "u8.CopyTo(header[8..]);
        BinaryPrimitives.WriteUInt32LittleEndian(header[16..], 16);
        BinaryPrimitives.WriteUInt16LittleEndian(header[20..], 1);
        BinaryPrimitives.WriteUInt16LittleEndian(header[22..], 1);
        BinaryPrimitives.WriteUInt32LittleEndian(header[24..], SampleRate);
        BinaryPrimitives.WriteUInt32LittleEndian(header[28..], SampleRate * 2);
        BinaryPrimitives.WriteUInt16LittleEndian(header[32..], 2);
        BinaryPrimitives.WriteUInt16LittleEndian(header[34..], 16);
        "data"u8.CopyTo(header[36..]);
        BinaryPrimitives.WriteUInt32LittleEndian(header[40..], (uint)completeBytes);
        output.Write(header);
        var buffer = new byte[16384];
        while (completeBytes > 0)
        {
            int read = input.Read(buffer, 0, (int)Math.Min(buffer.Length, completeBytes));
            if (read == 0) throw new EndOfStreamException();
            output.Write(buffer, 0, read);
            completeBytes -= read;
        }
        output.Flush(true);
        return WavePath;
    }

    public void Dispose() => Close();
}
