using System.Globalization;
using System.Resources;

namespace FluxDrop.Windows;

public static class L
{
    static readonly ResourceManager Resources = new(
        "FluxDrop.Windows.Resources.Strings",
        typeof(L).Assembly
    );
    public static string Language { get; set; } = "es";

    public static string T(string key) =>
        Resources.GetString(key, CultureInfo.GetCultureInfo(Language)) ?? key;

    public static string Operation(string id) => T("op_" + id);
}
