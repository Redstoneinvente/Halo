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

// MARK: - Surface ownership router

private enum RoutedContextInterface: String { case music, bluetooth, retro }

/// CI -> EI -> normal Halo. The normal SurfaceView remains alive behind EI so CI-local state
/// continues receiving events, but EI becomes the visible owner and receives CI-style sizing.
@MainActor
struct HaloSurfaceRouter: View {
    @ObservedObject var viewport: SurfaceViewport
    @ObservedObject var store: AppStore
    @ObservedObject var state: SurfaceState
    @ObservedObject var workspace: WorkspaceStore

    @ObservedObject private var ownership = EnvironmentalInterfaceOwnershipController.shared
    @ObservedObject private var eiSettings = EISettingsStore.shared
    @ObservedObject private var engine = EnvironmentalInterfaceEngine.shared
    @ObservedObject private var bluetooth = BluetoothStateService.shared

    @AppStorage("HaloContextMusicPriority") private var musicPriority = 60.0
    @AppStorage("HaloContextBluetoothEnabled") private var bluetoothEnabled = false
    @AppStorage("HaloContextBluetoothShowWhileConnected") private var bluetoothWhileConnected = true
    @AppStorage("HaloContextBluetoothShowOnChanges") private var bluetoothOnChanges = true
    @AppStorage("HaloContextBluetoothPriority") private var bluetoothPriority = 50.0
    @AppStorage("HaloContextRetroEnabled") private var retroEnabled = false
    @AppStorage("HaloContextRetroPriority") private var retroPriority = 80.0

    private var layout: WorkspaceLayout { state.layoutOverride ?? workspace.effectiveLayout }
    private var musicOptions: ContextMusicOptions { layout.contextMusic ?? ContextMusicOptions() }
    private var theme: Theme { state.theme }

    private var activeCI: RoutedContextInterface? {
        var candidates: [(RoutedContextInterface, Double, Int)] = []
        if retroEnabled && engine.retroGameRequested { candidates.append((.retro, retroPriority, 3)) }
        if musicOptions.enabled && workspace.media.isPlaying { candidates.append((.music, musicPriority, 2)) }
        let bluetoothEligible = bluetoothEnabled &&
            ((bluetoothOnChanges && bluetooth.lastEvent != nil) ||
             (bluetoothWhileConnected && !bluetooth.connectedDevices.isEmpty))
        if bluetoothEligible { candidates.append((.bluetooth, bluetoothPriority, 1)) }
        return candidates.max { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
            return lhs.2 < rhs.2
        }?.0
    }

    private var eiOwnsSurface: Bool {
        state.expanded && ownership.isRequested && eiSettings.settings.mode != .off && activeCI == nil
    }

    private var effectiveShape: SurfaceShapeKind {
        guard layout.appearance.surface.useStyleContour ?? true else { return layout.appearance.surface.shape }
        switch theme.style {
        case .pill, .island: return state.expanded ? .rounded : .capsule
        case .simulated, .notch: return .scoop
        case .shelf: return .chamfer
        case .detached, .menuBar: return .rounded
        default: return layout.appearance.surface.shape
        }
    }

    private var contour: HaloContour {
        HaloContour(kind: effectiveShape,
                    radius: (layout.appearance.surface.useStyleContour ?? true)
                        ? (theme.style == .menuBar ? 4 : theme.style == .pill ? 40 : theme.cornerRadius)
                        : theme.cornerRadius,
                    topRadius: layout.appearance.surface.topRadius,
                    bottomRadius: layout.appearance.surface.bottomRadius,
                    shoulder: layout.appearance.surface.shoulder)
    }

