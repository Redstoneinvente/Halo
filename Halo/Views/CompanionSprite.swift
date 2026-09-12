import SwiftUI
import AppKit
import ImageIO

// MARK: - Canonical EI pet animation atlas

/// Semantic companion motions shared by ambient EI, the owned EI surface and roaming pets.
enum HaloCompanionMotion: String, CaseIterable, Identifiable {
    case hidden, peekEyes, peekEars, peek, peekLeft, peekRight, observe, idle, walk, look, greet, celebrate
    case sleep, snack, dance, stretch, groom, playful, affectionate, tired, excited, paw, tail
    case resting, curious, happy, coffee, working, umbrella, entering, leaving
    var id: String { rawValue }
}

/// The supplied pet atlases are always 8 columns × 6 rows (48 frames total).
/// Row order is part of the asset contract and must not be inferred from source pixel dimensions.
enum HaloPetAtlasAnimation: Int, CaseIterable, Identifiable {
    case walk = 0
    case sleep = 1
    case play = 2
    case coffeeFromLeft = 3
    case coffeeFromRight = 4
    case wave = 5

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .walk: return "Walk Right"
        case .sleep: return "Settle & Sleep"
        case .play: return "Play With Ball"
        case .coffeeFromLeft: return "Enter Left & Coffee"
        case .coffeeFromRight: return "Enter Right & Coffee"
        case .wave: return "Say Hi / Paw Wave"
        }
    }

    var framesPerSecond: Double {
        switch self {
        case .walk: return 11
        case .sleep: return 7
        case .play: return 10
        case .coffeeFromLeft, .coffeeFromRight: return 8
        case .wave: return 9
        }
    }

    var loops: Bool {
        switch self {
        case .walk, .play: return true
        case .sleep, .coffeeFromLeft, .coffeeFromRight, .wave: return false
        }
    }
}

/// One transparent 8×6 atlas, pre-sliced once at load time. Frame rectangles are calculated from
/// normalized fractions of the atlas width/height so non-square source pixels and odd dimensions are safe.
final class HaloPetAtlas: @unchecked Sendable {
    static let columns = 8
    static let rows = 6
    let resourceName: String
    let pixelSize: CGSize
    private let frames: [[CGImage]]

    init?(resourceName: String, image: CGImage) {
        self.resourceName = resourceName
        self.pixelSize = CGSize(width: image.width, height: image.height)
        var sliced: [[CGImage]] = []
        sliced.reserveCapacity(Self.rows)
        for row in 0..<Self.rows {
            var rowFrames: [CGImage] = []
            rowFrames.reserveCapacity(Self.columns)
            for column in 0..<Self.columns {
                // Use normalized boundaries rather than width / 8 and height / 6 assumptions.
                let nx0 = CGFloat(column) / CGFloat(Self.columns)
                let nx1 = CGFloat(column + 1) / CGFloat(Self.columns)
                let ny0 = CGFloat(row) / CGFloat(Self.rows)
                let ny1 = CGFloat(row + 1) / CGFloat(Self.rows)
                let x0 = Int((nx0 * CGFloat(image.width)).rounded(.down))
                let x1 = Int((nx1 * CGFloat(image.width)).rounded(.down))
                let y0 = Int((ny0 * CGFloat(image.height)).rounded(.down))
                let y1 = Int((ny1 * CGFloat(image.height)).rounded(.down))
                let rect = CGRect(x: x0, y: y0, width: max(1, x1 - x0), height: max(1, y1 - y0))
                guard let frame = image.cropping(to: rect) else { return nil }
                rowFrames.append(frame)
            }
            sliced.append(rowFrames)
        }
        guard sliced.count == Self.rows, sliced.allSatisfy({ $0.count == Self.columns }) else { return nil }
        self.frames = sliced
    }

    func frame(animation: HaloPetAtlasAnimation, index: Int) -> CGImage? {
        guard animation.rawValue >= 0, animation.rawValue < frames.count else { return nil }
        let row = frames[animation.rawValue]
        guard !row.isEmpty else { return nil }
        return row[min(max(0, index), row.count - 1)]
    }
}

@MainActor
final class HaloPetAssetStore: ObservableObject {
    static let shared = HaloPetAssetStore()
    @Published private(set) var revision = 0
    private var atlases: [String: HaloPetAtlas] = [:]
    private var loading = Set<String>()

    func atlas(for kind: EIPetKind) -> HaloPetAtlas? { atlases[kind.rawValue] }

    func load(_ kind: EIPetKind) {
        let key = kind.rawValue
        guard atlases[key] == nil, !loading.contains(key) else { return }
        let resource: String
        switch kind {
        case .cat: resource = "cat"
        case .dog: resource = "dog"
        case .fox: resource = "fox"
        }
        guard let url = Bundle.main.url(forResource: resource, withExtension: "png") else { return }
        loading.insert(key)
        Task { [weak self] in
            let atlas = await Task.detached(priority: .utility) { () -> HaloPetAtlas? in
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
                return HaloPetAtlas(resourceName: "\(resource).png", image: image)
            }.value
            guard let self else { return }
            self.loading.remove(key)
            if let atlas { self.atlases[key] = atlas }
            self.revision &+= 1
        }
    }
}

