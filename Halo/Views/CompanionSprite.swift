import SwiftUI
import AppKit
import ImageIO

// MARK: - Canonical EI pet animation system (V2)

/// Semantic companion motions used by the rest of Halo. The V2 renderer translates these into
/// richer atlas animations without forcing the EI engine to know about asset layout.
enum HaloCompanionMotion: String, CaseIterable, Identifiable {
    case hidden, peekEyes, peekEars, peek, peekLeft, peekRight, observe, idle, walk, look, greet, celebrate
    case sleep, snack, dance, stretch, groom, playful, affectionate, tired, excited, paw, tail
    case resting, curious, happy, coffee, working, umbrella, entering, leaving
    var id: String { rawValue }
}

enum HaloPetAnimation: String, CaseIterable, Identifiable, Codable {
    case standingIdle, sittingIdle, walkRight, runRight, standToSit, lookAround
    case settleToSleep, sleepLoop, wakeToStretch, yawn, groomScratch, eatSnack, drinkWater
    case happyExcited, celebrate, sayHi, cursorTracking, pawAtCursor, affection, surprised, concerned
    case eyesPeekUp, headPeekUp, pawsOnLedge, headRestOnLedge, peekFromLeft, peekFromRight
    case climbOntoLedge, dropBehindLedge, tailReveal, hangingOverEdge
    case playWithBall, chaseBallRight, coffeeSipLoop, enterLeftToCoffee, enterRightToCoffee
    case tinyLaptopWorking, laptopToSleep, sleepingAtLaptop, umbrellaIdle, rainSeekShelter

    var id: String { rawValue }

    var displayName: String {
        rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized
    }
}

struct HaloPetManifest: Decodable, Sendable {
    struct CellSize: Decodable, Sendable { let width: Int; let height: Int }
    struct Definition: Decodable, Sendable {
        let id: String
        let row: Int
        let playbackFrames: Int
        let loop: Bool?
        let mirrorForLeft: Bool?
        let reverseAs: String?
        let frameSelectedByCursor: Bool?
    }

    let version: Int
    let cellSize: CellSize
    let columns: Int
    let generatedKeyframesPerAnimation: Int
    let atlases: [String: [Definition]]
}

struct HaloPetAnimationClip: @unchecked Sendable {
    let animation: HaloPetAnimation
    let frames: [CGImage]
    let playbackFrames: Int
    let loops: Bool
    let mirrorForLeft: Bool
    let frameSelectedByCursor: Bool

    var fps: Double {
        switch animation {
        case .standingIdle, .sittingIdle, .lookAround, .sleepLoop, .headRestOnLedge, .hangingOverEdge,
             .coffeeSipLoop, .tinyLaptopWorking, .sleepingAtLaptop, .umbrellaIdle:
            return 6
        case .walkRight: return 11
        case .runRight, .chaseBallRight: return 14
        case .settleToSleep, .wakeToStretch, .laptopToSleep: return 8
        case .enterLeftToCoffee, .enterRightToCoffee: return 8
        case .eyesPeekUp, .headPeekUp, .pawsOnLedge, .peekFromLeft, .peekFromRight,
             .climbOntoLedge, .dropBehindLedge, .tailReveal: return 10
        default: return 9
        }
    }

    var duration: TimeInterval { Double(max(1, playbackFrames)) / fps }

    func keyframe(forPlaybackFrame playbackFrame: Int) -> Int {
        guard !frames.isEmpty else { return 0 }
        let count = max(1, playbackFrames)
        let p = min(max(0, playbackFrame), count - 1)
        let normalized = Double(p) / Double(max(1, count - 1))
        return min(frames.count - 1, Int((normalized * Double(frames.count - 1)).rounded(.toNearestOrAwayFromZero)))
    }
}

/// All five V2 sheets for one species, sliced once and cached. The source PNG alpha is used as-is.
final class HaloPetV2Library: @unchecked Sendable {
    let species: String
    let clips: [HaloPetAnimation: HaloPetAnimationClip]

