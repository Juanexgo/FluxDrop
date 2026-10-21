using System.IO.Compression;
using System.Text;

namespace FluxDrop.Core;

public class PortableEngine : IEngine
{
    public virtual IReadOnlyList<Capability> Capabilities { get; } =
        DataEngine
            .Ids.Select(id => new Capability(
                id,
                "data",
                id.StartsWith("yaml") ? ["yaml", "yml"]
                    : id.StartsWith("json") ? ["json"]
                    : id.StartsWith("markdown") ? ["md", "markdown"]
                    : id.StartsWith("tsv") ? ["tsv"]
                    : ["csv"],
                id switch
                {
                    "jsonYAML" => "yaml",
                    "jsonCSV" or "tsvCSV" => "csv",
                    "csvTSV" => "tsv",
                    "markdownHTML" => "html",
                    _ => "json",
                }
            ))
            .Concat(
                new[] { "zip", "tar", "gzip" }.SelectMany(t =>
                    new[]
                    {
                        new Capability(
                            t + "Create",
                            "archive",
                            [],
                            t == "gzip" ? "gz" : t,
                            false,
                            t != "gzip"
                        ),
                        new Capability(
                            t + "Extract",
                            "archive",
                            [t == "gzip" ? "gz" : t],
                            "folder"
                        ),
                    }
                )
            )
            .Concat([
                new Capability("renameCopy", "folder", [], "copy", false, true),
                new Capability("duplicates", "folder", [], "json", false, true),
            ])
            .ToArray();

    public virtual async Task<Result> ExecuteAsync(
        Request r,
        IProgress<double?>? progress,
        CancellationToken token
    )
    {
        r.Options.Validate();
        if (r.Inputs.Length == 0 || r.Inputs.Length > 10000)
            throw new ArgumentException("Selecciona entre 1 y 10 000 entradas.");
        foreach (var i in r.Inputs)
            SafeFiles.Input(i);
        SafeFiles.Space(r.Destination, 0);
        string work = SafeFiles.Temp(r.Destination);
        try
        {
            token.ThrowIfCancellationRequested();
            if (DataEngine.Ids.Contains(r.Operation))
            {
                if (r.Inputs.Length != 1)
                    throw new ArgumentException("Una entrada por trabajo.");
                var text = await SafeFiles.Text(r.Inputs[0], token);
                var (extension, content) = DataEngine.Convert(r.Operation, text, r.Options);
                string temp = Path.Combine(work, "output");
                await File.WriteAllTextAsync(temp, content, new UTF8Encoding(false), token);
                if (extension == "json")
                    DataEngine.Json(await SafeFiles.Text(temp, token));
                else if (extension is "csv" or "tsv")
                    DataEngine.Csv(
                        await SafeFiles.Text(temp, token),
                        extension == "tsv" ? '\t' : r.Options.Delimiter
                    );
                token.ThrowIfCancellationRequested();
                return new([
                    SafeFiles.Publish(
                        temp,
                        r.Destination,
                        Path.GetFileNameWithoutExtension(r.Inputs[0]) + "-fluxdrop." + extension
                    ),
                ]);
            }
            if (r.Operation == "duplicates")
            {
                var hashes = new Dictionary<string, List<string>>();
                foreach (var f in r.Inputs.SelectMany(SafeFiles.Walk))
                {
                    token.ThrowIfCancellationRequested();
                    string key = new FileInfo(f).Length + ":" + await SafeFiles.Hash(f, token);
                    if (!hashes.TryGetValue(key, out var files))
                        hashes[key] = files = [];
                    files.Add(f);
                }
                string temp = Path.Combine(work, "output");
                Config.Write(temp, hashes.Values.Where(g => g.Count > 1).ToArray());
                return new(
                    [SafeFiles.Publish(temp, r.Destination, "duplicados.json")],
                    "Informe por SHA-256. No se ha eliminado ningún archivo."
                );
            }
            if (r.Operation == "renameCopy")
            {
                var names = RenamePreview(r.Inputs, r.Options);
                string stage = Path.Combine(work, "copies");
                Directory.CreateDirectory(stage);
                for (int i = 0; i < r.Inputs.Length; i++)
                {
                    token.ThrowIfCancellationRequested();
                    await using (var source = File.OpenRead(r.Inputs[i]))
                    await using (var dest = File.Create(Path.Combine(stage, names[i])))
                        await source.CopyToAsync(dest, token);
                    if (
                        await SafeFiles.Hash(r.Inputs[i], token)
                        != await SafeFiles.Hash(Path.Combine(stage, names[i]), token)
                    )
                        throw new IOException("La copia no coincide con el original.");
                    progress?.Report((i + 1d) / r.Inputs.Length);
                }
                token.ThrowIfCancellationRequested();
                return new([SafeFiles.PublishDirectory(stage, r.Destination, "renombrados")]);
            }
            if (
                r.Operation.EndsWith("Create", StringComparison.Ordinal)
                || r.Operation.EndsWith("Extract", StringComparison.Ordinal)
            )
            {
                string temp = await ArchiveEngine.Run(r, work, token);
                token.ThrowIfCancellationRequested();
                string name = Path.GetFileNameWithoutExtension(r.Inputs[0]);
                if (Directory.Exists(temp))
                    return new([
                        SafeFiles.PublishDirectory(temp, r.Destination, name + "-extraido"),
                    ]);
                string ext =
                    r.Operation.StartsWith("zip", StringComparison.Ordinal) ? "zip"
                    : r.Operation.StartsWith("tar", StringComparison.Ordinal) ? "tar"
                    : "gz";
                if (r.Operation == "gzipExtract")
                    ext = "bin";
                return new([SafeFiles.Publish(temp, r.Destination, name + "-fluxdrop." + ext)]);
            }
            throw new NotSupportedException("Esta operación no está disponible en el motor.");
        }
        finally
        {
            if (Directory.Exists(work))
                Directory.Delete(work, true);
        }
    }

    public static string[] RenamePreview(string[] inputs, Options o)
    {
        var names = inputs
            .Select(
                (p, i) =>
                    SafeFiles.SafeName(
                        o.Prefix
                            + (o.Number ? (i + 1).ToString("D3") + "-" : "")
                            + (
                                o.Replace.Length == 0
                                    ? Path.GetFileNameWithoutExtension(p)
                                    : Path.GetFileNameWithoutExtension(p)
                                        .Replace(o.Replace, o.With, StringComparison.Ordinal)
                            )
                            + o.Suffix
                            + Path.GetExtension(p)
                    )
            )
            .ToArray();
        if (names.Distinct(StringComparer.OrdinalIgnoreCase).Count() != names.Length)
            throw new IOException("La vista previa contiene nombres repetidos.");
        return names;
    }
}
