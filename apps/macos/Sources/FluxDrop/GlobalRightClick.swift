import AppKit
import ApplicationServices
import FluxCore

@MainActor @Observable final class GlobalRightClick {
    enum Status: String { case disabled, active, permissionRequired, unavailable }
    static let shared = GlobalRightClick()
    private(set) var status: Status = .disabled
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var gate = RightClickGate()
    private var configuration = FluxWidgetConfiguration()
    private init() {}
    func configure(_ value: FluxWidgetConfiguration) {
        configuration = value
        guard value.rightClickEnabled else {
            if !gate.awaitingUp { stop() }
            status = .disabled; return
        }
        if let tap, CFMachPortIsValid(tap) { CGEvent.tapEnable(tap: tap, enable: true); status = .active; return }
        stop()
        let mask = (CGEventMask(1) << CGEventType.rightMouseDown.rawValue) | (CGEventMask(1) << CGEventType.rightMouseUp.rawValue)
        // Mouse events only. No keyboard events, event synthesis, or private APIs.
        let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, pointer in
            guard let pointer else { return Unmanaged.passUnretained(event) }
            let owner = Unmanaged<GlobalRightClick>.fromOpaque(pointer).takeUnretainedValue()
            let rawType = type.rawValue, flags = event.flags.rawValue
            // Invariant: this tap source is installed exclusively on CFRunLoopGetMain().
            // Transfer value types only; never send the non-Sendable CGEvent across actors.
            let consume = MainActor.assumeIsolated { owner.receive(rawType: rawType, flags: flags) }
            return consume ? nil : Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let port else {
            status = !CGPreflightListenEventAccess() || !AXIsProcessTrusted() ? .permissionRequired : .unavailable
            return
        }
        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else { CFMachPortInvalidate(port); status = .unavailable; return }
        tap = port; source = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        status = .active
    }
    func requestPermission() {
        // Ask incrementally only after creating the mouse-only tap failed.
        if !CGPreflightListenEventAccess() { _ = CGRequestListenEventAccess() }
        else if !AXIsProcessTrusted() {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        configure(configuration)
    }
    private func receive(rawType: UInt32, flags rawFlags: UInt64) -> Bool {
        if rawType == CGEventType.tapDisabledByTimeout.rawValue {
            if let tap, configuration.rightClickEnabled { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }
        if rawType == CGEventType.tapDisabledByUserInput.rawValue {
            stop(); status = .unavailable
            DispatchQueue.main.async { WidgetPreferences.shared.configuration.rightClickEnabled = false }
            return false
        }
        guard rawType == CGEventType.rightMouseDown.rawValue || rawType == CGEventType.rightMouseUp.rawValue else { return false }
        let flags = CGEventFlags(rawValue: rawFlags), isDown = rawType == CGEventType.rightMouseDown.rawValue
        let matches = configuration.trigger.matches(option: flags.contains(.maskAlternate), control: flags.contains(.maskControl), shift: flags.contains(.maskShift), command: flags.contains(.maskCommand))
        let consume = gate.consume(isDown: isDown, enabled: configuration.rightClickEnabled, matches: matches, insideWidget: PanelController.shared.containsCursor)
        if isDown && consume {
            let dragging = CGEventSource.buttonState(.combinedSessionState, button: .left)
            // Return from the tap before constructing/updating windows.
            DispatchQueue.main.async { PanelController.shared.toggle(activate: !dragging) }
        }
        if !isDown && !configuration.rightClickEnabled { DispatchQueue.main.async { self.stop() } }
        return consume
    }
    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        source = nil; tap = nil; gate = .init()
    }
}
