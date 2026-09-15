import SwiftUI
import AppKit

// MARK: - Pixel Pet
// A normal opened-notch widget. This intentionally does not reactivate Halo's dormant EI runtime.

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
    case off = "Off", status = "Pet Status", breathing = "Breathing", music = "Music", environment = "Environment"
    var id: String { rawValue }
}

enum HaloPixelPetActivity: String, Codable {
    case idle, walk, sleep, eat, play, dance, working, gaming, charging, timer, greet, celebrate, concerned
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
    var needsMode: HaloPixelPetNeedsMode = .casual
    var environment: HaloPixelPetEnvironment = .cozy
    var palette: HaloPixelPetPalette = .classic
    var customPrimary = HaloPixelPetRGB(red: 0.93, green: 0.64, blue: 0.34)
    var customAccent = HaloPixelPetRGB(red: 0.98, green: 0.92, blue: 0.72)
    var autonomy = 0.78
    var animationSpeed = 1.0
    var interactionFrequency = 0.62
    var dayNightCycle = true
    var soundEffects = false
    var showWindow = true
    var showFurniture = true
    var showAmbientEvents = true
    var ledMode: HaloPixelPetLEDMode = .status
    var ledSize = 4.0
    var ledBrightness = 0.82
    var ledBloom = 3.0

    func normalized() -> Self {
        var v = self
        v.version = 1
        v.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
        if v.name.isEmpty { v.name = "Pixel" }
        v.autonomy = min(1, max(0, autonomy)); v.animationSpeed = min(2, max(0.35, animationSpeed)); v.interactionFrequency = min(1, max(0, interactionFrequency))
        v.ledSize = min(9, max(2, ledSize)); v.ledBrightness = min(1, max(0.15, ledBrightness)); v.ledBloom = min(12, max(0, ledBloom))
        v.customPrimary.red = min(1, max(0, v.customPrimary.red)); v.customPrimary.green = min(1, max(0, v.customPrimary.green)); v.customPrimary.blue = min(1, max(0, v.customPrimary.blue))
        v.customAccent.red = min(1, max(0, v.customAccent.red)); v.customAccent.green = min(1, max(0, v.customAccent.green)); v.customAccent.blue = min(1, max(0, v.customAccent.blue))
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
        if let data = defaults.data(forKey: preferencesKey), let decoded = try? JSONDecoder().decode(HaloPixelPetPreferences.self, from: data), decoded.version == 1 { preferences = decoded.normalized() }
        else { preferences = HaloPixelPetPreferences() }
        if let data = defaults.data(forKey: stateKey), let decoded = try? JSONDecoder().decode(HaloPixelPetState.self, from: data) { state = decoded }
        else { state = HaloPixelPetState() }
    }

    func update<T>(_ keyPath: WritableKeyPath<HaloPixelPetPreferences, T>, _ value: T) {
        var next = preferences; next[keyPath: keyPath] = value; preferences = next.normalized()
    }

    func reset() { preferences = HaloPixelPetPreferences(); state = HaloPixelPetState(); transientActivity = nil }

    func needs(at date: Date) -> HaloPixelPetNeedsSnapshot {
        let hours = max(0, date.timeIntervalSince(state.lastCareUpdate) / 3600)
        switch preferences.needsMode {
        case .off: return .init(hunger: 1, energy: 1, affection: max(0.65, state.affection))
        case .casual: return .init(hunger: max(0.45, state.hunger - hours * 0.010), energy: max(0.42, state.energy - hours * 0.007), affection: max(0.42, state.affection - hours * 0.004))
        case .full: return .init(hunger: max(0.20, state.hunger - hours * 0.022), energy: max(0.18, state.energy - hours * 0.016), affection: max(0.28, state.affection - hours * 0.008))
        }
    }

    func feed() { care(hunger: 0.28, energy: 0.04, affection: 0.03, activity: .eat) }
    func pet() { care(hunger: 0, energy: 0.01, affection: 0.16, activity: .greet) }
    func play() { care(hunger: -0.02, energy: -0.04, affection: 0.14, activity: .play) }
    func quickReaction() { show(.greet, seconds: 1.2) }