@MainActor
final class HaloPetDebugState: ObservableObject {
    static let shared = HaloPetDebugState()
    @Published var forcedMotion: HaloCompanionMotion?
    @Published var selectedAnimation: HaloPetAtlasAnimation = .walk
    @Published var previewFrame = 0
    private var playTask: Task<Void, Never>?

    func force(_ motion: HaloCompanionMotion?) {
        playTask?.cancel(); playTask = nil; forcedMotion = motion
    }

    func playAll() {
        playTask?.cancel()
        playTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let motions: [HaloCompanionMotion] = [.walk, .sleep, .playful, .coffee, .greet]
            for motion in motions {
                guard !Task.isCancelled else { return }
                self.forcedMotion = motion
                try? await Task.sleep(nanoseconds: 1_600_000_000)
            }
            if !Task.isCancelled { self.forcedMotion = nil }
        }
    }
}

/// Asset-backed 8×6 atlas renderer. The source PNGs already contain transparency, so Halo never
/// performs colour-keying, checkerboard removal or silhouette cleanup here; source alpha is preserved exactly.
struct HaloCompanionSprite: View {
    let kind: EIPetKind
    let style: EIPetVisualStyle
    var size: CGFloat
    var primary: Color
    var accent: Color
    var motion: HaloCompanionMotion = .idle
    var facingRight = true

    // Legacy call-site compatibility; atlas artwork intentionally ignores old vector/pixel styling.
    var displayPreset: EIPixelDisplayPreset = .clean
    var pixelGrid = false
    var pixelGlow = true
    var scanlines = false
    var ghosting = false
    var brightnessVariation = false

    @ObservedObject private var assets = HaloPetAssetStore.shared
    @ObservedObject private var debug = HaloPetDebugState.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animationEpoch = Date()
    @State private var hoverPoint: CGPoint?

    private var resolvedMotion: HaloCompanionMotion { debug.forcedMotion ?? motion }

    private var animation: HaloPetAtlasAnimation {
        switch resolvedMotion {
        case .walk, .leaving: return .walk
        case .sleep, .resting, .tired: return .sleep
        case .playful, .snack, .celebrate, .excited, .dance: return .play
        case .coffee, .working, .entering:
            return facingRight ? .coffeeFromLeft : .coffeeFromRight
        case .greet, .paw, .affectionate, .happy: return .wave
        case .hidden, .peekEyes, .peekEars, .peek, .peekLeft, .peekRight,
             .observe, .idle, .look, .stretch, .groom, .tail, .curious, .umbrella:
            return .wave
        }
    }

    private var shouldAnimate: Bool {
        if reduceMotion { return false }
        switch resolvedMotion {
        case .idle, .observe, .look, .curious, .umbrella, .peekEyes, .peekEars, .peek, .peekLeft, .peekRight, .hidden:
            return false
        default: return true
        }
    }

    var body: some View {
        Group {
            if resolvedMotion == .hidden {
                Color.clear
            } else if let atlas = assets.atlas(for: kind) {
                TimelineView(.animation(minimumInterval: shouldAnimate ? 1.0 / 30.0 : 0.25, paused: false)) { timeline in
                    if let frame = atlas.frame(animation: animation, index: frameIndex(at: timeline.date)) {
                        sprite(frame, phase: timeline.date.timeIntervalSinceReferenceDate)
                    }
                }
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size * 0.90)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let point): hoverPoint = point
            case .ended: hoverPoint = nil
            }
        }
        .task(id: kind.rawValue) { assets.load(kind) }
        .onAppear { animationEpoch = Date() }
        .onChange(of: resolvedMotion) { _ in animationEpoch = Date() }
        .onChange(of: facingRight) { _ in animationEpoch = Date() }
        .accessibilityLabel("\(kind.rawValue) companion")
    }

    private func frameIndex(at date: Date) -> Int {
        guard shouldAnimate else { return 0 }
        let elapsed = max(0, date.timeIntervalSince(animationEpoch))
        let raw = Int(floor(elapsed * animation.framesPerSecond))
        if animation.loops { return raw % HaloPetAtlas.columns }
        return min(HaloPetAtlas.columns - 1, raw)
    }

    private func sprite(_ image: CGImage, phase: Double) -> some View {
        let hover = cursorOffset
        let bob = reduceMotion ? 0 : bobOffset(phase)
        return Image(decorative: image, scale: 1, orientation: .up)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            // Atlas rows encode their own left/right entry direction. Only generic walk/idle art is mirrored.
            .scaleEffect(x: shouldMirror ? -1 : 1, y: 1, anchor: .center)
            .offset(x: hover.width, y: bob + hover.height + revealOffset)
            .mask(alignment: .top) {
                Rectangle().frame(height: max(1, size * 0.90 * revealAmount), alignment: .top)
            }
            .shadow(color: Color.black.opacity(resolvedMotion == .sleep ? 0.10 : 0.16), radius: max(1, size * 0.015), y: max(1, size * 0.010))
    }

    private var shouldMirror: Bool {
        switch animation {
        case .coffeeFromLeft, .coffeeFromRight: return false
        default: return !facingRight
        }
    }

    private var revealAmount: CGFloat {
        switch resolvedMotion {
        case .peekEyes: return 0.24
        case .peekEars: return 0.17
        case .peek, .peekLeft, .peekRight: return 0.60
        case .paw: return 0.74
        default: return 1
        }
    }

    private var revealOffset: CGFloat {
        let hidden = 1 - revealAmount
        return hidden > 0 ? hidden * size * 0.30 : 0
    }

    private func bobOffset(_ phase: Double) -> CGFloat {
        switch animation {
        case .walk: return -CGFloat(abs(sin(phase * 7.5))) * 1.2
        case .play: return -CGFloat(abs(sin(phase * 6.0))) * 1.0
        default: return 0
        }
    }

    private var cursorOffset: CGSize {
        guard let point = hoverPoint,
              [.observe, .look, .curious, .peek, .peekLeft, .peekRight].contains(resolvedMotion) else { return .zero }
        let nx = min(1, max(-1, (point.x / max(1, size) - 0.5) * 2))
        let ny = min(1, max(-1, (point.y / max(1, size * 0.90) - 0.5) * 2))
        return CGSize(width: nx * min(2.0, size * 0.015), height: ny * min(1.0, size * 0.008))
    }
}

