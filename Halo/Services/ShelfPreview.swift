import AppKit
import Quartz
import SwiftUI
import Combine
import CoreGraphics
import QuartzCore

@MainActor
final class ShelfPreview: NSObject {
    private var window: NSWindow?
    private var preview: QLPreviewView?
    func show(_ url: URL) {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 520), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            let preview = QLPreviewView(frame: window.contentView!.bounds, style: .normal)!
            preview.autoresizingMask = [.width, .height]
            window.contentView = preview
            window.center(); self.window = window; self.preview = preview
        }
        preview?.previewItem = url as NSURL
        window?.title = url.lastPathComponent
        NSApp.activate(ignoringOtherApps: true); window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Environmental Interface

/// EI is deliberately independent from CI. CI decides what the opened notch does;
/// EI adds ambient life around/inside it and can coexist with any CI.
enum EIMode: String, Codable, CaseIterable, Identifiable {
    case off = "Off", pet = "Pet", plant = "Plant", simulation = "Simulation"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .off: return "circle.slash"
        case .pet: return "pawprint.fill"
        case .plant: return "leaf.fill"
        case .simulation: return "building.2.fill"
        }
    }
}

enum EIActivityLevel: String, Codable, CaseIterable, Identifiable {
    case subtle = "Subtle", balanced = "Balanced", expressive = "Expressive"
    var id: String { rawValue }
    var probabilityMultiplier: Double {
        switch self { case .subtle: return 0.42; case .balanced: return 0.72; case .expressive: return 1 }
    }
    var spontaneousRange: ClosedRange<TimeInterval> {
        switch self {
        case .subtle: return 8 * 60 ... 20 * 60
        case .balanced: return 4 * 60 ... 12 * 60
        case .expressive: return 2 * 60 ... 7 * 60
        }
    }
}

enum EIPixelDisplayPreset: String, Codable, CaseIterable, Identifiable {
    case clean = "Clean Pixel", lcd = "Pixel LCD", monochrome = "Monochrome LCD", crt = "Retro CRT"
    var id: String { rawValue }
}
enum EIPetKind: String, Codable, CaseIterable, Identifiable { case cat = "Cat", dog = "Dog", fox = "Fox"; var id: String { rawValue } }
enum EIPlantKind: String, Codable, CaseIterable, Identifiable { case fern = "Fern", flower = "Flower", bonsai = "Bonsai"; var id: String { rawValue } }
enum EISimulationKind: String, Codable, CaseIterable, Identifiable { case tinyCity = "Tiny City"; var id: String { rawValue } }

struct EIInputSettings: Codable, Equatable {
    var timeOfDay = true
    var userActivity = true
    var longWorkSessions = true
    var idleState = true
    var musicPlayback = true
    var weather = true
    var activeApplication = true
    var ciState = true
    var systemEvents = true
}

struct EISettings: Codable, Equatable {
    var version = 1
    var mode: EIMode = .off
    var activityLevel: EIActivityLevel = .balanced
    var inputs = EIInputSettings()
    var displayPreset: EIPixelDisplayPreset = .clean
    var pixelGrid = false
    var pixelGlow = true
    var scanlines = false
    var ghosting = false
    var brightnessVariation = false
    var petKind: EIPetKind = .cat
    var petScale = 1.0
    var petInteraction = true
    var petLooksAtCursor = true
    var petHidesWhenApproached = false
    var petOccasionalObjects = true
    var petResident = false
    var petPrimaryColor = WidgetColor(red: 0.76, green: 0.78, blue: 0.82)
    var petAccentColor = WidgetColor(red: 0.96, green: 0.74, blue: 0.28)
    var plantKind: EIPlantKind = .fern
    var plantColor = WidgetColor(red: 0.31, green: 0.86, blue: 0.47)
    var plantPotColor = WidgetColor(red: 0.63, green: 0.34, blue: 0.20)
    var simulationKind: EISimulationKind = .tinyCity
    var simulationAccentColor = WidgetColor(red: 0.34, green: 0.77, blue: 1)
    var longWorkThresholdMinutes = 90.0
    func normalized() -> EISettings {
        var v = self
        v.petScale = min(1.6, max(0.7, petScale))
        v.longWorkThresholdMinutes = min(240, max(30, longWorkThresholdMinutes))
        return v
    }
}

@MainActor
final class EISettingsStore: ObservableObject {
    static let shared = EISettingsStore()
    private let defaults: UserDefaults
    private let key = "HaloEnvironmentalInterface.v1"
    @Published var settings: EISettings { didSet { persist() } }
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key), let saved = try? JSONDecoder().decode(EISettings.self, from: data), saved.version == 1 {
            settings = saved.normalized()
        } else { settings = EISettings() }
    }
    func reset() { settings = EISettings() }
    private func persist() {
        guard let data = try? JSONEncoder().encode(settings.normalized()) else { return }
        defaults.set(data, forKey: key)
    }
}

// MARK: Environment

enum EITimeOfDay: String, Codable, Equatable {
    case morning, day, evening, night
    static func current(at date: Date = Date(), calendar: Calendar = .current) -> EITimeOfDay {
        switch calendar.component(.hour, from: date) {
        case 5..<12: return .morning
        case 12..<17: return .day
        case 17..<22: return .evening
        default: return .night
        }
    }
}
struct EIWeatherState: Codable, Equatable { var condition: String; var isRaining: Bool; var temperatureCelsius: Double? }
struct EIApplicationContext: Codable, Equatable { var bundleIdentifier: String; var name: String }
struct EIContextInterface: Codable, Equatable { var identifier: String; var name: String; var priority: Double }
struct EISystemContext: Codable, Equatable { var battery: Int?; var charging: Bool; var lowPowerMode: Bool }
struct EIEnvironment: Equatable {
    var timeOfDay: EITimeOfDay = .day
    var activityDuration: TimeInterval = 0
    var idleDuration: TimeInterval = 0
    var isMusicPlaying = false
    var musicIntensity: Double?
    var weather: EIWeatherState?
    var activeApplication: EIApplicationContext?
    var activeCI: EIContextInterface?
    var systemState = EISystemContext(battery: nil, charging: false, lowPowerMode: false)
}

enum EIEnvironmentBridge {
    @MainActor static func updateWeather(_ weather: EIWeatherState?) { EnvironmentalInterfaceEngine.shared.updateWeather(weather) }
    /// Allows CI/features to expose semantic reactions such as buildStarted/buildSucceeded/buildFailed without app coupling.
    @MainActor static func emit(_ name: String) { EnvironmentalInterfaceEngine.shared.emitExternalEvent(name) }
}

// MARK: Placement / exclusion

enum EIPlacementEdge: String, Codable, CaseIterable { case left, right, underNotch, bottomLeft, bottomRight }
struct EIPlacementContext: Equatable {
    var availableRegions: [CGRect]
    var preferredEdges: [EIPlacementEdge]
    var contentExclusionRegions: [CGRect]
    static let automatic = EIPlacementContext(availableRegions: [], preferredEdges: [], contentExclusionRegions: [])
}
@MainActor
final class EIPlacementRegistry {
    static let shared = EIPlacementRegistry()
    private var contexts: [String: EIPlacementContext] = [:]
    func set(_ context: EIPlacementContext?, for screenID: String) {
        if let context { contexts[screenID] = context } else { contexts.removeValue(forKey: screenID) }
        NotificationCenter.default.post(name: .init("HaloEIPlacementChanged"), object: nil, userInfo: ["screen": screenID])
    }
    func context(for screenID: String) -> EIPlacementContext? { contexts[screenID] }
}

// MARK: Events / scheduler

