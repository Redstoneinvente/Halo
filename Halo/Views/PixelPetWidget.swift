import SwiftUI
import AppKit
import CoreGraphics

// MARK: - Pixel Pal
//
// HARD REQUIREMENT
// Pixel Pal must never prioritize detail over expression. It is a cute retro
// 8-bit character first. At small widget sizes, aggressively remove anatomy
// and detail rather than shrinking the character. A pair of expressive pixel
// eyes is a complete and desirable representation of the pet. Larger widgets
// provide room for movement and interactions, not a miniature apartment.

enum HaloPixelPetSpecies: String, Codable, CaseIterable, Identifiable {
    case cat = "Cat", dog = "Dog", fox = "Fox", rabbit = "Rabbit"
    case robot = "Robot", slime = "Slime", ghost = "Ghost"
    var id: String { rawValue }
}

enum HaloPixelPetPersonality: String, Codable, CaseIterable, Identifiable {
    case sleepy = "Sleepy", playful = "Playful", chaotic = "Chaotic", curious = "Curious"
    case affectionate = "Affectionate", independent = "Independent"
    var id: String { rawValue }
}

enum HaloPixelPetNeedsMode: String, Codable, CaseIterable, Identifiable {
    case off = "Off", casual = "Casual", full = "Full"
    var id: String { rawValue }
}

// Kept for preference decoding compatibility with the first Pixel Pet build.
// The expression-first renderer intentionally does not draw themed rooms.
enum HaloPixelPetEnvironment: String, Codable, CaseIterable, Identifiable {
    case cozy = "Cozy Bedroom", cyberpunk = "Cyberpunk", japanese = "Japanese Room", arcade = "Arcade"
    case space = "Space Station", forest = "Forest Cabin", minimal = "Minimal Mac", developer = "Developer Cave"
    var id: String { rawValue }
}

enum HaloPixelPetPalette: String, Codable, CaseIterable, Identifiable {
    case classic = "Classic", gameBoy = "Game Boy", monochrome = "Monochrome", amber = "Amber CRT", neon = "Neon", custom = "Custom"
    var id: String { rawValue }
}

enum HaloPixelPetLEDMode: String, Codable, CaseIterable, Identifiable {
    // Legacy cases stay decodable; normalized() migrates them to the new modes.
    case off = "Off"
    case status = "Pet Status"
    case breathing = "Breathing"
    case music = "Music"
    case environment = "Environment"
    case green = "Green"
    case amber = "Amber"
    case red = "Red"
    case rgb = "RGB"
    case battery = "Battery"
    case mood = "Pet Mood"
    case system = "System"
    case custom = "Custom"

    var id: String { rawValue }
    static let settingsCases: [Self] = [.off, .green, .amber, .red, .rgb, .battery, .music, .mood, .system, .custom]
}

enum HaloPixelPetActivity: String, Codable {
    case idle, walk, sleep, eat, play, dance, working, gaming, charging, timer, greet, celebrate, concerned, bored
}

struct HaloPixelPetRGB: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var color: Color { Color(red: min(1, max(0, red)), green: min(1, max(0, green)), blue: min(1, max(0, blue))) }
}

struct HaloPixelPetPreferences: Codable, Equatable {
    var version = 1
    var name = "Pixel"
    var species: HaloPixelPetSpecies = .cat
    var personality: HaloPixelPetPersonality = .curious
    var needsMode: HaloPixelPetNeedsMode = .off
    var environment: HaloPixelPetEnvironment = .minimal
    var palette: HaloPixelPetPalette = .classic
    var customPrimary = HaloPixelPetRGB(red: 0.93, green: 0.64, blue: 0.34)
    var customAccent = HaloPixelPetRGB(red: 0.35, green: 1.0, blue: 0.46)
    var autonomy = 0.78
    var animationSpeed = 1.0
    var interactionFrequency = 0.62
    var dayNightCycle = true
    var soundEffects = false
    var showWindow = false
    var showFurniture = false
    var showAmbientEvents = true
    var ledMode: HaloPixelPetLEDMode = .mood
    var ledSize = 4.0
    var ledBrightness = 0.82
    var ledBloom = 3.0

    func normalized() -> Self {
        var v = self
        v.version = 1
        v.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
        if v.name.isEmpty { v.name = "Pixel" }
        v.autonomy = min(1, max(0, autonomy))
        v.animationSpeed = min(2, max(0.35, animationSpeed))
        v.interactionFrequency = min(1, max(0, interactionFrequency))
        v.ledSize = min(9, max(2, ledSize))
        v.ledBrightness = min(1, max(0.15, ledBrightness))
        v.ledBloom = min(12, max(0, ledBloom))
        v.customPrimary.red = min(1, max(0, v.customPrimary.red))
        v.customPrimary.green = min(1, max(0, v.customPrimary.green))
        v.customPrimary.blue = min(1, max(0, v.customPrimary.blue))
        v.customAccent.red = min(1, max(0, v.customAccent.red))
        v.customAccent.green = min(1, max(0, v.customAccent.green))
        v.customAccent.blue = min(1, max(0, v.customAccent.blue))
        switch v.ledMode {
        case .status: v.ledMode = .mood
        case .breathing: v.ledMode = .rgb
        case .environment: v.ledMode = .system
        default: break
        }
        return v
    }