#if DEBUG
@MainActor
struct HaloPetDebugPanel: View {
    @ObservedObject private var settings = EISettingsStore.shared
    @ObservedObject private var debug = HaloPetDebugState.shared
    @ObservedObject private var assets = HaloPetAssetStore.shared

    var body: some View {
        DisclosureGroup("Pet Debug") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Pet", selection: $settings.settings.petKind) {
                    ForEach(EIPetKind.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                HStack {
                    Button("Walk") { debug.force(.walk) }
                    Button("Sleep") { debug.force(.sleep) }
                    Button("Play") { debug.force(.playful) }
                    Button("Coffee") { debug.force(.coffee) }
                    Button("Wave") { debug.force(.greet) }
                }
                .font(.caption2)
                HStack {
                    Button("Play All") { debug.playAll() }
                    Button("Release") { debug.force(nil) }
                }

                if let atlas = assets.atlas(for: settings.settings.petKind) {
                    Text("\(atlas.resourceName) · 8×6 · 48 transparent frames · \(Int(atlas.pixelSize.width))×\(Int(atlas.pixelSize.height)) px")
                        .font(.caption2).foregroundStyle(.secondary)
                    Picker("Atlas row", selection: $debug.selectedAnimation) {
                        ForEach(HaloPetAtlasAnimation.allCases) { Text($0.title).tag($0) }
                    }
                    Slider(value: Binding(get: { Double(debug.previewFrame) }, set: { debug.previewFrame = Int($0.rounded()) }), in: 0...7, step: 1)
                    if let frame = atlas.frame(animation: debug.selectedAnimation, index: debug.previewFrame) {
                        Image(decorative: frame, scale: 1, orientation: .up)
                            .resizable().interpolation(.high).scaledToFit().frame(height: 72)
                    }
                } else {
                    Text("Loading transparent atlas…").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.top, 6)
            .task(id: settings.settings.petKind.rawValue) { assets.load(settings.settings.petKind) }
        }
    }
}
#endif


// MARK: - Premium plant renderer