    private var physicalNotchPeekMotion: HaloCompanionMotion? {
        guard eiSettings.settings.mode == .pet, state.closedOcclusion != nil,
              let kind = engine.currentReaction?.kind else { return nil }
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

    var body: some View {
        ZStack(alignment: .top) {
            SurfaceView(store: store, state: state, workspace: workspace)
                .opacity(eiOwnsSurface ? 0 : 1)
                .allowsHitTesting(!eiOwnsSurface)
                .accessibilityHidden(eiOwnsSurface)

            if eiOwnsSurface {
                EIOpenSurface(surfaceState: state)
                    .background(EISurfaceBackdrop(mode: eiSettings.settings.mode,
                                                  preferences: EIOpenPreferencesStore.shared.value,
                                                  environment: engine.environment))
                    .clipShape(contour)
                    .overlay(contour.stroke(Color.white.opacity(0.11), lineWidth: 1))
                    .contentShape(contour)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    .zIndex(20)

                // Physical-notch peeks must not be children of EIOpenSurface: that surface is clipped
                // to Halo's contour. Render the pet above the owned surface so only the real hardware
                // notch/reveal window occludes it, making it genuinely emerge from the camera housing.
                if let peekMotion = physicalNotchPeekMotion {
                    EIPhysicalNotchPetPeek(surfaceState: state, motion: peekMotion)
                        .frame(width: viewport.size.width, height: viewport.size.height, alignment: .top)
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                        .zIndex(50)
                }
            }
        }
        .frame(width: viewport.size.width, height: viewport.size.height, alignment: .top)
        .clipped()
        .onAppear { updateAmbientSuppression(eiOwnsSurface) }
        .onChange(of: eiOwnsSurface) { active in updateAmbientSuppression(active) }
        .onDisappear { updateAmbientSuppression(false) }
    }

    private func updateAmbientSuppression(_ active: Bool) {
        DispatchQueue.main.async { EnvironmentalInterfaceManager.shared.setOwnedSurfaceActive(active) }
    }
}

// MARK: - Owned Environmental Interface

@MainActor
struct EIOpenSurface: View {
    @ObservedObject var surfaceState: SurfaceState
    @ObservedObject private var settings = EISettingsStore.shared
    @ObservedObject private var preferences = EIOpenPreferencesStore.shared
    @ObservedObject private var engine = EnvironmentalInterfaceEngine.shared
    @ObservedObject private var ui = EIOpenUI.shared

    private var sizingKey: String {
        "\(settings.settings.mode.rawValue)|\(ui.editing)|\(preferences.value.roomStyle.rawValue)|\(preferences.value.petVisual.rawValue)|\(settings.settings.plantKind.rawValue)"
    }

