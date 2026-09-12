import SwiftUI
import AppKit
import Combine
import QuartzCore

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

// MARK: - EI ownership, roaming and opened state

enum EIPetVisualStyle: String, Codable, CaseIterable, Identifiable {
    /// Kept only so old preference archives decode. EI v2 resolves this to `.smooth` immediately.
    case pixel = "Pixel"
    case smooth = "Smooth Vector"
    case illustrated = "Illustrated"
    case minimal = "Minimal"
    var id: String { rawValue }
}

enum EIRoomStyle: String, Codable, CaseIterable, Identifiable {
    case warm = "Warm", night = "Night", greenhouse = "Greenhouse", minimal = "Minimal"
    var id: String { rawValue }
}

struct EIOpenPreferences: Codable, Equatable {
    var version = 1
    var shortcutEnabled = true
    var roam = true
    var menuBar = true
    var screenEdges = true
    var shortcutKey: UInt32 = 14
    var shortcutModifiers: UInt32 = 2304
    var petVisual: EIPetVisualStyle = .smooth
    var roomStyle: EIRoomStyle = .warm
    var room = WidgetColor(red: 0.15, green: 0.10, blue: 0.10)
    var accent = WidgetColor(red: 0.96, green: 0.60, blue: 0.27)
    var floor = WidgetColor(red: 0.22, green: 0.13, blue: 0.10)
    var window = true
    var lamp = true
    var rug = true
    var shelf = true
    var roomPlants = true
}

@MainActor
final class EIOpenPreferencesStore: ObservableObject {
    static let shared = EIOpenPreferencesStore()
    private let defaults = UserDefaults.standard
    private let key = "HaloEIOpen.v1"
    private var pendingPersist: DispatchWorkItem?

    @Published var value: EIOpenPreferences {
        didSet { schedulePersist(value) }
    }

    private init() {
        var loaded = (defaults.data(forKey: key)
            .flatMap { try? JSONDecoder().decode(EIOpenPreferences.self, from: $0) })
            .flatMap { $0.version == 1 ? $0 : nil } ?? EIOpenPreferences()
        if loaded.petVisual == .pixel { loaded.petVisual = .smooth }
        value = loaded
        if let data = try? JSONEncoder().encode(loaded) { defaults.set(data, forKey: key) }
    }

    private func schedulePersist(_ snapshot: EIOpenPreferences) {
        pendingPersist?.cancel()
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        let work = DispatchWorkItem { [defaults, key] in defaults.set(data, forKey: key) }
        pendingPersist = work
        DispatchQueue.main.async(execute: work)
    }
}

@MainActor final class EIRoamModel: ObservableObject {
    @Published var right = true
    @Published var walking = false
}
@MainActor final class EIOpenUI: ObservableObject {
    static let shared = EIOpenUI()
    @Published var editing = false
}

/// Tracks EI's explicit ownership request, roaming pet state and CI safe regions.
/// The actual owned EI is rendered by HaloSurfaceRouter in the normal SwiftUI surface tree.
@MainActor
final class EnvironmentalInterfaceOwnershipController: ObservableObject {
    static let shared = EnvironmentalInterfaceOwnershipController()

    private struct SurfaceSnapshot {
        var frame = CGRect.zero
        var screenID = ""
    }

    @MainActor private final class RoamHost {
        let panel: NSPanel
        let model: EIRoamModel
        var frame = CGRect.zero
        init() {
            model = EIRoamModel()
            panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.becomesKeyOnlyIfNeeded = true
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            let view = NSHostingView(rootView: EIRoamingPetView(model: model))
            view.sizingOptions = []
            panel.contentView = view
        }
    }

    private enum Route { case notchL, notchR, menuL, menuR, left, right, bottom }
    private enum CIIdentifier: String { case music, bluetooth, retro }

    private weak var workspace: WorkspaceStore?
    private var started = false
    @Published private(set) var requested = false
    private var expandedByEI = false
    private var surfaces: [ObjectIdentifier: SurfaceSnapshot] = [:]
    private var roam: [String: RoamHost] = [:]
    private var bag = Set<AnyCancellable>()
    private var step = 0
    private var shortcut = ""
    private let hotkey = HotkeyService(identifierID: 4, notificationName: .init("HaloEnvironmentalInterfaceToggle"))

