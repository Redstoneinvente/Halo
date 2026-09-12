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

// MARK: - Environmental Interface definitions

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
        switch self { case .subtle: return 0.38; case .balanced: return 0.68; case .expressive: return 1 }
    }
    /// Spontaneous EI is intentionally sparse. Environmental/direct events can still react sooner.
    var spontaneousRange: ClosedRange<TimeInterval> {
        switch self {
        case .subtle: return 18 * 60 ... 45 * 60
        case .balanced: return 8 * 60 ... 25 * 60
        case .expressive: return 3 * 60 ... 12 * 60
        }
    }
}

/// Legacy persisted type. EI v2 no longer renders pixel art, but retaining this enum keeps old
/// preferences decodable while they are transparently migrated to vector presentation.
enum EIPixelDisplayPreset: String, Codable, CaseIterable, Identifiable {
    case clean = "Clean Pixel", lcd = "Pixel LCD", monochrome = "Monochrome LCD", crt = "Retro CRT"
    var id: String { rawValue }
}

enum EIPetKind: String, Codable, CaseIterable, Identifiable {
    case cat = "Cat", dog = "Dog", fox = "Fox"
    var id: String { rawValue }
}

enum EIPlantKind: String, Codable, CaseIterable, Identifiable {
    case bonsai = "Bonsai"
    case flower = "Flowering Plant"
    case vine = "Vine"
    case succulent = "Succulent"
    case fern = "Fern"
    var id: String { rawValue }
}

enum EISimulationKind: String, Codable, CaseIterable, Identifiable {
    case tinyCity = "Tiny City"
    var id: String { rawValue }
}

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

    // Legacy visual flags are retained only for preference compatibility.
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

    var plantKind: EIPlantKind = .bonsai
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
    private var pendingPersist: DispatchWorkItem?

    @Published var settings: EISettings { didSet { schedulePersist(settings.normalized()) } }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode(EISettings.self, from: data),
           saved.version == 1 {
            settings = saved.normalized()
        } else {
            settings = EISettings()
        }
    }

    func reset() { settings = EISettings() }

    private func schedulePersist(_ snapshot: EISettings) {
        pendingPersist?.cancel()
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        let defaults = self.defaults, key = self.key
        let work = DispatchWorkItem { defaults.set(data, forKey: key) }
        pendingPersist = work
        DispatchQueue.main.async(execute: work)
    }
}

// MARK: - Environment / context engine

enum EITimeOfDay: String, Codable, Equatable, CaseIterable, Identifiable {
    case morning, day, evening, night
    var id: String { rawValue }
    static func current(at date: Date = Date(), calendar: Calendar = .current) -> EITimeOfDay {
        switch calendar.component(.hour, from: date) {
        case 5..<12: return .morning
        case 12..<17: return .day
        case 17..<22: return .evening
        default: return .night
        }
    }
}

struct EIWeatherState: Codable, Equatable {
    var condition: String
    var isRaining: Bool
    var temperatureCelsius: Double?
}
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
    @MainActor static func emit(_ name: String) { EnvironmentalInterfaceEngine.shared.emitExternalEvent(name) }
}

// MARK: - Placement / exclusion

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
        guard contexts[screenID] != context else { return }
        if let context { contexts[screenID] = context } else { contexts.removeValue(forKey: screenID) }
        NotificationCenter.default.post(name: .init("HaloEIPlacementChanged"), object: nil, userInfo: ["screen": screenID])
    }
    func context(for screenID: String) -> EIPlacementContext? { contexts[screenID] }
}

// MARK: - State machine / scheduler

enum EIEventKind: String, Codable, CaseIterable {
    case lateNight, longWorkSession, userReturned, musicStarted, musicStopped, weatherChanged, rainStarted
    case ciActivated, ciDeactivated, applicationChanged, longIdlePeriod, systemWoke, spontaneous, userInteraction, external
}

struct EIEvent: Identifiable, Equatable {
    let id = UUID()
    let kind: EIEventKind
    let date: Date
    var detail: String?
}

enum EIReactionKind: String, Codable, CaseIterable, Identifiable {
    // Pet
    case petPeekEyes, petPeekEars, petPeekUnder, petPeekLeft, petPeekRight, petPawFirst, petTailFirst
    case petObserve, petLookAround, petStretch, petGroom, petCurlUp, petUnimpressed, petPlay, petChase
    case petCoffee, petLaptop, petLaptopSleep, petSleep, petYawn, petDance, petCelebrate, petGreet
    case petUmbrella, petRainWatch, petPat, petSnack, petToy, petCall, petHide
    // Plant
    case plantDormant, plantHealthy, plantSway, plantPerk, plantGrowLeaf, plantBloom, plantRain, plantNight, plantVineGrow
    // Simulation
    case cityMorning, cityDay, cityEvening, cityNight, cityTraffic, cityRain, cityStorm, cityMusic, cityBusy
    case cityDelivery, cityMeeting, cityPerformer, cityBalloon, cityBird, cityTaxi, cityConstruction

    var id: String { rawValue }

    var title: String {
        switch self {
        case .petPeekEyes: return "Pet · Eyes peek"
        case .petPeekEars: return "Pet · Ears peek"
        case .petPeekUnder: return "Pet · Peek underneath"
        case .petPeekLeft: return "Pet · Peek left"
        case .petPeekRight: return "Pet · Peek right"
        case .petPawFirst: return "Pet · Paw first"
        case .petTailFirst: return "Pet · Tail first"
        case .petObserve: return "Pet · Observe"
        case .petLookAround: return "Pet · Look around"
        case .petStretch: return "Pet · Stretch"
        case .petGroom: return "Pet · Groom"
        case .petCurlUp: return "Pet · Curl up"
        case .petUnimpressed: return "Pet · Unimpressed"
        case .petPlay: return "Pet · Play"
        case .petChase: return "Pet · Chase"
        case .petCoffee: return "Pet · Coffee"
        case .petLaptop: return "Pet · Tiny laptop"
        case .petLaptopSleep: return "Pet · Sleep at laptop"
        case .petSleep: return "Pet · Sleep"
        case .petYawn: return "Pet · Yawn"
        case .petDance: return "Pet · Dance"
        case .petCelebrate: return "Pet · Celebrate"
        case .petGreet: return "Pet · Greet"
        case .petUmbrella: return "Pet · Umbrella"
        case .petRainWatch: return "Pet · Watch rain"
        case .petPat: return "Pet · Pat"
        case .petSnack: return "Pet · Treat"
        case .petToy: return "Pet · Toy"
        case .petCall: return "Pet · Call"
        case .petHide: return "Pet · Hide"
        case .plantDormant: return "Plant · Dormant"
        case .plantHealthy: return "Plant · Healthy"
        case .plantSway: return "Plant · Sway"
        case .plantPerk: return "Plant · Perk"
        case .plantGrowLeaf: return "Plant · Grow leaf"
        case .plantBloom: return "Plant · Bloom"
        case .plantRain: return "Plant · Rain"
        case .plantNight: return "Plant · Night"
        case .plantVineGrow: return "Plant · Vine growth"
        case .cityMorning: return "City · Morning"
        case .cityDay: return "City · Day"
        case .cityEvening: return "City · Evening"
        case .cityNight: return "City · Night"
        case .cityTraffic: return "City · Traffic"
        case .cityRain: return "City · Rain"
        case .cityStorm: return "City · Storm"
        case .cityMusic: return "City · Music"
        case .cityBusy: return "City · Busy"
        case .cityDelivery: return "City · Delivery"
        case .cityMeeting: return "City · Two people meet"
        case .cityPerformer: return "City · Street performer"
        case .cityBalloon: return "City · Balloon"
        case .cityBird: return "City · Bird"
        case .cityTaxi: return "City · Taxi"
        case .cityConstruction: return "City · Construction"
        }
    }

    var mode: EIMode {
        if rawValue.hasPrefix("pet") { return .pet }
        if rawValue.hasPrefix("plant") { return .plant }
        return .simulation
    }
}

struct EIReaction: Identifiable, Equatable {
    let id = UUID()
    var kind: EIReactionKind
    var started: Date
    var duration: TimeInterval
    var priority: Int
    var source: EIEventKind
    var ends: Date { started.addingTimeInterval(duration) }
    func progress(at date: Date) -> Double { min(1, max(0, date.timeIntervalSince(started) / max(0.01, duration))) }
}

enum EIBehaviourState: String, CaseIterable, Identifiable {
    case hidden, peeking, observing, idle, sleeping, playful, affectionate, curious, tired, excited
    case dormant, growing, healthy, blooming
    case cityMorning, cityDay, cityEvening, cityNight, cityEvent
    var id: String { rawValue }
}