enum EIEventKind: String, Codable, CaseIterable {
    case lateNight, longWorkSession, userReturned, musicStarted, musicStopped, weatherChanged, rainStarted
    case ciActivated, ciDeactivated, applicationChanged, longIdlePeriod, systemWoke, spontaneous, userInteraction, external
}
struct EIEvent: Identifiable, Equatable { let id = UUID(); let kind: EIEventKind; let date: Date; var detail: String? }
enum EIReactionKind: String, Codable, CaseIterable {
    case petPeekUnder, petPeekLeft, petPeekRight, petLookAround, petCoffee, petSleep, petDance, petCelebrate, petGreet, petUmbrella, petPat, petSnack
    case plantSway, plantPerk, plantGrowLeaf, plantBloom, plantRain, plantNight
    case cityTraffic, cityNight, cityRain, cityMusic, cityBusy
}
struct EIReaction: Identifiable, Equatable {
    let id = UUID(); var kind: EIReactionKind; var started: Date; var duration: TimeInterval; var priority: Int; var source: EIEventKind
    var ends: Date { started.addingTimeInterval(duration) }
    func progress(at date: Date) -> Double { min(1, max(0, date.timeIntervalSince(started) / max(0.01, duration))) }
}
private struct EIReactionCandidate { var kind: EIReactionKind; var priority: Int; var cooldown: TimeInterval; var probability: Double; var duration: TimeInterval }
struct EIPetPersistentState: Codable, Equatable { var interactionCount = 0; var lastInteraction: Date? }
struct EIPlantPersistentState: Codable, Equatable { var createdAt = Date(); var lastUpdated = Date(); var growth = 0.08; var bonusGrowth = 0.0 }
struct EISimulationPersistentState: Codable, Equatable { var seed = Int.random(in: 1...999_999); var createdAt = Date(); var activityMoments = 0 }
struct EIPersistentState: Codable, Equatable { var version = 1; var pet = EIPetPersistentState(); var plant = EIPlantPersistentState(); var simulation = EISimulationPersistentState() }

@MainActor
final class EnvironmentalInterfaceEngine: ObservableObject {
    static let shared = EnvironmentalInterfaceEngine()
    @Published private(set) var environment = EIEnvironment()
    @Published private(set) var currentReaction: EIReaction?
    @Published private(set) var persistentState: EIPersistentState
    @Published private(set) var retroGameRequested = false
    @Published private(set) var anyHaloSurfaceExpanded = false
    private weak var workspace: WorkspaceStore?
    private let settingsStore = EISettingsStore.shared
    private let defaults = UserDefaults.standard
    private let stateKey = "HaloEnvironmentalInterfaceState.v1"
    private var loopTask: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()
    private var previousEnvironment: EIEnvironment?
    private var workSessionStart = Date()
    private var emittedLongWorkSession = false
    private var cooldowns: [EIReactionKind: Date] = [:]
    private var reactionHistory: [EIReactionKind] = []
    private var nextSpontaneousDate = Date.distantFuture
    private var weather: EIWeatherState?
    private var started = false
    private var lastMode: EIMode = .off
    private var lastActivity: EIActivityLevel = .balanced

    private init() {
        if let data = defaults.data(forKey: stateKey), let saved = try? JSONDecoder().decode(EIPersistentState.self, from: data), saved.version == 1 {
            persistentState = saved
        } else { persistentState = EIPersistentState() }
    }
    var settings: EISettings { settingsStore.settings }
    var shouldRender: Bool {
        switch settings.mode { case .off: return false; case .pet: return settings.petResident || currentReaction != nil; case .plant, .simulation: return true }
    }

