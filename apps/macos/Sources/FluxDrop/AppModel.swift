import AppKit
import SwiftUI
import FluxCore
import Carbon

private let localizedBundle: Bundle = Bundle.main.url(forResource: "FluxDrop_FluxDrop", withExtension: "bundle").flatMap(Bundle.init(url:)) ?? .module
func tr(_ key: String) -> String { NSLocalizedString(key, bundle: localizedBundle, comment: "") }

@MainActor @Observable final class AppModel {
    static let shared = AppModel()
    let queue: JobQueue
    var files: [URL] = []
    var options = ImageOptions()
    var directory: URL
    var message: String?
    var shortcut = UserDefaults.standard.integer(forKey: "shortcut")
    var search = ""
    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("FluxDrop")
        queue = JobQueue(journal: support.appendingPathComponent("queue-v1.json"), tools: Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers"))
        queue.keepHistory = !UserDefaults.standard.bool(forKey: "disableHistory")
        directory = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0].appendingPathComponent("FluxDrop", isDirectory: true)
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        catch { message = tr("error.destination") }
    }
    func addFiles() {
        let panel = NSOpenPanel(); panel.canChooseFiles = true; panel.canChooseDirectories = false; panel.allowsMultipleSelection = true; panel.allowedContentTypes = []; panel.allowsOtherFileTypes = true
        if presentFileDialog(panel) == .OK { add(panel.urls) }
    }
    func add(_ urls: [URL]) {
        for url in urls where url.isFileURL && !files.contains(url) { files.append(url) }
    }
    func chooseDestination() {
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
        if presentFileDialog(panel) == .OK, let url = panel.url { directory = url }
    }
    func run(_ urls: [URL]? = nil, format: ImageFormat? = nil) {
        let inputs = urls ?? files; guard !inputs.isEmpty else { return }
        var settings = options; if let format { settings.format = format }
        queue.enqueue(inputs, directory: directory, options: settings)
        if urls == nil { files = [] }
    }
}

@MainActor final class ShortcutController {
    static let shared = ShortcutController()
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var installedChoice: Int?
    func install(choice: Int) {
        guard installedChoice != choice else { return }
        if handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                MainActor.assumeIsolated { PanelController.shared.show() }; return noErr
            }, 1, &spec, nil, &handler)
        }
        let keys: [UInt32] = [UInt32(kVK_ANSI_D), UInt32(kVK_ANSI_K), UInt32(kVK_Space)]
        var candidate: EventHotKeyRef?
        let status = RegisterEventHotKey(keys[min(max(choice, 0), 2)], UInt32(controlKey | optionKey),
                                        EventHotKeyID(signature: 0x464C5558, id: 1), GetApplicationEventTarget(), 0, &candidate)
        if status == noErr {
            if let hotKey { UnregisterEventHotKey(hotKey) }
            hotKey = candidate; installedChoice = choice; UserDefaults.standard.set(choice, forKey: "shortcut")
        } else { AppModel.shared.shortcut = installedChoice ?? 0; AppModel.shared.message = tr("shortcut.conflict") }
    }
}

final class QuickPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { orderOut(nil) }
}
@MainActor final class PanelController {
    static let shared = PanelController()
    private var panel: QuickPanel?
    var containsCursor: Bool { panel?.isVisible == true && panel?.frame.contains(NSEvent.mouseLocation) == true }
    func show(activate: Bool = false) {
        let configuration = WidgetPreferences.shared.configuration
        if panel == nil {
            let p = QuickPanel(contentRect: NSRect(x: 0, y: 0, width: 324, height: 396), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.title = tr("panel.title"); p.isFloatingPanel = true; p.level = .floating; p.hidesOnDeactivate = false
            p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = false; p.animationBehavior = .none
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.contentView = NSHostingView(rootView: WidgetView(model: .shared)); panel = p
        }
        refresh(configuration)
        guard let panel else { return }
        let cursor = NSEvent.mouseLocation
        let frame = (NSScreen.screens.first { $0.frame.contains(cursor) } ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1000, height: 800)
        let x = min(max(cursor.x - panel.frame.width / 2, frame.minX), frame.maxX - panel.frame.width)
        let y = min(max(cursor.y - panel.frame.height / 2, frame.minY), frame.maxY - panel.frame.height)
        panel.setFrameOrigin(NSPoint(x: x, y: y)); panel.orderFrontRegardless()
        if activate { NSApp.activate(ignoringOtherApps: true); panel.makeKeyAndOrderFront(nil) }
    }
    func refresh(_ configuration: FluxWidgetConfiguration) {
        guard let panel else { return }
        panel.alphaValue = configuration.opacity
        panel.appearance = configuration.theme == .system ? nil : NSAppearance(named: configuration.theme == .dark ? .darkAqua : .aqua)
        panel.setContentSize(NSSize(width: configuration.diameter + 24, height: configuration.diameter + 72 + (configuration.showTriggerHint ? 24 : 0)))
    }
    func hide() { panel?.orderOut(nil) }
    func toggle(activate: Bool) { if panel?.isVisible == true { hide() } else { show(activate: activate) } }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) { ShortcutController.shared.install(choice: AppModel.shared.shortcut); LibraryStore.shared.startWatching(queue: AppModel.shared.queue); AppModel.shared.queue.onCompletion = CompletionNotification.post; GlobalRightClick.shared.configure(WidgetPreferences.shared.configuration) }
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        AppModel.shared.add(filenames.map { URL(fileURLWithPath: $0) }); PanelController.shared.show()
        sender.reply(toOpenOrPrint: .success)
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        GlobalRightClick.shared.stop(); AppModel.shared.queue.cancelAll(); return .terminateNow
    }
}

@MainActor func presentFileDialog(_ panel: NSSavePanel) -> NSApplication.ModalResponse {
    NSApp.activate(ignoringOtherApps: true)
    return panel.runModal()
}
