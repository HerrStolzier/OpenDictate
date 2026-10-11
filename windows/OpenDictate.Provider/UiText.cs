using System.Globalization;

namespace OpenDictate.Provider;

// User-facing text follows the Windows display language: German on German
// systems, English everywhere else (decision of 8 October 2026).
public static class UiText
{
    public static bool IsGerman => CultureInfo.CurrentUICulture.TwoLetterISOLanguageName == "de";
    public static string T(string german, string english) => IsGerman ? german : english;
}