enum EIMoodState: String, CaseIterable, Identifiable {
    case calm, curious, playful, affectionate, tired, excited
    var id: String { rawValue }
}

enum EIAnimationPhase: String { case entering, active, settling, exiting }

struct EIMoodModifiers: Equatable {
    var curiosity = 0.5
    var energy = 0.5
    var affection = 0.5
    var sleepiness = 0.5
    var playfulness = 0.5
}

struct EIPetPersonality: Equatable {
    var curiosity: Double
    var energy: Double
    var affection: Double
    var sleepiness: Double
    var playfulness: Double
}

struct EIPetDefinition: Identifiable {
    let kind: EIPetKind
    let personality: EIPetPersonality
    var id: EIPetKind { kind }

    static func definition(for kind: EIPetKind) -> EIPetDefinition {
        switch kind {
        case .cat:
            return .init(kind: .cat, personality: .init(curiosity: 0.8, energy: 0.4, affection: 0.5, sleepiness: 0.7, playfulness: 0.6))
        case .dog:
            return .init(kind: .dog, personality: .init(curiosity: 0.7, energy: 0.9, affection: 0.9, sleepiness: 0.4, playfulness: 0.9))
        case .fox:
            return .init(kind: .fox, personality: .init(curiosity: 0.86, energy: 0.55, affection: 0.38, sleepiness: 0.62, playfulness: 0.55))
        }
    }
}

struct EIBehaviourCandidate {
    var kind: EIReactionKind
    var state: EIBehaviourState
    var priority: Int
    var cooldown: TimeInterval
    var probability: Double
    var duration: TimeInterval
    var personalityWeight: Double = 1
}

struct EIBehaviourScheduler {
    static func candidates(for event: EIEvent, settings: EISettings, environment: EIEnvironment) -> [EIBehaviourCandidate] {
        switch settings.mode {
        case .off:
            return []
        case .pet:
            return petCandidates(event, settings: settings, environment: environment)
        case .plant:
            return plantCandidates(event, settings: settings)
        case .simulation:
            return cityCandidates(event, environment: environment)
        }
    }

    static func select(from candidates: [EIBehaviourCandidate], activity: EIActivityLevel,
                       cooldowns: [EIReactionKind: Date], recent: [EIReactionKind],
                       currentPriority: Int, force: Bool, at date: Date) -> EIBehaviourCandidate? {
        let eligible = candidates.filter { candidate in
            let cooldownReady = (cooldowns[candidate.kind] ?? .distantPast) <= date
            let repeated = recent.suffix(3).contains(candidate.kind)
            return (force || cooldownReady) && (force || !repeated) && (force || candidate.priority > currentPriority || currentPriority < 0)
        }
        guard !eligible.isEmpty else { return nil }
        if force { return eligible.max(by: { $0.priority < $1.priority }) }

        let weighted = eligible.map { candidate -> (EIBehaviourCandidate, Double) in
            let probability = min(1, max(0.005, candidate.probability * candidate.personalityWeight * activity.probabilityMultiplier))
            return (candidate, probability)
        }
        let total = weighted.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return nil }
        var roll = Double.random(in: 0..<total)
        for pair in weighted {
            roll -= pair.1
            if roll <= 0 { return pair.0 }
        }
        return weighted.last?.0
    }

    private static func petCandidates(_ event: EIEvent, settings: EISettings, environment: EIEnvironment) -> [EIBehaviourCandidate] {
        let personality = EIPetDefinition.definition(for: settings.petKind).personality
        func c(_ kind: EIReactionKind, _ state: EIBehaviourState, _ priority: Int, _ cooldown: TimeInterval,
               _ probability: Double, _ duration: TimeInterval, _ trait: Double = 1) -> EIBehaviourCandidate {
            .init(kind: kind, state: state, priority: priority, cooldown: cooldown,
                  probability: probability, duration: duration, personalityWeight: trait)
        }

        switch event.kind {
        case .lateNight:
            var values = [
                c(.petYawn, .tired, 58, 25 * 60, 0.54, 5, personality.sleepiness),
                c(.petSleep, .sleeping, 64, 40 * 60, 0.50, 12, personality.sleepiness),
                c(.petCoffee, .tired, 50, 35 * 60, 0.22, 7, personality.playfulness)
            ]
            if settings.petKind == .fox { values.append(c(.petObserve, .observing, 60, 16 * 60, 0.72, 9, personality.curiosity * 1.25)) }
            return values
        case .longWorkSession:
            return [
                c(.petLaptop, .curious, 74, 42 * 60, 0.55, 10, personality.curiosity),
                c(.petCoffee, .tired, 72, 45 * 60, 0.50, 7, personality.playfulness),
                c(.petLaptopSleep, .sleeping, 67, 55 * 60, 0.28, 13, personality.sleepiness),
                c(.petObserve, .observing, 54, 18 * 60, 0.38, 8, personality.curiosity)
            ]
        case .longIdlePeriod:
            return [c(.petSleep, .sleeping, 55, 34 * 60, 0.60, 13, personality.sleepiness),
                    c(.petCurlUp, .sleeping, 50, 28 * 60, 0.52, 11, personality.sleepiness)]
        case .userReturned, .systemWoke:
            switch settings.petKind {
            case .dog:
                return [c(.petGreet, .excited, 90, 7 * 60, 0.98, 6, personality.affection), c(.petPlay, .playful, 76, 12 * 60, 0.48, 8, personality.playfulness)]
            case .cat:
                return [c(.petPeekEyes, .peeking, 72, 8 * 60, 0.72, 5, personality.curiosity), c(.petUnimpressed, .observing, 66, 14 * 60, 0.35, 6, 1)]
            case .fox:
                return [c(.petObserve, .observing, 75, 9 * 60, 0.82, 7, personality.curiosity)]
            }
        case .musicStarted:
            return [
                c(.petObserve, .curious, 48, 10 * 60, 0.48, 7, personality.curiosity),
                c(.petDance, .playful, 56, 14 * 60, 0.48 + (environment.musicIntensity ?? 0) * 0.12, 9, personality.playfulness)
            ]
        case .rainStarted, .weatherChanged:
            guard environment.weather?.isRaining == true else { return [c(.petObserve, .curious, 32, 12 * 60, 0.28, 6, personality.curiosity)] }
            return [c(.petRainWatch, .observing, 48, 20 * 60, 0.58, 9, personality.curiosity),
                    c(.petUmbrella, .curious, 52, 32 * 60, 0.42, 8, personality.playfulness)]
        case .ciActivated:
            return [c(.petPeekLeft, .curious, 44, 8 * 60, 0.45, 6, personality.curiosity),
                    c(.petPeekRight, .curious, 44, 8 * 60, 0.45, 6, personality.curiosity),
                    c(.petObserve, .observing, 46, 10 * 60, 0.55, 7, personality.curiosity)]
        case .applicationChanged:
            return [c(.petPeekEars, .peeking, 20, 14 * 60, 0.20, 4, personality.curiosity),
                    c(.petObserve, .observing, 22, 15 * 60, 0.18, 5, personality.curiosity)]
        case .external:
            let detail = event.detail?.lowercased() ?? ""
            if detail.contains("succeed") || detail.contains("complete") || detail.contains("passed") {
                return [c(.petCelebrate, .excited, 82, 4 * 60, 0.90, 7, personality.energy)]
            }
            return [c(.petObserve, .curious, 52, 6 * 60, 0.62, 6, personality.curiosity)]
        case .spontaneous:
            var values = [
                c(.petPeekEyes, .peeking, 13, 10 * 60, 0.48, 5, personality.curiosity),
                c(.petPeekEars, .peeking, 12, 12 * 60, 0.42, 5, personality.curiosity),
                c(.petPeekUnder, .peeking, 14, 13 * 60, 0.44, 6, personality.curiosity),
                c(.petObserve, .observing, 12, 14 * 60, 0.36, 7, personality.curiosity),
                c(.petStretch, .idle, 10, 18 * 60, 0.28, 6, personality.energy),
                c(.petGroom, .idle, 10, 22 * 60, 0.20, 7, settings.petKind == .cat ? 1.3 : 0.55),
                c(.petPlay, .playful, 11, 24 * 60, 0.18, 8, personality.playfulness),
                c(.petPawFirst, .playful, 11, 20 * 60, 0.20, 6, personality.playfulness),
                c(.petTailFirst, .peeking, 10, 20 * 60, 0.18, 5, settings.petKind == .fox ? 1.35 : 0.8)
            ]
            if environment.timeOfDay == .night { values.append(c(.petCurlUp, .sleeping, 12, 32 * 60, 0.26, 12, personality.sleepiness)) }
            return values
        case .userInteraction:
            return []
        case .musicStopped, .ciDeactivated:
            return [c(.petLookAround, .curious, 24, 7 * 60, 0.25, 5, personality.curiosity)]
        }
    }

    private static func plantCandidates(_ event: EIEvent, settings: EISettings) -> [EIBehaviourCandidate] {
        func c(_ kind: EIReactionKind, _ state: EIBehaviourState, _ priority: Int, _ cooldown: TimeInterval,
               _ probability: Double, _ duration: TimeInterval) -> EIBehaviourCandidate {
            .init(kind: kind, state: state, priority: priority, cooldown: cooldown, probability: probability, duration: duration)
        }
        switch event.kind {
        case .lateNight: return [c(.plantNight, .dormant, 42, 45 * 60, 0.95, 12)]
        case .longWorkSession: return [c(.plantGrowLeaf, .growing, 38, 70 * 60, 0.32, 9), c(.plantBloom, .blooming, 32, 4 * 3600, 0.12, 13)]
        case .rainStarted: return [c(.plantRain, .healthy, 52, 35 * 60, 0.85, 12)]
        case .musicStarted: return [c(.plantSway, .healthy, 20, 15 * 60, 0.48, 10)]
        case .userReturned: return [c(.plantPerk, .healthy, 22, 16 * 60, 0.30, 6)]
        case .spontaneous:
            var values = [c(.plantSway, .healthy, 8, 18 * 60, 0.38, 8)]
            if settings.plantKind == .vine { values.append(c(.plantVineGrow, .growing, 9, 60 * 60, 0.24, 9)) }
            return values
        default: return []
        }
    }

    private static func cityCandidates(_ event: EIEvent, environment: EIEnvironment) -> [EIBehaviourCandidate] {
        func c(_ kind: EIReactionKind, _ priority: Int, _ cooldown: TimeInterval, _ probability: Double, _ duration: TimeInterval) -> EIBehaviourCandidate {
            .init(kind: kind, state: .cityEvent, priority: priority, cooldown: cooldown, probability: probability, duration: duration)
        }
        switch event.kind {
        case .lateNight: return [c(.cityNight, 48, 35 * 60, 1, 14)]
        case .rainStarted: return [c(.cityRain, 54, 24 * 60, 0.95, 13)]
        case .weatherChanged:
            if environment.weather?.condition.lowercased().contains("storm") == true { return [c(.cityStorm, 60, 35 * 60, 0.75, 12)] }
            return []
        case .musicStarted: return [c(.cityMusic, 28, 18 * 60, 0.44, 12)]
        case .userReturned: return [c(.cityBusy, 34, 15 * 60, 0.40, 9)]
        case .spontaneous:
            return [
                c(.cityDelivery, 10, 22 * 60, 0.18, 10), c(.cityMeeting, 9, 18 * 60, 0.17, 9),
                c(.cityPerformer, 9, 28 * 60, 0.12, 11), c(.cityBalloon, 8, 30 * 60, 0.11, 12),
                c(.cityBird, 8, 18 * 60, 0.20, 8), c(.cityTaxi, 9, 16 * 60, 0.20, 8),
                c(.cityConstruction, 8, 35 * 60, 0.10, 12), c(.cityTraffic, 7, 12 * 60, 0.25, 8)
            ]
        default: return []
        }
    }
}

