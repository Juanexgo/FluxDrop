import Foundation
import Observation

public enum JobState: String, Codable, Sendable { case pending, running, succeeded, failed, cancelled, interrupted }
public struct Job: Identifiable, Codable, Sendable {
    public var id = UUID()
    public let input: URL
    public let directory: URL
    public let options: ImageOptions
    public var state: JobState = .pending
    public var output: URL?
    public var recipe: Recipe?
    public var additionalInputs: [URL]?
    public var progress: Double?
    public var failure: EngineFailure?
    public init(input: URL, directory: URL, options: ImageOptions) { self.input = input; self.directory = directory; self.options = options }
}

/// UI state and checkpoint writes are main-actor owned. Image decoding/encoding is actor-isolated elsewhere.
@MainActor @Observable public final class JobQueue {
    public private(set) var jobs: [Job] = []
    public var onCompletion: (@MainActor (Job) -> Void)?
    public private(set) var paused = false
    public private(set) var persistenceFailed = false
    private let engine = ImageEngine()
    private let workflow: WorkflowEngine
    private var corruptJournal = false
    private var passwords: [UUID: String] = [:]
    public var keepHistory = true { didSet { save() } }
    private let journal: URL?
    private var active: Task<Void, Never>?
    private var activeID: UUID?
    public init(journal: URL? = nil, tools: URL = URL(fileURLWithPath: "/unavailable")) {
        self.journal = journal
        workflow = WorkflowEngine(tools: tools)
        if let journal, FileManager.default.fileExists(atPath: journal.path) {
            do {
                jobs = try JSONDecoder().decode([Job].self, from: Data(contentsOf: journal))
                // Never resume work without a new user action after a crash/relaunch.
                for i in jobs.indices where jobs[i].state == .running || jobs[i].state == .pending {
                    jobs[i].state = .interrupted; jobs[i].failure = .interrupted
                }
            } catch { persistenceFailed = true; corruptJournal = true }
        }
        save()
    }
    public func enqueue(_ urls: [URL], directory: URL, options: ImageOptions) {
        jobs.append(contentsOf: urls.map { Job(input: $0, directory: directory, options: options) }); save(); schedule()
    }
    public func enqueue(_ urls: [URL], directory: URL, recipe: Recipe, password: String? = nil) {
        guard let first = urls.first else { return }
        var job = Job(input: first, directory: directory, options: .init())
        job.recipe = recipe; job.additionalInputs = Array(urls.dropFirst())
        if let password, !password.isEmpty { passwords[job.id] = password }
        jobs.append(job); save(); schedule()
    }
    public func setPaused(_ value: Bool) { paused = value; if !value { schedule() } }
    public func cancel(_ id: UUID) {
        guard let i = jobs.firstIndex(where: { $0.id == id }) else { return }
        if jobs[i].state == .pending { jobs[i].state = .cancelled }
        if jobs[i].state == .running { active?.cancel() }
        save()
    }
    public func cancelAll() { for job in jobs { cancel(job.id) } }
    public func retry(_ id: UUID) {
        guard let job = jobs.first(where: { $0.id == id }), [.failed, .cancelled, .interrupted].contains(job.state) else { return }
        if let recipe = job.recipe { enqueue([job.input] + (job.additionalInputs ?? []), directory: job.directory, recipe: recipe) }
        else { enqueue([job.input], directory: job.directory, options: job.options) }
    }
    public func clearFinished() { jobs.removeAll { $0.state != .pending && $0.state != .running }; save() }
    private func schedule() {
        guard !paused, activeID == nil, let i = jobs.firstIndex(where: { $0.state == .pending }) else { return }
        jobs[i].state = .running; let job = jobs[i]; activeID = job.id; save()
        active = Task {
            do {
                let result: URL
                if let recipe = job.recipe {
                    let outputs = try await workflow.run(inputs: [job.input] + (job.additionalInputs ?? []), recipe: recipe, directory: job.directory, password: passwords[job.id]) { [weak self] fraction in
                        await self?.updateProgress(job.id, value: fraction)
                    }
                    result = outputs[0]
                } else { result = try await engine.convert(input: job.input, directory: job.directory, options: job.options) }
                complete(job.id, state: .succeeded, output: result, failure: nil)
            } catch is CancellationError {
                complete(job.id, state: .cancelled, output: nil, failure: nil)
            } catch {
                complete(job.id, state: .failed, output: nil, failure: error as? EngineFailure ?? .unknown)
            }
            passwords[job.id] = nil; activeID = nil; active = nil; schedule()
        }
    }
    private func complete(_ id: UUID, state: JobState, output: URL?, failure: EngineFailure?) {
        guard let i = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[i].state = state; jobs[i].output = output; jobs[i].failure = failure; save(); onCompletion?(jobs[i])
    }
    private func updateProgress(_ id: UUID, value: Double?) {
        if let i = jobs.firstIndex(where: { $0.id == id }) { jobs[i].progress = value }
    }
    private func save() {
        guard let journal, !corruptJournal else { return }
        do {
            try FileManager.default.createDirectory(at: journal.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let data = try JSONEncoder().encode(keepHistory ? jobs : jobs.filter { [.pending, .running].contains($0.state) })
            try data.write(to: journal, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: journal.path)
        } catch { persistenceFailed = true }
    }
}
