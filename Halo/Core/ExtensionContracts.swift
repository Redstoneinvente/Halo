import Foundation
import CryptoKit
import SwiftUI
import AppKit

/// Providers are deliberately not instantiated or networked by the core app.
struct WeatherSnapshot: Sendable { var temperatureCelsius: Double; var condition: String; var updated: Date }
protocol WeatherProvider { func forecast(latitude: Double, longitude: Double) async throws -> WeatherSnapshot }
protocol AIActionProvider {
    var disclosure: String { get }
    var isOnDevice: Bool { get }
    /// The caller must obtain explicit consent with the exact content and destination before invoking this method.
    func transform(text: String, instruction: String) async throws -> String
}
protocol NotchCommand { var id: String { get }; var title: String { get }; @MainActor func execute() }
protocol AutomationTrigger { var id: String { get }; func matches(context: [String: String]) -> Bool }
protocol AutomationAction { var id: String { get }; @MainActor func perform() }

struct LicenseClaims: Codable, Equatable {
    var version: Int
    var product: String
    var licenseID: String
    var features: [String]
    /// nil is a perpetual entitlement; verification has no server dependency.
    var expiresAt: Date?
}
struct SignedLicense: Codable {
    var payload: Data
    var signature: Data
    func verified(publicKey: Data, now: Date = Date()) throws -> LicenseClaims {
        let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
        guard key.isValidSignature(signature, for: payload) else { throw CocoaError(.fileReadCorruptFile) }
        let claims = try JSONDecoder().decode(LicenseClaims.self, from: payload)
        guard claims.version == 1, claims.product == "Halo", !claims.licenseID.isEmpty,
              claims.expiresAt.map({ $0 > now }) ?? true else { throw CocoaError(.fileReadCorruptFile) }
        return claims
    }
}

// MARK: - Owned Environmental Interface

