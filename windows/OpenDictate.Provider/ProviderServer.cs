using OpenDictate.Core;

namespace OpenDictate.Provider;

// Where transcription and translation go: OpenAI, or a custom server
// ("Eigener Server") with the same API, e.g. a local model. The address is
// the base URL including /v1; request paths are appended to it.
public sealed class ProviderServer
{
    public const string OpenAiBase = "https://api.openai.com/v1";
    public const string BaseUrlVariable = "OPENAI_BASE_URL";
    private const int MaximumAddressLength = 512;

    private ProviderServer(string baseAddress, string host, bool loopback)
    { Base = baseAddress; Host = host; IsLoopback = loopback; }

    public static ProviderServer OpenAi { get; } = Parse(OpenAiBase);
    public string Base { get; }
    // Host only, without path or port: the one detail the log may name.
    public string Host { get; }
    public bool IsLoopback { get; }
    public bool IsCustom => Base != OpenAiBase;
    // Requests to this computer carry no API key; every other server gets it.
    public bool SendsApiKey => !IsLoopback;
    // An empty path probably lacks the usual /v1.
    public bool LacksPath => Base.Count(c => c == '/') == 2;
    public Uri TranscriptionUri => new(Base + "/audio/transcriptions");
    public Uri ChatUri => new(Base + "/chat/completions");

    // The stored address wins over OPENAI_BASE_URL; without either, OpenAI.
    // A broken variable must not silently send audio to OpenAI instead.
    public static ProviderServer Resolve(string? stored, string? environment)
    {
        if (stored is not null) return Parse(stored);
        if (string.IsNullOrWhiteSpace(environment)) return OpenAi;
        try { return Parse(environment); }
        catch (UserFacingException error)
        { throw new UserFacingException(UiText.T($"{BaseUrlVariable} ist ungültig: {error.Message}", $"{BaseUrlVariable} is invalid: {error.Message}")); }
    }

    // Validates an address and returns it as stored: lowercase scheme and
    // host, no trailing slash.
    public static ProviderServer Parse(string address)
    {
        address = address.Trim();
        if (address.Length == 0 || address.Length > MaximumAddressLength || address.Any(c => c < 33 || c > 126))
            throw Invalid();
        // No credentials, query or fragment: the address is shown and its host
        // logged, and a key belongs in the Credential Manager only.
        if (address.IndexOfAny(['@', '?', '#', '\\']) >= 0)
            throw new UserFacingException(UiText.T(
                "Die Server-Adresse darf keine Zugangsdaten, keine Abfrage (?) und keinen Anker (#) enthalten.",
                "The server address must not contain credentials, a query (?) or a fragment (#)."));
        string scheme;
        if (address.StartsWith("https://", StringComparison.OrdinalIgnoreCase)) scheme = "https";
        else if (address.StartsWith("http://", StringComparison.OrdinalIgnoreCase)) scheme = "http";
        else throw new UserFacingException(UiText.T(
            "Die Server-Adresse muss mit https:// beginnen (http:// nur für diesen Computer).",
            "The server address must start with https:// (http:// only for this computer)."));
        string rest = address[(scheme.Length + 3)..];
        int slash = rest.IndexOf('/');
        string authority = slash < 0 ? rest : rest[..slash], path = slash < 0 ? "" : rest[slash..];
        var (host, port) = SplitAuthority(authority) ?? throw Invalid();
        host = host.ToLowerInvariant();
        if (port is not null && (!ushort.TryParse(port, out ushort number) || number == 0)) throw Invalid();
        bool loopback = host is "localhost" or "127.0.0.1" or "[::1]";
        if (scheme == "http" && !loopback)
            throw new UserFacingException(UiText.T(
                "http:// geht nur für diesen Computer (localhost, 127.0.0.1, [::1]); sonst https:// verwenden.",
                "http:// only works for this computer (localhost, 127.0.0.1, [::1]); use https:// otherwise."));
        path = path.TrimEnd('/');
        string baseAddress = port is null ? $"{scheme}://{host}{path}" : $"{scheme}://{host}:{port}{path}";
        return new ProviderServer(baseAddress, host, loopback);
    }

    // Splits host[:port] and [v6]:port; rejects anything else.
    private static (string Host, string? Port)? SplitAuthority(string authority)
    {
        string host; string? port = null;
        if (authority.StartsWith('['))
        {
            int end = authority.IndexOf(']');
            if (end < 2 || !authority[1..end].All(c => char.IsAsciiHexDigit(c) || c is ':' or '.')) return null;
            host = authority[..(end + 1)];
            string tail = authority[(end + 1)..];
            if (tail.Length > 0) { if (!tail.StartsWith(':')) return null; port = tail[1..]; }
        }
        else
        {
            int colon = authority.IndexOf(':');
            host = colon < 0 ? authority : authority[..colon];
            if (colon >= 0) port = authority[(colon + 1)..];
            if (host.Length == 0 || host[0] is '-' or '.' || !host.All(c => char.IsAsciiLetterOrDigit(c) || c is '-' or '.')) return null;
        }
        if (port is not null && (port.Length == 0 || !port.All(char.IsAsciiDigit))) return null;
        return (host, port);
    }

    private static UserFacingException Invalid() => new(UiText.T(
        "Ungültige Server-Adresse, z. B. http://127.0.0.1:8080/v1 verwenden.",
        "Invalid server address; use e.g. http://127.0.0.1:8080/v1."));
}
