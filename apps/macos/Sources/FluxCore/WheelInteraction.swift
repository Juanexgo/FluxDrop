import Foundation

public enum WheelMode: String, CaseIterable, Codable, Sendable { case convert, edit, files }
public enum DragKey: String, CaseIterable, Codable, Sendable { case shift, option, control, command }
public struct DragActivationSettings: Codable, Equatable, Sendable {
    public var enabled = false
    public var convertKey: DragKey = .shift
    public var editKey: DragKey = .command
    public var filesKey: DragKey = .control
    public init() {}
    public mutating func assign(_ key: DragKey, to target: WheelMode) {
        let old: DragKey
        switch target { case .convert: old = convertKey; case .edit: old = editKey; case .files: old = filesKey }
        if convertKey == key { convertKey = old }
        if editKey == key { editKey = old }
        if filesKey == key { filesKey = old }
        switch target { case .convert: convertKey = key; case .edit: editKey = key; case .files: filesKey = key }
    }
    public func validated() throws -> Self {
        guard Set([convertKey,editKey,filesKey]).count == 3 else { throw EngineFailure.invalidOptions }
        return self
    }
    public func mode(for keys: Set<DragKey>, dragging: Bool) -> WheelMode? {
        guard enabled, dragging, keys.count == 1, let key = keys.first else { return nil }
        if key == convertKey { return .convert }; if key == editKey { return .edit }; if key == filesKey { return .files }; return nil
    }
}
/// Public gesture state does not inspect another application's drag pasteboard.
public struct DragActivationGate: Sendable {
    private var previous: WheelMode?
    public init() {}
    public mutating func update(settings: DragActivationSettings, keys: Set<DragKey>, dragging: Bool) -> WheelMode? {
        let mode = settings.mode(for: keys, dragging: dragging)
        defer { previous = mode }
        return mode != previous ? mode : nil
    }
}
public enum FileAction: String, CaseIterable, Sendable { case share, shelf, copy, move, copyPaths, terminal }
public struct CropSelection: Equatable, Sendable {
    public var x: Double; public var y: Double; public var width: Double; public var height: Double
    public init(startX: Double, startY: Double, endX: Double, endY: Double) {
        let sx = min(max(startX,0),1), sy = min(max(startY,0),1), ex = min(max(endX,0),1), ey = min(max(endY,0),1)
        x = min(sx,ex); y = min(sy,ey); width = abs(ex-sx); height = abs(ey-sy)
    }
    public func apply(to options: inout ImageOptions) throws {
        guard [x,y,width,height].allSatisfy(\.isFinite), width > 0.001, height > 0.001, x >= 0, y >= 0, x+width <= 1.000001, y+height <= 1.000001 else { throw EngineFailure.invalidOptions }
        options.cropX = x; options.cropY = y; options.cropWidth = width; options.cropHeight = height
    }
}

/// Keeps every compatible action reachable while limiting the radial surface.
public struct ActionPage: Equatable, Sendable {
    public let index: Int
    public let count: Int
    public let range: Range<Int>
    public init(total: Int, requested: Int, size: Int = 7) {
        let size = max(1, size), total = max(0, total)
        count = max(1, (total + size - 1) / size)
        index = ((requested % count) + count) % count
        let start = min(total, index * size)
        range = start..<min(total, start + size)
    }
}
