import SwiftUI
import AppKit
import FluxCore

struct WidgetView: View {
    @Bindable var model: AppModel
    @Bindable var preferences = WidgetPreferences.shared
    @Bindable var library = LibraryStore.shared
    @Bindable var session = WheelSession.shared
    @Environment(\.openWindow) private var openWindow
    @State private var searchOpen = false
    @State private var query = ""
    var body: some View {
        let configuration = preferences.configuration
        VStack(spacing: 8) {
            Picker(tr("wheel.mode"), selection: $session.mode) { ForEach(WheelMode.allCases,id: \.self) { Text(tr("wheel." + $0.rawValue)).tag($0) } }
                .pickerStyle(.segmented).frame(width: configuration.diameter).accessibilityLabel(tr("wheel.mode"))
            RadialPanel(model: model, configuration: configuration, favorites: library.recipes.filter(\.favorite), mode: session.mode)
                .frame(width: configuration.diameter, height: configuration.diameter)
            HStack(spacing: 14) {
                Button { model.addFiles(); PanelController.shared.show(activate: true) } label: { Image(systemName: "plus") }.help(tr("files.add")).accessibilityLabel(tr("files.add"))
                Button { searchOpen.toggle() } label: { Image(systemName: "magnifyingglass") }.help(tr("actions.search")).accessibilityLabel(tr("actions.search"))
                    .popover(isPresented: $searchOpen) { search }
                Menu { ForEach(library.recipes.filter(\.favorite)) { recipe in
                    Button(recipe.name) { model.queue.enqueue(model.files, directory: model.directory, recipe: recipe); model.files = []; if configuration.closeAfterAction { PanelController.shared.hide() } }.disabled(model.files.isEmpty)
                } } label: { Image(systemName: "star") }.menuStyle(.borderlessButton).fixedSize().help(tr("favorites")).accessibilityLabel(tr("favorites"))
                SettingsLink { Image(systemName: "slider.horizontal.3") }.help(tr("widget.configure")).accessibilityLabel(tr("widget.configure"))
                Button { PanelController.shared.hide(); openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) } label: { Image(systemName: "macwindow") }.help(tr("window.open")).accessibilityLabel(tr("window.open"))
                Button { PanelController.shared.hide() } label: { Image(systemName: "xmark") }.help(tr("widget.hide")).accessibilityLabel(tr("widget.hide"))
            }.buttonStyle(.plain).font(.system(size: 12, weight: .semibold)).padding(.horizontal, 14).padding(.vertical, 10).background(.regularMaterial, in: Capsule())
            if configuration.showTriggerHint { Text(preferences.hint).font(.system(size: 10, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 5).background(.regularMaterial, in: Capsule()).accessibilityLabel(tr("widget.gesture") + ": " + preferences.hint) }
        }.padding(12).frame(width: configuration.diameter + 24, height: configuration.diameter + 108 + (configuration.showTriggerHint ? 24 : 0))
            .alert(tr("notice"), isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) { Button("OK") { model.message = nil } } message: { Text(model.message ?? "") }
            .tint(Color(configuration.accent.nsColor)).onExitCommand { PanelController.shared.hide() }
    }
    private var search: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(tr("actions.search"), text: $query).textFieldStyle(.roundedBorder)
            ScrollView { VStack(alignment: .leading, spacing: 10) {
                ForEach(ToolID.allCases.filter { query.isEmpty || tr("tool." + $0.rawValue).localizedCaseInsensitiveContains(query) }, id: \.self) { tool in
                    Button(tr("tool." + tool.rawValue)) {
                        model.queue.enqueue(model.files, directory: model.directory, recipe: Recipe(name: tr("tool." + tool.rawValue), steps: [ToolStep(tool: tool)])); model.files = []; searchOpen = false
                        if preferences.configuration.closeAfterAction { PanelController.shared.hide() }
                    }.disabled(model.files.isEmpty)
                }
            }.frame(maxWidth: .infinity, alignment: .leading) }
            Text(tr("widget.selectionNote")).font(.caption).foregroundStyle(.secondary)
        }.padding(16).frame(width: 300, height: 340)
    }
}
