import SwiftUI
import AppKit
import ImageIO
import QuartzCore
import Combine

struct GrainOverlay: View {
    let options: GrainOptions
    private static let texture: CGImage? = {
        var state: UInt32 = 0x48414c4f
        let bytes: [UInt8] = (0..<(128 * 128)).map { _ in
            state = state &* 1664525 &+ 1013904223
            return UInt8(truncatingIfNeeded: state >> 24)
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: 128, height: 128, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: 128,
                       space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }()
    var body: some View {
        if options.enabled {
            ZStack {
                Color(red: 1, green: 0.72, blue: 0.4).opacity(options.warmth * 0.12)
                if let texture = Self.texture {
                    Image(nsImage: NSImage(cgImage: texture, size: CGSize(width: 128 * options.size, height: 128 * options.size)))
                        .resizable(resizingMode: .tile).interpolation(.none)
                        .opacity(options.amount).blendMode(.softLight)
                }
            }.allowsHitTesting(false).accessibilityHidden(true)
        }
    }
}

struct SideDecorationView: View {
    let options: SideDecoration
    let playing: Bool
    let lowPower: Bool
    var maximumHeight: CGFloat = .infinity
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if options.isVisible(playing: playing) {
            Group {
                if options.kind == .symbol {
                    Image(systemName: options.symbol).resizable().scaledToFit().foregroundStyle(options.color.color)
                } else {
                    AnimatedSideAsset(path: options.assetPath, animate: !reduceMotion && !lowPower)
                }
            }.frame(width: min(options.size, maximumHeight), height: min(options.size, maximumHeight))
                .accessibilityLabel(options.kind == .symbol ? options.symbol : "Custom notch image")
        }
    }
}

/// Decode once per selected file; Core Animation plays cached frames without SwiftUI ticks.
struct AnimatedSideAsset: NSViewRepresentable {
    let path: String
    let animate: Bool
    final class AssetView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
    final class Coordinator {
        var path = ""
        var animate = false
        var frames: [CGImage] = []
        var durations: [Double] = []
        var task: Task<Void, Never>?
        func display(in view: NSView) {
            guard let layer = view.layer else { return }
            CATransaction.begin(); CATransaction.setDisableActions(true)
            layer.removeAnimation(forKey: "gif"); layer.contents = frames.first
            CATransaction.commit()
            guard animate, frames.count > 1 else { return }
            let total = durations.reduce(0, +)
            var elapsed = 0.0
            let times = durations.map { duration -> NSNumber in
                defer { elapsed += duration }; return NSNumber(value: elapsed / total)
            }
            let animation = CAKeyframeAnimation(keyPath: "contents")
            animation.values = frames; animation.keyTimes = times
            animation.calculationMode = .discrete; animation.duration = total; animation.repeatCount = .infinity
            layer.add(animation, forKey: "gif")
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> AssetView {
        let view = AssetView(); view.wantsLayer = true
        view.layer?.contentsGravity = .resizeAspect
        return view
    }
    func updateNSView(_ view: AssetView, context: Context) {
        let state = context.coordinator
        let changedAnimation = state.animate != animate
        state.animate = animate
        guard state.path != path else { if changedAnimation { state.display(in: view) }; return }
        state.path = path; state.task?.cancel(); state.frames = []; state.durations = []; state.display(in: view)
        let currentPath = path
        state.task = Task { @MainActor [weak state, weak view] in
            let decoded = await Task.detached(priority: .utility) { SideAssetDecoder.read(currentPath) }.value
            guard !Task.isCancelled, let state, let view, state.path == currentPath else { return }
            state.frames = decoded.frames; state.durations = decoded.durations; state.display(in: view)
        }
    }
    static func dismantleNSView(_ view: AssetView, coordinator: Coordinator) {
        coordinator.task?.cancel(); view.layer?.removeAllAnimations(); view.layer?.contents = nil
    }
}
private enum SideAssetDecoder {
    struct Frames { var frames: [CGImage] = []; var durations: [Double] = [] }
    static func read(_ path: String) -> Frames {
        let url = URL(fileURLWithPath: path)
        guard !path.isEmpty, let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 10_000_000,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return Frames() }
        let count = CGImageSourceGetCount(source)
        guard count > 0, count <= 120 else { return Frames() }
        var result = Frames()
        for index in 0..<count {
            guard let frame = CGImageSourceCreateThumbnailAtIndex(source, index, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 128,
                kCGImageSourceShouldCacheImmediately: true
            ] as CFDictionary) else { return Frames() }
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
            result.frames.append(frame); result.durations.append(delay.isFinite ? min(10, max(1.0 / 30, delay)) : 0.1)
        }
        return result
    }
}

// MARK: - Notch Ambient
// Decorative-only idle-notch system. This deliberately does not expose data widgets or
// functional controls: the physical/simulated notch is treated as part of the artwork.

enum NotchAmbientCategory: String, Codable, CaseIterable, Identifiable {
    case minimal = "Minimal"
    case hanging = "Hanging"
    case nature = "Nature"
    case space = "Space / Sci-Fi"
    case water = "Water"
    case energy = "Fire / Energy"
    case architecture = "Architecture"
    case retro = "Retro / Technology"
    case seasonal = "Seasonal"
    var id: String { rawValue }
}

enum NotchAmbientDecorationKind: String, Codable, CaseIterable, Identifiable {
    case edgeGlow = "Edge Glow"
    case halo = "Halo"
    case underline = "Underline"
    case shadowDepth = "Shadow / Depth"
    case fairyLights = "Fairy Lights"
    case hangingStars = "Hanging Stars / Moons"
    case christmasOrnaments = "Christmas Ornaments"
    case icicles = "Icicles"
    case vines = "Vines"
    case moss = "Grass / Moss"
    case treeBranch = "Tree Branch"
    case flowers = "Flowers"
    case clouds = "Clouds"
    case rain = "Rain"
    case snow = "Snow"
    case blackHole = "Black Hole"
    case portal = "Portal"
    case reactor = "Reactor"
    case spaceship = "Spaceship"
    case ufo = "UFO"
    case orbit = "Orbit"
    case aquarium = "Aquarium"
    case waterfall = "Waterfall"
    case waterSurface = "Water Surface"
    case fireplace = "Fireplace"
    case ember = "Ember"
    case plasma = "Plasma"
    case electricity = "Electricity"
    case tinyBuilding = "Tiny Building"
    case trainTunnel = "Train Tunnel"
    case bridge = "Bridge"
    case balcony = "Balcony"
    case crt = "CRT"
    case cyberpunk = "Cyberpunk"
    case circuit = "Circuit Board"
    case dataRain = "Matrix / Data Rain"
    case terminalCursor = "Terminal Cursor"

    var id: String { rawValue }

    var category: NotchAmbientCategory {
        switch self {
        case .edgeGlow, .halo, .underline, .shadowDepth: return .minimal
        case .fairyLights, .hangingStars, .christmasOrnaments, .icicles: return .hanging
        case .vines, .moss, .treeBranch, .flowers, .clouds, .rain, .snow: return .nature
        case .blackHole, .portal, .reactor, .spaceship, .ufo, .orbit: return .space
        case .aquarium, .waterfall, .waterSurface: return .water
        case .fireplace, .ember, .plasma, .electricity: return .energy
        case .tinyBuilding, .trainTunnel, .bridge, .balcony: return .architecture
        case .crt, .cyberpunk, .circuit, .dataRain, .terminalCursor: return .retro
        }
    }

    var symbol: String {
        switch self {
        case .edgeGlow: return "capsule.bottomhalf.filled"
        case .halo: return "circle.dotted.circle"
        case .underline: return "minus"
        case .shadowDepth: return "square.3.layers.3d.down.right"
        case .fairyLights: return "lightbulb.2"
        case .hangingStars: return "sparkles"
        case .christmasOrnaments: return "circle.grid.cross"
        case .icicles: return "triangle.fill"
        case .vines: return "leaf"
        case .moss: return "camera.macro"
        case .treeBranch: return "tree"
        case .flowers: return "camera.macro.circle"
        case .clouds: return "cloud"
        case .rain: return "cloud.rain"
        case .snow: return "snowflake"
        case .blackHole: return "circle.circle.fill"
        case .portal: return "circle.hexagongrid"
        case .reactor: return "atom"
        case .spaceship: return "airplane"
        case .ufo: return "lightspectrum.horizontal"
        case .orbit: return "circle.hexagonpath"
        case .aquarium: return "water.waves"
        case .waterfall: return "water.waves.and.arrow.down"
        case .waterSurface: return "wave.3.forward"
        case .fireplace: return "flame"
        case .ember: return "sparkles"
        case .plasma: return "waveform.path.ecg"
        case .electricity: return "bolt"
        case .tinyBuilding: return "building.2"
        case .trainTunnel: return "tram"
        case .bridge: return "point.bottomleft.forward.to.point.topright.scurvepath"
        case .balcony: return "rectangle.split.3x1"
        case .crt: return "display"
        case .cyberpunk: return "lightspectrum.horizontal"
        case .circuit: return "cpu"
        case .dataRain: return "textformat.123"
        case .terminalCursor: return "terminal"
        }
    }
}

enum NotchAmbientActivityLevel: String, Codable, CaseIterable, Identifiable {
    case staticMode = "Static"
    case calm = "Calm"
    case balanced = "Balanced"
    case lively = "Lively"
    var id: String { rawValue }
    var phaseMultiplier: Double {
        switch self { case .staticMode: return 0; case .calm: return 0.32; case .balanced: return 0.7; case .lively: return 1.0 }
    }
    var preferredFPS: Double {
        switch self { case .staticMode: return 0; case .calm: return 12; case .balanced: return 20; case .lively: return 30 }
    }
}

enum NotchAmbientAudioReaction: String, Codable, CaseIterable, Identifiable {
    case off = "Off"
    case subtle = "Subtle"
    case balanced = "Balanced"
    case strong = "Strong"
    var id: String { rawValue }
    var strength: Double {
        switch self { case .off: return 0; case .subtle: return 0.18; case .balanced: return 0.42; case .strong: return 0.78 }
    }
}

enum NotchAmbientCursorReaction: String, Codable, CaseIterable, Identifiable {
    case off = "Off"
    case illuminate = "Illuminate"
    case repel = "Repel"
    case attract = "Attract"
    case ripple = "Ripple"
    case bend = "Bend"
    var id: String { rawValue }
}

enum NotchAmbientColorSource: String, Codable, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case custom = "Custom"
    case wallpaper = "Wallpaper-derived"
    case albumArt = "Album-art-derived"
    case systemAccent = "System Accent"
    case timeBased = "Time-based"
    var id: String { rawValue }
}

enum NotchAmbientSymmetry: String, Codable, CaseIterable, Identifiable {
    case symmetric = "Symmetric"
    case leftWeighted = "Left Weighted"
    case rightWeighted = "Right Weighted"
    case asymmetric = "Asymmetric"
    case randomOrganic = "Random Organic"
    var id: String { rawValue }
}

enum NotchAmbientPlacement: String, Codable, CaseIterable, Identifiable {
    case above = "Above"
    case below = "Below"
    case left = "Left"
    case right = "Right"
    case around = "Around"
    case behind = "Behind"
    case edgeAttached = "Edge Attached"
    var id: String { rawValue }
}

enum NotchAmbientSeasonMode: String, Codable, CaseIterable, Identifiable {
    case automatic = "Follow Season Automatically"
    case manual = "Manual"
    case off = "Off"
    var id: String { rawValue }
}

enum NotchAmbientSeason: String, Codable, CaseIterable, Identifiable {
    case winter = "Winter"
    case spring = "Spring"
    case summer = "Summer"
    case autumn = "Autumn"
    case halloween = "Halloween"
    case christmas = "Christmas"
    case newYear = "New Year"
    var id: String { rawValue }
}

enum NotchAmbientHemisphere: String, Codable, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case northern = "Northern"
    case southern = "Southern"
    var id: String { rawValue }
}

enum NotchAmbientRotationMode: String, Codable, CaseIterable, Identifiable {
    case off = "Off"
    case everySession = "Every Session"
    case everyHour = "Every Hour"
    case daily = "Daily"
    case timeOfDay = "Time of Day"
    case random = "Random"
    var id: String { rawValue }
}

enum NotchAmbientTransitionStyle: String, Codable, CaseIterable, Identifiable {
    case fade = "Fade"
    case retract = "Retract"
    case dissolve = "Dissolve"
    case shrink = "Shrink"
    case slideBehind = "Slide Behind Notch"
    case particleCollapse = "Particle Collapse"
    var id: String { rawValue }
}

enum NotchAmbientBulbShape: String, Codable, CaseIterable, Identifiable {
    case round = "Round"
    case teardrop = "Teardrop"
    case capsule = "Capsule"
    case diamond = "Diamond"
    var id: String { rawValue }
}

enum NotchAmbientFoliageStyle: String, Codable, CaseIterable, Identifiable {
    case fine = "Fine"
    case broad = "Broad"
    case fern = "Fern"
    case floral = "Floral"
    var id: String { rawValue }
}

enum NotchAmbientPortalStyle: String, Codable, CaseIterable, Identifiable {
    case space = "Space"
    case nebula = "Nebula"
    case cyber = "Cyber"
    case fire = "Fire"
    case ice = "Ice"
    case void = "Void"
    case fantasy = "Fantasy"
    var id: String { rawValue }
}

enum NotchAmbientUnderlineStyle: String, Codable, CaseIterable, Identifiable {
    case solid = "Solid"
    case centerOrb = "Center Orb"
    case diamond = "Diamond"
    case dashes = "Dashes"
    var id: String { rawValue }
}

// Future Decoration Studio / pack contract. Built-ins use procedural renderers today,
// but a user-created pack can map the same depth/layer primitives without changing runtime ownership.
enum NotchAmbientLayerKind: String, Codable, CaseIterable {
    case shape, image, animatedImage, video, particleEmitter, glow, line, gradient, shader, procedural
}
enum NotchAmbientDepth: String, Codable, CaseIterable {
    case background, behindNotch, notchEdge, foreground, particles, glow
}
enum NotchAmbientBlend: String, Codable, CaseIterable { case normal, screen, plusLighter, multiply, overlay }

struct NotchAmbientLayerDescriptor: Codable, Equatable, Identifiable {
    var id = UUID()
    var kind: NotchAmbientLayerKind = .procedural
    var depth: NotchAmbientDepth = .foreground
    var role = ""
    var anchorX = 0.5
    var anchorY = 0.0
    var offsetX = 0.0
    var offsetY = 0.0
    var scale = 1.0
    var rotation = 0.0
    var opacity = 1.0
    var blend: NotchAmbientBlend = .normal
    var maskRole: String?
    var animationRole: String?
    var reactionRole: String?
}

