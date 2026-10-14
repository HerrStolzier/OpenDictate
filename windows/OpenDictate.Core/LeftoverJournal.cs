namespace OpenDictate.Core;

// A journal folder that outlived its dictation: the app ended before sealing,
// or sealing failed and the original was kept for the user. It holds plaintext
// audio, so it goes once it reaches the recovery limit of 24 hours, never
// earlier, and only while it holds nothing but a journal's own files.
public static class LeftoverJournal
{
    public static readonly TimeSpan MaximumAge = TimeSpan.FromHours(24);

    private static readonly string[] JournalFiles =
        [PcmJournal.FormatFileName, PcmJournal.RawFileName, PcmJournal.WaveFileName];

    // The newest timestamp counts, so a folder written to later is kept longer.
    public static bool MayRemove(string folderName, IEnumerable<string> entryNames,
        IEnumerable<DateTimeOffset> timestamps, DateTimeOffset now)
    {
        if (!Guid.TryParseExact(folderName, "N", out _)) return false;
        var names = entryNames.ToArray();
        if (names.Any(name => !JournalFiles.Contains(name, StringComparer.OrdinalIgnoreCase)) ||
            names.Distinct(StringComparer.OrdinalIgnoreCase).Count() != names.Length) return false;
        var stamps = timestamps.ToArray();
        return stamps.Length > 0 && now - stamps.Max() >= MaximumAge;
    }
}
