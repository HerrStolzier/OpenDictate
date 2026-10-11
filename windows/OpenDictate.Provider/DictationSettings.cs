using System.Text.Json;
using System.Text.Json.Serialization;
using OpenDictate.Core;

namespace OpenDictate.Provider;

// Model, spoken language, translation and custom server, stored as JSON
// without any secret. The API key stays in the Credential Manager.
public sealed record DictationSettings
{
    public const string DefaultModel = "gpt-transcribe";
    public const string DefaultTranslationModel = "gpt-5.4-mini";
    private const string DefaultToggleTarget = "en";

    // Without a settings file, German systems keep German as the spoken
    // language; elsewhere the language is detected. A file without the field
    // means detection, as on Linux.
    public static DictationSettings Default => new() { Language = UiText.IsGerman ? "de" : null };

    public string Model { get; init; } = DefaultModel;
    public string? Language { get; init; }
    // Translation target; null delivers the transcript unchanged.
    public string? TargetLanguage { get; init; }
    public string TranslationModel { get; init; } = DefaultTranslationModel;
    // Last chosen target, restored when translation is switched back on.
    public string? LastTargetLanguage { get; init; }
    // Custom server: base URL including /v1. Null uses OPENAI_BASE_URL when
    // set, otherwise OpenAI.
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Server { get; init; }
    // Windows dictation shortcut: "ctrl-win" (hold) or "right-ctrl".
    public string Shortcut { get; init; } = ShortcutGesture.SettingsName(ShortcutKey.CtrlWin);
    // Set once the first start has shown the shortcut and the user confirmed it.
    public bool ShortcutConfirmed { get; init; }
    // False keeps every transcript on the clipboard without sending Ctrl+V.
    public bool AutoInsert { get; init; } = true;

    [JsonIgnore]
    public ShortcutKey ShortcutKey => ShortcutGesture.Parse(Shortcut) ?? ShortcutKey.CtrlWin;

    public ProviderServer ResolveServer() =>
        ProviderServer.Resolve(Server, Environment.GetEnvironmentVariable(ProviderServer.BaseUrlVariable));

    public DictationSettings WithTarget(string? target) =>
        this with { TargetLanguage = target, LastTargetLanguage = target ?? LastTargetLanguage };

    // Switches translation off, or back on with the last chosen target
    // (English when none was chosen yet).
    public DictationSettings ToggleTarget() => TargetLanguage is { } target
        ? this with { TargetLanguage = null, LastTargetLanguage = target }
        : WithTarget(LastTargetLanguage ?? DefaultToggleTarget);

    // Which models a server offers is checked when it is used: a custom
    // server names its models freely, OpenAI only takes the known ones.
    public void Validate()
    {
        ValidateModelName(Model);
        if (!IsModelName(TranslationModel))
            throw new UserFacingException(UiText.T("Ungültiges Übersetzungsmodell.", "Invalid translation model."));
        if (Server is not null) ProviderServer.Parse(Server);
        if (ShortcutGesture.Parse(Shortcut) is null)
            throw new UserFacingException(UiText.T("Unbekanntes Tastenkürzel.", "Unknown shortcut."));
        foreach (var language in new[] { Language, TargetLanguage, LastTargetLanguage })
            if (language is not null) ValidateLanguage(language);
    }

    public static void ValidateModelFor(string model, ProviderServer server)
    {
        if (server.IsCustom) { ValidateModelName(model); return; }
        switch (model)
        {
            case "gpt-transcribe" or "gpt-4o-mini-transcribe" or "gpt-4o-transcribe" or "whisper-1": return;
            case "gpt-live-transcribe": throw new UserFacingException(UiText.T(
                "Das Echtzeitmodell kann nicht hochgeladen werden.", "The realtime model cannot take uploads."));
            default: throw new UserFacingException(UiText.T("Unbekanntes Transkriptionsmodell.", "Unknown transcription model."));
        }
    }

    public static void ValidateLanguage(string language)
    {
        if (language.Length is 0 or > 16 || !language.All(c => char.IsAsciiLetterOrDigit(c) || c == '-'))
            throw new UserFacingException(UiText.T("Ungültiger Sprachcode.", "Invalid language code."));
    }

    private static void ValidateModelName(string? model)
    {
        if (!IsModelName(model)) throw new UserFacingException(UiText.T("Ungültiger Modellname.", "Invalid model name."));
    }

    // Model names as custom servers use them, e.g. Systran/faster-whisper-small
    // or llama3.1:8b. A hand-edited file can carry null despite the type.
    private static bool IsModelName(string? model) =>
        model is { Length: > 0 and <= 128 } && model[0] is not ('.' or '/') && !model.Contains("..") &&
        model.All(c => char.IsAsciiLetterOrDigit(c) || c is '-' or '.' or '_' or ':' or '/');
}

public static class SettingsFile
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
        WriteIndented = true,
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Skip,
    };

    public static string DefaultPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "OpenDictate", "settings.json");

    // A missing file yields the defaults; a damaged one is refused instead of
    // being replaced, so a stored server address never falls back to OpenAI.
    public static DictationSettings Load(string path)
    {
        if (!File.Exists(path)) return DictationSettings.Default;
        DictationSettings? settings;
        try { settings = JsonSerializer.Deserialize<DictationSettings>(File.ReadAllBytes(path), Options); }
        catch (Exception error) when (error is JsonException or IOException or UnauthorizedAccessException) { throw Damaged(path); }
        if (settings is null) throw Damaged(path);
        try { settings.Validate(); }
        catch (UserFacingException error)
        {
            throw new UserFacingException(UiText.T($"{error.Message} Gespeicherten Wert in {path} korrigieren oder die Zeile löschen.",
                $"{error.Message} Fix the stored value in {path} or delete its line."));
        }
        return settings;
    }

    private static UserFacingException Damaged(string path) => new(UiText.T(
        $"Einstellungen in {path} sind beschädigt oder nicht lesbar.", $"Settings in {path} are damaged or unreadable."));

    // Writes a temporary file next to the target and replaces it in one step,
    // so a failed save keeps the previous settings.
    public static void Save(string path, DictationSettings settings)
    {
        settings.Validate();
        string folder = Path.GetDirectoryName(Path.GetFullPath(path))!;
        string temporary = Path.Combine(folder, $".settings-{Environment.ProcessId}-{Guid.NewGuid():N}.tmp");
        try
        {
            Directory.CreateDirectory(folder);
            using (var file = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write))
            {
                JsonSerializer.Serialize(file, settings, Options);
                file.Flush(flushToDisk: true);
            }
            File.Move(temporary, path, overwrite: true);
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        {
            try { File.Delete(temporary); } catch (Exception) { /* Only this save's own temporary file. */ }
            throw new UserFacingException(UiText.T("Einstellungen nicht speicherbar.", "Settings could not be saved."));
        }
    }
}
