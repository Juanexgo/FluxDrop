import AppKit
import ApplicationServices
import FluxCore

@MainActor @Observable final class WheelSession {
    static let shared = WheelSession()
    var mode: WheelMode = .convert
}
@MainActor @Observable final class DragActivation {
    static let shared = DragActivation()
    private(set) var active = false
    private(set) var permissionRequired = false
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var gate = DragActivationGate()
    private var settings = DragActivationSettings()
    func configure(_ value: DragActivationSettings) {
        settings = value
        guard value.enabled else { stop(); return }
        // Keyboard modifiers may require Accessibility/Input Monitoring. No key text is requested.
        guard CGPreflightListenEventAccess() || AXIsProcessTrusted() else { stop(); permissionRequired = true; return }
        if let tap, CFMachPortIsValid(tap) { CGEvent.tapEnable(tap: tap, enable: true); active = true; return }
        stop()
        let mask = CGEventMask(1) << CGEventType.flagsChanged.rawValue
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly, eventsOfInterest: mask, callback: { _, type, event, pointer in
            guard let pointer else { return Unmanaged.passUnretained(event) }
            let owner = Unmanaged<DragActivation>.fromOpaque(pointer).takeUnretainedValue()
            let raw = type.rawValue, flags = event.flags.rawValue
            // This source is installed only on the main run loop. No CGEvent crosses actors.
            MainActor.assumeIsolated { owner.receive(type: raw, flags: flags) }
            return Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()), let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else { permissionRequired = true; return }
        self.tap = port; self.source = source; CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true); active = true; permissionRequired = false
    }
    func requestPermission() {
        if !CGPreflightListenEventAccess() { _ = CGRequestListenEventAccess() }
        else if !AXIsProcessTrusted() { _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) }
        configure(settings)
    }
    private func receive(type: UInt32, flags raw: UInt64) {
        if type == CGEventType.tapDisabledByTimeout.rawValue { if let tap { CGEvent.tapEnable(tap: tap, enable: true) }; return }
        if type == CGEventType.tapDisabledByUserInput.rawValue { stop(); DispatchQueue.main.async { WidgetPreferences.shared.configuration.dragSettings.enabled = false }; return }
        guard type == CGEventType.flagsChanged.rawValue else { return }
        let flags = CGEventFlags(rawValue: raw); var keys = Set<DragKey>()
        if flags.contains(.maskShift) { keys.insert(.shift) }; if flags.contains(.maskAlternate) { keys.insert(.option) }
        if flags.contains(.maskControl) { keys.insert(.control) }; if flags.contains(.maskCommand) { keys.insert(.command) }
        let dragging = CGEventSource.buttonState(.combinedSessionState, button: .left)
        guard let mode = gate.update(settings: settings, keys: keys, dragging: dragging) else { return }
        DispatchQueue.main.async { WheelSession.shared.mode = mode; PanelController.shared.show(activate: false) }
    }
    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        tap = nil; source = nil; active = false; permissionRequired = false; gate = .init()
    }
}
