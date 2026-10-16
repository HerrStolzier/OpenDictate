using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using OpenDictate.Core;

namespace OpenDictate.App;

// A border with the design system's stepped corners: two steps of pixel-step
// per corner instead of a rounding. Buttons, fields and keycaps use it.
public sealed class StepBorder : Border
{
    protected override void OnRenderSizeChanged(SizeChangedInfo info)
    {
        base.OnRenderSizeChanged(info);
        Clip = Outline(info.NewSize, DesignMetric.PixelStep);
    }

    internal static Geometry Outline(Size size, double step)
    {
        double w = size.Width, h = size.Height, s = step, d = 2 * step;
        if (w < 2 * d || h < 2 * d) return new RectangleGeometry(new Rect(size));
        Point[] points =
        [
            new(0, d), new(s, d), new(s, s), new(d, s), new(d, 0),
            new(w - d, 0), new(w - d, s), new(w - s, s), new(w - s, d), new(w, d),
            new(w, h - d), new(w - s, h - d), new(w - s, h - s), new(w - d, h - s), new(w - d, h),
            new(d, h), new(d, h - s), new(s, h - s), new(s, h - d), new(0, h - d),
        ];
        var geometry = new StreamGeometry();
        using (var context = geometry.Open())
        {
            context.BeginFigure(points[0], isFilled: true, isClosed: true);
            context.PolyLineTo(points[1..], isStroked: false, isSmoothJoin: false);
        }
        geometry.Freeze();
        return geometry;
    }
}
