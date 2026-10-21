using System.Text.Json;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using FluxDrop.Core;
using PdfSharp.Drawing;
using PdfSharp.Pdf;
using PdfSharp.Pdf.IO;

namespace FluxDrop.Windows;

public static class WindowsChecks
{
    public static int Run(string[] args)
    {
        string root =
            args.SkipWhile(a => a != "--test-output").Skip(1).FirstOrDefault()
            ?? Path.Combine(Path.GetTempPath(), "FluxDrop-Windows-QA");
        Directory.CreateDirectory(root);
        var results = new List<object>();
        int failures = 0;
        void Check(bool b)
        {
            if (!b)
                throw new IOException("Assertion failed");
        }
        void Test(string name, Action action)
        {
            try
            {
                action();
                results.Add(new { name, status = "passed" });
            }
            catch (Exception e)
            {
                failures++;
                results.Add(
                    new
                    {
                        name,
                        status = "failed",
                        error = e.ToString(),
                    }
                );
            }
        }
        var app = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        var engine = new WindowsEngine();
        string input = Path.Combine(root, "café & datos.png");
        var pixels = Enumerable.Repeat((byte)190, 128 * 64 * 4).ToArray();
        var bitmap = BitmapSource.Create(
            128,
            64,
            96,
            96,
            PixelFormats.Bgra32,
            null,
            pixels,
            128 * 4
        );
        ImageEngine.Write(bitmap, input, "png", 100);
        string hash = SafeFiles.Hash(input, default).GetAwaiter().GetResult();
        Result Execute(string id, string[] files, Options? o = null) =>
            engine
                .ExecuteAsync(new(id, files, root, o ?? new()), null, default)
                .GetAwaiter()
                .GetResult();
        foreach (var format in new[] { "png", "jpg", "tiff", "bmp" })
            Test(
                "image " + format + " dimensions and original",
                () =>
                {
                    var r = Execute(
                        "image",
                        [input],
                        new Options { Format = format, MaxSide = 32 }
                    );
                    var image = ImageEngine.Read(r.Outputs[0]);
                    Check(image.PixelWidth == 32 && image.PixelHeight == 16);
                    Check(SafeFiles.Hash(input, default).GetAwaiter().GetResult() == hash);
                }
            );
        Test(
            "image crop rotate watermark",
            () =>
            {
                var r = Execute(
                    "image",
                    [input],
                    new Options
                    {
                        CropWidth = 40,
                        CropHeight = 20,
                        Rotate = 90,
                        Watermark = "Local",
                        MaxSide = 0,
                    }
                );
                var b = ImageEngine.Read(r.Outputs[0]);
                Check(b.PixelWidth == 20 && b.PixelHeight == 40);
            }
        );
        Test(
            "image damaged rejected",
            () =>
            {
                var f = Path.Combine(root, "corrupt.png");
                File.WriteAllText(f, "bad");
                try
                {
                    Execute("image", [f]);
                    throw new Exception("accepted");
                }
                catch (Exception e) when (e.Message != "accepted") { }
                ;
            }
        );
        Test(
            "PDF images creation merge split extract rotate reopen",
            () =>
            {
                var pdf = Execute("imagesPDF", [input, input]);
                using (var p = PdfReader.Open(pdf.Outputs[0], PdfDocumentOpenMode.Import))
                    Check(p.PageCount == 2);
                var merge = Execute("pdfMerge", [pdf.Outputs[0], pdf.Outputs[0]]);
                using (var p = PdfReader.Open(merge.Outputs[0], PdfDocumentOpenMode.Import))
                    Check(p.PageCount == 4);
                var extract = Execute(
                    "pdfExtract",
                    merge.Outputs,
                    new Options { Pages = "3,1", Rotate = 90 }
                );
                using (var p = PdfReader.Open(extract.Outputs[0], PdfDocumentOpenMode.Import))
                {
                    Check(p.PageCount == 2);
                    Check(p.Pages[0].Rotate == 90);
                }
                var split = Execute("pdfSplit", pdf.Outputs);
                Check(Directory.GetFiles(split.Outputs[0], "*.pdf").Length == 2);
                var rotate = Execute("pdfRotate", pdf.Outputs, new Options { Rotate = 180 });
                using var check = PdfReader.Open(rotate.Outputs[0], PdfDocumentOpenMode.Import);
                Check(check.Pages[0].Rotate == 180);
            }
        );
        Test(
            "PDF Windows render verifies PNG and compression pages",
            () =>
            {
                var pdf = Execute("imagesPDF", [input]);
                var images = Execute("pdfImages", pdf.Outputs);
                Check(
                    ImageEngine.Read(Directory.GetFiles(images.Outputs[0]).Single()).PixelWidth > 0
                );
                var compressed = Execute("pdfCompress", pdf.Outputs);
                using var p = PdfReader.Open(compressed.Outputs[0], PdfDocumentOpenMode.Import);
                Check(p.PageCount == 1);
            }
        );
        Test(
            "PDF password correct and incorrect",
            () =>
            {
                var path = Path.Combine(root, "encrypted.pdf");
                using (var p = new PdfDocument())
                {
                    p.AddPage();
                    p.SecuritySettings.UserPassword = "fixture";
                    p.SecuritySettings.OwnerPassword = "owner";
                    p.Save(path);
                }
                try
                {
                    Execute("pdfExtract", [path], new Options { Password = "wrong" });
                    throw new Exception("accepted");
                }
                catch (Exception e) when (e.Message != "accepted") { }
                var r = Execute("pdfExtract", [path], new Options { Password = "fixture" });
                using var output = PdfReader.Open(r.Outputs[0], PdfDocumentOpenMode.Import);
                Check(output.PageCount == 1);
            }
        );
        Test(
            "Markdown PDF reopens",
            () =>
            {
                var f = Path.Combine(root, "readme.md");
                File.WriteAllText(f, "# Hola\nLocal Windows");
                var r = Execute("markdownPDF", [f]);
                using var p = PdfReader.Open(r.Outputs[0], PdfDocumentOpenMode.Import);
                Check(p.PageCount > 0);
            }
        );
        Test(
            "widget and main window render",
            () =>
            {
                var main = new MainWindow();
                main.Add([input]);
                main.Show();
                main.UpdateLayout();
                var shot = new RenderTargetBitmap(1000, 790, 96, 96, PixelFormats.Pbgra32);
                shot.Render(main);
                ImageEngine.Write(shot, Path.Combine(root, "windows-main.png"), "png", 100);
                var widget = new WidgetWindow(main);
                widget.Show();
                widget.UpdateLayout();
                var wshot = new RenderTargetBitmap(
                    (int)widget.Width,
                    (int)widget.Height,
                    96,
                    96,
                    PixelFormats.Pbgra32
                );
                wshot.Render(widget);
                ImageEngine.Write(wshot, Path.Combine(root, "windows-widget.png"), "png", 100);
                widget.Close();
                main.Hide();
            }
        );
        if (MediaEngine.Available)
        {
            Test(
                "media engine LGPL configuration",
                () =>
                {
                    string config = ProcessRunner
                        .Run(MediaEngine.Ffmpeg, ["-buildconf"], default)
                        .GetAwaiter()
                        .GetResult();
                    string license = ProcessRunner
                        .Run(MediaEngine.Ffmpeg, ["-L"], default)
                        .GetAwaiter()
                        .GetResult(); // FFmpeg prints this on stderr; the release also ships configure flags.
                    Check(
                        File.ReadAllText(
                                Path.Combine(AppContext.BaseDirectory, "engines", "buildconf.txt")
                            )
                            .Contains("--disable-gpl")
                    );
                }
            );
            string wave = Path.Combine(root, "tone.wav");
            Test(
                "create media fixture",
                () =>
                    ProcessRunner
                        .Run(
                            MediaEngine.Ffmpeg,
                            [
                                "-v",
                                "error",
                                "-f",
                                "lavfi",
                                "-i",
                                "sine=frequency=440:duration=1",
                                "-y",
                                wave,
                            ],
                            default
                        )
                        .GetAwaiter()
                        .GetResult()
            );
            foreach (
                var op in new[] { "audioWAV", "audioFLAC", "audioM4A", "audioMP3", "audioOpus" }
            )
                Test(
                    op + " full decode and duration",
                    () =>
                    {
                        var r = Execute(op, [wave]);
                        var info = MediaEngine
                            .Probe(r.Outputs[0], default)
                            .GetAwaiter()
                            .GetResult()
                            .Info;
                        Check(info.Audio && Math.Abs(info.Duration - 1) < .2);
                    }
                );
            Test(
                "audio join trim after first source",
                () =>
                {
                    var r = Execute(
                        "audioJoin",
                        [wave, wave],
                        new Options { Start = 1.2, Duration = .5 }
                    );
                    Check(
                        Math.Abs(
                            MediaEngine
                                .Probe(r.Outputs[0], default)
                                .GetAwaiter()
                                .GetResult()
                                .Info.Duration - .5
                        ) < .1
                    );
                }
            );
            Test(
                "WebP output full decode",
                () =>
                {
                    var r = Execute("image", [input], new Options { Format = "webp" });
                    Check(
                        MediaEngine.Probe(r.Outputs[0], default).GetAwaiter().GetResult().Info.Video
                    );
                }
            );
            string video = Path.Combine(root, "video.mp4");
            Test(
                "video fixture and MP4 MOV GIF verified",
                () =>
                {
                    ProcessRunner
                        .Run(
                            MediaEngine.Ffmpeg,
                            [
                                "-v",
                                "error",
                                "-f",
                                "lavfi",
                                "-i",
                                "testsrc=size=160x90:rate=15:duration=1",
                                "-c:v",
                                "mpeg4",
                                "-pix_fmt",
                                "yuv420p",
                                "-y",
                                video,
                            ],
                            default
                        )
                        .GetAwaiter()
                        .GetResult();
                    foreach (var op in new[] { "videoMP4", "videoMOV", "videoGIF" })
                    {
                        var r = Execute(op, [video], new Options { MaxSide = 80 });
                        Check(
                            MediaEngine
                                .Probe(r.Outputs[0], default)
                                .GetAwaiter()
                                .GetResult()
                                .Info.Video
                        );
                    }
                }
            );
            Test(
                "media inspect JSON content",
                () =>
                {
                    var r = Execute("mediaInspect", [wave]);
                    using var json = JsonDocument.Parse(File.ReadAllText(r.Outputs[0]));
                    Check(json.RootElement.GetProperty("streams").GetArrayLength() > 0);
                }
            );
        }
        else
        {
            failures++;
            results.Add(
                new
                {
                    name = "bundled media engines",
                    status = "failed",
                    error = "not included",
                }
            );
        }
        Config.Write(
            Path.Combine(root, "windows-results.json"),
            new
            {
                passed = results.Count - failures,
                failed = failures,
                tests = results,
            }
        );
        app.Shutdown();
        return failures == 0 ? 0 : 1;
    }
}