    var primaryColor: Color {
        switch palette {
        case .classic:
            switch species {
            case .cat: return Color(red: 0.92, green: 0.64, blue: 0.36)
            case .dog: return Color(red: 0.73, green: 0.48, blue: 0.27)
            case .fox: return Color(red: 0.96, green: 0.39, blue: 0.16)
            case .rabbit: return Color(red: 0.84, green: 0.82, blue: 0.86)
            case .robot: return Color(red: 0.44, green: 0.72, blue: 0.86)
            case .slime: return Color(red: 0.33, green: 0.84, blue: 0.52)
            case .ghost: return Color(red: 0.76, green: 0.78, blue: 0.94)
            }
        case .gameBoy: return Color(red: 0.39, green: 0.48, blue: 0.22)
        case .monochrome: return Color(white: 0.82)
        case .amber: return Color(red: 1, green: 0.58, blue: 0.12)
        case .neon: return Color(red: 0.24, green: 0.92, blue: 0.90)
        case .custom: return customPrimary.color
        }
    }

    var accentColor: Color {
        switch palette {
        case .classic: return Color(red: 1, green: 0.91, blue: 0.67)
        case .gameBoy: return Color(red: 0.72, green: 0.78, blue: 0.42)
        case .monochrome: return .white
        case .amber: return Color(red: 1, green: 0.82, blue: 0.36)
        case .neon: return Color(red: 1, green: 0.27, blue: 0.75)
        case .custom: return customAccent.color
        }
    }
}

struct HaloPixelPetState: Codable, Equatable {
    var hunger = 0.88
    var energy = 0.82
    var affection = 0.72
    var lastInteraction = Date()
    var lastCareUpdate = Date()
}

struct HaloPixelPetNeedsSnapshot {
    let hunger: Double
    let energy: Double
    let affection: Double
    var needsAttention: Bool { hunger < 0.34 || energy < 0.28 }
}

@MainActor
final class HaloPixelPetStore: ObservableObject {
    static let shared = HaloPixelPetStore()
    @Published var preferences: HaloPixelPetPreferences { didSet { persistPreferences() } }
    @Published private(set) var state: HaloPixelPetState { didSet { persistState() } }
    @Published private(set) var transientActivity: HaloPixelPetActivity?

    private let defaults: UserDefaults
    private let preferencesKey = "HaloPixelPet.preferences.v1"
    private let stateKey = "HaloPixelPet.state.v1"
    private var clearActivityWork: DispatchWorkItem?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: preferencesKey),
           let decoded = try? JSONDecoder().decode(HaloPixelPetPreferences.self, from: data),
           decoded.version == 1 {
            preferences = decoded.normalized()
        } else {
            preferences = HaloPixelPetPreferences()
        }
        if let data = defaults.data(forKey: stateKey),
           let decoded = try? JSONDecoder().decode(HaloPixelPetState.self, from: data) {
            state = decoded
        } else {
            state = HaloPixelPetState()
        }
    }

    func update<T>(_ keyPath: WritableKeyPath<HaloPixelPetPreferences, T>, _ value: T) {
        var next = preferences
        next[keyPath: keyPath] = value
        preferences = next.normalized()
    }

    func reset() {
        preferences = HaloPixelPetPreferences()
        state = HaloPixelPetState()
        transientActivity = nil
    }

    func needs(at date: Date) -> HaloPixelPetNeedsSnapshot {
        let hours = max(0, date.timeIntervalSince(state.lastCareUpdate) / 3600)
        switch preferences.needsMode {
        case .off:
            return .init(hunger: 1, energy: 1, affection: max(0.65, state.affection))
        case .casual:
            return .init(hunger: max(0.45, state.hunger - hours * 0.010), energy: max(0.42, state.energy - hours * 0.007), affection: max(0.42, state.affection - hours * 0.004))
        case .full:
            return .init(hunger: max(0.20, state.hunger - hours * 0.022), energy: max(0.18, state.energy - hours * 0.016), affection: max(0.28, state.affection - hours * 0.008))
        }
    }

    func feed() { care(hunger: 0.28, energy: 0.04, affection: 0.03, activity: .eat) }
    func pet() { care(hunger: 0, energy: 0.01, affection: 0.16, activity: .greet) }
    func play() { care(hunger: -0.02, energy: -0.04, affection: 0.14, activity: .play) }
    func quickReaction() { show(.greet, seconds: 1.2) }

    private func care(hunger: Double, energy: Double, affection: Double, activity: HaloPixelPetActivity) {
        let current = needs(at: Date())
        state.hunger = min(1, max(0, current.hunger + hunger))
        state.energy = min(1, max(0, current.energy + energy))
        state.affection = min(1, max(0, current.affection + affection))
        state.lastCareUpdate = Date()
        state.lastInteraction = Date()
        show(activity, seconds: 2.1)
        if preferences.soundEffects { NSSound(named: NSSound.Name("Tink"))?.play() }
    }

    func show(_ activity: HaloPixelPetActivity, seconds: Double) {
        clearActivityWork?.cancel()
        transientActivity = activity
        let work = DispatchWorkItem { [weak self] in self?.transientActivity = nil }
        clearActivityWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func persistPreferences() {
        if let data = try? JSONEncoder().encode(preferences.normalized()) { defaults.set(data, forKey: preferencesKey) }
    }

    private func persistState() {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: stateKey) }
    }
}

