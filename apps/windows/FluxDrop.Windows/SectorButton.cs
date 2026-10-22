using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;

namespace FluxDrop.Windows;

/// <summary>Keyboard-accessible button with an annular sector as its real hit target.</summary>
public sealed class SectorButton : Button
{
    readonly Geometry shape;
    readonly Point labelPoint;
    readonly string title;
    readonly bool dark;

    public SectorButton(string title, int index, int count, double size, bool dark)
    {
        this.title = title;
        this.dark = dark;
        Content = title;
        Width = size;
        Height = size;
        Margin = new Thickness(0);
        Padding = new Thickness(0);
        Template = new ControlTemplate(typeof(Button));
        FocusVisualStyle = null;
        System.Windows.Automation.AutomationProperties.SetName(this, title);
        double center = size / 2,
            outer = center * .94,
            inner = center * .33;
        double mid = index * 360d / count - 90,
            start = mid - 360d / count * .465,
            end = mid + 360d / count * .465;
        Point P(double r, double angle) =>
            new(
                center + r * Math.Cos(angle * Math.PI / 180),
                center + r * Math.Sin(angle * Math.PI / 180)
            );
        labelPoint = P((outer + inner) / 2, mid);
        var geometry = new StreamGeometry();
        using (var g = geometry.Open())
        {
            g.BeginFigure(P(outer, start), true, true);
            g.ArcTo(
                P(outer, end),
                new Size(outer, outer),
                0,
                false,
                SweepDirection.Clockwise,
                true,
                false
            );
            g.LineTo(P(inner, end), true, false);
            g.ArcTo(
                P(inner, start),
                new Size(inner, inner),
                0,
                false,
                SweepDirection.Counterclockwise,
                true,
                false
            );
        }
        geometry.Freeze();
        shape = geometry;
    }

    protected override void OnRender(DrawingContext dc)
    {
        bool active = IsMouseOver || IsKeyboardFocused;
        var background = active
            ? UI.Coral
            : new SolidColorBrush(dark ? Color.FromRgb(64, 65, 68) : Color.FromRgb(232, 233, 229));
        var foreground = dark && !active ? Brushes.White : Brushes.Black;
        dc.DrawGeometry(
            background,
            new Pen(
                new SolidColorBrush(
                    dark ? Color.FromRgb(96, 96, 96) : Color.FromRgb(199, 202, 195)
                ),
                IsKeyboardFocused ? 2 : 1
            ),
            shape
        );
        var text = new FormattedText(
            title.ToUpperInvariant(),
            CultureInfo.CurrentUICulture,
            System.Windows.FlowDirection.LeftToRight,
            new Typeface("Segoe UI"),
            Math.Clamp(Width / 34, 10, 13),
            foreground,
            VisualTreeHelper.GetDpi(this).PixelsPerDip
        )
        {
            MaxTextWidth = Width * .27,
            TextAlignment = TextAlignment.Center,
            Trimming = TextTrimming.CharacterEllipsis,
        };
        dc.DrawText(
            text,
            new Point(labelPoint.X - text.MaxTextWidth / 2, labelPoint.Y - text.Height / 2)
        );
    }

    protected override HitTestResult? HitTestCore(PointHitTestParameters p) =>
        shape.FillContains(p.HitPoint) ? new PointHitTestResult(this, p.HitPoint) : null;

    protected override void OnMouseEnter(System.Windows.Input.MouseEventArgs e)
    {
        base.OnMouseEnter(e);
        InvalidateVisual();
    }

    protected override void OnMouseLeave(System.Windows.Input.MouseEventArgs e)
    {
        base.OnMouseLeave(e);
        InvalidateVisual();
    }

    protected override void OnGotKeyboardFocus(KeyboardFocusChangedEventArgs e)
    {
        base.OnGotKeyboardFocus(e);
        InvalidateVisual();
    }

    protected override void OnLostKeyboardFocus(KeyboardFocusChangedEventArgs e)
    {
        base.OnLostKeyboardFocus(e);
        InvalidateVisual();
    }
}
