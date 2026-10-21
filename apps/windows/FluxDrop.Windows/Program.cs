using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Media;
using FluxDrop.Core;

namespace FluxDrop.Windows;

public static class Program
{
    [STAThread]
    public static int Main(string[] args)
    {
        if (args.Contains("--self-test"))
            return WindowsChecks.Run(args);
        var app = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        app.DispatcherUnhandledException += (_, e) =>
        {
            MessageBox.Show(e.Exception.Message, "FluxDrop");
            e.Handled = true;
        };
        var window = new MainWindow();
        app.Run(window);
        return 0;
    }
}

public static class UI
{
    public static readonly SolidColorBrush Coral = new(Color.FromRgb(242, 112, 71));

    public static Button Action(string title, Action action)
    {
        var b = new Button
        {
            Content = title,
            Padding = new Thickness(14, 8, 14, 8),
            Margin = new Thickness(4),
            MinHeight = 36,
        };
        AutomationProperties.SetName(b, title);
        b.Click += (_, _) =>
        {
            try
            {
                action();
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "FluxDrop");
            }
        };
        return b;
    }

    public static TextBlock Text(string text, int size = 14) =>
        new()
        {
            Text = text,
            FontSize = size,
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(4, 6, 4, 6),
        };

    public static StackPanel Row(params UIElement[] children)
    {
        var p = new StackPanel { Orientation = Orientation.Horizontal };
        foreach (var c in children)
            p.Children.Add(c);
        return p;
    }

    public static TextBox Field(Panel panel, string label, string value = "")
    {
        panel.Children.Add(Text(label));
        var box = new TextBox
        {
            Text = value,
            Margin = new Thickness(4),
            Padding = new Thickness(8),
            MinWidth = 140,
        };
        AutomationProperties.SetName(box, label);
        panel.Children.Add(box);
        return box;
    }

    public static CheckBox Toggle(Panel panel, string label, bool value)
    {
        var b = new CheckBox
        {
            Content = label,
            IsChecked = value,
            Margin = new Thickness(4, 8, 4, 8),
        };
        AutomationProperties.SetName(b, label);
        panel.Children.Add(b);
        return b;
    }

    public static string? Folder()
    {
        var picker = new Microsoft.Win32.OpenFolderDialog();
        return picker.ShowDialog() == true ? picker.FolderName : null;
    }
}