    func start(workspace: WorkspaceStore) {
        self.workspace = workspace
        guard !started else { settingsDidChange(settingsStore.settings); return }
        started = true
        settingsStore.$settings.removeDuplicates().receive(on: RunLoop.main).sink { [weak self] in self?.settingsDidChange($0) }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: .init("HaloRetroGameToggle")).receive(on: RunLoop.main).sink { [weak self] _ in
            guard let self, self.defaults.object(forKey: "HaloContextRetroEnabled") as? Bool ?? false else { return }
            self.retroGameRequested.toggle(); self.refreshNow()
        }.store(in: &subscriptions)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification).receive(on: RunLoop.main).sink { [weak self] _ in
            guard let self, self.settings.inputs.systemEvents else { return }
            self.emit(EIEvent(kind: .systemWoke, date: Date()), force: true)
        }.store(in: &subscriptions)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification).receive(on: RunLoop.main).sink { [weak self] _ in self?.refreshNow() }.store(in: &subscriptions)
        refreshPlantProgress(); settingsDidChange(settingsStore.settings)
    }
    func stop() { loopTask?.cancel(); loopTask = nil; subscriptions.removeAll(); persistState(); started = false; workspace = nil }
    func setAnyHaloSurfaceExpanded(_ value: Bool) { guard anyHaloSurfaceExpanded != value else { return }; anyHaloSurfaceExpanded = value; refreshNow() }
    func updateWeather(_ value: EIWeatherState?) { weather = value; refreshNow() }
    func emitExternalEvent(_ name: String) {
        let value = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)); guard !value.isEmpty else { return }
        emit(EIEvent(kind: .external, date: Date(), detail: value))
    }
    func preview(_ kind: EIReactionKind, duration: TimeInterval = 4) {
        currentReaction = EIReaction(kind: kind, started: Date(), duration: duration, priority: 100, source: .userInteraction)
        cooldowns[kind] = Date().addingTimeInterval(2); postReactionChanged()
    }
    func interact(_ kind: EIReactionKind) {
        guard settings.mode == .pet, [.petPat, .petSnack, .petGreet].contains(kind) else { return }
        persistentState.pet.interactionCount += 1; persistentState.pet.lastInteraction = Date(); persistState()
        preview(kind, duration: kind == .petSnack ? 3.8 : 2.8)
    }

    private func settingsDidChange(_ value: EISettings) {
        let modeChanged = value.mode != lastMode, activityChanged = value.activityLevel != lastActivity
        lastMode = value.mode; lastActivity = value.activityLevel
        if value.mode == .off {
            loopTask?.cancel(); loopTask = nil; currentReaction = nil
            NotificationCenter.default.post(name: .init("HaloEIVisibilityChanged"), object: nil); return
        }
        if loopTask == nil { startLoop() }
        if modeChanged || activityChanged { scheduleNextSpontaneous(from: Date()) }
        refreshNow()
        if modeChanged {
            let kind: EIReactionKind = value.mode == .pet ? .petPeekUnder : value.mode == .plant ? .plantSway : .cityTraffic
            currentReaction = EIReaction(kind: kind, started: Date(), duration: 3.5, priority: 20, source: .spontaneous)
        }
        NotificationCenter.default.post(name: .init("HaloEIVisibilityChanged"), object: nil)
    }
    private func startLoop() {
        loopTask?.cancel()
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.tick()
                let interval: UInt64
                if self.currentReaction != nil { interval = 1_000_000_000 }
                else if self.settings.mode == .pet && !self.settings.petResident { interval = 10_000_000_000 }
                else { interval = 4_000_000_000 }
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }
    private func refreshNow() { guard settings.mode != .off else { return }; Task { [weak self] in await self?.tick() } }
    private func tick() async {
        guard settings.mode != .off, let workspace else { return }
        let now = Date()
        if let reaction = currentReaction, reaction.ends <= now { currentReaction = nil; postReactionChanged() }
        let idle: TimeInterval
        if settings.inputs.idleState || settings.inputs.userActivity || settings.inputs.longWorkSessions {
            let raw = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null)
            idle = min(24 * 3600, max(0, raw.isFinite ? raw : 0))
        } else { idle = 0 }
        if idle > 15 * 60 { workSessionStart = now; emittedLongWorkSession = false }
        let app: EIApplicationContext?
        if settings.inputs.activeApplication, let front = NSWorkspace.shared.frontmostApplication {
            app = EIApplicationContext(bundleIdentifier: front.bundleIdentifier ?? "", name: front.localizedName ?? "Application")
        } else { app = nil }
        let playing = settings.inputs.musicPlayback && workspace.media.isPlaying
        let spectrum = AudioSpectrumService.shared.snapshot()
        let next = EIEnvironment(timeOfDay: settings.inputs.timeOfDay ? .current(at: now) : .day,
                                 activityDuration: settings.inputs.userActivity || settings.inputs.longWorkSessions ? max(0, now.timeIntervalSince(workSessionStart)) : 0,
                                 idleDuration: idle,
                                 isMusicPlaying: playing,
                                 musicIntensity: playing && spectrum.available ? spectrum.overall : nil,
                                 weather: settings.inputs.weather ? weather : nil,
                                 activeApplication: app,
                                 activeCI: settings.inputs.ciState ? resolveActiveCI(workspace) : nil,
                                 systemState: EISystemContext(battery: workspace.system.battery, charging: workspace.system.charging, lowPowerMode: workspace.system.lowPower))
        detectEvents(previousEnvironment, next, now)
        environment = next; previousEnvironment = next; refreshPlantProgress(now: now)
        if currentReaction == nil, now >= nextSpontaneousDate { emit(EIEvent(kind: .spontaneous, date: now)); scheduleNextSpontaneous(from: now) }
    }

    private func resolveActiveCI(_ workspace: WorkspaceStore) -> EIContextInterface? {
        guard anyHaloSurfaceExpanded else { return nil }
        var candidates: [(EIContextInterface, Int)] = []
        if defaults.object(forKey: "HaloContextRetroEnabled") as? Bool ?? false, retroGameRequested {
            let p = defaults.object(forKey: "HaloContextRetroPriority") == nil ? 80 : defaults.double(forKey: "HaloContextRetroPriority")
            candidates.append((EIContextInterface(identifier: "retro", name: "Retro Game CI", priority: p), 3))
        }
        if workspace.effectiveLayout.contextMusic?.enabled == true, workspace.media.isPlaying {
            let p = defaults.object(forKey: "HaloContextMusicPriority") == nil ? 60 : defaults.double(forKey: "HaloContextMusicPriority")
            candidates.append((EIContextInterface(identifier: "music", name: "Music CI", priority: p), 2))
        }
        let btEnabled = defaults.object(forKey: "HaloContextBluetoothEnabled") as? Bool ?? false
        let changes = defaults.object(forKey: "HaloContextBluetoothShowOnChanges") as? Bool ?? true
        let connected = defaults.object(forKey: "HaloContextBluetoothShowWhileConnected") as? Bool ?? true
        if btEnabled && ((changes && workspace.bluetooth.lastEvent != nil) || (connected && !workspace.bluetooth.connectedDevices.isEmpty)) {
            let p = defaults.object(forKey: "HaloContextBluetoothPriority") == nil ? 50 : defaults.double(forKey: "HaloContextBluetoothPriority")
            candidates.append((EIContextInterface(identifier: "bluetooth", name: "Bluetooth CI", priority: p), 1))
        }
        return candidates.max { a, b in a.0.priority == b.0.priority ? a.1 < b.1 : a.0.priority < b.0.priority }?.0
    }
    private func detectEvents(_ previous: EIEnvironment?, _ current: EIEnvironment, _ now: Date) {
        guard let previous else { if current.timeOfDay == .night { emit(EIEvent(kind: .lateNight, date: now)) }; return }
        if settings.inputs.timeOfDay, previous.timeOfDay != .night, current.timeOfDay == .night { emit(EIEvent(kind: .lateNight, date: now)) }
        let threshold = settings.longWorkThresholdMinutes * 60
        if settings.inputs.longWorkSessions, !emittedLongWorkSession, previous.activityDuration < threshold, current.activityDuration >= threshold {
            emittedLongWorkSession = true; emit(EIEvent(kind: .longWorkSession, date: now))
        }
        if settings.inputs.idleState {
            if previous.idleDuration >= 300, current.idleDuration < 20 { workSessionStart = now; emittedLongWorkSession = false; emit(EIEvent(kind: .userReturned, date: now)) }
            if previous.idleDuration < 900, current.idleDuration >= 900 { emit(EIEvent(kind: .longIdlePeriod, date: now)) }
        }
        if settings.inputs.musicPlayback, previous.isMusicPlaying != current.isMusicPlaying { emit(EIEvent(kind: current.isMusicPlaying ? .musicStarted : .musicStopped, date: now)) }
        if settings.inputs.weather, previous.weather != current.weather {
            emit(EIEvent(kind: .weatherChanged, date: now))
            if previous.weather?.isRaining != true, current.weather?.isRaining == true { emit(EIEvent(kind: .rainStarted, date: now)) }
        }
        if settings.inputs.ciState, previous.activeCI != current.activeCI {
            emit(EIEvent(kind: current.activeCI == nil ? .ciDeactivated : .ciActivated, date: now, detail: current.activeCI?.identifier ?? previous.activeCI?.identifier))
        }
        if settings.inputs.activeApplication, previous.activeApplication?.bundleIdentifier != current.activeApplication?.bundleIdentifier {
            emit(EIEvent(kind: .applicationChanged, date: now, detail: current.activeApplication?.bundleIdentifier))
        }
    }
    private func emit(_ event: EIEvent, force: Bool = false) {
        guard settings.mode != .off else { return }
        let candidates = reactionCandidates(event).filter {
            (settings.petOccasionalObjects || ![EIReactionKind.petCoffee, .petUmbrella].contains($0.kind)) &&
            (force || (cooldowns[$0.kind] ?? .distantPast) <= event.date) &&
            (!reactionHistory.suffix(2).contains($0.kind) || event.kind == .userInteraction || event.kind == .systemWoke)
        }
        let currentPriority = currentReaction?.priority ?? -1
        let eligible = candidates.filter { force || currentReaction == nil || $0.priority > currentPriority }
        guard !eligible.isEmpty else { return }
        let selectedPool = eligible.filter { force || Double.random(in: 0...1) <= min(1, $0.probability * settings.activityLevel.probabilityMultiplier) }
        guard let selected = (selectedPool.isEmpty && force ? eligible : selectedPool).randomElement() else { return }
        currentReaction = EIReaction(kind: selected.kind, started: event.date, duration: selected.duration, priority: selected.priority, source: event.kind)
        cooldowns[selected.kind] = event.date.addingTimeInterval(selected.cooldown)
        reactionHistory.append(selected.kind); if reactionHistory.count > 8 { reactionHistory.removeFirst(reactionHistory.count - 8) }
        applyPersistentEffect(selected.kind); postReactionChanged()
    }
    private func reactionCandidates(_ event: EIEvent) -> [EIReactionCandidate] {
        switch settings.mode {
        case .off: return []
        case .pet:
            switch event.kind {
            case .lateNight: return [.init(kind: .petSleep, priority: 72, cooldown: 2700, probability: 0.85, duration: 7), .init(kind: .petCoffee, priority: 64, cooldown: 2100, probability: 0.45, duration: 5)]
            case .longWorkSession: return [.init(kind: .petCoffee, priority: 78, cooldown: 3600, probability: 0.9, duration: 6), .init(kind: .petSleep, priority: 68, cooldown: 3000, probability: 0.42, duration: 7)]
            case .userReturned, .systemWoke: return [.init(kind: .petGreet, priority: 82, cooldown: 480, probability: 0.95, duration: 4)]
            case .musicStarted: return [.init(kind: .petDance, priority: 58, cooldown: 600, probability: 0.76, duration: 7)]
            case .rainStarted: return [.init(kind: .petUmbrella, priority: 62, cooldown: 1200, probability: 0.85, duration: 6)]
            case .ciActivated: return [.init(kind: .petPeekLeft, priority: 36, cooldown: 360, probability: 0.55, duration: 3.6), .init(kind: .petPeekRight, priority: 36, cooldown: 360, probability: 0.55, duration: 3.6)]
            case .external:
                let name = event.detail?.lowercased() ?? ""
                if name.contains("succeed") || name.contains("complete") || name.contains("passed") { return [.init(kind: .petCelebrate, priority: 70, cooldown: 240, probability: 0.95, duration: 5)] }
                if name.contains("fail") || name.contains("error") { return [.init(kind: .petLookAround, priority: 66, cooldown: 240, probability: 0.9, duration: 5)] }
                return [.init(kind: .petPeekUnder, priority: 42, cooldown: 180, probability: 0.75, duration: 4)]
            case .spontaneous: return [.init(kind: .petPeekUnder, priority: 18, cooldown: 420, probability: 0.75, duration: 4), .init(kind: .petLookAround, priority: 16, cooldown: 360, probability: 0.78, duration: 5), .init(kind: .petPeekLeft, priority: 16, cooldown: 480, probability: 0.42, duration: 4), .init(kind: .petPeekRight, priority: 16, cooldown: 480, probability: 0.42, duration: 4)]
            default: return []
            }
        case .plant:
            switch event.kind {
            case .lateNight: return [.init(kind: .plantNight, priority: 40, cooldown: 1800, probability: 1, duration: 8)]
            case .longWorkSession: return [.init(kind: .plantGrowLeaf, priority: 52, cooldown: 3600, probability: 0.7, duration: 6), .init(kind: .plantBloom, priority: 48, cooldown: 7200, probability: 0.3, duration: 7)]
            case .rainStarted: return [.init(kind: .plantRain, priority: 48, cooldown: 1200, probability: 0.95, duration: 7)]
            case .musicStarted: return [.init(kind: .plantSway, priority: 22, cooldown: 480, probability: 0.6, duration: 8)]
            case .userReturned, .external: return [.init(kind: .plantPerk, priority: 28, cooldown: 480, probability: 0.7, duration: 4)]
            case .spontaneous: return [.init(kind: .plantSway, priority: 10, cooldown: 360, probability: 0.8, duration: 6)]
            default: return []
            }
        case .simulation:
            switch event.kind {
            case .lateNight: return [.init(kind: .cityNight, priority: 42, cooldown: 2700, probability: 1, duration: 9)]
            case .rainStarted: return [.init(kind: .cityRain, priority: 52, cooldown: 1200, probability: 1, duration: 9)]
            case .musicStarted: return [.init(kind: .cityMusic, priority: 30, cooldown: 600, probability: 0.75, duration: 8)]
            case .userReturned: return [.init(kind: .cityBusy, priority: 36, cooldown: 480, probability: 0.75, duration: 6)]
            case .external: return [.init(kind: .cityBusy, priority: 28, cooldown: 240, probability: 0.6, duration: 5)]
            case .spontaneous: return [.init(kind: .cityTraffic, priority: 10, cooldown: 240, probability: 0.9, duration: 7)]
            default: return []
            }
        }
    }
    private func applyPersistentEffect(_ kind: EIReactionKind) {
        switch kind {
        case .plantGrowLeaf: persistentState.plant.bonusGrowth = min(0.18, persistentState.plant.bonusGrowth + 0.004)
        case .plantBloom: persistentState.plant.bonusGrowth = min(0.18, persistentState.plant.bonusGrowth + 0.007)
        case .plantRain: persistentState.plant.bonusGrowth = min(0.18, persistentState.plant.bonusGrowth + 0.002)
        case .cityBusy, .cityMusic, .cityTraffic: persistentState.simulation.activityMoments += 1
        default: break
        }
        persistState()
    }
    private func refreshPlantProgress(now: Date = Date()) {
        var plant = persistentState.plant; let elapsed = max(0, now.timeIntervalSince(plant.lastUpdated)); guard elapsed >= 300 else { return }
        plant.growth = min(1, plant.growth + elapsed / (10 * 24 * 3600)); plant.lastUpdated = now; persistentState.plant = plant; persistState()
    }
    private func scheduleNextSpontaneous(from date: Date) { let r = settings.activityLevel.spontaneousRange; nextSpontaneousDate = date.addingTimeInterval(Double.random(in: r)) }
    private func postReactionChanged() { NotificationCenter.default.post(name: .init("HaloEIReactionChanged"), object: nil) }
    private func persistState() { if let data = try? JSONEncoder().encode(persistentState) { defaults.set(data, forKey: stateKey) } }
}