    init?(species: String, manifest: HaloPetManifest, rootURL: URL) {
        var result: [HaloPetAnimation: HaloPetAnimationClip] = [:]
        for (atlasName, definitions) in manifest.atlases {
            let atlasURL = rootURL.appendingPathComponent(species).appendingPathComponent("\(atlasName).png")
            guard let source = CGImageSourceCreateWithURL(atlasURL as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
            let columns = max(1, manifest.columns)
            let cellWidth = max(1, manifest.cellSize.width)
            let cellHeight = max(1, manifest.cellSize.height)
            let expectedWidth = columns * cellWidth
            guard image.width >= expectedWidth else { return nil }

            for definition in definitions {
                guard let animation = HaloPetAnimation(rawValue: definition.id) else { continue }
                let authoredTop = definition.row * cellHeight
                guard authoredTop >= 0, authoredTop + cellHeight <= image.height else { continue }

                var frames: [CGImage] = []
                frames.reserveCapacity(manifest.generatedKeyframesPerAnimation)
                for column in 0..<manifest.generatedKeyframesPerAnimation {
                    let x = column * cellWidth
                    guard x + cellWidth <= image.width else { break }

                    // The manifest is authored top-to-bottom, while CGImage crop rectangles use
                    // Core Graphics' bottom-origin image space. Convert the authored row explicitly.
                    // Using the fixed 200x200 manifest cell is also important: dividing by the PNG's
                    // total height makes a single export-padding pixel corrupt every row below it.
                    let y = image.height - authoredTop - cellHeight
                    let rect = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
                    guard let frame = image.cropping(to: rect) else { continue }
                    frames.append(frame)
                }
                guard !frames.isEmpty else { continue }
                result[animation] = HaloPetAnimationClip(
                    animation: animation,
                    frames: frames,
                    playbackFrames: definition.playbackFrames,
                    loops: definition.loop ?? false,
                    mirrorForLeft: definition.mirrorForLeft ?? false,
                    frameSelectedByCursor: definition.frameSelectedByCursor ?? false
                )
            }
        }
        self.species = species
        self.clips = result
    }

    func clip(_ animation: HaloPetAnimation) -> HaloPetAnimationClip? { clips[animation] }
}

@MainActor
final class HaloPetAssetStore: ObservableObject {
    static let shared = HaloPetAssetStore()
    @Published private(set) var revision = 0
    private var library: HaloPetV2Library?
    private var loadingSpecies: String?

    func library(for kind: EIPetKind) -> HaloPetV2Library? {
        let species = kind.rawValue.lowercased()
        return library?.species.lowercased() == species ? library : nil
    }

    func load(_ kind: EIPetKind) {
        let species = kind.rawValue.lowercased()
        guard library?.species != species, loadingSpecies != species else { return }
        loadingSpecies = species

        guard let root = Bundle.main.resourceURL?.appendingPathComponent("halo-pets-v2"),
              let manifestURL = Bundle.main.url(forResource: "manifest", withExtension: "json", subdirectory: "halo-pets-v2") else {
            loadingSpecies = nil
            return
        }

        Task { [weak self] in
            let decoded = await Task.detached(priority: .utility) { () -> HaloPetV2Library? in
                guard let data = try? Data(contentsOf: manifestURL),
                      let manifest = try? JSONDecoder().decode(HaloPetManifest.self, from: data),
                      manifest.version == 2 else { return nil }
                return HaloPetV2Library(species: species, manifest: manifest, rootURL: root)
            }.value
            guard let self else { return }
            // Publish on the next main-run-loop turn. Completing a decode can coincide with a
            // SwiftUI update pass; deferring ObservableObject publication avoids undefined
            // "Publishing changes from within view updates" behaviour.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.loadingSpecies = nil
                self.library = decoded
                self.revision &+= 1
            }
        }
    }
}

@MainActor
final class HaloPetDebugState: ObservableObject {
    static let shared = HaloPetDebugState()
    @Published var forcedMotion: HaloCompanionMotion?
    @Published var selectedAnimation: HaloPetAnimation = .sittingIdle
    @Published var previewFrame = 0
    private var playTask: Task<Void, Never>?

    func force(_ motion: HaloCompanionMotion?) {
        playTask?.cancel(); playTask = nil; forcedMotion = motion
    }

    func playAll() {
        playTask?.cancel()
        playTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let motions: [HaloCompanionMotion] = [
                .entering, .idle, .walk, .look, .greet, .playful, .snack, .groom,
                .coffee, .working, .tired, .sleep, .stretch, .umbrella,
                .peekEyes, .peek, .peekLeft, .peekRight, .tail, .leaving
            ]
            for motion in motions {
                guard !Task.isCancelled else { return }
                self.forcedMotion = motion
                try? await Task.sleep(nanoseconds: 1_800_000_000)
            }
            if !Task.isCancelled { self.forcedMotion = nil }
        }
    }
}

private struct HaloPetPlaybackSelection {
    let animation: HaloPetAnimation
    let localTime: TimeInterval
    let mirror: Bool
}