    private func care(hunger: Double, energy: Double, affection: Double, activity: HaloPixelPetActivity) {
        let current = needs(at: Date())
        state.hunger = min(1, max(0, current.hunger + hunger)); state.energy = min(1, max(0, current.energy + energy)); state.affection = min(1, max(0, current.affection + affection))
        state.lastCareUpdate = Date(); state.lastInteraction = Date(); show(activity, seconds: 2.1)
        if preferences.soundEffects { NSSound(named: NSSound.Name("Tink"))?.play() }
    }

    func show(_ activity: HaloPixelPetActivity, seconds: Double) {
        clearActivityWork?.cancel(); transientActivity = activity
        let work = DispatchWorkItem { [weak self] in self?.transientActivity = nil }; clearActivityWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func persistPreferences() { if let data = try? JSONEncoder().encode(preferences.normalized()) { defaults.set(data, forKey: preferencesKey) } }
    private func persistState() { if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: stateKey) } }
}

private struct HaloPixelPetContext {
    let activity: HaloPixelPetActivity
    let detail: String

    @MainActor
    static func resolve(store: AppStore, media: MediaService, system: SystemService, pet: HaloPixelPetStore, date: Date) -> Self {
        if let forced = pet.transientActivity { return .init(activity: forced, detail: "Interacting") }
        let needs = pet.needs(at: date)
        if store.finished { return .init(activity: .celebrate, detail: "Focus complete") }
        if store.deadline != nil || store.pausedSeconds > 0 { return .init(activity: .timer, detail: "Keeping time") }
        if system.charging { return .init(activity: .charging, detail: "Charging together") }
        if let battery = system.battery, battery <= 15 { return .init(activity: .concerned, detail: "Battery is low") }
        if media.isPlaying { return .init(activity: .dance, detail: "Listening to music") }

        let app = NSWorkspace.shared.frontmostApplication
        let bundle = app?.bundleIdentifier?.lowercased() ?? ""
        let appName = app?.localizedName?.lowercased() ?? ""
        if bundle == "com.apple.dt.xcode" || appName == "xcode" { return .init(activity: .working, detail: "Coding with you") }
        let games = ["steam", "minecraft", "roblox", "retroarch", "whisky", "crossover"]
        if games.contains(where: { bundle.contains($0) || appName.contains($0) }) { return .init(activity: .gaming, detail: "Game mode") }
        if needs.energy < 0.34 { return .init(activity: .sleep, detail: "Taking a nap") }
        if needs.hunger < 0.34 { return .init(activity: .concerned, detail: "Could use a snack") }

        let hour = Calendar.autoupdatingCurrent.component(.hour, from: date)
        if hour >= 23 || hour < 6 { return .init(activity: .sleep, detail: "Late-night nap") }
        let phase = Int(date.timeIntervalSinceReferenceDate / max(12, 42 - pet.preferences.autonomy * 26)) % 6
        switch pet.preferences.personality {
        case .sleepy where phase <= 1: return .init(activity: .sleep, detail: "Dozing")
        case .playful where phase <= 2: return .init(activity: .play, detail: "Playing")
        case .chaotic where phase <= 2: return .init(activity: phase == 0 ? .dance : .walk, detail: "Causing tiny trouble")
        case .curious where phase <= 2: return .init(activity: .walk, detail: "Exploring")
        case .affectionate where phase == 0: return .init(activity: .greet, detail: "Checking in")
        default: break
        }
        return .init(activity: phase == 0 ? .walk : .idle, detail: "Hanging out")
    }
}

