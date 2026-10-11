using System;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Shapes;
using System.Windows.Threading;
using OpenDictate.Core;
using OpenDictate.Provider;
using Forms = System.Windows.Forms;

namespace OpenDictate.App;

// The small dark pill at the top of the screen the dictation started on. It
// never activates or takes the focus, so Ctrl+V reaches the window the user
// was in, and it lets clicks through except on an error's buttons.
internal sealed class IndicatorWindow : Window
{
    private const DesignTheme Theme = DesignTheme.Nacht;
    private readonly TextBlock word = Brand.Text("", DesignFont.Heading with { Size = 20, LineHeight = 24 }, DesignColor.Ink, Theme);
    private readonly TextBlock detail = Brand.Text("", DesignFont.Label, DesignColor.InkMuted, Theme);
    private readonly Ellipse dot = new() { Width = 10, Height = 10, VerticalAlignment = VerticalAlignment.Center };
    private readonly StackPanel meter = new() { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
    private readonly Button retry;
    private readonly Button close;
    private readonly StackPanel buttons = new() { Orientation = Orientation.Horizontal, Margin = new Thickness(0, DesignMetric.Space3, 0, 0) };
    private readonly DispatcherTimer closer = new();
    private nint handle;
    private bool clickable;

    internal IndicatorPhase Phase { get; private set; } = IndicatorPhase.Closed;
    internal event Action? RetryRequested;

    internal IndicatorWindow()
    {
        WindowStyle = WindowStyle.None; AllowsTransparency = true; Background = Brushes.Transparent;
        Topmost = true; ShowInTaskbar = false; ShowActivated = false; Focusable = false;
        ResizeMode = ResizeMode.NoResize; SizeToContent = SizeToContent.WidthAndHeight;
        Title = "OpenDictate";
        retry = MakeButton(UiText.T("Nochmal senden", "Send again"), DesignColor.Signal, DesignColor.OnSignal);
        close = MakeButton(UiText.T("Schließen", "Close"), DesignColor.Surface, DesignColor.Ink);
        retry.Click += (_, _) => { Hide(IndicatorPhase.Closed); RetryRequested?.Invoke(); };
        close.Click += (_, _) => Hide(IndicatorPhase.Closed);
        buttons.Children.Add(retry); buttons.Children.Add(close);
        for (int i = 0; i < 5; i++)
            meter.Children.Add(new Rectangle { Width = DesignMetric.MeterCell, Height = DesignMetric.MeterCell, Margin = new Thickness(0, 0, DesignMetric.MeterGap, 0) });
        var line = new StackPanel { Orientation = Orientation.Horizontal };
        dot.Margin = new Thickness(0, 0, DesignMetric.Space3, 0);
        word.Margin = new Thickness(0, 0, DesignMetric.Space3, 0);
        word.TextWrapping = TextWrapping.NoWrap;
        word.VerticalAlignment = detail.VerticalAlignment = VerticalAlignment.Center;
        meter.Margin = new Thickness(DesignMetric.Space2, 0, 0, 0);
        line.Children.Add(dot); line.Children.Add(word); line.Children.Add(detail); line.Children.Add(meter);
        var body = new StackPanel(); body.Children.Add(line); body.Children.Add(buttons);
        detail.MaxWidth = 380;
        Content = new Border
        {
            Background = Brand.Brush(DesignColor.Bg, Theme),
            BorderBrush = Brand.Brush(DesignColor.Line, Theme),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(DesignMetric.RadiusCard),
            Padding = new Thickness(DesignMetric.Space4, DesignMetric.Space3, DesignMetric.Space6, DesignMetric.Space3),
            Child = body,
        };
        AutomationProperties.SetLiveSetting(detail, AutomationLiveSetting.Polite);
        closer.Tick += (_, _) => Hide(IndicatorPhase.Closed);
        SourceInitialized += (_, _) =>
        {
            handle = new WindowInteropHelper(this).Handle;
            ApplyStyle();
        };
        SizeChanged += (_, _) => Place();
    }

    private static Button MakeButton(string text, DesignColor background, DesignColor foreground) => new()
    {
        Content = Brand.Text(text, DesignFont.Ui, foreground, Theme),
        Background = Brand.Brush(background, Theme),
        BorderBrush = Brand.Brush(DesignColor.Line, Theme),
        Padding = new Thickness(DesignMetric.Space4, DesignMetric.Space2, DesignMetric.Space4, DesignMetric.Space2),
        Margin = new Thickness(0, 0, DesignMetric.Space2, 0),
        MinHeight = 36,
        Focusable = false,
    };

    // Screen of the window the dictation belongs to; the primary one otherwise.
    internal nint Anchor { get; set; }

    internal void Show(IndicatorPhase phase, string line, bool canRetry = false)
    {
        Phase = phase;
        closer.Stop();
        if (phase == IndicatorPhase.Closed) { Hide(); return; }
        word.Text = IndicatorText.Word(phase);
        detail.Text = line;
        dot.Fill = Brand.Brush(phase switch
        {
            IndicatorPhase.Listening or IndicatorPhase.Oops => DesignColor.Rec,
            IndicatorPhase.Copied => DesignColor.Warn,
            _ => DesignColor.Signal,
        }, Theme);
        meter.Visibility = phase == IndicatorPhase.Listening ? Visibility.Visible : Visibility.Collapsed;
        buttons.Visibility = phase == IndicatorPhase.Oops ? Visibility.Visible : Visibility.Collapsed;
        retry.Visibility = canRetry ? Visibility.Visible : Visibility.Collapsed;
        clickable = phase == IndicatorPhase.Oops;
        if (IndicatorText.ClosesAfter(phase) is { } after) { closer.Interval = after; closer.Start(); }
        AutomationProperties.SetName(this, string.IsNullOrEmpty(line) ? $"OpenDictate: {word.Text}" : $"OpenDictate: {word.Text}. {line}");
        if (!IsVisible) base.Show();
        ApplyStyle();
        Place();
    }

    internal void UpdateLine(string line, float level)
    {
        detail.Text = line;
        // Five cells light up with the input level, like the Mac meter.
        int lit = (int)Math.Ceiling(Math.Clamp(level * 4, 0, 1) * meter.Children.Count);
        for (int i = 0; i < meter.Children.Count; i++)
            ((Rectangle)meter.Children[i]).Fill = Brand.Brush(i < lit ? DesignColor.Signal : DesignColor.Line, Theme);
    }

    private void Hide(IndicatorPhase phase)
    {
        Phase = phase;
        closer.Stop();
        Hide();
    }

    private void ApplyStyle()
    {
        if (handle == 0) return;
        long style = Native.GetWindowLongPtrW(handle, Native.ExStyle);
        style |= Native.NoActivate | Native.ToolWindow;
        style = clickable ? style & ~Native.Transparent : style | Native.Transparent;
        Native.SetWindowLongPtrW(handle, Native.ExStyle, (nint)style);
    }

    private void Place()
    {
        if (!IsVisible) return;
        var screen = Anchor != 0 ? Forms.Screen.FromHandle(Anchor) : Forms.Screen.PrimaryScreen!;
        var area = screen.WorkingArea;
        var source = PresentationSource.FromVisual(this);
        double scaleX = source?.CompositionTarget?.TransformToDevice.M11 ?? 1;
        double scaleY = source?.CompositionTarget?.TransformToDevice.M22 ?? 1;
        Left = (area.Left + (area.Width - ActualWidth * scaleX) / 2) / scaleX;
        Top = (area.Top + DesignMetric.Space3 * scaleY) / scaleY;
    }
}