struct NotchAmbientDecorationManifest: Codable, Equatable, Identifiable {
    var version = 1
    var id: String
    var name: String
    var category: NotchAmbientCategory
    var renderer: String
    var assets: [String] = []
    var layers: [NotchAmbientLayerDescriptor] = []
    var previewAsset: String?
}

private enum NotchAmbientControl: Hashable {
    case thickness, softness, falloff, pulse, count, spacing, length, density, bloom, flicker, sway
    case wind, distortion, particles, scanlines, glitch, electricalFrequency, splash, accumulation
    case bulbShape, foliageStyle, portalStyle, underlineStyle, cursor, audio, symmetry, placement
}

extension NotchAmbientDecorationKind {
    fileprivate var controls: Set<NotchAmbientControl> {
        switch self {
        case .edgeGlow: return [.thickness, .softness, .falloff, .pulse, .audio, .cursor, .symmetry, .placement]
        case .halo: return [.softness, .falloff, .pulse, .audio, .cursor, .placement]
        case .underline: return [.thickness, .softness, .pulse, .underlineStyle, .audio, .cursor]
        case .shadowDepth: return [.thickness, .softness, .falloff]
        case .fairyLights: return [.count, .spacing, .length, .bloom, .flicker, .sway, .bulbShape, .audio, .cursor, .symmetry]
        case .hangingStars: return [.count, .spacing, .length, .bloom, .sway, .cursor, .symmetry]
        case .christmasOrnaments: return [.count, .spacing, .length, .bloom, .sway, .cursor, .symmetry]
        case .icicles: return [.count, .spacing, .length, .density, .bloom, .symmetry]
        case .vines, .moss, .treeBranch, .flowers: return [.count, .length, .density, .sway, .foliageStyle, .cursor, .symmetry, .placement]
        case .clouds: return [.count, .density, .softness, .wind, .symmetry, .placement]
        case .rain: return [.count, .density, .length, .wind, .splash, .placement]
        case .snow: return [.count, .density, .wind, .accumulation, .placement]
        case .blackHole: return [.softness, .density, .distortion, .particles, .audio, .cursor, .placement]
        case .portal: return [.softness, .density, .particles, .portalStyle, .audio, .cursor, .placement]
        case .reactor: return [.thickness, .softness, .pulse, .audio, .cursor, .symmetry, .placement]
        case .spaceship, .ufo: return [.softness, .pulse, .audio, .cursor, .symmetry]
        case .orbit: return [.count, .density, .particles, .audio, .cursor, .placement]
        case .aquarium: return [.count, .density, .sway, .particles, .cursor, .placement]
        case .waterfall: return [.density, .length, .softness, .splash, .audio, .cursor, .placement]
        case .waterSurface: return [.softness, .pulse, .audio, .cursor, .placement]
        case .fireplace: return [.density, .softness, .flicker, .audio, .placement]
        case .ember: return [.count, .density, .particles, .audio, .cursor, .placement]
        case .plasma: return [.thickness, .softness, .pulse, .audio, .cursor, .placement]
        case .electricity: return [.thickness, .softness, .electricalFrequency, .audio, .placement]
        case .tinyBuilding, .trainTunnel, .bridge, .balcony: return [.softness, .pulse, .symmetry]
        case .crt: return [.softness, .scanlines, .glitch, .pulse]
        case .cyberpunk: return [.thickness, .softness, .pulse, .audio, .cursor, .symmetry]
        case .circuit: return [.thickness, .density, .pulse, .audio, .cursor, .symmetry]
        case .dataRain: return [.count, .density, .length, .glitch, .placement]
        case .terminalCursor: return [.pulse, .glitch, .placement]
        }
    }
}

struct NotchAmbientSettings: Codable, Equatable {
    var enabled = false
    var decoration: NotchAmbientDecorationKind = .edgeGlow
    var presetID = "apple-minimal"
    var activity: NotchAmbientActivityLevel = .calm
    var colorSource: NotchAmbientColorSource = .automatic
    var primaryColor = WidgetColor(red: 0.70, green: 0.84, blue: 1.0)
    var secondaryColor = WidgetColor(red: 0.45, green: 0.55, blue: 1.0)
    var tertiaryColor = WidgetColor(red: 0.84, green: 0.48, blue: 1.0)
    var intensity = 0.32
    var thickness = 2.0
    var softness = 8.0
    var falloff = 0.72
    var pulse = 0.16
    var speed = 0.28
    var count = 9
    var spacing = 1.0
    var length = 46.0
    var density = 0.48
    var bloom = 0.28
    var flicker = 0.08
    var sway = 0.25
    var wind = 0.10
    var distortion = 0.22
    var electricalFrequency = 0.08
    var splash = true
    var accumulation = true
    var scanlines = 0.18
    var glitch = 0.04
    var bulbShape: NotchAmbientBulbShape = .round
    var foliageStyle: NotchAmbientFoliageStyle = .fine
    var portalStyle: NotchAmbientPortalStyle = .nebula
    var underlineStyle: NotchAmbientUnderlineStyle = .solid
    var audioReaction: NotchAmbientAudioReaction = .off
    var cursorReaction: NotchAmbientCursorReaction = .off
    var reactionRadius = 150.0
    var reactionStrength = 0.22
    var reactionSmoothing = 0.72
    var symmetry: NotchAmbientSymmetry = .symmetric
    var placement: NotchAmbientPlacement = .edgeAttached
    var timeBasedAppearance = false
    var seasonMode: NotchAmbientSeasonMode = .off
    var manualSeason: NotchAmbientSeason = .winter
    var hemisphere: NotchAmbientHemisphere = .automatic
    var rotationMode: NotchAmbientRotationMode = .off
    var favoritePresetIDs: [String] = []
    var transition: NotchAmbientTransitionStyle = .fade
    var transitionDuration = 0.38
    var horizontalExtent = 150.0
    var verticalExtent = 150.0
    var lowPowerAdaptive = true
    var yieldToPersistentClosedContent = false
    var lensDistortion = false
    var seed: UInt64 = 0x48414C4F_A6B13D2F

    func normalized() -> NotchAmbientSettings {
        var v = self
        v.intensity = min(1, max(0, intensity))
        v.thickness = min(18, max(0.5, thickness))
        v.softness = min(36, max(0, softness))
        v.falloff = min(1, max(0, falloff))
        v.pulse = min(1, max(0, pulse))
        v.speed = min(3, max(0.02, speed))
        v.count = min(64, max(1, count))
        v.spacing = min(3, max(0.25, spacing))
        v.length = min(180, max(6, length))
        v.density = min(1, max(0, density))
        v.bloom = min(1, max(0, bloom))
        v.flicker = min(0.7, max(0, flicker))
        v.sway = min(1, max(0, sway))
        v.wind = min(1, max(-1, wind))
        v.distortion = min(1, max(0, distortion))
        v.electricalFrequency = min(1, max(0.01, electricalFrequency))
        v.scanlines = min(1, max(0, scanlines))
        v.glitch = min(0.5, max(0, glitch))
        v.reactionRadius = min(420, max(40, reactionRadius))
        v.reactionStrength = min(1, max(0, reactionStrength))
        v.reactionSmoothing = min(1, max(0, reactionSmoothing))
        v.transitionDuration = min(1.5, max(0.08, transitionDuration))
        v.horizontalExtent = min(280, max(80, horizontalExtent))
        v.verticalExtent = min(260, max(72, verticalExtent))
        return v
    }

    var resolvedHemisphere: NotchAmbientHemisphere {
        guard hemisphere == .automatic else { return hemisphere }
        let southernRegions: Set<String> = ["AU", "NZ", "ZA", "MU", "AR", "CL", "UY", "PY", "BO", "BW", "NA", "ZM", "ZW", "MZ", "MG"]
        if let region = Locale.current.region?.identifier, southernRegions.contains(region.uppercased()) { return .southern }
        return .northern
    }

    func resolvedSeason(at date: Date = Date()) -> NotchAmbientSeason? {
        switch seasonMode {
        case .off: return nil
        case .manual: return manualSeason
        case .automatic:
            let month = Calendar.autoupdatingCurrent.component(.month, from: date)
            let northern: NotchAmbientSeason
            switch month {
            case 3...5: northern = .spring
            case 6...8: northern = .summer
            case 9...11: northern = .autumn
            default: northern = .winter
            }
            guard resolvedHemisphere == .southern else { return northern }
            switch northern {
            case .winter: return .summer
            case .spring: return .autumn
            case .summer: return .winter
            case .autumn: return .spring
            default: return northern
            }
        }
    }
}

struct NotchAmbientPreset: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var settings: NotchAmbientSettings
    var builtIn: Bool = false
}

extension NotchAmbientPreset {
    static let builtIns: [NotchAmbientPreset] = {
        func make(_ id: String, _ name: String, _ kind: NotchAmbientDecorationKind,
                  _ primary: WidgetColor, _ secondary: WidgetColor,
                  configure: (inout NotchAmbientSettings) -> Void = { _ in }) -> NotchAmbientPreset {
            var s = NotchAmbientSettings()
            s.enabled = true; s.presetID = id; s.decoration = kind
            s.primaryColor = primary; s.secondaryColor = secondary; s.colorSource = .custom
            configure(&s)
            return NotchAmbientPreset(id: id, name: name, settings: s.normalized(), builtIn: true)
        }
        let blue = WidgetColor(red: 0.63, green: 0.79, blue: 1.0)
        let violet = WidgetColor(red: 0.65, green: 0.38, blue: 1.0)
        let cyan = WidgetColor(red: 0.22, green: 0.88, blue: 1.0)
        let green = WidgetColor(red: 0.31, green: 0.78, blue: 0.42)
        let warm = WidgetColor(red: 1.0, green: 0.62, blue: 0.24)
        let red = WidgetColor(red: 1.0, green: 0.25, blue: 0.20)
        return [
            make("apple-minimal", "Apple Minimal", .edgeGlow, WidgetColor(red: 0.82, green: 0.88, blue: 0.96), blue) { $0.intensity = 0.13; $0.thickness = 1; $0.softness = 5; $0.pulse = 0.04; $0.activity = .calm },
            make("soft-halo", "Soft Halo", .halo, blue, violet) { $0.intensity = 0.24; $0.softness = 16; $0.pulse = 0.10 },
            make("aurora", "Aurora", .edgeGlow, cyan, violet) { $0.intensity = 0.34; $0.softness = 13; $0.pulse = 0.14; $0.activity = .calm },
            make("fairy-lights", "Fairy Lights", .fairyLights, WidgetColor(red: 1.0, green: 0.78, blue: 0.42), WidgetColor(red: 1.0, green: 0.47, blue: 0.31)) { $0.count = 9; $0.length = 54; $0.bloom = 0.42; $0.sway = 0.24; $0.flicker = 0.06 },
            make("hanging-stars", "Hanging Stars", .hangingStars, WidgetColor(red: 0.88, green: 0.91, blue: 1.0), violet) { $0.count = 7; $0.length = 60; $0.sway = 0.16; $0.bloom = 0.32 },
            make("overgrown", "Overgrown", .vines, green, WidgetColor(red: 0.12, green: 0.42, blue: 0.20)) { $0.density = 0.72; $0.length = 84; $0.sway = 0.18; $0.symmetry = .randomOrganic },
            make("bonsai-edge", "Bonsai Edge", .treeBranch, WidgetColor(red: 0.43, green: 0.29, blue: 0.18), green) { $0.length = 110; $0.density = 0.52; $0.symmetry = .rightWeighted },
            make("rainy-notch", "Rainy Notch", .rain, blue, cyan) { $0.density = 0.42; $0.length = 34; $0.speed = 0.42; $0.wind = 0.08 },
            make("snowcap", "Snowcap", .snow, WidgetColor(red: 0.91, green: 0.96, blue: 1.0), blue) { $0.density = 0.32; $0.speed = 0.18; $0.accumulation = true },
            make("aquarium", "Aquarium", .aquarium, cyan, WidgetColor(red: 0.12, green: 0.48, blue: 0.72)) { $0.density = 0.42; $0.count = 6; $0.sway = 0.18 },
            make("waterfall", "Waterfall", .waterfall, cyan, blue) { $0.density = 0.52; $0.length = 100; $0.softness = 6 },
            make("black-hole", "Black Hole", .blackHole, warm, violet) { $0.intensity = 0.64; $0.density = 0.55; $0.softness = 13; $0.distortion = 0.42; $0.activity = .calm },
            make("nebula-portal", "Nebula Portal", .portal, violet, cyan) { $0.portalStyle = .nebula; $0.intensity = 0.54; $0.density = 0.46; $0.softness = 12 },
            make("reactor", "Reactor", .reactor, cyan, blue) { $0.intensity = 0.46; $0.thickness = 2; $0.pulse = 0.28 },
            make("orbit", "Orbit", .orbit, WidgetColor(red: 0.90, green: 0.93, blue: 1.0), violet) { $0.count = 5; $0.density = 0.35; $0.speed = 0.24 },
            make("spaceship", "Spaceship", .spaceship, WidgetColor(red: 0.62, green: 0.72, blue: 0.86), cyan) { $0.intensity = 0.34; $0.softness = 7 },
            make("cyberpunk", "Cyberpunk", .cyberpunk, WidgetColor(red: 1.0, green: 0.16, blue: 0.72), cyan) { $0.intensity = 0.48; $0.pulse = 0.28; $0.thickness = 1.5 },
            make("circuit", "Circuit", .circuit, green, cyan) { $0.density = 0.48; $0.thickness = 1.2; $0.pulse = 0.18 },
            make("crt", "CRT", .crt, WidgetColor(red: 0.32, green: 1.0, blue: 0.52), WidgetColor(red: 0.14, green: 0.54, blue: 0.28)) { $0.intensity = 0.22; $0.scanlines = 0.28; $0.glitch = 0.02 },
            make("ember", "Ember", .ember, warm, red) { $0.count = 12; $0.density = 0.38; $0.speed = 0.20 },
            make("electric", "Electric", .electricity, cyan, violet) { $0.intensity = 0.36; $0.electricalFrequency = 0.05; $0.thickness = 1.3 },
            make("tiny-city", "Tiny City", .tinyBuilding, WidgetColor(red: 0.72, green: 0.80, blue: 0.92), warm) { $0.intensity = 0.30; $0.timeBasedAppearance = true },
            make("train-tunnel", "Train Tunnel", .trainTunnel, WidgetColor(red: 0.56, green: 0.62, blue: 0.70), warm) { $0.activity = .calm; $0.speed = 0.16 }
        ]
    }()
}

