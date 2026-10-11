// Generated from design/tokens.json by scripts/design-tokens.py. Do not edit.

namespace OpenDictate.Core;

public enum DesignTheme { Nacht, Bernstein, Papier }

public enum DesignColor
{
    Bg,
    Surface,
    SurfaceSunken,
    Line,
    Ink,
    InkMuted,
    Signal,
    SignalLight,
    SignalShade,
    SignalDeep,
    SignalInk,
    OnSignal,
    Rec,
    Warn,
    Sneaker,
    SneakerLight,
    Sole,
    Floor,
    Glitch,
    FocusRing,
}

public static class DesignTokens
{
    // sRGB value as 0xRRGGBB.
    public static uint Rgb(DesignColor color, DesignTheme theme) => (color, theme) switch
    {
        (DesignColor.Bg, DesignTheme.Nacht) => 0x0E1014,
        (DesignColor.Bg, DesignTheme.Bernstein) => 0x17110A,
        (DesignColor.Bg, DesignTheme.Papier) => 0xEDEEE9,
        (DesignColor.Surface, DesignTheme.Nacht) => 0x181C23,
        (DesignColor.Surface, DesignTheme.Bernstein) => 0x22190F,
        (DesignColor.Surface, DesignTheme.Papier) => 0xFFFFFF,
        (DesignColor.SurfaceSunken, DesignTheme.Nacht) => 0x12151A,
        (DesignColor.SurfaceSunken, DesignTheme.Bernstein) => 0x120D07,
        (DesignColor.SurfaceSunken, DesignTheme.Papier) => 0xE2E4DD,
        (DesignColor.Line, DesignTheme.Nacht) => 0x2A303A,
        (DesignColor.Line, DesignTheme.Bernstein) => 0x3A2C1B,
        (DesignColor.Line, DesignTheme.Papier) => 0xC9CCC3,
        (DesignColor.Ink, DesignTheme.Nacht) => 0xE9EEE2,
        (DesignColor.Ink, DesignTheme.Bernstein) => 0xFFE9C7,
        (DesignColor.Ink, DesignTheme.Papier) => 0x14161A,
        (DesignColor.InkMuted, DesignTheme.Nacht) => 0x8F988A,
        (DesignColor.InkMuted, DesignTheme.Bernstein) => 0xB49A74,
        (DesignColor.InkMuted, DesignTheme.Papier) => 0x585D63,
        (DesignColor.Signal, DesignTheme.Nacht) => 0xB6FF4D,
        (DesignColor.Signal, DesignTheme.Bernstein) => 0xFFB23F,
        (DesignColor.Signal, DesignTheme.Papier) => 0x1A4FE0,
        (DesignColor.SignalLight, DesignTheme.Nacht) => 0xDDFFA8,
        (DesignColor.SignalLight, DesignTheme.Bernstein) => 0xFFD796,
        (DesignColor.SignalLight, DesignTheme.Papier) => 0x7F9DFF,
        (DesignColor.SignalShade, DesignTheme.Nacht) => 0x86CC2E,
        (DesignColor.SignalShade, DesignTheme.Bernstein) => 0xD98E22,
        (DesignColor.SignalShade, DesignTheme.Papier) => 0x1440B8,
        (DesignColor.SignalDeep, DesignTheme.Nacht) => 0x7AB82A,
        (DesignColor.SignalDeep, DesignTheme.Bernstein) => 0xB8741A,
        (DesignColor.SignalDeep, DesignTheme.Papier) => 0x12389F,
        (DesignColor.SignalInk, DesignTheme.Nacht) => 0x5E9420,
        (DesignColor.SignalInk, DesignTheme.Bernstein) => 0x8F5810,
        (DesignColor.SignalInk, DesignTheme.Papier) => 0x0C2A7A,
        (DesignColor.OnSignal, DesignTheme.Nacht) => 0x0E1014,
        (DesignColor.OnSignal, DesignTheme.Bernstein) => 0x17110A,
        (DesignColor.OnSignal, DesignTheme.Papier) => 0xFFFFFF,
        (DesignColor.Rec, DesignTheme.Nacht) => 0xFF5D5D,
        (DesignColor.Rec, DesignTheme.Bernstein) => 0xFF6A4D,
        (DesignColor.Rec, DesignTheme.Papier) => 0xB52A1A,
        (DesignColor.Warn, DesignTheme.Nacht) => 0xFFD84D,
        (DesignColor.Warn, DesignTheme.Bernstein) => 0xFFEFB0,
        (DesignColor.Warn, DesignTheme.Papier) => 0x8A5A00,
        (DesignColor.Sneaker, DesignTheme.Nacht) => 0xF2F5EE,
        (DesignColor.Sneaker, DesignTheme.Bernstein) => 0xFFF3DE,
        (DesignColor.Sneaker, DesignTheme.Papier) => 0x2A2F38,
        (DesignColor.SneakerLight, DesignTheme.Nacht) => 0xFFFFFF,
        (DesignColor.SneakerLight, DesignTheme.Bernstein) => 0xFFFFFF,
        (DesignColor.SneakerLight, DesignTheme.Papier) => 0x4A515E,
        (DesignColor.Sole, DesignTheme.Nacht) => 0x9AA394,
        (DesignColor.Sole, DesignTheme.Bernstein) => 0xB49A74,
        (DesignColor.Sole, DesignTheme.Papier) => 0x585D63,
        (DesignColor.Floor, DesignTheme.Nacht) => 0x07080A,
        (DesignColor.Floor, DesignTheme.Bernstein) => 0x0A0704,
        (DesignColor.Floor, DesignTheme.Papier) => 0xC9CCC3,
        (DesignColor.Glitch, DesignTheme.Nacht) => 0x5CE1E6,
        (DesignColor.Glitch, DesignTheme.Bernstein) => 0x5CE1E6,
        (DesignColor.Glitch, DesignTheme.Papier) => 0x008C95,
        (DesignColor.FocusRing, DesignTheme.Nacht) => 0xB6FF4D,
        (DesignColor.FocusRing, DesignTheme.Bernstein) => 0xFFB23F,
        (DesignColor.FocusRing, DesignTheme.Papier) => 0x1A4FE0,
        _ => throw new ArgumentOutOfRangeException(nameof(color)),
    };
}

