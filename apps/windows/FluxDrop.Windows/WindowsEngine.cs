using FluxDrop.Core;

namespace FluxDrop.Windows;

public sealed class WindowsEngine : PortableEngine
{
    static string[] Images =>
        MediaEngine.Available
            ? ["png", "jpg", "jpeg", "tif", "tiff", "bmp", "webp"]
            : ["png", "jpg", "jpeg", "tif", "tiff", "bmp"];
    static readonly string[] Media =
    [
        "mp4",
        "mov",
        "mkv",
        "avi",
        "webm",
        "mp3",
        "m4a",
        "aac",
        "wav",
        "flac",
        "ogg",
        "opus",
        "wma",
    ];
    public override IReadOnlyList<Capability> Capabilities { get; }

    public WindowsEngine()
    {
        Capabilities = base
            .Capabilities.Concat([
                new Capability("recipe", "recipe", [], "copy", false, true),
                new Capability("image", "image", Images, "image"),
                new Capability("imageIcons", "image", Images, "folder"),
                new Capability("imagesPDF", "pdf", Images, "pdf", false, true),
                new Capability("markdownPDF", "data", ["md", "markdown"], "pdf"),
            ])
            .Concat(
                new[]
                {
                    "pdfText",
                    "pdfMerge",
                    "pdfExtract",
                    "pdfSplit",
                    "pdfRotate",
                    "pdfImages",
                    "pdfOCR",
                    "pdfCompress",
                }.Select(id => new Capability(
                    id,
                    "pdf",
                    ["pdf"],
                    id == "pdfImages" || id == "pdfSplit" ? "folder"
                        : id is "pdfOCR" or "pdfText" ? "txt"
                        : "pdf",
                    false,
                    id == "pdfMerge"
                ))
            )
            .Concat(
                MediaEngine.Available
                    ? new[]
                    {
                        "mediaInspect",
                        "videoMP4",
                        "videoMOV",
                        "videoGIF",
                        "audioM4A",
                        "audioWAV",
                        "audioFLAC",
                        "audioJoin",
                        "audioMP3",
                        "audioOpus",
                    }.Select(id => new Capability(
                        id,
                        "media",
                        Media,
                        id switch
                        {
                            "mediaInspect" => "json",
                            "videoMP4" => "mp4",
                            "videoMOV" => "mov",
                            "videoGIF" => "gif",
                            "audioM4A" => "m4a",
                            "audioFLAC" => "flac",
                            "audioMP3" => "mp3",
                            "audioOpus" => "opus",
                            _ => "wav",
                        },
                        false,
                        id == "audioJoin"
                    ))
                    : []
            )
            .ToArray();
    }