/// Manifest-driven renderer for halo-pets-v2. It preserves source alpha, caches the selected species,
/// supports one-shot -> loop chains, cursor-selected gaze frames, notch-specific animations and mirrored
/// locomotion while keeping the legacy HaloCompanionMotion API intact for the EI engine.
struct HaloCompanionSprite: View {
    let kind: EIPetKind
    let style: EIPetVisualStyle
    var size: CGFloat
    var primary: Color
    var accent: Color
    var motion: HaloCompanionMotion = .idle
    var facingRight = true

    // Legacy vector/pixel options remain for call-site compatibility; V2 illustrated art ignores them.
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
    @State private var hoverBegan: Date?

    private var resolvedMotion: HaloCompanionMotion { debug.forcedMotion ?? motion }

    var body: some View {
        Group {
            if resolvedMotion == .hidden {
                Color.clear
            } else if let library = assets.library(for: kind) {
                TimelineView(.animation(minimumInterval: reduceMotion ? 0.20 : 1.0 / 30.0, paused: false)) { timeline in
                    let elapsed = max(0, timeline.date.timeIntervalSince(animationEpoch))
                    let selection = playbackSelection(elapsed: elapsed, library: library)
                    if let clip = library.clip(selection.animation),
                       let frame = frame(for: clip, localTime: selection.localTime, at: timeline.date) {
                        sprite(frame, animation: selection.animation, mirror: selection.mirror)
                    }
                }
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size * 0.92)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let point):
                hoverPoint = point
                if hoverBegan == nil { hoverBegan = Date() }
            case .ended:
                hoverPoint = nil
                hoverBegan = nil
            }
        }
        .task(id: kind.rawValue) { assets.load(kind) }
        .onAppear { animationEpoch = Date() }
        .onChange(of: resolvedMotion) { _ in animationEpoch = Date() }
        .onChange(of: facingRight) { _ in animationEpoch = Date() }
        .accessibilityLabel("\(kind.rawValue) companion")
    }

    private func playbackSelection(elapsed: TimeInterval, library: HaloPetV2Library) -> HaloPetPlaybackSelection {
        func simple(_ animation: HaloPetAnimation, mirror: Bool = false) -> HaloPetPlaybackSelection {
            HaloPetPlaybackSelection(animation: animation, localTime: elapsed, mirror: mirror)
        }
        func chained(_ first: HaloPetAnimation, _ second: HaloPetAnimation, mirror: Bool = false) -> HaloPetPlaybackSelection {
            let firstDuration = library.clip(first)?.duration ?? 1.2
            return elapsed < firstDuration
                ? HaloPetPlaybackSelection(animation: first, localTime: elapsed, mirror: mirror)
                : HaloPetPlaybackSelection(animation: second, localTime: elapsed - firstDuration, mirror: mirror)
        }

        switch resolvedMotion {
        case .hidden: return simple(.sittingIdle)
        case .idle: return simple(.sittingIdle)
        case .walk: return simple(.walkRight, mirror: !facingRight)
        case .look: return cursorAware(elapsed: elapsed) ? simple(.cursorTracking) : simple(.lookAround)
        case .observe, .curious: return cursorAware(elapsed: elapsed) ? simple(.cursorTracking) : simple(.lookAround)
        case .greet: return simple(.sayHi)
        case .celebrate, .dance: return simple(.celebrate)
        case .sleep: return chained(.settleToSleep, .sleepLoop)
        case .resting: return simple(.headRestOnLedge)
        case .snack: return simple(.eatSnack)
        case .stretch: return simple(.wakeToStretch)
        case .groom: return simple(.groomScratch)
        case .playful: return simple(.playWithBall)
        case .affectionate: return simple(.affection)
        case .tired: return simple(.yawn)
        case .excited, .happy: return simple(.happyExcited)
        case .paw:
            return simple(.pawAtCursor)
        case .tail: return simple(.tailReveal)
        case .coffee:
            return facingRight
                ? chained(.enterLeftToCoffee, .coffeeSipLoop)
                : chained(.enterRightToCoffee, .coffeeSipLoop)
        case .working: return simple(.tinyLaptopWorking)
        case .umbrella: return simple(.umbrellaIdle)
        case .entering: return chained(.climbOntoLedge, .sittingIdle)
        case .leaving: return simple(.dropBehindLedge)
        case .peekEyes: return simple(.eyesPeekUp)
        case .peekEars: return simple(.headPeekUp)
        case .peek: return simple(.pawsOnLedge)
        case .peekLeft: return simple(.peekFromLeft)
        case .peekRight: return simple(.peekFromRight)
        }
    }

    private func cursorAware(elapsed: TimeInterval) -> Bool {
        guard hoverPoint != nil else { return false }
        if let began = hoverBegan {
            let linger = Date().timeIntervalSince(began)
            // The actual paw action is exposed by the EI click/hover reaction; the renderer keeps
            // tracking continuously here so gaze does not oscillate between two animations.
            return linger >= 0 || elapsed >= 0
        }
        return true
    }

    private func frame(for clip: HaloPetAnimationClip, localTime: TimeInterval, at date: Date) -> CGImage? {
        guard !clip.frames.isEmpty else { return nil }
        if reduceMotion { return clip.frames.first }

        if clip.frameSelectedByCursor {
            let index = cursorTrackingIndex()
            return clip.frames[min(max(0, index), clip.frames.count - 1)]
        }

        let rawPlayback = Int(floor(max(0, localTime) * clip.fps))
        let playbackFrame: Int
        if clip.loops {
            playbackFrame = rawPlayback % max(1, clip.playbackFrames)
        } else {
            playbackFrame = min(max(0, clip.playbackFrames - 1), rawPlayback)
        }
        return clip.frames[clip.keyframe(forPlaybackFrame: playbackFrame)]
    }

    private func cursorTrackingIndex() -> Int {
        guard let point = hoverPoint else { return 4 }
        let normalized = min(max(point.x / max(1, size), 0), 1)
        return min(7, max(0, Int((normalized * 7).rounded())))
    }

    private func sprite(_ image: CGImage, animation: HaloPetAnimation, mirror: Bool) -> some View {
        Image(decorative: image, scale: 1, orientation: .up)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .scaleEffect(x: mirror ? -1 : 1, y: 1, anchor: .center)
            // Notch interaction sheets already contain the authored body reveal. Do not crop them
            // a second time here: the real physical-notch host supplies the hardware occlusion mask.
            .shadow(color: Color.black.opacity(shadowOpacity(for: animation)), radius: max(1, size * 0.014), y: max(1, size * 0.008))
            .compositingGroup()
    }

    private func shadowOpacity(for animation: HaloPetAnimation) -> Double {
        switch animation {
        case .sleepLoop, .sleepingAtLaptop, .settleToSleep: return 0.08
        default: return 0.14
        }
    }
}