struct HaloPlantRenderer: View {
    let kind: EIPlantKind
    var size: CGFloat
    var plantColor: Color
    var potColor: Color
    var growth: Double
    var environment: EIEnvironment
    var reaction: EIReactionKind?
    var compact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.30 : 1.0 / 24.0, paused: false)) { timeline in
            plant(phase: timeline.date.timeIntervalSinceReferenceDate)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(kind.rawValue) environmental plant")
    }

    private func plant(phase: Double) -> some View {
        let g = CGFloat(min(1, max(0.06, growth)))
        let night = environment.timeOfDay == .night || reaction == .plantNight
        let rain = environment.weather?.isRaining == true || reaction == .plantRain
        let music = environment.isMusicPlaying
        let wind = reduceMotion ? 0.0 : sin(phase * (music ? 1.8 : 0.75)) * (music ? 3.2 : 1.4)
        let ambient = night ? 0.80 : 1.0

        return ZStack(alignment: .bottom) {
            Ellipse().fill(Color.black.opacity(0.20)).frame(width: size * 0.54, height: size * 0.10)
                .blur(radius: size * 0.015).offset(y: size * 0.025)
            pot(size)

            switch kind {
            case .bonsai: bonsai(size, g, wind, ambient, phase)
            case .flower: flowering(size, g, wind, ambient, phase)
            case .vine: vine(size, g, wind, ambient, phase)
            case .succulent: succulent(size, g, ambient)
            case .fern: fern(size, g, wind, ambient)
            }

            if rain { rainDrops(size, phase) }
        }
        .frame(width: size, height: size)
        .drawingGroup(opaque: false, colorMode: .linear)
    }

    private func pot(_ s: CGFloat) -> some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: s * 0.025, style: .continuous)
                .fill(potColor.mixed(with: .white, amount: 0.12)).frame(width: s * 0.40, height: s * 0.075)
            PlantPotShape().fill(LinearGradient(colors: [potColor, potColor.mixed(with: .black, amount: 0.28)], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.34, height: s * 0.22)
        }
        .shadow(color: Color.black.opacity(0.20), radius: s * 0.025, y: s * 0.018)
    }

    private func bonsai(_ s: CGFloat, _ g: CGFloat, _ wind: Double, _ ambient: Double, _ phase: Double) -> some View {
        ZStack(alignment: .bottom) {
            BonsaiTrunkShape().stroke(potColor.mixed(with: .black, amount: 0.36), style: StrokeStyle(lineWidth: max(3, s * 0.055), lineCap: .round, lineJoin: .round))
                .frame(width: s * 0.48, height: s * 0.60).offset(y: -s * 0.18)
            ForEach(0..<9, id: \.self) { index in
                if CGFloat(index + 1) / 9 <= max(0.22, g + 0.14) {
                    let xs: [CGFloat] = [-0.20, 0.10, -0.03, 0.22, -0.17, 0.05, 0.25, -0.06, 0.15]
                    let ys: [CGFloat] = [-0.48, -0.43, -0.55, -0.37, -0.31, -0.28, -0.23, -0.18, -0.15]
                    leafCluster(s * (0.20 + CGFloat(index % 3) * 0.018), phase + Double(index), ambient)
                        .rotationEffect(.degrees(wind * (index.isMultiple(of: 2) ? 1 : -0.7)), anchor: .bottom)
                        .offset(x: xs[index] * s, y: ys[index] * s)
                }
            }
        }
    }

    private func flowering(_ s: CGFloat, _ g: CGFloat, _ wind: Double, _ ambient: Double, _ phase: Double) -> some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<5, id: \.self) { index in
                let angle = Double(index - 2) * 12
                Capsule(style: .continuous).fill(plantColor.mixed(with: .black, amount: 0.18).opacity(ambient))
                    .frame(width: s * 0.025, height: s * (0.38 + g * 0.20))
                    .rotationEffect(.degrees(angle + wind * 0.45), anchor: .bottom).offset(y: -s * 0.18)
                leaf(s * 0.17, ambient)
                    .rotationEffect(.degrees(angle - 32 + wind), anchor: .trailing)
                    .offset(x: CGFloat(index - 2) * s * 0.055, y: -s * (0.30 + CGFloat(index % 2) * 0.08))
            }
            if g > 0.34 || reaction == .plantBloom {
                ForEach(0..<3, id: \.self) { index in
                    let openness: Double = reaction == .plantBloom ? 1 : Double(min(1, max(0, (g - 0.30) * 1.8)))
                    flower(s * 0.16, openness, phase + Double(index))
                        .offset(x: CGFloat(index - 1) * s * 0.13, y: -s * (0.61 + CGFloat(index % 2) * 0.055))
                        .rotationEffect(.degrees(wind * 0.65))
                }
            }
        }
    }

    private func vine(_ s: CGFloat, _ g: CGFloat, _ wind: Double, _ ambient: Double, _ phase: Double) -> some View {
        ZStack(alignment: .bottom) {
            VineStemShape().trim(from: 0, to: g)
                .stroke(plantColor.mixed(with: .black, amount: 0.22).opacity(ambient), style: StrokeStyle(lineWidth: max(2, s * 0.025), lineCap: .round))
                .frame(width: s * 0.64, height: s * 0.70).offset(y: -s * 0.16)
            ForEach(0..<10, id: \.self) { index in
                if CGFloat(index) / 10 < g {
                    leaf(s * 0.13, ambient)
                        .rotationEffect(.degrees(Double(index.isMultiple(of: 2) ? -38 : 38) + wind * 0.6))
                        .offset(x: CGFloat(sin(Double(index) * 1.17)) * s * 0.22,
                                y: -s * (0.24 + CGFloat(index) * 0.047))
                }
            }
            if reaction == .plantBloom && g > 0.45 {
                flower(s * 0.12, 1, phase).offset(x: s * 0.20, y: -s * 0.62)
            }
        }
    }

    private func succulent(_ s: CGFloat, _ g: CGFloat, _ ambient: Double) -> some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<11, id: \.self) { index in
                let angle = Double(index) / 11 * 320 - 160
                let inner = index >= 7
                PlantSucculentLeaf().fill(LinearGradient(colors: [plantColor.mixed(with: .white, amount: 0.20).opacity(ambient), plantColor.mixed(with: .black, amount: 0.20).opacity(ambient)], startPoint: .top, endPoint: .bottom))
                    .frame(width: s * (inner ? 0.15 : 0.19), height: s * (inner ? 0.28 : 0.36) * max(0.58, g))
                    .rotationEffect(.degrees(angle * (inner ? 0.38 : 0.58)), anchor: .bottom).offset(y: -s * 0.17)
            }
        }
    }

    private func fern(_ s: CGFloat, _ g: CGFloat, _ wind: Double, _ ambient: Double) -> some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<7, id: \.self) { index in
                FernFrondShape().stroke(plantColor.opacity(ambient), style: StrokeStyle(lineWidth: max(2, s * 0.022), lineCap: .round))
                    .overlay(FernLeaflets().stroke(plantColor.mixed(with: .white, amount: 0.10).opacity(ambient), lineWidth: max(1, s * 0.012)))
                    .frame(width: s * 0.22, height: s * (0.42 + g * 0.18))
                    .rotationEffect(.degrees(Double(index - 3) * 13 + wind), anchor: .bottom).offset(y: -s * 0.18)
            }
        }
    }

    private func leaf(_ size: CGFloat, _ ambient: Double) -> some View {
        PlantLeafShape().fill(LinearGradient(colors: [plantColor.mixed(with: .white, amount: 0.18).opacity(ambient), plantColor.mixed(with: .black, amount: 0.16).opacity(ambient)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size * 0.58)
            .overlay(PlantLeafVein().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
    }

    private func leafCluster(_ size: CGFloat, _ phase: Double, _ ambient: Double) -> some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                leaf(size * 0.72, ambient)
                    .rotationEffect(.degrees(Double(index) * 55 - 105 + sin(phase * 0.6 + Double(index)) * 2.2), anchor: .trailing)
                    .offset(x: CGFloat(index - 2) * size * 0.09)
            }
        }
    }

    private func flower(_ size: CGFloat, _ open: Double, _ phase: Double) -> some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Ellipse().fill(Color.pink.mixed(with: plantColor, amount: 0.18).opacity(0.92))
                    .frame(width: size * 0.58, height: size)
                    .rotationEffect(.degrees(Double(index) * 72))
                    .scaleEffect(CGFloat(0.40 + open * 0.60))
            }
            Circle().fill(Color.yellow.opacity(0.88)).frame(width: size * 0.25, height: size * 0.25)
        }
        .rotationEffect(.degrees(sin(phase * 0.5) * 2))
    }

    @ViewBuilder
    private func rainDrops(_ s: CGFloat, _ phase: Double) -> some View {
        ForEach(0..<6, id: \.self) { index in
            let travel = (phase * 0.48 + Double(index) * 0.17).truncatingRemainder(dividingBy: 1)
            Capsule().fill(Color.cyan.opacity(0.40)).frame(width: 1.5, height: s * 0.055)
                .offset(x: CGFloat(index - 3) * s * 0.12, y: -s * 0.72 + CGFloat(travel) * s * 0.56)
        }
    }
}

