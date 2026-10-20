import Foundation
import Observation
import FluxCore
import AppKit

@MainActor @Observable final class LibraryStore {
    static let shared = LibraryStore()
    var recipes: [Recipe] = []
    var watches: [WatchRule] = []
    var watchMessages: [UUID: String] = [:]
    var error: String?
    private let location: URL
    private let scanner = WatchScanner()
    private var watching: Task<Void, Never>?
    private struct State: Codable { var recipes: [Recipe]; var watches: [WatchRule] }
    private init() {
        location = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("FluxDrop/library-v1.json")
        if let data = try? Data(contentsOf: location) {
            do { let state = try JSONDecoder().decode(State.self, from: data); recipes = state.recipes; watches = state.watches }
            catch { self.error = tr("library.error") }
        }
    }
    func save() {
        do {
            try FileManager.default.createDirectory(at: location.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try JSONEncoder().encode(State(recipes: recipes, watches: watches)).write(to: location, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: location.path)
        } catch { self.error = tr("library.error") }
    }
    func add(_ recipe: Recipe) {
        do { try recipe.validate(); recipes.append(recipe); save() } catch { self.error = tr("error.invalidOptions") }
    }
    func importRecipe() {
        let dialog = NSOpenPanel(); dialog.canChooseFiles = true; dialog.canChooseDirectories = false; dialog.allowsMultipleSelection = false; dialog.allowedContentTypes = [.json]; dialog.allowsOtherFileTypes = false
        guard presentFileDialog(dialog) == .OK, let url = dialog.url else { return }
        do {
            guard (try url.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0 <= 1_000_000 else { throw EngineFailure.tooLarge }
            var recipe = try JSONDecoder().decode(Recipe.self, from: Data(contentsOf: url)); try recipe.validate()
            recipe.id = UUID(); recipes.append(recipe); save()
        } catch { self.error = tr("recipe.invalid") }
    }
    func export(_ recipe: Recipe) {
        let dialog = NSSavePanel(); dialog.allowedContentTypes = [.json]; dialog.nameFieldStringValue = recipe.name + ".json"
        guard presentFileDialog(dialog) == .OK, let url = dialog.url else { return }
        do { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; try encoder.encode(recipe).write(to: url, options: .atomic) }
        catch { self.error = tr("library.error") }
    }
    func startWatching(queue: JobQueue) {
        guard watching == nil else { return }
        watching = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                for rule in self.watches where rule.enabled {
                    do {
                        let scan = try await self.scanner.scan(rule)
                        guard let index = self.watches.firstIndex(where: { $0.id == rule.id && $0.enabled }) else { continue }
                        for file in scan.ready { queue.enqueue([file], directory: scan.destination, recipe: rule.recipe) }
                        self.watches[index].processed.merge(scan.fingerprints) { _, new in new }
                        if !scan.ready.isEmpty { self.watchMessages[rule.id] = tr("watch.queued") + " \(scan.ready.count)"; self.save() }
                    } catch { self.watchMessages[rule.id] = tr("watch.error") }
                }
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }
}
