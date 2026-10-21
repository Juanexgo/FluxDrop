import Foundation

public enum ToolID: String, Codable, CaseIterable, Sendable {
    case renameCopy, image, imageIcons, pdfMerge, pdfExtract, pdfSplit, pdfRotate, pdfImages, imagesPDF, pdfText, pdfOCR, pdfCompress
    case mediaInspect, videoMP4, videoMOV, videoGIF, audioM4A, audioWAV, audioFLAC, audioJoin
    case jsonPretty, jsonMinify, jsonYAML, yamlJSON, csvJSON, jsonCSV, csvTSV, tsvCSV, markdownHTML, markdownPDF
    case zipCreate, zipExtract, tarCreate, tarExtract, gzipCreate, gzipExtract
    public var category: String {
        switch self {
        case .renameCopy: "files"
        case .image, .imageIcons: "image"
        case .pdfMerge, .pdfExtract, .pdfSplit, .pdfRotate, .pdfImages, .imagesPDF, .pdfText, .pdfOCR, .pdfCompress: "pdf"
        case .mediaInspect, .videoMP4, .videoMOV, .videoGIF, .audioM4A, .audioWAV, .audioFLAC, .audioJoin: "media"
        case .jsonPretty, .jsonMinify, .jsonYAML, .yamlJSON, .csvJSON, .jsonCSV, .csvTSV, .tsvCSV, .markdownHTML, .markdownPDF: "data"
        default: "archive"
        }
    }
}
public struct ToolStep: Codable, Equatable, Sendable {
    public var tool: ToolID
    public var image = ImageOptions()
    public var pageRotations: [Int]?
    public var pages = "" // one-based, ordered, e.g. 3,1-2
    public var rotation = 90
    public var dpi = 144
    public var start = 0.0
    public var duration = 0.0 // 0 = until end
    public var width = 1920
    public var bitrate = 2500 // kbps video
    public var audioBitrate = 192
    public var mute = false
    public var normalize = false // EBU R128, -16 LUFS / -1.5 dBTP / LRA 11
    public var stripMetadata = true
    public var targetMB = 0.0
    public var fps = 12
    public var delimiter = ","
    public var encoding = "utf8"
    public var headers = true
    public var subtitle: URL?
    public var renamePrefix: String?
    public var renameSuffix: String?
    public var renameNumber: Bool?
    public init(tool: ToolID) { self.tool = tool }
}
public struct Recipe: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var version = 1
    public var name: String
    public var steps: [ToolStep]
    public var favorite = false
    public init(name: String, steps: [ToolStep]) { self.name = name; self.steps = steps }
    public func validate() throws {
        guard version == 1, !name.isEmpty, !steps.isEmpty, steps.count <= 12 else { throw EngineFailure.invalidOptions }
        // Capabilities compose only when the previous output has the following accepted type.
        for (previous, next) in zip(steps, steps.dropFirst()) {
            guard OperationRegistry.outputs(previous.tool).isSubset(of: OperationRegistry.inputs(next.tool)) else { throw EngineFailure.invalidOptions }
        }
    }
}
public enum OperationRegistry {
    public static func inputs(_ id: ToolID) -> Set<String> {
        switch id {
        case .image, .imageIcons, .imagesPDF: ["image"]
        case .pdfMerge, .pdfExtract, .pdfSplit, .pdfRotate, .pdfImages, .pdfText, .pdfOCR, .pdfCompress: ["pdf"]
        case .mediaInspect: ["video", "audio"]
        case .videoMP4, .videoMOV, .videoGIF: ["video"]
        case .audioM4A, .audioWAV, .audioFLAC, .audioJoin: ["video", "audio"]
        case .jsonPretty, .jsonMinify, .jsonYAML, .jsonCSV: ["json"]
        case .yamlJSON: ["yaml"]
        case .csvJSON, .csvTSV: ["csv"]
        case .tsvCSV: ["tsv"]
        case .markdownHTML, .markdownPDF: ["markdown"]
        case .renameCopy, .zipCreate, .tarCreate, .gzipCreate: ["image", "pdf", "video", "audio", "json", "yaml", "csv", "tsv", "markdown", "html", "text", "archive", "directory"]
        default: ["archive"]
        }
    }
    public static func outputs(_ id: ToolID) -> Set<String> {
        switch id {
        case .renameCopy: ["image", "pdf", "video", "audio", "json", "yaml", "csv", "tsv", "markdown", "html", "text", "archive"]
        case .imageIcons: ["directory"]
        case .image, .pdfImages, .videoGIF: ["image"]
        case .pdfMerge, .pdfExtract, .pdfSplit, .pdfRotate, .imagesPDF, .pdfCompress, .markdownPDF: ["pdf"]
        case .pdfText, .pdfOCR: ["text"]
        case .videoMP4, .videoMOV: ["video"]
        case .audioM4A, .audioWAV, .audioFLAC, .audioJoin: ["audio"]
        case .jsonPretty, .jsonMinify, .yamlJSON, .csvJSON, .mediaInspect: ["json"]
        case .jsonYAML: ["yaml"]
        case .jsonCSV, .tsvCSV: ["csv"]
        case .csvTSV: ["tsv"]
        case .markdownHTML: ["html"]
        case .zipCreate, .tarCreate, .gzipCreate: ["archive"]
        default: ["directory"]
        }
    }
}

public enum SafeOutput {
    public static func publish(_ temporary: URL, directory: URL, name: String) throws -> URL {
        let fm = FileManager.default
        let ext = temporary.pathExtension
        let stem = String(URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent.prefix(100))
        let isDirectory = (try temporary.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true
        for i in 0..<10000 {
            try Task.checkCancellation()
            let base = stem + "-fluxdrop" + (i == 0 ? "" : "-\(i)")
            let target = directory.appendingPathComponent(base + (ext.isEmpty ? "" : "." + ext))
            if isDirectory {
                // renamex_np with RENAME_EXCL refuses replacement atomically.
                if renamex_np(temporary.path, target.path, UInt32(RENAME_EXCL)) == 0 { return target }
            } else if link(temporary.path, target.path) == 0 { return target }
            if errno != EEXIST { throw EngineFailure.destination }
        }
        _ = fm; throw EngineFailure.destination
    }
    public static func stage(in directory: URL) throws -> URL {
        let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .volumeAvailableCapacityForImportantUsageKey])
        guard values.isDirectory == true else { throw EngineFailure.destination }
        if let bytes = values.volumeAvailableCapacityForImportantUsage, bytes < 32 * 1024 * 1024 { throw EngineFailure.noSpace }
        let url = directory.appendingPathComponent(".fluxdrop-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700]); return url
    }
}