    var isRequested: Bool { requested }
    var ciOwnsSurface: Bool { activeCI() != nil }

    func start(workspace: WorkspaceStore) {
        self.workspace = workspace
        guard !started else {
            deferRefresh(animatedRoaming: false)
            return
        }
        started = true

        NotificationCenter.default.publisher(for: .init("HaloPanelGeometryChanged"))
            .receive(on: RunLoop.main)
            .sink { [weak self] note in self?.geometry(note) }
            .store(in: &bag)
        NotificationCenter.default.publisher(for: .init("HaloEnvironmentalInterfaceToggle"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in DispatchQueue.main.async { self?.toggleNow() } }
            .store(in: &bag)
        NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                guard let panel = note.object as? HaloPanel else { return }
                let id = ObjectIdentifier(panel)
                if let surface = self?.surfaces.removeValue(forKey: id), !surface.screenID.isEmpty {
                    EIPlacementRegistry.shared.set(nil, for: surface.screenID)
                }
            }
            .store(in: &bag)

        EIOpenPreferencesStore.shared.$value.removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.hotkeyUpdate()
                    self?.refreshPlacements()
                    self?.roaming(true)
                }
            }
            .store(in: &bag)
        EISettingsStore.shared.$settings.removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] settings in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if settings.mode == .off, self.requested { self.closeNow() }
                    self.refreshPlacements()
                    self.roaming(true)
                }
            }
            .store(in: &bag)
        EnvironmentalInterfaceEngine.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.deferRefresh(animatedRoaming: false) }
            .store(in: &bag)
        workspace.media.objectWillChange.merge(with: workspace.bluetooth.objectWillChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.deferRefresh(animatedRoaming: false) }
            .store(in: &bag)
        workspace.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.deferRefresh(animatedRoaming: false) }
            .store(in: &bag)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.deferRefresh(animatedRoaming: false) }
            .store(in: &bag)

        // Resident pets may roam, but position changes should be moments, not constant motion.
        Timer.publish(every: 28, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.step &+= 1
                self.roaming(true)
            }
            .store(in: &bag)

        hotkeyUpdate()
        refreshPlacements()
        roaming(false)
    }

    func open(editor: Bool = false) {
        DispatchQueue.main.async { [weak self] in self?.openNow(editor: editor) }
    }

    func close() {
        DispatchQueue.main.async { [weak self] in self?.closeNow() }
    }

    private func openNow(editor: Bool) {
        guard EISettingsStore.shared.settings.mode != .off else { NSSound.beep(); return }
        if editor { EIOpenUI.shared.editing = true }
        guard !requested else { return }
        requested = true
        expandedByEI = surfaces.isEmpty || surfaces.values.allSatisfy { $0.frame.height <= 82 }
        if expandedByEI { NotificationCenter.default.post(name: .init("HaloToggle"), object: nil) }
        refreshPlacements()
        roaming(false)
    }

    private func closeNow() {
        guard requested else {
            EIOpenUI.shared.editing = false
            return
        }
        let shouldCollapse = expandedByEI && !ciOwnsSurface
        requested = false
        EIOpenUI.shared.editing = false
        expandedByEI = false
        refreshPlacements()
        roaming(true)
        if shouldCollapse {
            DispatchQueue.main.async { NotificationCenter.default.post(name: .init("HaloToggle"), object: nil) }
        }
    }

    private func toggleNow() {
        if requested { closeNow() }
        else { openNow(editor: false) }
    }

    private func deferRefresh(animatedRoaming: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.refreshPlacements()
            self?.roaming(animatedRoaming)
        }
    }

    private func hotkeyUpdate() {
        let prefs = EIOpenPreferencesStore.shared.value
        let key = "\(prefs.shortcutEnabled)-\(prefs.shortcutKey)-\(prefs.shortcutModifiers)"
        guard key != shortcut else { return }
        shortcut = key
        hotkey.stop()
        if prefs.shortcutEnabled { _ = hotkey.register(code: prefs.shortcutKey, modifiers: prefs.shortcutModifiers) }
    }

    private func geometry(_ note: Notification) {
        guard let panel = note.object as? HaloPanel,
              let frame = note.userInfo?["frame"] as? CGRect else { return }
        let id = ObjectIdentifier(panel)
        var snapshot = surfaces[id] ?? SurfaceSnapshot()
        snapshot.frame = frame
        if let screenID = note.userInfo?["screen"] as? String { snapshot.screenID = screenID }
        surfaces[id] = snapshot
        publishPlacement(for: snapshot)
        roaming(false)
    }

    private func refreshPlacements() {
        for surface in surfaces.values { publishPlacement(for: surface) }
    }

    /// Mirrors SurfaceView's CI arbitration so the hand-tuned EI safe region always belongs to
    /// the same CI that actually owns Halo.
    private func activeCI() -> CIIdentifier? {
        guard let workspace else { return nil }
        let defaults = UserDefaults.standard
        let bool: (String, Bool) -> Bool = { key, fallback in defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key) }
        let number: (String, Double) -> Double = { key, fallback in defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key) }
        var candidates: [(CIIdentifier, Double, Int)] = []
        if bool("HaloContextRetroEnabled", false), EnvironmentalInterfaceEngine.shared.retroGameRequested {
            candidates.append((.retro, number("HaloContextRetroPriority", 80), 3))
        }
        if workspace.effectiveLayout.contextMusic?.enabled == true, workspace.media.isPlaying {
            candidates.append((.music, number("HaloContextMusicPriority", 60), 2))
        }
        let bluetoothEligible = bool("HaloContextBluetoothEnabled", false) &&
            ((bool("HaloContextBluetoothShowOnChanges", true) && workspace.bluetooth.lastEvent != nil) ||
             (bool("HaloContextBluetoothShowWhileConnected", true) && !workspace.bluetooth.connectedDevices.isEmpty))
        if bluetoothEligible { candidates.append((.bluetooth, number("HaloContextBluetoothPriority", 50), 1)) }
        return candidates.max { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
            return lhs.2 < rhs.2
        }?.0
    }

    /// Each CI exposes a different safe silhouette. EI can decorate edges and corners but never
    /// occupies the primary control region advertised by the active Context Interface.
    private func publishPlacement(for surface: SurfaceSnapshot) {
        guard !surface.screenID.isEmpty, surface.frame.width > 80, surface.frame.height > 82,
              let owner = activeCI() else {
            if !surface.screenID.isEmpty { EIPlacementRegistry.shared.set(nil, for: surface.screenID) }
            return
        }
        let width = surface.frame.width
        let height = surface.frame.height
        let context: EIPlacementContext
        switch owner {
        case .music:
            let edgeWidth = max(54, width * 0.18)
            let lowerHeight = max(48, height * 0.22)
            context = EIPlacementContext(
                availableRegions: [
                    CGRect(x: 8, y: 8, width: edgeWidth, height: max(34, height * 0.24)),
                    CGRect(x: width - edgeWidth - 8, y: 8, width: edgeWidth, height: max(34, height * 0.24)),
                    CGRect(x: 10, y: height - lowerHeight - 8, width: max(64, width * 0.23), height: lowerHeight),
                    CGRect(x: width - max(64, width * 0.23) - 10, y: height - lowerHeight - 8, width: max(64, width * 0.23), height: lowerHeight)
                ],
                preferredEdges: [.bottomRight, .bottomLeft, .right, .left],
                contentExclusionRegions: [CGRect(x: width * 0.18, y: max(38, height * 0.10), width: width * 0.64, height: max(80, height * 0.70))]
            )
        case .bluetooth:
            let cornerWidth = max(58, width * 0.19)
            let cornerHeight = max(42, height * 0.20)
            context = EIPlacementContext(
                availableRegions: [
                    CGRect(x: 8, y: 8, width: cornerWidth, height: cornerHeight),
                    CGRect(x: width - cornerWidth - 8, y: 8, width: cornerWidth, height: cornerHeight),
                    CGRect(x: 10, y: height - cornerHeight - 8, width: cornerWidth, height: cornerHeight),
                    CGRect(x: width - cornerWidth - 10, y: height - cornerHeight - 8, width: cornerWidth, height: cornerHeight)
                ],
                preferredEdges: [.bottomRight, .bottomLeft, .right],
                contentExclusionRegions: [CGRect(x: width * 0.11, y: max(42, height * 0.12), width: width * 0.78, height: max(86, height * 0.66))]
            )
        case .retro:
            let cornerWidth = max(48, width * 0.15)
            let topHeight = max(34, min(58, height * 0.16))
            context = EIPlacementContext(
                availableRegions: [
                    CGRect(x: 8, y: 6, width: cornerWidth, height: topHeight),
                    CGRect(x: width - cornerWidth - 8, y: 6, width: cornerWidth, height: topHeight)
                ],
                preferredEdges: [.right, .left],
                contentExclusionRegions: [CGRect(x: 14, y: max(40, height * 0.12), width: max(1, width - 28), height: max(96, height * 0.74))]
            )
        }
        EIPlacementRegistry.shared.set(context, for: surface.screenID)
    }

    private func roaming(_ animated: Bool) {
        let settings = EISettingsStore.shared.settings
        let prefs = EIOpenPreferencesStore.shared.value
        let engine = EnvironmentalInterfaceEngine.shared

        // Hidden is the dominant Pet state. Roaming is only a presentation option for a resident
        // idle pet; reactions are rendered by EI's normal notch-aware ambient surface instead.
        guard settings.mode == .pet,
              settings.petResident,
              prefs.roam,
              engine.shouldRender,
              engine.currentReaction == nil,
              engine.behaviourState != .hidden,
              !requested else {
            roam.values.forEach { $0.panel.orderOut(nil) }
            return
        }

        let ids = Set(NSScreen.screens.map { WindowManager.displayID($0) })
        for id in roam.keys.filter({ !ids.contains($0) }) { roam.removeValue(forKey: id)?.panel.close() }

        for (index, screen) in NSScreen.screens.enumerated() {
            let id = WindowManager.displayID(screen)
            let host = roam[id] ?? RoamHost()
            roam[id] = host
            host.panel.ignoresMouseEvents = !settings.petInteraction
            let frame = roamFrame(route(step + index, prefs), screen, CGFloat(settings.petScale))
            host.model.right = host.frame == .zero || frame.midX >= host.frame.midX
            host.model.walking = host.frame != .zero && abs(frame.midX - host.frame.midX) > 20
            if animated, host.frame != .zero {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 2.8
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    host.panel.animator().setFrame(frame, display: false)
                }, completionHandler: { Task { @MainActor in host.model.walking = false } })
            } else {
                host.panel.setFrame(frame, display: false)
                host.model.walking = false
            }
            host.frame = frame
            host.panel.orderFrontRegardless()
        }
    }

    private func route(_ value: Int, _ prefs: EIOpenPreferences) -> Route {
        var routes: [Route] = [.notchL, .notchR]
        if prefs.menuBar { routes += [.menuL, .menuR] }
        if prefs.screenEdges { routes += [.left, .right, .bottom] }
        return routes[(value & Int.max) % routes.count]
    }

    private func roamFrame(_ route: Route, _ screen: NSScreen, _ scale: CGFloat) -> CGRect {
        let zoom = min(1.6, max(0.7, scale))
        let size = CGSize(width: 76 * zoom, height: 52 * zoom)
        let frame = screen.frame
        switch route {
        case .notchL: return .init(x: frame.midX - 170 * zoom, y: frame.maxY - size.height + 4, width: size.width, height: size.height)
        case .notchR: return .init(x: frame.midX + 94 * zoom, y: frame.maxY - size.height + 4, width: size.width, height: size.height)
        case .menuL: return .init(x: frame.minX + min(180, frame.width * 0.18), y: frame.maxY - size.height + 9, width: size.width, height: size.height)
        case .menuR: return .init(x: frame.maxX - min(250, frame.width * 0.22) - size.width, y: frame.maxY - size.height + 9, width: size.width, height: size.height)
        case .left: return .init(x: frame.minX - size.width * 0.45, y: frame.midY, width: size.width, height: size.height)
        case .right: return .init(x: frame.maxX - size.width * 0.55, y: frame.midY + 80, width: size.width, height: size.height)
        case .bottom: return .init(x: frame.midX - size.width / 2, y: frame.minY - size.height * 0.3, width: size.width, height: size.height)
        }
    }
}
