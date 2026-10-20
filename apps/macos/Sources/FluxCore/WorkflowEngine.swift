import Foundation

public actor WorkflowEngine {
    private let image = ImageEngine(), pdf = PDFEngine(), data = DataEngine(), archive = ArchiveEngine()
    private let media: MediaEngine
    public init(tools: URL) { media = MediaEngine(tools: tools) }
    public func run(inputs: [URL], recipe: Recipe, directory: URL, password: String? = nil,
                    progress: @escaping @Sendable (Double?) async -> Void = { _ in }) async throws -> [URL] {
        try recipe.validate(); guard !inputs.isEmpty, inputs.allSatisfy(\.isFileURL) else { throw EngineFailure.invalidOptions }
        let staging = try SafeOutput.stage(in: directory)
        defer { try? FileManager.default.removeItem(at: staging) }
        var current = inputs
        for (index, step) in recipe.steps.enumerated() {
            try Task.checkCancellation()
            let folder = staging.appendingPathComponent("step-\(index)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            let count = recipe.steps.count
            let update: @Sendable (Double) async -> Void = { fraction in await progress((Double(index) + fraction)/Double(count)) }
            switch step.tool.category {
            case "image":
                var next: [URL] = []
                for (i, url) in current.enumerated() {
                    if step.tool == .imageIcons { next.append(try await image.icons(input: url, directory: folder)) }
                    else { next.append(try await image.convert(input: url, directory: folder, options: step.image)) }; await update(Double(i+1)/Double(current.count))
                }
                current = next
            case "pdf": current = try await pdf.execute(inputs: current, step: step, staging: folder, password: password, progress: update)
            case "media":
                if step.tool == .audioJoin { current = try await media.execute(inputs: current, step: step, staging: folder, progress: update) }
                else {
                    var next: [URL] = []
                    for (i, url) in current.enumerated() {
                        let sub = folder.appendingPathComponent(String(i)); try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: false)
                        let batchCount = current.count
                        let batchUpdate: @Sendable (Double) async -> Void = { fraction in await update((Double(i) + fraction) / Double(batchCount)) }
                        let results = try await media.execute(inputs: [url], step: step, staging: sub, progress: batchUpdate)
                        // The size report is auxiliary, not input to the next conversion.
                        next += index < recipe.steps.count-1 ? results.filter { $0.lastPathComponent != "size-report.txt" } : results
                    }
                    current = next
                }
            case "data": current = try await data.execute(inputs: current, step: step, staging: folder)
            case "files":
                var next: [URL] = []
                for (i, url) in current.enumerated() {
                    let prefix = step.renamePrefix ?? "", suffix = step.renameSuffix ?? ""
                    let name = prefix + (step.renameNumber == true ? String(format: "%03d-", i+1) : "") + url.deletingPathExtension().lastPathComponent + suffix + (url.pathExtension.isEmpty ? "" : "." + url.pathExtension)
                    guard !name.contains("/"), !name.contains(":"), !name.contains("\0"), name.utf8.count < 240 else { throw EngineFailure.invalidOptions }
                    let target = folder.appendingPathComponent(name)
                    try FileManager.default.copyItem(at: url, to: target); next.append(target)
                }
                current = next
            case "archive": current = try await archive.execute(inputs: current, step: step, staging: folder)
            default: throw EngineFailure.unsupported
            }
        }
        try Task.checkCancellation()
        // Multi-output operations commit one directory atomically, so no partial batch is presented as complete.
        if current.count > 1 {
            let output = staging.appendingPathComponent("results", isDirectory: true)
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
            for (i, url) in current.enumerated() { try FileManager.default.moveItem(at: url, to: output.appendingPathComponent("\(i+1)-" + url.lastPathComponent)) }
            return [try SafeOutput.publish(output, directory: directory, name: inputs[0].lastPathComponent)]
        }
        guard let output = current.first else { throw EngineFailure.verify }
        return [try SafeOutput.publish(output, directory: directory, name: recipe.steps.last?.tool == .renameCopy ? output.lastPathComponent : inputs[0].lastPathComponent)]
    }
}