@MainActor
final class NotchAmbientStore: ObservableObject {
    static let shared = NotchAmbientStore()
    private let settingsKey = "HaloNotchAmbient.v1"
    private let presetsKey = "HaloNotchAmbientSavedPresets.v1"
    private let sessionToken = UInt64.random(in: 0...UInt64.max)

    @Published var settings: NotchAmbientSettings { didSet { persistSettings() } }
    @Published var savedPresets: [NotchAmbientPreset] { didSet { persistPresets() } }

    private init() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(NotchAmbientSettings.self, from: data) {
            settings = decoded.normalized()
        } else { settings = NotchAmbientSettings() }
        if let data = UserDefaults.standard.data(forKey: presetsKey),
           let decoded = try? JSONDecoder().decode([NotchAmbientPreset].self, from: data) {
            savedPresets = decoded.map { var p = $0; p.builtIn = false; p.settings = p.settings.normalized(); return p }
        } else { savedPresets = [] }
    }

    var allPresets: [NotchAmbientPreset] { NotchAmbientPreset.builtIns + savedPresets }

    func update<T>(_ keyPath: WritableKeyPath<NotchAmbientSettings, T>, _ value: T) {
        var next = settings
        next[keyPath: keyPath] = value
        settings = next.normalized()
    }

    func apply(_ preset: NotchAmbientPreset) {
        let wasEnabled = settings.enabled
        let rotation = settings.rotationMode
        let favorites = settings.favoritePresetIDs
        let lowPower = settings.lowPowerAdaptive
        var next = preset.settings
        next.enabled = wasEnabled
        next.rotationMode = rotation
        next.favoritePresetIDs = favorites
        next.lowPowerAdaptive = lowPower
        next.presetID = preset.id
        settings = next.normalized()
    }

    func reset() {
        var value = NotchAmbientPreset.builtIns.first(where: { $0.id == "apple-minimal" })?.settings ?? NotchAmbientSettings()
        value.enabled = settings.enabled
        settings = value.normalized()
    }

    func randomize() {
        var next = settings
        next.seed = UInt64.random(in: 0...UInt64.max)
        next.intensity = Double.random(in: 0.18...0.72)
        next.density = Double.random(in: 0.22...0.72)
        next.count = Int.random(in: 5...16)
        next.speed = Double.random(in: 0.12...0.62)
        next.sway = Double.random(in: 0.08...0.42)
        next.presetID = "custom"
        settings = next.normalized()
    }

    @discardableResult func saveCurrent(named raw: String) -> NotchAmbientPreset {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "My Ambient \(savedPresets.count + 1)" : String(trimmed.prefix(80))
        var value = settings; value.presetID = UUID().uuidString
        let preset = NotchAmbientPreset(id: value.presetID, name: name, settings: value, builtIn: false)
        savedPresets.append(preset)
        settings = value
        return preset
    }

    func duplicateCurrent() {
        let sourceName = allPresets.first(where: { $0.id == settings.presetID })?.name ?? "Custom Ambient"
        _ = saveCurrent(named: sourceName + " Copy")
    }

    func removeSaved(_ id: String) { savedPresets.removeAll { $0.id == id } }

    func setFavorite(_ id: String, enabled: Bool) {
        var next = settings
        next.favoritePresetIDs.removeAll { $0 == id }
        if enabled { next.favoritePresetIDs.append(id) }
        settings = next
    }

    func effectiveSettings(at date: Date) -> NotchAmbientSettings {
        let base = settings.normalized()
        guard base.rotationMode != .off else { return base }
        let favorites = allPresets.filter { base.favoritePresetIDs.contains($0.id) }
        guard !favorites.isEmpty else { return base }
        let calendar = Calendar.autoupdatingCurrent
        let index: Int
        switch base.rotationMode {
        case .off: return base
        case .everySession:
            index = Int(sessionToken % UInt64(favorites.count))
        case .everyHour:
            let hour = Int(date.timeIntervalSince1970 / 3600)
            index = positiveIndex(hour ^ Int(truncatingIfNeeded: base.seed), count: favorites.count)
        case .daily:
            let ordinal = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
            index = positiveIndex(ordinal ^ Int(truncatingIfNeeded: base.seed), count: favorites.count)
        case .timeOfDay:
            let hour = calendar.component(.hour, from: date)
            let bucket = min(3, max(0, hour / 6))
            index = bucket % favorites.count
        case .random:
            let block = Int(date.timeIntervalSince1970 / 1800)
            index = positiveIndex(block &* 1103515245 &+ Int(truncatingIfNeeded: base.seed), count: favorites.count)
        }
        var rotated = favorites[index].settings.normalized()
        rotated.enabled = base.enabled
        rotated.rotationMode = base.rotationMode
        rotated.favoritePresetIDs = base.favoritePresetIDs
        rotated.lowPowerAdaptive = base.lowPowerAdaptive
        rotated.yieldToPersistentClosedContent = base.yieldToPersistentClosedContent
        return rotated
    }

    private func positiveIndex(_ raw: Int, count: Int) -> Int { ((raw % count) + count) % count }
    private func persistSettings() { if let data = try? JSONEncoder().encode(settings.normalized()) { UserDefaults.standard.set(data, forKey: settingsKey) } }
    private func persistPresets() { if let data = try? JSONEncoder().encode(savedPresets) { UserDefaults.standard.set(data, forKey: presetsKey) } }
}

private enum NotchAmbientWallpaperSampler {
    @MainActor static func sample(screenFrame: CGRect) -> Color? {
        guard let screen = NSScreen.screens.first(where: { $0.frame == screenFrame }) ?? NSScreen.main,
              let url = NSWorkspace.shared.desktopImageURL(for: screen),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 32,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard bitmap.pixelsWide > 0, bitmap.pixelsHigh > 0 else { return nil }
        var r = 0.0, g = 0.0, b = 0.0, n = 0.0
        for y in stride(from: 0, to: bitmap.pixelsHigh, by: max(1, bitmap.pixelsHigh / 8)) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: max(1, bitmap.pixelsWide / 8)) {
                guard let c = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                r += Double(c.redComponent); g += Double(c.greenComponent); b += Double(c.blueComponent); n += 1
            }
        }
        guard n > 0 else { return nil }
        return Color(red: r / n, green: g / n, blue: b / n)
    }
}

private enum NotchAmbientPaletteResolver {
    static func colors(settings: NotchAmbientSettings, album: [WidgetColor], wallpaper: Color?, date: Date) -> [Color] {
        switch settings.colorSource {
        case .custom: return [settings.primaryColor.color, settings.secondaryColor.color, settings.tertiaryColor.color]
        case .albumArt:
            let values = album.prefix(3).map(\.color)
            return values.isEmpty ? defaults(for: settings.decoration) : values + Array(repeating: values.last ?? .accentColor, count: max(0, 3 - values.count))
        case .systemAccent: return [.accentColor, .accentColor.opacity(0.72), .white.opacity(0.82)]
        case .wallpaper:
            guard let wallpaper else { return defaults(for: settings.decoration) }
            return [wallpaper, wallpaper.opacity(0.72), .white.opacity(0.72)]
        case .timeBased:
            let hour = Calendar.autoupdatingCurrent.component(.hour, from: date)
            if hour < 6 { return [Color(red: 0.28, green: 0.40, blue: 0.78), Color(red: 0.45, green: 0.26, blue: 0.72), .white.opacity(0.72)] }
            if hour < 12 { return [Color(red: 1.0, green: 0.66, blue: 0.36), Color(red: 0.46, green: 0.74, blue: 1.0), .white.opacity(0.82)] }
            if hour < 18 { return [Color(red: 0.34, green: 0.76, blue: 1.0), Color(red: 0.36, green: 0.88, blue: 0.76), .white.opacity(0.82)] }
            return [Color(red: 0.92, green: 0.44, blue: 0.50), Color(red: 0.46, green: 0.32, blue: 0.80), .white.opacity(0.76)]
        case .automatic:
            if settings.decoration == .portal {
                switch settings.portalStyle {
                case .space: return [Color(red:0.30,green:0.52,blue:1), Color(red:0.12,green:0.18,blue:0.48), .white]
                case .nebula: return [Color(red:0.68,green:0.30,blue:1), Color(red:0.20,green:0.82,blue:1), Color(red:1,green:0.34,blue:0.72)]
                case .cyber: return [Color(red:0.08,green:0.94,blue:1), Color(red:1,green:0.12,blue:0.74), .white]
                case .fire: return [Color(red:1,green:0.52,blue:0.12), Color(red:1,green:0.12,blue:0.06), Color.yellow]
                case .ice: return [Color(red:0.58,green:0.88,blue:1), Color(red:0.18,green:0.48,blue:1), .white]
                case .void: return [Color(red:0.34,green:0.20,blue:0.58), Color(red:0.08,green:0.06,blue:0.14), Color(red:0.72,green:0.58,blue:1)]
                case .fantasy: return [Color(red:0.36,green:1,blue:0.66), Color(red:0.76,green:0.32,blue:1), Color(red:1,green:0.78,blue:0.30)]
                }
            }
            return defaults(for: settings.decoration)
        }
    }

    private static func defaults(for kind: NotchAmbientDecorationKind) -> [Color] {
        switch kind.category {
        case .minimal: return [Color(red: 0.68, green: 0.82, blue: 1), Color(red: 0.50, green: 0.52, blue: 1), .white]
        case .hanging: return [Color(red: 1, green: 0.76, blue: 0.42), Color(red: 1, green: 0.42, blue: 0.35), Color(red: 0.50, green: 0.72, blue: 1)]
        case .nature: return [Color(red: 0.28, green: 0.72, blue: 0.36), Color(red: 0.12, green: 0.42, blue: 0.21), Color(red: 0.85, green: 0.58, blue: 0.64)]
        case .space: return [Color(red: 1, green: 0.55, blue: 0.20), Color(red: 0.56, green: 0.28, blue: 1), Color(red: 0.18, green: 0.84, blue: 1)]
        case .water: return [Color(red: 0.18, green: 0.78, blue: 1), Color(red: 0.10, green: 0.38, blue: 0.78), Color(red: 0.32, green: 1, blue: 0.88)]
        case .energy: return [Color(red: 1, green: 0.48, blue: 0.16), Color(red: 1, green: 0.18, blue: 0.12), Color(red: 0.24, green: 0.82, blue: 1)]
        case .architecture: return [Color(red: 0.62, green: 0.70, blue: 0.82), Color(red: 0.20, green: 0.24, blue: 0.32), Color(red: 1, green: 0.68, blue: 0.30)]
        case .retro: return [Color(red: 0.20, green: 1, blue: 0.55), Color(red: 1, green: 0.16, blue: 0.72), Color(red: 0.18, green: 0.80, blue: 1)]
        case .seasonal: return [.white, .accentColor, .green]
        }
    }
}

@MainActor
struct NotchAmbientOverlayView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var state: SurfaceState
    @ObservedObject var workspace: WorkspaceStore
    @ObservedObject private var ambient = NotchAmbientStore.shared
    @ObservedObject private var hudBridge = HaloHUDNotchBridge.shared
    @ObservedObject private var account = HaloAccountManager.shared
    @ObservedObject private var license = HaloLicenseManager.shared
    @ObservedObject private var media: MediaService
    @ObservedObject private var system: SystemService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var screenAwake = true
    @State private var wallpaperColor: Color?
    @State private var activityClock = Date()

    init(store: AppStore, state: SurfaceState, workspace: WorkspaceStore) {
        self.store = store; self.state = state; self.workspace = workspace
        _media = ObservedObject(wrappedValue: workspace.media)
        _system = ObservedObject(wrappedValue: workspace.system)
    }

    private var screenFrame: CGRect { state.screenFrame }
    private var layout: WorkspaceLayout { state.layoutOverride ?? workspace.effectiveLayout }
    private var closed: ClosedNotchOptions { layout.closedNotch ?? ClosedNotchOptions() }
    private var current: NotchAmbientSettings { ambient.effectiveSettings(at: activityClock).normalized() }
    private var activeHUD: Bool { hudBridge.presentation.map { $0.screenFrame == screenFrame } ?? false }
    private var activeActivity: Bool {
        workspace.activities.contains { ($0.progress.map { $0 < 1 } ?? false) || $0.created.addingTimeInterval(12) > activityClock }
    }
    private var mediaOwnsNotch: Bool {
        guard media.isPlaying else { return false }
        if layout.contextMusic?.enabled == true { return true }
        return [closed.left, closed.right].contains { $0 == .media || $0 == .visualizer }
    }
    private var timerOwnsNotch: Bool {
        guard store.deadline != nil || store.pausedSeconds > 0 else { return false }
        return closed.left == .timer || closed.right == .timer
    }
    private var filesOwnNotch: Bool {
        guard !store.pinnedFiles.isEmpty else { return false }
        return closed.left == .files || closed.right == .files
    }
    private var fileShelfOwnsNotch: Bool {
        guard !store.pinnedFiles.isEmpty else { return false }
        let leftOwnsFiles = closed.left == .files
        let rightOwnsFiles = closed.right == .files
        return leftOwnsFiles || rightOwnsFiles
    }
    private var mirrorOwnsNotch: Bool { closed.left == .mirror || closed.right == .mirror }
    private var powerOwnsNotch: Bool {
        let p = closed.powerReaction ?? PowerReactionOptions()
        guard p.isEnabled, let battery = system.battery else { return false }
        if battery >= 99 && !system.onBattery { return p.charged != .off }
        if system.charging { return p.charging != .off }
        if system.onBattery && battery <= p.lowThreshold { return p.low != .off }
        return false
    }
    private var persistentClosedContent: Bool {
        func persistent(_ item: ClosedNotchItem) -> Bool {
            switch item {
            case .clock, .date, .battery: return true
            case .files: return !store.files.isEmpty
            case .mirror: return true
            default: return false
            }
        }
        return persistent(closed.left) || persistent(closed.right) ||
            closed.leftDecoration?.visibility == .always || closed.rightDecoration?.visibility == .always
    }
    private var notchLike: Bool { state.theme.style == .notch || state.theme.style == .simulated }
    private var hasCommercialAccess: Bool { account.isSignedIn && license.accessValid(for: account.userID) }
    private var shouldShow: Bool {
        guard current.enabled, screenAwake, notchLike, hasCommercialAccess else { return false }
        guard !state.expanded, !state.dropTargeted else { return false }
        guard !activeHUD, !activeActivity, !mediaOwnsNotch, !timerOwnsNotch else { return false }
        guard !fileShelfOwnsNotch, !mirrorOwnsNotch, !powerOwnsNotch else { return false }
        if current.yieldToPersistentClosedContent && persistentClosedContent { return false }
        return true
    }
    private var notchWidth: CGFloat { max(40, state.physicalNotchWidth > 0 ? state.physicalNotchWidth : min(190, state.compactWidth)) }
    private var notchHeight: CGFloat { max(16, state.physicalNotchHeight > 0 ? state.physicalNotchHeight : min(34, state.compactHeight)) }

    var body: some View {
        ZStack(alignment: .top) {
            if shouldShow {
                NotchAmbientRuntimeCanvas(settings: current, notchWidth: notchWidth, notchHeight: notchHeight,
                                          albumColors: media.artworkColors, wallpaperColor: wallpaperColor,
                                          screenFrame: screenFrame, lowPower: current.lowPowerAdaptive && system.lowPower,
                                          reduceMotion: reduceMotion)
                    .transition(current.transition.swiftUITransition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .animation(.easeInOut(duration: current.transitionDuration), value: shouldShow)
        .onAppear { updateWallpaper(); updateAudioCapture() }
        .onDisappear { AudioSpectrumService.shared.setActive(false, owner: "notch-ambient") }
        .onChange(of: shouldShow) { _ in updateAudioCapture() }
        .onChange(of: ambient.settings.audioReaction) { _ in updateAudioCapture() }
        .onChange(of: ambient.settings.colorSource) { _ in updateWallpaper() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.screensDidSleepNotification)) { _ in screenAwake = false }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.screensDidWakeNotification)) { _ in screenAwake = true }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.sessionDidResignActiveNotification)) { _ in screenAwake = false }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.sessionDidBecomeActiveNotification)) { _ in screenAwake = true }
        .task(id: ambient.settings.rotationMode) {
            let mode = ambient.settings.rotationMode
            guard mode != .off && mode != .everySession else { return }
            while !Task.isCancelled {
                let interval: TimeInterval
                switch mode {
                case .random: interval = 30 * 60
                case .everyHour: interval = 60 * 60
                case .daily: interval = 6 * 60 * 60
                case .timeOfDay: interval = 5 * 60
                default: interval = 60 * 60
                }
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                activityClock = Date()
            }
        }
        .task(id: workspace.activities.map { $0.id }) {
            activityClock = Date()
            guard let next = workspace.activities.map({ $0.created.addingTimeInterval(12) }).filter({ $0 > Date() }).min() else { return }
            let delay = max(0.01, next.timeIntervalSinceNow)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            activityClock = Date()
        }
    }

    private func updateWallpaper() {
        guard ambient.settings.colorSource == .wallpaper else { return }
        wallpaperColor = NotchAmbientWallpaperSampler.sample(screenFrame: screenFrame)
    }
    private func updateAudioCapture() {
        AudioSpectrumService.shared.setActive(shouldShow && current.audioReaction != .off, owner: "notch-ambient")
    }
}