private struct HaloPixelPetContext {
    let activity: HaloPixelPetActivity
    let detail: String
    let battery: Int?
    let charging: Bool

    @MainActor
    static func resolve(store: AppStore, media: MediaService, system: SystemService, pet: HaloPixelPetStore, date: Date) -> Self {
        if let forced = pet.transientActivity {
            return .init(activity: forced, detail: "Interacting", battery: system.battery, charging: system.charging)
        }
        if store.finished {
            return .init(activity: .celebrate, detail: "Timer finished", battery: system.battery, charging: system.charging)
        }
        if system.charging {
            return .init(activity: .charging, detail: "Charging", battery: system.battery, charging: true)
        }
        if let battery = system.battery, battery <= 15 {
            return .init(activity: .concerned, detail: "Low power", battery: battery, charging: false)
        }
        if media.isPlaying {
            return .init(activity: .dance, detail: "Music playing", battery: system.battery, charging: system.charging)
        }
        if store.deadline != nil || store.pausedSeconds > 0 {
            return .init(activity: .timer, detail: "Focus timer", battery: system.battery, charging: system.charging)
        }

        let app = NSWorkspace.shared.frontmostApplication
        let bundle = app?.bundleIdentifier?.lowercased() ?? ""
        let appName = app?.localizedName?.lowercased() ?? ""
        if bundle == "com.apple.dt.xcode" || appName == "xcode" {
            return .init(activity: .working, detail: "Coding with you", battery: system.battery, charging: system.charging)
        }
        let games = ["steam", "minecraft", "roblox", "retroarch", "whisky", "crossover"]
        if games.contains(where: { bundle.contains($0) || appName.contains($0) }) {
            return .init(activity: .gaming, detail: "Game mode", battery: system.battery, charging: system.charging)
        }

        let mouseIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let keyboardIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let idleSeconds = min(mouseIdle, keyboardIdle)
        if idleSeconds > 180 {
            return .init(activity: .bored, detail: "Waiting for you", battery: system.battery, charging: system.charging)
        }

        let hour = Calendar.autoupdatingCurrent.component(.hour, from: date)
        if pet.preferences.dayNightCycle && (hour >= 23 || hour < 6) {
            return .init(activity: .sleep, detail: "Sleeping", battery: system.battery, charging: system.charging)
        }
        if hour >= 6 && hour < 10 {
            return .init(activity: .greet, detail: "Morning", battery: system.battery, charging: system.charging)
        }

        let phase = Int(date.timeIntervalSinceReferenceDate / max(12, 42 - pet.preferences.autonomy * 26)) % 6
        let activity: HaloPixelPetActivity
        switch pet.preferences.personality {
        case .sleepy where phase <= 1: activity = .sleep
        case .playful where phase <= 2: activity = .play
        case .chaotic where phase <= 2: activity = phase == 0 ? .dance : .walk
        case .curious where phase <= 2: activity = .walk
        case .affectionate where phase == 0: activity = .greet
        default: activity = phase == 0 ? .walk : .idle
        }
        return .init(activity: activity, detail: "Hanging out", battery: system.battery, charging: system.charging)
    }
}

struct HaloPixelPetWidget: View {
    @Environment(\.openNotchGridColumnSpan) private var gridColumnSpan
    @Environment(\.openNotchGridRowSpan) private var gridRowSpan
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore
    @ObservedObject private var pet = HaloPixelPetStore.shared
    @ObservedObject private var media: MediaService
    @ObservedObject private var system: SystemService
    @State private var cursor = CGPoint.zero
    @State private var hovering = false

    init(store: AppStore, workspace: WorkspaceStore) {
        self.store = store
        self.workspace = workspace
        _media = ObservedObject(wrappedValue: workspace.media)
        _system = ObservedObject(wrappedValue: workspace.system)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.8 : 1.0 / 12.0, paused: false)) { timeline in
            GeometryReader { proxy in
                let columns = min(8, max(1, gridColumnSpan ?? Int((proxy.size.width / 96).rounded())))
                let rows = min(4, max(1, gridRowSpan ?? Int((proxy.size.height / 84).rounded())))
                let context = HaloPixelPetContext.resolve(store: store, media: media, system: system, pet: pet, date: timeline.date)
                HaloPixelPetStage(
                    columns: columns,
                    rows: rows,
                    size: proxy.size,
                    date: timeline.date,
                    activity: context.activity,
                    preferences: pet.preferences,
                    cursor: cursor,
                    cursorActive: hovering,
                    reduceMotion: reduceMotion,
                    battery: context.battery,
                    charging: context.charging,
                    musicPlaying: media.isPlaying
                )
                .accessibilityLabel("Pixel Pal \(pet.preferences.name), \(context.detail)")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { pet.pet() }
        .onTapGesture { pet.quickReaction() }
        .onContinuousHover { phase in
            switch phase {
            case .active(let point): cursor = point; hovering = true
            case .ended: hovering = false
            }
        }
        .contextMenu {
            Button("Pet \(pet.preferences.name)") { pet.pet() }
            Button("Play") { pet.play() }
            Button("Feed") { pet.feed() }
            Divider()
            Button("Pixel Pal Settings…") { HaloPixelPetSettingsWindowController.shared.show() }
        }
        .help("Click to greet · double-click to pet · right-click for interactions and settings")
    }
}

