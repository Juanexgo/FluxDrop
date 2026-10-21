import AppKit
import SwiftUI
import FluxCore

struct RadialPanel: NSViewRepresentable {
    let model: AppModel
    var configuration = FluxWidgetConfiguration()
    var favorites: [Recipe] = []
    var mode: WheelMode = .convert
    func makeNSView(context: Context) -> RadialDropView { RadialDropView(model: model) }
    func updateNSView(_ view: RadialDropView, context: Context) { view.configuration = configuration; view.favorites = favorites; view.mode = mode; view.refreshSelection() }
}
@MainActor final class RadialDropView: NSView {
    enum Command { case recipe(Recipe), editor(EditorController.Kind), file(FileAction) }
    struct Action { let title: String; let command: Command; let extensions: Set<String> }
    var mode: WheelMode = .convert
    var configuration = FluxWidgetConfiguration()
    var favorites: [Recipe] = []
    private var tracking: NSTrackingArea?
    private let model: AppModel
    private var actions: [Action] = []
    private var dragged: [URL] = []
    private var selected = 0
    private var accessibilityButtons: [RadialAccessibilityButton] = []
    init(model: AppModel) { self.model = model; super.init(frame: NSRect(x: 0,y: 0,width: 320,height: 320)); registerForDraggedTypes([.fileURL]); configure([]) }
    required init?(coder: NSCoder) { nil }
    override var acceptsFirstResponder: Bool { true }
    func refreshSelection() { configure(dragged.isEmpty ? model.files : dragged) }
    func configure(_ urls: [URL]) {
        let image: Set<String> = ["jpg","jpeg","png","heic","tif","tiff","bmp","webp"], pdf: Set<String> = ["pdf"]
        let video: Set<String> = ["mp4","mov","mkv","avi","webm","m4v"], audio: Set<String> = ["mp3","m4a","wav","flac","aiff","aac","ogg","opus"]
        let exts = Set(urls.map { $0.pathExtension.lowercased() })
        func action(_ tool: ToolID, _ extensions: Set<String>) -> Action { Action(title: tr("tool." + tool.rawValue), command: .recipe(Recipe(name: tr("tool." + tool.rawValue), steps: [ToolStep(tool: tool)])), extensions: extensions) }
        var next: [Action] = []
        if urls.isEmpty || !exts.isDisjoint(with: image) {
            next += ImageFormat.available.map { format in
                var step = ToolStep(tool: .image); step.image = model.options; step.image.format = format
                return Action(title: format.rawValue.uppercased(), command: .recipe(Recipe(name: format.rawValue.uppercased(), steps: [step])), extensions: image)
            }
        }
        if !exts.isDisjoint(with: pdf) { next += [.pdfText, .pdfImages, .pdfSplit, .pdfCompress].map { action($0, pdf) } }
        if !exts.isDisjoint(with: video) { next += [.videoMP4, .videoGIF, .audioM4A].map { action($0, video) } }
        if !exts.isDisjoint(with: audio) { next += [.audioM4A, .audioWAV, .audioFLAC, .mediaInspect].map { action($0, audio) } }
        if exts.contains("json") { next += [.jsonPretty, .jsonMinify, .jsonYAML, .jsonCSV].map { action($0, ["json"]) } }
        if exts.contains("csv") { next += [.csvJSON, .csvTSV].map { action($0, ["csv"]) } }
        if exts.contains("zip") { next.append(action(.zipExtract, ["zip"])) }
        if exts.contains("yaml") || exts.contains("yml") { next.append(action(.yamlJSON, ["yaml","yml"])) }
        if exts.contains("tsv") { next.append(action(.tsvCSV, ["tsv"])) }
        if exts.contains("md") || exts.contains("markdown") { next += [.markdownHTML,.markdownPDF].map { action($0,["md","markdown"]) } }
        if next.isEmpty { next = [action(.zipCreate, exts), action(.tarCreate, exts)] }
        if mode == .edit {
            next = []
            if urls.isEmpty || !exts.isDisjoint(with: image) { next.append(Action(title: tr("studio.image"), command: .editor(.image), extensions: image)) }
            if urls.isEmpty || !exts.isDisjoint(with: pdf) { next.append(Action(title: tr("studio.pdf"), command: .editor(.pdf), extensions: pdf)) }
            if urls.isEmpty || !exts.isDisjoint(with: video.union(audio)) { next.append(Action(title: tr("studio.media"), command: .editor(.media), extensions: video.union(audio))) }
            if urls.isEmpty || !exts.isDisjoint(with: image.union(pdf).union(video).union(audio)) { next.append(Action(title: tr("studio.compress"), command: .editor(.compress), extensions: image.union(pdf).union(video).union(audio))) }
            next.append(Action(title:tr("rename"),command:.editor(.folders),extensions:exts))
        }
        if mode == .files { next = FileAction.allCases.map { Action(title: tr("action." + $0.rawValue), command: .file($0), extensions: exts) } }
        if configuration.favoritesFirst && mode == .convert {
            let categories = Set(exts.map { ext -> String in
                if image.contains(ext) { return "image" }; if pdf.contains(ext) { return "pdf" }
                if video.contains(ext) { return "video" }; if audio.contains(ext) { return "audio" }
                if ["json","yaml","csv","tsv"].contains(ext) { return ext }
                if ["yml"].contains(ext) { return "yaml" }; if ["md","markdown"].contains(ext) { return "markdown" }
                if ["zip","tar","gz"].contains(ext) { return "archive" }; return "text"
            })
            let matching = favorites.filter { recipe in
                guard let first = recipe.steps.first else { return false }
                return urls.isEmpty || categories.isSubset(of: OperationRegistry.inputs(first.tool))
            }.map { Action(title: $0.name, command: .recipe($0), extensions: exts) }
            next = matching + next
        }
        actions = Array(next.prefix(6)); selected = min(selected, actions.count-1)
        accessibilityButtons = actions.enumerated().map { i, item in
            let element = RadialAccessibilityButton { [weak self] in self?.execute(i, files: self?.model.files ?? []) }
            element.setAccessibilityRole(.button); element.setAccessibilityLabel(item.title); element.setAccessibilityEnabled(!urls.isEmpty)
            element.setAccessibilityParent(self); return element
        }
        setAccessibilityElement(false); setAccessibilityChildren(accessibilityButtons); needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        let center = NSPoint(x: bounds.midX,y: bounds.midY), radius = min(bounds.width,bounds.height)/2-10
        let innerRadius = radius * 0.36
        for (i, action) in actions.enumerated() {
            let start = Double(i)*360/Double(actions.count)+2, end = Double(i+1)*360/Double(actions.count)-2
            let path = NSBezierPath(); path.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end)
            path.appendArc(withCenter: center, radius: innerRadius, startAngle: end, endAngle: start, clockwise: true); path.close()
            (selected == i ? configuration.accent.nsColor : NSColor.controlBackgroundColor).setFill(); path.fill()
            NSColor.separatorColor.setStroke(); path.lineWidth = 1; path.stroke()
            let angle = (start+end)/2 * .pi/180
            let point = NSPoint(x: center.x+cos(angle)*(radius+innerRadius)/2,y: center.y+sin(angle)*(radius+innerRadius)/2)
            let rect = NSRect(x: point.x-43,y: point.y-20,width: 86,height: 40)
            let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
            if configuration.showLabels { action.title.draw(in: rect, withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: selected == i ? NSColor.black : NSColor.labelColor, .paragraphStyle: paragraph]) }
            accessibilityButtons[i].setAccessibilityFrameInParentSpace(rect)
        }
        let centerSize = innerRadius * 1.76
        let circle = NSBezierPath(ovalIn: NSRect(x: center.x-centerSize/2,y: center.y-centerSize/2,width:centerSize,height:centerSize)); NSColor.windowBackgroundColor.setFill(); circle.fill()
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
        let count = dragged.isEmpty ? model.files.count : dragged.count
        let title = count == 0 ? tr("widget.drop") : (configuration.showLabels ? "\(count) " + tr("files.short") : (actions.indices.contains(selected) ? actions[selected].title : "FluxDrop"))
        title.draw(in: NSRect(x:center.x-centerSize/2+3,y:center.y-16,width:centerSize-6,height:34), withAttributes:[.font:NSFont.systemFont(ofSize:11,weight:.medium),.foregroundColor:NSColor.labelColor,.paragraphStyle:paragraph])
    }
    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: bounds, options: [.mouseMoved,.activeAlways,.inVisibleRect], owner: self)
        if let tracking { addTrackingArea(tracking) }; super.updateTrackingAreas()
    }
    override func mouseMoved(with event: NSEvent) { if let i = index(convert(event.locationInWindow,from:nil)) { selected = i; needsDisplay = true } }
    override func rightMouseDown(with event: NSEvent) { PanelController.shared.hide() }
    private func index(_ location: NSPoint) -> Int? {
        let dx = location.x-bounds.midX, dy = location.y-bounds.midY, r = hypot(dx,dy)
        guard r > (min(bounds.width,bounds.height)/2-10)*0.36, r < min(bounds.width,bounds.height)/2 else { return nil }
        var angle = atan2(dy,dx); if angle < 0 { angle += 2 * .pi }
        return min(actions.count-1, Int(angle/(2 * .pi)*Double(actions.count)))
    }
    private func urls(_ info: NSDraggingInfo) -> [URL] { (info.draggingPasteboard.readObjects(forClasses:[NSURL.self],options:[.urlReadingFileURLsOnly:true]) as? [URL]) ?? [] }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { dragged = urls(sender); configure(dragged); return dragged.isEmpty ? [] : .copy }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let index = index(convert(sender.draggingLocation, from:nil)) else { return [] }; selected = index; needsDisplay = true; return .copy
    }
    override func draggingExited(_ sender: NSDraggingInfo?) { dragged = []; configure(model.files) }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { index(convert(sender.draggingLocation, from:nil)) != nil }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let index = index(convert(sender.draggingLocation, from:nil)) else { return false }
        execute(index, files: urls(sender)); dragged = []; return true
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if let i = index(convert(event.locationInWindow,from:nil)) { selected = i; execute(i,files:model.files); needsDisplay = true }
        else if model.files.isEmpty { model.addFiles(); PanelController.shared.show(activate: true) }
    }
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: PanelController.shared.hide()
        case 123,126: selected = (selected+actions.count-1)%actions.count; needsDisplay = true
        case 124,125: selected = (selected+1)%actions.count; needsDisplay = true
        case 36: execute(selected, files:model.files)
        default: super.keyDown(with:event)
        }
    }
    private func execute(_ index: Int, files: [URL]) {
        guard !files.isEmpty, actions.indices.contains(index) else { return }
        let action = actions[index]
        switch action.command {
        case .file(let operation):
            FileActionController.shared.execute(operation, files: files, anchor: self)
            // Sharing picker and move review need their source panel to remain alive.
            if configuration.closeAfterAction && [.copy,.copyPaths,.shelf,.terminal].contains(operation) { PanelController.shared.hide() }
        case .editor(let kind):
            // The editor shows the exact input and explicitly applies to the displayed file.
            model.add(files); EditorController.shared.show(kind, files: files)
        case .recipe(let recipe):
            if recipe.steps.contains(where: { [.zipCreate,.tarCreate,.pdfMerge,.imagesPDF,.audioJoin].contains($0.tool) }) { model.queue.enqueue(files,directory:model.directory,recipe:recipe) }
            else { for file in files { model.queue.enqueue([file],directory:model.directory,recipe:recipe) } }
            model.files = []
            if configuration.closeAfterAction { PanelController.shared.hide() }
        }

    }
}
@MainActor final class RadialAccessibilityButton: NSAccessibilityElement {
    nonisolated let onPress: @MainActor @Sendable () -> Void
    init(onPress: @escaping @MainActor @Sendable () -> Void) { self.onPress = onPress; super.init() }
    nonisolated override func accessibilityPerformPress() -> Bool {
        let action = onPress
        Task { @MainActor in action() }
        return true
    }
}