// Lengths in device-independent pixels; RadiusIcon is a fraction of the icon size.
public static class DesignMetric
{
    public const double Space1 = 4.0;
    public const double Space2 = 8.0;
    public const double Space3 = 12.0;
    public const double Space4 = 16.0;
    public const double Space6 = 24.0;
    public const double Space8 = 32.0;
    public const double Space12 = 48.0;
    public const double Space16 = 64.0;
    public const double RadiusChip = 8.0;
    public const double RadiusCard = 18.0;
    public const double RadiusIcon = 0.225;
    public const double PixelStep = 3.0;
    public const double PixelIcon = 36.0;
    public const double MeterCell = 8.0;
    public const double MeterGap = 3.0;
}

// Letter spacing is a fraction of Size (CSS em); 0 when the style sets none.
public sealed record DesignTextStyle(string Family, double Size, double LineHeight, int Weight, double Tracking);

public static class DesignFont
{
    public const string Pixel = "Geist Pixel";
    public const string Mono = "Geist Mono";
    public const string Sans = "Geist";

    public static readonly DesignTextStyle Display = new(Pixel, 64.0, 64.0, 400, -0.01);
    public static readonly DesignTextStyle Title = new(Pixel, 40.0, 44.0, 400, 0.0);
    public static readonly DesignTextStyle Heading = new(Pixel, 24.0, 30.0, 400, 0.0);
    public static readonly DesignTextStyle Lead = new(Sans, 18.0, 28.0, 400, 0.0);
    public static readonly DesignTextStyle Body = new(Sans, 15.0, 24.0, 400, 0.0);
    public static readonly DesignTextStyle Strong = new(Sans, 15.0, 24.0, 600, 0.0);
    public static readonly DesignTextStyle Small = new(Sans, 13.0, 20.0, 400, 0.0);
    public static readonly DesignTextStyle Ui = new(Mono, 14.0, 20.0, 600, 0.0);
    public static readonly DesignTextStyle Label = new(Mono, 12.0, 16.0, 400, 0.02);
    public static readonly DesignTextStyle Code = new(Mono, 13.0, 20.0, 400, 0.0);
}