// MARK: Shared low-resolution pixel renderer

struct EIPixel { var x: Int; var y: Int; var width = 1; var height = 1; var color: Color; var opacity = 1.0 }
struct EIPixelScene { var columns: Int; var rows: Int; var pixels: [EIPixel]; var background: Color? = nil }

struct PixelDisplayRenderer: View {
    let scene: EIPixelScene
    let preset: EIPixelDisplayPreset
    var pixelGrid = false, glow = false, scanlines = false, ghosting = false, brightnessVariation = false
    var phase = 0.0
    var body: some View {
        GeometryReader { proxy in
            let scale = max(1, floor(min(proxy.size.width / CGFloat(max(1, scene.columns)), proxy.size.height / CGFloat(max(1, scene.rows)))))
            let render = CGSize(width: CGFloat(scene.columns) * scale, height: CGFloat(scene.rows) * scale)
            let origin = CGPoint(x: floor((proxy.size.width - render.width) / 2), y: floor((proxy.size.height - render.height) / 2))
            ZStack {
                if ghosting && preset != .clean { pixels(scale, CGPoint(x: origin.x + 1, y: origin.y + 1)).opacity(0.16) }
                pixels(scale, origin).brightness(brightnessVariation && preset != .clean ? sin(phase * 1.4) * 0.012 : 0)
                    .shadow(color: glow && preset != .clean ? Color.white.opacity(0.16) : .clear, radius: glow && preset != .clean ? 2.5 : 0)
                if pixelGrid && preset != .clean { grid(scale, origin, render) }
                if scanlines && preset != .clean { scanline(scale, origin, render) }
            }.frame(width: proxy.size.width, height: proxy.size.height)
        }.drawingGroup(opaque: false, colorMode: .linear)
    }
    private func pixels(_ scale: CGFloat, _ origin: CGPoint) -> some View {
        Canvas(rendersAsynchronously: true) { c, _ in
            if let bg = scene.background { c.fill(Path(CGRect(x: origin.x, y: origin.y, width: CGFloat(scene.columns) * scale, height: CGFloat(scene.rows) * scale)), with: .color(bg)) }
            for p in scene.pixels {
                c.fill(Path(CGRect(x: origin.x + CGFloat(p.x) * scale, y: origin.y + CGFloat(p.y) * scale, width: CGFloat(p.width) * scale, height: CGFloat(p.height) * scale)), with: .color(p.color.opacity(p.opacity)))
            }
        }
    }
    private func grid(_ scale: CGFloat, _ origin: CGPoint, _ size: CGSize) -> some View {
        Canvas { c, _ in
            guard scale >= 3 else { return }; let color = Color.black.opacity(preset == .crt ? 0.14 : 0.075)
            for x in 0...scene.columns { let v = origin.x + CGFloat(x) * scale; var p = Path(); p.move(to: CGPoint(x: v, y: origin.y)); p.addLine(to: CGPoint(x: v, y: origin.y + size.height)); c.stroke(p, with: .color(color), lineWidth: 0.5) }
            for y in 0...scene.rows { let v = origin.y + CGFloat(y) * scale; var p = Path(); p.move(to: CGPoint(x: origin.x, y: v)); p.addLine(to: CGPoint(x: origin.x + size.width, y: v)); c.stroke(p, with: .color(color), lineWidth: 0.5) }
        }.allowsHitTesting(false)
    }
    private func scanline(_ scale: CGFloat, _ origin: CGPoint, _ size: CGSize) -> some View {
        Canvas { c, _ in var y = origin.y + max(2, scale * 2); while y < origin.y + size.height { c.fill(Path(CGRect(x: origin.x, y: y, width: size.width, height: max(0.5, scale * 0.16))), with: .color(Color.black.opacity(preset == .crt ? 0.22 : 0.10))); y += max(2, scale * 2) } }.allowsHitTesting(false)
    }
}