private enum HaloPixelPetPresentation {
    case face, faceStrip, peek, tinyCreature, creatureStrip, personality, playground
}

private struct HaloPixelPetStage: View {
    let columns: Int
    let rows: Int
    let size: CGSize
    let date: Date
    let activity: HaloPixelPetActivity
    let preferences: HaloPixelPetPreferences
    let cursor: CGPoint
    let cursorActive: Bool
    let reduceMotion: Bool
    let battery: Int?
    let charging: Bool
    let musicPlaying: Bool

    private var presentation: HaloPixelPetPresentation {
        if columns == 1 && rows == 1 { return .face }
        if rows == 1 && columns == 2 { return .faceStrip }
        if columns == 1 { return .peek }
        if columns == 2 && rows == 2 { return .tinyCreature }
        if rows == 1 { return .creatureStrip }
        if columns <= 4 && rows <= 2 { return .personality }
        return .playground
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.08)
            switch presentation {
            case .face: face
            case .faceStrip: movingFace
            case .peek: peek
            case .tinyCreature: centeredCreature
            case .creatureStrip: roamingCreature(compact: true)
            case .personality:
                occasionalProp
                roamingCreature(compact: false)
            case .playground:
                if preferences.showAmbientEvents { ambientPixels }
                occasionalProp
                occasionalVisitor
                roamingCreature(compact: false)
            }
            HaloPixelPetLED(
                mode: preferences.ledMode,
                activity: activity,
                battery: battery,
                charging: charging,
                musicPlaying: musicPlaying,
                custom: preferences.customAccent.color,
                size: preferences.ledSize,
                brightness: preferences.ledBrightness,
                bloom: preferences.ledBloom,
                date: date
            )
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.04), lineWidth: 1).allowsHitTesting(false))
    }

    private var face: some View {
        HaloPixelPetFace(activity: activity, color: preferences.accentColor, date: date, accessory: .none)
            .frame(width: min(size.width * 0.78, 68), height: min(size.height * 0.62, 40))
    }

    private var movingFace: some View {
        let phase = Int(date.timeIntervalSinceReferenceDate / 3.6) % 6
        let x: CGFloat = {
            switch phase {
            case 1: return size.width * 0.27
            case 2: return size.width * 0.12
            case 3: return size.width * 0.88
            case 4: return size.width * 0.72
            default: return size.width * 0.50
            }
        }()
        let hidden = phase == 3 && Int(date.timeIntervalSinceReferenceDate * 3) % 3 == 0
        return HaloPixelPetFace(activity: activity, color: preferences.accentColor, date: date, accessory: .none)
            .frame(width: min(72, size.width * 0.42), height: min(42, size.height * 0.62))
            .opacity(hidden ? 0 : 1)
            .position(x: x, y: size.height * 0.53)
    }

    private var peek: some View {
        let phase = date.timeIntervalSinceReferenceDate * preferences.animationSpeed
        let bob = reduceMotion ? CGFloat.zero : CGFloat(sin(phase * 1.7) * 3)
        return ZStack {
            HaloPixelPetEars(species: preferences.species, color: preferences.primaryColor)
                .frame(width: min(54, size.width * 0.72), height: 20)
                .offset(y: -18)
            HaloPixelPetFace(activity: activity, color: preferences.accentColor, date: date, accessory: .none)
                .frame(width: min(58, size.width * 0.76), height: 34)
        }
        .offset(y: size.height * 0.23 + bob)
    }

    private var centeredCreature: some View {
        let side = min(min(size.width, size.height) * 0.64, 66)
        return HaloPixelPetSprite(species: preferences.species, activity: activity, primary: preferences.primaryColor, accent: preferences.accentColor)
            .frame(width: side, height: side)
    }

    private func roamingCreature(compact: Bool) -> some View {
        let phase = date.timeIntervalSinceReferenceDate * preferences.animationSpeed
        let sprite: CGFloat = compact ? min(44, size.height * 0.72) : min(58, min(size.width * 0.24, size.height * 0.46))
        let horizontalPadding = sprite * 0.62 + 8
        let travel = max(0, size.width - horizontalPadding * 2)
        let autonomousX = horizontalPadding + travel * CGFloat((sin(phase * (activity == .bored ? 0.95 : 0.52)) + 1) * 0.5)
        let cursorX = min(size.width - horizontalPadding, max(horizontalPadding, cursor.x))
        let x: CGFloat = cursorActive && columns >= 4 && preferences.autonomy > 0.25 ? cursorX : autonomousX
        let baseY = size.height * (compact ? 0.60 : 0.72)
        let jump: CGFloat = {
            guard !reduceMotion else { return 0 }
            switch activity {
            case .dance: return -abs(CGFloat(sin(phase * 4.2))) * min(9, size.height * 0.12)
            case .play: return -abs(CGFloat(sin(phase * 2.8))) * min(13, size.height * 0.17)
            case .celebrate: return -abs(CGFloat(sin(phase * 5.2))) * min(16, size.height * 0.20)
            case .walk, .bored: return -abs(CGFloat(sin(phase * 2.4))) * 2
            default: return 0
            }
        }()
        return HaloPixelPetSprite(species: preferences.species, activity: activity, primary: preferences.primaryColor, accent: preferences.accentColor)
            .frame(width: sprite, height: sprite)
            .position(x: x, y: baseY + jump)
    }

    @ViewBuilder private var occasionalProp: some View {
        let slot = Int(date.timeIntervalSinceReferenceDate / 12) % 6
        if activity == .dance {
            HaloPixelPetProp(kind: .music, color: preferences.accentColor).frame(width: 24, height: 24).position(x: size.width * 0.72, y: size.height * 0.28)
        } else if activity == .charging {
            HaloPixelPetProp(kind: .heart, color: preferences.accentColor).frame(width: 24, height: 24).position(x: size.width * 0.76, y: size.height * 0.28)
        } else if activity == .timer || activity == .celebrate {
            HaloPixelPetProp(kind: .alert, color: preferences.accentColor).frame(width: 22, height: 22).position(x: size.width * 0.72, y: size.height * 0.28)
        } else if slot == 1 && columns >= 3 {
            HaloPixelPetProp(kind: .ball, color: preferences.primaryColor).frame(width: 22, height: 22).position(x: size.width * 0.28, y: size.height * 0.76)
        } else if slot == 3 && columns >= 4 {
            HaloPixelPetProp(kind: .box, color: preferences.accentColor).frame(width: 26, height: 22).position(x: size.width * 0.74, y: size.height * 0.77)
        }
    }

    @ViewBuilder private var occasionalVisitor: some View {
        let slot = Int(date.timeIntervalSinceReferenceDate / 24) % 8
        if slot == 6 && columns >= 5 && rows >= 3 {
            HaloPixelPetSprite(species: visitorSpecies, activity: .idle, primary: preferences.primaryColor.opacity(0.70), accent: preferences.accentColor.opacity(0.75))
                .frame(width: 34, height: 34)
                .position(x: size.width * 0.84, y: size.height * 0.72)
                .opacity(0.82)
        }
    }

    private var visitorSpecies: HaloPixelPetSpecies {
        switch preferences.species {
        case .cat: return .ghost
        case .ghost: return .cat
        case .robot: return .slime
        default: return .robot
        }
    }

    @ViewBuilder private var ambientPixels: some View {
        let slot = Int(date.timeIntervalSinceReferenceDate / 16) % 5
        if slot == 2 && columns >= 5 {
            HaloPixelPetAmbientSpark(color: preferences.accentColor, date: date)
                .frame(width: size.width * 0.45, height: min(40, size.height * 0.24))
                .position(x: size.width * 0.67, y: size.height * 0.22)
        }
    }
}

