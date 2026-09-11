import SwiftUI
import AppKit
import Combine

@MainActor
final class AppStore: ObservableObject {
    let workspace = WorkspaceStore()
    @Published var configuration: Configuration { didSet { scheduleSave() } }
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
    private var pendingSave: DispatchWorkItem?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "configuration"),
           var saved = try? JSONDecoder().decode(Configuration.self, from: data),
           let theme = try? saved.theme.validated() {
            saved.theme = theme
            configuration = saved
        } else { configuration = Configuration() }
        workspace.applyTheme = { [weak self] theme in self?.configuration.theme = theme }
        EnvironmentalInterfaceManager.shared.start(workspace: workspace)
        EnvironmentalInterfaceOwnershipController.shared.start(workspace: workspace)
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
    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.flushConfiguration() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
    func flushConfiguration() {
        pendingSave?.cancel()
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
        var seen = Set(files)
        let accepted = Array(urls.filter { $0.isFileURL && seen.insert($0).inserted }.prefix(max(0, 100 - files.count)))
        guard !accepted.isEmpty else { return }
        for url in accepted { addedAt[url] = Date() }
        files.append(contentsOf: accepted)
        workspace.publish(accepted.count == 1 ? "File added" : "Files added", detail: "\(accepted.count) shelf references")
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

// MARK: - EI ownership, roaming and cozy opened state

enum EIPetVisualStyle: String, Codable, CaseIterable, Identifiable { case pixel = "Pixel", smooth = "Smooth"; var id: String { rawValue } }
enum EIRoomStyle: String, Codable, CaseIterable, Identifiable { case warm = "Warm", night = "Night", greenhouse = "Greenhouse", minimal = "Minimal"; var id: String { rawValue } }
struct EIOpenPreferences: Codable, Equatable {
    var version = 1, shortcutEnabled = true, roam = true, menuBar = true, screenEdges = true
    var shortcutKey: UInt32 = 14, shortcutModifiers: UInt32 = 2304
    var petVisual: EIPetVisualStyle = .pixel; var roomStyle: EIRoomStyle = .warm
    var room = WidgetColor(red: 0.15, green: 0.10, blue: 0.10), accent = WidgetColor(red: 0.96, green: 0.60, blue: 0.27), floor = WidgetColor(red: 0.22, green: 0.13, blue: 0.10)
    var window = true, lamp = true, rug = true
}
@MainActor final class EIOpenPreferencesStore: ObservableObject {
    static let shared = EIOpenPreferencesStore(); @Published var value: EIOpenPreferences { didSet { if let d = try? JSONEncoder().encode(value) { UserDefaults.standard.set(d, forKey: "HaloEIOpen.v1") } } }
    private init() { value = (UserDefaults.standard.data(forKey: "HaloEIOpen.v1").flatMap { try? JSONDecoder().decode(EIOpenPreferences.self, from: $0) }).flatMap { $0.version == 1 ? $0 : nil } ?? EIOpenPreferences() }
}
@MainActor final class EIRoamModel: ObservableObject { @Published var right = true; @Published var walking = false }
@MainActor final class EIOpenUI: ObservableObject { static let shared = EIOpenUI(); @Published var editing = false }

@MainActor final class EnvironmentalInterfaceOwnershipController {
    static let shared = EnvironmentalInterfaceOwnershipController()
    @MainActor private final class Host {
        let panel: NSPanel; var frame = CGRect.zero
        init(root: AnyView, level: Int) { panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false); panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = false; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false; panel.becomesKeyOnlyIfNeeded = true; panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + level); panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]; let v = NSHostingView(rootView: root); v.sizingOptions = []; panel.contentView = v }
    }
    @MainActor private final class RoamHost { let host: Host; let model: EIRoamModel; init() { let model = EIRoamModel(); self.model = model; host = Host(root: AnyView(EIRoamingPetView(model: model)), level: 2) } }
    private enum Route { case notchL, notchR, menuL, menuR, left, right, bottom }
    private weak var workspace: WorkspaceStore?; private var started = false, requested = false, expandedByEI = false; private var hosts: [ObjectIdentifier: Host] = [:], roam: [String: RoamHost] = [:]; private var bag = Set<AnyCancellable>(); private var step = 0, shortcut = ""
    private let hotkey = HotkeyService(identifierID: 4, notificationName: .init("HaloEnvironmentalInterfaceToggle"))
    var isRequested: Bool { requested }
    func start(workspace: WorkspaceStore) {
        self.workspace = workspace; guard !started else { refresh(true); return }; started = true
        NotificationCenter.default.publisher(for: .init("HaloPanelGeometryChanged")).receive(on: RunLoop.main).sink { [weak self] in self?.geometry($0) }.store(in: &bag)
        NotificationCenter.default.publisher(for: .init("HaloEnvironmentalInterfaceToggle")).receive(on: RunLoop.main).sink { [weak self] _ in self?.toggle() }.store(in: &bag)
        NotificationCenter.default.publisher(for: NSWindow.willCloseNotification).receive(on: RunLoop.main).sink { [weak self] n in if let w = n.object as? NSWindow { self?.hosts.removeValue(forKey: ObjectIdentifier(w))?.panel.close() } }.store(in: &bag)
        EIOpenPreferencesStore.shared.$value.removeDuplicates().receive(on: RunLoop.main).sink { [weak self] _ in self?.hotkeyUpdate(); self?.refresh(true) }.store(in: &bag)
        EISettingsStore.shared.$settings.removeDuplicates().receive(on: RunLoop.main).sink { [weak self] s in if s.mode == .off, self?.requested == true { self?.close() }; self?.refresh(true) }.store(in: &bag)
        EnvironmentalInterfaceEngine.shared.objectWillChange.receive(on: RunLoop.main).sink { [weak self] _ in DispatchQueue.main.async { self?.refresh(true) } }.store(in: &bag)
        workspace.media.objectWillChange.merge(with: workspace.bluetooth.objectWillChange).receive(on: RunLoop.main).sink { [weak self] _ in DispatchQueue.main.async { self?.refresh(true) } }.store(in: &bag)
        workspace.$settings.receive(on: RunLoop.main).sink { [weak self] _ in DispatchQueue.main.async { self?.refresh(true) } }.store(in: &bag)
        Timer.publish(every: 6, on: .main, in: .common).autoconnect().sink { [weak self] _ in self?.step &+= 1; self?.roaming(true) }.store(in: &bag)
        hotkeyUpdate(); refresh(false)
    }
    func open(editor: Bool = false) { if editor { EIOpenUI.shared.editing = true }; if !requested { toggle() } }
    func close() { guard requested else { return }; requested = false; EIOpenUI.shared.editing = false; let collapse = expandedByEI && !hasCI(); expandedByEI = false; hosts.values.forEach { $0.panel.orderOut(nil) }; if let workspace { EnvironmentalInterfaceManager.shared.start(workspace: workspace) }; roaming(true); if collapse { DispatchQueue.main.async { NotificationCenter.default.post(name: .init("HaloToggle"), object: nil) } } }
    private func toggle() {
        guard EISettingsStore.shared.settings.mode != .off else { NSSound.beep(); return }; if requested { close(); return }
        requested = true; EnvironmentalInterfaceManager.shared.stop(); if let workspace { EnvironmentalInterfaceEngine.shared.start(workspace: workspace) }
        expandedByEI = hosts.values.allSatisfy { $0.frame.height <= 82 }; if expandedByEI { NotificationCenter.default.post(name: .init("HaloToggle"), object: nil) }; refresh(true)
    }
    private func hotkeyUpdate() { let p = EIOpenPreferencesStore.shared.value, k = "\(p.shortcutEnabled)-\(p.shortcutKey)-\(p.shortcutModifiers)"; guard k != shortcut else { return }; shortcut = k; hotkey.stop(); if p.shortcutEnabled { _ = hotkey.register(code: p.shortcutKey, modifiers: p.shortcutModifiers) } }
    private func geometry(_ n: Notification) { guard let w = n.object as? NSWindow, let f = n.userInfo?["frame"] as? CGRect else { return }; let id = ObjectIdentifier(w), h = hosts[id] ?? Host(root: AnyView(EIOpenSurface()), level: 3); hosts[id] = h; h.frame = f; owned(h, false); roaming(false) }
    private func refresh(_ a: Bool) { hosts.values.forEach { owned($0, a) }; roaming(a) }
    private func owned(_ h: Host, _ a: Bool) { guard requested, !hasCI(), h.frame.height > 82 else { h.panel.orderOut(nil); return }; if a, h.panel.frame != .zero { NSAnimationContext.runAnimationGroup { c in c.duration = 0.18; h.panel.animator().setFrame(h.frame, display: false) } } else { h.panel.setFrame(h.frame, display: false) }; h.panel.ignoresMouseEvents = false; h.panel.orderFrontRegardless() }
    private func hasCI() -> Bool {
        guard let w = workspace else { return false }; let d = UserDefaults.standard, b: (String,Bool)->Bool = { d.object(forKey:$0) == nil ? $1 : d.bool(forKey:$0) }
        if b("HaloContextRetroEnabled", false), EnvironmentalInterfaceEngine.shared.retroGameRequested { return true }
        if w.effectiveLayout.contextMusic?.enabled == true, w.media.isPlaying { return true }
        return b("HaloContextBluetoothEnabled", false) && ((b("HaloContextBluetoothShowOnChanges", true) && w.bluetooth.lastEvent != nil) || (b("HaloContextBluetoothShowWhileConnected", true) && !w.bluetooth.connectedDevices.isEmpty))
    }
    private func roaming(_ animated: Bool) {
        let e = EISettingsStore.shared.settings, p = EIOpenPreferencesStore.shared.value; guard e.mode == .pet, p.roam, !e.petResident, EnvironmentalInterfaceEngine.shared.currentReaction == nil, !requested else { roam.values.forEach { $0.host.panel.orderOut(nil) }; return }
        let ids = Set(NSScreen.screens.map { WindowManager.displayID($0) }); for id in roam.keys.filter({ !ids.contains($0) }) { roam.removeValue(forKey: id)?.host.panel.close() }
        for (i,s) in NSScreen.screens.enumerated() { let id = WindowManager.displayID(s), r = roam[id] ?? RoamHost(); roam[id] = r; r.host.panel.ignoresMouseEvents = !e.petInteraction; let f = roamFrame(route(step+i,p),s,CGFloat(e.petScale)); r.model.right = r.host.frame == .zero || f.midX >= r.host.frame.midX; r.model.walking = r.host.frame != .zero && abs(f.midX-r.host.frame.midX)>20; if animated, r.host.frame != .zero { NSAnimationContext.runAnimationGroup({ c in c.duration=2.1; r.host.panel.animator().setFrame(f, display:false) }, completionHandler:{ Task { @MainActor in r.model.walking=false } }) } else { r.host.panel.setFrame(f, display:false); r.model.walking=false }; r.host.frame=f; r.host.panel.orderFrontRegardless() }
    }
    private func route(_ n:Int,_ p:EIOpenPreferences)->Route { var a:[Route]=[.notchL,.notchR]; if p.menuBar { a += [.menuL,.menuR] }; if p.screenEdges { a += [.left,.right,.bottom] }; return a[(n & Int.max)%a.count] }
    private func roamFrame(_ r:Route,_ s:NSScreen,_ z:CGFloat)->CGRect { let q=min(1.6,max(0.7,z)), sz=CGSize(width:76*q,height:52*q), f=s.frame; switch r { case .notchL:return .init(x:f.midX-170*q,y:f.maxY-sz.height+4,width:sz.width,height:sz.height); case .notchR:return .init(x:f.midX+94*q,y:f.maxY-sz.height+4,width:sz.width,height:sz.height); case .menuL:return .init(x:f.minX+min(180,f.width*0.18),y:f.maxY-sz.height+9,width:sz.width,height:sz.height); case .menuR:return .init(x:f.maxX-min(250,f.width*0.22)-sz.width,y:f.maxY-sz.height+9,width:sz.width,height:sz.height); case .left:return .init(x:f.minX-sz.width*0.45,y:f.midY,width:sz.width,height:sz.height); case .right:return .init(x:f.maxX-sz.width*0.55,y:f.midY+80,width:sz.width,height:sz.height); case .bottom:return .init(x:f.midX-sz.width/2,y:f.minY-sz.height*0.3,width:sz.width,height:sz.height) } }
}
