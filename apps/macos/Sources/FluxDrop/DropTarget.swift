import AppKit
import SwiftUI

/// Native destination: reads only file URLs offered to this view by the drag source.
struct DropTarget: NSViewRepresentable {
    let title: String
    let onDrop: @MainActor ([URL]) -> Void
    func makeNSView(context: Context) -> DropView { DropView(title: title, onDrop: onDrop) }
    func updateNSView(_ view: DropView, context: Context) { view.label.stringValue = title; view.onDrop = onDrop }
}
final class DropView: NSView {
    let label = NSTextField(labelWithString: "")
    var onDrop: @MainActor ([URL]) -> Void
    init(title: String, onDrop: @escaping @MainActor ([URL]) -> Void) {
        self.onDrop = onDrop
        super.init(frame: .zero)
        wantsLayer = true; layer?.cornerRadius = 10; layer?.borderWidth = 1
        label.stringValue = title; label.alignment = .center; label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([label.centerXAnchor.constraint(equalTo: centerXAnchor), label.centerYAnchor.constraint(equalTo: centerYAnchor), label.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -12)])
        registerForDraggedTypes([.fileURL]); setAccessibilityLabel(title); setAccessibilityRole(.group)
        highlight(false)
    }
    required init?(coder: NSCoder) { nil }
    private func urls(_ sender: NSDraggingInfo) -> [URL] {
        (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
    }
    private func highlight(_ on: Bool) { layer?.borderColor = (on ? NSColor.systemOrange : NSColor.separatorColor).cgColor; layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let valid = !urls(sender).isEmpty; highlight(valid); return valid ? .copy : []
    }
    override func draggingExited(_ sender: NSDraggingInfo?) { highlight(false) }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { !urls(sender).isEmpty }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let files = urls(sender); highlight(false); guard !files.isEmpty else { return false }; onDrop(files); return true
    }
}
