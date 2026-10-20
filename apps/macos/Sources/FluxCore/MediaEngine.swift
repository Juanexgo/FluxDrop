import Foundation

public actor ProcessRunner {
    public init() {}
    private static func progressTail(_ url: URL) throws -> String {
        let file = try FileHandle(forReadingFrom: url); defer { try? file.close() }
        let size = try file.seekToEnd(); try file.seek(toOffset: size > 65536 ? size - 65536 : 0)
        return String(decoding: try file.readToEnd() ?? Data(), as: UTF8.self)
    }
    /// No shell. Embedded FFmpeg/ffprobe do not spawn subprocesses; cancellation kills the process and its threads.
    public func run(executable: URL, arguments: [String], directory: URL,
                    progressFile: URL? = nil, duration: Double = 0,
                    progress: @Sendable (Double) async -> Void = { _ in }) async throws -> Data {
        try Task.checkCancellation()
        guard FileManager.default.isExecutableFile(atPath: executable.path) else { throw EngineFailure.unavailableEngine }
        let stdout = directory.appendingPathComponent(UUID().uuidString + ".stdout")
        let stderr = directory.appendingPathComponent(UUID().uuidString + ".stderr")
        FileManager.default.createFile(atPath: stdout.path, contents: nil)
        FileManager.default.createFile(atPath: stderr.path, contents: nil)
        let out = try FileHandle(forWritingTo: stdout), err = try FileHandle(forWritingTo: stderr)
        defer { try? out.close(); try? err.close(); try? FileManager.default.removeItem(at: stdout); try? FileManager.default.removeItem(at: stderr) }
        let process = Process(); process.executableURL = executable; process.arguments = arguments
        process.standardInput = FileHandle.nullDevice; process.standardOutput = out; process.standardError = err
        process.environment = ["PATH": "/usr/bin:/bin", "LANG": "en_US.UTF-8"]; process.currentDirectoryURL = directory
        try process.run()
        while process.isRunning {
            if Task.isCancelled {
                kill(process.processIdentifier, SIGKILL)
                while process.isRunning { await Task.yield() }
                throw CancellationError()
            }
            if let progressFile, duration > 0, let text = try? Self.progressTail(progressFile),
               let value = text.components(separatedBy: "\n").last(where: { $0.hasPrefix("out_time_us=") }),
               let micros = Double(value.dropFirst(12)) {
                await progress(min(0.99, max(0, micros / 1_000_000 / duration)))
            }
            // Bound diagnostic storage for malformed inputs.
            let size = (try? stderr.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let outputSize = (try? stdout.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            if size > 4_000_000 || outputSize > 16_000_000 { kill(process.processIdentifier, SIGKILL); while process.isRunning { await Task.yield() }; throw EngineFailure.process }
            try? await Task.sleep(for: .milliseconds(100))
        }
        try Task.checkCancellation()
        guard process.terminationStatus == 0 else { throw EngineFailure.process }
        let size = (try stdout.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0
        guard size <= 16_000_000 else { throw EngineFailure.tooLarge }
        return try Data(contentsOf: stdout)
    }
}
public actor MediaEngine {
    private let runner = ProcessRunner()
    private let tools: URL
    public init(tools: URL) { self.tools = tools }
    public func inspect(_ input: URL, staging: URL) async throws -> Data {
        guard input.isFileURL else { throw EngineFailure.unsupported }
        return try await runner.run(executable: tools.appendingPathComponent("ffprobe"), arguments: ["-v", "error", "-protocol_whitelist", "file,pipe", "-show_format", "-show_streams", "-of", "json", input.path], directory: staging)
    }
    public func execute(inputs: [URL], step: ToolStep, staging: URL, progress: @Sendable (Double) async -> Void = { _ in }) async throws -> [URL] {
        guard let input = inputs.first, step.start.isFinite, step.duration.isFinite, step.targetMB.isFinite,
              step.start >= 0, step.duration >= 0, (16...8192).contains(step.width), (1...30).contains(step.fps),
              (64...50000).contains(step.bitrate), (32...320).contains(step.audioBitrate), (0...100000).contains(step.targetMB) else { throw EngineFailure.invalidOptions }
        let data = try await inspect(input, staging: staging)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], let streams = root["streams"] as? [[String: Any]], !streams.isEmpty else { throw EngineFailure.unsupported }
        if step.tool == .mediaInspect { let url = staging.appendingPathComponent("media.json"); try data.write(to: url); return [url] }
        let video = streams.first { $0["codec_type"] as? String == "video" }
        let audio = streams.contains { $0["codec_type"] as? String == "audio" }
        let isVideo = [.videoMP4, .videoMOV, .videoGIF].contains(step.tool)
        guard isVideo ? video != nil : audio else { throw EngineFailure.unsupported }
        // Refuse HDR rather than silently clipping or mislabelling it as SDR.
        if let transfer = video?["color_transfer"] as? String, ["smpte2084", "arib-std-b67"].contains(transfer), isVideo { throw EngineFailure.hdr }
        let format = root["format"] as? [String: Any]
        let total = Double(format?["duration"] as? String ?? "0") ?? 0
        guard total > 0, step.start < total else { throw EngineFailure.invalidOptions }
        let duration = step.duration > 0 ? min(step.duration, total - step.start) : total - step.start
        let ext: String
        switch step.tool { case .videoMP4: ext = "mp4"; case .videoMOV: ext = "mov"; case .videoGIF: ext = "gif"; case .audioM4A: ext = "m4a"; case .audioFLAC: ext = "flac"; default: ext = "wav" }
        let output = staging.appendingPathComponent("media." + ext), progressURL = staging.appendingPathComponent("progress.txt")
        var args = ["-hide_banner", "-loglevel", "error", "-nostdin", "-y", "-protocol_whitelist", "file,pipe", "-i", input.path]
        if step.tool == .audioJoin {
            guard inputs.count > 1, inputs.count <= 32 else { throw EngineFailure.invalidOptions }
            for url in inputs.dropFirst() { args += ["-protocol_whitelist", "file,pipe", "-i", url.path] }
            let chain = inputs.indices.map { "[\($0):a:0]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo[a\($0)];" }.joined()
            args += ["-filter_complex", chain + inputs.indices.map { "[a\($0)]" }.joined() + "concat=n=\(inputs.count):v=0:a=1" + (step.normalize ? ",loudnorm=I=-16:TP=-1.5:LRA=11" : "") + "[out]", "-map", "[out]", "-c:a", "pcm_s16le", "-ss", String(step.start)]
            if step.duration > 0 { args += ["-t", String(step.duration)] }
        } else {
            if let subtitle = step.subtitle, isVideo, step.tool != .videoGIF {
                guard ["srt", "vtt"].contains(subtitle.pathExtension.lowercased()) else { throw EngineFailure.unsupported }
                args += ["-protocol_whitelist", "file,pipe", "-i", subtitle.path, "-map", "0:v:0", "-map", "0:a?", "-map", "1:0", "-c:s", "mov_text"]
            }
            args += ["-ss", String(step.start), "-t", String(duration)]
            if isVideo {
                if step.tool == .videoGIF {
                    guard duration <= 60 else { throw EngineFailure.invalidOptions }
                    let width = min(step.width, 960)
                    args += ["-an", "-filter_complex", "fps=\(step.fps),scale=\(width):-2:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse", "-loop", "0"]
                } else {
                    let bitrate = step.targetMB > 0 ? Int(step.targetMB * 8_000 / duration) - (step.mute ? 0 : step.audioBitrate) : step.bitrate
                    guard bitrate >= 64 else { throw EngineFailure.invalidOptions }
                    args += ["-vf", "scale='min(\(step.width),iw)':-2", "-pix_fmt", "yuv420p"]
                    if step.tool == .videoMP4 { args += ["-c:v", "h264_videotoolbox", "-allow_sw", "1", "-b:v", "\(bitrate)k"] }
                    else { args += ["-c:v", "mpeg4", "-b:v", "\(bitrate)k"] }
                    if step.mute { args += ["-an"] } else { args += ["-c:a", "aac", "-b:a", "\(step.audioBitrate)k"] }
                    args += ["-movflags", "+faststart"]
                }
            } else {
                args += ["-vn"]
                switch step.tool { case .audioM4A: args += ["-c:a", "aac", "-b:a", "\(step.audioBitrate)k"]; case .audioFLAC: args += ["-c:a", "flac"]; default: args += ["-c:a", "pcm_s16le"] }
            }
            if step.normalize && audio && !step.mute && step.tool != .videoGIF { args += ["-af", "loudnorm=I=-16:TP=-1.5:LRA=11"] }
        }
        if step.stripMetadata { args += ["-map_metadata", "-1", "-map_chapters", "-1"] }
        args += ["-progress", progressURL.path, output.path]
        _ = try await runner.run(executable: tools.appendingPathComponent("ffmpeg"), arguments: args, directory: staging, progressFile: progressURL, duration: step.tool == .audioJoin ? 0 : duration, progress: progress)
        let verified = try await inspect(output, staging: staging)
        guard let result = try JSONSerialization.jsonObject(with: verified) as? [String: Any], let resultStreams = result["streams"] as? [[String: Any]], !resultStreams.isEmpty else { throw EngineFailure.verify }
        _ = try await runner.run(executable: tools.appendingPathComponent("ffmpeg"), arguments: ["-v", "error", "-nostdin", "-protocol_whitelist", "file,pipe", "-i", output.path, "-t", "1", "-f", "null", "-"], directory: staging)
        if step.targetMB > 0 && isVideo && step.tool != .videoGIF {
            let size = (try output.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0
            let report = staging.appendingPathComponent("size-report.txt")
            try "Target: \(step.targetMB) MB\nActual: \(Double(size)/1_000_000) MB\nApproximate bitrate target, not a hard limit.\n".write(to: report, atomically: true, encoding: .utf8)
            return [output, report]
        }
        return [output]
    }
}
