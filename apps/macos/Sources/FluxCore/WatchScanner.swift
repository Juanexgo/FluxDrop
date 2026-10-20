import Foundation

public struct WatchRule: Identifiable, Codable, Sendable {
    public var id = UUID()
    public var source: URL
    public var destination: URL
    public var sourceBookmark: Data
    public var destinationBookmark: Data
    public var recipe: Recipe
    public var enabled = true
    public var processed: [String: String] = [:]
    public init(source: URL, destination: URL, recipe: Recipe) throws {
        let a = source.resolvingSymlinksInPath().standardizedFileURL.path + "/", b = destination.resolvingSymlinksInPath().standardizedFileURL.path + "/"
        guard !a.hasPrefix(b), !b.hasPrefix(a) else { throw EngineFailure.invalidOptions }
        try recipe.validate(); self.source = source; self.destination = destination; self.recipe = recipe
        sourceBookmark = try source.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        destinationBookmark = try destination.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
    }
}
public struct WatchScan: Sendable {
    public let source: URL
    public let destination: URL
    public let ready: [URL]
    public let fingerprints: [String: String]
}
public actor WatchScanner {
    private struct Observation { let signature: String; let since: Date }
    private var observations: [UUID: [String: Observation]] = [:]
    public init() {}
    public func scan(_ rule: WatchRule, now: Date = Date()) throws -> WatchScan {
        var stale = false
        let source = try URL(resolvingBookmarkData: rule.sourceBookmark, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
        let destination = try URL(resolvingBookmarkData: rule.destinationBookmark, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
        let a = source.resolvingSymlinksInPath().standardizedFileURL.path + "/", b = destination.resolvingSymlinksInPath().standardizedFileURL.path + "/"
        guard !a.hasPrefix(b), !b.hasPrefix(a) else { throw EngineFailure.destination }
        let files = try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles])
        guard files.count <= 10000 else { throw EngineFailure.tooLarge }
        var state = observations[rule.id] ?? [:], ready: [URL] = [], fingerprints: [String: String] = [:]
        let paths = Set(files.map(\.path)); state = state.filter { paths.contains($0.key) }
        for url in files {
            let value = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey])
            guard value.isRegularFile == true, value.isSymbolicLink != true, !url.lastPathComponent.contains("-fluxdrop") else { continue }
            let signature = "\(value.fileSize ?? 0):\(value.contentModificationDate?.timeIntervalSince1970 ?? 0)"
            if rule.processed[url.path] == signature { continue }
            if let previous = state[url.path], previous.signature == signature, now.timeIntervalSince(previous.since) >= 10 {
                // Quiet-period heuristic; cannot prove another application has closed a file.
                ready.append(url); fingerprints[url.path] = signature
            } else if state[url.path]?.signature != signature { state[url.path] = Observation(signature: signature, since: now) }
        }
        observations[rule.id] = state
        return WatchScan(source: source, destination: destination, ready: ready, fingerprints: fingerprints)
    }
}
