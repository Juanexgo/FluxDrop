import Foundation

public enum WidgetTheme: String, Codable, CaseIterable, Sendable { case system, light, dark }
public enum WidgetAccent: String, Codable, CaseIterable, Sendable { case coral, orange, blue, green, violet }
public enum WidgetTrigger: String, Codable, CaseIterable, Sendable {
    case rightClick, optionRightClick, controlRightClick
    public func matches(option: Bool, control: Bool, shift: Bool, command: Bool) -> Bool {
        guard !shift, !command else { return false }
        switch self {
        case .rightClick: return !option && !control
        case .optionRightClick: return option && !control
        case .controlRightClick: return control && !option
        }
    }
}
public struct FluxWidgetConfiguration: Codable, Equatable, Sendable {
    public var version = 1
    public var diameter = 300.0
    public var opacity = 1.0
    public var theme: WidgetTheme = .system
    public var accent: WidgetAccent = .coral
    public var showLabels = true
    public var showTriggerHint = true
    public var favoritesFirst = true
    public var closeAfterAction = true
    public var rightClickEnabled = false
    public var trigger: WidgetTrigger = .rightClick
    public var dragActivation: DragActivationSettings?
    public var dragSettings: DragActivationSettings {
        get { dragActivation ?? DragActivationSettings() }
        set { dragActivation = newValue }
    }
    public init() {}
    public func validated() throws -> Self {
        guard version == 1, diameter.isFinite, (240...400).contains(diameter), opacity.isFinite, (0.85...1).contains(opacity) else { throw EngineFailure.invalidOptions }
        _ = try dragSettings.validated()
        return self
    }
    public mutating func resetAppearance() {
        diameter = 300; opacity = 1; theme = .system; accent = .coral; showLabels = true; showTriggerHint = true
    }
}
/// Match the mouse-down/up pair: never consume an unrelated mouse-up.
public struct RightClickGate: Sendable {
    public private(set) var awaitingUp = false
    public init() {}
    public mutating func consume(isDown: Bool, enabled: Bool, matches: Bool, insideWidget: Bool) -> Bool {
        if !isDown { let result = awaitingUp; awaitingUp = false; return result }
        awaitingUp = enabled && matches && !insideWidget
        return awaitingUp
    }
}
