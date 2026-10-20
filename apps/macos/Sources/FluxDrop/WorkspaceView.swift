import SwiftUI
import AppKit
import FluxCore
import QuickLookUI
import ServiceManagement
import UserNotifications

struct WorkspaceView: View {
    @Bindable var model: AppModel
    var body: some View {
        TabView {
            MainView(model: model).tabItem { Label(tr("category.image"), systemImage: "photo") }
            ToolsView(model: model).tabItem { Label(tr("tools"), systemImage: "slider.horizontal.3") }
            RecipesView(model: model, library: .shared).tabItem { Label(tr("recipes"), systemImage: "square.stack.3d.up") }
            FoldersView(model: model).tabItem { Label(tr("folders"), systemImage: "folder") }
            WatchesView(model: model, library: .shared).tabItem { Label(tr("watches"), systemImage: "eye") }
        }.frame(minWidth: 900, minHeight: 640)
    }
}
struct SelectionView: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Button(tr("files.add")) { model.addFiles() }; Button(tr("files.clear")) { model.files = [] }; Text("\(model.files.count)").monospacedDigit() }
            DropTarget(title: tr("files.drop.any")) { model.add($0) }.frame(height: 52)
            ScrollView { LazyVStack(alignment: .leading) {
                ForEach(model.files, id: \.self) { url in
                    HStack {
                        Text(url.lastPathComponent).lineLimit(1); Spacer()
                        Button { if let index = model.files.firstIndex(of: url), index > 0 { model.files.swapAt(index,index-1) } } label: { Image(systemName: "arrow.up") }.accessibilityLabel(tr("move.up"))
                        Button { if let index = model.files.firstIndex(of: url), index+1 < model.files.count { model.files.swapAt(index,index+1) } } label: { Image(systemName: "arrow.down") }.accessibilityLabel(tr("move.down"))
                        Button { PreviewController.shared.show(url) } label: { Image(systemName: "eye") }.accessibilityLabel(tr("preview"))
                    }
                }
            } }.frame(height: 110)
            Button(tr("destination.choose")) { model.chooseDestination() }
            Text(model.directory.path).font(.caption).textSelection(.enabled)
        }
    }
}
struct ToolsView: View {
    @Bindable var model: AppModel
    @State private var step = ToolStep(tool: .pdfMerge)
    @State private var password = ""
    @State private var presetName = ""
    @State private var search = ""
    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(tr("tools")).font(.title.bold())
                    SelectionView(model: model)
                    TextField(tr("actions.search"), text: $search)
                    Picker(tr("operation"), selection: $step.tool) {
                        ForEach(ToolID.allCases.filter { search.isEmpty || tr("tool." + $0.rawValue).localizedCaseInsensitiveContains(search) }, id: \.self) { Text(tr("tool." + $0.rawValue)).tag($0) }
                    }
                    Text(tr("accepts") + " " + OperationRegistry.inputs(step.tool).sorted().map { tr("category." + $0) }.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                    Text(tr("mixed.note")).font(.caption).foregroundStyle(.secondary)
                    StepOptions(step: $step)
                    if step.tool.category == "pdf", step.tool != .imagesPDF { SecureField(tr("pdf.password"), text: $password) }
                    Button(tr("run")) { run() }.buttonStyle(.borderedProminent).disabled(model.files.isEmpty)
                    Divider()
                    TextField(tr("preset.name"), text: $presetName)
                    Button(tr("preset.save")) { LibraryStore.shared.add(Recipe(name: presetName, steps: [step])); presetName = "" }.disabled(presetName.isEmpty)
                }.padding(24)
            }.frame(minWidth: 400, idealWidth: 460)
            QueueView(queue: model.queue).frame(minWidth: 340)
        }
    }
    private func run() {
        let recipe = Recipe(name: tr("tool." + step.tool.rawValue), steps: [step])
        let grouped: Set<ToolID> = [.pdfMerge, .imagesPDF, .audioJoin, .zipCreate, .tarCreate]
        if grouped.contains(step.tool) { model.queue.enqueue(model.files, directory: model.directory, recipe: recipe, password: password) }
        else { for url in model.files { model.queue.enqueue([url], directory: model.directory, recipe: recipe, password: password) } }
        password = ""; model.files = []
    }
}
struct QueueView: View {
    let queue: JobQueue
    var body: some View {
        VStack(alignment: .leading) {
            HStack { Text(tr("queue")).font(.title2.bold()); Spacer(); Button(tr(queue.paused ? "queue.resume" : "queue.pause")) { queue.setPaused(!queue.paused) } }
            ScrollView { LazyVStack { ForEach(queue.jobs.reversed()) { JobRow(job: $0, queue: queue) } } }
            HStack { Button(tr("queue.cancelAll")) { queue.cancelAll() }; Button(tr("history.clear")) { queue.clearFinished() } }
        }.padding(24)
    }
}
struct StepOptions: View {
    @Binding var step: ToolStep
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if step.tool == .renameCopy {
                TextField(tr("prefix"), text: Binding(get: { step.renamePrefix ?? "" }, set: { step.renamePrefix = $0 }))
                TextField(tr("suffix"), text: Binding(get: { step.renameSuffix ?? "" }, set: { step.renameSuffix = $0 }))
                Toggle(tr("numbering"), isOn: Binding(get: { step.renameNumber ?? false }, set: { step.renameNumber = $0 }))
            }
            if step.tool == .image { ImageEditOptions(options: $step.image) }
            if step.tool == .imageIcons { Text(tr("icons.note")).font(.caption) }
            if step.tool.category == "pdf" {
                if step.tool != .imagesPDF { TextField(tr("pdf.pages"), text: $step.pages) }
                if step.tool == .pdfRotate { Picker(tr("rotation"), selection: $step.rotation) { Text("90°").tag(90); Text("180°").tag(180); Text("270°").tag(270) } }
                if [.pdfImages, .pdfOCR, .pdfCompress].contains(step.tool) {
                    Picker("DPI", selection: $step.dpi) { ForEach([72, 96, 144, 200, 300], id: \.self) { Text("\($0)").tag($0) } }
                }
                if step.tool == .pdfCompress { Text(tr("pdf.compress.note")).font(.caption); Slider(value: $step.image.quality, in: 0.2...1).accessibilityLabel(tr("quality")) }
                if step.tool == .pdfExtract { Text(tr("pdf.reorder.note")).font(.caption) }
            }
            if step.tool.category == "media" && step.tool != .mediaInspect {
                HStack { TextField(tr("media.start"), value: $step.start, format: .number); TextField(tr("media.duration"), value: $step.duration, format: .number) }
                if [.videoMP4, .videoMOV, .videoGIF].contains(step.tool) {
                    Picker(tr("media.width"), selection: $step.width) { ForEach([480, 640, 1280, 1920, 3840], id: \.self) { Text("\($0) px").tag($0) } }
                    if step.tool == .videoGIF { Stepper("FPS: \(step.fps)", value: $step.fps, in: 1...30); Text(tr("gif.note")).font(.caption) }
                    else {
                        TextField(tr("media.bitrate"), value: $step.bitrate, format: .number)
                        TextField(tr("media.target"), value: $step.targetMB, format: .number)
                        Toggle(tr("media.mute"), isOn: $step.mute)
                        HStack { Button(tr("media.subtitle")) { chooseSubtitle() }; if step.subtitle != nil { Button(tr("remove")) { step.subtitle = nil } } }
                        if let subtitle = step.subtitle { Text(subtitle.lastPathComponent).font(.caption) }
                    }
                }
                TextField(tr("audio.bitrate"), value: $step.audioBitrate, format: .number)
                Toggle(tr("media.normalize"), isOn: $step.normalize)
                Toggle(tr("metadata.strip"), isOn: $step.stripMetadata)
                Text(tr("media.note")).font(.caption).foregroundStyle(.secondary)
                if step.tool == .audioJoin { Text(tr("audio.join.note")).font(.caption) }
            }
            if step.tool.category == "data" {
                Picker(tr("encoding"), selection: $step.encoding) { Text("UTF-8").tag("utf8"); Text("UTF-16").tag("utf16"); Text("ISO-8859-1").tag("latin1") }
                if [.csvJSON, .jsonCSV, .csvTSV, .tsvCSV].contains(step.tool) {
                    TextField(tr("delimiter"), text: $step.delimiter); Toggle(tr("headers"), isOn: $step.headers)
                    Text(tr("csv.note")).font(.caption)
                }
                if [.markdownHTML, .markdownPDF].contains(step.tool) { Text(tr("markdown.note")).font(.caption) }
                if [.jsonYAML, .yamlJSON].contains(step.tool) { Text(tr("yaml.note")).font(.caption) }
            }
            if step.tool.category == "archive" { Text(tr("archive.note")).font(.caption) }
        }
    }
    private func chooseSubtitle() { let panel = NSOpenPanel(); panel.canChooseFiles = true; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false; panel.allowedContentTypes = []; panel.allowsOtherFileTypes = true; if presentFileDialog(panel) == .OK { step.subtitle = panel.url } }
}
struct ImageEditOptions: View {
    @Binding var options: ImageOptions
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(tr("format"), selection: $options.format) { ForEach(ImageFormat.available, id: \.self) { Text($0.rawValue.uppercased()).tag($0) } }
            TextField(tr("resize.zero"), value: $options.maxPixel, format: .number)
            Slider(value: $options.quality, in: 0.1...1).accessibilityLabel(tr("quality"))
            Picker(tr("rotation"), selection: $options.rotation) { ForEach([0,90,180,270], id: \.self) { Text("\($0)°").tag($0) } }
            Toggle(tr("flip.horizontal"), isOn: $options.flipHorizontal); Toggle(tr("flip.vertical"), isOn: $options.flipVertical)
            Text(tr("crop.note")).font(.caption)
            HStack { TextField("X", value: $options.cropX, format: .number); TextField("Y", value: $options.cropY, format: .number) }
            HStack { TextField(tr("crop.width"), value: $options.cropWidth, format: .number); TextField(tr("crop.height"), value: $options.cropHeight, format: .number) }
            Toggle(tr("metadata.strip"), isOn: $options.stripMetadata)
            TextField(tr("watermark.text"), text: $options.watermark)
            HStack {
                Button(tr("watermark.image")) { let p = NSOpenPanel(); p.canChooseFiles = true; p.canChooseDirectories = false; p.allowsMultipleSelection = false; p.allowedContentTypes = [.image]; p.allowsOtherFileTypes = false; if presentFileDialog(p) == .OK { options.watermarkImage = p.url } }
                if options.watermarkImage != nil { Button(tr("remove")) { options.watermarkImage = nil } }
            }
            if let url = options.watermarkImage { Text(url.lastPathComponent).font(.caption) }
        }
    }
}
@MainActor final class PreviewController: NSObject, @MainActor QLPreviewPanelDataSource {
    static let shared = PreviewController()
    private var url: URL?
    func show(_ url: URL) { self.url = url; let panel = QLPreviewPanel.shared(); panel?.dataSource = self; panel?.reloadData(); panel?.makeKeyAndOrderFront(nil) }
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { url == nil ? 0 : 1 }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! { url as NSURL? }
}

struct SystemOptions: View {
    @State private var notifications = UserDefaults.standard.bool(forKey: "notifications")
    @State private var login = SMAppService.mainApp.status == .enabled
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading) {
            Toggle(tr("notifications"), isOn: $notifications).onChange(of: notifications) {
                if notifications {
                    Task { do { let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]); notifications = granted; UserDefaults.standard.set(granted, forKey: "notifications") } catch { notifications = false; self.error = tr("system.error") } }
                } else { UserDefaults.standard.set(false, forKey: "notifications") }
            }
            Toggle(tr("login"), isOn: $login).onChange(of: login) {
                Task {
                    do { if login { try SMAppService.mainApp.register() } else { try await SMAppService.mainApp.unregister() } }
                    catch { self.error = tr("system.error"); login = SMAppService.mainApp.status == .enabled }
                }
            }
            if let error { Text(error).foregroundStyle(.red).font(.caption) }
        }
    }
}
@MainActor enum CompletionNotification {
    static func post(_ job: Job) {
        guard UserDefaults.standard.bool(forKey: "notifications") else { return }
        let content = UNMutableNotificationContent(); content.title = "FluxDrop"; content.body = tr("state." + job.state.rawValue)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: job.id.uuidString, content: content, trigger: nil))
    }
}
