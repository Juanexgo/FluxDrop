import SwiftUI
import AppKit
import FluxCore

@main struct FluxDropApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        WindowGroup("FluxDrop", id: "main") { WorkspaceView(model: .shared).frame(minWidth: 900, minHeight: 640).tint(.orange).toolbar { Button(tr("panel.open")) { PanelController.shared.show(activate: true) } } }
        Settings { PreferencesView(model: .shared) }
        MenuBarExtra("FluxDrop", systemImage: "drop.circle.fill") { MenuContent(model: .shared) }
    }
}
struct MenuContent: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button(tr("panel.open")) { PanelController.shared.show(activate: true) }
        Button(tr("files.add")) { model.addFiles() }
        Button(tr("window.open")) { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
        Divider()
        Button(tr(model.queue.paused ? "queue.resume" : "queue.pause")) { model.queue.setPaused(!model.queue.paused) }
        Menu(tr("jobs.recent")) {
            ForEach(model.queue.jobs.suffix(5).reversed()) { job in
                Button(job.input.lastPathComponent + " · " + tr("state." + job.state.rawValue)) {
                    if let url = job.output, FileManager.default.fileExists(atPath: url.path) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                }.disabled(job.output == nil)
            }
        }
        Menu(tr("favorites")) {
            ForEach(LibraryStore.shared.recipes.filter(\.favorite)) { recipe in
                Button(recipe.name) { model.queue.enqueue(model.files, directory: model.directory, recipe: recipe); model.files = [] }.disabled(model.files.isEmpty)
            }
        }
        SettingsLink { Text(tr("preferences")) }
        if WidgetPreferences.shared.configuration.rightClickEnabled { Button(tr("widget.disableRightClick")) { WidgetPreferences.shared.configuration.rightClickEnabled = false } }
        if WidgetPreferences.shared.configuration.dragSettings.enabled { Button(tr("drag.disable")) { WidgetPreferences.shared.configuration.dragSettings.enabled = false } }
        Divider(); Button(tr("quit")) { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
struct OutputOptions: View {
    @Bindable var model: AppModel
    var body: some View {
        Picker(tr("format"), selection: $model.options.format) { ForEach(ImageFormat.available, id: \.self) { Text($0.rawValue.uppercased()).tag($0) } }
        Picker(tr("resize"), selection: $model.options.maxPixel) {
            Text(tr("size.original")).tag(0)
            ForEach([512, 1024, 2048, 4096], id: \.self) { Text("\($0) px").tag($0) }
        }
        HStack { Text(tr("quality")); Slider(value: $model.options.quality, in: 0.1...1).accessibilityLabel(tr("quality")); Text(model.options.quality, format: .percent.precision(.fractionLength(0))).monospacedDigit() }
        Text(tr("export.note")).font(.caption).foregroundStyle(.secondary)
        Button(tr("destination.choose")) { model.chooseDestination() }
        Text(model.directory.path).font(.caption).foregroundStyle(.secondary).lineLimit(2).textSelection(.enabled)
    }
}
struct MainView: View {
    @Bindable var model: AppModel
    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 16) {
                ScrollView { VStack(alignment: .leading, spacing: 16) {
                Label("FluxDrop", systemImage: "drop.circle.fill").font(.largeTitle.bold()).foregroundStyle(.orange)
                Text(tr("tagline")).foregroundStyle(.secondary)
                DropTarget(title: tr("files.drop")) { model.add($0) }.frame(height: 74)
                HStack {
                    Button(tr("files.add")) { model.addFiles() }.keyboardShortcut("o")
                    Button(tr("files.clear")) { model.files = [] }.disabled(model.files.isEmpty)
                }
                ScrollView {
                    LazyVStack(alignment: .leading) {
                        ForEach(model.files, id: \.self) { url in Label(url.lastPathComponent, systemImage: "photo").lineLimit(1).help(url.path) }
                    }
                }.frame(height: 100)
                OutputOptions(model: model)
                Text(tr("image.advanced.note")).font(.caption).foregroundStyle(.secondary)
                } }
                Button(tr("convert")) { model.run() }.buttonStyle(.borderedProminent).disabled(model.files.isEmpty).keyboardShortcut(.return, modifiers: .command)
            }.padding(24).frame(minWidth: 310, idealWidth: 340, maxWidth: 400)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(tr("queue")).font(.title2.bold()); Spacer()
                    Button(tr(model.queue.paused ? "queue.resume" : "queue.pause")) { model.queue.setPaused(!model.queue.paused) }
                }
                Text(tr("queue.note")).font(.caption).foregroundStyle(.secondary)
                if model.queue.jobs.isEmpty { ContentUnavailableView(tr("queue.empty"), systemImage: "tray", description: Text(tr("queue.empty.hint"))) }
                ScrollView {
                    LazyVStack(spacing: 10) { ForEach(model.queue.jobs.reversed()) { JobRow(job: $0, queue: model.queue) } }
                }
                HStack {
                    Button(tr("queue.cancelAll")) { model.queue.cancelAll() }
                    Button(tr("history.clear")) { model.queue.clearFinished() }
                }
                if model.queue.persistenceFailed { Text(tr("journal.error")).foregroundStyle(.red) }
            }.padding(24).frame(minWidth: 380)
        }
        .alert(tr("notice"), isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) { Button("OK") { model.message = nil } } message: { Text(model.message ?? "") }
    }
}
struct JobRow: View {
    let job: Job
    let queue: JobQueue
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Text(job.input.lastPathComponent).lineLimit(1); Spacer(); if job.state == .running { if let progress = job.progress { ProgressView(value: progress).frame(width: 70) } else { ProgressView().controlSize(.small) } } }
            Text(tr("state." + job.state.rawValue)).font(.caption).foregroundStyle(job.state == .failed ? .red : .secondary)
            if let failure = job.failure { Text(tr("error." + failure.rawValue)).font(.caption).foregroundStyle(.red) }
            if let url = job.output {
                Text(url.lastPathComponent).font(.caption).textSelection(.enabled)
                if FileManager.default.fileExists(atPath: url.path) {
                    HStack {
                        Button(tr("finder.reveal")) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                        Text(tr("result.drag")).font(.caption).onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
                    }
                } else { Text(tr("result.missing")).font(.caption) }
            }
            if [.pending, .running].contains(job.state) { Button(tr("cancel")) { queue.cancel(job.id) } }
            if [.failed, .cancelled, .interrupted].contains(job.state) { Button(tr("retry")) { queue.retry(job.id) } }
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}
struct PreferencesView: View {
    @Bindable var model: AppModel
    var body: some View {
        TabView {
            ScrollView { WidgetSettingsView().padding(24) }.tabItem { Label(tr("widget.title"), systemImage: "circle.hexagongrid") }
            ScrollView { Form {
                Picker(tr("shortcut"), selection: $model.shortcut) { Text("⌃⌥D").tag(0); Text("⌃⌥K").tag(1); Text("⌃⌥Space").tag(2) }
                    .onChange(of: model.shortcut) { ShortcutController.shared.install(choice: model.shortcut) }
                Text(tr("shortcut.note")).font(.caption)
                Toggle(tr("history.keep"), isOn: Binding(get: { model.queue.keepHistory }, set: { model.queue.keepHistory = $0; UserDefaults.standard.set(!$0, forKey: "disableHistory") }))
                SystemOptions()
                Text(tr("privacy.note")).font(.caption)
                Text(tr("licenses.summary")).font(.caption).foregroundStyle(.secondary)
                Button(tr("licenses.open")) {
                    if let resources = Bundle.main.resourceURL { NSWorkspace.shared.open(resources.appendingPathComponent("ThirdParty")) }
                }
            }.padding(24) }.tabItem { Label(tr("preferences.general"), systemImage: "gearshape") }
        }.frame(width: 560, height: 620).tint(.orange)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in GlobalRightClick.shared.configure(WidgetPreferences.shared.configuration); DragActivation.shared.configure(WidgetPreferences.shared.configuration.dragSettings) }
        .alert(tr("notice"), isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) { Button("OK") { model.message = nil } } message: { Text(model.message ?? "") }
    }
}
