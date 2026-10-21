import SwiftUI
import AppKit
import FluxCore

struct RecipesView: View {
    @Bindable var model: AppModel
    @Bindable var library: LibraryStore
    @State private var name = ""
    @State private var draft: [ToolStep] = []
    @State private var step = ToolStep(tool: .image)
    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(tr("recipe.create")).font(.title2.bold())
                    TextField(tr("preset.name"), text: $name)
                    Picker(tr("operation"), selection: $step.tool) { ForEach(ToolID.allCases, id: \.self) { Text(tr("tool." + $0.rawValue)).tag($0) } }
                    StepOptions(step: $step)
                    Button(tr("recipe.addStep")) { draft.append(step) }.disabled(draft.count >= 12)
                    ForEach(Array(draft.enumerated()), id: \.offset) { index, item in Text("\(index+1). " + tr("tool." + item.tool.rawValue)) }
                    HStack {
                        Button(tr("undo")) { if !draft.isEmpty { draft.removeLast() } }.disabled(draft.isEmpty)
                        Button(tr("preset.save")) { library.add(Recipe(name: name, steps: draft)); if library.error == nil { draft = []; name = "" } }.disabled(draft.isEmpty || name.isEmpty)
                    }
                    Text(tr("recipe.note")).font(.caption)
                }.padding(24)
            }.frame(minWidth: 360)
            VStack(alignment: .leading, spacing: 16) {
                HStack { Text(tr("recipes")).font(.title2.bold()); Spacer(); Button(tr("import")) { library.importRecipe() } }
                SelectionView(model: model)
                Button(tr("folder.images")) {
                    let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true
                    if presentFileDialog(panel) == .OK, let folder = panel.url {
                        do {
                            let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                            let images = files.filter { ["jpg","jpeg","png","heic","tif","tiff","bmp","webp"].contains($0.pathExtension.lowercased()) }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                            model.add(images); library.error = tr("folder.filtered") + " \(files.count-images.count)"
                        } catch { library.error = tr("error.unreadable") }
                    }
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(library.recipes) { recipe in
                            VStack(alignment: .leading) {
                                Text(recipe.name).font(.headline)
                                Text(recipe.steps.map { tr("tool." + $0.tool.rawValue) }.joined(separator: " → ")).font(.caption)
                                HStack {
                                    Button(tr("run")) { model.queue.enqueue(model.files, directory: model.directory, recipe: recipe); model.files = [] }.disabled(model.files.isEmpty)
                                    Button(tr("export")) { library.export(recipe) }
                                    Button { if let i = library.recipes.firstIndex(where: { $0.id == recipe.id }) { library.recipes[i].favorite.toggle(); library.save() } } label: { Image(systemName: recipe.favorite ? "star.fill" : "star") }.accessibilityLabel(tr("favorite"))
                                    Button(tr("remove")) { library.recipes.removeAll { $0.id == recipe.id }; library.save() }
                                }
                            }.padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                if let error = library.error { Text(error).foregroundStyle(.red); Button("OK") { library.error = nil } }
            }.padding(24).frame(minWidth: 400)
        }
    }
}
struct WatchesView: View {
    @Bindable var model: AppModel
    @Bindable var library: LibraryStore
    @State private var selected: UUID?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tr("watches")).font(.largeTitle.bold())
            Text(tr("watch.note")).foregroundStyle(.secondary)
            Picker(tr("recipes"), selection: $selected) { Text(tr("choose")).tag(nil as UUID?); ForEach(library.recipes) { Text($0.name).tag(Optional($0.id)) } }
            HStack { Button(tr("destination.choose")) { model.chooseDestination() }; Text(model.directory.path).font(.caption) }
            Button(tr("watch.add")) { add() }.disabled(selected == nil)
            List {
                ForEach(library.watches) { rule in
                    VStack(alignment: .leading) {
                        Text(rule.source.path).font(.headline); Text("→ " + rule.destination.path).font(.caption)
                        Text(rule.recipe.name)
                        Text(library.watchMessages[rule.id] ?? tr(rule.enabled ? "watch.waiting" : "watch.paused")).font(.caption)
                        HStack {
                            Button(tr(rule.enabled ? "queue.pause" : "queue.resume")) { if let i = library.watches.firstIndex(where: { $0.id == rule.id }) { library.watches[i].enabled.toggle(); library.save() } }
                            Button(tr("remove")) { library.watches.removeAll { $0.id == rule.id }; library.save() }
                        }
                    }
                }
            }
            if let error = library.error { Text(error).foregroundStyle(.red) }
        }.padding(24)
    }
    private func add() {
        guard let recipe = library.recipes.first(where: { $0.id == selected }) else { return }
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true
        guard presentFileDialog(panel) == .OK, let source = panel.url else { return }
        do { library.watches.append(try WatchRule(source: source, destination: model.directory, recipe: recipe)); library.save() }
        catch { library.error = tr("watch.invalid") }
    }
}
struct FoldersView: View {
    @Bindable var model: AppModel
    @State private var options = RenameOptions()
    @State private var plan: [RenameItem] = []
    @State private var groups: [DuplicateGroup] = []
    @State private var selected = Set<URL>()
    @State private var busy = false
    @State private var message = ""
    @State private var confirmTrash = false
    private let engine = FolderEngine()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(tr("folders")).font(.largeTitle.bold())
                SelectionView(model: model)
                Button(tr("folder.addContents")) { addContents() }
                Divider(); Text(tr("rename")).font(.title2.bold())
                HStack { TextField(tr("prefix"), text: $options.prefix); TextField(tr("suffix"), text: $options.suffix) }
                HStack { TextField(tr("find"), text: $options.find); TextField(tr("replace"), text: $options.replace) }
                Toggle(tr("numbering"), isOn: $options.number)
                Button(tr("rename.preview")) { perform { plan = try await engine.plan(model.files, options: options) } }.disabled(busy || model.files.isEmpty)
                ForEach(plan) { item in Text(item.source.lastPathComponent + " → " + item.destination.lastPathComponent).font(.caption) }
                Button(tr("rename.apply")) { perform { try await engine.rename(plan); model.files = plan.map(\.destination); plan = []; message = tr("done") } }.disabled(busy || plan.isEmpty)
                Divider(); Text(tr("duplicates")).font(.title2.bold())
                Button(tr("duplicates.scan")) { perform { groups = try await engine.duplicates(model.files); selected = []; message = groups.isEmpty ? tr("duplicates.none") : "" } }.disabled(busy)
                ForEach(groups) { group in
                    VStack(alignment: .leading) {
                        Text(ByteCountFormatter.string(fromByteCount: group.bytes, countStyle: .file)).font(.headline)
                        ForEach(group.files, id: \.self) { file in
                            Toggle(file.path, isOn: Binding(get: { selected.contains(file) }, set: { if $0 { selected.insert(file) } else { selected.remove(file) } }))
                        }
                    }
                }
                Button(tr("duplicates.trash")) { confirmTrash = true }.disabled(busy || selected.isEmpty)
                Divider(); Text(tr("organize")).font(.title2.bold()); Text(tr("organize.note")).font(.caption)
                Button(tr("organize.copy")) { perform { let result = try await engine.organize(model.files, directory: model.directory); NSWorkspace.shared.activateFileViewerSelecting([result]); message = tr("done") } }.disabled(busy || model.files.isEmpty)
                if busy { ProgressView() }; if !message.isEmpty { Text(message) }
            }.padding(24)
        }
        .confirmationDialog(tr("duplicates.confirm"), isPresented: $confirmTrash) {
            Button(tr("duplicates.trash"), role: .destructive) { perform { try await engine.trash(selected, groups: groups); model.files.removeAll { selected.contains($0) }; groups = []; selected = []; message = tr("done") } }
        }
    }
    private func perform(_ work: @escaping @MainActor () async throws -> Void) {
        busy = true; message = ""
        Task { do { try await work() } catch { message = tr("error." + ((error as? EngineFailure)?.rawValue ?? "unknown")) }; busy = false }
    }
    private func addContents() {
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true
        guard presentFileDialog(panel) == .OK, let url = panel.url else { return }
        do { model.add(try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])); plan = [] }
        catch { message = tr("error.unreadable") }
    }
}
