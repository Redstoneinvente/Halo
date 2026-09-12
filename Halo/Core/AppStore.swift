import SwiftUI
import AppKit
import Combine
import QuartzCore
import Security

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
        // Environmental Interface is intentionally dormant for now. Keep the implementation
        // and assets in the tree so development can resume later without shipping EI at runtime.
        // Commercial account/license restoration is owned by AppDelegate so Halo's runtime
        // cannot start before access has been validated.
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

@MainActor final class EINotchPeekModel: ObservableObject {
    @Published var motion: HaloCompanionMotion = .peekEyes
    @Published var notchWidth: CGFloat = 180
    @Published var notchHeight: CGFloat = 32
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

    @MainActor private final class PeekHost {
        let panel: NSPanel
        let model: EINotchPeekModel
        init() {
            model = EINotchPeekModel()
            panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.becomesKeyOnlyIfNeeded = true
            panel.ignoresMouseEvents = true
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 4)
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
            let view = NSHostingView(rootView: EIPhysicalNotchPetPeek(model: model))
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
    private var peekHosts: [String: PeekHost] = [:]
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
                    self?.refreshNotchPeek()
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
                    self.refreshNotchPeek()
                }
            }
            .store(in: &bag)
        EnvironmentalInterfaceEngine.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.deferRefresh(animatedRoaming: false) }
            .store(in: &bag)
        HaloPetDebugState.shared.$forcedMotion.removeDuplicates()
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
        refreshNotchPeek()
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
        refreshNotchPeek()
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
        refreshNotchPeek()
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
            self?.refreshNotchPeek()
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
        refreshNotchPeek()
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

    private func activePeekMotion() -> HaloCompanionMotion? {
        let settings = EISettingsStore.shared.settings
        let engine = EnvironmentalInterfaceEngine.shared
        guard settings.mode == .pet, engine.shouldRender else { return nil }

        if let forced = HaloPetDebugState.shared.forcedMotion {
            switch forced {
            case .peekEyes, .peekEars, .peek, .peekLeft, .peekRight, .paw, .tail:
                return forced
            default:
                break
            }
        }

        guard let kind = engine.currentReaction?.kind else { return nil }
        switch kind {
        case .petPeekEyes: return .peekEyes
        case .petPeekEars: return .peekEars
        case .petPeekUnder: return .peek
        case .petPeekLeft: return .peekLeft
        case .petPeekRight: return .peekRight
        case .petPawFirst: return .paw
        case .petTailFirst: return .tail
        default: return nil
        }
    }

    private func targetPeekScreen() -> NSScreen? {
        let notched = NSScreen.screens.filter { $0.safeAreaInsets.top > 0 }
        guard !notched.isEmpty else { return nil }

        if requested {
            let ordered = surfaces.values.sorted { lhs, rhs in lhs.frame.height > rhs.frame.height }
            for snapshot in ordered where !snapshot.screenID.isEmpty {
                if let screen = notched.first(where: { WindowManager.displayID($0) == snapshot.screenID }) {
                    return screen
                }
            }
        }
        if let main = NSScreen.main, main.safeAreaInsets.top > 0 { return main }
        return notched.first
    }

    private func notchGeometry(for screen: NSScreen) -> CGSize {
        let height = max(22, screen.safeAreaInsets.top)
        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea,
           right.minX > left.maxX {
            return CGSize(width: max(92, right.minX - left.maxX), height: height)
        }
        return CGSize(width: 180, height: height)
    }

    private func refreshNotchPeek() {
        guard let motion = activePeekMotion(), let screen = targetPeekScreen() else {
            peekHosts.values.forEach { $0.panel.orderOut(nil) }
            return
        }

        let id = WindowManager.displayID(screen)
        let host = peekHosts[id] ?? PeekHost()
        peekHosts[id] = host
        let notch = notchGeometry(for: screen)
        if host.model.motion != motion { host.model.motion = motion }
        if abs(host.model.notchWidth - notch.width) > 0.5 { host.model.notchWidth = notch.width }
        if abs(host.model.notchHeight - notch.height) > 0.5 { host.model.notchHeight = notch.height }

        let zoom = min(1.6, max(0.7, CGFloat(EISettingsStore.shared.settings.petScale)))
        let spriteSize = min(168, max(116, notch.width * 0.78)) * zoom
        let width = max(360, notch.width + spriteSize * 1.55)
        let height = max(150, notch.height + spriteSize * 0.88)
        let frame = CGRect(x: screen.frame.midX - width / 2,
                           y: screen.frame.maxY - height,
                           width: width,
                           height: height)
        if host.panel.frame != frame { host.panel.setFrame(frame, display: false) }

        for (otherID, other) in peekHosts where otherID != id { other.panel.orderOut(nil) }
        host.panel.orderFrontRegardless()
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


// MARK: - Halo account + LicenseSeat commercial services

struct HaloCommercialConfiguration {
    private static func value(_ key: String) -> String {
        if let env = ProcessInfo.processInfo.environment[key], !env.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return env.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    static var firebaseAPIKey: String { value("HaloFirebaseAPIKey") }
    static var licenseSeatPublishableKey: String { value("HaloLicenseSeatPublishableKey") }
    static var licenseSeatProductSlug: String { value("HaloLicenseSeatProductSlug") }
    static var trialEndpoint: String { value("HaloTrialEndpoint") }
    static var firebaseConfigured: Bool { !firebaseAPIKey.isEmpty }
    static var licenseSeatConfigured: Bool {
        !licenseSeatPublishableKey.isEmpty && !licenseSeatProductSlug.isEmpty
    }
    static var trialConfigured: Bool { !trialEndpoint.isEmpty }
}

enum HaloKeychain {
    private static let service = "com.redstoneinvente.Halo.commercial"

    static func string(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func set(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            attributes.forEach { add[$0.key] = $0.value }
            return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
        }
        return status == errSecSuccess
    }

    static func remove(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private struct FirebaseAuthResponse: Decodable {
    let idToken: String
    let email: String?
    let refreshToken: String
    let expiresIn: String
    let localId: String
}

private struct FirebaseRefreshResponse: Decodable {
    let expiresIn: String
    let refreshToken: String
    let idToken: String
    let userId: String

    enum CodingKeys: String, CodingKey {
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case userId = "user_id"
    }
}

private struct FirebaseLookupResponse: Decodable {
    struct User: Decodable {
        let localId: String
        let email: String?
        let emailVerified: Bool?
        let displayName: String?
    }
    let users: [User]?
}

@MainActor
final class HaloAccountManager: ObservableObject {
    static let shared = HaloAccountManager()

    @Published private(set) var isSignedIn = false
    @Published private(set) var email = ""
    @Published private(set) var userID = ""
    @Published private(set) var emailVerified = false
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?
    @Published var notice: String?

    private var idToken = ""
    private var tokenExpiry = Date.distantPast
    private let refreshKey = "firebase.refreshToken"
    private let defaults = UserDefaults.standard

    var isConfigured: Bool { HaloCommercialConfiguration.firebaseConfigured }

    func restore() async {
        guard isConfigured else {
            clearLocalSession()
            return
        }
        guard let refresh = HaloKeychain.string(for: refreshKey), !refresh.isEmpty else {
            clearLocalSession()
            return
        }
        do {
            try await refreshSession(using: refresh)
            try await loadProfile()
        } catch {
            clearLocalSession()
            errorMessage = readable(error)
        }
    }

    func signUp(email: String, password: String) async {
        await authenticate(endpoint: "accounts:signUp", email: email, password: password)
    }

    func signIn(email: String, password: String) async {
        await authenticate(endpoint: "accounts:signInWithPassword", email: email, password: password)
    }

    func resetPassword(email: String) async {
        guard isConfigured else { errorMessage = "Firebase is not configured yet."; return }
        let cleaned = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { errorMessage = "Enter your email address first."; return }
        isBusy = true; errorMessage = nil; notice = nil
        defer { isBusy = false }
        do {
            _ = try await firebaseRequest(
                endpoint: "accounts:sendOobCode",
                body: ["requestType": "PASSWORD_RESET", "email": cleaned]
            )
            notice = "Password reset email sent."
        } catch { errorMessage = readable(error) }
    }

    func sendVerificationEmail() async {
        guard isConfigured else { errorMessage = "Firebase is not configured yet."; return }
        guard isSignedIn else { errorMessage = "Sign in to your Halo account first."; return }
        if emailVerified { notice = "Your email is already verified."; errorMessage = nil; return }
        isBusy = true; errorMessage = nil; notice = nil
        defer { isBusy = false }
        do {
            let token = try await validIDToken()
            _ = try await firebaseRequest(
                endpoint: "accounts:sendOobCode",
                body: ["requestType": "VERIFY_EMAIL", "idToken": token]
            )
            notice = email.isEmpty ? "Verification email sent." : "Verification email sent to \(email)."
        } catch { errorMessage = readable(error) }
    }

    func refreshVerificationStatus() async {
        guard isConfigured else { errorMessage = "Firebase is not configured yet."; return }
        guard isSignedIn else { errorMessage = "Sign in to your Halo account first."; return }
        isBusy = true; errorMessage = nil; notice = nil
        defer { isBusy = false }
        do {
            _ = try await validIDToken()
            try await loadProfile()
            notice = emailVerified ? "Email verified." : "Email is still awaiting verification."
        } catch { errorMessage = readable(error) }
    }

    func signOut() {
        clearLocalSession()
        notice = "Signed out."
        errorMessage = nil
    }

    func validIDToken() async throws -> String {
        guard isSignedIn else { throw HaloCommercialError.message("Sign in to your Halo account first.") }
        if Date().addingTimeInterval(60) < tokenExpiry, !idToken.isEmpty { return idToken }
        guard let refresh = HaloKeychain.string(for: refreshKey) else {
            throw HaloCommercialError.message("Your Halo session has expired. Please sign in again.")
        }
        try await refreshSession(using: refresh)
        return idToken
    }

    private func authenticate(endpoint: String, email: String, password: String) async {
        guard isConfigured else { errorMessage = "Firebase is not configured yet."; return }
        let cleaned = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.contains("@") else { errorMessage = "Enter a valid email address."; return }
        guard password.count >= 6 else { errorMessage = "Password must contain at least 6 characters."; return }
        isBusy = true; errorMessage = nil; notice = nil
        defer { isBusy = false }
        do {
            let data = try await firebaseRequest(
                endpoint: endpoint,
                body: ["email": cleaned, "password": password, "returnSecureToken": true]
            )
            let result = try JSONDecoder().decode(FirebaseAuthResponse.self, from: data)
            adopt(idToken: result.idToken, refreshToken: result.refreshToken,
                  userID: result.localId, email: result.email ?? cleaned,
                  expiresIn: result.expiresIn)
            try await loadProfile()
            notice = endpoint.contains("signUp") ? "Halo account created." : "Signed in."
        } catch { errorMessage = readable(error) }
    }

    private func refreshSession(using refreshToken: String) async throws {
        guard let encoded = "grant_type=refresh_token&refresh_token=\(formEncode(refreshToken))".data(using: .utf8),
              let url = URL(string: "https://securetoken.googleapis.com/v1/token?key=\(HaloCommercialConfiguration.firebaseAPIKey)") else {
            throw HaloCommercialError.message("Firebase configuration is invalid.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = encoded
        let data = try await send(request)
        let result = try JSONDecoder().decode(FirebaseRefreshResponse.self, from: data)
        adopt(idToken: result.idToken, refreshToken: result.refreshToken,
              userID: result.userId, email: defaults.string(forKey: "HaloAccountEmail") ?? "",
              expiresIn: result.expiresIn)
    }

    private func loadProfile() async throws {
        guard !idToken.isEmpty else { return }
        let data = try await firebaseRequest(endpoint: "accounts:lookup", body: ["idToken": idToken])
        guard let user = try JSONDecoder().decode(FirebaseLookupResponse.self, from: data).users?.first else { return }
        userID = user.localId
        email = user.email ?? email
        emailVerified = user.emailVerified ?? false
        defaults.set(email, forKey: "HaloAccountEmail")
        isSignedIn = true
    }

    private func adopt(idToken: String, refreshToken: String, userID: String, email: String, expiresIn: String) {
        self.idToken = idToken
        self.userID = userID
        self.email = email
        tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn) ?? 3600)
        isSignedIn = true
        HaloKeychain.set(refreshToken, for: refreshKey)
        defaults.set(email, forKey: "HaloAccountEmail")
    }

    private func clearLocalSession() {
        HaloKeychain.remove(refreshKey)
        defaults.removeObject(forKey: "HaloAccountEmail")
        idToken = ""
        tokenExpiry = .distantPast
        isSignedIn = false
        email = ""
        userID = ""
        emailVerified = false
    }

    private func firebaseRequest(endpoint: String, body: [String: Any]) async throws -> Data {
        guard let url = URL(string: "https://identitytoolkit.googleapis.com/v1/\(endpoint)?key=\(HaloCommercialConfiguration.firebaseAPIKey)") else {
            throw HaloCommercialError.message("Firebase configuration is invalid.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await send(request)
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw HaloCommercialError.message("No response from Firebase.") }
        guard (200..<300).contains(http.statusCode) else {
            throw HaloCommercialError.message(firebaseErrorMessage(from: data) ?? "Firebase request failed (\(http.statusCode)).")
        }
        return data
    }

    private func firebaseErrorMessage(from data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = root["error"] as? [String: Any],
              let raw = error["message"] as? String else { return nil }
        switch raw {
        case "EMAIL_EXISTS": return "An account already exists with this email."
        case "EMAIL_NOT_FOUND": return "No Halo account exists with this email."
        case "INVALID_PASSWORD", "INVALID_LOGIN_CREDENTIALS": return "Incorrect email or password."
        case "USER_DISABLED": return "This account has been disabled."
        case "OPERATION_NOT_ALLOWED": return "Email/password sign-in is not enabled in Firebase."
        case "TOO_MANY_ATTEMPTS_TRY_LATER": return "Too many attempts. Please try again later."
        default: return raw.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func formEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+&="))) ?? value
    }

    private func readable(_ error: Error) -> String {
        (error as? HaloCommercialError)?.message ?? error.localizedDescription
    }
}

enum HaloLicenseState: Equatable {
    case unconfigured
    case inactive
    case checking
    case valid(plan: String?)
    case invalid(String)

    var title: String {
        switch self {
        case .unconfigured: return "Not configured"
        case .inactive: return "No license activated"
        case .checking: return "Checking license…"
        case .valid(let plan): return plan.map { "Licensed · \($0)" } ?? "Licensed"
        case .invalid: return "License needs attention"
        }
    }

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
}

struct HaloLicenseDetails: Equatable {
    var status: String = ""
    var plan: String = ""
    var expiresAt: Date?
    var activeSeats: Int?
    var seatLimit: Int?

    static let empty = HaloLicenseDetails()

    var statusTitle: String {
        guard !status.isEmpty else { return "Unknown" }
        return status.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var daysRemaining: Int? {
        guard let expiresAt else { return nil }
        return max(0, Int(ceil(expiresAt.timeIntervalSinceNow / 86_400)))
    }

    var activatedMacsTitle: String {
        guard let activeSeats else { return "Unavailable" }
        if let seatLimit { return "\(activeSeats) of \(seatLimit)" }
        return "\(activeSeats)"
    }
}

@MainActor
final class HaloLicenseManager: ObservableObject {
    static let shared = HaloLicenseManager()

    @Published private(set) var state: HaloLicenseState = .inactive
    @Published private(set) var licenseHint = ""
    @Published private(set) var details: HaloLicenseDetails = .empty
    @Published private(set) var isBusy = false
    @Published private(set) var isStartingTrial = false
    @Published var errorMessage: String?
    @Published var notice: String?

    private let licenseKeyKey = "licenseseat.licenseKey"
    private let fingerprintKey = "licenseseat.fingerprint"

    var isConfigured: Bool { HaloCommercialConfiguration.licenseSeatConfigured }
    var trialConfigured: Bool { HaloCommercialConfiguration.trialConfigured }

    func restoreAndValidate() async {
        guard isConfigured else { state = .unconfigured; details = .empty; return }
        guard let key = HaloKeychain.string(for: licenseKeyKey), !key.isEmpty else { state = .inactive; details = .empty; return }
        licenseHint = Self.hint(key)
        await validate()
    }

    func startTrial() async {
        guard trialConfigured else {
            errorMessage = "Halo trials are not configured on this build yet."
            return
        }
        guard HaloAccountManager.shared.isSignedIn else {
            errorMessage = "Sign in to your Halo account before starting a trial."
            return
        }
        guard HaloAccountManager.shared.emailVerified else {
            errorMessage = "Verify your email before starting the free trial."
            return
        }
        guard let url = URL(string: HaloCommercialConfiguration.trialEndpoint),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || (scheme == "http" && ["localhost", "127.0.0.1"].contains(url.host ?? "")) else {
            errorMessage = "The Halo trial service URL is invalid."
            return
        }

        isStartingTrial = true
        errorMessage = nil
        notice = nil
        defer { isStartingTrial = false }

        do {
            let token = try await HaloAccountManager.shared.validIDToken()
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "platform": "macOS",
                "device_name": Host.current().localizedName ?? "Mac"
            ])

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw HaloCommercialError.message("No response from the Halo trial service.")
            }
            let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            guard (200..<300).contains(http.statusCode) else {
                let message = ((root?["error"] as? [String: Any])?["message"] as? String)
                    ?? (root?["message"] as? String)
                    ?? "Unable to start the Halo trial (\(http.statusCode))."
                throw HaloCommercialError.message(message)
            }
            guard let key = (root?["license_key"] as? String) ?? (root?["licenseKey"] as? String),
                  !key.isEmpty else {
                throw HaloCommercialError.message("The trial service did not return a license.")
            }

            await activate(key)
            if state.isValid {
                notice = "Your 14-day Halo trial is active."
            }
        } catch {
            errorMessage = readable(error)
        }
    }

    func activate(_ key: String) async {
        guard isConfigured else { state = .unconfigured; errorMessage = "LicenseSeat is not configured yet."; return }
        let cleaned = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 6 else { errorMessage = "Enter your LicenseSeat key."; return }
        isBusy = true; state = .checking; errorMessage = nil; notice = nil
        defer { isBusy = false }
        do {
            let payload: [String: Any] = [
                "license_key": cleaned,
                "fingerprint": fingerprint(),
                "device_name": Host.current().localizedName ?? "Mac"
            ]
            let json = try await request(endpoint: "activate", body: payload)
            let parsed = parseValidation(json)
            guard parsed.valid else { throw HaloCommercialError.message(parsed.message ?? "License activation was rejected.") }
            HaloKeychain.set(cleaned, for: licenseKeyKey)
            licenseHint = Self.hint(cleaned)
            details = parsed.details
            state = .valid(plan: parsed.details.plan.isEmpty ? nil : parsed.details.plan)
            notice = "License activated on this Mac."
        } catch {
            state = .invalid(readable(error))
            errorMessage = readable(error)
        }
    }

    func validate() async {
        guard isConfigured else { state = .unconfigured; return }
        guard let key = HaloKeychain.string(for: licenseKeyKey), !key.isEmpty else { state = .inactive; return }
        isBusy = true; state = .checking; errorMessage = nil
        defer { isBusy = false }
        do {
            let json = try await request(endpoint: "validate", body: [
                "license_key": key,
                "fingerprint": fingerprint()
            ])
            let parsed = parseValidation(json)
            details = parsed.details
            if parsed.valid {
                state = .valid(plan: parsed.details.plan.isEmpty ? nil : parsed.details.plan)
                licenseHint = Self.hint(key)
            } else {
                state = .invalid(parsed.message ?? "This license is not valid for this Mac.")
            }
        } catch {
            details = .empty
            state = .invalid(readable(error))
            errorMessage = readable(error)
        }
    }

    func deactivate() async {
        guard isConfigured else { return }
        guard let key = HaloKeychain.string(for: licenseKeyKey), !key.isEmpty else { state = .inactive; return }
        isBusy = true; errorMessage = nil; notice = nil
        defer { isBusy = false }
        do {
            _ = try await request(endpoint: "deactivate", body: [
                "license_key": key,
                "fingerprint": fingerprint()
            ])
            HaloKeychain.remove(licenseKeyKey)
            licenseHint = ""
            details = .empty
            state = .inactive
            notice = "This Mac has been deactivated."
        } catch { errorMessage = readable(error) }
    }

    func clearLocalLicense() {
        HaloKeychain.remove(licenseKeyKey)
        licenseHint = ""
        details = .empty
        state = isConfigured ? .inactive : .unconfigured
        notice = "Local license data cleared."
    }

    private func fingerprint() -> String {
        if let existing = HaloKeychain.string(for: fingerprintKey), !existing.isEmpty { return existing }
        let value = "halo-\(UUID().uuidString.lowercased())"
        HaloKeychain.set(value, for: fingerprintKey)
        return value
    }

    private func request(endpoint: String, body: [String: Any]) async throws -> [String: Any] {
        let slugAllowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        guard let slug = HaloCommercialConfiguration.licenseSeatProductSlug.addingPercentEncoding(withAllowedCharacters: slugAllowed),
              let url = URL(string: "https://licenseseat.com/api/v1/products/\(slug)/licenses/\(endpoint)") else {
            throw HaloCommercialError.message("LicenseSeat product configuration is invalid.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(HaloCommercialConfiguration.licenseSeatPublishableKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw HaloCommercialError.message("No response from LicenseSeat.") }
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw HaloCommercialError.message("LicenseSeat returned an unreadable response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = ((root["error"] as? [String: Any])?["message"] as? String)
                ?? (root["message"] as? String)
                ?? "LicenseSeat request failed (\(http.statusCode))."
            throw HaloCommercialError.message(message)
        }
        return root
    }

    private func parseValidation(_ root: [String: Any]) -> (valid: Bool, details: HaloLicenseDetails, message: String?) {
        let license = (root["license"] as? [String: Any])
            ?? ((root["activation"] as? [String: Any])?["license"] as? [String: Any])
        let status = (license?["status"] as? String) ?? ""
        let plan = (license?["plan_key"] as? String) ?? (license?["plan"] as? String) ?? ""
        let activeSeats = intValue(license?["active_seats"])
        let seatLimit = intValue(license?["seat_limit"])

        var expiresAt = dateValue(license?["expires_at"])
        if expiresAt == nil, let entitlements = license?["active_entitlements"] as? [[String: Any]] {
            let expirations = entitlements.compactMap { dateValue($0["expires_at"]) }
            expiresAt = expirations.min()
        }

        let explicitValid = root["valid"] as? Bool
        let object = root["object"] as? String
        let inferredValid = status.lowercased() == "active" || object == "activation"
        let valid = explicitValid ?? inferredValid
        let message = (root["message"] as? String)
            ?? ((root["error"] as? [String: Any])?["message"] as? String)
        let details = HaloLicenseDetails(
            status: status.isEmpty ? (valid ? "active" : "invalid") : status,
            plan: plan,
            expiresAt: expiresAt,
            activeSeats: activeSeats,
            seatLimit: seatLimit
        )
        return (valid, details, message)
    }

    private func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }

    private func dateValue(_ value: Any?) -> Date? {
        guard let raw = value as? String, !raw.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) { return date }
        return ISO8601DateFormatter().date(from: raw)
    }

    private static func hint(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else { return "••••" }
        return "••••-\(trimmed.suffix(4))"
    }

    private func readable(_ error: Error) -> String {
        (error as? HaloCommercialError)?.message ?? error.localizedDescription
    }
}

private enum HaloCommercialError: Error {
    case message(String)
    var message: String {
        switch self { case .message(let value): return value }
    }
}