struct EIPetPersistentState: Codable, Equatable {
    var interactionCount = 0
    var lastInteraction: Date?
    // Optional additions preserve decoding of older state archives.
    var preferredSleepEdge: EIPlacementEdge?
    var recentBehaviours: [String]?
    var lastAppearance: Date?
    var appearanceCount: Int?
}

struct EIPlantPersistentState: Codable, Equatable {
    var createdAt = Date()
    var lastUpdated = Date()
    var growth = 0.08
    var bonusGrowth = 0.0
    var potVariant: Int?
    var unlockedDecorations: [String]?
}

struct EISimulationPersistentState: Codable, Equatable {
    var seed = Int.random(in: 1...999_999)
    var createdAt = Date()
    var activityMoments = 0
    var lastSimulatedAt: Date?
    var unlockedVariations: [String]?
}

struct EIPersistentState: Codable, Equatable {
    var version = 1
    var pet = EIPetPersistentState()
    var plant = EIPlantPersistentState()
    var simulation = EISimulationPersistentState()
}

enum EIDebugScenario: String, CaseIterable, Identifiable {
    case live = "Live environment"
    case morning = "Morning"
    case night = "Night"
    case longWork = "Long work session"
    case longIdle = "Long idle"
    case userReturn = "User return"
    case music = "Music start"
    case highMusic = "High music intensity"
    case rain = "Rain"
    case storm = "Storm"
    case ci = "CI activation"
    case appChange = "Application change"
    case wake = "System wake"
    var id: String { rawValue }
}

private struct EIDebugOverrides {
    var scenario: EIDebugScenario = .live
    var forcedMood: EIMoodState?
}

@MainActor
final class EnvironmentalInterfaceEngine: ObservableObject {
    static let shared = EnvironmentalInterfaceEngine()

    @Published private(set) var environment = EIEnvironment()
    @Published private(set) var currentReaction: EIReaction?
    @Published private(set) var persistentState: EIPersistentState
    @Published private(set) var behaviourState: EIBehaviourState = .hidden
    @Published private(set) var moodState: EIMoodState = .calm
    @Published private(set) var moodModifiers = EIMoodModifiers()
    @Published private(set) var animationPhase: EIAnimationPhase = .active
    @Published private(set) var retroGameRequested = false
    @Published private(set) var anyHaloSurfaceExpanded = false
    @Published private(set) var debugScenario: EIDebugScenario = .live

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
    private var debug = EIDebugOverrides()
    private var started = false
    private var lastMode: EIMode = .off
    private var lastActivity: EIActivityLevel = .balanced

    private init() {
        if let data = defaults.data(forKey: stateKey),
           let saved = try? JSONDecoder().decode(EIPersistentState.self, from: data),
           saved.version == 1 {
            persistentState = saved
        } else {
            persistentState = EIPersistentState()
        }
    }

    var settings: EISettings { settingsStore.settings }
    var shouldRender: Bool {
        switch settings.mode {
        case .off: return false
        case .pet: return settings.petResident || behaviourState != .hidden || currentReaction != nil
        case .plant, .simulation: return true
        }
    }

