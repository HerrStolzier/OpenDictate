using OpenDictate.Core;

namespace OpenDictate.Provider;

// One word per state for the small dictation indicator, as on macOS and in
// the Linux bar (design/brand.md). It never takes the focus.
public enum IndicatorPhase { Closed, Listening, Writing, Inserted, Copied, Oops }

public static class IndicatorText
{
    public static string Word(IndicatorPhase phase) => phase switch
    {
        IndicatorPhase.Listening => UiText.T("Hört zu", "Listening"),
        IndicatorPhase.Writing => UiText.T("Schreibt", "Writing"),
        IndicatorPhase.Inserted => UiText.T("Eingefügt", "Pasted"),
        IndicatorPhase.Copied => UiText.T("Kopiert", "Copied"),
        IndicatorPhase.Oops => UiText.T("Hoppla", "Oops"),
        _ => UiText.T("Bereit", "Ready"),
    };

    // The line under the word. An error's reason says what is safe.
    public static string Detail(IndicatorPhase phase, TimeSpan elapsed = default, bool translating = false, string reason = "") => phase switch
    {
        IndicatorPhase.Listening => Listening(elapsed, RecordingLimit),
        IndicatorPhase.Writing => translating ? UiText.T("Wird übersetzt", "Translating") : UiText.T("Wird umgewandelt", "Transcribing"),
        // The app cannot see whether the target accepted Ctrl+V.
        IndicatorPhase.Inserted => UiText.T("per Strg+V, kurz prüfen", "with Ctrl+V, check it"),
        IndicatorPhase.Copied => UiText.T("Nicht eingefügt. Der Text liegt in der Zwischenablage.", "Not pasted. The text is on the clipboard."),
        IndicatorPhase.Oops => reason,
        _ => "",
    };

    // Successful endings close by themselves; the copied text needs a manual
    // paste, so its longer line stays a little longer. An error stays.
    public static TimeSpan? ClosesAfter(IndicatorPhase phase) => phase switch
    {
        IndicatorPhase.Inserted => TimeSpan.FromSeconds(2),
        IndicatorPhase.Copied => TimeSpan.FromSeconds(4),
        _ => null,
    };

    public static readonly TimeSpan RecordingLimit = TimeSpan.FromSeconds(90);

    // m:ss, rounded down to whole seconds.
    public static string Clock(TimeSpan elapsed)
    {
        int whole = Math.Max(0, (int)elapsed.TotalSeconds);
        return $"{whole / 60}:{whole % 60:00}";
    }

    // The recording line counts down during the last ten seconds before the
    // automatic stop.
    public static string Listening(TimeSpan elapsed, TimeSpan limit)
    {
        int left = Math.Max(0, (int)Math.Ceiling((limit - elapsed).TotalSeconds));
        return left <= 10 ? UiText.T($"REC · Stopp in {left} s", $"REC · stops in {left} s") : "REC " + Clock(elapsed);
    }

    // What the indicator shows once a dictation has ended; null closes it.
    // saved: this dictation's recording reached the protected store.
    public static (IndicatorPhase Phase, string Reason)? Ending(DictationResult result, bool saved)
    {
        string safe = saved ? " " + UiText.T("Deine Aufnahme ist gesichert.", "Your recording is saved.") : "";
        return result.Outcome switch
        {
            DictationOutcome.Delivered => (IndicatorPhase.Inserted, ""),
            DictationOutcome.ManualDelivery => (IndicatorPhase.Copied, ""),
            DictationOutcome.Cancelled => null,
            DictationOutcome.EmptyResponse => (IndicatorPhase.Oops, UiText.T("Nichts erkannt.", "Nothing recognized.") + safe),
            DictationOutcome.DeliveryUncertain => (IndicatorPhase.Oops, UiText.T(
                "Einfügen nicht bestätigt. Bitte prüfen; der Text liegt unter „Letzten Text kopieren“.",
                "Paste not confirmed. Please check; the text is under “Copy last text”.")),
            _ => (IndicatorPhase.Oops, (result.Message ?? UiText.T("Das hat nicht geklappt.", "That did not work.")) + safe),
        };
    }
}