#if DEBUG
@MainActor
struct HaloPetDebugPanel: View {
    @ObservedObject private var settings = EISettingsStore.shared
    @ObservedObject private var debug = HaloPetDebugState.shared
    @ObservedObject private var assets = HaloPetAssetStore.shared

    var body: some View {
        DisclosureGroup("Pet Debug V2") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Pet", selection: $settings.settings.petKind) {
                    ForEach(EIPetKind.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                HStack {
                    Button("Idle") { debug.force(.idle) }
                    Button("Walk") { debug.force(.walk) }
                    Button("Sleep") { debug.force(.sleep) }
                    Button("Play") { debug.force(.playful) }
                    Button("Coffee") { debug.force(.coffee) }
                    Button("Work") { debug.force(.working) }
                }
                .font(.caption2)
                HStack {
                    Button("Peek") { debug.force(.peek) }
                    Button("Wave") { debug.force(.greet) }
                    Button("Rain") { debug.force(.umbrella) }
                    Button("Play All") { debug.playAll() }
                    Button("Release") { debug.force(nil) }
                }
                .font(.caption2)

                if let library = assets.library(for: settings.settings.petKind) {
                    Text("halo-pets-v2 · \(library.species) · \(library.clips.count) animations")
                        .font(.caption2).foregroundStyle(.secondary)
                    Picker("Animation", selection: $debug.selectedAnimation) {
                        ForEach(HaloPetAnimation.allCases) { Text($0.displayName).tag($0) }
                    }
                    Slider(value: Binding(get: { Double(debug.previewFrame) }, set: { debug.previewFrame = Int($0.rounded()) }), in: 0...7, step: 1)
                    if let clip = library.clip(debug.selectedAnimation), !clip.frames.isEmpty {
                        let index = min(debug.previewFrame, clip.frames.count - 1)
                        Image(decorative: clip.frames[index], scale: 1, orientation: .up)
                            .resizable().interpolation(.high).scaledToFit().frame(height: 86)
                        Text("8 key poses · playback \(clip.playbackFrames) · \(clip.loops ? "loop" : "one-shot")")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Loading V2 pet library…").font(.caption2).foregroundStyle(.secondary)
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
