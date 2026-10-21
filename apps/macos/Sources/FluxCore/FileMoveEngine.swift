import Foundation

public actor FileMoveEngine {
    public init() {}
    public func plan(_ inputs: [URL], destination: URL) throws -> [RenameItem] {
        guard !inputs.isEmpty, inputs.count <= 10000, destination.isFileURL else { throw EngineFailure.invalidOptions }
        let fm = FileManager.default, folder = destination.resolvingSymlinksInPath().standardizedFileURL
        let folderValues = try folder.resourceValues(forKeys: [.isDirectoryKey,.volumeIdentifierKey])
        guard folderValues.isDirectory == true else { throw EngineFailure.destination }
        var names = Set<String>(); var sources = Set<String>(); var result: [RenameItem] = []
        for input in inputs {
            guard input.isFileURL else { throw EngineFailure.unsupported }
            let source = input.standardizedFileURL
            let values = try source.resourceValues(forKeys: [.isSymbolicLinkKey,.isRegularFileKey,.isDirectoryKey,.volumeIdentifierKey])
            guard values.isSymbolicLink != true, values.isRegularFile == true || values.isDirectory == true else { throw EngineFailure.unsupported }
            // Atomic moves on one volume only: never implement a hidden copy-then-delete fallback.
            guard String(describing: values.volumeIdentifier) == String(describing: folderValues.volumeIdentifier) else { throw EngineFailure.destination }
            let resolved = source.resolvingSymlinksInPath().path
            guard folder.path != resolved, !folder.path.hasPrefix(resolved + "/"), sources.insert(resolved).inserted else { throw EngineFailure.invalidOptions }
            let target = folder.appendingPathComponent(source.lastPathComponent)
            guard !fm.fileExists(atPath: target.path), names.insert(target.path.precomposedStringWithCanonicalMapping.lowercased()).inserted else { throw EngineFailure.collision }
            result.append(RenameItem(source: source, destination: target))
        }
        let sortedSources = sources.sorted()
        guard !zip(sortedSources, sortedSources.dropFirst()).contains(where: { $1.hasPrefix($0 + "/") }) else { throw EngineFailure.invalidOptions }
        return result
    }
    public func move(_ plan: [RenameItem]) async throws {
        // renamex_np(RENAME_EXCL) in FolderEngine refuses replacement and rolls back a partial batch.
        try await FolderEngine().rename(plan)
    }
}