    func start(workspace: WorkspaceStore) {
        self.workspace = workspace
        guard !started else {
            let current = settingsStore.settings
            DispatchQueue.main.async { [weak self] in self?.settingsDidChange(current) }
            return
        }
        started = true

        settingsStore.$settings.removeDuplicates().receive(on: RunLoop.main).sink { [weak self] value in
            DispatchQueue.main.async { self?.settingsDidChange(value) }
        }.store(in: &subscriptions)

        NotificationCenter.default.publisher(for: .init("HaloRetroGameToggle")).receive(on: RunLoop.main).sink { [weak self] _ in
            guard let self, self.defaults.object(forKey: "HaloContextRetroEnabled") as? Bool ?? false else { return }
            self.retroGameRequested.toggle(); self.refreshNow()
        }.store(in: &subscriptions)

        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification).receive(on: RunLoop.main).sink { [weak self] _ in
            guard let self, self.settings.inputs.systemEvents else { return }
            self.emit(EIEvent(kind: .systemWoke, date: Date()), force: true)
        }.store(in: &subscriptions)

        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification).receive(on: RunLoop.main).sink { [weak self] _ in
            self?.refreshNow()
        }.store(in: &subscriptions)

        refreshPlantProgress()
        reconcileSimulationElapsedTime()
        let initial = settingsStore.settings
        DispatchQueue.main.async { [weak self] in self?.settingsDidChange(initial) }
    }

    func stop() {
        loopTask?.cancel(); loopTask = nil
        subscriptions.removeAll()
        persistentState.simulation.lastSimulatedAt = Date()
        persistState()
        started = false
        workspace = nil
    }

    func setAnyHaloSurfaceExpanded(_ value: Bool) {
        guard anyHaloSurfaceExpanded != value else { return }
        anyHaloSurfaceExpanded = value
        refreshNow()
    }

    func updateWeather(_ value: EIWeatherState?) { weather = value; refreshNow() }

    func emitExternalEvent(_ name: String) {
        let value = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard !value.isEmpty else { return }
        emit(EIEvent(kind: .external, date: Date(), detail: value))
    }

    func preview(_ kind: EIReactionKind, duration: TimeInterval = 5) {
        animationPhase = .entering
        currentReaction = EIReaction(kind: kind, started: Date(), duration: duration, priority: 100, source: .userInteraction)
        cooldowns[kind] = Date().addingTimeInterval(2)
        behaviourState = state(for: kind)
        updateMood(for: kind)
        remember(kind)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { [weak self] in self?.animationPhase = .active }
        postReactionChanged()
    }

    func interact(_ kind: EIReactionKind) {
        guard settings.mode == .pet,
              [.petPat, .petSnack, .petGreet, .petToy, .petCall, .petHide].contains(kind) else { return }
        persistentState.pet.interactionCount += 1
        persistentState.pet.lastInteraction = Date()
        persistState()
        if kind == .petHide {
            currentReaction = nil
            behaviourState = .hidden
            animationPhase = .exiting
            postReactionChanged()
            return
        }
        preview(kind, duration: kind == .petSnack ? 4.2 : kind == .petToy ? 7 : 4.5)
    }

    func applyDebugScenario(_ scenario: EIDebugScenario) {
        debug.scenario = scenario
        debugScenario = scenario
        if scenario == .live {
            debug.forcedMood = nil
            refreshNow()
            return
        }
        switch scenario {
        case .morning: preview(settings.mode == .simulation ? .cityMorning : settings.mode == .plant ? .plantHealthy : .petStretch, duration: 8)
        case .night: emit(EIEvent(kind: .lateNight, date: Date()), force: true)
        case .longWork: emit(EIEvent(kind: .longWorkSession, date: Date()), force: true)
        case .longIdle: emit(EIEvent(kind: .longIdlePeriod, date: Date()), force: true)
        case .userReturn: emit(EIEvent(kind: .userReturned, date: Date()), force: true)
        case .music, .highMusic: emit(EIEvent(kind: .musicStarted, date: Date()), force: true)
        case .rain, .storm: emit(EIEvent(kind: .rainStarted, date: Date()), force: true)
        case .ci: emit(EIEvent(kind: .ciActivated, date: Date(), detail: "debug-ci"), force: true)
        case .appChange: emit(EIEvent(kind: .applicationChanged, date: Date(), detail: "com.apple.dt.Xcode"), force: true)
        case .wake: emit(EIEvent(kind: .systemWoke, date: Date()), force: true)
        case .live: break
        }
        refreshNow()
    }

    func forceMood(_ mood: EIMoodState?) {
        debug.forcedMood = mood
        moodState = mood ?? derivedMood(environment)
    }

    func forceBehaviour(_ kind: EIReactionKind) { preview(kind, duration: 30) }

    private func settingsDidChange(_ value: EISettings) {
        let modeChanged = value.mode != lastMode
        let activityChanged = value.activityLevel != lastActivity
        lastMode = value.mode
        lastActivity = value.activityLevel

        if value.mode == .off {
            loopTask?.cancel(); loopTask = nil
            currentReaction = nil
            behaviourState = .hidden
            NotificationCenter.default.post(name: .init("HaloEIVisibilityChanged"), object: nil)
            return
        }
        if loopTask == nil { startLoop() }
        if modeChanged || activityChanged { scheduleNextSpontaneous(from: Date()) }
        if modeChanged {
            currentReaction = nil
            switch value.mode {
            case .pet: behaviourState = .hidden
            case .plant: behaviourState = .healthy
            case .simulation: behaviourState = cityState(for: environment.timeOfDay)
            case .off: behaviourState = .hidden
            }
        }
        refreshNow()
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
                else if self.settings.mode == .pet && !self.settings.petResident { interval = 9_000_000_000 }
                else { interval = 4_000_000_000 }
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    private func refreshNow() {
        guard settings.mode != .off else { return }
        Task { [weak self] in await self?.tick() }
    }

    private func tick() async {
        guard settings.mode != .off, let workspace else { return }
        let now = Date()

        if let reaction = currentReaction, reaction.ends <= now {
            animationPhase = .settling
            currentReaction = nil
            transitionToAmbientState()
            postReactionChanged()
        }

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
        var next = EIEnvironment(
            timeOfDay: settings.inputs.timeOfDay ? .current(at: now) : .day,
            activityDuration: settings.inputs.userActivity || settings.inputs.longWorkSessions ? max(0, now.timeIntervalSince(workSessionStart)) : 0,
            idleDuration: idle,
            isMusicPlaying: playing,
            musicIntensity: playing && spectrum.available ? spectrum.overall : nil,
            weather: settings.inputs.weather ? weather : nil,
            activeApplication: app,
            activeCI: settings.inputs.ciState ? resolveActiveCI(workspace) : nil,
            systemState: EISystemContext(battery: workspace.system.battery, charging: workspace.system.charging, lowPowerMode: workspace.system.lowPower)
        )
        applyDebugOverrides(to: &next)

        detectEvents(previousEnvironment, next, now)
        environment = next
        previousEnvironment = next
        moodModifiers = modifiers(for: next)
        moodState = debug.forcedMood ?? derivedMood(next)
        refreshPlantProgress(now: now)

        if currentReaction == nil, now >= nextSpontaneousDate {
            emit(EIEvent(kind: .spontaneous, date: now))
            scheduleNextSpontaneous(from: now)
        }
    }

    private func applyDebugOverrides(to environment: inout EIEnvironment) {
        switch debug.scenario {
        case .live: break
        case .morning: environment.timeOfDay = .morning
        case .night: environment.timeOfDay = .night
        case .longWork: environment.activityDuration = max(environment.activityDuration, settings.longWorkThresholdMinutes * 60 + 60)
        case .longIdle: environment.idleDuration = max(environment.idleDuration, 1800)
        case .userReturn: environment.idleDuration = 0
        case .music: environment.isMusicPlaying = true; environment.musicIntensity = 0.35
        case .highMusic: environment.isMusicPlaying = true; environment.musicIntensity = 0.90
        case .rain: environment.weather = EIWeatherState(condition: "Rain", isRaining: true, temperatureCelsius: 18)
        case .storm: environment.weather = EIWeatherState(condition: "Storm", isRaining: true, temperatureCelsius: 17)
        case .ci: environment.activeCI = EIContextInterface(identifier: "debug-ci", name: "Debug CI", priority: 100)
        case .appChange: environment.activeApplication = EIApplicationContext(bundleIdentifier: "com.apple.dt.Xcode", name: "Xcode")
        case .wake: break
        }
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
        guard let previous else {
            if current.timeOfDay == .night { emit(EIEvent(kind: .lateNight, date: now)) }
            return
        }
        if settings.inputs.timeOfDay, previous.timeOfDay != .night, current.timeOfDay == .night {
            emit(EIEvent(kind: .lateNight, date: now))
        }
        let threshold = settings.longWorkThresholdMinutes * 60
        if settings.inputs.longWorkSessions, !emittedLongWorkSession,
           previous.activityDuration < threshold, current.activityDuration >= threshold {
            emittedLongWorkSession = true
            emit(EIEvent(kind: .longWorkSession, date: now))
        }
        if settings.inputs.idleState {
            if previous.idleDuration >= 300, current.idleDuration < 20 {
                workSessionStart = now; emittedLongWorkSession = false
                emit(EIEvent(kind: .userReturned, date: now))
            }
            if previous.idleDuration < 900, current.idleDuration >= 900 {
                emit(EIEvent(kind: .longIdlePeriod, date: now))
            }
        }
        if settings.inputs.musicPlayback, previous.isMusicPlaying != current.isMusicPlaying {
            emit(EIEvent(kind: current.isMusicPlaying ? .musicStarted : .musicStopped, date: now))
        }
        if settings.inputs.weather, previous.weather != current.weather {
            emit(EIEvent(kind: .weatherChanged, date: now))
            if previous.weather?.isRaining != true, current.weather?.isRaining == true {
                emit(EIEvent(kind: .rainStarted, date: now))
            }
        }
        if settings.inputs.ciState, previous.activeCI != current.activeCI {
            emit(EIEvent(kind: current.activeCI == nil ? .ciDeactivated : .ciActivated, date: now,
                         detail: current.activeCI?.identifier ?? previous.activeCI?.identifier))
        }
        if settings.inputs.activeApplication,
           previous.activeApplication?.bundleIdentifier != current.activeApplication?.bundleIdentifier {
            emit(EIEvent(kind: .applicationChanged, date: now, detail: current.activeApplication?.bundleIdentifier))
        }
    }

    private func emit(_ event: EIEvent, force: Bool = false) {
        guard settings.mode != .off else { return }
        var candidates = EIBehaviourScheduler.candidates(for: event, settings: settings, environment: environment)
        if settings.mode == .pet, !settings.petOccasionalObjects {
            candidates.removeAll { [.petCoffee, .petUmbrella, .petLaptop, .petLaptopSleep, .petToy].contains($0.kind) }
        }
        let currentPriority = currentReaction?.priority ?? -1
        guard let selected = EIBehaviourScheduler.select(from: candidates, activity: settings.activityLevel,
                                                         cooldowns: cooldowns, recent: reactionHistory,
                                                         currentPriority: currentPriority, force: force, at: event.date) else { return }

        animationPhase = .entering
        currentReaction = EIReaction(kind: selected.kind, started: event.date, duration: selected.duration,
                                     priority: selected.priority, source: event.kind)
        behaviourState = selected.state
        cooldowns[selected.kind] = event.date.addingTimeInterval(selected.cooldown)
        reactionHistory.append(selected.kind)
        if reactionHistory.count > 12 { reactionHistory.removeFirst(reactionHistory.count - 12) }
        updateMood(for: selected.kind)
        applyPersistentEffect(selected.kind)
        remember(selected.kind)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in self?.animationPhase = .active }
        postReactionChanged()
    }

    private func remember(_ kind: EIReactionKind) {
        guard settings.mode == .pet else { return }
        var recent = persistentState.pet.recentBehaviours ?? []
        recent.append(kind.rawValue)
        if recent.count > 10 { recent.removeFirst(recent.count - 10) }
        persistentState.pet.recentBehaviours = recent
        if behaviourState != .hidden {
            persistentState.pet.lastAppearance = Date()
            persistentState.pet.appearanceCount = (persistentState.pet.appearanceCount ?? 0) + 1
        }
        persistState()
    }

    private func state(for kind: EIReactionKind) -> EIBehaviourState {
        switch kind {
        case .petPeekEyes, .petPeekEars, .petPeekUnder, .petPeekLeft, .petPeekRight, .petPawFirst, .petTailFirst: return .peeking
        case .petObserve, .petLookAround, .petUnimpressed, .petRainWatch: return .observing
        case .petSleep, .petCurlUp, .petLaptopSleep: return .sleeping
        case .petPlay, .petChase, .petToy, .petDance: return .playful
        case .petPat, .petSnack: return .affectionate
        case .petCoffee, .petYawn: return .tired
        case .petCelebrate, .petGreet, .petCall: return .excited
        case .petStretch, .petGroom, .petLaptop, .petUmbrella: return .idle
        case .petHide: return .hidden
        case .plantDormant, .plantNight: return .dormant
        case .plantGrowLeaf, .plantVineGrow: return .growing
        case .plantBloom: return .blooming
        case .plantHealthy, .plantSway, .plantPerk, .plantRain: return .healthy
        case .cityMorning: return .cityMorning
        case .cityDay: return .cityDay
        case .cityEvening: return .cityEvening
        case .cityNight: return .cityNight
        default: return .cityEvent
        }
    }

    private func transitionToAmbientState() {
        animationPhase = .settling
        switch settings.mode {
        case .off: behaviourState = .hidden
        case .pet: behaviourState = settings.petResident ? .idle : .hidden
        case .plant: behaviourState = environment.timeOfDay == .night ? .dormant : .healthy
        case .simulation: behaviourState = cityState(for: environment.timeOfDay)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.animationPhase = .active }
    }

    private func cityState(for time: EITimeOfDay) -> EIBehaviourState {
        switch time { case .morning: return .cityMorning; case .day: return .cityDay; case .evening: return .cityEvening; case .night: return .cityNight }
    }

    private func modifiers(for environment: EIEnvironment) -> EIMoodModifiers {
        let p = EIPetDefinition.definition(for: settings.petKind).personality
        var value = EIMoodModifiers(curiosity: p.curiosity, energy: p.energy, affection: p.affection,
                                    sleepiness: p.sleepiness, playfulness: p.playfulness)
        if environment.timeOfDay == .night { value.sleepiness = min(1, value.sleepiness + 0.22); value.energy *= 0.72 }
        if settings.petKind == .fox && (environment.timeOfDay == .evening || environment.timeOfDay == .night) { value.energy = min(1, value.energy + 0.18); value.curiosity = min(1, value.curiosity + 0.12) }
        if environment.isMusicPlaying { value.energy = min(1, value.energy + (environment.musicIntensity ?? 0.25) * 0.22); value.playfulness = min(1, value.playfulness + 0.12) }
        if environment.idleDuration > 900 { value.sleepiness = min(1, value.sleepiness + 0.18) }
        if environment.activeCI != nil { value.curiosity = min(1, value.curiosity + 0.15) }
        return value
    }

    private func derivedMood(_ environment: EIEnvironment) -> EIMoodState {
        let m = modifiers(for: environment)
        if m.sleepiness > 0.82 { return .tired }
        if currentReaction.map({ state(for: $0.kind) == .excited }) == true { return .excited }
        if currentReaction.map({ state(for: $0.kind) == .affectionate }) == true { return .affectionate }
        if m.playfulness > 0.82 && m.energy > 0.68 { return .playful }
        if m.curiosity > 0.78 { return .curious }
        return .calm
    }

    private func updateMood(for kind: EIReactionKind) {
        guard debug.forcedMood == nil else { moodState = debug.forcedMood!; return }
        switch state(for: kind) {
        case .sleeping, .tired: moodState = .tired
        case .playful: moodState = .playful
        case .affectionate: moodState = .affectionate
        case .excited: moodState = .excited
        case .curious, .peeking, .observing: moodState = .curious
        default: moodState = .calm
        }
    }

    private func applyPersistentEffect(_ kind: EIReactionKind) {
        switch kind {
        case .plantGrowLeaf, .plantVineGrow:
            persistentState.plant.bonusGrowth = min(0.22, persistentState.plant.bonusGrowth + 0.0035)
        case .plantBloom:
            persistentState.plant.bonusGrowth = min(0.22, persistentState.plant.bonusGrowth + 0.005)
        case .plantRain:
            persistentState.plant.bonusGrowth = min(0.22, persistentState.plant.bonusGrowth + 0.0015)
        case .cityBusy, .cityMusic, .cityTraffic, .cityDelivery, .cityMeeting, .cityPerformer, .cityTaxi, .cityConstruction:
            persistentState.simulation.activityMoments += 1
        default:
            break
        }
        persistState()
    }

    private func refreshPlantProgress(now: Date = Date()) {
        var plant = persistentState.plant
        let elapsed = max(0, now.timeIntervalSince(plant.lastUpdated))
        guard elapsed >= 300 else { return }
        // Roughly two weeks to move from a new plant toward mature baseline growth.
        plant.growth = min(1, plant.growth + elapsed / (14 * 24 * 3600))
        plant.lastUpdated = now
        persistentState.plant = plant
        persistState()
    }

    private func reconcileSimulationElapsedTime(now: Date = Date()) {
        let previous = persistentState.simulation.lastSimulatedAt ?? persistentState.simulation.createdAt
        let elapsed = min(7 * 24 * 3600, max(0, now.timeIntervalSince(previous)))
        if elapsed > 3600 {
            persistentState.simulation.activityMoments += min(24, Int(elapsed / 3600))
        }
        persistentState.simulation.lastSimulatedAt = now
        persistState()
    }

    private func scheduleNextSpontaneous(from date: Date) {
        nextSpontaneousDate = date.addingTimeInterval(Double.random(in: settings.activityLevel.spontaneousRange))
    }

    private func postReactionChanged() {
        NotificationCenter.default.post(name: .init("HaloEIReactionChanged"), object: nil)
    }

    private func persistState() {
        if let data = try? JSONEncoder().encode(persistentState) { defaults.set(data, forKey: stateKey) }
    }
}

