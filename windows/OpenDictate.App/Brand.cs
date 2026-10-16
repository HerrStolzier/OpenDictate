using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Shapes;
using OpenDictate.Core;

namespace OpenDictate.App;

// Colours, fonts and lengths from the design system (design/generated via
// DesignTokens.cs). The app uses the dark default theme Nacht everywhere;
// Theme.xaml styles the controls with the resources Install puts in place.
internal static class Brand
{
    internal const DesignTheme Theme = DesignTheme.Nacht;
    private static readonly Uri FontBase = new("pack://application:,,,/OpenDictate;component/");

    // Resource keys used by Theme.xaml.
    private static readonly (string Key, DesignColor Color)[] Colors =
    [
        ("Bg", DesignColor.Bg), ("Surface", DesignColor.Surface), ("Sunken", DesignColor.SurfaceSunken),
        ("Line", DesignColor.Line), ("Edge", DesignColor.Edge), ("Ink", DesignColor.Ink), ("InkMuted", DesignColor.InkMuted),
        ("Signal", DesignColor.Signal), ("OnSignal", DesignColor.OnSignal), ("FocusRingBrush", DesignColor.FocusRing),
    ];

    internal static void Install(Application app)
    {
        foreach (var (key, color) in Colors) app.Resources[key] = Brush(color);
        app.Resources["SansFont"] = Font(DesignFont.Sans);
        app.Resources["MonoFont"] = Font(DesignFont.Mono);
        app.Resources["PixelFont"] = Font(DesignFont.Pixel);
        app.Resources["BodySize"] = DesignFont.Body.Size;
        app.Resources["UiSize"] = DesignFont.Ui.Size;
        app.Resources["CodeSize"] = DesignFont.Code.Size;
        app.Resources["RadiusChip"] = new CornerRadius(DesignMetric.RadiusChip);
        app.Resources["RadiusCard"] = new CornerRadius(DesignMetric.RadiusCard);
        app.Resources.MergedDictionaries.Add(new ResourceDictionary { Source = new Uri("pack://application:,,,/OpenDictate;component/Theme.xaml") });
    }

    internal static Style Style(string key) => (Style)Application.Current.FindResource(key);

    internal static SolidColorBrush Brush(DesignColor color, DesignTheme theme = Theme)
    {
        var brush = new SolidColorBrush(ColorOf(color, theme));
        brush.Freeze();
        return brush;
    }

    private static Color ColorOf(DesignColor color, DesignTheme theme)
    {
        uint rgb = DesignTokens.Rgb(color, theme);
        return Color.FromRgb((byte)(rgb >> 16), (byte)(rgb >> 8), (byte)rgb);
    }

    internal static FontFamily Font(string family) => new(FontBase, $"./Fonts/#{family}");

    internal static TextBlock Text(string text, DesignTextStyle style, DesignColor color, DesignTheme theme = Theme) => new()
    {
        Text = text,
        FontFamily = Font(style.Family),
        FontSize = style.Size,
        LineHeight = style.LineHeight,
        FontWeight = FontWeight.FromOpenTypeWeight(style.Weight),
        Foreground = Brush(color, theme),
        TextWrapping = TextWrapping.Wrap,
    };

    // A key as it appears on the keyboard: stepped corners and a darker lower edge.
    internal static UIElement Keycap(string label) => new StepBorder
    {
        Background = Brush(DesignColor.Line),
        Child = new Border
        {
            BorderBrush = Brush(DesignColor.Bg),
            BorderThickness = new Thickness(0, 0, 0, DesignMetric.PixelStep),
            Padding = new Thickness(10, 4, 10, 4),
            Child = Text(label, DesignFont.Code, DesignColor.Ink),
        },
    };

    // A square in a state colour; it stands next to the state word, never alone.
    internal static Rectangle Mark(DesignColor color, double size = DesignMetric.Space2) => new()
    {
        Width = size, Height = size, Fill = Brush(color), VerticalAlignment = VerticalAlignment.Center,
    };

    // Blink at rest, from design/assets/logos/blink-32.svg (32 x 32 grid) plus its
    // floor shadow, scaled to size.
    internal static UIElement Blink(double size)
    {
        (int X, int Y, int W, int H, DesignColor Color)[] cells =
        [
            (7, 29, 18, 2, DesignColor.Floor),
            (12, 1, 1, 1, DesignColor.SignalLight), (13, 1, 6, 1, DesignColor.Signal), (19, 1, 1, 1, DesignColor.SignalShade),
            (11, 2, 2, 18, DesignColor.SignalLight), (13, 2, 6, 18, DesignColor.Signal), (19, 2, 2, 18, DesignColor.SignalShade),
            (12, 20, 1, 1, DesignColor.SignalLight), (13, 20, 6, 1, DesignColor.Signal), (19, 20, 1, 1, DesignColor.SignalShade),
            (12, 21, 2, 6, DesignColor.SignalDeep), (18, 21, 2, 6, DesignColor.SignalDeep),
            (9, 26, 5, 2, DesignColor.Sneaker), (9, 28, 5, 1, DesignColor.Sole),
            (18, 26, 5, 2, DesignColor.Sneaker), (18, 28, 5, 1, DesignColor.Sole),
        ];
        var canvas = new Canvas { Width = 32, Height = 32 };
        foreach (var (x, y, w, h, color) in cells)
        {
            var cell = new Rectangle { Width = w, Height = h, Fill = Brush(color) };
            Canvas.SetLeft(cell, x); Canvas.SetTop(cell, y);
            canvas.Children.Add(cell);
        }
        RenderOptions.SetEdgeMode(canvas, EdgeMode.Aliased);
        return new Viewbox { Width = size, Height = size, Child = canvas };
    }

    // Windows 11 draws the title bar in the window's background colour; older
    // versions ignore the attributes and keep their own.
    internal static void DarkTitleBar(Window window)
    {
        nint handle = new WindowInteropHelper(window).Handle;
        if (handle == 0) return;
        int dark = 1;
        Native.DwmSetWindowAttribute(handle, Native.DwmUseImmersiveDarkMode, ref dark, sizeof(int));
        var bg = ColorOf(DesignColor.Bg, Theme);
        int colorRef = bg.R | (bg.G << 8) | (bg.B << 16);
        Native.DwmSetWindowAttribute(handle, Native.DwmCaptionColor, ref colorRef, sizeof(int));
        Native.DwmSetWindowAttribute(handle, Native.DwmBorderColor, ref colorRef, sizeof(int));
    }
}