// MARK: - Tiny City vector simulation

struct HaloCityRenderer: View {
    var accent: Color
    var environment: EIEnvironment
    var reaction: EIReactionKind?
    var seed: Int
    var compact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.25 : 1.0 / 30.0, paused: false)) { timeline in
            GeometryReader { proxy in city(proxy.size, timeline.date.timeIntervalSinceReferenceDate) }
        }
        .accessibilityLabel("Tiny City environmental simulation")
    }

    private func city(_ size: CGSize, _ phase: Double) -> some View {
        let night = environment.timeOfDay == .night || reaction == .cityNight
        let evening = environment.timeOfDay == .evening
        let rain = environment.weather?.isRaining == true || reaction == .cityRain || reaction == .cityStorm
        let busy = reaction == .cityBusy || environment.timeOfDay == .day
        let music = environment.isMusicPlaying || reaction == .cityMusic
        let roadY = size.height * 0.76
        let speed: Double = reduceMotion ? 0 : (busy ? 34 : night ? 12 : 24)
        let travelWidth = Double(max(1, size.width + 70))
        let taxiWidth = Double(max(1, size.width + 80))
        let carX = CGFloat((phase * speed).truncatingRemainder(dividingBy: travelWidth)) - 35
        let taxiX = size.width - CGFloat((phase * speed * 0.68 + 96).truncatingRemainder(dividingBy: taxiWidth)) + 40
        let sky: [Color] = night
            ? [Color(red: 0.025, green: 0.035, blue: 0.09), Color(red: 0.07, green: 0.09, blue: 0.17)]
            : evening
                ? [Color(red: 0.20, green: 0.12, blue: 0.22), Color(red: 0.54, green: 0.25, blue: 0.20)]
                : [Color(red: 0.08, green: 0.14, blue: 0.22), Color(red: 0.13, green: 0.24, blue: 0.32)]

        return ZStack(alignment: .bottom) {
            LinearGradient(colors: sky, startPoint: .top, endPoint: .bottom)

            RoundedRectangle(cornerRadius: min(22, size.height * 0.16), style: .continuous)
                .fill(Color.black.opacity(0.88))
                .frame(width: min(size.width * 0.26, 150), height: size.height * 0.55)
                .overlay(alignment: .bottom) {
                    Capsule().fill(accent.opacity(0.32)).frame(width: min(64, size.width * 0.12), height: 3).padding(.bottom, 7)
                }
                .offset(y: -size.height * 0.19)

            buildings(size, night, music, phase)
            Rectangle().fill(Color.black.opacity(0.48)).frame(height: size.height * 0.22)
            Rectangle().fill(Color.white.opacity(0.055)).frame(height: 1).offset(y: -size.height * 0.20)

            cityCar(accent, false).frame(width: 32, height: 15).position(x: carX, y: roadY)
            cityCar(Color.yellow.opacity(0.86), true).frame(width: 34, height: 15)
                .scaleEffect(x: -1, y: 1).position(x: taxiX, y: roadY + size.height * 0.075)

            pedestrians(size, phase, busy, night, rain)
            if music { club(size, phase) }
            if rain { rainLayer(size, phase) }
            randomMoment(size, phase)
        }
        .drawingGroup(opaque: false, colorMode: .linear)
    }

    private func buildings(_ size: CGSize, _ night: Bool, _ music: Bool, _ phase: Double) -> some View {
        let heights: [CGFloat] = [0.35, 0.49, 0.31, 0.44, 0.38, 0.52, 0.34, 0.42]
        return HStack(alignment: .bottom, spacing: max(2, size.width * 0.008)) {
            ForEach(Array(heights.enumerated()), id: \.offset) { index, ratio in
                if index == 3 || index == 4 {
                    Color.clear.frame(width: size.width * 0.12)
                } else {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.12), Color.black.opacity(0.32)], startPoint: .top, endPoint: .bottom))
                        .frame(width: max(18, size.width * 0.075), height: size.height * ratio)
                        .overlay(windowGrid(index, night, music, phase).padding(5))
                }
            }
        }
        .frame(maxWidth: .infinity).padding(.horizontal, 8).offset(y: -size.height * 0.20)
    }

    private func windowGrid(_ index: Int, _ night: Bool, _ music: Bool, _ phase: Double) -> some View {
        let active = night || environment.timeOfDay == .evening
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
            ForEach(0..<8, id: \.self) { window in
                let lit = active && ((window + index + seed) % 3 != 0)
                RoundedRectangle(cornerRadius: 1)
                    .fill(lit ? Color.yellow.opacity(0.45 + (music && index == 6 ? abs(sin(phase * 2.2)) * 0.28 : 0)) : Color.white.opacity(0.055))
                    .frame(height: 4)
            }
        }
    }

    private func cityCar(_ color: Color, _ taxi: Bool) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(color).frame(width: 30, height: 10)
            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(color.mixed(with: .white, amount: 0.14))
                .frame(width: 17, height: 8).offset(x: 2, y: -5)
            HStack(spacing: 14) {
                Circle().fill(Color.black.opacity(0.88)).frame(width: 6, height: 6)
                Circle().fill(Color.black.opacity(0.88)).frame(width: 6, height: 6)
            }.offset(y: 2)
            if taxi { Capsule().fill(Color.white.opacity(0.55)).frame(width: 8, height: 2).offset(y: -10) }
        }
    }

    @ViewBuilder
    private func pedestrians(_ size: CGSize, _ phase: Double, _ busy: Bool, _ night: Bool, _ rain: Bool) -> some View {
        let count = night ? 2 : busy ? 7 : 4
        ForEach(0..<count, id: \.self) { index in
            let lane = CGFloat(index % 2)
            let speed = reduceMotion ? 0.0 : Double(6 + (index * 3) % 7)
            let travel = CGFloat((phase * speed + Double(index * 53)).truncatingRemainder(dividingBy: Double(max(1, size.width + 40)))) - 20
            CityPerson(umbrella: rain && index.isMultiple(of: 2), accent: index.isMultiple(of: 3) ? accent : Color.white.opacity(0.68))
                .frame(width: 12, height: 22)
                .position(x: index.isMultiple(of: 2) ? travel : size.width - travel,
                          y: size.height * (0.68 + lane * 0.09))
        }
    }

    private func club(_ size: CGSize, _ phase: Double) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(accent.opacity(0.16 + abs(sin(phase * 2.0)) * 0.14))
            .frame(width: max(28, size.width * 0.07), height: max(18, size.height * 0.10))
            .overlay(Image(systemName: "music.note").font(.system(size: 8, weight: .bold)).foregroundStyle(accent.opacity(0.8)))
            .position(x: size.width * 0.82, y: size.height * 0.55)
    }

    @ViewBuilder
    private func rainLayer(_ size: CGSize, _ phase: Double) -> some View {
        ForEach(0..<18, id: \.self) { index in
            let travel = (phase * 0.58 + Double(index) * 0.071).truncatingRemainder(dividingBy: 1)
            Capsule().fill(Color.cyan.opacity(0.20 + Double(index % 3) * 0.04))
                .frame(width: 1, height: 9).rotationEffect(.degrees(8))
                .position(x: CGFloat(index) / 18 * size.width, y: CGFloat(travel) * size.height)
        }
        Rectangle().fill(Color.cyan.opacity(0.07)).frame(height: 2).blur(radius: 2).offset(y: -size.height * 0.18)
    }

    @ViewBuilder
    private func randomMoment(_ size: CGSize, _ phase: Double) -> some View {
        let slot = (Int(phase / 19) + seed) % 11
        switch slot {
        case 2:
            Circle().fill(Color.red.opacity(0.76)).frame(width: 9, height: 9)
                .overlay(Rectangle().fill(Color.white.opacity(0.5)).frame(width: 1, height: 18).offset(y: 11))
                .position(x: size.width * 0.18, y: size.height * 0.23)
        case 5:
            Image(systemName: "bird.fill").font(.system(size: 9)).foregroundStyle(Color.white.opacity(0.42))
                .position(x: CGFloat((phase * 8).truncatingRemainder(dividingBy: Double(max(1, size.width)))), y: size.height * 0.19)
        case 8:
            RoundedRectangle(cornerRadius: 3).fill(Color.orange.opacity(0.72)).frame(width: 38, height: 15)
                .overlay(Text("DELIVERY").font(.system(size: 4, weight: .bold)).foregroundStyle(.white.opacity(0.8)))
                .position(x: size.width * 0.70, y: size.height * 0.76)
        default:
            EmptyView()
        }
    }
}