private extension NotchAmbientTransitionStyle {
    var swiftUITransition: AnyTransition {
        switch self {
        case .fade, .dissolve: return .opacity
        case .retract: return .opacity.combined(with: .scale(scale: 0.86, anchor: .top))
        case .shrink: return .opacity.combined(with: .scale(scale: 0.72, anchor: .top))
        case .slideBehind: return .opacity.combined(with: .move(edge: .top))
        case .particleCollapse: return .opacity.combined(with: .scale(scale: 0.55, anchor: .top))
        }
    }
}

private struct NotchAmbientRuntimeCanvas: View {
    let settings: NotchAmbientSettings
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let albumColors: [WidgetColor]
    let wallpaperColor: Color?
    let screenFrame: CGRect
    let lowPower: Bool
    let reduceMotion: Bool

    private var needsFastUpdates: Bool {
        if settings.audioReaction != .off { return true }
        if !reduceMotion && settings.cursorReaction != .off { return true }
        return !reduceMotion && settings.activity != .staticMode
    }
    private var temporal: Bool {
        settings.timeBasedAppearance || settings.colorSource == .timeBased || settings.seasonMode == .automatic || settings.rotationMode != .off
    }
    private var interval: TimeInterval {
        if lowPower { return 1.0 / 8.0 }
        if settings.audioReaction != .off { return 1.0 / 18.0 }
        return 1.0 / max(1, settings.activity.preferredFPS)
    }

    var body: some View {
        if needsFastUpdates {
            TimelineView(.periodic(from: .now, by: interval)) { context in artwork(at: context.date) }
        } else if temporal {
            TimelineView(.periodic(from: .now, by: 300)) { context in artwork(at: context.date) }
        } else {
            artwork(at: Date())
        }
    }

    private func artwork(at date: Date) -> some View {
        GeometryReader { proxy in
            let spectrum = settings.audioReaction == .off ? AudioSpectrumSnapshot() : AudioSpectrumService.shared.snapshot()
            let audio = spectrum.available ? spectrum.overall * settings.audioReaction.strength : 0
            let phase = reduceMotion ? 0 : date.timeIntervalSinceReferenceDate * settings.speed * settings.activity.phaseMultiplier
            let palette = NotchAmbientPaletteResolver.colors(settings: settings, album: albumColors, wallpaper: wallpaperColor, date: date)
            let cursor = cursorPoint(in: proxy.size)
            NotchAmbientArtwork(settings: settings, notchWidth: notchWidth, notchHeight: notchHeight,
                                phase: phase, audio: audio, cursor: cursor, palette: palette,
                                lowPower: lowPower, reduceMotion: reduceMotion, date: date)
        }
    }

    private func cursorPoint(in size: CGSize) -> CGPoint? {
        guard settings.cursorReaction != .off, !reduceMotion, !screenFrame.isEmpty else { return nil }
        let mouse = NSEvent.mouseLocation
        let x = size.width / 2 + (mouse.x - screenFrame.midX)
        let y = screenFrame.maxY - mouse.y
        guard x > -settings.reactionRadius, x < size.width + settings.reactionRadius,
              y > -settings.reactionRadius, y < size.height + settings.reactionRadius else { return nil }
        return CGPoint(x: x, y: y)
    }
}

private struct NotchAmbientArtwork: View {
    let settings: NotchAmbientSettings
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let phase: Double
    let audio: Double
    let cursor: CGPoint?
    let palette: [Color]
    let lowPower: Bool
    let reduceMotion: Bool
    let date: Date

    var body: some View {
        Canvas { context, size in
            let physicalNotch = CGRect(x: (size.width - notchWidth) / 2, y: 0, width: notchWidth, height: notchHeight)
            let artworkNotch = NotchAmbientPainter.placedNotch(physicalNotch, settings: settings)
            NotchAmbientPainter.draw(kind: settings.decoration, context: &context, size: size, notch: artworkNotch,
                                     settings: settings, phase: phase, audio: audio, cursor: cursor,
                                     palette: palette, lowPower: lowPower, date: date)
            if let season = settings.resolvedSeason(at: date) {
                NotchAmbientPainter.drawSeason(season, context: &context, size: size, notch: physicalNotch,
                                               settings: settings, phase: phase, palette: palette, lowPower: lowPower)
            }
        }
    }
}

