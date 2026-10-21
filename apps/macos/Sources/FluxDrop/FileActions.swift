import AppKit
import SwiftUI
import FluxCore

@MainActor final class FileActionController {
    static let shared = FileActionController()
    private var picker: NSSharingServicePicker?
    func execute(_ action: FileAction, files: [URL], anchor: NSView) {
        guard !files.isEmpty, files.count <= 10000, files.allSatisfy({ $0.isFileURL && FileManager.default.fileExists(atPath: $0.path) }) else { AppModel.shared.message = tr("error.unreadable"); return }
        switch action {
        case .share:
            picker = NSSharingServicePicker(items: files); picker?.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxY)
        case .shelf: ShelfController.shared.add(files)
        case .copy:
            NSPasteboard.general.clearContents()
            if !NSPasteboard.general.writeObjects(files.map { $0 as NSURL }) { AppModel.shared.message = tr("action.failed") }
        case .copyPaths:
            NSPasteboard.general.clearContents()
            if !NSPasteboard.general.setString(files.map(\.path).joined(separator: "\n"), forType: .string) { AppModel.shared.message = tr("action.failed") }
        case .terminal:
            guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else { AppModel.shared.message = tr("action.failed"); return }
            let folders = Array(Set(files.map { url in (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true ? url : url.deletingLastPathComponent() })).sorted { $0.path < $1.path }
            guard folders.count <= 10 else { AppModel.shared.message = tr("action.terminalLimit"); return }
            NSWorkspace.shared.open(folders, withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                if error != nil { Task { @MainActor in AppModel.shared.message = tr("action.failed") } }
            }
        case .move: chooseMove(files)
        }
    }
    private func chooseMove(_ files: [URL]) {
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
        guard presentFileDialog(panel) == .OK, let destination = panel.url else { return }
        Task {
            do {
                let engine = FileMoveEngine(), plan = try await engine.plan(files, destination: destination)
                let alert = NSAlert(); alert.messageText = tr("action.moveReview")
                alert.informativeText = plan.prefix(12).map { $0.source.lastPathComponent + " → " + $0.destination.path }.joined(separator: "\n") + "\n\(plan.count) " + tr("files.short") + "\n" + tr("action.moveNote")
                alert.addButton(withTitle: tr("action.move")); alert.addButton(withTitle: tr("cancel"))
                NSApp.activate(ignoringOtherApps: true)
                guard alert.runModal() == .alertFirstButtonReturn else { return }
                try await engine.move(plan)
                AppModel.shared.files = plan.map(\.destination)
                NSWorkspace.shared.activateFileViewerSelecting(plan.map(\.destination)); PanelController.shared.hide()
            } catch { AppModel.shared.message = tr("error." + ((error as? EngineFailure)?.rawValue ?? "unknown")); PanelController.shared.show(activate: true) }
        }
    }
}
@MainActor @Observable final class ShelfController {
    static let shared = ShelfController()
    var files: [URL] = []
    var pinned = false
    private var panel: QuickPanel?
    func add(_ urls: [URL]) {
        for url in urls where url.isFileURL && !files.contains(url) && files.count < 50 { files.append(url) }
        if panel == nil {
            let p = QuickPanel(contentRect: NSRect(x: 0,y: 0,width: 310,height: 380), styleMask: [.titled,.closable,.utilityWindow,.nonactivatingPanel], backing: .buffered, defer: false)
            p.title = tr("action.shelf"); p.level = .floating; p.hidesOnDeactivate = false; p.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary]
            p.contentView = NSHostingView(rootView: ShelfView(shelf: self)); panel = p
        }
        position(); NSApp.activate(ignoringOtherApps:true); panel?.makeKeyAndOrderFront(nil)
    }
    func position() {
        guard let panel else { return }
        let frame = (NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main)?.visibleFrame ?? .zero
        let x = pinned ? frame.maxX-panel.frame.width-12 : min(max(NSEvent.mouseLocation.x,frame.minX),frame.maxX-panel.frame.width)
        panel.setFrameOrigin(NSPoint(x:x,y:max(frame.minY,frame.midY-panel.frame.height/2)))
    }
}
struct ShelfView: View {
    @Bindable var shelf: ShelfController
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Toggle(tr("action.pin"), isOn: $shelf.pinned).toggleStyle(.button).onChange(of: shelf.pinned) { shelf.position() }
                Spacer(); Button(tr("files.clear")) { shelf.files = [] }
            }
            Text(tr("action.shelfNote")).font(.caption).foregroundStyle(.secondary)
            DropTarget(title: tr("files.drop.any")) { shelf.add($0) }.frame(height: 48)
            ScrollView { LazyVStack(alignment: .leading) {
                ForEach(shelf.files, id: \.self) { url in
                    HStack {
                        Label(url.lastPathComponent, systemImage: "doc").lineLimit(1)
                            .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
                        Spacer()
                        Button { NSWorkspace.shared.activateFileViewerSelecting([url]) } label: { Image(systemName: "folder") }.accessibilityLabel(tr("finder.reveal"))
                        Button { shelf.files.removeAll { $0 == url } } label: { Image(systemName: "xmark") }.accessibilityLabel(tr("remove"))
                    }.padding(.vertical, 5).help(url.path)
                }
            } }
        }.padding(16).frame(minWidth: 280,minHeight: 320)
    }
}