struct HaloPixelPetWidget: View {
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
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
        self.store = store; self.workspace = workspace
        _media = ObservedObject(wrappedValue: workspace.media); _system = ObservedObject(wrappedValue: workspace.system)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.8 : 1.0 / 12.0, paused: false)) { timeline in
            GeometryReader { proxy in
                let columns = min(8, max(1, gridColumnSpan ?? Int((proxy.size.width / 96).rounded())))
                let rows = min(4, max(1, gridRowSpan ?? Int((proxy.size.height / 84).rounded())))
                let context = HaloPixelPetContext.resolve(store: store, media: media, system: system, pet: pet, date: timeline.date)
                HaloPixelPetHabitat(columns: columns, rows: rows, size: proxy.size, date: timeline.date, activity: context.activity, detail: context.detail, needs: pet.needs(at: timeline.date), preferences: pet.preferences, musicPlaying: media.isPlaying, cursor: cursor, cursorActive: hovering, reduceMotion: reduceMotion)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { pet.pet() }
        .onTapGesture { pet.quickReaction() }
        .onContinuousHover { phase in
            switch phase { case .active(let point): cursor = point; hovering = true; case .ended: hovering = false }
        }
        .contextMenu {
            Button("Feed \(pet.preferences.name)") { pet.feed() }
            Button("Pet \(pet.preferences.name)") { pet.pet() }
            Button("Play") { pet.play() }
            Divider()
            Button("Pixel Pet Settings…") { HaloPixelPetSettingsWindowController.shared.show() }
        }
        .help("Click to greet · double-click to pet · right-click for care and settings")
        .accessibilityLabel("Halo Pixel Pet, \(pet.preferences.name)")
    }
}

private struct HaloPixelPetHabitat: View {
    let columns: Int, rows: Int
    let size: CGSize
    let date: Date
    let activity: HaloPixelPetActivity
    let detail: String
    let needs: HaloPixelPetNeedsSnapshot
    let preferences: HaloPixelPetPreferences
    let musicPlaying: Bool
    let cursor: CGPoint
    let cursorActive: Bool
    let reduceMotion: Bool

    private var tier: Int {
        if columns == 1 && rows == 1 { return 0 }
        if rows == 1 || columns == 1 { return 1 }
        if columns <= 2 && rows <= 2 { return 2 }
        if columns <= 3 && rows <= 2 { return 3 }
        if columns <= 4 && rows <= 2 { return 4 }
        if columns <= 6 && rows <= 3 { return 5 }
        if columns == 8 && rows == 4 { return 7 }
        return 6
    }

    var body: some View {
        ZStack {
            HaloPixelPetBackdrop(environment: preferences.environment, dayNight: preferences.dayNightCycle, date: date, tier: tier)
            if tier == 0 { tinyPet }
            else {
                if preferences.showWindow && (rows >= 2 || columns == 1) {
                    HaloPixelWindow(date: date, dayNight: preferences.dayNightCycle)
                        .frame(width: min(82, size.width * 0.26), height: min(58, size.height * 0.28))
                        .position(x: columns == 1 ? size.width * 0.5 : size.width * 0.18, y: columns == 1 ? size.height * 0.20 : size.height * 0.23)
                }
                if preferences.showFurniture { furniture }
                if tier >= 6 && preferences.showAmbientEvents { ambientEvent }
                if tier == 7 { fullHabitatDividers }
                petInWorld
                if rows >= 2 && columns >= 3 { statusCaption }
            }
            HaloPixelPetLED(mode: preferences.ledMode, activity: activity, needs: needs, musicPlaying: musicPlaying, environment: preferences.environment, size: preferences.ledSize, brightness: preferences.ledBrightness, bloom: preferences.ledBloom, date: date)
                .padding(7).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .clipShape(RoundedRectangle(cornerRadius: tier == 0 ? 10 : 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: tier == 0 ? 10 : 14, style: .continuous).stroke(Color.white.opacity(0.055), lineWidth: 1).allowsHitTesting(false))
    }

    private var tinyPet: some View {
        let side = min(size.width, size.height) * 0.76
        return HaloPixelPetSprite(species: preferences.species, activity: activity, primary: preferences.primaryColor, accent: preferences.accentColor)
            .frame(width: side, height: side)
            .overlay(alignment: .topTrailing) { if needs.needsAttention { Text("!").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.orange).offset(x: 4, y: -3) } }
    }