private enum NotchAmbientPainter {
    private static func c(_ palette: [Color], _ index: Int) -> Color { palette.isEmpty ? .accentColor : palette[index % palette.count] }
    private static func rand(_ index: Int, seed: UInt64, salt: UInt64 = 0) -> Double {
        var x = seed &+ UInt64(truncatingIfNeeded: index &* 0x9E37) &+ salt &* 0x9E3779B97F4A7C15
        x &+= 0x9E3779B97F4A7C15; x = (x ^ (x >> 30)) &* 0xBF58476D1CE4E5B9
        x = (x ^ (x >> 27)) &* 0x94D049BB133111EB; x ^= x >> 31
        return Double(x & 0x1F_FFFF) / Double(0x1F_FFFF)
    }
    private static func line(_ context: inout GraphicsContext, _ points: [CGPoint], color: Color, width: CGFloat) {
        guard let first = points.first else { return }
        var p = Path(); p.move(to: first); for point in points.dropFirst() { p.addLine(to: point) }
        context.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: max(0.35, width), lineCap: .round, lineJoin: .round))
    }
    private static func glowLine(_ context: inout GraphicsContext, _ points: [CGPoint], color: Color, width: CGFloat, bloom: Double) {
        if bloom > 0 { line(&context, points, color: color.opacity(0.10 + bloom * 0.12), width: width + CGFloat(7 + 14 * bloom)) }
        line(&context, points, color: color.opacity(0.32 + bloom * 0.24), width: width + CGFloat(2 + 3 * bloom))
        line(&context, points, color: color.opacity(0.82), width: width)
    }
    private static func ellipse(_ context: inout GraphicsContext, rect: CGRect, color: Color, fill: Bool, width: CGFloat = 1) {
        let p = Path(ellipseIn: rect)
        if fill { context.fill(p, with: .color(color)) } else { context.stroke(p, with: .color(color), lineWidth: width) }
    }
    private static func rounded(_ rect: CGRect, radius: CGFloat) -> Path {
        Path(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    }
    private static func effectiveIntensity(_ s: NotchAmbientSettings, audio: Double, lowPower: Bool) -> Double {
        let power = lowPower ? 0.72 : 1.0
        return min(1, s.intensity * power * (1 + audio))
    }
    private static func cursorInfluence(_ cursor: CGPoint?, point: CGPoint, settings: NotchAmbientSettings) -> (strength: Double, dx: CGFloat, dy: CGFloat) {
        guard let cursor, settings.cursorReaction != .off else { return (0, 0, 0) }
        let dx = point.x - cursor.x, dy = point.y - cursor.y
        let d = max(1, hypot(dx, dy)); let radius = CGFloat(settings.reactionRadius)
        guard d < radius else { return (0, 0, 0) }
        let raw = Double(1 - d / radius)
        let exponent = max(0.35, 1.85 - settings.reactionSmoothing * 1.45)
        let strength = pow(raw, exponent) * settings.reactionStrength
        let sign: CGFloat = settings.cursorReaction == .attract ? -1 : 1
        return (strength, sign * dx / d * CGFloat(12 * strength), sign * dy / d * CGFloat(12 * strength))
    }

    static func placedNotch(_ notch: CGRect, settings s: NotchAmbientSettings) -> CGRect {
        switch s.placement {
        case .above: return notch.offsetBy(dx: 0, dy: -min(10, notch.height * 0.25))
        case .below: return notch.offsetBy(dx: 0, dy: min(18, notch.height * 0.45))
        case .left: return notch.offsetBy(dx: -min(54, notch.width * 0.28), dy: 0)
        case .right: return notch.offsetBy(dx: min(54, notch.width * 0.28), dy: 0)
        case .around, .behind, .edgeAttached: return notch
        }
    }

    static func draw(kind: NotchAmbientDecorationKind, context: inout GraphicsContext, size: CGSize, notch: CGRect,
                     settings s: NotchAmbientSettings, phase: Double, audio: Double, cursor: CGPoint?,
                     palette: [Color], lowPower: Bool, date: Date) {
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: date)
        let timeFactor = s.timeBasedAppearance ? (hour < 6 ? 0.68 : hour < 12 ? 1.08 : hour < 18 ? 1.0 : 0.82) : 1.0
        let intensity = min(1, effectiveIntensity(s, audio: audio, lowPower: lowPower) * timeFactor)
        switch kind {
        case .edgeGlow: drawEdgeGlow(&context, notch: notch, s: s, phase: phase, intensity: intensity, palette: palette, cursor: cursor)
        case .halo: drawHalo(&context, notch: notch, s: s, phase: phase, intensity: intensity, palette: palette, cursor: cursor)
        case .underline: drawUnderline(&context, notch: notch, s: s, phase: phase, intensity: intensity, palette: palette)
        case .shadowDepth: drawDepth(&context, notch: notch, s: s, intensity: intensity, palette: palette)
        case .fairyLights: drawHanging(&context, size: size, notch: notch, s: s, phase: phase, intensity: intensity, palette: palette, stars: false, ornaments: false, cursor: cursor, lowPower: lowPower)
        case .hangingStars: drawHanging(&context, size: size, notch: notch, s: s, phase: phase, intensity: intensity, palette: palette, stars: true, ornaments: false, cursor: cursor, lowPower: lowPower)
        case .christmasOrnaments: drawHanging(&context, size: size, notch: notch, s: s, phase: phase, intensity: intensity, palette: palette, stars: false, ornaments: true, cursor: cursor, lowPower: lowPower)
        case .icicles: drawIcicles(&context, notch: notch, s: s, phase: phase, intensity: intensity, palette: palette, lowPower: lowPower)
        case .vines, .moss, .treeBranch, .flowers: drawNature(&context, size: size, notch: notch, kind: kind, s: s, phase: phase, intensity: intensity, palette: palette, cursor: cursor, lowPower: lowPower)
        case .clouds, .rain, .snow: drawWeather(&context, size: size, notch: notch, kind: kind, s: s, phase: phase, intensity: intensity, palette: palette, lowPower: lowPower)
        case .blackHole, .portal, .reactor, .spaceship, .ufo, .orbit: drawSpace(&context, size: size, notch: notch, kind: kind, s: s, phase: phase, intensity: intensity, palette: palette, cursor: cursor, lowPower: lowPower)
        case .aquarium, .waterfall, .waterSurface: drawWater(&context, size: size, notch: notch, kind: kind, s: s, phase: phase, intensity: intensity, palette: palette, cursor: cursor, lowPower: lowPower)
        case .fireplace, .ember, .plasma, .electricity: drawEnergy(&context, size: size, notch: notch, kind: kind, s: s, phase: phase, intensity: intensity, palette: palette, cursor: cursor, lowPower: lowPower)
        case .tinyBuilding, .trainTunnel, .bridge, .balcony: drawArchitecture(&context, size: size, notch: notch, kind: kind, s: s, phase: phase, intensity: intensity, palette: palette, date: date)
        case .crt, .cyberpunk, .circuit, .dataRain, .terminalCursor: drawRetro(&context, size: size, notch: notch, kind: kind, s: s, phase: phase, intensity: intensity, palette: palette, cursor: cursor, lowPower: lowPower)
        }
    }

    private static func drawEdgeGlow(_ ctx: inout GraphicsContext, notch n: CGRect, s: NotchAmbientSettings, phase: Double, intensity: Double, palette: [Color], cursor: CGPoint?) {
        let breathe = 1 + sin(phase * 0.75) * s.pulse * 0.22
        let y = n.maxY + 0.5
        let falloff = 0.52 + s.falloff * 0.48
        let points = [CGPoint(x: n.minX, y: n.minY + n.height * 0.46), CGPoint(x: n.minX, y: y), CGPoint(x: n.maxX, y: y), CGPoint(x: n.maxX, y: n.minY + n.height * 0.46)]
        glowLine(&ctx, points, color: c(palette, 0).opacity(intensity * breathe * falloff), width: CGFloat(s.thickness), bloom: s.softness / 22)
        if let cursor {
            let x = min(n.maxX, max(n.minX, cursor.x))
            let anchor = CGPoint(x: x, y: y)
            let reaction = cursorInfluence(cursor, point: anchor, settings: s)
            if reaction.strength > 0 {
                let half = CGFloat(12 + reaction.strength * 22)
                glowLine(&ctx, [CGPoint(x:max(n.minX,x-half),y:y), CGPoint(x:min(n.maxX,x+half),y:y)], color:c(palette,1).opacity(intensity*(0.35+reaction.strength)), width:CGFloat(s.thickness*1.15), bloom:min(1,s.softness/18))
            }
        }
        if s.symmetry != .symmetric {
            let start = s.symmetry == .rightWeighted ? n.midX : n.minX
            glowLine(&ctx, [CGPoint(x: start, y: y + 2), CGPoint(x: n.maxX, y: y + 2)], color: c(palette, 1).opacity(intensity * 0.55), width: CGFloat(max(0.6, s.thickness * 0.55)), bloom: s.softness / 30)
        }
    }

    private static func drawHalo(_ ctx: inout GraphicsContext, notch n: CGRect, s: NotchAmbientSettings, phase: Double, intensity: Double, palette: [Color], cursor: CGPoint?) {
        let interaction = cursorInfluence(cursor, point: CGPoint(x:n.midX,y:n.maxY), settings:s).strength
        let p = 1 + sin(phase * 0.55) * s.pulse * 0.18 + interaction * 0.08
        let falloff = 0.52 + s.falloff * 0.48
        for i in 0..<5 {
            let inset = CGFloat(i * 7 + 5)
            let rect = n.insetBy(dx: -inset * p, dy: -inset * 0.42 * p).offsetBy(dx: 0, dy: 5)
            ellipse(&ctx, rect: rect, color: c(palette, i).opacity(intensity * falloff * (0.18 - Double(i) * 0.025) * (1 + interaction)), fill: false, width: CGFloat(5 + i * 3))
        }
    }

    private static func drawUnderline(_ ctx: inout GraphicsContext, notch n: CGRect, s: NotchAmbientSettings, phase: Double, intensity: Double, palette: [Color]) {
        let y = n.maxY + 5, half = n.width * 0.34
        let a = CGPoint(x: n.midX - half, y: y), b = CGPoint(x: n.midX + half, y: y)
        switch s.underlineStyle {
        case .solid: glowLine(&ctx, [a, b], color: c(palette, 0).opacity(intensity), width: CGFloat(s.thickness), bloom: s.softness / 24)
        case .centerOrb:
            glowLine(&ctx, [a, b], color: c(palette, 0).opacity(intensity * 0.7), width: CGFloat(s.thickness), bloom: s.softness / 28)
            ellipse(&ctx, rect: CGRect(x: n.midX - 3, y: y - 3, width: 6, height: 6), color: c(palette, 1).opacity(intensity), fill: true)
        case .diamond:
            glowLine(&ctx, [a, CGPoint(x: n.midX - 7, y: y), CGPoint(x: n.midX, y: y + 5), CGPoint(x: n.midX + 7, y: y), b], color: c(palette, 0).opacity(intensity), width: CGFloat(s.thickness), bloom: s.softness / 26)
        case .dashes:
            for i in 0..<6 { let x0 = a.x + CGFloat(i) * (2 * half / 6); line(&ctx, [CGPoint(x: x0, y: y), CGPoint(x: x0 + half / 7, y: y)], color: c(palette, i).opacity(intensity), width: CGFloat(s.thickness)) }
        }
        if s.activity != .staticMode {
            let t = CGFloat((sin(phase * 0.7) + 1) / 2)
            ellipse(&ctx, rect: CGRect(x: a.x + (b.x-a.x)*t - 1.5, y: y-1.5, width: 3, height: 3), color: .white.opacity(intensity * 0.75), fill: true)
        }
    }

    private static func drawDepth(_ ctx: inout GraphicsContext, notch n: CGRect, s: NotchAmbientSettings, intensity: Double, palette: [Color]) {
        let depth = CGFloat(4 + s.thickness * 1.8)
        ctx.fill(rounded(CGRect(x: n.minX - 1, y: n.maxY, width: n.width + 2, height: depth), radius: depth * 0.45), with: .color(Color.black.opacity(0.22 + intensity * 0.30)))
        line(&ctx, [CGPoint(x: n.minX + 5, y: n.maxY + 0.5), CGPoint(x: n.maxX - 5, y: n.maxY + 0.5)], color: c(palette, 0).opacity(0.14 + intensity * 0.18), width: 0.8)
        line(&ctx, [CGPoint(x: n.minX, y: n.maxY + depth), CGPoint(x: n.maxX, y: n.maxY + depth)], color: Color.black.opacity(0.18), width: 2)
    }

    private static func drawHanging(_ ctx: inout GraphicsContext, size: CGSize, notch n: CGRect, s: NotchAmbientSettings, phase: Double, intensity: Double, palette: [Color], stars: Bool, ornaments: Bool, cursor: CGPoint?, lowPower: Bool) {
        let count = max(2, min(lowPower ? 12 : 24, s.count)); let span = n.width * CGFloat(min(1.35, max(0.55, 0.55 + s.spacing * 0.33)))
        for i in 0..<count {
            let t = Double(i) / Double(max(1, count - 1)); let baseX = n.midX - span/2 + span * CGFloat(t)
            let variance = 0.72 + rand(i, seed: s.seed, salt: 11) * 0.55
            let len = CGFloat(s.length * variance)
            let sway = CGFloat(s.sway * 7) * sin(phase * (0.55 + rand(i, seed: s.seed, salt: 12)*0.35) + Double(i)*0.61)
            let point = CGPoint(x: baseX + sway, y: n.maxY + len)
            let reaction = cursorInfluence(cursor, point: point, settings: s)
            let end = CGPoint(x: point.x + reaction.dx, y: point.y + reaction.dy)
            line(&ctx, [CGPoint(x: baseX, y: n.maxY - 1), CGPoint(x: end.x, y: end.y - 3)], color: Color.white.opacity(0.10 + intensity*0.12), width: 0.65)
            let flicker = 1 - s.flicker * rand(i + Int(abs(phase) * 4), seed: s.seed, salt: 13)
            let color = c(palette, i).opacity(intensity * flicker * (1 + reaction.strength * 0.45))
            if stars {
                let r = CGFloat(2.5 + rand(i, seed: s.seed, salt: 14)*2.2)
                if i.isMultiple(of: 3) {
                    var moon = Path(); moon.move(to:CGPoint(x:end.x,y:end.y-r-1)); moon.addCurve(to:CGPoint(x:end.x,y:end.y+r+1),control1:CGPoint(x:end.x-r*1.4,y:end.y-r*0.25),control2:CGPoint(x:end.x-r*1.4,y:end.y+r*0.35)); moon.addCurve(to:CGPoint(x:end.x,y:end.y-r-1),control1:CGPoint(x:end.x-r*0.10,y:end.y+r*0.30),control2:CGPoint(x:end.x-r*0.10,y:end.y-r*0.28)); moon.closeSubpath(); ctx.fill(moon,with:.color(color))
                } else {
                    line(&ctx, [CGPoint(x:end.x-r,y:end.y), CGPoint(x:end.x+r,y:end.y)], color: color, width: 1)
                    line(&ctx, [CGPoint(x:end.x,y:end.y-r), CGPoint(x:end.x,y:end.y+r)], color: color, width: 1)
                    ellipse(&ctx, rect: CGRect(x:end.x-1.2,y:end.y-1.2,width:2.4,height:2.4), color: color, fill: true)
                }
            } else if ornaments {
                let radius=CGFloat(3.2+rand(i,seed:s.seed,salt:16)*2.1)
                line(&ctx,[CGPoint(x:end.x,y:end.y-radius-3),CGPoint(x:end.x,y:end.y-radius)],color:Color.white.opacity(0.28+intensity*0.25),width:0.7)
                ellipse(&ctx,rect:CGRect(x:end.x-radius,y:end.y-radius,width:radius*2,height:radius*2),color:c(palette,i).opacity(0.42+intensity*0.48),fill:true)
                line(&ctx,[CGPoint(x:end.x-radius*0.45,y:end.y-radius*0.45),CGPoint(x:end.x+radius*0.35,y:end.y+radius*0.35)],color:Color.white.opacity(0.22),width:0.65)
            } else {
                let w: CGFloat = s.bulbShape == .capsule ? 4 : 5
                let h: CGFloat = s.bulbShape == .teardrop ? 7 : s.bulbShape == .capsule ? 8 : 5
                if s.bloom > 0 { ellipse(&ctx, rect:CGRect(x:end.x-w,y:end.y-h,width:w*2,height:h*2), color:color.opacity(0.12+s.bloom*0.15), fill:true) }
                if s.bulbShape == .diamond {
                    line(&ctx, [CGPoint(x:end.x,y:end.y-4),CGPoint(x:end.x+4,y:end.y),CGPoint(x:end.x,y:end.y+4),CGPoint(x:end.x-4,y:end.y),CGPoint(x:end.x,y:end.y-4)], color:color, width:1.3)
                } else { ellipse(&ctx, rect:CGRect(x:end.x-w/2,y:end.y-h/2,width:w,height:h), color:color, fill:true) }
            }
        }
    }

    private static func drawIcicles(_ ctx: inout GraphicsContext, notch n: CGRect, s: NotchAmbientSettings, phase: Double, intensity: Double, palette: [Color], lowPower: Bool) {
        let densityCount = Int(s.density * 12.0)
        let maximumCount: Int = lowPower ? 16 : 30
        let count: Int = max(4, min(maximumCount, s.count + densityCount))

        for i in 0..<count {
            let denominator = Double(max(1, count - 1))
            let t = Double(i) / denominator
            let x = n.minX + n.width * CGFloat(t)
            let lengthFactor = 0.28 + rand(i, seed: s.seed, salt: 21) * 0.72
            let length = CGFloat(s.length * lengthFactor)

            var icicle = Path()
            icicle.move(to: CGPoint(x: x - 2.0, y: n.maxY))
            icicle.addLine(to: CGPoint(x: x, y: n.maxY + length))
            icicle.addLine(to: CGPoint(x: x + 2.0, y: n.maxY))
            icicle.closeSubpath()
            let icicleOpacity = 0.10 + intensity * 0.30
            ctx.fill(icicle, with: .color(c(palette, i).opacity(icicleOpacity)))

            if rand(i, seed: s.seed, salt: 22) > 0.72 {
                let wave = sin(phase + Double(i))
                let dropletY = n.maxY + length * 0.55 + CGFloat(wave) * 2.0
                let dropletRect = CGRect(x: x - 0.8, y: dropletY, width: 1.6, height: 1.6)
                ellipse(&ctx, rect: dropletRect, color: .white.opacity(intensity * 0.55), fill: true)
            }
        }
    }

    private static func drawNature(_ ctx: inout GraphicsContext, size: CGSize, notch n: CGRect, kind: NotchAmbientDecorationKind, s: NotchAmbientSettings, phase: Double, intensity: Double, palette: [Color], cursor: CGPoint?, lowPower: Bool) {
        if kind == .moss {
            let count=max(8,min(lowPower ? 28:52,Int(14+s.density*40)))
            for i in 0..<count { let side = i.isMultiple(of:2) ? n.minX : n.maxX; let spread=CGFloat(rand(i,seed:s.seed,salt:31)*30); let x=side + (i.isMultiple(of:2) ? -spread:spread); let h=CGFloat(4+rand(i,seed:s.seed,salt:32)*18*s.density); let tip=CGPoint(x:x+CGFloat(sin(phase+Double(i)))*1.8*s.sway,y:n.maxY-h); let react=cursorInfluence(cursor,point:tip,settings:s); line(&ctx,[CGPoint(x:x,y:n.maxY+2),CGPoint(x:tip.x+react.dx,y:tip.y+react.dy)],color:c(palette,i).opacity(0.32+intensity*0.45),width:1.1) }
            return
        }
        let branchRight = s.symmetry == .rightWeighted || (s.symmetry != .leftWeighted && rand(1,seed:s.seed,salt:30)>0.5)
        let sides:[CGFloat] = s.symmetry == .symmetric ? [n.minX,n.maxX] : [branchRight ? n.maxX:n.minX]
        for (sideIndex,side) in sides.enumerated() {
            let sign:CGFloat = side <= n.midX ? -1:1
            let endY = n.maxY + CGFloat(s.length * (kind == .treeBranch ? 0.38:1))
            let endX = side + sign * CGFloat(kind == .treeBranch ? s.length*0.70:s.length*0.18)
            var vine=Path(); vine.move(to:CGPoint(x:side,y:n.maxY-2)); vine.addCurve(to:CGPoint(x:endX,y:endY),control1:CGPoint(x:side+sign*18,y:n.maxY+CGFloat(s.length*0.18)),control2:CGPoint(x:endX-sign*15,y:endY-CGFloat(s.length*0.25)))
            ctx.stroke(vine,with:.color(c(palette,1).opacity(0.34+intensity*0.42)),style:StrokeStyle(lineWidth:kind == .treeBranch ? 2.6:1.4,lineCap:.round))
            let leaves=max(3,min(lowPower ? 10:20,Int(4+s.density*14)))
            for i in 0..<leaves { let t=CGFloat(i+1)/CGFloat(leaves+1); var x=side+(endX-side)*t; var y=n.maxY+(endY-n.maxY)*t; x += sign*CGFloat(sin(phase*0.5+Double(i+sideIndex))*s.sway*4); let react=cursorInfluence(cursor,point:CGPoint(x:x,y:y),settings:s); x += react.dx; y += react.dy; let w:CGFloat=s.foliageStyle == .broad ? 8:5; let h:CGFloat=s.foliageStyle == .fern ? 3:6; ellipse(&ctx,rect:CGRect(x:x-w/2,y:y-h/2,width:w,height:h),color:c(palette,i).opacity(0.30+intensity*0.42),fill:true); if kind == .flowers || s.foliageStyle == .floral, rand(i,seed:s.seed,salt:35)>0.65 { ellipse(&ctx,rect:CGRect(x:x-2.2,y:y-2.2,width:4.4,height:4.4),color:c(palette,2).opacity(0.55+intensity*0.35),fill:true) } }
        }
        if kind == .treeBranch && s.activity != .staticMode && rand(Int(abs(phase)/8),seed:s.seed,salt:39)>0.88 { let t=CGFloat(phase.truncatingRemainder(dividingBy:10)/10); let x=n.midX+CGFloat(sin(phase*0.35))*70; let y=n.maxY+20+t*90; ellipse(&ctx,rect:CGRect(x:x-2,y:y-1,width:5,height:2.5),color:c(palette,1).opacity(0.45),fill:true) }
    }

    private static func drawWeather(_ ctx: inout GraphicsContext, size: CGSize, notch n: CGRect, kind: NotchAmbientDecorationKind, s: NotchAmbientSettings, phase: Double, intensity: Double, palette: [Color], lowPower: Bool) {
        if kind == .clouds {
            for i in 0..<max(3,min(8,s.count/2)) { let side:CGFloat=i.isMultiple(of:2) ? -1:1; let x=n.midX+side*(n.width/2+CGFloat(8+i*9))+CGFloat(sin(phase*0.12+Double(i))*5); let y=n.maxY+CGFloat(8+rand(i,seed:s.seed,salt:41)*18); ellipse(&ctx,rect:CGRect(x:x-18,y:y-7,width:36,height:14),color:c(palette,0).opacity(0.06+intensity*0.13),fill:true) }
            return
        }
        let maxCount = lowPower ? 20:42; let count=max(5,min(maxCount,Int(Double(s.count)*0.8+s.density*28)))
        if kind == .snow && s.accumulation { line(&ctx,[CGPoint(x:n.minX+4,y:n.maxY+1),CGPoint(x:n.maxX-4,y:n.maxY+1)],color:.white.opacity(0.18+intensity*0.25),width:2.3) }
        for i in 0..<count {
            let width=n.width+110; let base=rand(i,seed:s.seed,salt:42); let speed=kind == .rain ? 40.0:12.0
            let y=n.maxY+CGFloat((base*Double(max(1,size.height-n.maxY))+phase*speed).truncatingRemainder(dividingBy:Double(max(20,size.height-n.maxY))))
            let x=n.midX-width/2+CGFloat(rand(i,seed:s.seed,salt:43))*width+CGFloat(s.wind)*y*0.16
            if kind == .rain { line(&ctx,[CGPoint(x:x,y:y),CGPoint(x:x+CGFloat(s.wind)*4,y:y+CGFloat(s.length*0.45))],color:c(palette,i).opacity(0.14+intensity*0.34),width:0.8); if s.splash && y > size.height-8 && rand(i,seed:s.seed,salt:44)>0.7 { line(&ctx,[CGPoint(x:x-3,y:size.height-5),CGPoint(x:x,y:size.height-7),CGPoint(x:x+3,y:size.height-5)],color:c(palette,0).opacity(0.18),width:0.7) } }
            else { let r=CGFloat(1+rand(i,seed:s.seed,salt:45)*1.6); ellipse(&ctx,rect:CGRect(x:x-r,y:y-r,width:r*2,height:r*2),color:.white.opacity(0.18+intensity*0.42),fill:true) }
        }
    }

    private static func drawSpace(_ ctx: inout GraphicsContext, size: CGSize, notch n: CGRect, kind: NotchAmbientDecorationKind, s: NotchAmbientSettings, phase: Double, intensity: Double, palette: [Color], cursor: CGPoint?, lowPower: Bool) {
        switch kind {
        case .blackHole:
            let center = CGPoint(x: n.midX, y: n.midY + 4.0)
            for i in 0..<8 {
                let pad = CGFloat(9 + i * 7)
                let ringHeight = CGFloat(18 + i * 3)
                let ringRect = CGRect(
                    x: center.x - n.width / 2.0 - pad,
                    y: center.y - ringHeight / 2.0,
                    width: n.width + pad * 2.0,
                    height: ringHeight
                )
                let ringOpacity = (0.16 - Double(i) * 0.012) * intensity
                let ringWidth = CGFloat(1.2 + Double(i % 3))
                ellipse(&ctx, rect: ringRect, color: c(palette, i).opacity(ringOpacity), fill: false, width: ringWidth)
            }

            let maximumParticles: Int = lowPower ? 18 : 36
            let particleCount: Int = max(6, min(maximumParticles, Int(8.0 + s.density * 30.0)))
            for i in 0..<particleCount {
                let angularSpeed = 0.18 + rand(i, seed: s.seed, salt: 51) * 0.18
                let angle = phase * angularSpeed + rand(i, seed: s.seed, salt: 52) * Double.pi * 2.0
                let radiusX = n.width / 2.0 + CGFloat(18.0 + rand(i, seed: s.seed, salt: 53) * 70.0)
                let radiusY = CGFloat(12.0 + rand(i, seed: s.seed, salt: 54) * 25.0)
                var point = CGPoint(
                    x: center.x + CGFloat(cos(angle)) * radiusX,
                    y: center.y + CGFloat(sin(angle)) * radiusY
                )
                let reaction = cursorInfluence(cursor, point: point, settings: s)
                point.x += reaction.dx
                point.y += reaction.dy
                let radius = CGFloat(0.8 + rand(i, seed: s.seed, salt: 55) * 1.8)
                let particleRect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2.0, height: radius * 2.0)
                ellipse(&ctx, rect: particleRect, color: c(palette, i).opacity(0.25 + intensity * 0.58), fill: true)
            }

            if s.lensDistortion || s.distortion > 0.5 {
                let lensRect = n.insetBy(dx: -24.0, dy: -10.0).offsetBy(dx: 0, dy: 5.0)
                ellipse(&ctx, rect: lensRect, color: .white.opacity(intensity * s.distortion * 0.08), fill: false, width: 1.0)
            }
        case .portal:
            let center = CGPoint(x: n.midX, y: n.midY + 5.0)
            let interaction = cursorInfluence(cursor, point: center, settings: s).strength

            for i in 0..<7 {
                let pad = CGFloat(7 + i * 7)
                let verticalRadius = CGFloat(13 + i * 2)
                let ringHeight = CGFloat(26 + i * 4)
                let ringRect = CGRect(
                    x: center.x - n.width / 2.0 - pad,
                    y: center.y - verticalRadius,
                    width: n.width + pad * 2.0,
                    height: ringHeight
                )
                let baseOpacity = 0.25 - Double(i) * 0.022
                let ringOpacity = intensity * baseOpacity * (1.0 + interaction * 1.3)
                let ringWidth = CGFloat(1.2 + Double(i % 2))
                ellipse(&ctx, rect: ringRect, color: c(palette, i).opacity(ringOpacity), fill: false, width: ringWidth)
            }

            let maximumParticles: Int = lowPower ? 14 : 28
            let particleCount: Int = max(4, min(maximumParticles, Int(5.0 + s.density * 24.0)))
            let portalSpeed: Double = 9.0 + interaction * 6.0
            for i in 0..<particleCount {
                let angleSeed = rand(i, seed: s.seed, salt: 61)
                let angle = angleSeed * Double.pi * 2.0 + phase * 0.12
                let radius = CGFloat(25.0 + rand(i, seed: s.seed, salt: 62) * 80.0)
                let x = center.x + CGFloat(cos(angle)) * radius
                let driftInput = phase * portalSpeed + Double(i) * 7.0
                let drift = driftInput.truncatingRemainder(dividingBy: 18.0)
                let y = center.y + CGFloat(sin(angle)) * radius * 0.36 + CGFloat(drift)
                let opacity = intensity * (0.58 + interaction * 0.32)
                let particleRect = CGRect(x: x - 1.0, y: y - 1.0, width: 2.0, height: 2.0)
                ellipse(&ctx, rect: particleRect, color: c(palette, i).opacity(opacity), fill: true)
            }
        case .reactor:
            let y=n.maxY+5; for side in [-1.0,1.0] { let sx=CGFloat(side); let start=CGPoint(x:n.midX+sx*n.width/2,y:y); let p=[start,CGPoint(x:start.x+sx*20,y:y+12),CGPoint(x:start.x+sx*65,y:y+12),CGPoint(x:start.x+sx*82,y:y+2)]; glowLine(&ctx,p,color:c(palette,side<0 ? 0:1).opacity(intensity),width:CGFloat(s.thickness),bloom:s.softness/25); let t=CGFloat((phase*0.22).truncatingRemainder(dividingBy:1)); let x=p[1].x+(p[2].x-p[1].x)*t; ellipse(&ctx,rect:CGRect(x:x-2,y:y+10,width:4,height:4),color:.white.opacity(intensity*0.75),fill:true) }
        case .spaceship:
            var left=Path(); left.move(to:CGPoint(x:n.minX,y:n.maxY-4)); left.addLine(to:CGPoint(x:n.minX-76,y:n.maxY+20)); left.addLine(to:CGPoint(x:n.minX-20,y:n.maxY+27)); left.closeSubpath(); ctx.fill(left,with:.color(c(palette,0).opacity(0.18+intensity*0.34))); var right=Path(); right.move(to:CGPoint(x:n.maxX,y:n.maxY-4)); right.addLine(to:CGPoint(x:n.maxX+76,y:n.maxY+20)); right.addLine(to:CGPoint(x:n.maxX+20,y:n.maxY+27)); right.closeSubpath(); ctx.fill(right,with:.color(c(palette,0).opacity(0.18+intensity*0.34))); for x in [n.minX+18,n.maxX-18] { glowLine(&ctx,[CGPoint(x:x,y:n.maxY),CGPoint(x:x,y:n.maxY+15+CGFloat(sin(phase)*2))],color:c(palette,2).opacity(intensity),width:2,bloom:s.softness/24) }
        case .ufo:
            ellipse(&ctx,rect:CGRect(x:n.minX-54,y:n.maxY-8,width:n.width+108,height:25),color:c(palette,0).opacity(0.18+intensity*0.35),fill:false,width:1.4); line(&ctx,[CGPoint(x:n.minX-36,y:n.maxY+7),CGPoint(x:n.maxX+36,y:n.maxY+7)],color:c(palette,1).opacity(intensity*0.45),width:1); if sin(phase*0.12)>0.82 { var beam=Path(); beam.move(to:CGPoint(x:n.midX-10,y:n.maxY+10)); beam.addLine(to:CGPoint(x:n.midX-34,y:n.maxY+90)); beam.addLine(to:CGPoint(x:n.midX+34,y:n.maxY+90)); beam.addLine(to:CGPoint(x:n.midX+10,y:n.maxY+10)); beam.closeSubpath(); ctx.fill(beam,with:.color(c(palette,2).opacity(intensity*0.045))) }
        case .orbit:
            ellipse(&ctx,rect:CGRect(x:n.minX-80,y:n.midY-20,width:n.width+160,height:40),color:c(palette,0).opacity(intensity*0.20),fill:false,width:0.8); let count=max(2,min(lowPower ? 7:12,s.count)); for i in 0..<count { let a=phase*(0.14+Double(i)*0.015)+Double(i)/Double(count)*Double.pi*2; let x=n.midX+cos(a)*(n.width/2+60); let y=n.midY+sin(a)*20; let r=CGFloat(1.5+rand(i,seed:s.seed,salt:68)*2.3); ellipse(&ctx,rect:CGRect(x:x-r,y:y-r,width:r*2,height:r*2),color:c(palette,i).opacity(0.4+intensity*0.5),fill:true) }
        default: break
        }
    }

    private static func drawWater(_ ctx: inout GraphicsContext, size: CGSize, notch n: CGRect, kind: NotchAmbientDecorationKind, s: NotchAmbientSettings, phase: Double, intensity: Double, palette: [Color], cursor: CGPoint?, lowPower: Bool) {
        switch kind {
        case .waterSurface:
            for k in 0..<3 { var p=Path(); let y=n.maxY+CGFloat(7+k*5); p.move(to:CGPoint(x:n.minX-75,y:y)); for j in 1...24 { let x=n.minX-75+CGFloat(j)*(n.width+150)/24; let yy=y+CGFloat(sin(Double(j)*0.85+phase*0.45+Double(k))*2.3*(1+audioLikeCursor(cursor,point:CGPoint(x:x,y:y),s:s))); p.addLine(to:CGPoint(x:x,y:yy)) }; ctx.stroke(p,with:.color(c(palette,k).opacity(0.18+intensity*0.26)),lineWidth:1) }
        case .waterfall:
            let count=max(6,min(lowPower ? 18:34,Int(8+s.density*28))); for i in 0..<count { let x=n.minX+CGFloat(rand(i,seed:s.seed,salt:71))*n.width; let start=n.maxY; let len=CGFloat(s.length*(0.65+rand(i,seed:s.seed,salt:72)*0.45)); let wobble=CGFloat(sin(phase*0.6+Double(i))*2); line(&ctx,[CGPoint(x:x,y:start),CGPoint(x:x+wobble,y:min(size.height,start+len))],color:c(palette,i).opacity(0.08+intensity*0.28),width:CGFloat(0.5+rand(i,seed:s.seed,salt:73)*1.3)) }; if s.splash { for i in 0..<8 { let x=n.midX+CGFloat(rand(i,seed:s.seed,salt:74)-0.5)*n.width; let y=min(size.height-5,n.maxY+CGFloat(s.length)); ellipse(&ctx,rect:CGRect(x:x-2,y:y-1,width:4,height:2),color:c(palette,0).opacity(intensity*0.22),fill:false,width:0.7) } }
        case .aquarium:
            let waterTop=n.maxY+5; line(&ctx,[CGPoint(x:n.minX-36,y:waterTop),CGPoint(x:n.maxX+36,y:waterTop)],color:c(palette,0).opacity(0.16+intensity*0.28),width:1); let fish=max(2,min(lowPower ? 4:8,s.count)); for i in 0..<fish { let dir:CGFloat=i.isMultiple(of:2) ? 1:-1; let travel=(phase*(0.035+rand(i,seed:s.seed,salt:75)*0.025)+rand(i,seed:s.seed,salt:76)).truncatingRemainder(dividingBy:1); let x=n.midX+CGFloat(travel-0.5)*(n.width+130)*dir; let y=waterTop+CGFloat(18+rand(i,seed:s.seed,salt:77)*70); ellipse(&ctx,rect:CGRect(x:x-6,y:y-2.5,width:12,height:5),color:c(palette,i+1).opacity(0.28+intensity*0.36),fill:true); var tail=Path(); tail.move(to:CGPoint(x:x-6*dir,y:y)); tail.addLine(to:CGPoint(x:x-11*dir,y:y-4)); tail.addLine(to:CGPoint(x:x-11*dir,y:y+4)); tail.closeSubpath(); ctx.fill(tail,with:.color(c(palette,i+1).opacity(0.32+intensity*0.34))) }; for i in 0..<8 { let x=n.midX+CGFloat(rand(i,seed:s.seed,salt:78)-0.5)*(n.width+80); let y=waterTop+CGFloat((rand(i,seed:s.seed,salt:79)*90-phase*8).truncatingRemainder(dividingBy:90)); ellipse(&ctx,rect:CGRect(x:x-1.5,y:y-1.5,width:3,height:3),color:.white.opacity(0.12+intensity*0.18),fill:false,width:0.6) }; for side in [-1.0,1.0] { let baseX=n.midX+CGFloat(side)*(n.width/2+20); for j in 0..<4 { line(&ctx,[CGPoint(x:baseX+CGFloat(j*4)*CGFloat(side),y:waterTop+85),CGPoint(x:baseX+CGFloat(j*3)*CGFloat(side)+CGFloat(sin(phase*0.4+Double(j))*3),y:waterTop+45-CGFloat(j*7))],color:c(palette,2).opacity(0.20+intensity*0.24),width:1.2) } }
        default: break
        }
    }
    private static func audioLikeCursor(_ cursor: CGPoint?, point: CGPoint, s: NotchAmbientSettings) -> Double { cursorInfluence(cursor,point:point,settings:s).strength }

    private static func drawEnergy(_ ctx: inout GraphicsContext, size: CGSize, notch n: CGRect, kind: NotchAmbientDecorationKind, s: NotchAmbientSettings, phase: Double, intensity: Double, palette: [Color], cursor: CGPoint?, lowPower: Bool) {
        switch kind {
        case .fireplace:
            let flames=max(4,min(lowPower ? 8:14,Int(5+s.density*10))); for i in 0..<flames { let x=n.minX+CGFloat(i+1)*n.width/CGFloat(flames+1); let h=CGFloat(10+rand(i,seed:s.seed,salt:81)*26)*(1+CGFloat(intensity)*0.35); var p=Path(); p.move(to:CGPoint(x:x-5,y:n.maxY+1)); p.addCurve(to:CGPoint(x:x,y:n.maxY-h),control1:CGPoint(x:x-7,y:n.maxY-h*0.35),control2:CGPoint(x:x+4,y:n.maxY-h*0.62)); p.addCurve(to:CGPoint(x:x+5,y:n.maxY+1),control1:CGPoint(x:x+2,y:n.maxY-h*0.45),control2:CGPoint(x:x+8,y:n.maxY-h*0.15)); p.closeSubpath(); ctx.fill(p,with:.color(c(palette,i).opacity(0.20+intensity*0.46))) }
        case .ember:
            let count=max(5,min(lowPower ? 14:28,s.count+Int(s.density*12))); for i in 0..<count { let x=n.midX+CGFloat(rand(i,seed:s.seed,salt:82)-0.5)*(n.width+90)+CGFloat(sin(phase+Double(i))*4); let y=n.maxY+CGFloat((rand(i,seed:s.seed,salt:83)*120-phase*7).truncatingRemainder(dividingBy:120)); let r=CGFloat(0.7+rand(i,seed:s.seed,salt:84)*1.8); ellipse(&ctx,rect:CGRect(x:x-r,y:y-r,width:r*2,height:r*2),color:c(palette,i).opacity(0.20+intensity*0.55),fill:true) }
        case .plasma:
            for side in [-1.0,1.0] { let sx=CGFloat(side); var pts=[CGPoint(x:n.midX+sx*n.width/2,y:n.maxY-2)]; for i in 1...7 { let x=n.midX+sx*(n.width/2+CGFloat(i)*18); let y=n.maxY+CGFloat(8+sin(phase*0.8+Double(i))*8); pts.append(CGPoint(x:x,y:y)) }; glowLine(&ctx,pts,color:c(palette,side<0 ? 0:1).opacity(intensity),width:CGFloat(s.thickness),bloom:s.softness/22) }
        case .electricity:
            let cycle=(sin(phase*0.27)+1)/2; guard cycle > 1-s.electricalFrequency*2.4 else { return }; for side in [-1.0,1.0] { let sx=CGFloat(side); var pts=[CGPoint(x:n.midX+sx*n.width/2,y:n.maxY)]; for i in 1...6 { let x=n.midX+sx*(n.width/2+CGFloat(i)*10); let y=n.maxY+CGFloat(i*5)+CGFloat(rand(i,seed:s.seed,salt:85)-0.5)*12; pts.append(CGPoint(x:x,y:y)) }; glowLine(&ctx,pts,color:c(palette,side<0 ? 0:1).opacity(intensity*0.72),width:CGFloat(s.thickness),bloom:s.softness/20) }
        default: break
        }
    }

    private static func drawArchitecture(_ ctx: inout GraphicsContext, size: CGSize, notch n: CGRect, kind: NotchAmbientDecorationKind, s: NotchAmbientSettings, phase: Double, intensity: Double, palette: [Color], date: Date) {
        let night = Calendar.autoupdatingCurrent.component(.hour, from: date) < 7 || Calendar.autoupdatingCurrent.component(.hour, from: date) >= 19
        switch kind {
        case .tinyBuilding:
            for side in [-1.0,1.0] { let rect=CGRect(x:(side<0 ? n.minX-58:n.maxX+8),y:n.maxY-2,width:50,height:72); ctx.fill(rounded(rect,radius:3),with:.color(c(palette,0).opacity(0.12+intensity*0.18))); for row in 0..<4 { for col in 0..<3 { let x=rect.minX+8+CGFloat(col)*14; let y=rect.minY+9+CGFloat(row)*15; ctx.fill(rounded(CGRect(x:x,y:y,width:6,height:8),radius:1),with:.color((night ? c(palette,2):c(palette,1)).opacity(night ? 0.30+intensity*0.42:0.08+intensity*0.12))) } }; line(&ctx,[CGPoint(x:rect.minX,y:rect.minY),CGPoint(x:side<0 ? n.minX:n.maxX,y:n.maxY)],color:c(palette,0).opacity(0.28),width:1.2) }
        case .trainTunnel:
            let arch=CGRect(x:n.minX-16,y:n.minY-2,width:n.width+32,height:n.height+42); ctx.stroke(rounded(arch,radius:18),with:.color(c(palette,0).opacity(0.18+intensity*0.28)),lineWidth:2); let t=(phase*0.035).truncatingRemainder(dividingBy:1); if t>0.62 { let local=(t-0.62)/0.38; let x=n.minX-100+CGFloat(local)*(n.width/2+90); let train=CGRect(x:x,y:n.maxY+18,width:34,height:12); ctx.fill(rounded(train,radius:2),with:.color(c(palette,0).opacity(0.35+intensity*0.35))); ellipse(&ctx,rect:CGRect(x:train.maxX-5,y:train.midY-2,width:4,height:4),color:c(palette,2).opacity(0.75),fill:true) }
        case .bridge:
            line(&ctx,[CGPoint(x:n.minX-80,y:n.maxY+20),CGPoint(x:n.minX,y:n.maxY+5),CGPoint(x:n.maxX,y:n.maxY+5),CGPoint(x:n.maxX+80,y:n.maxY+20)],color:c(palette,0).opacity(0.25+intensity*0.32),width:2); for i in 0...6 { let x=n.minX-60+CGFloat(i)*(n.width+120)/6; line(&ctx,[CGPoint(x:x,y:n.maxY+10),CGPoint(x:x,y:n.maxY+34)],color:c(palette,1).opacity(0.18+intensity*0.18),width:0.8) }
        case .balcony:
            let y=n.maxY+18; line(&ctx,[CGPoint(x:n.minX-28,y:y),CGPoint(x:n.maxX+28,y:y)],color:c(palette,0).opacity(0.25+intensity*0.35),width:1.5); for i in 0...8 { let x=n.minX-24+CGFloat(i)*(n.width+48)/8; line(&ctx,[CGPoint(x:x,y:n.maxY+4),CGPoint(x:x,y:y)],color:c(palette,1).opacity(0.18+intensity*0.22),width:0.8) }
        default: break
        }
    }

    private static func drawRetro(_ ctx: inout GraphicsContext, size: CGSize, notch n: CGRect, kind: NotchAmbientDecorationKind, s: NotchAmbientSettings, phase: Double, intensity: Double, palette: [Color], cursor: CGPoint?, lowPower: Bool) {
        switch kind {
        case .crt:
            let rect=CGRect(x:n.minX-38,y:n.maxY-2,width:n.width+76,height:80); ctx.stroke(rounded(rect,radius:8),with:.color(c(palette,0).opacity(0.12+intensity*0.20)),lineWidth:1); let lines=max(3,min(18,Int(4+s.scanlines*18))); for i in 0..<lines { let y=rect.minY+CGFloat(i+1)*rect.height/CGFloat(lines+1); line(&ctx,[CGPoint(x:rect.minX+5,y:y),CGPoint(x:rect.maxX-5,y:y)],color:c(palette,0).opacity(0.025+s.scanlines*0.055),width:0.6) }; if s.glitch>0 && sin(phase*0.09)>0.94 { line(&ctx,[CGPoint(x:rect.minX+12,y:rect.midY),CGPoint(x:rect.maxX-22,y:rect.midY)],color:c(palette,1).opacity(intensity*0.22),width:2) }
        case .cyberpunk:
            for side in [-1.0,1.0] { let sx=CGFloat(side); let y=n.maxY+7; let p=[CGPoint(x:n.midX+sx*n.width/2,y:y),CGPoint(x:n.midX+sx*(n.width/2+24),y:y),CGPoint(x:n.midX+sx*(n.width/2+34),y:y+8),CGPoint(x:n.midX+sx*(n.width/2+90),y:y+8)]; glowLine(&ctx,p,color:c(palette,side<0 ? 0:1).opacity(intensity),width:CGFloat(s.thickness),bloom:s.softness/24); let t=CGFloat((phase*0.18).truncatingRemainder(dividingBy:1)); let x=p[2].x+(p[3].x-p[2].x)*t; ellipse(&ctx,rect:CGRect(x:x-1.5,y:y+6.5,width:3,height:3),color:.white.opacity(intensity*0.7),fill:true) }
        case .circuit:
            let traces=max(2,min(lowPower ? 5:9,Int(3+s.density*7))); for side in [-1.0,1.0] { let sx=CGFloat(side); for i in 0..<traces { let y=n.maxY+CGFloat(4+i*7); let x0=n.midX+sx*n.width/2; let x1=x0+sx*CGFloat(18+i*3); let x2=x1+sx*CGFloat(35+rand(i,seed:s.seed,salt:91)*35); line(&ctx,[CGPoint(x:x0,y:n.maxY),CGPoint(x:x1,y:y),CGPoint(x:x2,y:y)],color:c(palette,i).opacity(0.14+intensity*0.35),width:CGFloat(s.thickness)); ellipse(&ctx,rect:CGRect(x:x2-1.5,y:y-1.5,width:3,height:3),color:c(palette,i).opacity(intensity*0.55),fill:true) } }
        case .dataRain:
            let cols=max(3,min(lowPower ? 9:16,s.count)); for i in 0..<cols { let t=CGFloat(i)/CGFloat(max(1,cols-1)); let x=n.minX-50+t*(n.width+100); let y=n.maxY+CGFloat((rand(i,seed:s.seed,salt:92)*100+phase*15).truncatingRemainder(dividingBy:110)); for j in 0..<4 { let bit=((i+j+Int(abs(phase)))%2); ctx.draw(Text("\(bit)").font(.system(size:7,weight:.medium,design:.monospaced)).foregroundColor(c(palette,0).opacity(0.10+intensity*0.28)),at:CGPoint(x:x,y:y+CGFloat(j*9))) } }
        case .terminalCursor:
            let y=n.maxY+12; let visible=s.activity == .staticMode || sin(phase * 1.6) > -0.15; if visible { ctx.fill(rounded(CGRect(x:n.midX-10,y:y,width:20,height:2.2),radius:1),with:.color(c(palette,0).opacity(0.35+intensity*0.48))) }
        default: break
        }
    }

    static func drawSeason(_ season: NotchAmbientSeason, context ctx: inout GraphicsContext, size: CGSize, notch n: CGRect, settings s: NotchAmbientSettings, phase: Double, palette: [Color], lowPower: Bool) {
        let alpha = 0.18 + s.intensity * 0.18
        switch season {
        case .winter:
            for i in 0..<(lowPower ? 5:9) { let x=n.midX+CGFloat(rand(i,seed:s.seed,salt:101)-0.5)*(n.width+90); let y=n.maxY+CGFloat((rand(i,seed:s.seed,salt:102)*90+phase*4).truncatingRemainder(dividingBy:90)); ellipse(&ctx,rect:CGRect(x:x-1,y:y-1,width:2,height:2),color:.white.opacity(alpha),fill:true) }
        case .spring:
            for i in 0..<5 { let side:CGFloat=i.isMultiple(of:2) ? -1:1; let x=n.midX+side*(n.width/2+CGFloat(6+i*3)); let y=n.maxY+CGFloat(4+i*3); ellipse(&ctx,rect:CGRect(x:x-2,y:y-2,width:4,height:4),color:c(palette,2).opacity(alpha+0.12),fill:true) }
        case .summer:
            line(&ctx,[CGPoint(x:n.minX-10,y:n.maxY+2),CGPoint(x:n.maxX+10,y:n.maxY+2)],color:Color.yellow.opacity(alpha*0.34),width:2)
        case .autumn:
            for i in 0..<5 { let x=n.midX+CGFloat(rand(i,seed:s.seed,salt:103)-0.5)*(n.width+70); let y=n.maxY+CGFloat((rand(i,seed:s.seed,salt:104)*80+phase*3).truncatingRemainder(dividingBy:80)); ellipse(&ctx,rect:CGRect(x:x-2,y:y-1,width:5,height:2.5),color:Color.orange.opacity(alpha+0.08),fill:true) }
        case .halloween:
            ellipse(&ctx,rect:n.insetBy(dx:-12,dy:-6).offsetBy(dx:0,dy:5),color:Color.purple.opacity(alpha*0.32),fill:false,width:2)
        case .christmas:
            for i in 0..<6 { let t=CGFloat(i)/5; let x=n.minX+n.width*t; ellipse(&ctx,rect:CGRect(x:x-2,y:n.maxY+4,width:4,height:4),color:(i.isMultiple(of:2) ? Color.red:Color.green).opacity(alpha+0.12),fill:true) }
        case .newYear:
            if sin(phase*0.12)>0.80 { for i in 0..<5 { let a=Double(i)/5*Double.pi*2; let x=n.midX+cos(a)*35; let y=n.maxY+28+sin(a)*18; ellipse(&ctx,rect:CGRect(x:x-1.3,y:y-1.3,width:2.6,height:2.6),color:.white.opacity(alpha+0.18),fill:true) } }
        }
    }
}