@MainActor
struct EIOpenSurface: View {
    @ObservedObject private var settings = EISettingsStore.shared
    @ObservedObject private var preferences = EIOpenPreferencesStore.shared
    @ObservedObject private var engine = EnvironmentalInterfaceEngine.shared
    @ObservedObject private var ui = EIOpenUI.shared

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                EICozyRoom(preferences: preferences.value, environment: engine.environment)
                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 4)
                    main(size: proxy.size)
                    Spacer(minLength: 4)
                    actions.padding(.bottom, 13)
                }
                .foregroundStyle(.white)

                if ui.editing {
                    HStack {
                        Spacer()
                        EIQuickEditor()
                            .frame(width: min(330, proxy.size.width * 0.58))
                            .padding(12)
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .animation(.easeInOut(duration: 0.18), value: ui.editing)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Label(title, systemImage: settings.settings.mode.symbol).font(.headline)
            Text("ENVIRONMENTAL INTERFACE")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(preferences.value.accent.color.opacity(0.9))
            Spacer()
            Button { ui.editing.toggle() } label: { Image(systemName: "slider.horizontal.3") }
                .buttonStyle(.plain).help("Customize EI")
            Button { EnvironmentalInterfaceOwnershipController.shared.close() } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain).help("Close Environmental Interface")
        }
        .padding(14)
    }

    private var title: String {
        switch settings.settings.mode {
        case .off: return "Environmental Interface"
        case .pet: return "Companion"
        case .plant: return "Cozy Garden"
        case .simulation: return "Tiny World"
        }
    }

    @ViewBuilder
    private func main(size: CGSize) -> some View {
        switch settings.settings.mode {
        case .off:
            EmptyView()
        case .pet:
            EIPetAvatar(size: min(165, max(92, size.height * 0.48)), walking: false)
                .onTapGesture { engine.interact(.petPat) }
        case .plant:
            EIPlantCozy(size: min(180, max(110, size.height * 0.52)))
                .onTapGesture { engine.preview(.plantPerk, duration: 3) }
        case .simulation:
            VStack(spacing: 10) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: min(92, size.height * 0.30)))
                    .foregroundStyle(preferences.value.accent.color)
                    .shadow(color: preferences.value.accent.color.opacity(0.3), radius: 14)
                Text("A tiny world living in your notch").font(.caption)
                Text(engine.environment.timeOfDay.rawValue.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced)).opacity(0.55)
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch settings.settings.mode {
        case .off:
            EmptyView()
        case .pet:
            HStack {
                action("Pat", "hand.tap") { engine.interact(.petPat) }
                action("Snack", "fork.knife") { engine.interact(.petSnack) }
                action("Hello", "bubble.left") { engine.interact(.petGreet) }
            }
            .disabled(!settings.settings.petInteraction)
        case .plant:
            HStack {
                action("Water", "drop.fill") { engine.preview(.plantRain, duration: 4) }
                action("Touch", "hand.tap") { engine.preview(.plantPerk, duration: 3) }
                action("Sun", "sun.max.fill") { engine.preview(.plantBloom, duration: 5) }
            }
        case .simulation:
            HStack {
                action("Busy", "car.2.fill") { engine.preview(.cityBusy, duration: 6) }
                action("Night", "moon.stars.fill") { engine.preview(.cityNight, duration: 7) }
                action("Rain", "cloud.rain.fill") { engine.preview(.cityRain, duration: 7) }
            }
        }
    }

    private func action(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption.bold())
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(.white.opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

@MainActor
private struct EIQuickEditor: View {
    @ObservedObject private var preferences = EIOpenPreferencesStore.shared
    @ObservedObject private var settings = EISettingsStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("EI Studio").font(.headline)
                if settings.settings.mode == .pet {
                    Picker("Pet style", selection: binding(\.petVisual)) {
                        ForEach(EIPetVisualStyle.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Toggle("Roam outside notch", isOn: binding(\.roam))
                    Toggle("Walk in menu bar", isOn: binding(\.menuBar)).disabled(!preferences.value.roam)
                    Toggle("Peek from screen edges", isOn: binding(\.screenEdges)).disabled(!preferences.value.roam)
                }
                if settings.settings.mode == .pet || settings.settings.mode == .plant {
                    Divider()
                    Picker("Room", selection: binding(\.roomStyle)) {
                        ForEach(EIRoomStyle.allCases) { Text($0.rawValue).tag($0) }
                    }
                    ColorPicker("Room color", selection: color(\.room), supportsOpacity: false)
                    ColorPicker("Accent", selection: color(\.accent), supportsOpacity: false)
                    ColorPicker("Floor", selection: color(\.floor), supportsOpacity: false)
                    Toggle("Window", isOn: binding(\.window))
                    Toggle("Lamp", isOn: binding(\.lamp))
                    Toggle("Rug", isOn: binding(\.rug))
                    Toggle("Shelf", isOn: binding(\.shelf))
                    Toggle("Room plants", isOn: binding(\.roomPlants))
                }
                Divider()
                Toggle("EI shortcut", isOn: binding(\.shortcutEnabled))
                if preferences.value.shortcutEnabled {
                    Picker("Key", selection: binding(\.shortcutKey)) {
                        Text("E").tag(UInt32(14)); Text("I").tag(UInt32(34)); Text("P").tag(UInt32(35)); Text("J").tag(UInt32(38))
                    }
                    Picker("Modifiers", selection: binding(\.shortcutModifiers)) {
                        Text("Option + Command").tag(UInt32(2304)); Text("Control + Option").tag(UInt32(6144)); Text("Control + Shift").tag(UInt32(4608))
                    }
                }
                Text("Context Interfaces always have ownership priority.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(13)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .foregroundStyle(.white)
    }

    private func binding<T>(_ keyPath: WritableKeyPath<EIOpenPreferences, T>) -> Binding<T> {
        Binding(get: { preferences.value[keyPath: keyPath] }, set: { value in
            var copy = preferences.value
            copy[keyPath: keyPath] = value
            preferences.value = copy
        })
    }

    private func color(_ keyPath: WritableKeyPath<EIOpenPreferences, WidgetColor>) -> Binding<Color> {
        Binding(get: { preferences.value[keyPath: keyPath].color }, set: { value in
            var copy = preferences.value
            copy[keyPath: keyPath] = WidgetColor(value)
            preferences.value = copy
        })
    }
}

@MainActor
struct EIRoamingPetView: View {
    @ObservedObject var model: EIRoamModel
    @ObservedObject private var settings = EISettingsStore.shared
    @ObservedObject private var engine = EnvironmentalInterfaceEngine.shared

    var body: some View {
        EIPetAvatar(size: 66, walking: model.walking)
            .scaleEffect(x: model.right ? 1 : -1, y: 1)
            .contentShape(Rectangle())
            .onTapGesture { if settings.settings.petInteraction { engine.interact(.petPat) } }
            .contextMenu {
                Button("Pat") { engine.interact(.petPat) }
                Button("Snack") { engine.interact(.petSnack) }
                Button("Say hello") { engine.interact(.petGreet) }
                Divider()
                Button("Open EI") { EnvironmentalInterfaceOwnershipController.shared.open() }
                Button("Customize") { EnvironmentalInterfaceOwnershipController.shared.open(editor: true) }
            }
    }
}

@MainActor
private struct EIPetAvatar: View {
    let size: CGFloat
    let walking: Bool
    @ObservedObject private var preferences = EIOpenPreferencesStore.shared
    @ObservedObject private var settings = EISettingsStore.shared
    @ObservedObject private var engine = EnvironmentalInterfaceEngine.shared

    var body: some View {
        HaloCompanionSprite(
            kind: settings.settings.petKind,
            style: preferences.value.petVisual,
            size: size,
            primary: settings.settings.petPrimaryColor.color,
            accent: settings.settings.petAccentColor.color,
            motion: motion,
            facingRight: true,
            displayPreset: settings.settings.displayPreset,
            pixelGrid: settings.settings.pixelGrid,
            pixelGlow: settings.settings.pixelGlow,
            scanlines: settings.settings.scanlines,
            ghosting: settings.settings.ghosting,
            brightnessVariation: settings.settings.brightnessVariation
        )
    }

    private var motion: HaloCompanionMotion {
        if walking { return .walk }
        switch engine.currentReaction?.kind {
        case .petDance?: return .dance
        case .petSleep?: return .sleep
        case .petSnack?: return .snack
        case .petGreet?: return .greet
        case .petCelebrate?: return .celebrate
        case .petPeekLeft?, .petPeekRight?, .petPeekUnder?: return .peek
        case .petLookAround?: return .look
        default: return .idle
        }
    }
}

@MainActor
private struct EIPlantCozy: View {
    let size: CGFloat
    @ObservedObject private var settings = EISettingsStore.shared
    @ObservedObject private var engine = EnvironmentalInterfaceEngine.shared

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: false)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            let growth = min(1, engine.persistentState.plant.growth + engine.persistentState.plant.bonusGrowth)
            ZStack(alignment: .bottom) {
                Ellipse().fill(Color.black.opacity(0.22)).frame(width: size * 0.60, height: size * 0.12).offset(y: size * 0.04)
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [settings.settings.plantPotColor.color.opacity(1), settings.settings.plantPotColor.color.opacity(0.68)], startPoint: .top, endPoint: .bottom))
                    .frame(width: size * 0.38, height: size * 0.27)
                Capsule().fill(settings.settings.plantColor.color)
                    .frame(width: size * 0.05, height: size * (0.44 + growth * 0.16))
                    .offset(y: -size * 0.20)
                ZStack {
                    ForEach(0..<8, id: \.self) { index in
                        Ellipse()
                            .fill(settings.settings.plantColor.color.opacity(index.isMultiple(of: 3) ? 0.72 : 0.94))
                            .frame(width: size * 0.29, height: size * 0.12)
                            .rotationEffect(.degrees(index.isMultiple(of: 2) ? -30 : 30))
                            .offset(x: (index.isMultiple(of: 2) ? -1 : 1) * size * 0.14,
                                    y: -CGFloat(index / 2) * size * 0.12)
                            .scaleEffect(index < Int(2 + growth * 6) ? 1 : 0.05)
                    }
                }
                .rotationEffect(.degrees(sin(phase * 1.2) * (engine.environment.isMusicPlaying ? 6 : 2)))
                .offset(y: -size * 0.33)

                if engine.currentReaction?.kind == .plantBloom {
                    ZStack {
                        Circle().fill(.pink).frame(width: size * 0.14)
                        Circle().fill(.yellow).frame(width: size * 0.05)
                    }
                    .offset(y: -size * 0.76)
                }
                if engine.currentReaction?.kind == .plantRain {
                    ForEach(0..<5, id: \.self) { index in
                        Capsule().fill(Color.cyan.opacity(0.65)).frame(width: 2, height: 10)
                            .offset(x: CGFloat(index - 2) * size * 0.12, y: -size * (0.56 + CGFloat(index % 2) * 0.08))
                    }
                }
            }
            .frame(width: size, height: size)
        }
    }
}

