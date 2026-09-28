namespace OpenDictate.Core;

public enum DictationPhase { Idle, Recording, Transcribing, Cancelling, Delivering }
public enum DictationOutcome { Delivered, ManualDelivery, DeliveryUncertain, Cancelled, EmptyResponse, Failed }
public enum TextDelivery { Rejected, Completed, Uncertain }
public sealed record DictationResult(DictationOutcome Outcome, string? Text = null);

// One lease spans recording, preparation, transcription and delivery. A cancelled
// provider retains the lease until it actually settles, even if it ignores its
// token. The flow never deletes audio or retries a request/delivery.
public sealed class DictationFlow
{
    private readonly object sync = new();
    private CancellationTokenSource? active;
    private DictationPhase phase;
    public DictationPhase Phase { get { lock (sync) return phase; } }
    public bool IsBusy { get { lock (sync) return active is not null; } }

    public bool Cancel()
    {
        lock (sync)
        {
            if (active is null || phase == DictationPhase.Delivering) return false;
            phase = DictationPhase.Cancelling;
            active.Cancel();
            return true;
        }
    }

    public async Task<DictationResult> RunAsync(
        Func<CancellationToken, Task<byte[]>> recordAndPrepare,
        Func<ReadOnlyMemory<byte>, CancellationToken, Task<string>> transcribe,
        Func<string, CancellationToken, Task<TextDelivery>> deliver,
        CancellationToken shutdown = default)
    {
        CancellationTokenSource lifetime;
        lock (sync)
        {
            if (active is not null) throw new InvalidOperationException("A dictation is already active.");
            active = lifetime = CancellationTokenSource.CreateLinkedTokenSource(shutdown);
            phase = DictationPhase.Recording;
        }
        var token = lifetime.Token;
        bool dispatchStarted = false;
        string? recognized = null;
        try
        {
            token.ThrowIfCancellationRequested();
            byte[] audio = await recordAndPrepare(token);
            token.ThrowIfCancellationRequested();
            // The prototype only accepts a nonempty, bounded PCM16/16 kHz mono WAV.
            ValidateWave(audio);
            lock (sync)
            {
                token.ThrowIfCancellationRequested();
                phase = DictationPhase.Transcribing;
            }
            string text = await transcribe(audio, token);
            token.ThrowIfCancellationRequested();
            if (string.IsNullOrWhiteSpace(text)) return new(DictationOutcome.EmptyResponse);
            if (text.Length > 16000) return new(DictationOutcome.Failed);
            lock (sync)
            {
                token.ThrowIfCancellationRequested();
                phase = DictationPhase.Delivering;
                recognized = text;
                dispatchStarted = true;
            }
            // The adapter revalidates the originally captured target immediately
            // before its single dispatch. Uncertain delivery is never retried.
            TextDelivery result = await deliver(text, token);
            return result switch
            {
                TextDelivery.Completed => new(DictationOutcome.Delivered, text),
                TextDelivery.Rejected => new(DictationOutcome.ManualDelivery, text),
                _ => new(DictationOutcome.DeliveryUncertain, text)
            };
        }
        catch (OperationCanceledException) { return dispatchStarted ? new(DictationOutcome.DeliveryUncertain, recognized) : new(DictationOutcome.Cancelled); }
        catch (Exception) { return dispatchStarted ? new(DictationOutcome.DeliveryUncertain, recognized) : new(DictationOutcome.Failed); }
        finally
        {
            lock (sync) { active = null; phase = DictationPhase.Idle; }
            lifetime.Dispose();
        }
    }

    public static void ValidateWave(ReadOnlySpan<byte> audio)
    {
        if (audio.Length < 46 || audio.Length > 44 + PcmJournal.SampleRate * 2 * 90 ||
            !audio[..4].SequenceEqual("RIFF"u8) || !audio[8..16].SequenceEqual("WAVEfmt "u8) ||
            !audio[36..40].SequenceEqual("data"u8)) throw new InvalidDataException("Unsupported audio.");
        static uint U32(ReadOnlySpan<byte> a, int offset) => System.Buffers.Binary.BinaryPrimitives.ReadUInt32LittleEndian(a[offset..]);
        static ushort U16(ReadOnlySpan<byte> a, int offset) => System.Buffers.Binary.BinaryPrimitives.ReadUInt16LittleEndian(a[offset..]);
        if (U32(audio, 4) != audio.Length - 8 || U32(audio, 16) != 16 || U16(audio, 20) != 1 ||
            U16(audio, 22) != 1 || U32(audio, 24) != 16000 || U32(audio, 28) != 32000 ||
            U16(audio, 32) != 2 || U16(audio, 34) != 16 || U32(audio, 40) != audio.Length - 44 ||
            (audio.Length - 44) % 2 != 0) throw new InvalidDataException("Unsupported audio.");
    }
}