@MainActor
struct NotchAmbientSettingsView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore
    @ObservedObject private var ambient = NotchAmbientStore.shared
    @State private var presetName = ""
    @State private var wallpaperColor: Color?

    private var s: NotchAmbientSettings { ambient.settings.normalized() }
    private var controls: Set<NotchAmbientControl> { s.decoration.controls }

    var body: some View {
        Section {
            NotchAmbientSettingsPreview(settings: s, albumColors: workspace.media.artworkColors, wallpaperColor: wallpaperColor)
                .frame(height: 172)
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            Toggle("Enabled", isOn: binding(\.enabled))
            Text("Decorative only. Notch Ambient yields whenever a higher-priority notch owner needs the space, and never intercepts pointer events.")
                .font(.caption).foregroundStyle(.secondary)
        } header: { Text("Notch Ambient") }

        Section("Decoration") {
            Picker("Decoration", selection: binding(\.decoration)) {
                ForEach(NotchAmbientCategory.allCases.filter { $0 != .seasonal }) { category in
                    Section(category.rawValue) {
                        ForEach(NotchAmbientDecorationKind.allCases.filter { $0.category == category }) { kind in
                            Label(kind.rawValue, systemImage: kind.symbol).tag(kind)
                        }
                    }
                }
            }
            Picker("Activity", selection: binding(\.activity)) { ForEach(NotchAmbientActivityLevel.allCases) { Text($0.rawValue).tag($0) } }
            Text("Calm is recommended for a decoration that can stay visible for hours. Static removes decorative motion while retaining the composition.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("Presets") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 8)], spacing: 8) {
                ForEach(ambient.allPresets) { preset in presetCard(preset) }
            }
            HStack {
                Button("Randomize") { ambient.randomize() }
                Button("Reset") { ambient.reset() }
                Button("Duplicate Preset") { ambient.duplicateCurrent() }
            }
            HStack {
                TextField("Preset name", text: $presetName)
                Button("Save Preset") { let saved = ambient.saveCurrent(named: presetName); presetName = saved.name }
            }
        }

        appearanceSection
        if controls.contains(.cursor) || controls.contains(.audio) { interactionSection }
        motionSection
        environmentSection
        advancedSection
    }

    private func presetCard(_ preset: NotchAmbientPreset) -> some View {
        Button { ambient.apply(preset) } label: {
            VStack(alignment: .leading, spacing: 6) {
                NotchAmbientMiniPreview(settings: preset.settings)
                    .frame(height: 54)
                HStack(spacing: 5) {
                    Image(systemName: preset.settings.decoration.symbol).font(.caption)
                    Text(preset.name).font(.caption.weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 0)
                    if ambient.settings.presetID == preset.id { Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(Color.accentColor) }
                }
            }
            .padding(8)
            .background(Color.primary.opacity(ambient.settings.presetID == preset.id ? 0.09 : 0.035), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Color.primary.opacity(ambient.settings.presetID == preset.id ? 0.20 : 0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(ambient.settings.favoritePresetIDs.contains(preset.id) ? "Remove from Rotation" : "Add to Rotation") { ambient.setFavorite(preset.id, enabled: !ambient.settings.favoritePresetIDs.contains(preset.id)) }
            if !preset.builtIn { Button("Delete Saved Preset", role: .destructive) { ambient.removeSaved(preset.id) } }
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Color", selection: binding(\.colorSource)) { ForEach(NotchAmbientColorSource.allCases) { Text($0.rawValue).tag($0) } }
            if s.colorSource == .custom {
                ColorPicker("Primary", selection: colorBinding(\.primaryColor), supportsOpacity: false)
                ColorPicker("Secondary", selection: colorBinding(\.secondaryColor), supportsOpacity: false)
                ColorPicker("Tertiary", selection: colorBinding(\.tertiaryColor), supportsOpacity: false)
            }
            labeledSlider("Intensity", binding(\.intensity), 0...1)
            if controls.contains(.thickness) { labeledSlider("Thickness", binding(\.thickness), 0.5...18, suffix: " pt") }
            if controls.contains(.softness) { labeledSlider("Softness", binding(\.softness), 0...36, suffix: " pt") }
            if controls.contains(.falloff) { labeledSlider("Falloff", binding(\.falloff), 0...1) }
            if controls.contains(.bloom) { labeledSlider("Bloom", binding(\.bloom), 0...1) }
            if controls.contains(.underlineStyle) { Picker("Line style", selection: binding(\.underlineStyle)) { ForEach(NotchAmbientUnderlineStyle.allCases) { Text($0.rawValue).tag($0) } } }
            if controls.contains(.bulbShape) { Picker("Bulb shape", selection: binding(\.bulbShape)) { ForEach(NotchAmbientBulbShape.allCases) { Text($0.rawValue).tag($0) } } }
            if controls.contains(.foliageStyle) { Picker("Foliage style", selection: binding(\.foliageStyle)) { ForEach(NotchAmbientFoliageStyle.allCases) { Text($0.rawValue).tag($0) } } }
            if controls.contains(.portalStyle) { Picker("Portal environment", selection: binding(\.portalStyle)) { ForEach(NotchAmbientPortalStyle.allCases) { Text($0.rawValue).tag($0) } } }
        }
    }

    private var interactionSection: some View {
        Section("Interaction") {
            if controls.contains(.audio) {
                Picker("Audio reaction", selection: binding(\.audioReaction)) { ForEach(NotchAmbientAudioReaction.allCases) { Text($0.rawValue).tag($0) } }
                Text("Audio reaction changes lighting, energy or motion in a concept-appropriate way; it never turns the decoration into a generic equalizer.").font(.caption).foregroundStyle(.secondary)
            }
            if controls.contains(.cursor) {
                Picker("Cursor reaction", selection: binding(\.cursorReaction)) { ForEach(NotchAmbientCursorReaction.allCases) { Text($0.rawValue).tag($0) } }
                if s.cursorReaction != .off {
                    labeledSlider("Reaction radius", binding(\.reactionRadius), 40...420, suffix: " pt")
                    labeledSlider("Strength", binding(\.reactionStrength), 0...1)
                    labeledSlider("Smoothing", binding(\.reactionSmoothing), 0...1)
                }
                Text("Cursor reaction reads the global pointer position from a mouse-pass-through layer, so it cannot steal notch hover or clicks.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var motionSection: some View {
        Section("Motion") {
            labeledSlider("Animation speed", binding(\.speed), 0.02...3, suffix: "×")
            if controls.contains(.pulse) { labeledSlider("Pulse / breathing", binding(\.pulse), 0...1) }
            if controls.contains(.sway) { labeledSlider("Sway strength", binding(\.sway), 0...1) }
            if controls.contains(.flicker) { labeledSlider("Flicker", binding(\.flicker), 0...0.7) }
            if controls.contains(.wind) { labeledSlider("Wind", binding(\.wind), -1...1) }
            if controls.contains(.electricalFrequency) { labeledSlider("Arc frequency", binding(\.electricalFrequency), 0.01...1) }
            if controls.contains(.count) { integerSlider("Element count", binding(\.count), 1...64) }
            if controls.contains(.density) { labeledSlider("Density", binding(\.density), 0...1) }
            if controls.contains(.spacing) { labeledSlider("Spacing", binding(\.spacing), 0.25...3, suffix: "×") }
            if controls.contains(.length) { labeledSlider("Length", binding(\.length), 6...180, suffix: " pt") }
            if controls.contains(.distortion) { labeledSlider("Lens / distortion", binding(\.distortion), 0...1); Toggle("Screen-lens hint", isOn: binding(\.lensDistortion)) }
            if controls.contains(.splash) { Toggle("Splash / mist", isOn: binding(\.splash)) }
            if controls.contains(.accumulation) { Toggle("Edge accumulation", isOn: binding(\.accumulation)) }
            if controls.contains(.scanlines) { labeledSlider("Scanlines", binding(\.scanlines), 0...1) }
            if controls.contains(.glitch) { labeledSlider("Glitch probability", binding(\.glitch), 0...0.5) }
            Picker("Transition", selection: binding(\.transition)) { ForEach(NotchAmbientTransitionStyle.allCases) { Text($0.rawValue).tag($0) } }
            labeledSlider("Transition duration", binding(\.transitionDuration), 0.08...1.5, suffix: " s")
        }
    }

    private var environmentSection: some View {
        Section("Environment") {
            Toggle("Evolve through the day", isOn: binding(\.timeBasedAppearance))
            Picker("Seasonal mode", selection: binding(\.seasonMode)) { ForEach(NotchAmbientSeasonMode.allCases) { Text($0.rawValue).tag($0) } }
            if s.seasonMode == .manual { Picker("Season", selection: binding(\.manualSeason)) { ForEach(NotchAmbientSeason.allCases) { Text($0.rawValue).tag($0) } } }
            if s.seasonMode == .automatic { Picker("Hemisphere", selection: binding(\.hemisphere)) { ForEach(NotchAmbientHemisphere.allCases) { Text($0.rawValue).tag($0) } } }
            if controls.contains(.symmetry) { Picker("Symmetry", selection: binding(\.symmetry)) { ForEach(NotchAmbientSymmetry.allCases) { Text($0.rawValue).tag($0) } } }
            if controls.contains(.placement) { Picker("Placement", selection: binding(\.placement)) { ForEach(NotchAmbientPlacement.allCases) { Text($0.rawValue).tag($0) } } }
            Text("Seasonal variations are opt-in. Automatic season follows the local region/hemisphere but never enables holiday decorations by itself.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var advancedSection: some View {
        Section("Advanced") {
            Picker("Rotation", selection: binding(\.rotationMode)) { ForEach(NotchAmbientRotationMode.allCases) { Text($0.rawValue).tag($0) } }
            if s.rotationMode != .off {
                Text("Favorite presets used by rotation").font(.caption.weight(.semibold))
                ForEach(ambient.allPresets) { preset in
                    Toggle(preset.name, isOn: favoriteBinding(preset.id))
                }
            }
            Toggle("Adapt for Low Power Mode", isOn: binding(\.lowPowerAdaptive))
            Toggle("Yield to persistent closed-notch content", isOn: binding(\.yieldToPersistentClosedContent))
            labeledSlider("Horizontal canvas", binding(\.horizontalExtent), 80...280, suffix: " pt")
            labeledSlider("Vertical canvas", binding(\.verticalExtent), 72...260, suffix: " pt")
            Text("The runtime canvas is a separate transparent, click-through layer. It follows the real/simulated notch and closed-notch offsets without increasing Halo's interactive hit area. Reduce Motion automatically substitutes static treatments and Low Power Mode lowers particle/update cost.").font(.caption).foregroundStyle(.secondary)
            DisclosureGroup("Decoration Studio architecture") {
                Text("Built-in decorations already resolve through reusable Shape, Image, Animated Image, Video, Particle Emitter, Glow, Line, Gradient, Shader and Procedural layer roles with explicit depth. The manifest contract is versioned so a future Decoration Studio and importable packs can add assets, layers, animations, reactions and previews without replacing the runtime ownership system.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear { updateWallpaper() }
        .onChange(of: ambient.settings.colorSource) { _ in updateWallpaper() }
    }

    private func binding<T>(_ path: WritableKeyPath<NotchAmbientSettings, T>) -> Binding<T> {
        Binding(get: { ambient.settings[keyPath: path] }, set: { ambient.update(path, $0) })
    }
    private func colorBinding(_ path: WritableKeyPath<NotchAmbientSettings, WidgetColor>) -> Binding<Color> {
        Binding(get: { ambient.settings[keyPath: path].color }, set: { ambient.update(path, WidgetColor($0)) })
    }
    private func favoriteBinding(_ id: String) -> Binding<Bool> {
        Binding(get: { ambient.settings.favoritePresetIDs.contains(id) }, set: { ambient.setFavorite(id, enabled: $0) })
    }
    private func labeledSlider(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, suffix: String = "") -> some View {
        HStack { Text(title); Slider(value: value, in: range); Text(String(format: range.upperBound <= 3 ? "%.2f%@" : "%.0f%@", value.wrappedValue, suffix)).font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(minWidth: 48, alignment: .trailing) }
    }
    private func integerSlider(_ title: String, _ value: Binding<Int>, _ range: ClosedRange<Int>) -> some View {
        HStack { Text(title); Slider(value: Binding(get:{ Double(value.wrappedValue) },set:{ value.wrappedValue=Int($0.rounded()) }), in: Double(range.lowerBound)...Double(range.upperBound), step:1); Text("\(value.wrappedValue)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width:32,alignment:.trailing) }
    }
    private func updateWallpaper() {
        guard ambient.settings.colorSource == .wallpaper else { return }
        wallpaperColor = NotchAmbientWallpaperSampler.sample(screenFrame: (NSScreen.main ?? NSScreen.screens.first)?.frame ?? .zero)
    }
}

private struct NotchAmbientSettingsPreview: View {
    let settings: NotchAmbientSettings
    let albumColors: [WidgetColor]
    let wallpaperColor: Color?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack(alignment:.top) {
            LinearGradient(colors:[Color.black.opacity(0.96),Color(red:0.045,green:0.055,blue:0.08)],startPoint:.top,endPoint:.bottom)
            NotchAmbientRuntimeCanvas(settings: settings, notchWidth: 176, notchHeight: 32, albumColors: albumColors,
                                      wallpaperColor: wallpaperColor, screenFrame: .zero,
                                      lowPower: false, reduceMotion: reduceMotion)
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black).frame(width:176,height:42).offset(y:-10)
            Text(settings.decoration.rawValue.uppercased()).font(.system(size:8,weight:.semibold,design:.monospaced)).tracking(1).foregroundStyle(.white.opacity(0.30)).padding(.top,8)
        }
        .clipShape(RoundedRectangle(cornerRadius:14,style:.continuous))
        .overlay(RoundedRectangle(cornerRadius:14,style:.continuous).stroke(Color.white.opacity(0.08),lineWidth:1))
    }
}

private struct NotchAmbientMiniPreview: View {
    let settings: NotchAmbientSettings
    var body: some View {
        ZStack(alignment:.top) {
            Color.black.opacity(0.88)
            NotchAmbientArtwork(settings: { var x=settings; x.activity = .staticMode; return x }(), notchWidth: 58, notchHeight: 14,
                                phase: 0.5, audio: 0, cursor: nil,
                                palette: NotchAmbientPaletteResolver.colors(settings: settings, album: [], wallpaper: nil, date: Date()),
                                lowPower: true, reduceMotion: true, date: Date())
            RoundedRectangle(cornerRadius:4).fill(Color.black).frame(width:58,height:19).offset(y:-5)
        }
        .clipShape(RoundedRectangle(cornerRadius:7,style:.continuous))
    }
}