private struct EIScenePalette {
    var foreground: Color; var secondary: Color; var highlight: Color; var dark: Color
    static func resolve(_ s: EISettings, _ primary: Color, _ secondary: Color) -> EIScenePalette {
        switch s.displayPreset {
        case .monochrome: return .init(foreground: Color(red: 0.5, green: 1, blue: 0.56), secondary: Color(red: 0.23, green: 0.62, blue: 0.31), highlight: Color(red: 0.78, green: 1, blue: 0.7), dark: Color(red: 0.04, green: 0.11, blue: 0.05))
        case .lcd: return .init(foreground: primary.opacity(0.92), secondary: secondary.opacity(0.86), highlight: .white.opacity(0.92), dark: .black.opacity(0.7))
        case .crt: return .init(foreground: primary, secondary: secondary, highlight: .white, dark: .black.opacity(0.85))
        case .clean: return .init(foreground: primary, secondary: secondary, highlight: .white, dark: .black.opacity(0.76))
        }
    }
}

@MainActor private struct EIPetView: View {
    @ObservedObject var engine: EnvironmentalInterfaceEngine; let settings: EISettings
    var body: some View {
        TimelineView(.animation(minimumInterval: engine.currentReaction == nil ? 0.22 : 1.0 / 30.0, paused: engine.currentReaction == nil && !settings.petResident)) { t in
            let phase = t.date.timeIntervalSinceReferenceDate
            PixelDisplayRenderer(scene: scene(t.date, phase), preset: settings.displayPreset, pixelGrid: settings.pixelGrid, glow: settings.pixelGlow, scanlines: settings.scanlines, ghosting: settings.ghosting, brightnessVariation: settings.brightnessVariation, phase: phase)
        }
        .contextMenu { if settings.petInteraction { Button("Pat") { engine.interact(.petPat) }; Button("Give snack") { engine.interact(.petSnack) }; Button("Say hi") { engine.interact(.petGreet) } } }
        .onTapGesture { if settings.petInteraction { engine.interact(.petPat) } }
    }
    private func scene(_ date: Date, _ phase: Double) -> EIPixelScene {
        let kind = engine.currentReaction?.kind ?? .petLookAround, progress = engine.currentReaction?.progress(at: date) ?? 0.5
        let p = EIScenePalette.resolve(settings, settings.petPrimaryColor.color, settings.petAccentColor.color)
        var a: [EIPixel] = []; var dx = 0, dy = 0; var sleeping = false; var crouch = false; var left = false
        switch kind {
        case .petPeekUnder: dy = Int((1 - sin(progress * .pi)) * 5)
        case .petPeekLeft: dx = -2; dy = Int((1 - sin(progress * .pi)) * 3)
        case .petPeekRight: dx = 2; left = true; dy = Int((1 - sin(progress * .pi)) * 3)
        case .petDance: dx = Int(round(sin(phase * 9) * 2)); dy = -Int(abs(sin(phase * 9)).rounded())
        case .petSleep: sleeping = true; crouch = true; dy = 2
        case .petCoffee: crouch = progress > 0.55
        default: dx = Int(round(sin(phase * 0.8) * 0.7))
        }
        if settings.petHidesWhenApproached, let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }), abs(NSEvent.mouseLocation.x - screen.frame.midX) < 120 { dy += 3 }
        let bx = 10 + dx, by = 9 + dy, bh = crouch ? 3 : 4, hx = bx + (left ? -3 : 8)
        a += [.init(x: bx, y: by, width: 10, height: bh, color: p.foreground), .init(x: hx, y: by - 4, width: 6, height: 5, color: p.foreground)]
        switch settings.petKind {
        case .cat: a += [.init(x: hx, y: by - 5, width: 2, height: 2, color: p.foreground), .init(x: hx + 4, y: by - 5, width: 2, height: 2, color: p.foreground)]
        case .dog: a += [.init(x: hx - 1, y: by - 3, width: 2, height: 3, color: p.secondary), .init(x: hx + 5, y: by - 3, width: 2, height: 3, color: p.secondary)]
        case .fox: a += [.init(x: hx, y: by - 6, width: 2, height: 3, color: p.foreground), .init(x: hx + 4, y: by - 6, width: 2, height: 3, color: p.foreground), .init(x: hx + 2, y: by, width: 2, height: 1, color: p.secondary)]
        }
        var eyeShift = 0
        if settings.petLooksAtCursor, let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) { eyeShift = NSEvent.mouseLocation.x < screen.frame.midX ? -1 : 1 }
        a.append(.init(x: max(hx, min(hx + 5, hx + 3 + eyeShift)), y: by - 2, color: p.dark))
        if !sleeping { a += [.init(x: bx + 2, y: by + bh, width: 2, height: 2, color: p.foreground), .init(x: bx + 7, y: by + bh, width: 2, height: 2, color: p.foreground)] }
        let tail = left ? bx + 9 : bx, dir = left ? 1 : -1, wave = Int(round(sin(phase * 2.2)))
        a += [.init(x: tail + dir * 2, y: by + 1, width: 2, height: 1, color: p.foreground), .init(x: tail + dir * 3, y: by + wave, width: 1, height: 2, color: p.foreground)]
        switch kind {
        case .petCoffee: a += [.init(x: bx - 4, y: by + 1, width: 3, height: 3, color: settings.petAccentColor.color), .init(x: bx - 3, y: by - 1, color: p.highlight, opacity: 0.65)]
        case .petUmbrella: a += [.init(x: bx + 2, y: by - 8, width: 8, color: settings.petAccentColor.color), .init(x: bx + 3, y: by - 9, width: 6, color: settings.petAccentColor.color), .init(x: bx + 6, y: by - 7, height: 8, color: p.highlight)]
        case .petSleep: a += [.init(x: bx + 12, y: by - 4, width: 2, color: p.highlight, opacity: 0.65), .init(x: bx + 14, y: by - 6, width: 2, color: p.highlight, opacity: 0.45)]
        case .petSnack: a.append(.init(x: bx - 3, y: by + 2, width: 2, height: 2, color: settings.petAccentColor.color))
        case .petGreet, .petCelebrate: a.append(.init(x: bx + 9, y: by + Int(round(sin(phase * 7))), width: 2, color: p.highlight))
        default: break
        }
        return .init(columns: 32, rows: 18, pixels: a)
    }
}