    private var petInWorld: some View {
        let sprite = min(max(38, min(size.width / CGFloat(max(2, columns)), size.height * 0.36)), tier >= 5 ? 74 : 62)
        let floorY = size.height * (columns == 1 ? 0.80 : 0.73)
        let phase = date.timeIntervalSinceReferenceDate * preferences.animationSpeed
        let targetX: CGFloat = {
            if cursorActive && preferences.autonomy > 0.25 && [.curious, .playful, .chaotic].contains(preferences.personality) { return min(size.width - sprite * 0.55, max(sprite * 0.55, cursor.x)) }
            if [.walk, .play, .dance].contains(activity) {
                let travel = max(0, size.width - sprite - 18); return sprite * 0.5 + 9 + travel * CGFloat((sin(phase * 0.72) + 1) * 0.5)
            }
            if activity == .working { return tier >= 4 ? size.width * 0.72 : size.width * 0.58 }
            if activity == .charging { return size.width * 0.78 }
            return size.width * 0.5
        }()
        let bounce: CGFloat = reduceMotion ? 0 : CGFloat(activity == .dance ? sin(phase * 3.4) * 5 : activity == .walk ? -abs(sin(phase * 2.2)) * 2 : 0)
        return HaloPixelPetSprite(species: preferences.species, activity: activity, primary: preferences.primaryColor, accent: preferences.accentColor)
            .frame(width: sprite, height: sprite).position(x: targetX, y: floorY - sprite * 0.38 + bounce)
    }

    @ViewBuilder private var furniture: some View {
        let floor = size.height * 0.76
        if columns >= 2 { HaloPixelBed(accent: preferences.accentColor).frame(width: min(76, size.width * 0.22), height: 34).position(x: size.width * 0.84, y: floor - 8) }
        if columns >= 2 && rows >= 2 {
            HaloPixelBowl(color: preferences.primaryColor).frame(width: 28, height: 18).position(x: size.width * 0.34, y: floor + 2)
            HaloPixelToy(color: preferences.accentColor).frame(width: 24, height: 24).position(x: size.width * 0.47, y: floor - 1)
        }
        if columns >= 3 && rows >= 2 { HaloPixelPlant().frame(width: 34, height: 52).position(x: size.width * 0.08, y: floor - 22) }
        if tier >= 4 { HaloPixelComputer(active: activity == .working || activity == .gaming || activity == .timer, accent: preferences.accentColor).frame(width: 56, height: 50).position(x: size.width * 0.70, y: floor - 25) }
        if tier >= 5 { HaloPixelLamp(on: isNight, accent: preferences.accentColor).frame(width: 30, height: 58).position(x: size.width * 0.57, y: floor - 29) }
        if rows == 1 { HaloPixelToy(color: preferences.accentColor).frame(width: 20, height: 20).position(x: size.width * 0.22, y: size.height * 0.73) }
    }

    private var statusCaption: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(preferences.name).font(.system(size: 9, weight: .bold, design: .monospaced))
            Text(detail).font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
        }.padding(.horizontal, 6).padding(.vertical, 4).background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 4)).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(7)
    }

    @ViewBuilder private var ambientEvent: some View {
        let phase = Int(date.timeIntervalSince1970 / 18) % 4
        if phase == 0 { HaloPixelShootingStar(accent: preferences.accentColor).frame(width: 54, height: 24).position(x: size.width * 0.72, y: size.height * 0.16) }
        else if phase == 1 { HaloPixelButterfly(accent: preferences.primaryColor).frame(width: 22, height: 18).position(x: size.width * 0.30, y: size.height * 0.34) }
        else if phase == 2 { HaloPixelParcel(accent: preferences.accentColor).frame(width: 30, height: 24).position(x: size.width * 0.91, y: size.height * 0.69) }
    }

    private var fullHabitatDividers: some View {
        ZStack {
            Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1).position(x: size.width * 0.50, y: size.height * 0.38)
            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1).position(x: size.width * 0.50, y: size.height * 0.56)
            Text("BEDROOM").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(.secondary).position(x: size.width * 0.30, y: size.height * 0.08)
            Text("LIVING").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(.secondary).position(x: size.width * 0.70, y: size.height * 0.08)
        }.allowsHitTesting(false)
    }

    private var isNight: Bool { let hour = Calendar.autoupdatingCurrent.component(.hour, from: date); return hour >= 19 || hour < 7 }
}

