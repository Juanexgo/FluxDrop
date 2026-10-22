using System.Globalization;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using FluxDrop.Core;

namespace FluxDrop.Windows;

public static class ImageEngine
{
    public static async Task<BitmapSource> ReadInputAsync(
        string path,
        string work,
        CancellationToken token
    )
    {
        byte[] header = new byte[32];
        int length;
        using (var file = File.OpenRead(path))
            length = await file.ReadAsync(header, token);
        if (
            length >= 12
            && System.Text.Encoding.ASCII.GetString(header, 0, 4) == "RIFF"
            && System.Text.Encoding.ASCII.GetString(header, 8, 4) == "WEBP"
        )
        {
            if (
                length >= 21
                && System.Text.Encoding.ASCII.GetString(header, 12, 4) == "VP8X"
                && (header[20] & 2) != 0
            )
                throw new IOException("WebP animado no admitido en imágenes; usa multimedia.");
            if (!MediaEngine.Available)
                throw new IOException("WebP requiere el motor incluido.");
            var info = (await MediaEngine.Probe(path, token)).Info;
            if (info.Width <= 0 || info.Height <= 0 || (long)info.Width * info.Height > 100_000_000)
                throw new IOException("Dimensiones WebP no válidas.");
            string decoded = Path.Combine(work, "decoded-" + Guid.NewGuid().ToString("N") + ".bmp");
            await ProcessRunner.Run(
                MediaEngine.Ffmpeg,
                ["-v", "error", "-nostdin", "-i", path, "-frames:v", "1", "-c:v", "bmp", decoded],
                token
            );
            var result = Read(decoded);
            if (result.PixelWidth != info.Width || result.PixelHeight != info.Height)
                throw new IOException("Dimensiones WebP inesperadas.");
            return result;
        }
        return Read(path);
    }

    public static BitmapSource Read(string file)
    {
        using var s = File.OpenRead(file);
        var decoder = BitmapDecoder.Create(
            s,
            BitmapCreateOptions.PreservePixelFormat,
            BitmapCacheOption.OnLoad
        );
        if (decoder.Frames.Count != 1)
            throw new IOException(
                "Solo imágenes de un fotograma; usa el motor multimedia para animaciones."
            );
        var frame = decoder.Frames[0];
        if (
            (long)frame.PixelWidth * frame.PixelHeight > 100_000_000
            || frame.PixelWidth > 32768
            || frame.PixelHeight > 32768
        )
            throw new IOException("Imagen demasiado grande (máximo 100 MP).");
        BitmapSource result = frame;
        if (frame.Metadata is BitmapMetadata metadata)
        {
            ushort orientation = 1;
            try
            {
                orientation = System.Convert.ToUInt16(
                    metadata.GetQuery("/app1/ifd/{ushort=274}") ?? 1,
                    CultureInfo.InvariantCulture
                );
            }
            catch (NotSupportedException) { }
            var transform = new TransformGroup();
            if (orientation is 2 or 4 or 5 or 7)
                transform.Children.Add(new ScaleTransform(-1, 1));
            if (orientation is 3 or 4)
                transform.Children.Add(new RotateTransform(180));
            if (orientation is 5 or 6)
                transform.Children.Add(new RotateTransform(90));
            if (orientation is 7 or 8)
                transform.Children.Add(new RotateTransform(270));
            if (transform.Children.Count > 0)
                result = new TransformedBitmap(result, transform);
        }
        if (frame.ColorContexts?.Count > 0)
        {
            var converted = new ColorConvertedBitmap(
                result,
                frame.ColorContexts[0],
                new ColorContext(PixelFormats.Bgra32),
                PixelFormats.Bgra32
            );
            converted.Freeze();
            result = converted;
        }
        result.Freeze();
        return result;
    }

    public static BitmapSource Transform(BitmapSource source, Options o)
    {
        BitmapSource image = source;
        if (o.CropWidth > 0 || o.CropHeight > 0)
        {
            if (
                o.CropWidth < 1
                || o.CropHeight < 1
                || o.CropX + o.CropWidth > image.PixelWidth
                || o.CropY + o.CropHeight > image.PixelHeight
            )
                throw new ArgumentException("El recorte está fuera de la imagen.");
            image = new CroppedBitmap(
                image,
                new Int32Rect(o.CropX, o.CropY, o.CropWidth, o.CropHeight)
            );
        }
        var transforms = new TransformGroup();
        if (o.Rotate % 360 != 0)
            transforms.Children.Add(new RotateTransform(o.Rotate));
        if (o.Flip)
            transforms.Children.Add(new ScaleTransform(-1, 1));
        if (transforms.Children.Count > 0)
            image = new TransformedBitmap(image, transforms);
        if (o.MaxSide > 0 && Math.Max(image.PixelWidth, image.PixelHeight) > o.MaxSide)
        {
            double ratio = o.MaxSide / (double)Math.Max(image.PixelWidth, image.PixelHeight);
            image = new TransformedBitmap(image, new ScaleTransform(ratio, ratio));
        }
        int w = image.PixelWidth,
            h = image.PixelHeight;
        var visual = new DrawingVisual();
        using (var dc = visual.RenderOpen())
        {
            if (o.Format is "jpg" or "jpeg")
                dc.DrawRectangle(Brushes.White, null, new Rect(0, 0, w, h));
            dc.DrawImage(image, new Rect(0, 0, w, h));
            if (o.WatermarkImage.Length > 0)
            {
                var mark = Read(o.WatermarkImage);
                double mw = Math.Min(w / 3d, mark.PixelWidth),
                    mh = mw * mark.PixelHeight / mark.PixelWidth;
                dc.PushOpacity(.7);
                dc.DrawImage(mark, new Rect(w - mw - 12, h - mh - 12, mw, mh));
                dc.Pop();
            }
            if (o.Watermark.Length > 0)
            {
                var text = new FormattedText(
                    o.Watermark,
                    CultureInfo.CurrentUICulture,
                    System.Windows.FlowDirection.LeftToRight,
                    new Typeface("Segoe UI"),
                    Math.Max(12, w / 32d),
                    Brushes.White,
                    1
                );
                dc.DrawRectangle(
                    new SolidColorBrush(Color.FromArgb(130, 0, 0, 0)),
                    null,
                    new Rect(
                        4,
                        h - text.Height - 12,
                        Math.Min(w - 8, text.Width + 16),
                        text.Height + 8
                    )
                );
                dc.DrawText(text, new Point(12, h - text.Height - 8));
            }
        }
        var output = new RenderTargetBitmap(w, h, 96, 96, PixelFormats.Pbgra32);
        output.Render(visual);
        output.Freeze();
        return output;
    }

    public static void Write(BitmapSource image, string path, string format, int quality)
    {
        BitmapEncoder encoder = format switch
        {
            "jpg" or "jpeg" => new JpegBitmapEncoder { QualityLevel = quality },
            "png" => new PngBitmapEncoder(),
            "tiff" or "tif" => new TiffBitmapEncoder { Compression = TiffCompressOption.Zip },
            "bmp" => new BmpBitmapEncoder(),
            _ => throw new NotSupportedException("Formato de imagen no disponible."),
        };
        encoder.Frames.Add(BitmapFrame.Create(image));
        using (var s = File.Create(path))
            encoder.Save(s);
        var check = Read(path);
        if (check.PixelWidth != image.PixelWidth || check.PixelHeight != image.PixelHeight)
            throw new IOException("Dimensiones de salida incorrectas.");
    }
}
