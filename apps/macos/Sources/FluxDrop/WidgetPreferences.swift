import AppKit
import SwiftUI
import FluxCore

@MainActor @Observable final class WidgetPreferences {
    static let shared = WidgetPreferences()
    var configuration: FluxWidgetConfiguration {
        didSet {
            guard (try? configuration.validated()) != nil else { configuration = oldValue; return }
            if let data = try? JSONEncoder().encode(configuration) { UserDefaults.standard.set(data, forKey: "widget.settings.v1") }
            PanelController.shared.refresh(configuration)
            GlobalRightClick.shared.configure(configuration)
            DragActivation.shared.configure(configuration.dragSettings)
        }
    }
    private init() {
        if let data = UserDefaults.standard.data(forKey: "widget.settings.v1"),
           let value = try? JSONDecoder().decode(FluxWidgetConfiguration.self, from: data), let checked = try? value.validated() { configuration = checked }
        else { configuration = .init() }
    }
    var hint: String { configuration.rightClickEnabled ? tr("widget.trigger." + configuration.trigger.rawValue) : ["⌃⌥D", "⌃⌥K", "⌃⌥Space"][min(max(AppModel.shared.shortcut, 0), 2)] }
}
extension WidgetAccent {
    var nsColor: NSColor {
        switch self {
        case .coral: NSColor(calibratedRed: 1, green: 0.34, blue: 0.22, alpha: 1)
        case .orange: .systemOrange
        case .blue: .systemBlue
        case .green: .systemGreen
        case .violet: .systemPurple
        }
    }
}
struct WidgetSettingsView: View {
    @Bindable var preferences = WidgetPreferences.shared
    @Bindable var mouse = GlobalRightClick.shared
    @Bindable var drag = DragActivation.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(tr("widget.title")).font(.title2.bold())
            Text(tr("widget.description")).foregroundStyle(.secondary)
            GroupBox(tr("widget.appearance")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text(tr("widget.size")); Slider(value: $preferences.configuration.diameter, in: 240...400, step: 20).accessibilityLabel(tr("widget.size")); Text("\(Int(preferences.configuration.diameter)) pt").monospacedDigit() }
                    Picker(tr("widget.theme"), selection: $preferences.configuration.theme) { ForEach(WidgetTheme.allCases, id: \.self) { Text(tr("widget.theme." + $0.rawValue)).tag($0) } }
                    Picker(tr("widget.accent"), selection: $preferences.configuration.accent) { ForEach(WidgetAccent.allCases, id: \.self) { Text(tr("widget.accent." + $0.rawValue)).tag($0) } }
                    HStack { Text(tr("widget.opacity")); Slider(value: $preferences.configuration.opacity, in: 0.85...1).accessibilityLabel(tr("widget.opacity")); Text(preferences.configuration.opacity, format: .percent.precision(.fractionLength(0))) }
                    Toggle(tr("widget.labels"), isOn: $preferences.configuration.showLabels)
                    Toggle(tr("widget.hint"), isOn: $preferences.configuration.showTriggerHint)
                    Button(tr("widget.reset")) { preferences.configuration.resetAppearance() }
                }.padding(8)
            }
            GroupBox(tr("widget.activation")) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(tr("widget.rightClickEnabled"), isOn: $preferences.configuration.rightClickEnabled)
                    Picker(tr("widget.gesture"), selection: $preferences.configuration.trigger) { ForEach(WidgetTrigger.allCases, id: \.self) { Text(tr("widget.trigger." + $0.rawValue)).tag($0) } }
                    Text(tr("widget.contextNote")).font(.caption).foregroundStyle(.secondary)
                    Label(tr("widget.status." + mouse.status.rawValue), systemImage: mouse.status == .active ? "checkmark.circle.fill" : "info.circle").font(.caption).foregroundStyle(mouse.status == .active ? .green : .secondary)
                    if mouse.status == .permissionRequired {
                        Text(tr("widget.permissionNote")).font(.caption)
                        HStack { Button(tr("widget.requestPermission")) { mouse.requestPermission() }; Button(tr("widget.retry")) { mouse.configure(preferences.configuration) } }
                    }
                    if mouse.status == .unavailable { Button(tr("widget.retry")) { mouse.configure(preferences.configuration) } }
                }.padding(8)
            }
            GroupBox(tr("drag.title")) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(tr("drag.enabled"), isOn: $preferences.configuration.dragSettings.enabled)
                    dragPicker(.convert, $preferences.configuration.dragSettings.convertKey)
                    dragPicker(.edit, $preferences.configuration.dragSettings.editKey)
                    dragPicker(.files, $preferences.configuration.dragSettings.filesKey)
                    Text(tr("drag.note")).font(.caption).foregroundStyle(.secondary)
                    Label(tr(drag.active ? "drag.active" : (drag.permissionRequired ? "drag.permission" : "drag.inactive")), systemImage: drag.active ? "checkmark.circle" : "info.circle").font(.caption)
                    if drag.permissionRequired { Button(tr("widget.requestPermission")) { drag.requestPermission() } }
                    Button(tr("widget.retry")) { drag.configure(preferences.configuration.dragSettings) }
                }.padding(8)
            }
            Toggle(tr("widget.favoritesFirst"), isOn: $preferences.configuration.favoritesFirst)
            Toggle(tr("widget.closeAfterAction"), isOn: $preferences.configuration.closeAfterAction)
            HStack {
                Button(tr("widget.show")) { PanelController.shared.show(activate: true) }.buttonStyle(.borderedProminent)
                Button(tr("widget.hide")) { PanelController.shared.hide() }
            }
            Text(tr("widget.selectionNote")).font(.caption).foregroundStyle(.secondary)
        }
    }
    private func dragPicker(_ mode: WheelMode,_ value: Binding<DragKey>) -> some View {
        Picker(tr("wheel." + mode.rawValue),selection: Binding(get: { value.wrappedValue }, set: { newValue in
            var settings = preferences.configuration.dragSettings
            settings.assign(newValue, to: mode)
            preferences.configuration.dragSettings = settings
        })) {
            ForEach(DragKey.allCases,id: \.self) { key in Text(tr("drag.key." + key.rawValue)).tag(key) }
        }.onChange(of: value.wrappedValue) { if !drag.active && preferences.configuration.dragSettings.enabled { drag.configure(preferences.configuration.dragSettings) } }
    }
}