private struct HaloPixelPetBackdrop: View {
    let environment: HaloPixelPetEnvironment, dayNight: Bool, date: Date, tier: Int
    private var night: Bool { guard dayNight else { return false }; let hour = Calendar.autoupdatingCurrent.component(.hour, from: date); return hour >= 19 || hour < 7 }
    private var colors: [Color] {
        switch environment {
        case .cozy: return night ? [Color(red: 0.08, green: 0.07, blue: 0.13), Color(red: 0.16, green: 0.09, blue: 0.10)] : [Color(red: 0.30, green: 0.18, blue: 0.15), Color(red: 0.20, green: 0.12, blue: 0.10)]
        case .cyberpunk: return [Color(red: 0.055, green: 0.025, blue: 0.10), Color(red: 0.08, green: 0.02, blue: 0.13)]
        case .japanese: return night ? [Color(red: 0.07, green: 0.08, blue: 0.10), Color(red: 0.11, green: 0.08, blue: 0.07)] : [Color(red: 0.28, green: 0.23, blue: 0.18), Color(red: 0.20, green: 0.16, blue: 0.13)]
        case .arcade: return [Color(red: 0.04, green: 0.04, blue: 0.09), Color(red: 0.10, green: 0.03, blue: 0.12)]
        case .space: return [Color(red: 0.025, green: 0.035, blue: 0.065), Color(red: 0.04, green: 0.055, blue: 0.09)]
        case .forest: return night ? [Color(red: 0.035, green: 0.07, blue: 0.055), Color(red: 0.07, green: 0.08, blue: 0.05)] : [Color(red: 0.16, green: 0.23, blue: 0.13), Color(red: 0.17, green: 0.13, blue: 0.08)]
        case .minimal: return night ? [Color(red: 0.07, green: 0.075, blue: 0.09), Color(red: 0.10, green: 0.10, blue: 0.12)] : [Color(red: 0.19, green: 0.20, blue: 0.22), Color(red: 0.14, green: 0.15, blue: 0.17)]
        case .developer: return [Color(red: 0.025, green: 0.045, blue: 0.035), Color(red: 0.02, green: 0.03, blue: 0.025)]
        }
    }
    var body: some View { ZStack(alignment: .bottom) { LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom); if tier > 0 { Rectangle().fill(Color.black.opacity(0.18)).frame(height: 24) } } }
}

private struct HaloPixelWindow: View {
    let date: Date, dayNight: Bool
    private var night: Bool { guard dayNight else { return false }; let hour = Calendar.autoupdatingCurrent.component(.hour, from: date); return hour >= 19 || hour < 7 }
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle().fill(night ? Color(red: 0.025, green: 0.05, blue: 0.12) : Color(red: 0.28, green: 0.58, blue: 0.78))
                Circle().fill(night ? Color.white.opacity(0.9) : Color.yellow.opacity(0.86)).frame(width: night ? 6 : 9, height: night ? 6 : 9).position(x: proxy.size.width * 0.72, y: proxy.size.height * 0.28)
                Rectangle().fill(Color.white.opacity(0.20)).frame(width: 2); Rectangle().fill(Color.white.opacity(0.20)).frame(height: 2)
            }.overlay(Rectangle().stroke(Color.white.opacity(0.23), lineWidth: 2))
        }
    }
}