@MainActor private struct EIPlantView: View {
    @ObservedObject var engine: EnvironmentalInterfaceEngine; let settings: EISettings
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.14, paused: false)) { t in
            let phase = t.date.timeIntervalSinceReferenceDate
            PixelDisplayRenderer(scene: scene(phase), preset: settings.displayPreset, pixelGrid: settings.pixelGrid, glow: settings.pixelGlow, scanlines: settings.scanlines, ghosting: settings.ghosting, brightnessVariation: settings.brightnessVariation, phase: phase)
        }.allowsHitTesting(false)
    }
    private func scene(_ phase: Double) -> EIPixelScene {
        let growth = min(1, engine.persistentState.plant.growth + engine.persistentState.plant.bonusGrowth), stage = growth < 0.22 ? 1 : growth < 0.52 ? 2 : growth < 0.82 ? 3 : 4
        let p = EIScenePalette.resolve(settings, settings.plantColor.color, settings.plantPotColor.color), reaction = engine.currentReaction?.kind
        let strength = reaction == .plantSway ? 1.8 : engine.environment.isMusicPlaying ? 0.55 : 0.25, sway = Int(round(sin(phase * (reaction == .plantSway ? 3 : 1.1)) * strength))
        var a: [EIPixel] = [.init(x: 9, y: 14, width: 8, height: 3, color: settings.plantPotColor.color), .init(x: 10, y: 17, width: 6, color: settings.plantPotColor.color.opacity(0.75))]
        if settings.plantKind == .bonsai { a += [.init(x: 11, y: 8, width: 3, height: 7, color: settings.plantPotColor.color), .init(x: 9, y: 6, width: 4, height: 2, color: settings.plantPotColor.color)] } else { a.append(.init(x: 12, y: 7, width: 2, height: 8, color: p.foreground)) }
        if stage >= 1 { a += [.init(x: 9 + sway, y: 10, width: 4, height: 2, color: p.foreground), .init(x: 14 + sway, y: 9, width: 4, height: 2, color: p.foreground)] }
        if stage >= 2 { a += [.init(x: 7 + sway, y: 7, width: 6, height: 2, color: p.foreground), .init(x: 14 + sway, y: 6, width: 5, height: 2, color: p.foreground)] }
        if stage >= 3 { a += [.init(x: 8 + sway, y: 4, width: 5, height: 2, color: p.secondary), .init(x: 14 + sway, y: 3, width: 5, height: 2, color: p.secondary), .init(x: 12 + sway, y: 2, width: 3, height: 2, color: p.foreground)] }
        if stage >= 4 || reaction == .plantBloom || (settings.plantKind == .flower && stage >= 3) { a += [.init(x: 12 + sway, y: 0, width: 3, height: 3, color: p.highlight), .init(x: 13 + sway, y: 1, color: settings.plantPotColor.color)] }
        if reaction == .plantRain || engine.environment.weather?.isRaining == true { a += [.init(x: 5, y: 2, height: 2, color: .cyan.opacity(0.72)), .init(x: 20, y: 5, height: 2, color: .cyan.opacity(0.72))] }
        if engine.environment.timeOfDay == .night || reaction == .plantNight { a += [.init(x: 20, y: 1, width: 2, height: 2, color: .white.opacity(0.65)), .init(x: 21, y: 0, color: .white.opacity(0.35))] }
        return .init(columns: 26, rows: 19, pixels: a)
    }
}

@MainActor private struct EICityView: View {
    @ObservedObject var engine: EnvironmentalInterfaceEngine; let settings: EISettings
    var body: some View {
        TimelineView(.animation(minimumInterval: engine.environment.isMusicPlaying ? 1.0 / 15.0 : 0.12, paused: false)) { t in
            let phase = t.date.timeIntervalSinceReferenceDate
            PixelDisplayRenderer(scene: scene(phase), preset: settings.displayPreset, pixelGrid: settings.pixelGrid, glow: settings.pixelGlow, scanlines: settings.scanlines, ghosting: settings.ghosting, brightnessVariation: settings.brightnessVariation, phase: phase)
        }.allowsHitTesting(false)
    }
    private func scene(_ phase: Double) -> EIPixelScene {
        let accent = settings.simulationAccentColor.color, night = engine.environment.timeOfDay == .night || engine.currentReaction?.kind == .cityNight
        let p = EIScenePalette.resolve(settings, night ? Color(red: 0.27, green: 0.54, blue: 0.96) : accent, night ? Color(red: 0.72, green: 0.58, blue: 0.24) : .white.opacity(0.72))
        let seed = engine.persistentState.simulation.seed, heights = [7 + seed % 3, 11 + (seed / 3) % 4, 8 + (seed / 7) % 5, 13 + (seed / 11) % 3, 9 + (seed / 13) % 4, 6 + (seed / 17) % 5]
        var a: [EIPixel] = [], x = 2
        for (index, h) in heights.enumerated() {
            let w = index.isMultiple(of: 2) ? 8 : 7, y = 18 - h
            a.append(.init(x: x, y: y, width: w, height: h, color: p.dark.opacity(0.82)))
            for wy in stride(from: y + 2, to: 17, by: 3) { for wx in stride(from: x + 2, to: x + w - 1, by: 3) { if night ? ((wx + wy + seed + index) % 3 != 0) : ((wx + wy + index) % 5 == 0) { a.append(.init(x: wx, y: wy, color: p.secondary, opacity: night ? 0.92 : 0.45)) } } }
            x += w + 2
        }
        a.append(.init(x: 0, y: 18, width: 64, height: 2, color: p.foreground.opacity(0.45)))
        let speed = engine.currentReaction?.kind == .cityBusy ? 8.0 : 4.0, car = Int((phase * speed).truncatingRemainder(dividingBy: 60))
        a += [.init(x: car, y: 17, width: 4, color: p.highlight), .init(x: (64 - car + 64) % 64, y: 19, width: 3, color: p.secondary)]
        if engine.environment.isMusicPlaying || engine.currentReaction?.kind == .cityMusic { let pulse = Int(abs(sin(phase * 5)) * 3); a.append(.init(x: 27, y: 11 - pulse, width: 5, height: 1 + pulse, color: accent.opacity(0.74))) }
        if engine.environment.weather?.isRaining == true || engine.currentReaction?.kind == .cityRain { let shift = Int((phase * 8).truncatingRemainder(dividingBy: 4)); for rx in stride(from: 3, to: 62, by: 7) { a.append(.init(x: rx, y: (rx + shift) % 9, height: 2, color: .cyan.opacity(0.56))) } }
        return .init(columns: 64, rows: 20, pixels: a)
    }
}

@MainActor private struct EnvironmentalInterfaceRegionView: View {
    @ObservedObject var engine = EnvironmentalInterfaceEngine.shared
    @ObservedObject var settingsStore = EISettingsStore.shared
    var body: some View {
        Group {
            switch settingsStore.settings.mode {
            case .off: EmptyView()
            case .pet: EIPetView(engine: engine, settings: settingsStore.settings)
            case .plant: EIPlantView(engine: engine, settings: settingsStore.settings)
            case .simulation: EICityView(engine: engine, settings: settingsStore.settings)
            }
        }.transition(.opacity.combined(with: .scale(scale: 0.94))).animation(.easeInOut(duration: 0.18), value: settingsStore.settings.mode).animation(.easeInOut(duration: 0.16), value: engine.currentReaction?.id)
    }
}

// MARK: Overlay manager