// MARK: - Ambient EI renderers

@MainActor
private struct EIPetView: View {
    @ObservedObject var engine: EnvironmentalInterfaceEngine
    @ObservedObject private var preferences = EIOpenPreferencesStore.shared
    let settings: EISettings

    var body: some View {
        GeometryReader { proxy in
            HaloCompanionSprite(
                kind: settings.petKind,
                style: preferences.value.petVisual,
                size: min(proxy.size.width, proxy.size.height * 1.30),
                primary: settings.petPrimaryColor.color,
                accent: settings.petAccentColor.color,
                motion: motion,
                facingRight: facingRight
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .contextMenu {
            if settings.petInteraction {
                Button("Pat") { engine.interact(.petPat) }
                Button("Give treat") { engine.interact(.petSnack) }
                Button("Give toy") { engine.interact(.petToy) }
                Button("Call pet") { engine.interact(.petCall) }
                Button("Hide for now") { engine.interact(.petHide) }
                Divider()
                Button("Open EI") { EnvironmentalInterfaceOwnershipController.shared.open() }
            }
        }
        .onTapGesture { if settings.petInteraction { engine.interact(.petPat) } }
    }

    private var motion: HaloCompanionMotion {
        guard let kind = engine.currentReaction?.kind else {
            switch engine.behaviourState { case .hidden: return .hidden; case .sleeping: return .sleep; case .observing: return .observe; default: return .idle }
        }
        switch kind {
        case .petPeekEyes: return .peekEyes
        case .petPeekEars: return .peekEars
        case .petPeekUnder, .petPeekLeft, .petPeekRight: return .peek
        case .petPawFirst: return .paw
        case .petTailFirst: return .tail
        case .petObserve, .petRainWatch: return .observe
        case .petLookAround, .petUnimpressed: return .look
        case .petStretch: return .stretch
        case .petGroom: return .groom
        case .petCurlUp, .petSleep, .petLaptopSleep: return .sleep
        case .petPlay, .petChase, .petToy: return .playful
        case .petCoffee, .petYawn: return .tired
        case .petLaptop, .petUmbrella: return .idle
        case .petDance: return .dance
        case .petCelebrate: return .celebrate
        case .petGreet, .petCall: return .greet
        case .petPat: return .affectionate
        case .petSnack: return .snack
        case .petHide: return .hidden
        default: return .idle
        }
    }

    private var facingRight: Bool {
        switch engine.currentReaction?.kind { case .petPeekRight?: return false; default: return true }
    }
}

@MainActor
private struct EIPlantView: View {
    @ObservedObject var engine: EnvironmentalInterfaceEngine
    let settings: EISettings
    var body: some View {
        GeometryReader { proxy in
            HaloPlantRenderer(kind: settings.plantKind,
                              size: min(proxy.size.width, proxy.size.height * 1.25),
                              plantColor: settings.plantColor.color,
                              potColor: settings.plantPotColor.color,
                              growth: min(1, engine.persistentState.plant.growth + engine.persistentState.plant.bonusGrowth),
                              environment: engine.environment,
                              reaction: engine.currentReaction?.kind,
                              compact: proxy.size.height < 70)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .allowsHitTesting(false)
    }
}

@MainActor
private struct EICityView: View {
    @ObservedObject var engine: EnvironmentalInterfaceEngine
    let settings: EISettings
    var body: some View {
        HaloCityRenderer(accent: settings.simulationAccentColor.color,
                         environment: engine.environment,
                         reaction: engine.currentReaction?.kind,
                         seed: engine.persistentState.simulation.seed,
                         compact: true)
            .allowsHitTesting(false)
    }
}

@MainActor
private struct EnvironmentalInterfaceRegionView: View {
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
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .animation(.easeInOut(duration: 0.20), value: settingsStore.settings.mode)
        .animation(.easeInOut(duration: 0.20), value: engine.currentReaction?.id)
    }
}

// MARK: - Ambient EI manager

@MainActor
final class EnvironmentalInterfaceManager {
    static let shared = EnvironmentalInterfaceManager()

    @MainActor private final class Host {
        let overlay: NSPanel
        let haloWindow: NSWindow
        var screenID = ""
        var haloFrame = CGRect.zero
        var lastResolvedFrame = CGRect.zero

        init(_ haloWindow: NSWindow) {
            self.haloWindow = haloWindow
            overlay = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            overlay.backgroundColor = .clear
            overlay.isOpaque = false
            overlay.hasShadow = false
            overlay.hidesOnDeactivate = false
            overlay.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            overlay.isReleasedWhenClosed = false
            let host = NSHostingView(rootView: EnvironmentalInterfaceRegionView())
            host.sizingOptions = []
            overlay.contentView = host
        }
    }

    private weak var workspace: WorkspaceStore?
    private var hosts: [ObjectIdentifier: Host] = [:]
    private var subscriptions = Set<AnyCancellable>()
    private var started = false
    private var suppressedByHUD = false
    private var ownedSurfaceActive = false

    func start(workspace: WorkspaceStore) {
        self.workspace = workspace
        EnvironmentalInterfaceEngine.shared.start(workspace: workspace)
        guard !started else { deferRefreshAll(false); return }
        started = true

        NotificationCenter.default.publisher(for: .init("HaloPanelGeometryChanged"))
            .receive(on: RunLoop.main).sink { [weak self] in self?.handleGeometry($0) }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: .init("HaloEIVisibilityChanged"))
            .merge(with: NotificationCenter.default.publisher(for: .init("HaloEIReactionChanged")))
            .merge(with: NotificationCenter.default.publisher(for: .init("HaloEIPlacementChanged")))
            .receive(on: RunLoop.main).sink { [weak self] _ in self?.deferRefreshAll(true) }.store(in: &subscriptions)
        EISettingsStore.shared.$settings.removeDuplicates().receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.deferRefreshAll(true) }.store(in: &subscriptions)
        EIOpenPreferencesStore.shared.$value.removeDuplicates().receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.deferRefreshAll(true) }.store(in: &subscriptions)
        EnvironmentalInterfaceOwnershipController.shared.$requested.removeDuplicates().receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.deferRefreshAll(true) }.store(in: &subscriptions)
        HaloHUDNotchBridge.shared.$presentation.map { $0 != nil }.removeDuplicates().receive(on: RunLoop.main)
            .sink { [weak self] active in DispatchQueue.main.async { self?.suppressedByHUD = active; self?.refreshAll(true) } }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSWindow.willCloseNotification).receive(on: RunLoop.main)
            .sink { [weak self] note in if let window = note.object as? NSWindow { self?.remove(window) } }.store(in: &subscriptions)
    }

    func setOwnedSurfaceActive(_ active: Bool) {
        guard ownedSurfaceActive != active else { return }
        ownedSurfaceActive = active
        deferRefreshAll(true)
    }

    func stop() {
        hosts.values.forEach { $0.overlay.close() }
        hosts.removeAll(); subscriptions.removeAll()
        EnvironmentalInterfaceEngine.shared.stop()
        workspace = nil; started = false
    }

    private func deferRefreshAll(_ animated: Bool) {
        DispatchQueue.main.async { [weak self] in self?.refreshAll(animated) }
    }

    private func handleGeometry(_ note: Notification) {
        guard let halo = note.object as? NSWindow,
              let frame = note.userInfo?["frame"] as? CGRect else { return }
        let key = ObjectIdentifier(halo)
        let host = hosts[key] ?? Host(halo)
        hosts[key] = host
        if let id = note.userInfo?["screen"] as? String { host.screenID = id }
        host.haloFrame = frame
        refresh(host, false)
        updateExpanded()
    }

    private func remove(_ window: NSWindow) {
        if let host = hosts.removeValue(forKey: ObjectIdentifier(window)) { host.overlay.close() }
        updateExpanded()
    }

    private func refreshAll(_ animated: Bool) {
        hosts.values.forEach { refresh($0, animated) }
        updateExpanded()
    }

    private func updateExpanded() {
        let expanded = hosts.values.contains { $0.haloFrame.height > 82 }
        DispatchQueue.main.async { EnvironmentalInterfaceEngine.shared.setAnyHaloSurfaceExpanded(expanded) }
    }

    private func refresh(_ host: Host, _ animated: Bool) {
        let settings = EISettingsStore.shared.settings
        let engine = EnvironmentalInterfaceEngine.shared
        guard !suppressedByHUD,
              !ownedSurfaceActive,
              settings.mode != .off, engine.shouldRender,
              host.haloFrame.width > 1, host.haloFrame.height > 1 else {
            host.overlay.orderOut(nil); return
        }
        let frame = resolvedFrame(host, settings, engine.currentReaction)
        guard frame.width >= 24, frame.height >= 20 else { host.overlay.orderOut(nil); return }
        host.overlay.ignoresMouseEvents = !(settings.mode == .pet && settings.petInteraction)
        if animated, host.lastResolvedFrame != .zero, host.lastResolvedFrame != frame {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.20
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                host.overlay.animator().setFrame(frame, display: false)
            }
        } else {
            host.overlay.setFrame(frame, display: false)
        }
        host.lastResolvedFrame = frame
        host.overlay.orderFrontRegardless()
    }

    private func resolvedFrame(_ host: Host, _ settings: EISettings, _ reaction: EIReaction?) -> CGRect {
        let halo = host.haloFrame
        let compact = halo.height <= 82
        let size: CGSize
        switch settings.mode {
        case .off: return .zero
        case .pet:
            let scale = CGFloat(settings.petScale)
            size = CGSize(width: (compact ? 90 : 120) * scale, height: (compact ? 48 : 72) * scale)
        case .plant:
            size = CGSize(width: compact ? 82 : 118, height: compact ? 54 : 90)
        case .simulation:
            size = CGSize(width: min(compact ? 180 : 360, max(120, halo.width * (compact ? 0.74 : 0.72))), height: compact ? min(52, halo.height) : 112)
        }

        if let context = EIPlacementRegistry.shared.context(for: host.screenID),
           !context.availableRegions.isEmpty,
           let region = chooseRegion(context, size) {
            return CGRect(x: halo.minX + region.minX, y: halo.minY + region.minY,
                          width: min(size.width, region.width), height: min(size.height, region.height))
        }

        if settings.mode == .simulation {
            return CGRect(x: halo.midX - min(size.width, halo.width - 8) / 2,
                          y: compact ? halo.minY : halo.minY + 7,
                          width: min(size.width, halo.width - 8), height: min(size.height, halo.height))
        }

        var edge = preferredEdge(reaction?.kind, compact)
        if !compact, EnvironmentalInterfaceEngine.shared.environment.activeCI != nil,
           reaction?.kind != .petPeekLeft, reaction?.kind != .petPeekRight {
            edge = .underNotch
        }
        switch edge {
        case .left, .bottomLeft:
            return CGRect(x: halo.minX + (compact ? 2 : 9), y: compact ? halo.minY : halo.minY + 7,
                          width: min(size.width, halo.width / (compact ? 1.8 : 1.35)), height: min(size.height, halo.height))
        case .right, .bottomRight:
            let width = min(size.width, halo.width / (compact ? 1.8 : 1.35))
            return CGRect(x: halo.maxX - width - (compact ? 2 : 9), y: compact ? halo.minY : halo.minY + 7,
                          width: width, height: min(size.height, halo.height))
        case .underNotch:
            return CGRect(x: halo.midX - min(size.width, halo.width) / 2,
                          y: compact ? halo.minY : halo.maxY - min(halo.height, size.height + 34),
                          width: min(size.width, halo.width), height: min(size.height, halo.height))
        }
    }

    private func preferredEdge(_ kind: EIReactionKind?, _ compact: Bool) -> EIPlacementEdge {
        switch kind {
        case .petPeekLeft?: return compact ? .left : .bottomLeft
        case .petPeekRight?: return compact ? .right : .bottomRight
        case .petPeekUnder?, .petPeekEyes?, .petPeekEars?, .petPawFirst?: return .underNotch
        default: return compact ? .right : .bottomRight
        }
    }

    private func chooseRegion(_ context: EIPlacementContext, _ size: CGSize) -> CGRect? {
        let ranked = context.availableRegions.sorted { a, b in
            let af = a.width >= size.width && a.height >= size.height
            let bf = b.width >= size.width && b.height >= size.height
            return af == bf ? a.width * a.height > b.width * b.height : af && !bf
        }
        return ranked.first(where: { region in
            region.width >= min(24, size.width) && region.height >= min(20, size.height) &&
            !context.contentExclusionRegions.contains(where: { exclusion in
                let intersection = exclusion.intersection(region)
                return !intersection.isNull && intersection.width * intersection.height > region.width * region.height * 0.45
            })
        }) ?? ranked.first
    }
}