private struct HaloPixelPetSprite: View {
    let species: HaloPixelPetSpecies, activity: HaloPixelPetActivity, primary: Color, accent: Color
    var body: some View {
        Canvas { context, size in
            let cell = max(1, floor(min(size.width / 16, size.height / 16))); let ox = floor((size.width - cell * 16) / 2); let oy = floor((size.height - cell * 16) / 2)
            func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int) -> Path { Path(CGRect(x: ox + CGFloat(x) * cell, y: oy + CGFloat(y) * cell, width: CGFloat(w) * cell, height: CGFloat(h) * cell)) }
            func fill(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: Color) { context.fill(rect(x, y, w, h), with: .color(color)) }
            let dark = Color.black.opacity(0.62)
            if species == .slime { fill(3, 6, 10, 6, primary); fill(4, 4, 8, 3, primary); fill(5, 7, 2, activity == .sleep ? 1 : 2, dark); fill(10, 7, 2, activity == .sleep ? 1 : 2, dark); fill(7, 10, 3, 1, accent); return }
            if species == .ghost { fill(4, 3, 8, 9, primary); fill(3, 5, 10, 6, primary); fill(4, 12, 2, 2, primary); fill(8, 12, 2, 2, primary); fill(11, 12, 2, 2, primary); fill(5, 6, 2, activity == .sleep ? 1 : 2, dark); fill(9, 6, 2, activity == .sleep ? 1 : 2, dark); return }
            if species == .robot { fill(4, 3, 8, 7, primary); fill(5, 10, 6, 4, primary); fill(7, 1, 2, 2, accent); fill(8, 0, 1, 2, accent); fill(5, 6, 2, 2, activity == .sleep ? dark.opacity(0.7) : accent); fill(9, 6, 2, 2, activity == .sleep ? dark.opacity(0.7) : accent); return }
            fill(4, 7, 8, 6, primary); fill(5, 4, 7, 6, primary); fill(4, 12, 2, 2, primary); fill(10, 12, 2, 2, primary)
            switch species {
            case .cat: fill(5, 2, 2, 3, primary); fill(10, 2, 2, 3, primary); fill(12, 9, 2, 2, primary); fill(13, 7, 1, 3, primary)
            case .dog: fill(4, 3, 2, 5, primary); fill(11, 3, 2, 5, primary); fill(12, 10, 2, 2, primary)
            case .fox: fill(4, 2, 3, 4, primary); fill(10, 2, 3, 4, primary); fill(12, 9, 3, 3, primary); fill(14, 10, 1, 2, accent)
            case .rabbit: fill(5, 0, 2, 5, primary); fill(10, 0, 2, 5, primary); fill(6, 1, 1, 3, accent); fill(10, 1, 1, 3, accent)
            default: break
            }
            if activity == .sleep { fill(6, 7, 2, 1, dark); fill(9, 7, 2, 1, dark) }
            else { fill(6, 6, 2, 2, dark); fill(9, 6, 2, 2, dark); if activity == .dance || activity == .celebrate { fill(6, 6, 1, 1, accent); fill(9, 6, 1, 1, accent) } }
            fill(8, 8, 1, 1, dark); if activity == .greet || activity == .celebrate { fill(7, 9, 3, 1, accent) }
            if activity == .gaming { fill(4, 5, 1, 4, accent); fill(12, 5, 1, 4, accent) }
            if activity == .charging { fill(13, 12, 2, 1, .green) }; if activity == .timer { fill(13, 4, 2, 2, accent) }
        }.accessibilityHidden(true)
    }
}

private struct HaloPixelPetLED: View {
    let mode: HaloPixelPetLEDMode, activity: HaloPixelPetActivity, needs: HaloPixelPetNeedsSnapshot
    let musicPlaying: Bool, environment: HaloPixelPetEnvironment
    let size: Double, brightness: Double, bloom: Double, date: Date
    private var color: Color {
        switch mode {
        case .off: return .clear
        case .status: if needs.needsAttention || activity == .concerned { return .red }; if needs.hunger < 0.55 { return .orange }; if activity == .sleep { return .blue }; return .green
        case .breathing: return activity == .sleep ? .blue : .green
        case .music: return musicPlaying ? .purple : .gray
        case .environment: switch environment { case .cyberpunk, .arcade: return .pink; case .space: return .cyan; case .forest: return .green; case .developer: return .mint; default: return .orange }
        }
    }
    var body: some View {
        if mode != .off {
            let seconds = date.timeIntervalSinceReferenceDate
            let pulse = mode == .breathing ? 0.58 + 0.42 * ((sin(seconds * 2) + 1) * 0.5) : (mode == .music && musicPlaying ? 0.55 + 0.45 * ((sin(seconds * 8) + 1) * 0.5) : 1)
            Rectangle().fill(color.opacity(brightness * pulse)).frame(width: size, height: size).shadow(color: color.opacity(0.55 * brightness * pulse), radius: bloom)
        }
    }
}

