using System.Globalization;
using System.Text.Json;
using FluxDrop.Core;

namespace FluxDrop.Windows;

public sealed record MediaInfo(
    double Duration,
    bool Video,
    bool Audio,
    bool Hdr,
    int Width,
    int Height
);

public static class MediaEngine
{
    public static string Ffmpeg => Path.Combine(AppContext.BaseDirectory, "engines", "ffmpeg.exe");
    public static string Ffprobe =>
        Path.Combine(AppContext.BaseDirectory, "engines", "ffprobe.exe");
    public static bool Available => File.Exists(Ffmpeg) && File.Exists(Ffprobe);

    public static async Task<(MediaInfo Info, string Json)> Probe(
        string path,
        CancellationToken token
    )
    {
        var json = await ProcessRunner
            .Run(
                Ffprobe,
                ["-v", "error", "-show_streams", "-show_format", "-of", "json", path],
                token
            )
            .ConfigureAwait(false);
        using var d = JsonDocument.Parse(json);
        var streams = d.RootElement.GetProperty("streams").EnumerateArray().ToArray();
        bool video = streams.Any(s => s.GetProperty("codec_type").GetString() == "video"),
            audio = streams.Any(s => s.GetProperty("codec_type").GetString() == "audio");
        double duration = 0;
        if (
            d.RootElement.TryGetProperty("format", out var f)
            && f.TryGetProperty("duration", out var dur)
        )
            double.TryParse(
                dur.GetString(),
                NumberStyles.Float,
                CultureInfo.InvariantCulture,
                out duration
            );
        bool hdr = streams.Any(s =>
            s.TryGetProperty("color_transfer", out var t)
            && t.GetString() is "smpte2084" or "arib-std-b67"
        );
        var vs = streams.FirstOrDefault(s => s.GetProperty("codec_type").GetString() == "video");
        int width = vs.ValueKind == JsonValueKind.Undefined
                ? 0
                : vs.GetProperty("width").GetInt32(),
            height = vs.ValueKind == JsonValueKind.Undefined
                ? 0
                : vs.GetProperty("height").GetInt32();
        return (new(duration, video, audio, hdr, width, height), json);
    }