// MARK: - Settings / inspector

@MainActor
struct EnvironmentalInterfaceSettingsView: View {
    @ObservedObject private var store = EISettingsStore.shared
    @ObservedObject private var engine = EnvironmentalInterfaceEngine.shared
    @ObservedObject private var preferences = EIOpenPreferencesStore.shared
    @ObservedObject private var ownership = EnvironmentalInterfaceOwnershipController.shared
    @AppStorage("HaloEIDebugInspectorEnabled") private var inspectorEnabled = false
    @State private var debugReaction: EIReactionKind = .petPeekUnder
    @State private var debugMood: EIMoodState = .calm

    var body: some View {
        Section("Environmental Interface") {
            Picker("Environmental Interface", selection: binding(\.mode)) {
                ForEach(EIMode.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
            }.pickerStyle(.segmented)
            Text("EI lives around the actual Halo geometry. CI remains the higher-priority owner; EI yields to CI exclusion regions instead of covering controls.")
                .font(.caption).foregroundStyle(.secondary)
        }

        if store.settings.mode != .off {
            Section("Ownership & shortcut") {
                HStack {
                    Button(ownership.isRequested ? "Close EI" : "Open EI") {
                        ownership.isRequested ? ownership.close() : ownership.open()
                    }
                    Button("Open EI Studio") { ownership.open(editor: true) }
                }
                Toggle("Enable EI shortcut", isOn: pref(\.shortcutEnabled))
                if preferences.value.shortcutEnabled {
                    Picker("Key", selection: pref(\.shortcutKey)) {
                        Text("E").tag(UInt32(14)); Text("I").tag(UInt32(34)); Text("P").tag(UInt32(35)); Text("J").tag(UInt32(38))
                    }
                    Picker("Modifiers", selection: pref(\.shortcutModifiers)) {
                        Text("Option + Command").tag(UInt32(2304)); Text("Control + Option").tag(UInt32(6144)); Text("Control + Shift").tag(UInt32(4608))
                    }
                    Text("Current shortcut: \(shortcutDescription). Press it again to close the EI surface.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Activity") {
                Picker("Activity level", selection: binding(\.activityLevel)) {
                    ForEach(EIActivityLevel.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
                Text(activityDescription).font(.caption).foregroundStyle(.secondary)
            }

            Section("Environmental inputs") {
                Toggle("Time of day", isOn: input(\.timeOfDay))
                Toggle("User activity", isOn: input(\.userActivity))
                Toggle("Long work sessions", isOn: input(\.longWorkSessions))
                if store.settings.inputs.longWorkSessions {
                    Slider(value: binding(\.longWorkThresholdMinutes), in: 30...240, step: 5) { Text("Long work threshold") }
                }
                Toggle("Idle state", isOn: input(\.idleState))
                Toggle("Music / playback", isOn: input(\.musicPlayback))
                Toggle("Weather, when available", isOn: input(\.weather))
                Toggle("Active application", isOn: input(\.activeApplication))
                Toggle("Context Interface state", isOn: input(\.ciState))
                Toggle("System events", isOn: input(\.systemEvents))
                Text("EI only uses high-level context required for behaviour selection; it does not inspect documents, messages, browsing data or typed content.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            modeSettings

            if store.settings.mode == .pet || store.settings.mode == .plant { cozySettings }

            Section("Live state") {
                LabeledContent("Behaviour") { Text(engine.behaviourState.rawValue.capitalized) }
                LabeledContent("Mood") { Text(engine.moodState.rawValue.capitalized) }
                LabeledContent("Time") { Text(engine.environment.timeOfDay.rawValue.capitalized) }
                LabeledContent("Idle") { Text(duration(engine.environment.idleDuration)) }
                LabeledContent("Work session") { Text(duration(engine.environment.activityDuration)) }
                LabeledContent("Music") { Text(engine.environment.isMusicPlaying ? "Playing" : "Not playing") }
                LabeledContent("Active CI") { Text(engine.environment.activeCI?.name ?? "None") }
                if let weather = engine.environment.weather { LabeledContent("Weather") { Text(weather.condition) } }
            }

            Section("Developer") {
                Toggle("EI Inspector", isOn: $inspectorEnabled)
                if inspectorEnabled { inspector }
            }

            Section {
                Button("Reset EI settings") { store.reset() }
                Text("Pets never die, starve, become permanently unhappy, or require streaks. Plants never die and weather never controls plant health.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var modeSettings: some View {
        switch store.settings.mode {
        case .off:
            EmptyView()
        case .pet:
            Section("Pet") {
                Picker("Companion", selection: binding(\.petKind)) {
                    ForEach(EIPetKind.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Visual treatment", selection: pref(\.petVisual)) {
                    Text("Soft Vector").tag(EIPetVisualStyle.smooth)
                    Text("Illustrated Vector").tag(EIPetVisualStyle.illustrated)
                    Text("Minimal Vector").tag(EIPetVisualStyle.minimal)
                }
                Slider(value: binding(\.petScale), in: 0.7...1.6, step: 0.05) { Text("Pet size") }
                ColorPicker("Pet color", selection: color(\.petPrimaryColor), supportsOpacity: false)
                ColorPicker("Accent / objects", selection: color(\.petAccentColor), supportsOpacity: false)
                Toggle("Allow interactions", isOn: binding(\.petInteraction))
                Toggle("Look toward cursor", isOn: binding(\.petLooksAtCursor))
                Toggle("Hide a little when approached", isOn: binding(\.petHidesWhenApproached))
                Toggle("Occasionally carry tiny objects", isOn: binding(\.petOccasionalObjects))
                Toggle("Keep pet quietly resident around Halo", isOn: binding(\.petResident))
                Divider()
                Toggle("Allow pet to roam outside Halo", isOn: pref(\.roam))
                Toggle("Walk through the menu bar", isOn: pref(\.menuBar)).disabled(!preferences.value.roam)
                Toggle("Peek from screen edges", isOn: pref(\.screenEdges)).disabled(!preferences.value.roam)
                HStack {
                    Button("Pat") { engine.interact(.petPat) }
                    Button("Treat") { engine.interact(.petSnack) }
                    Button("Toy") { engine.interact(.petToy) }
                    Button("Call") { engine.interact(.petCall) }
                    Button("Hide") { engine.interact(.petHide) }
                }.disabled(!store.settings.petInteraction)
                personalitySummary
                Text("Hidden is the normal pet state. Spontaneous appearances are weighted, cooled down and recent behaviours are suppressed so the companion does not become wallpaper.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        case .plant:
            Section("Plant") {
                Picker("Plant", selection: binding(\.plantKind)) {
                    ForEach(EIPlantKind.allCases) { Text($0.rawValue).tag($0) }
                }
                ColorPicker("Plant color", selection: color(\.plantColor), supportsOpacity: false)
                ColorPicker("Pot color", selection: color(\.plantPotColor), supportsOpacity: false)
                ProgressView(value: min(1, engine.persistentState.plant.growth + engine.persistentState.plant.bonusGrowth))
                HStack {
                    Button("Water") { engine.preview(.plantRain, duration: 7) }
                    Button("Touch") { engine.preview(.plantPerk, duration: 5) }
                    Button("Bloom") { engine.preview(.plantBloom, duration: 10) }
                    Button("Sway") { engine.preview(.plantSway, duration: 8) }
                }
                Text("Growth persists over days and weeks. Optional interaction creates a pleasant moment but is never required for health or progression.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        case .simulation:
            Section("Simulation") {
                Picker("World", selection: binding(\.simulationKind)) {
                    ForEach(EISimulationKind.allCases) { Text($0.rawValue).tag($0) }
                }
                ColorPicker("City accent", selection: color(\.simulationAccentColor), supportsOpacity: false)
                Text("Tiny City treats the notch as architecture: a central structure with autonomous traffic, inhabitants, lighting, weather and occasional minute-scale events. Aquarium and Terrarium use the same world-state interfaces and can be added without changing the scheduler.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Traffic") { engine.preview(.cityTraffic, duration: 10) }
                    Button("Rain") { engine.preview(.cityRain, duration: 10) }
                    Button("Night") { engine.preview(.cityNight, duration: 12) }
                    Button("Delivery") { engine.preview(.cityDelivery, duration: 10) }
                }
            }
        }
    }

    private var personalitySummary: some View {
        let p = EIPetDefinition.definition(for: store.settings.petKind).personality
        return VStack(alignment: .leading, spacing: 4) {
            Text("Personality").font(.caption.bold())
            HStack(spacing: 10) {
                Text("Curiosity \(Int(p.curiosity * 100))")
                Text("Energy \(Int(p.energy * 100))")
                Text("Affection \(Int(p.affection * 100))")
                Text("Play \(Int(p.playfulness * 100))")
            }.font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var cozySettings: some View {
        Section("EI surface environment") {
            Picker("Room style", selection: pref(\.roomStyle)) {
                ForEach(EIRoomStyle.allCases) { Text($0.rawValue).tag($0) }
            }
            ColorPicker("Room color", selection: prefColor(\.room), supportsOpacity: false)
            ColorPicker("Accent light", selection: prefColor(\.accent), supportsOpacity: false)
            ColorPicker("Floor", selection: prefColor(\.floor), supportsOpacity: false)
            Toggle("Window", isOn: pref(\.window))
            Toggle("Lamp", isOn: pref(\.lamp))
            Toggle("Rug", isOn: pref(\.rug))
            Toggle("Wall shelf", isOn: pref(\.shelf))
            Toggle("Room plants", isOn: pref(\.roomPlants))
        }
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 9) {
            Picker("Environment", selection: Binding(get: { engine.debugScenario }, set: { engine.applyDebugScenario($0) })) {
                ForEach(EIDebugScenario.allCases) { Text($0.rawValue).tag($0) }
            }
            Picker("Mood", selection: $debugMood) {
                ForEach(EIMoodState.allCases) { Text($0.rawValue.capitalized).tag($0) }
            }
            HStack {
                Button("Force mood") { engine.forceMood(debugMood) }
                Button("Use automatic mood") { engine.forceMood(nil) }
            }
            Picker("Behaviour", selection: $debugReaction) {
                ForEach(EIReactionKind.allCases.filter { $0.mode == store.settings.mode }) { Text($0.title).tag($0) }
            }
            Button("Run behaviour for 30s") { engine.forceBehaviour(debugReaction) }
            HStack {
                Button("Morning") { engine.applyDebugScenario(.morning) }
                Button("Night") { engine.applyDebugScenario(.night) }
                Button("Long work") { engine.applyDebugScenario(.longWork) }
                Button("Return") { engine.applyDebugScenario(.userReturn) }
                Button("Rain") { engine.applyDebugScenario(.rain) }
            }
            Text("Inspector changes are temporary. Choose Live environment to return to real context.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var activityDescription: String {
        switch store.settings.activityLevel {
        case .subtle: return "Professional mode: long quiet stretches with rare discoveries."
        case .balanced: return "Default: enough life to feel present without constant motion."
        case .expressive: return "More frequent reactions, still with hidden/rest periods and cooldowns."
        }
    }

    private var shortcutDescription: String {
        let modifiers: String
        switch preferences.value.shortcutModifiers { case 6144: modifiers = "⌃⌥"; case 4608: modifiers = "⌃⇧"; default: modifiers = "⌥⌘" }
        let key: String
        switch preferences.value.shortcutKey { case 34: key = "I"; case 35: key = "P"; case 38: key = "J"; default: key = "E" }
        return modifiers + key
    }

    private func binding<T>(_ keyPath: WritableKeyPath<EISettings, T>) -> Binding<T> {
        Binding(get: { store.settings[keyPath: keyPath] }, set: { newValue in
            var value = store.settings; value[keyPath: keyPath] = newValue
            DispatchQueue.main.async { store.settings = value }
        })
    }
    private func input(_ keyPath: WritableKeyPath<EIInputSettings, Bool>) -> Binding<Bool> {
        Binding(get: { store.settings.inputs[keyPath: keyPath] }, set: { newValue in
            var value = store.settings; value.inputs[keyPath: keyPath] = newValue
            DispatchQueue.main.async { store.settings = value }
        })
    }
    private func color(_ keyPath: WritableKeyPath<EISettings, WidgetColor>) -> Binding<Color> {
        Binding(get: { store.settings[keyPath: keyPath].color }, set: { newValue in
            var value = store.settings; value[keyPath: keyPath] = WidgetColor(newValue)
            DispatchQueue.main.async { store.settings = value }
        })
    }
    private func pref<T>(_ keyPath: WritableKeyPath<EIOpenPreferences, T>) -> Binding<T> {
        Binding(get: { preferences.value[keyPath: keyPath] }, set: { newValue in
            var value = preferences.value; value[keyPath: keyPath] = newValue
            DispatchQueue.main.async { preferences.value = value }
        })
    }
    private func prefColor(_ keyPath: WritableKeyPath<EIOpenPreferences, WidgetColor>) -> Binding<Color> {
        Binding(get: { preferences.value[keyPath: keyPath].color }, set: { newValue in
            var value = preferences.value; value[keyPath: keyPath] = WidgetColor(newValue)
            DispatchQueue.main.async { preferences.value = value }
        })
    }
    private func duration(_ value: TimeInterval) -> String {
        let seconds = max(0, Int(value.rounded()))
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m"
    }
}
