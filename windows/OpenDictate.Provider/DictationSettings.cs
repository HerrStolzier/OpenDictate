using System.Text.Json;
using System.Text.Json.Serialization;
using OpenDictate.Core;

namespace OpenDictate.Provider;

// Service, models, spoken language, translation and custom server, stored as
// JSON without any secret. The API key stays in the Credential Manager.
public sealed record DictationSettings
{
    public const string DefaultModel = "gpt-transcribe";
    public const string DefaultTranslationModel = "gpt-5.4-mini";
    public const string OpenAiService = "openai";
    public const string ServerService = "server";
    private const string DefaultToggleTarget = "en";

    // Without a settings file, German systems keep German as the spoken
    // language; elsewhere the language is detected. A file without the field
    // means detection, as on Linux.
    public static DictationSettings Default => new() { Language = UiText.IsGerman ? "de" : null };

    // Who turns the recording into text: "openai" or "server". Null (files
    // from before the choice) means the custom server whenever one is known.
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Service { get; init; }
    // OpenAI's models; the custom server keeps its own, so switching between
    // the two never sends one side's model name to the other.
    public string Model { get; init; } = DefaultModel;
    public string TranslationModel { get; init; } = DefaultTranslationModel;
    public string ServerModel { get; init; } = DefaultModel;
    public string ServerTranslationModel { get; init; } = DefaultTranslationModel;
    public string? Language { get; init; }
    // Translation target; null delivers the transcript unchanged.
    public string? TargetLanguage { get; init; }
    // Last chosen target, restored when translation is switched back on.
    public string? LastTargetLanguage { get; init; }
    // Custom server: base URL including /v1, kept while OpenAI is chosen.
    // Null uses OPENAI_BASE_URL when set.
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Server { get; init; }
    // Windows dictation shortcut: "ctrl-win" or "right-ctrl".
    public string Shortcut { get; init; } = ShortcutGesture.SettingsName(ShortcutKey.CtrlWin);
    // "hold" records while the shortcut is held, "tap" toggles with a tap.
    public string ShortcutMode { get; init; } = ShortcutGesture.ModeName(TriggerMode.Hold);
    // Set once the first start has shown the shortcut and the user confirmed it.
    public bool ShortcutConfirmed { get; init; }
    // False keeps every transcript on the clipboard without sending Ctrl+V.
    public bool AutoInsert { get; init; } = true;
    // Explicit local spelling hints, shared limits with Linux (#164).
    public IReadOnlyList<string> Vocabulary { get; init; } = [];

    [JsonIgnore]
    public ShortcutKey ShortcutKey => ShortcutGesture.Parse(Shortcut) ?? ShortcutKey.CtrlWin;

    [JsonIgnore]
    public TriggerMode TriggerMode => ShortcutGesture.ParseMode(ShortcutMode) ?? TriggerMode.Hold;

    private static string? EnvironmentServer => Environment.GetEnvironmentVariable(ProviderServer.BaseUrlVariable);

    public bool UsesServer(string? environment) => Service switch
    {
        OpenAiService => false,
        ServerService => true,
        _ => Server is not null || !string.IsNullOrWhiteSpace(environment),
    };

    public ProviderServer ResolveServer() => ResolveServer(EnvironmentServer);

    // OpenAI when chosen; the custom server never falls back to OpenAI, not
    // even when its address is missing or broken.
    public ProviderServer ResolveServer(string? environment)
    {
        if (!UsesServer(environment)) return ProviderServer.OpenAi;
        if (Server is null && string.IsNullOrWhiteSpace(environment))
            throw new UserFacingException(UiText.T(
                "Kein eigener Server eingerichtet. Trag die Adresse in den Einstellungen ein oder wähl OpenAI.",
                "No custom server set up. Enter its address in the settings or choose OpenAI."));
        return ProviderServer.Resolve(Server, environment);
    }

    // Where a dictation goes and the settings it is sent with: the chosen
    // service's own models stand in Model and TranslationModel.
    public (DictationSettings Request, ProviderServer Server) ForDictation() => ForDictation(EnvironmentServer);

    public (DictationSettings Request, ProviderServer Server) ForDictation(string? environment)
    {
        var server = ResolveServer(environment);
        var request = UsesServer(environment) ? this with { Model = ServerModel, TranslationModel = ServerTranslationModel } : this;
        return (request, server);
    }

