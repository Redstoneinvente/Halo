from pathlib import Path
import re

sprite = Path('Halo/Views/CompanionSprite.swift')
text = sprite.read_text()
start = text.index('// MARK: - Canonical EI pet animation atlas')
end = text.index('// MARK: - Premium plant renderer')

replacement = r'''// MARK: - Canonical EI pet animation system (V2)

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

private struct HaloPetManifest: Decodable, Sendable {
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

private struct HaloPetAnimationClip: @unchecked Sendable {
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
            let rows = max(1, definitions.map(\.row).max().map { $0 + 1 } ?? 1)
            let columns = max(1, manifest.columns)

            for definition in definitions {
                guard let animation = HaloPetAnimation(rawValue: definition.id) else { continue }
                var frames: [CGImage] = []
                frames.reserveCapacity(manifest.generatedKeyframesPerAnimation)
                for column in 0..<manifest.generatedKeyframesPerAnimation {
                    // Normalized cell boundaries keep slicing robust even if a future export is not
                    // exactly 200 px per cell. Atlas rows are authored top-to-bottom and CGImage
                    // cropping here uses the same top-left raster convention.
                    let nx0 = CGFloat(column) / CGFloat(columns)
                    let nx1 = CGFloat(column + 1) / CGFloat(columns)
                    let ny0 = CGFloat(definition.row) / CGFloat(rows)
                    let ny1 = CGFloat(definition.row + 1) / CGFloat(rows)
                    let x0 = Int((nx0 * CGFloat(image.width)).rounded(.down))
                    let x1 = Int((nx1 * CGFloat(image.width)).rounded(.down))
                    let y0 = Int((ny0 * CGFloat(image.height)).rounded(.down))
                    let y1 = Int((ny1 * CGFloat(image.height)).rounded(.down))
                    let rect = CGRect(x: x0, y: y0, width: max(1, x1 - x0), height: max(1, y1 - y0))
                    guard let frame = image.cropping(to: rect) else { return nil }
                    frames.append(frame)
                }
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
        library?.species == kind.rawValue ? library : nil
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
            self.loadingSpecies = nil
            self.library = decoded
            self.revision &+= 1
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
            .mask(alignment: notchMaskAlignment(for: animation)) {
                Rectangle()
                    .frame(width: size, height: size * 0.92 * notchRevealAmount(for: animation))
            }
            .shadow(color: Color.black.opacity(shadowOpacity(for: animation)), radius: max(1, size * 0.014), y: max(1, size * 0.008))
    }

    private func notchMaskAlignment(for animation: HaloPetAnimation) -> Alignment {
        switch animation {
        case .peekFromLeft: return .leading
        case .peekFromRight: return .trailing
        default: return .bottom
        }
    }

    private func notchRevealAmount(for animation: HaloPetAnimation) -> CGFloat {
        // V2 notch sheets already encode the partial-body composition. Clipping remains here so the
        // sprite can sit against Halo's real notch boundary without drawing a fake ledge.
        switch animation {
        case .eyesPeekUp: return 0.34
        case .headPeekUp: return 0.52
        case .pawsOnLedge: return 0.72
        case .tailReveal: return 0.58
        default: return 1
        }
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


'''

sprite.write_text(text[:start] + replacement + text[end:])

# Package halo-pets-v2 as one folder resource so duplicate atlas filenames preserve species subdirectories.
pbx = Path('Halo.xcodeproj/project.pbxproj')
p = pbx.read_text()
folder_ref = 'F84A0AB03055599200E8B51E'
folder_build = 'F84A0AB13055599200E8B51E'

if folder_ref not in p:
    p = p.replace('/* Begin PBXBuildFile section */', '/* Begin PBXBuildFile section */\n\t\t' + folder_build + ' /* halo-pets-v2 in Resources */ = {isa = PBXBuildFile; fileRef = ' + folder_ref + ' /* halo-pets-v2 */; };')
    p = p.replace('/* End PBXFileReference section */', '\t\t' + folder_ref + ' /* halo-pets-v2 */ = {isa = PBXFileReference; lastKnownFileType = folder; path = "Halo/Halo Icons/Pets/halo-pets-v2"; sourceTree = SOURCE_ROOT; };\n/* End PBXFileReference section */')

# Remove individually copied V2 build-file entries from the Resources phase only; those flatten same-named files.
for bid in [
    'F84A0A9F3055599200E8B51E','F84A0AA03055599200E8B51E','F84A0AA13055599200E8B51E',
    'F84A0AA23055599200E8B51E','F84A0AA33055599200E8B51E','F84A0AA43055599200E8B51E',
    'F84A0AA53055599200E8B51E','F84A0AA63055599200E8B51E','F84A0AA73055599200E8B51E',
    'F84A0AA83055599200E8B51E','F84A0AA93055599200E8B51E','F84A0AAA3055599200E8B51E',
    'F84A0AAB3055599200E8B51E','F84A0AAC3055599200E8B51E','F84A0AAD3055599200E8B51E',
    'F84A0AAE3055599200E8B51E','F84A0AAF3055599200E8B51E'
]:
    # Only remove resource-phase list lines, leave PBXBuildFile declarations alone for Xcode navigator stability.
    p = re.sub(r'^\s*' + bid + r' /\* .*? in Resources \*/,\n', '', p, flags=re.M)

resource_marker = '\t\t\tfiles = (\n'
resource_phase = p.index('/* Begin PBXResourcesBuildPhase section */')
files_pos = p.index(resource_marker, resource_phase) + len(resource_marker)
entry = '\t\t\t\t' + folder_build + ' /* halo-pets-v2 in Resources */,\n'
if entry not in p:
    p = p[:files_pos] + entry + p[files_pos:]

pbx.write_text(p)
print('Applied halo-pets-v2 renderer and folder-resource packaging')
