using System.Text;
using FluxDrop.Core;
using PdfSharp.Drawing;
using PdfSharp.Pdf;
using PdfSharp.Pdf.IO;
using Windows.Graphics.Imaging;
using Windows.Storage;
using Windows.Storage.Streams;

namespace FluxDrop.Windows;

public static class PdfEngine
{
    static PdfDocument Open(string path, string password, PdfDocumentOpenMode mode)
    {
        var pdf = PdfReader.Open(path, password, mode);
        if (pdf.PageCount is < 1 or > 10000)
        {
            pdf.Dispose();
            throw new IOException("PDF vacío o con más de 10 000 páginas.");
        }
        if (!pdf.SecuritySettings.PermitExtractContent)
        {
            pdf.Dispose();
            throw new IOException("El PDF no permite extraer su contenido.");
        }
        return pdf;
    }

    public static int[] Pages(string spec, int count)
    {
        if (string.IsNullOrWhiteSpace(spec))
            return Enumerable.Range(0, count).ToArray();
        var result = new List<int>();
        foreach (var group in spec.Split(','))
        {
            var parts = group.Trim().Split('-');
            if (parts.Length > 2 || !int.TryParse(parts[0], out int a))
                throw new FormatException("Rango PDF inválido. Ejemplo: 1,3-5.");
            int b = a;
            if (parts.Length == 2 && !int.TryParse(parts[1], out b))
                throw new FormatException("Rango PDF inválido.");
            if (a < 1 || b < a || b > count)
                throw new FormatException("Rango fuera del documento.");
            result.AddRange(Enumerable.Range(a - 1, b - a + 1));
            if (result.Count > 10000)
                throw new FormatException("Demasiadas páginas.");
        }
        return result.ToArray();
    }