    public override async Task<Result> ExecuteAsync(
        Request r,
        IProgress<double?>? progress,
        CancellationToken token
    )
    {
        if (r.Operation == "recipe")
        {
            var recipe =
                System.Text.Json.JsonSerializer.Deserialize<Recipe>(
                    r.Options.RecipeJson,
                    Config.Json
                ) ?? throw new ArgumentException("Receta vacía.");
            recipe.Validate(Capabilities.Where(c => c.Id != "recipe").ToArray());
            string stage = SafeFiles.Temp(r.Destination);
            try
            {
                string[] current = r.Inputs;
                for (int i = 0; i < recipe.Steps.Count; i++)
                {
                    var step = recipe.Steps[i];
                    var cap = Capabilities.First(c => c.Id == step.Operation);
                    string dest = Path.Combine(stage, i.ToString());
                    Directory.CreateDirectory(dest);
                    var next = new List<string>();
                    if (cap.Aggregate)
                    {
                        var result = await ExecuteAsync(
                            new(step.Operation, current, dest, step.Options),
                            progress,
                            token
                        );
                        next.AddRange(result.Outputs);
                    }
                    else
                        foreach (var input in current)
                        {
                            var result = await ExecuteAsync(
                                new(step.Operation, [input], dest, step.Options),
                                progress,
                                token
                            );
                            next.AddRange(result.Outputs);
                        }
                    current = next.ToArray();
                }
                token.ThrowIfCancellationRequested();
                string final = Path.Combine(stage, "final");
                Directory.CreateDirectory(final);
                foreach (var output in current)
                {
                    string dest = Path.Combine(final, Path.GetFileName(output));
                    if (Directory.Exists(output))
                        Directory.Move(output, dest);
                    else
                        File.Move(output, dest);
                }
                return new([SafeFiles.PublishDirectory(final, r.Destination, "receta-fluxdrop")]);
            }
            finally
            {
                if (Directory.Exists(stage))
                    Directory.Delete(stage, true);
            }
        }
        if (base.Capabilities.Any(c => c.Id == r.Operation))
            return await base.ExecuteAsync(r, progress, token);
        return await Task.Run<Result>(
            async () =>
            {
                r.Options.Validate();
                foreach (var input in r.Inputs)
                    SafeFiles.Input(input);
                SafeFiles.Space(
                    r.Destination,
                    r.Inputs.Where(File.Exists).Sum(p => new FileInfo(p).Length)
                );
                string work = SafeFiles.Temp(r.Destination);
                try
                {
                    token.ThrowIfCancellationRequested();
                    string temp;
                    bool folder = false;
                    string ext;
                    string detail = "";
                    if (r.Operation is "image" or "imageIcons")
                    {
                        var image = await ImageEngine.ReadInputAsync(
                            r.Inputs.Single(),
                            work,
                            token
                        );
                        if (r.Operation == "imageIcons")
                        {
                            if (image.PixelWidth != image.PixelHeight || image.PixelWidth < 1024)
                                throw new IOException(
                                    "El icono requiere una imagen cuadrada de al menos 1024 px."
                                );
                            temp = Path.Combine(work, "icons");
                            Directory.CreateDirectory(temp);
                            foreach (int size in new[] { 16, 24, 32, 48, 64, 128, 256, 512, 1024 })
                            {
                                token.ThrowIfCancellationRequested();
                                ImageEngine.Write(
                                    ImageEngine.Transform(image, r.Options with { MaxSide = size }),
                                    Path.Combine(temp, $"icon-{size}.png"),
                                    "png",
                                    100
                                );
                            }
                            folder = true;
                            ext = "";
                        }
                        else
                        {
                            ext = r.Options.Format.ToLowerInvariant();
                            if (
                                !new[]
                                {
                                    "png",
                                    "jpg",
                                    "jpeg",
                                    "tif",
                                    "tiff",
                                    "bmp",
                                    "webp",
                                }.Contains(ext)
                            )
                                throw new IOException("Codificador no incluido para ese formato.");
                            if (!r.Options.StripMetadata)
                                throw new IOException(
                                    "Esta versión exporta imágenes sin metadatos. Activa quitar metadatos."
                                );
                            var transformed = ImageEngine.Transform(image, r.Options);
                            temp = Path.Combine(work, "image." + (ext == "webp" ? "bmp" : ext));
                            ImageEngine.Write(
                                transformed,
                                temp,
                                ext == "webp" ? "bmp" : ext,
                                r.Options.Quality
                            );
                            if (ext == "webp")
                            {
                                if (!MediaEngine.Available)
                                    throw new IOException("WebP requiere el motor incluido.");
                                string webp = Path.Combine(work, "image.webp");
                                await ProcessRunner.Run(
                                    MediaEngine.Ffmpeg,
                                    [
                                        "-v",
                                        "error",
                                        "-nostdin",
                                        "-i",
                                        temp,
                                        "-c:v",
                                        "libwebp",
                                        "-quality",
                                        r.Options.Quality.ToString(),
                                        "-frames:v",
                                        "1",
                                        webp,
                                    ],
                                    token
                                );
                                await ProcessRunner.Run(
                                    MediaEngine.Ffmpeg,
                                    ["-v", "error", "-xerror", "-i", webp, "-f", "null", "-"],
                                    token
                                );
                                temp = webp;
                            }
                        }
                    }
                    else if (
                        r.Operation.StartsWith("pdf", StringComparison.Ordinal)
                        || r.Operation is "imagesPDF" or "markdownPDF"
                    )
                    {
                        (temp, folder) = await PdfEngine.Run(r, work, progress, token);
                        ext = Path.GetExtension(temp).TrimStart('.');
                        if (r.Operation == "pdfCompress")
                            detail =
                                "PDF rasterizado: se pierden texto seleccionable, enlaces y vectores. No garantiza menor tamaño.";
                    }
                    else
                    {
                        temp = await MediaEngine.Run(r, work, progress, token);
                        ext = Path.GetExtension(temp).TrimStart('.');
                        if (
                            r.Operation.StartsWith("video", StringComparison.Ordinal)
                            && r.Operation != "videoGIF"
                        )
                            detail =
                                "Vídeo MPEG-4 Part 2 con audio AAC opcional. No es H.264. Objetivo de tamaño aproximado.";
                    }
                    token.ThrowIfCancellationRequested();
                    string name = Path.GetFileNameWithoutExtension(r.Inputs[0]) + "-fluxdrop";
                    return new(
                        [
                            folder
                                ? SafeFiles.PublishDirectory(temp, r.Destination, name)
                                : SafeFiles.Publish(temp, r.Destination, name + "." + ext),
                        ],
                        detail
                    );
                }
                finally
                {
                    if (Directory.Exists(work))
                        Directory.Delete(work, true);
                }
            },
            token
        );
    }
}
