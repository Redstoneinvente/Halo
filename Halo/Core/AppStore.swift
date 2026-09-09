import SwiftUI
import AppKit
import Combine

@MainActor
final class AppStore: ObservableObject {
    let workspace = WorkspaceStore()
    @Published var configuration: Configuration { didSet { save() } }
    @Published var error: String?
    @Published var files: [URL] = [] { didSet { persistFiles() } }
    private var addedAt: [URL: Date] = [:]
    @Published var pinnedFiles = Set<URL>()
    let shelfPreview = ShelfPreview()
    @Published var deadline: Date?
    @Published var pausedSeconds: TimeInterval = 0
    @Published var finished = false
    private var ticker: AnyCancellable?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "configuration"),
           var saved = try? JSONDecoder().decode(Configuration.self, from: data),
           let theme = try? saved.theme.validated() {
            saved.theme = theme
            configuration = saved
        } else { configuration = Configuration() }
        workspace.applyTheme = { [weak self] theme in self?.configuration.theme = theme }
        if workspace.settings.persistShelf {
            files = (defaults.stringArray(forKey: "shelf.paths") ?? []).map { URL(fileURLWithPath: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
            let savedDates = (defaults.dictionary(forKey: "shelf.addedAt") as? [String: Date]) ?? [:]
            addedAt = Dictionary(uniqueKeysWithValues: files.map { ($0, savedDates[$0.path] ?? Date()) })
            pinnedFiles = Set((defaults.stringArray(forKey: "shelf.pinned") ?? []).map { URL(fileURLWithPath: $0) }).intersection(files)
        }
        if let end = defaults.object(forKey: "timer.deadline") as? Date {
            if end > Date() { deadline = end; monitorTimer() }
            else { finished = true; defaults.removeObject(forKey: "timer.deadline") }
        }
    }
    private func save() {
        do { defaults.set(try JSONEncoder().encode(configuration), forKey: "configuration") }
        catch { self.error = error.localizedDescription }
    }
    func startTimer(minutes: Int) {
        finished = false
        pausedSeconds = 0
        deadline = Date().addingTimeInterval(Double(minutes * 60))
        defaults.set(deadline, forKey: "timer.deadline")
        monitorTimer()
    }
    private func monitorTimer() {
        ticker?.cancel()
        ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] now in
            guard let self, let end = self.deadline, now >= end else { return }
            self.deadline = nil
            self.finished = true
            self.defaults.removeObject(forKey: "timer.deadline")
            self.workspace.publish("Focus complete", detail: "Time for a break")
            self.workspace.notify("Your Halo focus session is complete")
            self.ticker?.cancel()
            NSSound.beep()
        }
    }
    func pauseResume() {
        if let end = deadline {
            pausedSeconds = max(0, end.timeIntervalSinceNow)
            deadline = nil
            defaults.removeObject(forKey: "timer.deadline")
            ticker?.cancel()
        } else if pausedSeconds > 0 {
            deadline = Date().addingTimeInterval(pausedSeconds)
            defaults.set(deadline, forKey: "timer.deadline")
            pausedSeconds = 0
            monitorTimer()
        }
    }
    func resetTimer() { deadline = nil; pausedSeconds = 0; finished = false; ticker?.cancel(); defaults.removeObject(forKey: "timer.deadline") }
    func persistFiles() {
        defaults.set(workspace.settings.persistShelf ? files.map(\.path) : [], forKey: "shelf.paths")
        defaults.set(workspace.settings.persistShelf ? pinnedFiles.map(\.path) : [], forKey: "shelf.pinned")
        let dates = addedAt.filter { files.contains($0.key) }
        defaults.set(workspace.settings.persistShelf ? Dictionary(uniqueKeysWithValues: dates.map { ($0.key.path, $0.value) }) : [:], forKey: "shelf.addedAt")
    }
    func toggleFilePin(_ url: URL) {
        if pinnedFiles.contains(url) { pinnedFiles.remove(url) } else { pinnedFiles.insert(url) }
        persistFiles()
    }
    func removeFile(_ url: URL) {
        pinnedFiles.remove(url); addedAt.removeValue(forKey: url); files.removeAll { $0 == url }
    }
    func clearShelf() { pinnedFiles = []; addedAt = [:]; files = [] }
    func expireFiles() {
        let retention = workspace.settings.shelfRetentionMinutes
        guard retention > 0 else { return }
        let expired = files.filter { !pinnedFiles.contains($0) && Date().timeIntervalSince(addedAt[$0] ?? Date()) > Double(retention * 60) }
        guard !expired.isEmpty else { return }
        files.removeAll { expired.contains($0) }
        addedAt = addedAt.filter { files.contains($0.key) }
    }
    func addFiles(_ urls: [URL]) {
        for url in urls where url.isFileURL && !files.contains(url) && files.count < 100 {
            addedAt[url] = Date(); files.append(url)
        }
    }
    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { addFiles(panel.urls) }
    }
    func importTheme() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard (values.fileSize ?? 0) < 1_000_000 else { throw CocoaError(.fileReadTooLarge) }
            let data = try Data(contentsOf: url)
            if let archive = try? JSONDecoder().decode(ThemeArchive.self, from: data) {
                let validated = try archive.validated()
                configuration.theme = validated.theme; workspace.settings.layout = validated.layout
            } else { configuration.theme = try JSONDecoder().decode(Theme.self, from: data).validated() }
        } catch { self.error = "Theme import failed: \(error.localizedDescription)" }
    }
    func exportTheme() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "MyTheme.haloTheme"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            var layout = workspace.settings.layout
            layout.appearance.assetPath = ""
            try encoder.encode(ThemeArchive(theme: configuration.theme, layout: layout)).write(to: url, options: .atomic)
        } catch { self.error = error.localizedDescription }
    }
}