private struct HaloPixelBed: View { let accent: Color; var body: some View { ZStack(alignment: .bottom) { Rectangle().fill(Color.black.opacity(0.34)); Rectangle().fill(accent.opacity(0.52)).frame(height: 16); Rectangle().fill(Color.white.opacity(0.38)).frame(width: 22, height: 8).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 4).padding(.bottom, 12) } } }
private struct HaloPixelBowl: View { let color: Color; var body: some View { ZStack(alignment: .bottom) { Rectangle().fill(color.opacity(0.78)).frame(height: 8); Rectangle().fill(color.opacity(0.42)).frame(width: 18, height: 11) } } }
private struct HaloPixelToy: View { let color: Color; var body: some View { Rectangle().fill(color.opacity(0.85)).scaleEffect(0.62).rotationEffect(.degrees(45)) } }
private struct HaloPixelPlant: View { var body: some View { ZStack(alignment: .bottom) { Rectangle().fill(Color.brown.opacity(0.72)).frame(width: 18, height: 14); Rectangle().fill(Color.green.opacity(0.8)).frame(width: 5, height: 34).offset(y: -10); Rectangle().fill(Color.green.opacity(0.7)).frame(width: 17, height: 7).offset(x: -6, y: -28); Rectangle().fill(Color.green.opacity(0.65)).frame(width: 15, height: 7).offset(x: 6, y: -20) } } }
private struct HaloPixelComputer: View { let active: Bool, accent: Color; var body: some View { VStack(spacing: 2) { Rectangle().fill(Color.black.opacity(0.72)).overlay(Rectangle().fill(accent.opacity(active ? 0.55 : 0.12)).padding(4)); Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 40, height: 5) } } }
private struct HaloPixelLamp: View { let on: Bool, accent: Color; var body: some View { ZStack(alignment: .bottom) { Rectangle().fill(Color.gray.opacity(0.55)).frame(width: 4); Rectangle().fill(accent.opacity(on ? 0.84 : 0.34)).frame(width: 22, height: 14).offset(y: -34); Rectangle().fill(Color.gray.opacity(0.55)).frame(width: 22, height: 4) } } }
private struct HaloPixelShootingStar: View { let accent: Color; var body: some View { ZStack { Rectangle().fill(accent.opacity(0.26)).frame(width: 42, height: 2).rotationEffect(.degrees(-18)); Rectangle().fill(accent).frame(width: 5, height: 5).offset(x: 20, y: -6) } } }
private struct HaloPixelButterfly: View { let accent: Color; var body: some View { HStack(spacing: 2) { Rectangle().fill(accent.opacity(0.72)).frame(width: 8, height: 10).rotationEffect(.degrees(-28)); Rectangle().fill(Color.white.opacity(0.65)).frame(width: 2, height: 12); Rectangle().fill(accent.opacity(0.72)).frame(width: 8, height: 10).rotationEffect(.degrees(28)) } } }
private struct HaloPixelParcel: View { let accent: Color; var body: some View { ZStack { Rectangle().fill(Color.brown.opacity(0.72)); Rectangle().fill(accent.opacity(0.55)).frame(width: 4); Rectangle().fill(accent.opacity(0.45)).frame(height: 3) } } }

@MainActor
final class HaloPixelPetSettingsWindowController {
    static let shared = HaloPixelPetSettingsWindowController()
    private var window: NSWindow?
    func show() {
        if let window { NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil); return }
        let controller = NSHostingController(rootView: HaloPixelPetSettingsView())
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 620, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Halo · Pixel Pet"; window.contentViewController = controller; window.isReleasedWhenClosed = false; window.minSize = CGSize(width: 540, height: 600); window.center(); self.window = window
        NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil)
    }
}

