using System.Buffers.Binary;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace OpenDictate.Core;

public sealed record BridgeMessage(string Type, string? Id = null, string? Token = null,
    string? Text = null, bool? Ok = null, string? Reason = null, string? Kind = null, int Protocol = 1);

// Both native messaging and the local pipe use bounded UTF-8 frames. Framing
// never assumes a whole message arrives in one stream read.
public static class BridgeFrame
{
    public const int MaximumBytes = 128 * 1024;
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        MaxDepth = 8
    };

    public static async Task<BridgeMessage?> ReadAsync(Stream stream, CancellationToken token = default)
    {
        byte[] prefix = new byte[4];
        int first = await stream.ReadAsync(prefix.AsMemory(0, 1), token);
        if (first == 0) return null;
        await stream.ReadExactlyAsync(prefix.AsMemory(1), token);
        uint length = BinaryPrimitives.ReadUInt32LittleEndian(prefix);
        if (length == 0 || length > MaximumBytes) throw new InvalidDataException("Invalid bridge frame length.");
        byte[] bytes = new byte[length];
        await stream.ReadExactlyAsync(bytes, token);
        var message = JsonSerializer.Deserialize<BridgeMessage>(bytes, Options)
            ?? throw new InvalidDataException("Empty bridge message.");
        if (message.Protocol != 1 || string.IsNullOrEmpty(message.Type) || message.Type.Length > 24 ||
            message.Id?.Length > 64 || message.Token?.Length > 64 || message.Text?.Length > 16000 ||
            message.Reason?.Length > 64 || message.Kind?.Length > 16)
            throw new InvalidDataException("Invalid bridge envelope.");
        return message;
    }

    public static async Task WriteAsync(Stream stream, BridgeMessage message, CancellationToken token = default)
    {
        byte[] bytes = JsonSerializer.SerializeToUtf8Bytes(message, Options);
        if (bytes.Length > MaximumBytes) throw new InvalidDataException("Bridge message too large.");
        byte[] prefix = new byte[4];
        BinaryPrimitives.WriteUInt32LittleEndian(prefix, (uint)bytes.Length);
        await stream.WriteAsync(prefix, token);
        await stream.WriteAsync(bytes, token);
        await stream.FlushAsync(token);
    }
}