private enum HaloPixelPetFaceAccessory { case none }

private struct HaloPixelPetFace: View {
    let activity: HaloPixelPetActivity
    let color: Color
    let date: Date
    let accessory: HaloPixelPetFaceAccessory

    var body: some View {
        Canvas { context, size in
            let columns: CGFloat = 16
            let rows: CGFloat = 10
            let cell = max(1, floor(min(size.width / columns, size.height / rows)))
            let ox = floor((size.width - cell * columns) / 2)
            let oy = floor((size.height - cell * rows) / 2)
            func pixel(_ x: Int, _ y: Int, _ w: Int = 1, _ h: Int = 1, _ tone: Color? = nil) {
                let rect = CGRect(x: ox + CGFloat(x) * cell, y: oy + CGFloat(y) * cell, width: CGFloat(w) * cell, height: CGFloat(h) * cell)
                context.fill(Path(rect), with: .color(tone ?? color))
            }
            func heart(_ x: Int, _ y: Int) {
                pixel(x, y, 1, 1); pixel(x + 2, y, 1, 1); pixel(x - 1, y + 1, 5, 1); pixel(x, y + 2, 3, 1); pixel(x + 1, y + 3, 1, 1)
            }
            func star(_ x: Int, _ y: Int) {
                pixel(x + 1, y, 1, 1); pixel(x, y + 1, 3, 1); pixel(x + 1, y + 2, 1, 1); pixel(x - 1, y + 1, 1, 1); pixel(x + 3, y + 1, 1, 1)
            }
            func happyEye(_ x: Int, _ y: Int) {
                pixel(x, y + 1); pixel(x + 1, y); pixel(x + 2, y + 1)
            }
            func sleepyEye(_ x: Int, _ y: Int) { pixel(x, y, 3, 1) }
            func dotEye(_ x: Int, _ y: Int) { pixel(x, y, 2, 2) }

            let blink = activity == .idle && Int(date.timeIntervalSinceReferenceDate * 4) % 23 == 0
            switch activity {
            case .charging:
                heart(3, 3); heart(10, 3)
                pixel(7, 1); pixel(6, 3, 2, 1); pixel(7, 4); pixel(6, 5)
            case .concerned:
                dotEye(3, 3); dotEye(11, 3)
                pixel(4, 6); pixel(11, 6); pixel(4, 7, 1, 2); pixel(11, 7, 1, 2)
            case .sleep:
                sleepyEye(3, 4); sleepyEye(10, 4)
                pixel(13, 2); pixel(14, 1); pixel(13, 0)
            case .dance:
                happyEye(3, 3); happyEye(10, 3)
                pixel(13, 1); pixel(13, 2); pixel(12, 3, 2, 1); pixel(11, 4)
            case .celebrate:
                star(3, 3); star(10, 3)
            case .timer:
                pixel(4, 2, 1, 4); pixel(4, 7); pixel(11, 2, 1, 4); pixel(11, 7)
            case .working:
                dotEye(3, 3); dotEye(11, 3)
                pixel(2, 2, 4, 1); pixel(10, 2, 4, 1); pixel(6, 3, 4, 1)
            case .gaming:
                star(3, 3); star(10, 3)
                pixel(7, 7, 2, 1)
            case .greet, .play, .eat:
                happyEye(3, 3); happyEye(10, 3)
                pixel(7, 7, 2, 1)
            case .bored:
                pixel(3, 3, 3, 1); pixel(10, 4, 2, 2)
                pixel(13, 2, 2, 1); pixel(14, 3); pixel(13, 4); pixel(13, 6)
            case .walk, .idle:
                if blink {
                    sleepyEye(3, 4); sleepyEye(10, 4)
                } else {
                    dotEye(3, 3); dotEye(11, 3)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct HaloPixelPetEars: View {
    let species: HaloPixelPetSpecies
    let color: Color
    var body: some View {
        Canvas { context, size in
            let cell = max(1, floor(min(size.width / 14, size.height / 5)))
            let ox = floor((size.width - cell * 14) / 2)
            let oy = floor((size.height - cell * 5) / 2)
            func p(_ x: Int, _ y: Int, _ w: Int = 1, _ h: Int = 1) {
                context.fill(Path(CGRect(x: ox + CGFloat(x) * cell, y: oy + CGFloat(y) * cell, width: CGFloat(w) * cell, height: CGFloat(h) * cell)), with: .color(color))
            }
            switch species {
            case .rabbit:
                p(3, 0, 2, 5); p(9, 0, 2, 5)
            case .dog:
                p(2, 2, 3, 3); p(9, 2, 3, 3)
            case .robot:
                p(6, 0, 2, 3); p(7, 0); p(5, 3, 4, 1)
            case .slime, .ghost:
                p(4, 3, 6, 2)
            default:
                p(3, 2); p(4, 1); p(5, 2); p(9, 2); p(10, 1); p(11, 2)
            }
        }
    }
}

private struct HaloPixelPetSprite: View {
    let species: HaloPixelPetSpecies
    let activity: HaloPixelPetActivity
    let primary: Color
    let accent: Color

    var body: some View {
        Canvas { context, size in
            let cell = max(1, floor(min(size.width / 16, size.height / 16)))
            let ox = floor((size.width - cell * 16) / 2)
            let oy = floor((size.height - cell * 16) / 2)
            func fill(_ x: Int, _ y: Int, _ w: Int = 1, _ h: Int = 1, _ color: Color? = nil) {
                let rect = CGRect(x: ox + CGFloat(x) * cell, y: oy + CGFloat(y) * cell, width: CGFloat(w) * cell, height: CGFloat(h) * cell)
                context.fill(Path(rect), with: .color(color ?? primary))
            }
            let dark = Color.black.opacity(0.82)

            if species == .slime {
                fill(3, 6, 10, 6); fill(4, 4, 8, 3)
            } else if species == .ghost {
                fill(4, 3, 8, 9); fill(3, 5, 10, 6); fill(4, 12, 2, 2); fill(8, 12, 2, 2); fill(11, 12, 2, 2)
            } else if species == .robot {
                fill(4, 3, 8, 7); fill(5, 10, 6, 4); fill(7, 1, 2, 2, accent); fill(8, 0, 1, 2, accent)
            } else {
                fill(4, 7, 8, 6); fill(5, 4, 7, 6); fill(4, 12, 2, 2); fill(10, 12, 2, 2)
                switch species {
                case .cat:
                    fill(5, 2, 2, 3); fill(10, 2, 2, 3); fill(12, 9, 2, 2); fill(13, 7, 1, 3)
                case .dog:
                    fill(4, 3, 2, 5); fill(11, 3, 2, 5); fill(12, 10, 2, 2)
                case .fox:
                    fill(4, 2, 3, 4); fill(10, 2, 3, 4); fill(12, 9, 3, 3); fill(14, 10, 1, 2, accent)
                case .rabbit:
                    fill(5, 0, 2, 5); fill(10, 0, 2, 5); fill(6, 1, 1, 3, accent); fill(10, 1, 1, 3, accent)
                default: break
                }
            }

            switch activity {
            case .sleep:
                fill(5, 6, 3, 1, dark); fill(9, 6, 3, 1, dark)
            case .charging:
                fill(5, 6, 2, 2, accent); fill(10, 6, 2, 2, accent)
                fill(7, 10); fill(8, 9); fill(9, 10, 1, 1, accent)
            case .concerned:
                fill(5, 6, 2, 2, dark); fill(10, 6, 2, 2, dark); fill(5, 9, 1, 3, .cyan); fill(11, 9, 1, 3, .cyan)
            case .dance:
                fill(5, 6, 2, 2, dark); fill(10, 6, 2, 2, dark)
                fill(3, 4, 2, 5, accent); fill(12, 4, 2, 5, accent); fill(5, 3, 7, 1, accent)
            case .working:
                fill(5, 6, 2, 2, dark); fill(10, 6, 2, 2, dark)
                fill(4, 5, 4, 1, accent); fill(9, 5, 4, 1, accent); fill(8, 6, 1, 1, accent)
            case .gaming, .celebrate:
                fill(5, 6, 2, 2, accent); fill(10, 6, 2, 2, accent)
            case .greet, .play, .eat:
                fill(5, 7); fill(6, 6); fill(7, 7); fill(10, 7); fill(11, 6); fill(12, 7)
            case .timer:
                fill(6, 5, 1, 4, accent); fill(11, 5, 1, 4, accent); fill(6, 10, 1, 1, accent); fill(11, 10, 1, 1, accent)
            case .bored:
                fill(5, 7, 3, 1, dark); fill(10, 7, 2, 2, dark)
            case .idle, .walk:
                fill(5, 6, 2, 2, dark); fill(10, 6, 2, 2, dark)
            }
        }
        .accessibilityHidden(true)
    }
}

private enum HaloPixelPetPropKind { case ball, heart, music, box, alert }

private struct HaloPixelPetProp: View {
    let kind: HaloPixelPetPropKind
    let color: Color
    var body: some View {
        Canvas { context, size in
            let cell = max(1, floor(min(size.width / 8, size.height / 8)))
            let ox = floor((size.width - cell * 8) / 2)
            let oy = floor((size.height - cell * 8) / 2)
            func p(_ x: Int, _ y: Int, _ w: Int = 1, _ h: Int = 1, _ c: Color? = nil) {
                context.fill(Path(CGRect(x: ox + CGFloat(x) * cell, y: oy + CGFloat(y) * cell, width: CGFloat(w) * cell, height: CGFloat(h) * cell)), with: .color(c ?? color))
            }
            switch kind {
            case .ball:
                p(2, 2, 4, 4); p(1, 3, 6, 2); p(3, 1, 2, 6)
            case .heart:
                p(1, 2, 2, 2); p(5, 2, 2, 2); p(1, 3, 6, 2); p(2, 5, 4, 1); p(3, 6, 2, 1)
            case .music:
                p(4, 1, 1, 5); p(5, 1, 2, 1); p(2, 5, 3, 2); p(5, 4, 2, 2)
            case .box:
                p(1, 2, 6, 5, Color.brown.opacity(0.85)); p(1, 2, 6, 1); p(3, 2, 2, 5)
            case .alert:
                p(3, 1, 2, 4); p(3, 6, 2, 2)
            }
        }
    }
}

private struct HaloPixelPetAmbientSpark: View {
    let color: Color
    let date: Date
    var body: some View {
        Canvas { context, size in
            let phase = date.timeIntervalSinceReferenceDate
            for index in 0..<6 {
                let seed = Double(index) * 1.73
                let x = size.width * CGFloat((sin(phase * 0.22 + seed) + 1) * 0.5)
                let y = size.height * CGFloat((cos(phase * 0.31 + seed * 1.8) + 1) * 0.5)
                let rect = CGRect(x: floor(x), y: floor(y), width: 2, height: 2)
                context.fill(Path(rect), with: .color(color.opacity(0.45)))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct HaloPixelPetLED: View {
    let mode: HaloPixelPetLEDMode
    let activity: HaloPixelPetActivity
    let battery: Int?
    let charging: Bool
    let musicPlaying: Bool
    let custom: Color
    let size: Double
    let brightness: Double
    let bloom: Double
    let date: Date

    private var color: Color {
        switch mode {
        case .off: return .clear
        case .green: return .green
        case .amber: return .orange
        case .red: return .red
        case .rgb:
            return Color(hue: (date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 8)) / 8, saturation: 0.88, brightness: 1)
        case .battery:
            guard let battery else { return .gray }
            if charging { return .green }
            if battery <= 15 { return .red }
            if battery <= 35 { return .orange }
            return .green
        case .music:
            return musicPlaying ? .purple : .gray
        case .mood, .status:
            switch activity {
            case .concerned: return .red
            case .sleep: return .blue
            case .charging, .greet, .celebrate: return .green
            case .dance, .play: return .purple
            case .working, .gaming, .timer: return .cyan
            case .bored: return .orange
            default: return .green
            }
        case .system, .environment:
            if charging { return .green }
            if let battery, battery <= 15 { return .red }
            if activity == .timer { return .cyan }
            return .green
        case .custom: return custom
        case .breathing: return .green
        }
    }

    var body: some View {
        if mode != .off {
            let seconds = date.timeIntervalSinceReferenceDate
            let pulse: Double = {
                switch mode {
                case .music where musicPlaying: return 0.58 + 0.42 * ((sin(seconds * 8) + 1) * 0.5)
                case .rgb, .breathing: return 0.65 + 0.35 * ((sin(seconds * 2.2) + 1) * 0.5)
                default: return 1
                }
            }()
            Circle()
                .fill(color.opacity(brightness * pulse))
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color.white.opacity(0.45 * brightness), lineWidth: 0.5))
                .shadow(color: color.opacity(0.58 * brightness * pulse), radius: bloom)
        }
    }
}

@MainActor
final class HaloPixelPetSettingsWindowController {
    static let shared = HaloPixelPetSettingsWindowController()
    private var window: NSWindow?

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let controller = NSHostingController(rootView: HaloPixelPetSettingsView())
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 620, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Halo · Pixel Pal"
        window.contentViewController = controller
        window.isReleasedWhenClosed = false
        window.minSize = CGSize(width: 540, height: 580)
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct HaloPixelPetSettingsView: View {
    @ObservedObject private var pet = HaloPixelPetStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    HaloPixelPetFace(activity: .greet, color: pet.preferences.accentColor, date: Date(), accessory: .none)
                        .frame(width: 72, height: 48)
                        .padding(10)
                        .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pixel Pal").font(.title2.weight(.bold))
                        Text("Expression first. Tiny at 1×1, alive at 8×4 — never a miniature room.").foregroundStyle(.secondary)
                    }
                }

                group("Companion") {
                    LabeledContent("Name") { TextField("Pixel", text: bind(\.name)).frame(width: 180) }
                    LabeledContent("Species") { Picker("", selection: bind(\.species)) { ForEach(HaloPixelPetSpecies.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 180) }
                    LabeledContent("Personality") { Picker("", selection: bind(\.personality)) { ForEach(HaloPixelPetPersonality.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 180) }
                    LabeledContent("Optional care") { Picker("", selection: bind(\.needsMode)) { ForEach(HaloPixelPetNeedsMode.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 180) }
                    Text("Care is optional and never punitive. The pet is primarily a contextual Halo expression, not a chore simulator.").font(.caption).foregroundStyle(.secondary)
                }

                group("Behavior") {
                    Toggle("Follow day / night", isOn: bind(\.dayNightCycle))
                    Toggle("Occasional pixel events", isOn: bind(\.showAmbientEvents))
                    slider("Animation speed", bind(\.animationSpeed), 0.35...2)
                    slider("Autonomy", bind(\.autonomy), 0...1)
                    slider("Interaction frequency", bind(\.interactionFrequency), 0...1)
                    Toggle("Sound effects", isOn: bind(\.soundEffects))
                }

                group("Pixel Style") {
                    LabeledContent("Palette") { Picker("", selection: bind(\.palette)) { ForEach(HaloPixelPetPalette.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 180) }
                    if pet.preferences.palette == .custom {
                        RGBSliders(title: "Pet", red: bind(\.customPrimary.red), green: bind(\.customPrimary.green), blue: bind(\.customPrimary.blue))
                        RGBSliders(title: "Expression / LED", red: bind(\.customAccent.red), green: bind(\.customAccent.green), blue: bind(\.customAccent.blue))
                    }
                }

                group("Fake LED") {
                    LabeledContent("Behavior") {
                        Picker("", selection: bind(\.ledMode)) {
                            ForEach(HaloPixelPetLEDMode.settingsCases) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 180)
                    }
                    slider("Size", bind(\.ledSize), 2...9)
                    slider("Brightness", bind(\.ledBrightness), 0.15...1)
                    slider("Bloom", bind(\.ledBloom), 0...12)
                }

                HStack {
                    Button("Pet") { pet.pet() }
                    Button("Play") { pet.play() }
                    Button("Feed") { pet.feed() }
                    Spacer()
                    Button("Reset Pixel Pal") { pet.reset() }
                }
            }
            .padding(24)
        }
        .frame(minWidth: 540, minHeight: 580)
    }

    private func bind<T>(_ path: WritableKeyPath<HaloPixelPetPreferences, T>) -> Binding<T> {
        Binding(get: { pet.preferences[keyPath: path] }, set: { pet.update(path, $0) })
    }

    @ViewBuilder private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            content()
        }
        .padding(14)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder private func slider(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue)).monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}

private struct RGBSliders: View {
    let title: String
    @Binding var red: Double
    @Binding var green: Double
    @Binding var blue: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption.weight(.semibold))
            HStack { Text("R").frame(width: 14); Slider(value: $red, in: 0...1) }
            HStack { Text("G").frame(width: 14); Slider(value: $green, in: 0...1) }
            HStack { Text("B").frame(width: 14); Slider(value: $blue, in: 0...1) }
        }
    }
}