@MainActor
final class EnvironmentalInterfaceManager {
    static let shared = EnvironmentalInterfaceManager()
    @MainActor private final class Host {
        let overlay: NSPanel; let haloWindow: NSWindow
        var screenID = ""; var haloFrame = CGRect.zero; var lastResolvedFrame = CGRect.zero
        init(_ haloWindow: NSWindow) {
            self.haloWindow = haloWindow
            overlay = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            overlay.backgroundColor = .clear; overlay.isOpaque = false; overlay.hasShadow = false; overlay.hidesOnDeactivate = false
            overlay.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]; overlay.isReleasedWhenClosed = false
            let host = NSHostingView(rootView: EnvironmentalInterfaceRegionView()); host.sizingOptions = []; overlay.contentView = host
        }
    }
    private weak var workspace: WorkspaceStore?
    private var hosts: [ObjectIdentifier: Host] = [:]
    private var subscriptions = Set<AnyCancellable>()
    private var started = false, suppressedByHUD = false
    func start(workspace: WorkspaceStore) {
        self.workspace = workspace; EnvironmentalInterfaceEngine.shared.start(workspace: workspace)
        guard !started else { refreshAll(false); return }; started = true
        NotificationCenter.default.publisher(for: .init("HaloPanelGeometryChanged")).receive(on: RunLoop.main).sink { [weak self] in self?.handleGeometry($0) }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: .init("HaloEIVisibilityChanged"))
            .merge(with: NotificationCenter.default.publisher(for: .init("HaloEIReactionChanged")))
            .merge(with: NotificationCenter.default.publisher(for: .init("HaloEIPlacementChanged")))
            .receive(on: RunLoop.main).sink { [weak self] _ in self?.refreshAll(true) }.store(in: &subscriptions)
        EISettingsStore.shared.$settings.removeDuplicates().receive(on: RunLoop.main).sink { [weak self] _ in self?.refreshAll(true) }.store(in: &subscriptions)
        HaloHUDNotchBridge.shared.$presentation.map { $0 != nil }.removeDuplicates().receive(on: RunLoop.main).sink { [weak self] active in self?.suppressedByHUD = active; self?.refreshAll(true) }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSWindow.willCloseNotification).receive(on: RunLoop.main).sink { [weak self] note in if let w = note.object as? NSWindow { self?.remove(w) } }.store(in: &subscriptions)
    }
    func stop() { hosts.values.forEach { $0.overlay.close() }; hosts.removeAll(); subscriptions.removeAll(); EnvironmentalInterfaceEngine.shared.stop(); workspace = nil; started = false }
    private func handleGeometry(_ note: Notification) {
        guard let halo = note.object as? NSWindow, let frame = note.userInfo?["frame"] as? CGRect else { return }
        let key = ObjectIdentifier(halo), host = hosts[key] ?? Host(halo); hosts[key] = host
        if let id = note.userInfo?["screen"] as? String { host.screenID = id }
        host.haloFrame = frame; refresh(host, false); updateExpanded()
    }
    private func remove(_ window: NSWindow) { if let h = hosts.removeValue(forKey: ObjectIdentifier(window)) { h.overlay.close() }; updateExpanded() }
    private func refreshAll(_ animated: Bool) { hosts.values.forEach { refresh($0, animated) }; updateExpanded() }
    private func updateExpanded() { EnvironmentalInterfaceEngine.shared.setAnyHaloSurfaceExpanded(hosts.values.contains { $0.haloFrame.height > 82 }) }
    private func refresh(_ host: Host, _ animated: Bool) {
        let settings = EISettingsStore.shared.settings, engine = EnvironmentalInterfaceEngine.shared
        guard !suppressedByHUD, settings.mode != .off, engine.shouldRender, host.haloFrame.width > 1, host.haloFrame.height > 1 else { host.overlay.orderOut(nil); return }
        let frame = resolvedFrame(host, settings, engine.currentReaction); guard frame.width >= 24, frame.height >= 20 else { host.overlay.orderOut(nil); return }
        host.overlay.ignoresMouseEvents = !(settings.mode == .pet && settings.petInteraction)
        if animated, host.lastResolvedFrame != .zero, host.lastResolvedFrame != frame {
            NSAnimationContext.runAnimationGroup { c in c.duration = 0.18; c.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut); host.overlay.animator().setFrame(frame, display: false) }
        } else { host.overlay.setFrame(frame, display: false) }
        host.lastResolvedFrame = frame; host.overlay.orderFrontRegardless()
    }
    private func resolvedFrame(_ host: Host, _ settings: EISettings, _ reaction: EIReaction?) -> CGRect {
        let halo = host.haloFrame, compact = halo.height <= 82
        let size: CGSize
        switch settings.mode {
        case .off: return .zero
        case .pet: let s = CGFloat(settings.petScale); size = CGSize(width: (compact ? 76 : 102) * s, height: (compact ? 38 : 58) * s)
        case .plant: size = CGSize(width: compact ? 62 : 88, height: compact ? 40 : 66)
        case .simulation: size = CGSize(width: min(compact ? 78 : 220, max(64, halo.width * (compact ? 0.38 : 0.46))), height: compact ? min(30, halo.height) : 68)
        }
        if let context = EIPlacementRegistry.shared.context(for: host.screenID), !context.availableRegions.isEmpty, let r = chooseRegion(context, size) {
            return CGRect(x: halo.minX + r.minX, y: halo.minY + r.minY, width: min(size.width, r.width), height: min(size.height, r.height))
        }
        if settings.mode == .simulation { return CGRect(x: halo.maxX - size.width - (compact ? 3 : 10), y: compact ? halo.minY : halo.minY + 8, width: size.width, height: min(size.height, halo.height)) }
        var edge = preferredEdge(reaction?.kind, compact)
        if !compact, EnvironmentalInterfaceEngine.shared.environment.activeCI != nil, reaction?.kind != .petPeekLeft, reaction?.kind != .petPeekRight { edge = .underNotch }
        switch edge {
        case .left, .bottomLeft: return CGRect(x: halo.minX + (compact ? 3 : 10), y: compact ? halo.minY : halo.minY + 8, width: min(size.width, halo.width / (compact ? 2.1 : 1.3)), height: min(size.height, halo.height))
        case .right, .bottomRight: let w = min(size.width, halo.width / (compact ? 2.1 : 1.3)); return CGRect(x: halo.maxX - w - (compact ? 3 : 10), y: compact ? halo.minY : halo.minY + 8, width: w, height: min(size.height, halo.height))
        case .underNotch: return CGRect(x: halo.midX - min(size.width, halo.width) / 2, y: compact ? halo.minY : halo.maxY - min(halo.height, size.height + 42), width: min(size.width, halo.width), height: min(size.height, halo.height))
        }
    }
    private func preferredEdge(_ kind: EIReactionKind?, _ compact: Bool) -> EIPlacementEdge {
        switch kind { case .petPeekLeft?: return compact ? .left : .bottomLeft; case .petPeekRight?: return compact ? .right : .bottomRight; case .petPeekUnder?: return .underNotch; default: return compact ? .right : .bottomRight }
    }
    private func chooseRegion(_ context: EIPlacementContext, _ size: CGSize) -> CGRect? {
        let ranked = context.availableRegions.sorted { a, b in let af = a.width >= size.width && a.height >= size.height, bf = b.width >= size.width && b.height >= size.height; return af == bf ? a.width * a.height > b.width * b.height : af && !bf }
        return ranked.first(where: { r in r.width >= min(24, size.width) && r.height >= min(20, size.height) && !context.contentExclusionRegions.contains(where: { ex in let i = ex.intersection(r); return !i.isNull && i.width * i.height > r.width * r.height * 0.45 }) }) ?? ranked.first
    }
}

// MARK: Settings UI

