import Foundation
import CryptoKit

public struct RenameItem: Identifiable, Sendable {
    public var id: URL { source }
    public let source: URL
    public let destination: URL
}
public struct RenameOptions: Sendable {
    public var prefix = "", suffix = "", find = "", replace = ""
    public var number = false
    public init() {}
}
public struct DuplicateGroup: Identifiable, Sendable {
    public var id: String { digest }
    public let digest: String
    public let files: [URL]
    public let bytes: Int64
}
public actor FolderEngine {
    public init() {}
    public func plan(_ inputs: [URL], options: RenameOptions) throws -> [RenameItem] {
        guard inputs.count <= 10000 else { throw EngineFailure.tooLarge }
        var destinations = Set<String>(); var plan: [RenameItem] = []
        for (i, source) in inputs.enumerated() {
            let values = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else { throw EngineFailure.unsupported }
            let stem = source.deletingPathExtension().lastPathComponent
            let changed = options.find.isEmpty ? stem : stem.replacingOccurrences(of: options.find, with: options.replace)
            let name = options.prefix + (options.number ? String(format: "%03d-", i+1) : "") + changed + options.suffix + (source.pathExtension.isEmpty ? "" : "." + source.pathExtension)
            guard !name.isEmpty, !name.contains("/"), !name.contains(":"), !name.contains("\0"), name.utf8.count <= 240 else { throw EngineFailure.invalidOptions }
            let target = source.deletingLastPathComponent().appendingPathComponent(name)
            if target == source { continue }
            guard destinations.insert(target.path.precomposedStringWithCanonicalMapping.lowercased()).inserted,
                  !FileManager.default.fileExists(atPath: target.path) else { throw EngineFailure.collision }
            plan.append(RenameItem(source: source, destination: target))
        }
        return plan
    }
    public func rename(_ plan: [RenameItem]) throws {
        var completed: [RenameItem] = []
        do {
            for item in plan {
                try Task.checkCancellation()
                guard renamex_np(item.source.path, item.destination.path, UInt32(RENAME_EXCL)) == 0 else { throw EngineFailure.collision }
                completed.append(item)
            }
        } catch {
            var rollbackFailed = false
            for item in completed.reversed() { if renamex_np(item.destination.path, item.source.path, UInt32(RENAME_EXCL)) != 0 { rollbackFailed = true } }
            if rollbackFailed { throw EngineFailure.partialRename }; throw error
        }
    }
    public func duplicates(_ inputs: [URL]) throws -> [DuplicateGroup] {
        var bySize: [Int64: [URL]] = [:]
        for url in Set(inputs) {
            let value = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
            guard value.isRegularFile == true, value.isSymbolicLink != true else { continue }
            bySize[Int64(value.fileSize ?? 0), default: []].append(url)
        }
        var result: [DuplicateGroup] = []
        for (size, urls) in bySize where urls.count > 1 {
            var groups: [String: [URL]] = [:]
            for url in urls {
                let file = try FileHandle(forReadingFrom: url); defer { try? file.close() }
                var hash = SHA256()
                while let bytes = try file.read(upToCount: 1_048_576), !bytes.isEmpty { try Task.checkCancellation(); hash.update(data: bytes) }
                let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
                groups[digest, default: []].append(url)
            }
            for (digest, files) in groups where files.count > 1 { result.append(DuplicateGroup(digest: digest, files: files.sorted { $0.path < $1.path }, bytes: size)) }
        }
        return result
    }
    public func trash(_ selected: Set<URL>, groups: [DuplicateGroup]) throws {
        let allowed = Set(groups.flatMap(\.files))
        guard selected.isSubset(of: allowed), groups.allSatisfy({ !Set($0.files).isSubset(of: selected) }) else { throw EngineFailure.invalidOptions }
        // Re-hash before removing; stale scan results never authorize deleting changed content.
        let current = try duplicates(groups.flatMap(\.files))
        let currentFiles = Set(current.flatMap(\.files)); guard selected.isSubset(of: currentFiles), current.allSatisfy({ !Set($0.files).isSubset(of: selected) }) else { throw EngineFailure.verify }
        for url in selected { try Task.checkCancellation(); try FileManager.default.trashItem(at: url, resultingItemURL: nil) }
    }
    public func organize(_ inputs: [URL], directory: URL) throws -> URL {
        let staging = try SafeOutput.stage(in: directory); defer { try? FileManager.default.removeItem(at: staging) }
        let output = staging.appendingPathComponent("organized", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
        for url in inputs {
            try Task.checkCancellation()
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else { throw EngineFailure.unsupported }
            let ext = url.pathExtension.lowercased()
            let category = ["jpg", "jpeg", "png", "heic", "tiff", "webp"].contains(ext) ? "Images" : ["mov", "mp4", "mkv"].contains(ext) ? "Video" : ["wav", "m4a", "flac", "mp3"].contains(ext) ? "Audio" : ext == "pdf" ? "PDF" : "Other"
            let folder = output.appendingPathComponent(category, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let temp = staging.appendingPathComponent(UUID().uuidString + (ext.isEmpty ? "" : "." + ext))
            try FileManager.default.copyItem(at: url, to: temp)
            _ = try SafeOutput.publish(temp, directory: folder, name: url.lastPathComponent)
            try FileManager.default.removeItem(at: temp)
        }
        return try SafeOutput.publish(output, directory: directory, name: "organized")
    }
}