    public static async Task<(string Path, bool Folder)> Run(
        Request r,
        string work,
        IProgress<double?>? progress,
        CancellationToken token
    )
    {
        string target = Path.Combine(work, "result.pdf");
        var o = r.Options;
        if (r.Operation == "imagesPDF")
        {
            using var output = new PdfDocument();
            for (int i = 0; i < r.Inputs.Length; i++)
            {
                token.ThrowIfCancellationRequested();
                var image = await ImageEngine.ReadInputAsync(r.Inputs[i], work, token);
                string png = Path.Combine(work, i + ".png");
                ImageEngine.Write(image, png, "png", 100);
                using var x = XImage.FromFile(png);
                var page = output.AddPage();
                page.Width = XUnit.FromPoint(image.PixelWidth * 72d / 96);
                page.Height = XUnit.FromPoint(image.PixelHeight * 72d / 96);
                using (var g = XGraphics.FromPdfPage(page))
                    g.DrawImage(x, 0, 0, page.Width.Point, page.Height.Point);
                progress?.Report((i + 1d) / r.Inputs.Length);
            }
            int expectedPages = output.PageCount;
            output.Save(target);
            Verify(target, expectedPages);
            return (target, false);
        }
        if (r.Operation == "markdownPDF")
        {
            string text = await SafeFiles.Text(r.Inputs.Single(), token);
            using var pdf = new PdfDocument();
            var font = new XFont("Segoe UI", 11);
            var page = pdf.AddPage();
            var g = XGraphics.FromPdfPage(page);
            double y = 48;
            foreach (var line in text.Replace("\r", "").Split('\n'))
            {
                for (int start = 0; start < Math.Max(1, line.Length); start += 85)
                {
                    token.ThrowIfCancellationRequested();
                    if (y > page.Height.Point - 48)
                    {
                        g.Dispose();
                        page = pdf.AddPage();
                        g = XGraphics.FromPdfPage(page);
                        y = 48;
                    }
                    g.DrawString(
                        line.Substring(start, Math.Min(85, line.Length - start)),
                        font,
                        XBrushes.Black,
                        new XPoint(42, y)
                    );
                    y += 16;
                }
            }
            g.Dispose();
            int expectedPages = pdf.PageCount;
            pdf.Save(target);
            Verify(target, expectedPages);
            return (target, false);
        }
        if (r.Operation == "pdfMerge")
        {
            if (r.Inputs.Length < 2)
                throw new ArgumentException("Selecciona al menos dos PDF.");
            using var output = new PdfDocument();
            foreach (var input in r.Inputs)
            {
                using var pdf = Open(input, o.Password, PdfDocumentOpenMode.Import);
                for (int i = 0; i < pdf.PageCount; i++)
                {
                    token.ThrowIfCancellationRequested();
                    output.AddPage(pdf.Pages[i]);
                }
            }
            int expectedPages = output.PageCount;
            output.Save(target);
            Verify(target, expectedPages);
            return (target, false);
        }
        using var source = Open(r.Inputs.Single(), o.Password, PdfDocumentOpenMode.Import);
        int[] pages = Pages(o.Pages, source.PageCount);
        if (r.Operation is "pdfExtract" or "pdfRotate" or "pdfSplit")
        {
            bool split = r.Operation == "pdfSplit";
            if (split)
            {
                target = Path.Combine(work, "pages");
                Directory.CreateDirectory(target);
            }
            using var output = new PdfDocument();
            for (int i = 0; i < pages.Length; i++)
            {
                token.ThrowIfCancellationRequested();
                if (split)
                {
                    using var single = new PdfDocument();
                    var p = single.AddPage(source.Pages[pages[i]]);
                    p.Rotate = (p.Rotate + o.Rotate) % 360;
                    string f = Path.Combine(target, $"page-{i + 1:D4}.pdf");
                    single.Save(f);
                    Verify(f, 1);
                }
                else
                {
                    var p = output.AddPage(source.Pages[pages[i]]);
                    p.Rotate = (p.Rotate + o.Rotate) % 360;
                }
                progress?.Report((i + 1d) / pages.Length);
            }
            if (!split)
            {
                output.Save(target);
                Verify(target, pages.Length);
            }
            return (target, split);
        }
        if (r.Operation == "pdfText")
        {
            using var stream = File.OpenRead(r.Inputs[0]);
            using var document = UglyToad.PdfPig.PdfDocument.Open(
                stream,
                new UglyToad.PdfPig.ParsingOptions
                {
                    Password = o.Password,
                    UseLenientParsing = false,
                }
            );
            var text = new StringBuilder();
            for (int i = 0; i < pages.Length; i++)
            {
                token.ThrowIfCancellationRequested();
                text.AppendLine(document.GetPage(pages[i] + 1).Text);
                if (text.Length > 16 * 1024 * 1024)
                    throw new IOException("Texto PDF demasiado grande.");
                progress?.Report((i + 1d) / pages.Length);
            }
            if (string.IsNullOrWhiteSpace(text.ToString()))
                throw new IOException("El PDF no contiene texto extraíble. Usa OCR local.");
            target = Path.Combine(work, "text.txt");
            await File.WriteAllTextAsync(target, text.ToString(), new UTF8Encoding(false), token);
            return (target, false);
        }
        var native = await global::Windows.Data.Pdf.PdfDocument.LoadFromFileAsync(
            await StorageFile.GetFileFromPathAsync(Path.GetFullPath(r.Inputs[0])),
            o.Password
        );
        string dir = Path.Combine(work, "rendered");
        Directory.CreateDirectory(dir);
        var textOutput = new StringBuilder();
        using var compressed = new PdfDocument();
        string ocrExe = Path.Combine(AppContext.BaseDirectory, "engines", "tesseract.exe");
        if (r.Operation == "pdfOCR" && !File.Exists(ocrExe))
            throw new IOException("El motor OCR local no está incluido en esta instalación.");
        for (int i = 0; i < pages.Length; i++)
        {
            token.ThrowIfCancellationRequested();
            using var page = native.GetPage((uint)pages[i]);
            uint width = (uint)Math.Ceiling(page.Size.Width * o.Dpi / 96d),
                height = (uint)Math.Ceiling(page.Size.Height * o.Dpi / 96d);
            if ((long)width * height > 80_000_000 || width > 16000 || height > 16000)
                throw new IOException("La página supera el límite de render (80 MP).");
            using var stream = new InMemoryRandomAccessStream();
            await page.RenderToStreamAsync(
                stream,
                new global::Windows.Data.Pdf.PdfPageRenderOptions
                {
                    DestinationWidth = width,
                    DestinationHeight = height,
                }
            );
            token.ThrowIfCancellationRequested();
            stream.Seek(0);
            if (r.Operation == "pdfOCR")
            {
                string png = Path.Combine(dir, $"page-{i + 1:D4}.png");
                await using (var destination = File.Create(png))
                    await stream.AsStreamForRead().CopyToAsync(destination, token);
                string bmp = Path.ChangeExtension(png, "bmp");
                ImageEngine.Write(ImageEngine.Read(png), bmp, "bmp", 100);
                string language =
                    o.OcrLanguage.StartsWith("es", StringComparison.OrdinalIgnoreCase) ? "spa"
                    : o.OcrLanguage.StartsWith("en", StringComparison.OrdinalIgnoreCase) ? "eng"
                    : throw new ArgumentException("OCR incluido: español o inglés.");
                if (
                    !File.Exists(
                        Path.Combine(
                            AppContext.BaseDirectory,
                            "engines",
                            "tessdata",
                            language + ".traineddata"
                        )
                    )
                )
                    throw new IOException(
                        "Modelo OCR no instalado. Vuelve a ejecutar el instalador y selecciona OCR español e inglés."
                    );
                string text = await ProcessRunner.Run(
                    ocrExe,
                    [
                        bmp,
                        "stdout",
                        "--tessdata-dir",
                        Path.Combine(AppContext.BaseDirectory, "engines", "tessdata"),
                        "-l",
                        language,
                        "--psm",
                        "3",
                    ],
                    token
                );
                textOutput.AppendLine(text);
            }
            else
            {
                string png = Path.Combine(dir, $"page-{i + 1:D4}.png");
                await using (var dest = File.Create(png))
                    await stream.AsStreamForRead().CopyToAsync(dest, token);
                var image = ImageEngine.Read(png);
                if (r.Operation == "pdfCompress")
                {
                    string jpg = Path.ChangeExtension(png, "jpg");
                    ImageEngine.Write(image, jpg, "jpg", o.Quality);
                    using var x = XImage.FromFile(jpg);
                    var p = compressed.AddPage();
                    p.Width = XUnit.FromPoint(page.Size.Width * 72 / 96);
                    p.Height = XUnit.FromPoint(page.Size.Height * 72 / 96);
                    using var g = XGraphics.FromPdfPage(p);
                    g.DrawImage(x, 0, 0, p.Width.Point, p.Height.Point);
                }
            }
            progress?.Report((i + 1d) / pages.Length);
        }
        if (r.Operation == "pdfOCR")
        {
            target = Path.Combine(work, "ocr.txt");
            await File.WriteAllTextAsync(
                target,
                textOutput.ToString(),
                new UTF8Encoding(false),
                token
            );
            return (target, false);
        }
        if (r.Operation == "pdfCompress")
        {
            compressed.Save(target);
            Verify(target, pages.Length);
            return (target, false);
        }
        if (r.Operation != "pdfImages")
            throw new NotSupportedException(
                "Extraer texto existente requiere un motor de texto PDF adicional; usa OCR para texto reconocido."
            );
        return (dir, true);
    }

    static void Verify(string file, int pages)
    {
        using var result = PdfReader.Open(file, PdfDocumentOpenMode.Import);
        if (result.PageCount != pages)
            throw new IOException("El PDF de salida no contiene las páginas esperadas.");
    }
}