    // As setServerAddress on macOS: without any address (stored or from
    // OPENAI_BASE_URL) OpenAI is chosen, the very first address chooses the
    // custom server, and otherwise the choice stays.
    public DictationSettings WithServerAddress(string? address, string? environment)
    {
        bool hadAddress = Server is not null || !string.IsNullOrWhiteSpace(environment);
        bool known = address is not null || !string.IsNullOrWhiteSpace(environment);
        bool server = known && ((!hadAddress && address is not null) || UsesServer(environment));
        return this with { Server = address, Service = server ? ServerService : OpenAiService };
    }

    // Files from before the service choice kept the custom server's model
    // names in Model and TranslationModel; they move to the server side, as
    // migrateServiceChoice does on macOS. A known OpenAI model stays. Unlike
    // macOS, an address from OPENAI_BASE_URL alone migrates too: if the
    // variable goes away later, dictation stops with a message instead of
    // silently going to OpenAI. SettingsFile.Load stores the result.
    public DictationSettings Migrated(string? environment)
    {
        if (Service is not null || !UsesServer(environment)) return this;
        return this with
        {
            Service = ServerService,
            ServerModel = Model,
            ServerTranslationModel = TranslationModel,
            Model = IsOpenAiModel(Model) ? Model : DefaultModel,
            TranslationModel = DefaultTranslationModel,
        };
    }

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
        ValidateVocabulary(Vocabulary);
        ValidateModelName(Model);
        ValidateModelName(ServerModel);
        if (!IsModelName(TranslationModel) || !IsModelName(ServerTranslationModel))
            throw new UserFacingException(UiText.T("Ungültiges Übersetzungsmodell.", "Invalid translation model."));
        if (Service is not (null or OpenAiService or ServerService))
            throw new UserFacingException(UiText.T("Unbekannter Dienst.", "Unknown service."));
        if (Server is not null) ProviderServer.Parse(Server);
        if (ShortcutGesture.Parse(Shortcut) is null)
            throw new UserFacingException(UiText.T("Unbekanntes Tastenkürzel.", "Unknown shortcut."));
        if (ShortcutGesture.ParseMode(ShortcutMode) is null)
            throw new UserFacingException(UiText.T("Unbekannte Art, das Kürzel zu nutzen.", "Unknown shortcut mode."));
        foreach (var language in new[] { Language, TargetLanguage, LastTargetLanguage })
            if (language is not null) ValidateLanguage(language);
    }

    public static void ValidateModelFor(string model, ProviderServer server)
    {
        if (server.IsCustom) { ValidateModelName(model); return; }
        if (IsOpenAiModel(model)) return;
        throw new UserFacingException(model == "gpt-live-transcribe"
            ? UiText.T("Das Echtzeitmodell funktioniert mit OpenDictate nicht. Wähl ein anderes Modell.", "The realtime model does not work with OpenDictate. Pick another model.")
            : UiText.T("Unbekanntes Transkriptionsmodell.", "Unknown transcription model."));
    }

    private static bool IsOpenAiModel(string model) =>
        model is "gpt-transcribe" or "gpt-4o-mini-transcribe" or "gpt-4o-transcribe" or "whisper-1";

    public static void ValidateLanguage(string language)
    {
        if (language.Length is 0 or > 16 || !language.All(c => char.IsAsciiLetterOrDigit(c) || c == '-'))
            throw new UserFacingException(UiText.T("Ungültiger Sprachcode.", "Invalid language code."));
    }

    public static void ValidateVocabulary(IReadOnlyList<string>? words)
    {
        if (words is null || words.Count > 64
            || words.Any(word => string.IsNullOrWhiteSpace(word) || word != word.Trim() || word.Any(char.IsControl))
            || System.Text.Encoding.UTF8.GetByteCount(string.Join(", ", words)) > 800)
            throw new UserFacingException(UiText.T(
                "Vokabular: höchstens 64 Einträge und 800 UTF-8-Bytes. Leere Einträge und Steuerzeichen sind nicht erlaubt.",
                "Vocabulary: at most 64 entries and 800 UTF-8 bytes. Empty entries and control characters are not allowed."));
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
            throw new UserFacingException(UiText.T($"{error.Message} Korrigier den Wert in {path} oder lösch die Zeile.",
                $"{error.Message} Fix the stored value in {path} or delete its line."));
        }
        // The migrated choice is stored, so it still holds once
        // OPENAI_BASE_URL is gone.
        var migrated = settings.Migrated(Environment.GetEnvironmentVariable(ProviderServer.BaseUrlVariable));
        if (migrated != settings)
        {
            try { Save(path, migrated); }
            catch (UserFacingException) { /* Used for this run; stored at the next load or change. */ }
        }
        return migrated;
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
            throw new UserFacingException(UiText.T("Die Einstellungen ließen sich nicht speichern.", "The settings could not be saved."));
        }
    }
}