@MainActor
struct EnvironmentalInterfaceSettingsView: View {
    @ObservedObject private var store = EISettingsStore.shared
    @ObservedObject private var engine = EnvironmentalInterfaceEngine.shared
    var body: some View {
        Section("Environmental Interface") {
            Picker("Environmental Interface", selection: binding(\.mode)) { ForEach(EIMode.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) } }.pickerStyle(.segmented)
            Text("EI adds ambient life around the notch without replacing Context Interfaces. CI and EI can run at the same time.").font(.caption).foregroundStyle(.secondary)
        }
        if store.settings.mode != .off {
            Section("Activity") {
                Picker("Activity level", selection: binding(\.activityLevel)) { ForEach(EIActivityLevel.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                Text(activityDescription).font(.caption).foregroundStyle(.secondary)
            }
            Section("Environmental inputs") {
                Toggle("Time of day", isOn: input(\.timeOfDay)); Toggle("User activity", isOn: input(\.userActivity)); Toggle("Long work sessions", isOn: input(\.longWorkSessions))
                if store.settings.inputs.longWorkSessions { Slider(value: binding(\.longWorkThresholdMinutes), in: 30...240, step: 5) { Text("Long work threshold") }; Text("Long-session reactions begin around \(Int(store.settings.longWorkThresholdMinutes)) minutes and remain occasional.").font(.caption).foregroundStyle(.secondary) }
                Toggle("Idle state", isOn: input(\.idleState)); Toggle("Music / playback", isOn: input(\.musicPlayback)); Toggle("Weather, when available", isOn: input(\.weather)); Toggle("Active application", isOn: input(\.activeApplication)); Toggle("Context Interface state", isOn: input(\.ciState)); Toggle("System events", isOn: input(\.systemEvents))
                Text("EI uses only high-level state needed for reactions; it does not inspect documents, messages, browsing data or typed content.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Pixel display") {
                Picker("Display style", selection: binding(\.displayPreset)) { ForEach(EIPixelDisplayPreset.allCases) { Text($0.rawValue).tag($0) } }
                Toggle("Pixel grid", isOn: binding(\.pixelGrid)); Toggle("Pixel glow", isOn: binding(\.pixelGlow)); Toggle("Scanlines", isOn: binding(\.scanlines)); Toggle("LCD persistence / ghosting", isOn: binding(\.ghosting)); Toggle("Subtle brightness variation", isOn: binding(\.brightnessVariation))
                Text("Scenes render on a deliberately low logical pixel grid and scale as discrete cells rather than filtering high-resolution artwork.").font(.caption).foregroundStyle(.secondary)
            }
            modeSettings
            Section("Live environment") {
                LabeledContent("Time") { Text(engine.environment.timeOfDay.rawValue.capitalized) }; LabeledContent("Idle") { Text(duration(engine.environment.idleDuration)) }; LabeledContent("Work session") { Text(duration(engine.environment.activityDuration)) }; LabeledContent("Music") { Text(engine.environment.isMusicPlaying ? "Playing" : "Not playing") }; LabeledContent("Active CI") { Text(engine.environment.activeCI?.name ?? "None") }
                if let weather = engine.environment.weather { LabeledContent("Weather") { Text(weather.condition) } }
            }
            Section { Button("Reset EI settings") { store.reset() }; Text("When EI is Off its rendering and behaviour loop stop entirely. Hidden Pet mode also drops to a low-frequency environment check.").font(.caption).foregroundStyle(.secondary) }
        }
    }
    @ViewBuilder private var modeSettings: some View {
        switch store.settings.mode {
        case .off: EmptyView()
        case .pet:
            Section("Pet") {
                Picker("Companion", selection: binding(\.petKind)) { ForEach(EIPetKind.allCases) { Text($0.rawValue).tag($0) } }; Slider(value: binding(\.petScale), in: 0.7...1.6, step: 0.05) { Text("Pet size") }
                Toggle("Allow click / reaction menu", isOn: binding(\.petInteraction)); Toggle("Look toward cursor", isOn: binding(\.petLooksAtCursor)); Toggle("Hide a little when approached", isOn: binding(\.petHidesWhenApproached)); Toggle("Occasionally carry tiny objects", isOn: binding(\.petOccasionalObjects)); Toggle("Keep pet quietly resident", isOn: binding(\.petResident))
                ColorPicker("Pet color", selection: color(\.petPrimaryColor), supportsOpacity: false); ColorPicker("Accent / objects", selection: color(\.petAccentColor), supportsOpacity: false)
                HStack { Button("Preview peek") { engine.preview(.petPeekUnder) }; Button("Preview coffee") { engine.preview(.petCoffee, duration: 5) }; Button("Preview dance") { engine.preview(.petDance, duration: 6) }; Button("Preview sleep") { engine.preview(.petSleep, duration: 6) } }
                Text("The companion never dies, starves, becomes permanently unhappy, shames you, or requires daily interaction.").font(.caption).foregroundStyle(.secondary)
            }
        case .plant:
            Section("Plant") {
                Picker("Plant", selection: binding(\.plantKind)) { ForEach(EIPlantKind.allCases) { Text($0.rawValue).tag($0) } }; ColorPicker("Plant color", selection: color(\.plantColor), supportsOpacity: false); ColorPicker("Pot color", selection: color(\.plantPotColor), supportsOpacity: false)
                ProgressView(value: min(1, engine.persistentState.plant.growth + engine.persistentState.plant.bonusGrowth)); Text("Growth is deliberately slow and persists between launches. Work sessions can create small positive moments, never mandatory progression.").font(.caption).foregroundStyle(.secondary)
                HStack { Button("Preview sway") { engine.preview(.plantSway, duration: 6) }; Button("Preview rain") { engine.preview(.plantRain, duration: 6) }; Button("Preview bloom") { engine.preview(.plantBloom, duration: 7) } }
            }
        case .simulation:
            Section("Simulation") {
                Picker("World", selection: binding(\.simulationKind)) { ForEach(EISimulationKind.allCases) { Text($0.rawValue).tag($0) } }; ColorPicker("City accent", selection: color(\.simulationAccentColor), supportsOpacity: false)
                Text("The first world is one polished horizontal tiny city: persistent layout seed, traffic, window lights, day/night state, rain and music activity.").font(.caption).foregroundStyle(.secondary)
                HStack { Button("Preview traffic") { engine.preview(.cityTraffic, duration: 7) }; Button("Preview rain") { engine.preview(.cityRain, duration: 8) }; Button("Preview night") { engine.preview(.cityNight, duration: 8) } }
            }
        }
    }
    private var activityDescription: String { switch store.settings.activityLevel { case .subtle: return "Rare moments; easy to forget about until EI quietly surprises you."; case .balanced: return "Occasional context-aware moments without constant movement."; case .expressive: return "More frequent reactions while still yielding to important UI." } }
    private func binding<T>(_ kp: WritableKeyPath<EISettings, T>) -> Binding<T> { Binding(get: { store.settings[keyPath: kp] }, set: { var v = store.settings; v[keyPath: kp] = $0; store.settings = v }) }
    private func input(_ kp: WritableKeyPath<EIInputSettings, Bool>) -> Binding<Bool> { Binding(get: { store.settings.inputs[keyPath: kp] }, set: { var v = store.settings; v.inputs[keyPath: kp] = $0; store.settings = v }) }
    private func color(_ kp: WritableKeyPath<EISettings, WidgetColor>) -> Binding<Color> { Binding(get: { store.settings[keyPath: kp].color }, set: { var v = store.settings; v[keyPath: kp] = WidgetColor($0); store.settings = v }) }
    private func duration(_ value: TimeInterval) -> String { let s = max(0, Int(value.rounded())); if s < 60 { return "\(s)s" }; let m = s / 60; return m < 60 ? "\(m)m" : "\(m / 60)h \(m % 60)m" }
}
