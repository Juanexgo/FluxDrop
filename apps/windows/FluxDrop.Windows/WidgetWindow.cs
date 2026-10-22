using System.Collections.Specialized;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Shapes;

namespace FluxDrop.Windows;

public sealed class WidgetWindow : Window
{
    readonly MainWindow main;
    bool files;
    readonly Grid layout = new();

    public WidgetWindow(MainWindow main)
    {
        this.main = main;
        Title = "FluxDrop";
        Width = main.Preferences.WidgetSize;
        Height = Width + 84;
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        Foreground = Brushes.White;
        Topmost = true;
        ShowInTaskbar = false;
        ResizeMode = ResizeMode.NoResize;
        Content = layout;
        AllowDrop = true;
        Drop += (_, e) =>
        {
            main.AcceptDrop(e);
            e.Handled = true;
            Render();
        };
        PreviewKeyDown += (_, e) =>
        {
            if (e.Key == Key.Escape)
                Hide();
        };
        Deactivated += (_, _) =>
        {
            if (!IsMouseOver)
                Hide();
        };
        Render();
    }

    public void NearCursor()
    {
        Width = main.Preferences.WidgetSize;
        Height = Width + 84;
        Render();
        var cursor = System.Windows.Forms.Cursor.Position;
        var screen = System.Windows.Forms.Screen.FromPoint(cursor).WorkingArea;
        var source = PresentationSource.FromVisual(main);
        var transform = source?.CompositionTarget?.TransformFromDevice ?? Matrix.Identity;
        var point = transform.Transform(new Point(cursor.X, cursor.Y));
        var topLeft = transform.Transform(new Point(screen.Left, screen.Top));
        var bottomRight = transform.Transform(new Point(screen.Right, screen.Bottom));
        Left = Math.Clamp(
            point.X - Width / 2,
            topLeft.X,
            Math.Max(topLeft.X, bottomRight.X - Width)
        );
        Top = Math.Clamp(
            point.Y - Height / 2,
            topLeft.Y,
            Math.Max(topLeft.Y, bottomRight.Y - Height)
        );
        Show();
        Activate();
    }

    void Render()
    {
        bool dark = main.Foreground is SolidColorBrush foreground && foreground.Color.R > 200;
        Foreground = dark ? Brushes.White : Brushes.Black;
        layout.Children.Clear();
        var outer = new Border
        {
            CornerRadius = new CornerRadius(30),
            Background = new SolidColorBrush(
                dark ? Color.FromArgb(248, 35, 36, 39) : Color.FromArgb(250, 248, 247, 243)
            ),
            BorderBrush = new SolidColorBrush(Color.FromRgb(90, 85, 80)),
            BorderThickness = new Thickness(1),
            Padding = new Thickness(12),
        };
        layout.Children.Add(outer);
        var stack = new StackPanel();
        outer.Child = stack;
        stack.Children.Add(
            UI.Row(
                UI.Text("FluxDrop", 20),
                UI.Action(
                    files ? L.T("Back") : L.T("FileActions"),
                    () =>
                    {
                        files = !files;
                        Render();
                    }
                ),
                UI.Action("×", Hide)
            )
        );
        var canvas = new Canvas { Width = Width - 26, Height = Width - 26 };
        stack.Children.Add(canvas);
        double center = (Width - 26) / 2,
            radius = center * .68;
        var circle = new Ellipse
        {
            Width = center * 1.92,
            Height = center * 1.92,
            Stroke = new SolidColorBrush(Color.FromRgb(86, 79, 72)),
            StrokeThickness = 1,
            Fill = new SolidColorBrush(
                dark ? Color.FromRgb(44, 43, 43) : Color.FromRgb(215, 217, 211)
            ),
        };
        Canvas.SetLeft(circle, center * .04);
        Canvas.SetTop(circle, center * .04);
        canvas.Children.Add(circle);
        string[] labels = files
            ?
            [
                L.T("Copy"),
                L.T("CopyPath"),
                L.T("Move"),
                L.T("Shelf"),
                L.T("Terminal"),
                L.T("Share"),
            ]
            : main.Preferences.Favorites;
        for (int i = 0; i < labels.Length; i++)
        {
            int index = i;
            string value = labels[i];
            var button = new SectorButton(value, index, labels.Length, Width - 26, dark);
            button.Click += (_, _) =>
            {
                try
                {
                    Choose(index, value);
                }
                catch (Exception ex)
                {
                    MessageBox.Show(ex.Message, "FluxDrop");
                }
            };
            button.ToolTip = files ? value : L.T("Drop");
            button.AllowDrop = true;
            button.Drop += (_, e) =>
            {
                try
                {
                    main.AcceptDrop(e);
                    e.Handled = true;
                    Choose(index, value);
                }
                catch (Exception ex)
                {
                    MessageBox.Show(ex.Message, "FluxDrop");
                }
            };
            canvas.Children.Add(button);
        }
        var middle = UI.Action(
            main.Selection.Length == 0 ? L.T("Add") : main.Selection.Length + " ↓",
            () => main.AddFiles()
        );
        middle.Width = 78;
        middle.Height = 68;
        Canvas.SetLeft(middle, center - 39);
        Canvas.SetTop(middle, center - 34);
        canvas.Children.Add(middle);
        stack.Children.Add(
            UI.Action(
                L.T("Advanced"),
                () =>
                {
                    Hide();
                    main.Show();
                    main.Activate();
                }
            )
        );
    }

    void Choose(int index, string value)
    {
        if (files)
        {
            switch (index)
            {
                case 0:
                    main.CopyFiles();
                    break;
                case 1:
                    main.CopyPaths();
                    break;
                case 2:
                    main.MoveFiles();
                    break;
                case 3:
                    main.ShowShelf();
                    break;
                case 4:
                    main.OpenTerminal();
                    break;
                case 5:
                    main.ShareFiles();
                    break;
            }
        }
        else
            main.QuickConvert(value);
        Hide();
    }
}

public sealed class ShelfWindow : Window
{
    readonly ListBox list = new() { Margin = new Thickness(12) };

    public ShelfWindow(IEnumerable<string> files)
    {
        Title = L.T("Shelf");
        Width = 420;
        Height = 330;
        Topmost = true;
        var root = new DockPanel();
        var text = UI.Text(L.T("Drop"));
        DockPanel.SetDock(text, Dock.Top);
        root.Children.Add(text);
        root.Children.Add(list);
        Content = root;
        foreach (var f in files.Take(50))
            list.Items.Add(f);
        list.SelectionMode = SelectionMode.Extended;
        list.PreviewMouseMove += (_, e) =>
        {
            if (e.LeftButton == MouseButtonState.Pressed && list.SelectedItems.Count > 0)
            {
                var paths = new StringCollection();
                paths.AddRange(
                    list.SelectedItems.Cast<string>()
                        .Where(p => File.Exists(p) || Directory.Exists(p))
                        .ToArray()
                );
                var data = new DataObject();
                data.SetFileDropList(paths);
                DragDrop.DoDragDrop(list, data, DragDropEffects.Copy);
            }
        };
    }
}
