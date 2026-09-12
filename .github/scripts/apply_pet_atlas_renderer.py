from pathlib import Path

path = Path('Halo/Views/CompanionSprite.swift')
text = path.read_text()
start_marker = '// MARK: - Canonical EI pet sprite content'
end_marker = '// MARK: - Premium plant renderer'
assert start_marker in text, 'pet section marker missing'
assert end_marker in text, 'plant section marker missing'
start = text.index(start_marker)
end = text.index(end_marker)

replacement = r'''// MARK: - Canonical EI pet animation atlas

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
'''

text = text[:start] + replacement + '\n\n' + text[end:]
path.write_text(text)