private struct HaloPixelPetSettingsView: View {
    @ObservedObject private var pet = HaloPixelPetStore.shared
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    HaloPixelPetSprite(species: pet.preferences.species, activity: .idle, primary: pet.preferences.primaryColor, accent: pet.preferences.accentColor).frame(width: 72, height: 72).padding(8).background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) { Text("Pixel Pet").font(.title2.weight(.bold)); Text("A tiny Halo resident. Bigger widgets give it a bigger world, not merely bigger pixels.").foregroundStyle(.secondary) }
                }
                group("Companion") {
                    LabeledContent("Name") { TextField("Pixel", text: bind(\.name)).frame(width: 180) }
                    LabeledContent("Species") { Picker("", selection: bind(\.species)) { ForEach(HaloPixelPetSpecies.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 180) }
                    LabeledContent("Personality") { Picker("", selection: bind(\.personality)) { ForEach(HaloPixelPetPersonality.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 180) }
                    LabeledContent("Needs") { Picker("", selection: bind(\.needsMode)) { ForEach(HaloPixelPetNeedsMode.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 180) }
                    Text("Full mode still never kills or permanently harms the pet. Care creates interactions, not chores.").font(.caption).foregroundStyle(.secondary)
                }
                group("World") {
                    LabeledContent("Environment") { Picker("", selection: bind(\.environment)) { ForEach(HaloPixelPetEnvironment.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 180) }
                    Toggle("Follow day / night", isOn: bind(\.dayNightCycle)); Toggle("Show window", isOn: bind(\.showWindow)); Toggle("Show furniture", isOn: bind(\.showFurniture)); Toggle("Ambient events in large habitats", isOn: bind(\.showAmbientEvents))
                }
                group("Pixel Style") {
                    LabeledContent("Palette") { Picker("", selection: bind(\.palette)) { ForEach(HaloPixelPetPalette.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 180) }
                    if pet.preferences.palette == .custom { RGBSliders(title: "Primary", red: bind(\.customPrimary.red), green: bind(\.customPrimary.green), blue: bind(\.customPrimary.blue)); RGBSliders(title: "Accent", red: bind(\.customAccent.red), green: bind(\.customAccent.green), blue: bind(\.customAccent.blue)) }
                    slider("Animation speed", bind(\.animationSpeed), 0.35...2); slider("Autonomy", bind(\.autonomy), 0...1); slider("Interaction frequency", bind(\.interactionFrequency), 0...1); Toggle("Sound effects", isOn: bind(\.soundEffects))
                }
                group("Fake LED") {
                    LabeledContent("Behavior") { Picker("", selection: bind(\.ledMode)) { ForEach(HaloPixelPetLEDMode.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 180) }
                    slider("Size", bind(\.ledSize), 2...9); slider("Brightness", bind(\.ledBrightness), 0.15...1); slider("Bloom", bind(\.ledBloom), 0...12)
                }
                HStack { Button("Feed") { pet.feed() }; Button("Pet") { pet.pet() }; Button("Play") { pet.play() }; Spacer(); Button("Reset Pixel Pet") { pet.reset() } }
            }.padding(24)
        }.frame(minWidth: 540, minHeight: 600)
    }

    private func bind<T>(_ path: WritableKeyPath<HaloPixelPetPreferences, T>) -> Binding<T> { Binding(get: { pet.preferences[keyPath: path] }, set: { pet.update(path, $0) }) }
    @ViewBuilder private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View { VStack(alignment: .leading, spacing: 12) { Text(title).font(.headline); content() }.padding(14).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12)) }
    @ViewBuilder private func slider(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View { VStack(alignment: .leading, spacing: 5) { HStack { Text(title); Spacer(); Text(String(format: "%.2f", value.wrappedValue)).monospacedDigit().foregroundStyle(.secondary) }; Slider(value: value, in: range) } }
}

private struct RGBSliders: View {
    let title: String
    @Binding var red: Double
    @Binding var green: Double
    @Binding var blue: Double
    var body: some View { VStack(alignment: .leading, spacing: 5) { Text(title).font(.caption.weight(.semibold)); HStack { Text("R").frame(width: 14); Slider(value: $red, in: 0...1) }; HStack { Text("G").frame(width: 14); Slider(value: $green, in: 0...1) }; HStack { Text("B").frame(width: 14); Slider(value: $blue, in: 0...1) } } }
}
