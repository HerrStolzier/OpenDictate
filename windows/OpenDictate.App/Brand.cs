using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using OpenDictate.Core;

namespace OpenDictate.App;

// Colours, fonts and lengths from the design system (design/generated via
// DesignTokens.cs). The indicator is dark (Nacht) like on macOS; the settings
// window uses the light Papier theme so standard Windows controls fit.
internal static class Brand
{
    private static readonly Uri FontBase = new("pack://application:,,,/OpenDictate;component/");

    internal static SolidColorBrush Brush(DesignColor color, DesignTheme theme)
    {
        uint rgb = DesignTokens.Rgb(color, theme);
        var brush = new SolidColorBrush(Color.FromRgb((byte)(rgb >> 16), (byte)(rgb >> 8), (byte)rgb));
        brush.Freeze();
        return brush;
    }

    internal static FontFamily Font(string family) => new(FontBase, $"./Fonts/#{family}");

    internal static TextBlock Text(string text, DesignTextStyle style, DesignColor color, DesignTheme theme) => new()
    {
        Text = text,
        FontFamily = Font(style.Family),
        FontSize = style.Size,
        LineHeight = style.LineHeight,
        FontWeight = FontWeight.FromOpenTypeWeight(style.Weight),
        Foreground = Brush(color, theme),
        TextWrapping = TextWrapping.Wrap,
    };
}