private struct CityPerson: View {
    let umbrella: Bool
    let accent: Color
    var body: some View {
        ZStack(alignment: .top) {
            if umbrella { ArcShape().stroke(accent.opacity(0.65), lineWidth: 1.5).frame(width: 12, height: 7).offset(y: -3) }
            Circle().fill(accent).frame(width: 4.5, height: 4.5)
            Capsule().fill(accent.opacity(0.88)).frame(width: 4, height: 10).offset(y: 4)
            HStack(spacing: 2) {
                Capsule().fill(accent.opacity(0.70)).frame(width: 1.5, height: 7).rotationEffect(.degrees(10))
                Capsule().fill(accent.opacity(0.70)).frame(width: 1.5, height: 7).rotationEffect(.degrees(-10))
            }.offset(y: 13)
        }
    }
}

// MARK: - Vector shapes

private struct CompanionEarShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.maxY), control1: CGPoint(x: r.width * 0.72, y: r.height * 0.22), control2: CGPoint(x: r.width * 0.95, y: r.height * 0.70))
        p.addCurve(to: CGPoint(x: r.minX, y: r.maxY), control1: CGPoint(x: r.width * 0.72, y: r.height * 0.95), control2: CGPoint(x: r.width * 0.28, y: r.height * 0.95))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY), control1: CGPoint(x: r.width * 0.05, y: r.height * 0.70), control2: CGPoint(x: r.width * 0.28, y: r.height * 0.22)); return p
    }
}
private struct CompanionFloppyEarShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.height * 0.64), control1: CGPoint(x: r.maxX, y: r.height * 0.10), control2: CGPoint(x: r.maxX, y: r.height * 0.38))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY), control1: CGPoint(x: r.width * 0.92, y: r.maxY), control2: CGPoint(x: r.width * 0.66, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.height * 0.36), control1: CGPoint(x: r.width * 0.08, y: r.height * 0.84), control2: CGPoint(x: r.minX, y: r.height * 0.58)); p.closeSubpath(); return p
    }
}
private struct CompanionTailShape: Shape {
    let kind: EIPetKind
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.width * 0.10, y: r.height * 0.92))
        if kind == .dog {
            p.addCurve(to: CGPoint(x: r.width * 0.74, y: r.height * 0.26), control1: CGPoint(x: r.width * 0.36, y: r.height * 0.80), control2: CGPoint(x: r.width * 0.46, y: r.height * 0.20))
        } else {
            p.addCurve(to: CGPoint(x: r.width * 0.82, y: r.height * 0.20), control1: CGPoint(x: r.width * 0.42, y: r.height * 0.92), control2: CGPoint(x: r.width * 0.88, y: r.height * 0.76))
            p.addCurve(to: CGPoint(x: r.width * 0.60, y: r.height * 0.06), control1: CGPoint(x: r.width * 0.94, y: r.height * 0.10), control2: CGPoint(x: r.width * 0.77, y: r.minY))
        }; return p
    }
}
private struct CompanionMouthShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.maxY), control1: CGPoint(x: r.midX, y: r.height * 0.62), control2: CGPoint(x: r.width * 0.20, y: r.maxY))
        p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addCurve(to: CGPoint(x: r.maxX, y: r.maxY), control1: CGPoint(x: r.midX, y: r.height * 0.62), control2: CGPoint(x: r.width * 0.80, y: r.maxY)); return p
    }
}
private struct CompanionChestShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.height * 0.52), control1: CGPoint(x: r.width * 0.88, y: r.height * 0.13), control2: CGPoint(x: r.maxX, y: r.height * 0.34))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY), control1: CGPoint(x: r.width * 0.82, y: r.height * 0.78), control2: CGPoint(x: r.width * 0.62, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.height * 0.52), control1: CGPoint(x: r.width * 0.38, y: r.maxY), control2: CGPoint(x: r.width * 0.12, y: r.height * 0.78)); p.closeSubpath(); return p
    }
}
private struct FoxCheekShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY), control1: CGPoint(x: r.width * 0.18, y: r.maxY), control2: CGPoint(x: r.width * 0.36, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.midY), control1: CGPoint(x: r.width * 0.64, y: r.maxY), control2: CGPoint(x: r.width * 0.82, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY), control1: CGPoint(x: r.width * 0.82, y: r.height * 0.18), control2: CGPoint(x: r.width * 0.63, y: r.minY)); p.closeSubpath(); return p
    }
}
private struct CupShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(roundedRect: CGRect(x: r.minX, y: r.minY, width: r.width * 0.72, height: r.height), cornerRadius: r.height * 0.16)
        p.addEllipse(in: CGRect(x: r.width * 0.62, y: r.height * 0.22, width: r.width * 0.34, height: r.height * 0.48)); return p
    }
}
private struct PlantPotShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.width * 0.08, y: r.minY)); p.addLine(to: CGPoint(x: r.width * 0.92, y: r.minY)); p.addLine(to: CGPoint(x: r.width * 0.78, y: r.maxY)); p.addLine(to: CGPoint(x: r.width * 0.22, y: r.maxY)); p.closeSubpath(); return p
    }
}
private struct BonsaiTrunkShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.width * 0.42, y: r.height * 0.52), control1: CGPoint(x: r.width * 0.48, y: r.height * 0.82), control2: CGPoint(x: r.width * 0.28, y: r.height * 0.68))
        p.addCurve(to: CGPoint(x: r.width * 0.58, y: r.height * 0.14), control1: CGPoint(x: r.width * 0.58, y: r.height * 0.40), control2: CGPoint(x: r.width * 0.65, y: r.height * 0.28))
        p.move(to: CGPoint(x: r.width * 0.44, y: r.height * 0.54)); p.addCurve(to: CGPoint(x: r.width * 0.18, y: r.height * 0.34), control1: CGPoint(x: r.width * 0.31, y: r.height * 0.48), control2: CGPoint(x: r.width * 0.24, y: r.height * 0.38))
        p.move(to: CGPoint(x: r.width * 0.52, y: r.height * 0.34)); p.addCurve(to: CGPoint(x: r.width * 0.82, y: r.height * 0.25), control1: CGPoint(x: r.width * 0.64, y: r.height * 0.30), control2: CGPoint(x: r.width * 0.72, y: r.height * 0.25)); return p
    }
}
private struct VineStemShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.width * 0.26, y: r.height * 0.63), control1: CGPoint(x: r.width * 0.70, y: r.height * 0.86), control2: CGPoint(x: r.width * 0.18, y: r.height * 0.76))
        p.addCurve(to: CGPoint(x: r.width * 0.70, y: r.height * 0.31), control1: CGPoint(x: r.width * 0.35, y: r.height * 0.51), control2: CGPoint(x: r.width * 0.78, y: r.height * 0.48))
        p.addCurve(to: CGPoint(x: r.width * 0.48, y: r.minY), control1: CGPoint(x: r.width * 0.61, y: r.height * 0.20), control2: CGPoint(x: r.width * 0.38, y: r.height * 0.12)); return p
    }
}
private struct PlantLeafShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.minX, y: r.midY)); p.addCurve(to: CGPoint(x: r.maxX, y: r.midY), control1: CGPoint(x: r.width * 0.30, y: r.minY), control2: CGPoint(x: r.width * 0.72, y: r.minY)); p.addCurve(to: CGPoint(x: r.minX, y: r.midY), control1: CGPoint(x: r.width * 0.70, y: r.maxY), control2: CGPoint(x: r.width * 0.28, y: r.maxY)); return p
    }
}
private struct PlantLeafVein: Shape {
    func path(in r: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: r.minX, y: r.midY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY)); return p }
}
private struct PlantSucculentLeaf: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addCurve(to: CGPoint(x: r.maxX, y: r.maxY), control1: CGPoint(x: r.maxX, y: r.height * 0.34), control2: CGPoint(x: r.maxX, y: r.height * 0.77)); p.addCurve(to: CGPoint(x: r.minX, y: r.maxY), control1: CGPoint(x: r.width * 0.72, y: r.height * 0.91), control2: CGPoint(x: r.width * 0.28, y: r.height * 0.91)); p.addCurve(to: CGPoint(x: r.midX, y: r.minY), control1: CGPoint(x: r.minX, y: r.height * 0.77), control2: CGPoint(x: r.minX, y: r.height * 0.34)); return p
    }
}
private struct FernFrondShape: Shape {
    func path(in r: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.maxY)); p.addCurve(to: CGPoint(x: r.midX, y: r.minY), control1: CGPoint(x: r.width * 0.18, y: r.height * 0.62), control2: CGPoint(x: r.width * 0.82, y: r.height * 0.34)); return p }
}
private struct FernLeaflets: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); for i in 1..<7 { let y = r.maxY - CGFloat(i) / 7 * r.height; let x = r.midX + CGFloat(sin(Double(i) * 0.9)) * r.width * 0.10; p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: r.minX, y: y - r.height * 0.06)); p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: r.maxX, y: y - r.height * 0.06)) }; return p
    }
}
private struct ArcShape: Shape {
    func path(in r: CGRect) -> Path { var p = Path(); p.addArc(center: CGPoint(x: r.midX, y: r.maxY), radius: r.width * 0.48, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false); return p }
}

private extension Color {
    func mixed(with other: Color, amount: CGFloat) -> Color {
        let fraction = max(0, min(1, amount))
        let lhs = NSColor(self).usingColorSpace(.deviceRGB) ?? .white
        let rhs = NSColor(other).usingColorSpace(.deviceRGB) ?? .white
        return Color(nsColor: lhs.blended(withFraction: fraction, of: rhs) ?? lhs)
    }
}