    public static async Task<string> Run(
        Request r,
        string work,
        IProgress<double?>? progress,
        CancellationToken token
    )
    {
        if (!Available)
            throw new IOException("Los motores multimedia no están incluidos en esta instalación.");
        var (first, json) = await Probe(r.Inputs[0], token);
        if (r.Operation == "mediaInspect")
        {
            string p = Path.Combine(work, "info.json");
            await File.WriteAllTextAsync(p, json, token);
            return p;
        }
        bool video = r.Operation.StartsWith("video", StringComparison.Ordinal);
        if (video && (!first.Video || first.Hdr))
            throw new IOException(
                first.Hdr
                    ? "Vídeo HDR: esta versión no hace tone mapping. Conserva el original."
                    : "No contiene una pista de vídeo."
            );
        if (!video && !first.Audio)
            throw new IOException("No contiene una pista de audio.");
        if (
            !double.IsFinite(first.Duration)
            || first.Duration <= 0
            || (r.Operation != "audioJoin" && r.Options.Start >= first.Duration)
        )
            throw new IOException("Duración desconocida o recorte fuera de la entrada.");
        var o = r.Options;
        double duration =
            o.Duration > 0
                ? Math.Min(o.Duration, first.Duration - o.Start)
                : first.Duration - o.Start;
        string ext = r.Operation switch
        {
            "videoMP4" => "mp4",
            "videoMOV" => "mov",
            "videoGIF" => "gif",
            "audioM4A" => "m4a",
            "audioMP3" => "mp3",
            "audioOpus" => "opus",
            "audioFLAC" => "flac",
            _ => "wav",
        };
        string target = Path.Combine(work, "result." + ext);
        var args = new List<string> { "-hide_banner", "-nostdin", "-v", "error", "-y" };
        if (r.Operation == "audioJoin")
        {
            if (r.Inputs.Length is < 2 or > 32)
                throw new ArgumentException("Unir audio requiere 2–32 entradas.");
            double total = 0;
            foreach (var input in r.Inputs)
            {
                var (info, _) = await Probe(input, token);
                if (!info.Audio || info.Duration <= 0)
                    throw new IOException("Una entrada de la unión no tiene audio válido.");
                total += info.Duration;
                args.AddRange(["-i", input]);
            }
            if (o.Start >= total)
                throw new IOException("El recorte está fuera de la secuencia.");
            duration = o.Duration > 0 ? Math.Min(o.Duration, total - o.Start) : total - o.Start;
            string filter =
                string.Join(
                    ';',
                    Enumerable
                        .Range(0, r.Inputs.Length)
                        .Select(i =>
                            $"[{i}:a:0]aresample=48000,aformat=sample_fmts=s16:channel_layouts=stereo[a{i}]"
                        )
                )
                + ";"
                + string.Concat(Enumerable.Range(0, r.Inputs.Length).Select(i => $"[a{i}]"))
                + $"concat=n={r.Inputs.Length}:v=0:a=1,atrim=start={F(o.Start)}"
                + (o.Duration > 0 ? $":duration={F(o.Duration)}" : "")
                + ",asetpts=PTS-STARTPTS"
                + (o.Normalize ? ",loudnorm=I=-16:TP=-1.5:LRA=11" : "")
                + "[out]";
            args.AddRange(["-filter_complex", filter, "-map", "[out]", "-c:a", "pcm_s16le"]);
        }
        else
        {
            args.AddRange(["-i", r.Inputs[0]]);
            if (o.Subtitles.Length > 0)
            {
                if (!video || ext == "gif")
                    throw new ArgumentException("Los subtítulos requieren salida MP4 o MOV.");
                SafeFiles.Input(o.Subtitles);
                args.AddRange(["-i", o.Subtitles]);
            }
            if (o.Start > 0)
                args.AddRange(["-ss", F(o.Start)]);
            if (o.Duration > 0)
                args.AddRange(["-t", F(o.Duration)]);
            if (video)
            {
                args.AddRange(["-map", "0:v:0"]);
                if (ext == "gif")
                {
                    if (duration > 60)
                        throw new IOException("GIF: recorta a un máximo de 60 segundos.");
                    args.AddRange([
                        "-vf",
                        $"fps=15,scale='min({Math.Min(o.MaxSide == 0 ? 640 : o.MaxSide, 960)},iw)':-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse",
                        "-an",
                    ]);
                }
                else
                {
                    if (o.MaxSide > 0)
                        args.AddRange(["-vf", $"scale='min({o.MaxSide},iw)':-2"]);
                    args.AddRange([
                        "-c:v",
                        "mpeg4",
                        "-b:v",
                        (
                            o.TargetMB > 0
                                ? Math.Max(128, (int)(o.TargetMB * 8 * 1000 / duration) - 192)
                                : o.VideoBitrate
                        ) + "k",
                        "-pix_fmt",
                        "yuv420p",
                    ]);
                    if (o.RemoveAudio || !first.Audio)
                        args.Add("-an");
                    else
                        args.AddRange(["-map", "0:a:0?", "-c:a", "aac", "-b:a", o.Bitrate + "k"]);
                    if (o.Subtitles.Length > 0)
                    {
                        args.AddRange(["-map", "1:0", "-c:s", "mov_text"]);
                    }
                    args.AddRange(["-movflags", "+faststart"]);
                }
            }
            else
            {
                args.AddRange(["-map", "0:a:0", "-vn"]);
                if (o.Normalize)
                    args.AddRange(["-af", "loudnorm=I=-16:TP=-1.5:LRA=11"]);
                args.AddRange([
                    "-c:a",
                    ext switch
                    {
                        "mp3" => "libmp3lame",
                        "opus" => "libopus",
                        "m4a" => "aac",
                        "flac" => "flac",
                        _ => "pcm_s16le",
                    },
                ]);
                if (ext is "mp3" or "opus" or "m4a")
                    args.AddRange(["-b:a", o.Bitrate + "k"]);
            }
        }
        if (o.StripMetadata)
            args.AddRange(["-map_metadata", "-1"]);
        args.AddRange(["-progress", "pipe:1", "-nostats", target]);
        await ProcessRunner.Run(
            Ffmpeg,
            args,
            token,
            line =>
            {
                if (
                    line.StartsWith("out_time_us=", StringComparison.Ordinal)
                    && double.TryParse(line[12..], out var us)
                )
                    progress?.Report(Math.Clamp(us / 1_000_000 / duration, 0, .99));
            }
        );
        var (actual, _) = await Probe(target, token);
        if (
            video && !actual.Video
            || !video && !actual.Audio
            || Math.Abs(actual.Duration - duration) > Math.Max(.75, duration * .03)
        )
            throw new IOException("Códec o duración de salida inesperados.");
        await ProcessRunner.Run(
            Ffmpeg,
            ["-v", "error", "-xerror", "-i", target, "-f", "null", "-"],
            token
        );
        return target;
    }

    static string F(double x) => x.ToString("0.######", CultureInfo.InvariantCulture);
}