    private var preferredSize: CGSize {
        let base: CGSize
        switch settings.settings.mode {
        case .off: base = CGSize(width: 500, height: 330)
        case .pet: base = CGSize(width: 560, height: 370)
        case .plant: base = CGSize(width: 590, height: 410)
        case .simulation: base = CGSize(width: 700, height: 390)
        }
        if ui.editing { return CGSize(width: base.width + 245, height: max(base.height, 470)) }
        return base
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                content(size: proxy.size)

                HStack(spacing: 9) {
                    Label(title, systemImage: settings.settings.mode.symbol)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                    Text("EI")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(preferences.value.accent.color.opacity(0.82))
                    Spacer()
                    Button { ui.editing.toggle() } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .buttonStyle(.plain)
                    .help(ui.editing ? "EI Studio is open" : "Open EI Studio")
                    Button { EnvironmentalInterfaceOwnershipController.shared.close() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain).help("Close Environmental Interface")
                }
                .padding(.horizontal, 16)
                .padding(.top, 13)
                .zIndex(8)

                if ui.editing {
                    HStack {
                        Spacer()
                        EIQuickEditor()
                            .frame(width: min(350, proxy.size.width * 0.52))
                            .frame(maxHeight: max(120, proxy.size.height - 24))
                            .padding(12)
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(30)
                }
            }
            .animation(.easeInOut(duration: 0.22), value: ui.editing)
        }
        .task(id: sizingKey) {
            await Task.yield()
            guard !Task.isCancelled else { return }
            migrateLegacyPetStyleIfNeeded()
            publishPreferredSize()
        }
        .onDisappear {
            DispatchQueue.main.async { [surfaceState] in
                guard !EnvironmentalInterfaceOwnershipController.shared.isRequested else { return }
                surfaceState.contextPreferredSize = nil
            }
        }
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        switch settings.settings.mode {
        case .off:
            EmptyView()
        case .pet:
            ZStack(alignment: .bottom) {
                EIHabitatDetails(preferences: preferences.value, environment: engine.environment)
                    .allowsHitTesting(false)

                // On a real notched display the active peek is rendered by HaloSurfaceRouter,
                // outside this clipped room. Keep the normal companion out of the way while peeking.
                if physicalNotchPeekMotion == nil || surfaceState.closedOcclusion == nil {
                    EIPetAvatar(size: min(220, max(120, size.height * 0.58)), walking: false)
                        .offset(y: -max(8, size.height * 0.055))
                        .onTapGesture { engine.interact(.petPat) }
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                }
                petActions.padding(.bottom, 13)
            }
            .animation(.easeInOut(duration: 0.20), value: physicalNotchPeekMotion != nil)
        case .plant:
            ZStack(alignment: .bottom) {
                EIHabitatDetails(preferences: preferences.value, environment: engine.environment)
                    .allowsHitTesting(false)
                HaloPlantRenderer(kind: settings.settings.plantKind,
                                  size: min(280, max(150, size.height * 0.70)),
                                  plantColor: settings.settings.plantColor.color,
                                  potColor: settings.settings.plantPotColor.color,
                                  growth: min(1, engine.persistentState.plant.growth + engine.persistentState.plant.bonusGrowth),
                                  environment: engine.environment,
                                  reaction: engine.currentReaction?.kind)
                    .offset(y: -max(12, size.height * 0.04))
                    .onTapGesture { engine.preview(.plantPerk, duration: 4.5) }
                plantActions.padding(.bottom, 13)
            }
        case .simulation:
            ZStack(alignment: .bottom) {
                HaloCityRenderer(accent: settings.settings.simulationAccentColor.color,
                                 environment: engine.environment,
                                 reaction: engine.currentReaction?.kind,
                                 seed: engine.persistentState.simulation.seed,
                                 compact: false)
                    .padding(.top, 28)
                cityActions.padding(.bottom, 12)
            }
        }
    }

