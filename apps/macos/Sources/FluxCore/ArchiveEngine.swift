import Foundation
import CArchive

public actor ArchiveEngine {
    public init() {}
    static let limit: Int64 = 1_073_741_824
    public static func safeComponents(_ path: String) throws -> [String] {
        guard !path.hasPrefix("/"), !path.contains("\\"), !path.contains(":"), !path.contains("\0") else { throw EngineFailure.unsafeArchive }
        let parts = path.split(separator: "/").map(String.init)
        guard !parts.isEmpty, parts.count < 64, parts.allSatisfy({ $0 != ".." && $0 != "." && $0.utf8.count <= 240 }) else { throw EngineFailure.unsafeArchive }
        return parts
    }
    public func execute(inputs: [URL], step: ToolStep, staging: URL) throws -> [URL] {
        guard !inputs.isEmpty else { throw EngineFailure.invalidOptions }
        if [.zipExtract, .tarExtract, .gzipExtract].contains(step.tool) {
            guard inputs.count == 1 else { throw EngineFailure.invalidOptions }
            let folder = staging.appendingPathComponent("extracted", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            try extract(inputs[0], into: folder, tool: step.tool); return [folder]
        }
        let ext = step.tool == .zipCreate ? "zip" : step.tool == .tarCreate ? "tar" : "gz"
        let output = staging.appendingPathComponent("archive." + ext)
        guard let writer = archive_write_new() else { throw EngineFailure.encode }; defer { archive_write_free(writer) }
        switch step.tool {
        case .zipCreate: guard archive_write_set_format_zip(writer) == 0 else { throw EngineFailure.encode }
        case .tarCreate: guard archive_write_set_format_pax_restricted(writer) == 0 else { throw EngineFailure.encode }
        case .gzipCreate:
            guard inputs.count == 1, archive_write_set_format_raw(writer) == 0, archive_write_add_filter_gzip(writer) == 0 else { throw EngineFailure.invalidOptions }
        default: throw EngineFailure.unsupported
        }
        guard archive_write_open_filename(writer, output.path) == 0 else { throw EngineFailure.destination }
        var names = Set<String>(); var total: Int64 = 0; var count = 0
        for input in inputs {
            var files = [input]
            let root = try input.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            if root.isDirectory == true {
                guard step.tool != .gzipCreate else { throw EngineFailure.invalidOptions }
                if let enumerator = FileManager.default.enumerator(at: input, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: []) {
                    for case let url as URL in enumerator { files.append(url); guard files.count <= 10000 else { throw EngineFailure.tooLarge } }
                }
            }
            for file in files {
                try Task.checkCancellation(); count += 1; guard count <= 10000 else { throw EngineFailure.tooLarge }
                let values = try file.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                guard values.isSymbolicLink != true, values.isDirectory == true || values.isRegularFile == true else { throw EngineFailure.unsafeArchive }
                let relative = input.lastPathComponent + String(file.path.dropFirst(input.path.count))
                _ = try Self.safeComponents(relative)
                guard names.insert(relative.precomposedStringWithCanonicalMapping.lowercased()).inserted else { throw EngineFailure.unsafeArchive }
                let size = Int64(values.fileSize ?? 0); total += values.isDirectory == true ? 0 : size
                guard total <= Self.limit else { throw EngineFailure.tooLarge }
                guard let entry = archive_entry_new() else { throw EngineFailure.encode }; defer { archive_entry_free(entry) }
                archive_entry_set_pathname(entry, relative); archive_entry_set_filetype(entry, values.isDirectory == true ? 0o040000 : 0o100000)
                archive_entry_set_perm(entry, values.isDirectory == true ? 0o700 : 0o600); archive_entry_set_size(entry, values.isDirectory == true ? 0 : size)
                guard archive_write_header(writer, entry) == 0 else { throw EngineFailure.encode }
                if values.isRegularFile == true {
                    let handle = try FileHandle(forReadingFrom: file); defer { try? handle.close() }
                    var read: Int64 = 0
                    while let data = try handle.read(upToCount: 65536), !data.isEmpty {
                        try Task.checkCancellation(); read += Int64(data.count); guard read <= size else { throw EngineFailure.verify }
                        let written = data.withUnsafeBytes { archive_write_data(writer, $0.baseAddress, data.count) }
                        guard written == data.count else { throw EngineFailure.encode }
                    }
                    guard read == size else { throw EngineFailure.verify }
                }
            }
        }
        guard archive_write_close(writer) == 0 else { throw EngineFailure.encode }
        let verify = staging.appendingPathComponent("verify", isDirectory: true)
        try FileManager.default.createDirectory(at: verify, withIntermediateDirectories: false)
        try extract(output, into: verify, tool: step.tool == .gzipCreate ? .gzipExtract : step.tool == .zipCreate ? .zipExtract : .tarExtract)
        try FileManager.default.removeItem(at: verify)
        return [output]
    }
    private func extract(_ source: URL, into directory: URL, tool: ToolID) throws {
        guard let reader = archive_read_new() else { throw EngineFailure.unreadable }; defer { archive_read_free(reader) }
        archive_read_support_filter_all(reader)
        switch tool { case .zipExtract: archive_read_support_format_zip(reader); case .tarExtract: archive_read_support_format_tar(reader); case .gzipExtract: archive_read_support_format_raw(reader); default: throw EngineFailure.unsupported }
        guard archive_read_open_filename(reader, source.path, 65536) == 0 else { throw EngineFailure.unreadable }
        let compressed = Int64((try source.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0)
        let allowed = min(Self.limit, max(16_777_216, compressed * 200))
        var entry: OpaquePointer?; var names = Set<String>(); var total: Int64 = 0; var count = 0
        while true {
            try Task.checkCancellation()
            let status = archive_read_next_header(reader, &entry)
            if status == 1 { break }
            guard status == 0, let entry, let raw = archive_entry_pathname(entry) else { throw EngineFailure.unreadable }
            count += 1; guard count <= 10000 else { throw EngineFailure.tooLarge }
            guard archive_entry_symlink(entry) == nil, archive_entry_hardlink(entry) == nil else { throw EngineFailure.unsafeArchive }
            let type = archive_entry_filetype(entry)
            guard type == 0o100000 || type == 0o040000 else { throw EngineFailure.unsafeArchive }
            let path = tool == .gzipExtract ? "decompressed" : String(cString: raw)
            let components = try Self.safeComponents(path)
            let normalized = components.joined(separator: "/").precomposedStringWithCanonicalMapping.lowercased()
            guard names.insert(normalized).inserted else { throw EngineFailure.unsafeArchive }
            let target = components.reduce(directory) { $0.appendingPathComponent($1) }
            let size = archive_entry_size(entry)
            guard size >= 0, size <= allowed - total else { throw EngineFailure.tooLarge }
            if type == 0o040000 { try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]); continue }
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let fd = open(target.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
            guard fd >= 0 else { throw EngineFailure.unsafeArchive }
            let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true); defer { try? handle.close() }
            var buffer = [UInt8](repeating: 0, count: 65536)
            while true {
                try Task.checkCancellation()
                let amount = archive_read_data(reader, &buffer, buffer.count)
                guard amount >= 0 else { throw EngineFailure.unreadable }; if amount == 0 { break }
                total += Int64(amount); guard total <= allowed else { throw EngineFailure.tooLarge }
                try handle.write(contentsOf: Data(buffer.prefix(amount)))
            }
        }
        guard count > 0 else { throw EngineFailure.unreadable }
    }
}