private struct EITriangleRoom: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct EICozyRoom: View {
    let preferences: EIOpenPreferences
    let environment: EIEnvironment

    var body: some View {
        GeometryReader { proxy in
            let accent = preferences.accent.color
            ZStack {
                LinearGradient(colors: background, startPoint: .topLeading, endPoint: .bottomTrailing)

                if preferences.window {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(colors: sky, startPoint: .top, endPoint: .bottom))
                        .frame(width: min(150, proxy.size.width * 0.30), height: min(104, proxy.size.height * 0.32))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.18), lineWidth: 2))
                        .overlay(alignment: .topTrailing) {
                            if environment.weather?.isRaining == true {
                                Image(systemName: "cloud.rain.fill").foregroundStyle(.cyan.opacity(0.75)).padding(8)
                            }
                        }
                        .position(x: proxy.size.width * 0.24, y: proxy.size.height * 0.35)
                }

                Rectangle().fill(preferences.floor.color)
                    .frame(height: proxy.size.height * 0.27)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                if preferences.rug {
                    Ellipse().fill(accent.opacity(0.30))
                        .frame(width: min(250, proxy.size.width * 0.56), height: min(68, proxy.size.height * 0.18))
                        .position(x: proxy.size.width * 0.52, y: proxy.size.height * 0.82)
                }

                if preferences.shelf {
                    VStack(spacing: 5) {
                        HStack(spacing: 7) {
                            ForEach(0..<4, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(index.isMultiple(of: 2) ? accent.opacity(0.58) : Color.white.opacity(0.24))
                                    .frame(width: 8 + CGFloat(index % 2) * 4, height: 20 + CGFloat(index) * 2)
                            }
                        }
                        Capsule().fill(.white.opacity(0.20)).frame(width: 78, height: 4)
                    }
                    .position(x: proxy.size.width * 0.72, y: proxy.size.height * 0.30)
                }

                if preferences.roomPlants {
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { index in
                            Capsule().fill(Color.green.opacity(0.55 + Double(index) * 0.12))
                                .frame(width: 8, height: 22 + CGFloat(index) * 5)
                                .rotationEffect(.degrees(Double(index - 1) * 18))
                        }
                    }
                    .overlay(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 4).fill(accent.opacity(0.55)).frame(width: 30, height: 13).offset(y: 7)
                    }
                    .position(x: proxy.size.width * 0.14, y: proxy.size.height * 0.72)
                }

                if preferences.lamp {
                    VStack(spacing: -2) {
                        EITriangleRoom().fill(accent.opacity(0.78)).frame(width: 44, height: 30)
                        Rectangle().fill(.white.opacity(0.35)).frame(width: 4, height: 40)
                        Capsule().fill(.white.opacity(0.20)).frame(width: 30, height: 6)
                    }
                    .shadow(color: accent.opacity(environment.timeOfDay == .night ? 0.68 : 0.38), radius: 24)
                    .position(x: proxy.size.width * 0.84, y: proxy.size.height * 0.58)
                }
            }
        }
    }

    private var sky: [Color] {
        if environment.timeOfDay == .night {
            return [Color(red: 0.03, green: 0.05, blue: 0.13), .purple.opacity(0.45)]
        }
        return [.blue.opacity(0.70), .orange.opacity(environment.timeOfDay == .evening ? 0.50 : 0.12)]
    }

    private var background: [Color] {
        switch preferences.roomStyle {
        case .warm: return [preferences.room.color, preferences.accent.color.opacity(0.22), .black.opacity(0.92)]
        case .night: return [Color(red: 0.03, green: 0.04, blue: 0.09), preferences.room.color.opacity(0.72), .black]
        case .greenhouse: return [Color(red: 0.04, green: 0.12, blue: 0.08), preferences.room.color.opacity(0.75), preferences.accent.color.opacity(0.16)]
        case .minimal: return [preferences.room.color, preferences.room.color.opacity(0.70), .black.opacity(0.80)]
        }
    }
}