    private var physicalNotchPeekMotion: HaloCompanionMotion? {
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

    private var title: String {
        switch settings.settings.mode {
        case .off: return "Environmental Interface"
        case .pet: return "Companion"
        case .plant: return "Living Plant"
        case .simulation: return "Tiny City"
        }
    }

    private var petActions: some View {
        HStack(spacing: 7) {
            action("Pat", "hand.tap") { engine.interact(.petPat) }
            action("Treat", "sparkles") { engine.interact(.petSnack) }
            action("Toy", "circle.hexagongrid.fill") { engine.interact(.petToy) }
            action("Call", "wave.3.right") { engine.interact(.petCall) }
            action("Hide", "eye.slash") { engine.interact(.petHide) }
        }
        .disabled(!settings.settings.petInteraction)
    }

    private var plantActions: some View {
        HStack(spacing: 7) {
            action("Water", "drop.fill") { engine.preview(.plantRain, duration: 7) }
            action("Touch", "hand.tap") { engine.preview(.plantPerk, duration: 5) }
            action("Bloom", "camera.macro") { engine.preview(.plantBloom, duration: 10) }
            if settings.settings.plantKind == .vine {
                action("Grow", "arrow.up.right") { engine.preview(.plantVineGrow, duration: 9) }
            }
        }
    }

    private var cityActions: some View {
        HStack(spacing: 7) {
            action("Traffic", "car.2.fill") { engine.preview(.cityTraffic, duration: 9) }
            action("Rain", "cloud.rain.fill") { engine.preview(.cityRain, duration: 10) }
            action("Night", "moon.stars.fill") { engine.preview(.cityNight, duration: 11) }
            action("Delivery", "shippingbox.fill") { engine.preview(.cityDelivery, duration: 9) }
        }
    }

    private func action(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 9).padding(.vertical, 6)
                .background(.black.opacity(0.24), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func publishPreferredSize() {
        let next = preferredSize
        if let current = surfaceState.contextPreferredSize,
           abs(current.width - next.width) < 1, abs(current.height - next.height) < 1 { return }
        surfaceState.contextPreferredSize = next
    }

    private func migrateLegacyPetStyleIfNeeded() {
        guard preferences.value.petVisual == .pixel else { return }
        var value = preferences.value
        value.petVisual = .smooth
        DispatchQueue.main.async { EIOpenPreferencesStore.shared.value = value }
    }
}

// MARK: - EI Studio

@MainActor
private struct EIQuickEditor: View {
    @ObservedObject private var preferences = EIOpenPreferencesStore.shared
    @ObservedObject private var settings = EISettingsStore.shared
    @ObservedObject private var engine = EnvironmentalInterfaceEngine.shared
    @ObservedObject private var ui = EIOpenUI.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("EI Studio").font(.headline)
                    Text("Live customization").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    ui.editing = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .buttonStyle(.plain)
                .help("Close EI Studio")
                .accessibilityLabel("Close EI Studio")
            }
            .padding(.horizontal, 13).padding(.top, 12).padding(.bottom, 10)

            Divider().opacity(0.35)

            ScrollView {
                VStack(alignment: .leading, spacing: 11) {
                    if settings.settings.mode == .pet {
                        Label("Canonical pet artwork", systemImage: "photo.on.rectangle.angled")
                            .font(.caption.weight(.semibold))
                        Text("Cat, Dog and Fox use their supplied sprite sheets. Halo animates the artwork without redrawing the characters.")
                            .font(.caption2).foregroundStyle(.secondary)
                        Toggle("Roam outside notch", isOn: binding(\.roam))
                        Toggle("Walk in menu bar", isOn: binding(\.menuBar)).disabled(!preferences.value.roam)
                        Toggle("Peek from screen edges", isOn: binding(\.screenEdges)).disabled(!preferences.value.roam)
#if DEBUG
                        HaloPetDebugPanel()
#endif
                    }

                    if settings.settings.mode == .pet || settings.settings.mode == .plant {
                        Divider()
                        Picker("Habitat", selection: binding(\.roomStyle)) {
                            ForEach(EIRoomStyle.allCases) { Text($0.rawValue).tag($0) }
                        }
                        ColorPicker("Room color", selection: color(\.room), supportsOpacity: false)
                        ColorPicker("Accent light", selection: color(\.accent), supportsOpacity: false)
                        ColorPicker("Surface", selection: color(\.floor), supportsOpacity: false)
                        Toggle("Window", isOn: binding(\.window))
                        Toggle("Lamp", isOn: binding(\.lamp))
                        Toggle("Rug", isOn: binding(\.rug))
                        Toggle("Shelf", isOn: binding(\.shelf))
                        Toggle("Room plants", isOn: binding(\.roomPlants))
                    }

                    Divider()
                    HStack {
                        Text("Behaviour").font(.caption.weight(.semibold))
                        Spacer()
                        Text(engine.behaviourState.rawValue.capitalized).font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Mood").font(.caption.weight(.semibold))
                        Spacer()
                        Text(engine.moodState.rawValue.capitalized).font(.caption).foregroundStyle(.secondary)
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

                    Text("CI always has ownership priority. EI content automatically yields to CI exclusion regions.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(13)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .foregroundStyle(.white)
    }

    private var petStyleBinding: Binding<EIPetVisualStyle> {
        Binding(get: {
            preferences.value.petVisual == .pixel ? .smooth : preferences.value.petVisual
        }, set: { newValue in
            var copy = preferences.value; copy.petVisual = newValue
            DispatchQueue.main.async { preferences.value = copy }
        })
    }

    private func binding<T>(_ keyPath: WritableKeyPath<EIOpenPreferences, T>) -> Binding<T> {
        Binding(get: { preferences.value[keyPath: keyPath] }, set: { value in
            var copy = preferences.value; copy[keyPath: keyPath] = value
            DispatchQueue.main.async { preferences.value = copy }
        })
    }

    private func color(_ keyPath: WritableKeyPath<EIOpenPreferences, WidgetColor>) -> Binding<Color> {
        Binding(get: { preferences.value[keyPath: keyPath].color }, set: { value in
            var copy = preferences.value; copy[keyPath: keyPath] = WidgetColor(value)
            DispatchQueue.main.async { preferences.value = copy }
        })
    }
}

// MARK: - Roaming pet

@MainActor
private struct EIPhysicalNotchPetPeek: View {
    @ObservedObject var surfaceState: SurfaceState
    let motion: HaloCompanionMotion
    @ObservedObject private var preferences = EIOpenPreferencesStore.shared
    @ObservedObject private var settings = EISettingsStore.shared

    var body: some View {
        GeometryReader { proxy in
            if let occlusion = surfaceState.closedOcclusion {
                let notchWidth = max(92, occlusion.width)
                let notchHeight = max(22, occlusion.height)
                let spriteSize = min(150, max(108, notchWidth * 0.72))
                let centerX = horizontalCenter(in: proxy.size, notchWidth: notchWidth, spriteSize: spriteSize)
                let centerY = verticalCenter(notchHeight: notchHeight, spriteSize: spriteSize)

                HaloCompanionSprite(kind: settings.settings.petKind,
                                    style: preferences.value.petVisual == .pixel ? .smooth : preferences.value.petVisual,
                                    size: spriteSize,
                                    primary: settings.settings.petPrimaryColor.color,
                                    accent: settings.settings.petAccentColor.color,
                                    motion: motion,
                                    facingRight: motion != .peekRight)
                    .position(x: centerX, y: centerY)
                    .mask {
                        revealMask(size: proxy.size,
                                   notchWidth: notchWidth,
                                   notchHeight: notchHeight,
                                   spriteSize: spriteSize)
                    }
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func horizontalCenter(in size: CGSize, notchWidth: CGFloat, spriteSize: CGFloat) -> CGFloat {
        let notchLeft = size.width / 2 - notchWidth / 2
        let notchRight = size.width / 2 + notchWidth / 2
        switch motion {
        case .peekLeft:
            return notchLeft - spriteSize * 0.18
        case .peekRight:
            return notchRight + spriteSize * 0.18
        case .tail:
            return size.width / 2 + notchWidth * 0.18
        default:
            return size.width / 2
        }
    }

    private func verticalCenter(notchHeight: CGFloat, spriteSize: CGFloat) -> CGFloat {
        // Keep most of the body behind/above the notch edge. The reveal mask exposes only the part
        // that has actually cleared the physical camera housing, so the pet reads as peeking, not
        // standing inside Halo.
        switch motion {
        case .peekEyes: return notchHeight + spriteSize * 0.08
        case .peekEars: return notchHeight + spriteSize * 0.11
        case .peek: return notchHeight + spriteSize * 0.18
        case .paw: return notchHeight + spriteSize * 0.20
        case .tail: return notchHeight + spriteSize * 0.13
        case .peekLeft, .peekRight: return notchHeight + spriteSize * 0.10
        default: return notchHeight + spriteSize * 0.15
        }
    }

    @ViewBuilder
    private func revealMask(size: CGSize, notchWidth: CGFloat, notchHeight: CGFloat, spriteSize: CGFloat) -> some View {
        let notchLeft = size.width / 2 - notchWidth / 2
        let notchRight = size.width / 2 + notchWidth / 2
        switch motion {
        case .peekLeft:
            Rectangle()
                .frame(width: spriteSize * 0.62, height: spriteSize * 0.68)
                .position(x: notchLeft - spriteSize * 0.25,
                          y: notchHeight + spriteSize * 0.12)
        case .peekRight:
            Rectangle()
                .frame(width: spriteSize * 0.62, height: spriteSize * 0.68)
                .position(x: notchRight + spriteSize * 0.25,
                          y: notchHeight + spriteSize * 0.12)
        default:
            let revealHeight: CGFloat
            let revealWidth: CGFloat
            switch motion {
            case .peekEyes:
                revealHeight = spriteSize * 0.22
                revealWidth = min(notchWidth * 0.76, spriteSize * 0.82)
            case .peekEars:
                revealHeight = spriteSize * 0.28
                revealWidth = min(notchWidth * 0.82, spriteSize * 0.90)
            case .peek:
                revealHeight = spriteSize * 0.42
                revealWidth = min(notchWidth * 0.94, spriteSize)
            case .paw:
                revealHeight = spriteSize * 0.48
                revealWidth = min(notchWidth, spriteSize)
            case .tail:
                revealHeight = spriteSize * 0.34
                revealWidth = min(notchWidth * 0.84, spriteSize * 0.90)
            default:
                revealHeight = spriteSize * 0.38
                revealWidth = min(notchWidth * 0.90, spriteSize)
            }
            Rectangle()
                .frame(width: revealWidth, height: revealHeight)
                .position(x: size.width / 2,
                          y: notchHeight + revealHeight / 2)
        }
    }
}

@MainActor
struct EIRoamingPetView: View {
    @ObservedObject var model: EIRoamModel
    @ObservedObject private var settings = EISettingsStore.shared
    @ObservedObject private var engine = EnvironmentalInterfaceEngine.shared

    var body: some View {
        EIPetAvatar(size: 72, walking: model.walking)
            .scaleEffect(x: model.right ? 1 : -1, y: 1)
            .contentShape(Rectangle())
            .onTapGesture { if settings.settings.petInteraction { engine.interact(.petPat) } }
            .contextMenu {
                Button("Pat") { engine.interact(.petPat) }
                Button("Give treat") { engine.interact(.petSnack) }
                Button("Give toy") { engine.interact(.petToy) }
                Button("Call") { engine.interact(.petCall) }
                Button("Hide for now") { engine.interact(.petHide) }
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
        HaloCompanionSprite(kind: settings.settings.petKind,
                            style: preferences.value.petVisual == .pixel ? .smooth : preferences.value.petVisual,
                            size: size,
                            primary: settings.settings.petPrimaryColor.color,
                            accent: settings.settings.petAccentColor.color,
                            motion: motion,
                            facingRight: true)
    }

    private var motion: HaloCompanionMotion {
        if walking { return .walk }
        guard let kind = engine.currentReaction?.kind else {
            switch engine.behaviourState {
            case .hidden: return .hidden
            case .sleeping: return .sleep
            case .observing: return .observe
            case .playful: return .playful
            case .affectionate: return .affectionate
            case .tired: return .tired
            case .excited: return .excited
            default: return .idle
            }
        }
        switch kind {
        case .petPeekEyes: return .peekEyes
        case .petPeekEars: return .peekEars
        case .petPeekUnder: return .peek
        case .petPeekLeft: return .peekLeft
        case .petPeekRight: return .peekRight
        case .petPawFirst: return .paw
        case .petTailFirst: return .tail
        case .petObserve: return .observe
        case .petRainWatch: return .umbrella
        case .petLookAround, .petUnimpressed: return .look
        case .petStretch: return .stretch
        case .petGroom: return .groom
        case .petCurlUp, .petSleep: return .sleep
        case .petLaptopSleep: return .working
        case .petPlay, .petChase, .petToy: return .playful
        case .petCoffee: return .coffee
        case .petYawn: return .tired
        case .petDance: return .dance
        case .petCelebrate: return .celebrate
        case .petGreet, .petCall: return .greet
        case .petPat: return .affectionate
        case .petSnack: return .snack
        case .petHide: return .hidden
        default: return .idle
        }
    }
}

// MARK: - EI habitat / surface backdrop

private struct EISurfaceBackdrop: View {
    let mode: EIMode
    let preferences: EIOpenPreferences
    let environment: EIEnvironment

    var body: some View {
        switch mode {
        case .simulation:
            Color.black
        case .off:
            Color.black
        case .pet, .plant:
            LinearGradient(colors: background, startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [preferences.floor.color.opacity(0.15), preferences.floor.color.opacity(0.72)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 110)
                }
        }
    }

    private var background: [Color] {
        switch preferences.roomStyle {
        case .warm: return [preferences.room.color, preferences.accent.color.opacity(0.14), .black.opacity(0.94)]
        case .night: return [Color(red: 0.025, green: 0.03, blue: 0.07), preferences.room.color.opacity(0.72), .black]
        case .greenhouse: return [Color(red: 0.03, green: 0.10, blue: 0.07), preferences.room.color.opacity(0.72), preferences.accent.color.opacity(0.12)]
        case .minimal: return [preferences.room.color.opacity(0.88), preferences.room.color.opacity(0.56), .black.opacity(0.88)]
        }
    }
}

private struct EIHabitatDetails: View {
    let preferences: EIOpenPreferences
    let environment: EIEnvironment

    var body: some View {
        GeometryReader { proxy in
            let accent = preferences.accent.color
            ZStack {
                if preferences.window {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(LinearGradient(colors: sky, startPoint: .top, endPoint: .bottom))
                        .frame(width: min(150, proxy.size.width * 0.25), height: min(92, proxy.size.height * 0.26))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.12), lineWidth: 1))
                        .overlay(alignment: .topTrailing) {
                            if environment.weather?.isRaining == true {
                                Image(systemName: "cloud.rain.fill").font(.caption).foregroundStyle(.cyan.opacity(0.58)).padding(7)
                            }
                        }
                        .position(x: proxy.size.width * 0.18, y: proxy.size.height * 0.38)
                }

                if preferences.rug {
                    Ellipse().fill(accent.opacity(0.16))
                        .frame(width: min(260, proxy.size.width * 0.46), height: min(62, proxy.size.height * 0.16))
                        .position(x: proxy.size.width * 0.52, y: proxy.size.height * 0.82)
                }

                if preferences.shelf {
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            ForEach(0..<4, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(index.isMultiple(of: 2) ? accent.opacity(0.40) : Color.white.opacity(0.16))
                                    .frame(width: 7 + CGFloat(index % 2) * 4, height: 17 + CGFloat(index) * 2)
                            }
                        }
                        Capsule().fill(Color.white.opacity(0.13)).frame(width: 70, height: 3)
                    }
                    .position(x: proxy.size.width * 0.75, y: proxy.size.height * 0.30)
                }

                if preferences.roomPlants {
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { index in
                            Capsule().fill(Color.green.opacity(0.32 + Double(index) * 0.10))
                                .frame(width: 7, height: 18 + CGFloat(index) * 5)
                                .rotationEffect(.degrees(Double(index - 1) * 16))
                        }
                    }
                    .overlay(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 4).fill(accent.opacity(0.34)).frame(width: 27, height: 11).offset(y: 6)
                    }
                    .position(x: proxy.size.width * 0.11, y: proxy.size.height * 0.72)
                }

                if preferences.lamp {
                    VStack(spacing: -2) {
                        EITriangleRoom().fill(accent.opacity(0.60)).frame(width: 38, height: 26)
                        Rectangle().fill(Color.white.opacity(0.24)).frame(width: 3, height: 34)
                        Capsule().fill(Color.white.opacity(0.14)).frame(width: 27, height: 5)
                    }
                    .shadow(color: accent.opacity(environment.timeOfDay == .night ? 0.52 : 0.24), radius: 22)
                    .position(x: proxy.size.width * 0.86, y: proxy.size.height * 0.60)
                }
            }
        }
    }

    private var sky: [Color] {
        if environment.timeOfDay == .night { return [Color(red: 0.025, green: 0.04, blue: 0.11), .purple.opacity(0.34)] }
        return [.blue.opacity(0.52), .orange.opacity(environment.timeOfDay == .evening ? 0.38 : 0.08)]
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
