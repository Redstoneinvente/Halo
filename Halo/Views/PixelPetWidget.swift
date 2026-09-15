import SwiftUI
import AppKit
import CoreGraphics

// MARK: - Pixel Pal v2
// Canonical direction: Docs/PixelPalV2.md
// Premium, face-first pixel character. Authored sprite data is the source of truth.
// No body, room, habitat, hunger/energy loop, dashboard, or care-game mechanics.

enum HaloPixelPalExpression: String, Codable, CaseIterable, Identifiable {
    case neutral
    case blink
    case happy
    case superHappy
    case excited
    case love
    case sleepy
    case bored
    case focused
    case surprised
    case shocked
    case confused
    case dizzy
    case worried
    case sad
    case crying
    case shy
    case mischievous
    case smug
    case annoyed
    case furious
    case wink
    case music

    var id: String { rawValue }

    var title: String {
        switch self {
        case .superHappy: return "Super Happy"
        default: return rawValue.capitalized
        }
    }
}

enum HaloPixelPalFaceStyle: String, Codable, CaseIterable, Identifiable {
    case soft = "Soft"
    case minimal = "Minimal"
    case robot = "Robot"
    case cat = "Cat"

    var id: String { rawValue }
}

enum HaloPixelPalEyeStyle: String, Codable, CaseIterable, Identifiable {
    case glossy = "Glossy"
    case classic = "Classic"
    case dot = "Dot"
    case wide = "Wide"
    case digital = "Digital"
    case sparkle = "Sparkle"

    var id: String { rawValue }
}

enum HaloPixelPalMouthStyle: String, Codable, CaseIterable, Identifiable {
    case automatic = "Expression"
    case none = "None"
    case tiny = "Tiny"
    case smile = "Smile"
    case flat = "Flat"
    case cat = "Cat"
    case open = "Open"

    var id: String { rawValue }
}

enum HaloPixelPalCheekStyle: String, Codable, CaseIterable, Identifiable {
    case none = "None"
    case soft = "Soft"
    case kawaii = "Kawaii"
    case shy = "Shy"

    var id: String { rawValue }
}

enum HaloPixelPalAccessory: String, Codable, CaseIterable, Identifiable {
    case none = "None"
    case bow = "Bow"
    case catEars = "Cat Ears"
    case glasses = "Glasses"
    case shades = "Shades"
    case headphones = "Headphones"
    case halo = "Halo"
    case horns = "Horns"
    case flower = "Flower"
    case sleepingCap = "Sleeping Cap"
    case crown = "Crown"
    case sprout = "Sprout"
    case bandage = "Bandage"

    var id: String { rawValue }
}

enum HaloPixelPalAccessoryMode: String, Codable, CaseIterable, Identifiable {
    case off = "Off"
    case manual = "Manual"
    case contextual = "Contextual"
    case randomAllowed = "Random Allowed"

    var id: String { rawValue }
}

enum HaloPixelPalBackgroundStyle: String, Codable, CaseIterable, Identifiable {
    case transparent = "Transparent"
    case black = "Black"
    case custom = "Custom"
    case glow = "Soft Glow"

    var id: String { rawValue }
}

enum HaloPixelPalPalette: String, Codable, CaseIterable, Identifiable {
    case white = "Pearl"
    case green = "Mint"
    case amber = "Amber"
    case cyan = "Sky"
    case pink = "Sakura"
    case purple = "Lavender"
    case red = "Coral"
    case custom = "Custom"

    var id: String { rawValue }
}

struct HaloPixelPalRGB: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double

    var color: Color {
        Color(
            red: min(1, max(0, red)),
            green: min(1, max(0, green)),
            blue: min(1, max(0, blue))
        )
    }
}

struct HaloPixelPalPreferences: Codable, Equatable {
    // Legacy persisted field retained so Codable stays backward-compatible.
    var showCheeks: Bool = true
    var version = 7

    // Appearance
    var faceStyle: HaloPixelPalFaceStyle = .soft
    var eyeStyle: HaloPixelPalEyeStyle = .glossy
    var mouthStyle: HaloPixelPalMouthStyle = .automatic
    var cheekStyle: HaloPixelPalCheekStyle = .soft
    var palette: HaloPixelPalPalette = .white
    var customColor = HaloPixelPalRGB(red: 0.90, green: 0.96, blue: 1.0)
    var accentColor = HaloPixelPalRGB(red: 1.0, green: 0.42, blue: 0.68)
    var blushColor = HaloPixelPalRGB(red: 1.0, green: 0.38, blue: 0.58)
    var backgroundStyle: HaloPixelPalBackgroundStyle = .transparent
    var backgroundColor = HaloPixelPalRGB(red: 0.025, green: 0.025, blue: 0.035)
    var backgroundOpacity = 1.0
    var backgroundCornerRadius = 0.0
    var pixelCornerRadius = 0.0
    var inactiveLEDIntensity = 0.075
    var inactiveLEDUsesFaceColor = true
    var inactiveLEDColor = HaloPixelPalRGB(red: 0.36, green: 0.40, blue: 0.46)
    var faceScale = 1.0
    var glowIntensity = 0.10

    // Accessories
    var accessoryMode: HaloPixelPalAccessoryMode = .contextual
    var selectedAccessory: HaloPixelPalAccessory = .none
    var allowedAccessories: [HaloPixelPalAccessory] = HaloPixelPalAccessory.allCases.filter { $0 != .none }

    // Animation
    var automaticBlinking = true
    var animationSpeed = 1.0
    var animationIntensity = 0.85
    var dizzyRotationThresholdTurns = 0.8

    // Direct interactions
    var hoverReaction = true
    var tapReaction = true
    var doubleTapReaction = true
    var longPressReaction = true

    // Context reactions
    var contextReactions = true
    var chargingReaction = true
    var lowBatteryReaction = true
    var musicReaction = true
    var timerReaction = true
    var appReaction = true
    var idleReaction = true
    var nightReaction = true

    init() {}

    private enum CodingKeys: String, CodingKey {
        case version
        case faceStyle, eyeStyle, mouthStyle, cheekStyle, palette, customColor, accentColor, blushColor
        case backgroundStyle, backgroundColor, backgroundOpacity, backgroundCornerRadius, pixelCornerRadius, inactiveLEDIntensity, inactiveLEDUsesFaceColor, inactiveLEDColor, faceScale, glowIntensity
        case accessoryMode, selectedAccessory, allowedAccessories
        case automaticBlinking, animationSpeed, animationIntensity, dizzyRotationThresholdTurns
        case hoverReaction, tapReaction, doubleTapReaction, longPressReaction
        case contextReactions, chargingReaction, lowBatteryReaction, musicReaction
        case timerReaction, appReaction, idleReaction, nightReaction
        // v3 legacy
        case showCheeks
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = 7
        faceStyle = try c.decodeIfPresent(HaloPixelPalFaceStyle.self, forKey: .faceStyle) ?? .soft
        eyeStyle = try c.decodeIfPresent(HaloPixelPalEyeStyle.self, forKey: .eyeStyle) ?? .glossy
        mouthStyle = try c.decodeIfPresent(HaloPixelPalMouthStyle.self, forKey: .mouthStyle) ?? .automatic
        if let decodedCheeks = try c.decodeIfPresent(HaloPixelPalCheekStyle.self, forKey: .cheekStyle) {
            cheekStyle = decodedCheeks
        } else {
            cheekStyle = (try c.decodeIfPresent(Bool.self, forKey: .showCheeks) ?? true) ? .soft : .none
        }
        palette = try c.decodeIfPresent(HaloPixelPalPalette.self, forKey: .palette) ?? .white
        customColor = try c.decodeIfPresent(HaloPixelPalRGB.self, forKey: .customColor) ?? HaloPixelPalRGB(red: 0.90, green: 0.96, blue: 1.0)
        accentColor = try c.decodeIfPresent(HaloPixelPalRGB.self, forKey: .accentColor) ?? HaloPixelPalRGB(red: 1.0, green: 0.42, blue: 0.68)
        blushColor = try c.decodeIfPresent(HaloPixelPalRGB.self, forKey: .blushColor) ?? HaloPixelPalRGB(red: 1.0, green: 0.38, blue: 0.58)
        backgroundStyle = try c.decodeIfPresent(HaloPixelPalBackgroundStyle.self, forKey: .backgroundStyle) ?? .transparent
        backgroundColor = try c.decodeIfPresent(HaloPixelPalRGB.self, forKey: .backgroundColor) ?? HaloPixelPalRGB(red: 0.025, green: 0.025, blue: 0.035)
        backgroundOpacity = try c.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? 1.0
        backgroundCornerRadius = try c.decodeIfPresent(Double.self, forKey: .backgroundCornerRadius) ?? 0.0
        pixelCornerRadius = try c.decodeIfPresent(Double.self, forKey: .pixelCornerRadius) ?? 0.0
        inactiveLEDIntensity = try c.decodeIfPresent(Double.self, forKey: .inactiveLEDIntensity) ?? 0.075
        inactiveLEDUsesFaceColor = try c.decodeIfPresent(Bool.self, forKey: .inactiveLEDUsesFaceColor) ?? true
        inactiveLEDColor = try c.decodeIfPresent(HaloPixelPalRGB.self, forKey: .inactiveLEDColor) ?? HaloPixelPalRGB(red: 0.36, green: 0.40, blue: 0.46)
        faceScale = try c.decodeIfPresent(Double.self, forKey: .faceScale) ?? 1.0
        glowIntensity = try c.decodeIfPresent(Double.self, forKey: .glowIntensity) ?? 0.10

        accessoryMode = try c.decodeIfPresent(HaloPixelPalAccessoryMode.self, forKey: .accessoryMode) ?? .contextual
        selectedAccessory = try c.decodeIfPresent(HaloPixelPalAccessory.self, forKey: .selectedAccessory) ?? .none
        allowedAccessories = try c.decodeIfPresent([HaloPixelPalAccessory].self, forKey: .allowedAccessories)
            ?? HaloPixelPalAccessory.allCases.filter { $0 != .none }

        automaticBlinking = try c.decodeIfPresent(Bool.self, forKey: .automaticBlinking) ?? true
        animationSpeed = try c.decodeIfPresent(Double.self, forKey: .animationSpeed) ?? 1.0
        animationIntensity = try c.decodeIfPresent(Double.self, forKey: .animationIntensity) ?? 0.85
        dizzyRotationThresholdTurns = try c.decodeIfPresent(Double.self, forKey: .dizzyRotationThresholdTurns) ?? 0.8

        hoverReaction = try c.decodeIfPresent(Bool.self, forKey: .hoverReaction) ?? true
        tapReaction = try c.decodeIfPresent(Bool.self, forKey: .tapReaction) ?? true
        doubleTapReaction = try c.decodeIfPresent(Bool.self, forKey: .doubleTapReaction) ?? true
        longPressReaction = try c.decodeIfPresent(Bool.self, forKey: .longPressReaction) ?? true

        contextReactions = try c.decodeIfPresent(Bool.self, forKey: .contextReactions) ?? true
        chargingReaction = try c.decodeIfPresent(Bool.self, forKey: .chargingReaction) ?? true
        lowBatteryReaction = try c.decodeIfPresent(Bool.self, forKey: .lowBatteryReaction) ?? true
        musicReaction = try c.decodeIfPresent(Bool.self, forKey: .musicReaction) ?? true
        timerReaction = try c.decodeIfPresent(Bool.self, forKey: .timerReaction) ?? true
        appReaction = try c.decodeIfPresent(Bool.self, forKey: .appReaction) ?? true
        idleReaction = try c.decodeIfPresent(Bool.self, forKey: .idleReaction) ?? true
        nightReaction = try c.decodeIfPresent(Bool.self, forKey: .nightReaction) ?? true
    }

    func normalized() -> Self {
        var value = self
        value.version = 7
        value.animationSpeed = min(2.0, max(0.35, animationSpeed))
        value.animationIntensity = min(1.0, max(0.0, animationIntensity))
        value.dizzyRotationThresholdTurns = min(2.0, max(0.35, dizzyRotationThresholdTurns))
        value.faceScale = min(1.0, max(0.76, faceScale))
        value.glowIntensity = min(1.0, max(0.0, glowIntensity))
        value.backgroundOpacity = min(1.0, max(0.0, backgroundOpacity))
        value.backgroundCornerRadius = min(0.5, max(0.0, backgroundCornerRadius))
        value.pixelCornerRadius = min(0.5, max(0.0, pixelCornerRadius))
        value.inactiveLEDIntensity = min(0.35, max(0.0, inactiveLEDIntensity))
        value.customColor = Self.clamped(customColor)
        value.accentColor = Self.clamped(accentColor)
        value.blushColor = Self.clamped(blushColor)
        value.backgroundColor = Self.clamped(backgroundColor)
        value.inactiveLEDColor = Self.clamped(inactiveLEDColor)
        value.allowedAccessories = Array(Set(allowedAccessories.filter { $0 != .none }))
            .sorted { $0.rawValue < $1.rawValue }
        return value
    }

    private static func clamped(_ value: HaloPixelPalRGB) -> HaloPixelPalRGB {
        HaloPixelPalRGB(
            red: min(1, max(0, value.red)),
            green: min(1, max(0, value.green)),
            blue: min(1, max(0, value.blue))
        )
    }

    var faceColor: Color {
        switch palette {
        case .white: return Color(red: 0.96, green: 0.98, blue: 1.0)
        case .green: return Color(red: 0.45, green: 1.0, blue: 0.72)
        case .amber: return Color(red: 1.0, green: 0.73, blue: 0.31)
        case .cyan: return Color(red: 0.45, green: 0.91, blue: 1.0)
        case .pink: return Color(red: 1.0, green: 0.58, blue: 0.78)
        case .purple: return Color(red: 0.76, green: 0.64, blue: 1.0)
        case .red: return Color(red: 1.0, green: 0.45, blue: 0.44)
        case .custom: return customColor.color
        }
    }
}

// MARK: - Sprite model

private enum HaloPixelPalColorRole: Character {
    case primary = "p"
    case accent = "a"
    case blush = "b"
    case white = "w"
    case shadow = "s"
    case accessoryFrame = "g"
    case accessoryLens = "l"
}

private struct HaloPixelPalSprite {
    let rows: [String]

    var width: Int { rows.map(\.count).max() ?? 0 }
    var height: Int { rows.count }
}

private struct HaloPixelPalPlacedSprite {
    let sprite: HaloPixelPalSprite
    let x: Int
    let y: Int
    let mirrorX: Bool

    init(_ sprite: HaloPixelPalSprite, x: Int, y: Int, mirrorX: Bool = false) {
        self.sprite = sprite
        self.x = x
        self.y = y
        self.mirrorX = mirrorX
    }
}

private enum HaloPixelPalSprites {
    // Eyes are authored components. They are intentionally higher-resolution than v1/v3.
    static func openEye(_ style: HaloPixelPalEyeStyle) -> HaloPixelPalSprite {
        switch style {
        case .glossy:
            return .init(rows: [
                ".pppp.",
                "pwwssp",
                "pwsssp",
                "pssssp",
                "ppsspp",
                ".aaaa."
            ])
        case .classic:
            return .init(rows: [
                ".pp..",
                "ppp..",
                "pwp..",
                "ppp.."
            ])
        case .dot:
            return .init(rows: [
                "pp",
                "pp"
            ])
        case .wide:
            return .init(rows: [
                ".pppp.",
                "ppwppp",
                "pppppp",
                ".aaaa."
            ])
        case .digital:
            return .init(rows: [
                "pppp.",
                "p..p.",
                "p.wp.",
                "pppp."
            ])
        case .sparkle:
            return .init(rows: [
                "..a..",
                ".apa.",
                "apwpa",
                ".apa.",
                "..a.."
            ])
        }
    }

    static func closedEye(_ style: HaloPixelPalEyeStyle) -> HaloPixelPalSprite {
        switch style {
        case .dot:
            return .init(rows: ["pp"])
        case .wide:
            return .init(rows: ["ppppp"])
        case .sparkle:
            return .init(rows: [".apa."])
        default:
            return .init(rows: [".ppp.", "p...p"])
        }
    }

    static func happyEye(_ style: HaloPixelPalEyeStyle) -> HaloPixelPalSprite {
        switch style {
        case .dot:
            return .init(rows: ["p.p", ".p."])
        case .wide:
            return .init(rows: ["p...p", ".ppp."])
        case .digital:
            return .init(rows: ["p..p", ".pp."])
        case .sparkle:
            return .init(rows: ["a...a", ".apa.", "..p.."])
        case .classic, .glossy:
            return .init(rows: ["..p..", ".p.p.", "p...p"])
        }
    }

    static let heartEye = HaloPixelPalSprite(rows: [
        ".aa.aa.",
        "aaaaaaa",
        ".aaaaa.",
        "..aaa..",
        "...a..."
    ])

    static let starEye = HaloPixelPalSprite(rows: [
        "..a..",
        "a.a.a",
        ".apa.",
        "a.a.a",
        "..a.."
    ])

    static let xEye = HaloPixelPalSprite(rows: [
        "p...p",
        ".p.p.",
        "..p..",
        ".p.p.",
        "p...p"
    ])
    static let winkEye = HaloPixelPalSprite(rows: [
        "p...p",
        ".ppp."
    ])
    static let furiousEye = HaloPixelPalSprite(rows: [
        "ppppp",
        ".ppp.",
        "..p.."
    ])

    static let worriedBrow = HaloPixelPalSprite(rows: ["pp..."])
    static let annoyedBrow = HaloPixelPalSprite(rows: ["..ppp"])
    static let furiousBrow = HaloPixelPalSprite(rows: [
        "pp...",
        ".pp..",
        "..pp."
    ])
    static let raisedBrow = HaloPixelPalSprite(rows: [".pp.."])

    static let mouthTiny = HaloPixelPalSprite(rows: [
        "p.p",
        ".p."
    ])
    static let mouthFlat = HaloPixelPalSprite(rows: ["ppppp"])
    static let mouthSmile = HaloPixelPalSprite(rows: [
        "p...p",
        ".p.p.",
        "..p.."
    ])
    static let mouthBigSmile = HaloPixelPalSprite(rows: [
        "p.....p",
        ".ppppp.",
        ".pwwwp.",
        "..aaa.."
    ])
    static let mouthOpen = HaloPixelPalSprite(rows: [
        ".ppp.",
        "p...p",
        "p.a.p",
        ".ppp."
    ])
    static let mouthO = HaloPixelPalSprite(rows: [
        ".pp.",
        "p..p",
        "p..p",
        ".pp."
    ])
    static let mouthFrown = HaloPixelPalSprite(rows: [
        "..p..",
        ".p.p.",
        "p...p"
    ])
    static let mouthGrimace = HaloPixelPalSprite(rows: [
        ".ppppp.",
        "pwwwwwp",
        ".ppppp."
    ])
    static let mouthCat = HaloPixelPalSprite(rows: [
        "p.p.p",
        ".p.p."
    ])
    static let mouthSmug = HaloPixelPalSprite(rows: [
        "....p",
        ".ppp."
    ])

    static let cheekSoft = HaloPixelPalSprite(rows: [".bb."])
    static let cheekKawaii = HaloPixelPalSprite(rows: ["bbbb", ".bb."])
    static let cheekShy = HaloPixelPalSprite(rows: ["b..b", ".bb."])

    static let tear = HaloPixelPalSprite(rows: [
        "a",
        "a",
        "w"
    ])
    static let sweat = HaloPixelPalSprite(rows: [
        ".a",
        "aa",
        ".a"
    ])
    static let sparkle = HaloPixelPalSprite(rows: [
        ".a.",
        "awa",
        ".a."
    ])
    static let heart = HaloPixelPalSprite(rows: [
        "a.a",
        "aaa",
        ".a."
    ])
    static let musicNote = HaloPixelPalSprite(rows: [
        ".aa",
        "..a",
        "..a",
        ".aa",
        ".a."
    ])
    static let exclamation = HaloPixelPalSprite(rows: [
        "a",
        "a",
        "a",
        ".",
        "a"
    ])

    static let zSmall = HaloPixelPalSprite(rows: [
        "aaa",
        "..a",
        ".a.",
        "aaa"
    ])
    static let zTiny = HaloPixelPalSprite(rows: [
        "aa",
        ".a",
        "aa"
    ])

    // Accessories
    static let bow = HaloPixelPalSprite(rows: [
        "aa...aa",
        "aaa.aaa",
        ".aaaaa.",
        "...a..."
    ])
    static let catEar = HaloPixelPalSprite(rows: [
        "p...p",
        "pp.pp",
        "p...p"
    ])
    static let glasses = HaloPixelPalSprite(rows: [
        "gggg...gggg",
        "g..g.g.g..g",
        "gggg...gggg"
    ])
    static let shades = HaloPixelPalSprite(rows: [
        "ggggg.ggggg",
        "glllg.glllg",
        ".ggg...ggg."
    ])
    static let headphones = HaloPixelPalSprite(rows: [
        "..ppppppp..",
        ".p.......p.",
        "pp.......pp",
        "pa.......ap"
    ])
    static let halo = HaloPixelPalSprite(rows: [
        "..aaaaa..",
        ".a.....a.",
        "..aaaaa.."
    ])
    static let horns = HaloPixelPalSprite(rows: [
        "p.......p",
        "pp.....pp",
        ".p.....p."
    ])
    static let flower = HaloPixelPalSprite(rows: [
        ".a.",
        "apa",
        ".a."
    ])
    static let sleepingCap = HaloPixelPalSprite(rows: [
        "....aaa...",
        "...aaaaa..",
        "..aaaaaaa.",
        ".aaaaaaaaa",
        "pppppppppp",
        ".........a"
    ])
    static let crown = HaloPixelPalSprite(rows: [
        "a..a..a",
        "aa.a.aa",
        ".aaaaa.",
        ".aaaaa."
    ])
    static let sprout = HaloPixelPalSprite(rows: [
        ".a.a.",
        "..a..",
        "..a.."
    ])
    static let bandage = HaloPixelPalSprite(rows: [
        "ppppp",
        "pwwwp",
        "ppppp"
    ])
}

// MARK: - Store and context

struct HaloPixelPalTapBurst {
    static let window: TimeInterval = 1.2
    static let threshold = 5

    private(set) var tapTimes: [TimeInterval] = []

    mutating func register(count: Int, at now: TimeInterval) -> Bool {
        tapTimes.removeAll { now - $0 > Self.window }
        tapTimes.append(contentsOf: repeatElement(now, count: max(1, count)))
        guard tapTimes.count >= Self.threshold else { return false }
        tapTimes.removeAll(keepingCapacity: true)
        return true
    }

    mutating func reset() {
        tapTimes.removeAll(keepingCapacity: true)
    }
}

struct HaloPixelPalCursorOrbitDetector {
    private struct Sample {
        let time: TimeInterval
        let angle: Double
        let radius: Double
        let x: Double
        let y: Double
    }

    // One quick, natural circle should be enough.
    static let sampleWindow: TimeInterval = 1.15
    static let cooldown: TimeInterval = 2.0
    static let minimumDuration: TimeInterval = 0.12
    static let minimumPathSpeed = 0.85
    static let minimumDirectionConsistency = 0.55
    static let minimumRadius = 0.08
    static let maximumRadius = 0.68
    static let maximumRadiusSpread = 0.36
    static let minimumSamples = 6

    private var samples: [Sample] = []
    private var lastTrigger = -Double.infinity

    mutating func register(location: CGPoint, size: CGSize, at now: TimeInterval, minimumRotationTurns: Double) -> Bool {
        guard size.width > 1, size.height > 1 else {
            resetPath()
            return false
        }

        if now - lastTrigger < Self.cooldown {
            resetPath()
            return false
        }

        let side = Double(min(size.width, size.height))
        let dx = (Double(location.x) - Double(size.width) * 0.5) / side
        let dy = (Double(location.y) - Double(size.height) * 0.5) / side
        let radius = hypot(dx, dy)
        guard radius >= Self.minimumRadius, radius <= Self.maximumRadius else {
            resetPath()
            return false
        }

        if let last = samples.last, now - last.time > 0.28 {
            resetPath()
        }

        samples.append(.init(time: now, angle: atan2(dy, dx), radius: radius, x: dx, y: dy))
        samples.removeAll { now - $0.time > Self.sampleWindow }

        guard samples.count >= Self.minimumSamples,
              let first = samples.first,
              let last = samples.last else { return false }

        let duration = last.time - first.time
        guard duration >= Self.minimumDuration else { return false }

        var signedRotation = 0.0
        var absoluteRotation = 0.0
        var pathDistance = 0.0
        var minRadius = Double.greatestFiniteMagnitude
        var maxRadius = 0.0

        for index in samples.indices {
            let sample = samples[index]
            minRadius = min(minRadius, sample.radius)
            maxRadius = max(maxRadius, sample.radius)
            guard index > samples.startIndex else { continue }

            let previous = samples[index - 1]
            var delta = sample.angle - previous.angle
            while delta > .pi { delta -= 2 * .pi }
            while delta < -.pi { delta += 2 * .pi }
            signedRotation += delta
            absoluteRotation += abs(delta)
            pathDistance += hypot(sample.x - previous.x, sample.y - previous.y)
        }

        guard absoluteRotation > 0.001 else { return false }
        let directionConsistency = abs(signedRotation) / absoluteRotation
        let pathSpeed = pathDistance / duration
        let radiusSpread = maxRadius - minRadius
        let minimumRotation = Double.pi * 2.0 * min(2.0, max(0.35, minimumRotationTurns))

        guard abs(signedRotation) >= minimumRotation,
              directionConsistency >= Self.minimumDirectionConsistency,
              pathSpeed >= Self.minimumPathSpeed,
              radiusSpread <= Self.maximumRadiusSpread else { return false }

        lastTrigger = now
        resetPath()
        return true
    }

    mutating func resetPath() {
        samples.removeAll(keepingCapacity: true)
    }
}
@MainActor
final class HaloPixelPalStore: ObservableObject {
    static let shared = HaloPixelPalStore()

    @Published var preferences: HaloPixelPalPreferences {
        didSet { persist() }
    }
    @Published private(set) var reaction: HaloPixelPalExpression?
    @Published private(set) var reactionStarted = Date()
    @Published private(set) var cookieRescueStarted: Date?
    private var tapIndex = 0
    private var pressIndex = 0
    private var tapBurst = HaloPixelPalTapBurst()

    private let defaults: UserDefaults
    private let preferencesKey = "HaloPixelPal.preferences.v4"
    private let legacyKeys = ["HaloPixelPal.preferences.v3", "HaloPixelPal.preferences.v2"]
    private var clearReactionWork: DispatchWorkItem?
    private var cookieRescueWork: DispatchWorkItem?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: preferencesKey),
           let decoded = try? JSONDecoder().decode(HaloPixelPalPreferences.self, from: data) {
            preferences = decoded.normalized()
            return
        }

        for key in legacyKeys {
            if let data = defaults.data(forKey: key),
               let decoded = try? JSONDecoder().decode(HaloPixelPalPreferences.self, from: data) {
                preferences = decoded.normalized()
                persist()
                return
            }
        }
        preferences = HaloPixelPalPreferences()
    }

    func update<T>(_ keyPath: WritableKeyPath<HaloPixelPalPreferences, T>, _ value: T) {
        var next = preferences
        next[keyPath: keyPath] = value
        preferences = next.normalized()
    }

    func react(_ expression: HaloPixelPalExpression, seconds: Double = 1.7) {
        clearReactionWork?.cancel()
        if expression != .furious {
            cookieRescueWork?.cancel()
            cookieRescueStarted = nil
        }
        reactionStarted = Date()
        reaction = expression
        let work = DispatchWorkItem { [weak self] in self?.reaction = nil }
        clearReactionWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    func tapped() {
        guard preferences.tapReaction, reaction != .furious else { return }
        if let escalation = escalatedTapReaction(forPhysicalTapCount: 1) {
            react(escalation, seconds: escalation == .furious ? 2.82 : 3.4)
            return
        }
        let sequence: [HaloPixelPalExpression] = [.happy, .shy, .mischievous, .superHappy, .confused]
        react(sequence[tapIndex % sequence.count])
        tapIndex += 1
    }

    func doubleTapped() {
        guard preferences.doubleTapReaction, reaction != .furious else { return }
        if let escalation = escalatedTapReaction(forPhysicalTapCount: 2) {
            react(escalation, seconds: escalation == .furious ? 2.82 : 3.4)
            return
        }
        react(.love, seconds: 2.2)
    }

    private func escalatedTapReaction(forPhysicalTapCount count: Int) -> HaloPixelPalExpression? {
        let triggered = tapBurst.register(count: count, at: Date().timeIntervalSinceReferenceDate)
        if reaction == .annoyed {
            return triggered ? .furious : .annoyed
        }
        return triggered ? .annoyed : nil
    }

    func feedFuryCookie() {
        guard reaction == .furious, cookieRescueStarted == nil else { return }
        clearReactionWork?.cancel()
        let started = Date()
        cookieRescueStarted = started
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.reaction == .furious, self.cookieRescueStarted == started else { return }
            self.cookieRescueStarted = nil
            self.react(.happy, seconds: 2.4)
        }
        cookieRescueWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62, execute: work)
    }

    func longPressed() {
        guard preferences.longPressReaction else { return }
        let sequence: [HaloPixelPalExpression] = [.sleepy, .shy, .smug]
        react(sequence[pressIndex % sequence.count], seconds: 2.4)
        pressIndex += 1
    }

    func reset() {
        preferences = HaloPixelPalPreferences()
        reaction = nil
        clearReactionWork?.cancel()
        cookieRescueWork?.cancel()
        cookieRescueStarted = nil
        tapIndex = 0
        pressIndex = 0
        tapBurst.reset()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(preferences.normalized()) {
            defaults.set(data, forKey: preferencesKey)
        }
    }
}

private enum HaloPixelPalFX {
    case none, hearts, sparkle, dizzy, music, sweat, tears, alert, sleepZ
}

private struct HaloPixelPalContext {
    let expression: HaloPixelPalExpression
    let accessory: HaloPixelPalAccessory?
    let fx: HaloPixelPalFX

    @MainActor
    static func resolve(
        store: AppStore,
        media: MediaService,
        system: SystemService,
        pal: HaloPixelPalStore,
        hovering: Bool,
        date: Date
    ) -> Self {
        if let reaction = pal.reaction {
            return .init(
                expression: reaction,
                accessory: (reaction == .annoyed || reaction == .furious) ? .horns : nil,
                fx: fx(for: reaction)
            )
        }

        let p = pal.preferences
        let resting: Self = hovering && p.hoverReaction
            ? .init(expression: .happy, accessory: nil, fx: .none)
            : .init(expression: .neutral, accessory: nil, fx: .none)
        guard p.contextReactions else { return resting }

        if p.timerReaction && store.finished {
            return .init(expression: .shocked, accessory: nil, fx: .alert)
        }
        if p.lowBatteryReaction, let battery = system.battery, battery <= 15 {
            return .init(expression: .worried, accessory: .bandage, fx: .sweat)
        }
        if p.chargingReaction, let battery = system.battery, battery >= 100, !system.onBattery {
            return .init(expression: .superHappy, accessory: .crown, fx: .sparkle)
        }
        if p.chargingReaction && system.charging {
            return .init(expression: .love, accessory: .halo, fx: .hearts)
        }
        if p.musicReaction && media.isPlaying {
            return .init(expression: .music, accessory: .headphones, fx: .music)
        }
        if p.timerReaction && (store.deadline != nil || store.pausedSeconds > 0) {
            return .init(expression: .focused, accessory: nil, fx: .none)
        }

        if p.appReaction {
            let app = NSWorkspace.shared.frontmostApplication
            let bundle = app?.bundleIdentifier?.lowercased() ?? ""
            let appName = app?.localizedName?.lowercased() ?? ""
            if bundle == "com.apple.dt.xcode" || appName == "xcode" {
                return .init(expression: .focused, accessory: .glasses, fx: .none)
            }
            let gameHints = ["steam", "minecraft", "roblox", "retroarch", "whisky", "crossover"]
            if gameHints.contains(where: { bundle.contains($0) || appName.contains($0) }) {
                return .init(expression: .excited, accessory: .shades, fx: .sparkle)
            }
        }

        if p.nightReaction {
            let hour = Calendar.autoupdatingCurrent.component(.hour, from: date)

            // Late night: settle down, breathe slowly and drift off with floating Zs.
            if hour >= 23 || hour < 5 {
                return .init(expression: .sleepy, accessory: .sleepingCap, fx: .sleepZ)
            }

            // Early morning: wake up bright and fresh before normal daytime behavior resumes.
            if hour >= 5 && hour < 9 {
                return .init(expression: .happy, accessory: .sprout, fx: .sparkle)
            }
        }

        if hovering && p.hoverReaction { return resting }

        if p.idleReaction {
            let mouseIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
            let keyboardIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
            if min(mouseIdle, keyboardIdle) > 180 {
                return .init(expression: .bored, accessory: nil, fx: .none)
            }
        }

        return resting
    }

    private static func fx(for expression: HaloPixelPalExpression) -> HaloPixelPalFX {
        switch expression {
        case .love: return .hearts
        case .superHappy, .excited, .shy: return .sparkle
        case .music: return .music
        case .worried: return .sweat
        case .crying: return .tears
        case .sleepy: return .sleepZ
        case .dizzy: return .dizzy
        case .annoyed, .furious, .shocked, .surprised: return .alert
        default: return .none
        }
    }
}

// MARK: - Widget

struct HaloPixelPetWidget: View {
    @Environment(\.openNotchGridColumnSpan) private var gridColumnSpan
    @Environment(\.openNotchGridRowSpan) private var gridRowSpan
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hovering = false
    @State private var pointer = CGPoint.zero
    @State private var animationEpoch = Date()
    @State private var orbitDetector = HaloPixelPalCursorOrbitDetector()

    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore
    @ObservedObject private var pal = HaloPixelPalStore.shared
    @ObservedObject private var media: MediaService
    @ObservedObject private var system: SystemService

    init(store: AppStore, workspace: WorkspaceStore) {
        self.store = store
        self.workspace = workspace
        _media = ObservedObject(wrappedValue: workspace.media)
        _system = ObservedObject(wrappedValue: workspace.system)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.45 : 1.0 / 24.0, paused: false)) { timeline in
            GeometryReader { proxy in
                let columns = min(4, max(1, gridColumnSpan ?? 1))
                let rows = min(4, max(1, gridRowSpan ?? columns))
                let squareSize = min(columns, rows)
                let state = HaloPixelPalContext.resolve(
                    store: store,
                    media: media,
                    system: system,
                    pal: pal,
                    hovering: hovering,
                    date: timeline.date
                )
                let expression = resolvedExpression(base: state.expression, date: timeline.date)
                let side = max(1, min(proxy.size.width, proxy.size.height))

                HaloPixelPalFace(
                    expression: expression,
                    contextualAccessory: state.accessory,
                    fx: state.fx,
                    squareSize: squareSize,
                    preferences: pal.preferences,
                    date: timeline.date,
                    reduceMotion: reduceMotion,
                    animationTime: timeline.date.timeIntervalSince(pal.reaction == nil ? animationEpoch : pal.reactionStarted),
                    reactionElapsed: pal.reaction.map { _ in timeline.date.timeIntervalSince(pal.reactionStarted) },
                    cookieRescueElapsed: pal.cookieRescueStarted.map { timeline.date.timeIntervalSince($0) },
                    pointer: pal.preferences.hoverReaction && hovering ? pointer : .zero,
                    onCookieTap: { pal.feedFuryCookie() }
                )
                .frame(width: side, height: side)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        hovering = true
                        if orbitDetector.register(
                            location: location,
                            size: CGSize(width: side, height: side),
                            at: Date().timeIntervalSinceReferenceDate,
                            minimumRotationTurns: pal.preferences.dizzyRotationThresholdTurns
                        ) {
                            pal.react(.dizzy, seconds: 1.9)
                        }
                        let next = CGPoint(x: ((location.x / max(1, proxy.size.width) - 0.5) * 2).rounded(),
                                           y: ((location.y / max(1, proxy.size.height) - 0.5) * 2).rounded())
                        if pointer != next { pointer = next }
                    case .ended:
                        hovering = false
                        pointer = .zero
                        orbitDetector.resetPath()
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            LongPressGesture(minimumDuration: 0.55)
                .onEnded { _ in pal.longPressed() }
                .exclusively(before:
                    TapGesture(count: 2).onEnded { pal.doubleTapped() }
                        .exclusively(before: TapGesture().onEnded { pal.tapped() })
                )
        )
        .onDisappear { hovering = false; pointer = .zero; orbitDetector.resetPath() }
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { pal.tapped() }
        .accessibilityAction(named: Text("Show affection")) { pal.doubleTapped() }
        .contextMenu {
            Menu("Expression") {
                ForEach(HaloPixelPalExpression.allCases.filter { $0 != .blink }) { expression in
                    Button(expression.title) { pal.react(expression, seconds: 2.2) }
                }
            }
            Divider()
            Button("Pixel Pal Settings…") { HaloPixelPalSettingsWindowController.shared.show() }
        }
        .accessibilityLabel("Halo Pixel Pal")
        .help("Hover, click, double-click, long-press, or quickly circle the cursor around Pixel Pal · right-click for settings")
    }

    private func resolvedExpression(base: HaloPixelPalExpression, date: Date) -> HaloPixelPalExpression {
        guard base == .neutral, pal.preferences.automaticBlinking else { return base }
        let speed = max(0.35, pal.preferences.animationSpeed)
        let cycle = date.timeIntervalSince(animationEpoch) * speed
        let phase = cycle.truncatingRemainder(dividingBy: 12.0)
        if phase > (reduceMotion ? 11.35 : 11.72) { return .blink }
        if !reduceMotion && phase > 7.18 && phase < 7.42 { return .wink }
        return base
    }
}

// MARK: - Face renderer

private struct HaloPixelPalRelativeRoundedRectangle: Shape {
    let radiusFraction: Double

    func path(in rect: CGRect) -> Path {
        let fraction = min(0.5, max(0.0, radiusFraction))
        let radius = min(rect.width, rect.height) * fraction
        return Path(roundedRect: rect, cornerRadius: radius)
    }
}

private struct HaloPixelPalFace: View {
    let expression: HaloPixelPalExpression
    let contextualAccessory: HaloPixelPalAccessory?
    let fx: HaloPixelPalFX
    let squareSize: Int
    let preferences: HaloPixelPalPreferences
    let date: Date
    let reduceMotion: Bool
    var animationTime: TimeInterval = 0
    var reactionElapsed: TimeInterval? = nil
    var cookieRescueElapsed: TimeInterval? = nil
    var pointer: CGPoint = .zero
    var onCookieTap: (() -> Void)? = nil
    @Environment(\.displayScale) private var displayScale

    private let logicalGrid = 24

    private var faceColor: Color {
        expression == .furious ? Color(red: 1.0, green: 0.11, blue: 0.07) : preferences.faceColor
    }
    private var accentColor: Color {
        expression == .furious ? Color(red: 1.0, green: 0.52, blue: 0.08) : preferences.accentColor.color
    }
    private var blushColor: Color {
        expression == .furious ? Color(red: 0.62, green: 0.02, blue: 0.02) : preferences.blushColor.color
    }

    var body: some View {
        ZStack {
            ZStack {
                background
                if preferences.inactiveLEDIntensity > 0.001 {
                    Canvas { context, size in
                        let geometry = HaloPixelPalDisplayGeometry(size: size, scale: displayScale, fill: preferences.faceScale)
                        let inactiveColor = preferences.inactiveLEDUsesFaceColor ? faceColor : preferences.inactiveLEDColor.color
                        for y in 0..<logicalGrid {
                            for x in 0..<logicalGrid {
                                let rect = geometry.led(x: x, y: y)
                                let radius = min(rect.width, rect.height) * preferences.pixelCornerRadius
                                context.fill(Path(roundedRect: rect, cornerRadius: radius),
                                             with: .color(inactiveColor.opacity(preferences.inactiveLEDIntensity)),
                                             style: FillStyle(antialiased: preferences.pixelCornerRadius > 0.001))
                            }
                        }
                    }
                }
            }
            .clipShape(HaloPixelPalRelativeRoundedRectangle(radiusFraction: preferences.backgroundCornerRadius))

            Canvas { context, size in
                draw(context: &context, size: size)
            }
            .shadow(
                color: faceColor.opacity(preferences.glowIntensity * 0.55),
                radius: 1 + 7 * preferences.glowIntensity
            )

            if expression == .furious, let reactionElapsed = reactionElapsed {
                Canvas { context, size in
                    drawFuryDoor(
                        context: &context,
                        size: size,
                        elapsed: reactionElapsed,
                        cookieRescueElapsed: cookieRescueElapsed
                    )
                }
                .allowsHitTesting(false)

                if cookieRescueElapsed == nil, reactionElapsed >= 1.05, reactionElapsed < 2.15, let onCookieTap {
                    GeometryReader { proxy in
                        let hitSize = max(24.0, min(proxy.size.width, proxy.size.height) * 0.30)
                        Button(action: onCookieTap) {
                            Color.clear
                                .frame(width: hitSize, height: hitSize)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        .accessibilityLabel("Give Pixel Pal the cookie")
                        .help("Give Pixel Pal the cookie")
                    }
                }
            }
        }
        .clipped()
    }

    private func furyDoorClosure(elapsed: TimeInterval, cookieRescueElapsed: TimeInterval?) -> Double {
        func smooth(_ value: Double) -> Double {
            let p = min(1.0, max(0.0, value))
            return p * p * (3.0 - 2.0 * p)
        }
        if let rescue = cookieRescueElapsed {
            return max(0.0, 1.0 - smooth(rescue / 0.55))
        }
        if reduceMotion {
            return elapsed >= 0.65 && elapsed < 2.80 ? 1.0 : 0.0
        }
        if elapsed < 0.55 { return 0 }
        if elapsed < 1.05 { return smooth((elapsed - 0.55) / 0.50) }
        if elapsed < 2.15 { return 1 }
        if elapsed < 2.80 { return 1 - smooth((elapsed - 2.15) / 0.65) }
        return 0
    }

    private func drawFuryDoor(
        context: inout GraphicsContext,
        size: CGSize,
        elapsed: TimeInterval,
        cookieRescueElapsed: TimeInterval?
    ) {
        let closure = furyDoorClosure(elapsed: elapsed, cookieRescueElapsed: cookieRescueElapsed)
        guard closure > 0.001 else { return }

        let panelWidth = size.width * 0.5 * closure
        let edgeWidth = max(1.0, min(size.width, size.height) / 48.0)
        let panelColor = Color(red: 0.12, green: 0.015, blue: 0.012).opacity(0.98)
        let edgeColor = Color(red: 0.95, green: 0.08, blue: 0.04).opacity(0.92)
        let seamColor = Color.black.opacity(0.42)

        func paintRect(_ rect: CGRect, _ color: Color) {
            var path = Path()
            path.addRect(rect)
            context.fill(path, with: .color(color))
        }

        paintRect(CGRect(x: 0, y: 0, width: panelWidth, height: size.height), panelColor)
        paintRect(CGRect(x: size.width - panelWidth, y: 0, width: panelWidth, height: size.height), panelColor)
        paintRect(CGRect(x: max(0, panelWidth - edgeWidth), y: 0, width: edgeWidth, height: size.height), edgeColor)
        paintRect(CGRect(x: size.width - panelWidth, y: 0, width: edgeWidth, height: size.height), edgeColor)

        for row in 1..<4 {
            let y = size.height * CGFloat(row) / 4.0
            paintRect(CGRect(x: 0, y: y, width: panelWidth, height: edgeWidth), seamColor)
            paintRect(CGRect(x: size.width - panelWidth, y: y, width: panelWidth, height: edgeWidth), seamColor)
        }

        if let rescue = cookieRescueElapsed {
            drawFuryCookie(context: &context, size: size, consumeProgress: min(1.0, rescue / 0.48))
        } else if elapsed >= 1.05 && elapsed < 2.15 {
            drawFuryCookie(context: &context, size: size, consumeProgress: 0)
        }
    }

    private func drawFuryCookie(context: inout GraphicsContext, size: CGSize, consumeProgress: Double) {
        let pattern = [
            "..bbb..",
            ".bbbbb.",
            "bbdbdbb",
            "bbbbbbb",
            "bdbbbdb",
            ".bbdbb.",
            "..bbb.."
        ]
        let pixel = max(1.0, min(size.width, size.height) / 30.0)
        let cookieSide = pixel * 7.0
        let origin = CGPoint(x: (size.width - cookieSide) / 2.0, y: (size.height - cookieSide) / 2.0)
        let visibleColumns = max(0, min(7, Int(ceil(7.0 * (1.0 - consumeProgress)))))
        let dough = Color(red: 0.92, green: 0.55, blue: 0.18)
        let edge = Color(red: 0.62, green: 0.28, blue: 0.07)
        let chip = Color(red: 0.25, green: 0.09, blue: 0.025)

        func paintCookiePixel(_ rect: CGRect, _ color: Color) {
            var path = Path()
            path.addRect(rect)
            context.fill(path, with: .color(color))
        }

        for (y, row) in pattern.enumerated() {
            for (x, value) in row.enumerated() where x < visibleColumns && value != "." {
                let rect = CGRect(
                    x: origin.x + CGFloat(x) * pixel,
                    y: origin.y + CGFloat(y) * pixel,
                    width: pixel,
                    height: pixel
                )
                let isOuter = x == 0 || x == 6 || y == 0 || y == 6
                paintCookiePixel(rect, value == "d" ? chip : (isOuter ? edge : dough))
            }
        }

        if consumeProgress > 0.08 && consumeProgress < 0.95 {
            let crumb = max(1.0, pixel * 0.72)
            let t = CGFloat(consumeProgress)
            let crumbs = [
                CGPoint(x: size.width / 2 + pixel * 3.2 + pixel * 2.4 * t, y: size.height / 2 - pixel * 1.7 - pixel * 2.0 * t),
                CGPoint(x: size.width / 2 + pixel * 2.4 + pixel * 1.5 * t, y: size.height / 2 + pixel * 0.2 + pixel * 1.7 * t),
                CGPoint(x: size.width / 2 + pixel * 1.4 + pixel * 2.0 * t, y: size.height / 2 + pixel * 2.0 - pixel * 0.8 * t)
            ]
            for (index, point) in crumbs.enumerated() {
                paintCookiePixel(
                    CGRect(x: point.x, y: point.y, width: crumb, height: crumb),
                    (index == 1 ? chip : dough).opacity(1.0 - consumeProgress)
                )
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        switch preferences.backgroundStyle {
        case .transparent:
            Color.clear
        case .black:
            Color.black.opacity(preferences.backgroundOpacity)
        case .custom:
            preferences.backgroundColor.color.opacity(preferences.backgroundOpacity)
        case .glow:
            ZStack {
                Color.black.opacity(0.74 * preferences.backgroundOpacity)
                RadialGradient(
                    colors: [faceColor.opacity(0.10 + 0.28 * preferences.glowIntensity), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 180
                )
                .opacity(preferences.backgroundOpacity)
            }
        }
    }

    private func draw(context: inout GraphicsContext, size: CGSize) {
        let geometry = HaloPixelPalDisplayGeometry(size: size, scale: displayScale, fill: preferences.faceScale)

        var layers: [(placed: HaloPixelPalPlacedSprite, opacity: Double, x: Int, y: Int)] = []
        func render(_ placed: HaloPixelPalPlacedSprite, opacity: Double = 1, extraX: Int = 0, extraY: Int = 0) {
            layers.append((placed, opacity, extraX, extraY))
        }
        drawFaceStyle(render: render)
        drawEyes(render: render)
        drawBrows(render: render)
        drawMouth(render: render)
        drawCheeks(render: render)
        drawAccessory(render: render)
        drawFX(render: render)

        // Constrain the whole composition, including accessories, before moving it.
        // A cap or floating heart must never lose its top row during a bounce.
        let requestedMotion = logicalMotion()
        let minX = layers.map { $0.placed.x + $0.x }.min() ?? 0
        let minY = layers.map { $0.placed.y + $0.y }.min() ?? 0
        let maxX = layers.map { $0.placed.x + $0.x + $0.placed.sprite.width }.max() ?? logicalGrid
        let maxY = layers.map { $0.placed.y + $0.y + $0.placed.sprite.height }.max() ?? logicalGrid
        let motion = (x: min(logicalGrid - maxX, max(-minX, requestedMotion.x)),
                      y: min(logicalGrid - maxY, max(-minY, requestedMotion.y)))

        func color(for role: HaloPixelPalColorRole) -> Color {
            switch role {
            case .primary: return faceColor
            case .accent: return accentColor
            case .blush: return blushColor
            case .white: return .white
            case .shadow: return Color.black.opacity(0.78)
            case .accessoryFrame: return Color(red: 0.72, green: 0.78, blue: 0.90)
            case .accessoryLens: return Color(red: 0.15, green: 0.34, blue: 0.58)
            }
        }

        func paint(_ placed: HaloPixelPalPlacedSprite, opacity: Double = 1.0, extraX: Int = 0, extraY: Int = 0) {
            let rows = placed.sprite.rows
            for (rowIndex, row) in rows.enumerated() {
                let chars = Array(row)
                for (columnIndex, char) in chars.enumerated() {
                    guard let role = HaloPixelPalColorRole(rawValue: char) else { continue }
                    let sourceX = placed.mirrorX ? (chars.count - 1 - columnIndex) : columnIndex
                    let logicalX = placed.x + sourceX + motion.x + extraX
                    let logicalY = placed.y + rowIndex + motion.y + extraY
                    guard logicalX >= 0, logicalY >= 0, logicalX < logicalGrid, logicalY < logicalGrid else { continue }
                    let rect = geometry.led(x: logicalX, y: logicalY)
                    let radius = min(rect.width, rect.height) * preferences.pixelCornerRadius
                    context.fill(Path(roundedRect: rect, cornerRadius: radius),
                                 with: .color(color(for: role).opacity(opacity)),
                                 style: FillStyle(antialiased: preferences.pixelCornerRadius > 0.001))
                }
            }
        }

        for layer in layers {
            paint(layer.placed, opacity: layer.opacity, extraX: layer.x, extraY: layer.y)
        }
    }

    private func drawFaceStyle(render: (HaloPixelPalPlacedSprite, Double, Int, Int) -> Void) {
        switch preferences.faceStyle {
        case .soft:
            break
        case .minimal:
            break
        case .robot:
            let left = HaloPixelPalSprite(rows: ["p", "a", "p"])
            render(.init(left, x: 1, y: 10), 0.75, 0, 0)
            render(.init(left, x: 22, y: 10), 0.75, 0, 0)
        case .cat:
            let ear = HaloPixelPalSprite(rows: [
                "p...p",
                "pp.pp",
                ".p.p."
            ])
            render(.init(ear, x: 1, y: 1), 0.95, 0, 0)
            render(.init(ear, x: 18, y: 1, mirrorX: true), 0.95, 0, 0)
        }
    }

    private enum EyePose { case open, happy, closed, heart, star, winkLeft, winkRight, confused, dizzy, furious, smug }

    private var eyePose: EyePose {
        switch expression {
        case .blink, .sleepy, .bored: return .closed
        case .happy, .superHappy, .music, .shy: return .happy
        case .love: return .heart
        case .excited, .shocked: return .star
        case .wink, .mischievous: return .winkRight
        case .confused: return .confused
        case .dizzy: return .dizzy
        case .furious: return .furious
        case .smug: return .smug
        default: return .open
        }
    }

    private func drawEyes(render: (HaloPixelPalPlacedSprite, Double, Int, Int) -> Void) {
        let lookX = reduceMotion ? 0 : Int(pointer.x)
        let lookY = reduceMotion ? 0 : Int(pointer.y)
        let leftX = 3 + lookX
        let rightX = 15 + lookX
        let y = 7 + lookY

        func drawOpenPair() {
            let eye = HaloPixelPalSprites.openEye(preferences.eyeStyle)
            render(.init(eye, x: leftX, y: y), 1, 0, 0)
            render(.init(eye, x: rightX, y: y, mirrorX: true), 1, 0, 0)
        }

        switch eyePose {
        case .open:
            drawOpenPair()
        case .happy:
            let eye = HaloPixelPalSprites.happyEye(preferences.eyeStyle)
            render(.init(eye, x: leftX, y: y + 1), 1, 0, 0)
            render(.init(eye, x: rightX, y: y + 1, mirrorX: true), 1, 0, 0)
        case .closed:
            let eye = HaloPixelPalSprites.closedEye(preferences.eyeStyle)
            render(.init(eye, x: leftX, y: y + 2), 1, 0, 0)
            render(.init(eye, x: rightX, y: y + 2, mirrorX: true), 1, 0, 0)
        case .heart:
            render(.init(HaloPixelPalSprites.heartEye, x: 2, y: 6), 1, 0, 0)
            render(.init(HaloPixelPalSprites.heartEye, x: 15, y: 6, mirrorX: true), 1, 0, 0)
        case .star:
            render(.init(HaloPixelPalSprites.starEye, x: 3, y: 6), 1, 0, 0)
            render(.init(HaloPixelPalSprites.starEye, x: 16, y: 6, mirrorX: true), 1, 0, 0)
        case .winkLeft:
            let open = HaloPixelPalSprites.openEye(preferences.eyeStyle)
            render(.init(HaloPixelPalSprites.winkEye, x: leftX, y: y + 2), 1, 0, 0)
            render(.init(open, x: rightX, y: y, mirrorX: true), 1, 0, 0)
        case .winkRight:
            let open = HaloPixelPalSprites.openEye(preferences.eyeStyle)
            render(.init(open, x: leftX, y: y), 1, 0, 0)
            render(.init(HaloPixelPalSprites.winkEye, x: rightX, y: y + 2, mirrorX: true), 1, 0, 0)
        case .confused:
            let open = HaloPixelPalSprites.openEye(preferences.eyeStyle)
            let closed = HaloPixelPalSprites.closedEye(preferences.eyeStyle)
            render(.init(open, x: leftX, y: y), 1, 0, 0)
            render(.init(closed, x: rightX, y: y + 2, mirrorX: true), 1, 0, 0)
        case .dizzy:
            render(.init(HaloPixelPalSprites.xEye, x: 3, y: 6), 1, 0, 0)
            render(.init(HaloPixelPalSprites.xEye, x: 16, y: 6, mirrorX: true), 1, 0, 0)
        case .furious:
            render(.init(HaloPixelPalSprites.furiousEye, x: leftX, y: y + 1), 1, 0, 0)
            render(.init(HaloPixelPalSprites.furiousEye, x: rightX, y: y + 1, mirrorX: true), 1, 0, 0)
        case .smug:
            let eye = HaloPixelPalSprite(rows: ["ppppp", ".ppp."])
            render(.init(eye, x: leftX, y: y + 2), 1, 0, 0)
            render(.init(eye, x: rightX, y: y + 2, mirrorX: true), 1, 0, 0)
        }
    }

    private func drawBrows(render: (HaloPixelPalPlacedSprite, Double, Int, Int) -> Void) {
        let leftX = 3
        let rightX = 16
        let y = 4
        switch expression {
        case .worried, .sad, .crying, .shy:
            render(.init(HaloPixelPalSprites.worriedBrow, x: leftX, y: y), 0.95, 0, 0)
            render(.init(HaloPixelPalSprites.worriedBrow, x: rightX, y: y, mirrorX: true), 0.95, 0, 0)
        case .furious:
            render(.init(HaloPixelPalSprites.furiousBrow, x: leftX, y: 2), 1, 0, 0)
            render(.init(HaloPixelPalSprites.furiousBrow, x: rightX, y: 2, mirrorX: true), 1, 0, 0)
        case .annoyed, .focused:
            render(.init(HaloPixelPalSprites.annoyedBrow, x: leftX, y: y), 0.95, 0, 0)
            render(.init(HaloPixelPalSprites.annoyedBrow, x: rightX, y: y, mirrorX: true), 0.95, 0, 0)
        case .surprised, .shocked:
            render(.init(HaloPixelPalSprites.raisedBrow, x: leftX, y: 3), 0.95, 0, 0)
            render(.init(HaloPixelPalSprites.raisedBrow, x: rightX, y: 3, mirrorX: true), 0.95, 0, 0)
        case .confused:
            render(.init(HaloPixelPalSprites.raisedBrow, x: leftX, y: 3), 0.95, 0, 0)
            render(.init(HaloPixelPalSprites.worriedBrow, x: rightX, y: y, mirrorX: true), 0.88, 0, 0)
        case .mischievous:
            render(.init(HaloPixelPalSprites.annoyedBrow, x: leftX, y: y), 0.82, 0, 0)
        case .smug:
            render(.init(HaloPixelPalSprites.raisedBrow, x: rightX, y: 3, mirrorX: true), 0.78, 0, 0)
        default:
            break
        }
    }

    private func automaticMouth() -> HaloPixelPalSprite? {
        switch expression {
        case .neutral, .focused: return HaloPixelPalSprites.mouthTiny
        case .confused, .dizzy: return HaloPixelPalSprites.mouthO
        case .blink, .sleepy, .bored: return HaloPixelPalSprites.mouthFlat
        case .happy, .music: return HaloPixelPalSprites.mouthSmile
        case .superHappy, .excited, .love: return HaloPixelPalSprites.mouthBigSmile
        case .surprised, .shocked: return HaloPixelPalSprites.mouthO
        case .worried, .sad, .crying, .annoyed: return HaloPixelPalSprites.mouthFrown
        case .furious: return HaloPixelPalSprites.mouthGrimace
        case .shy: return HaloPixelPalSprites.mouthTiny
        case .mischievous, .smug, .wink: return HaloPixelPalSprites.mouthSmug
        }
    }

    private func selectedMouth() -> HaloPixelPalSprite? {
        switch preferences.mouthStyle {
        case .automatic: return automaticMouth()
        case .none: return nil
        case .tiny: return HaloPixelPalSprites.mouthTiny
        case .smile: return HaloPixelPalSprites.mouthSmile
        case .flat: return HaloPixelPalSprites.mouthFlat
        case .cat: return HaloPixelPalSprites.mouthCat
        case .open: return HaloPixelPalSprites.mouthOpen
        }
    }

    private func drawMouth(render: (HaloPixelPalPlacedSprite, Double, Int, Int) -> Void) {
        guard let mouth = selectedMouth() else { return }
        let x = max(0, (logicalGrid - mouth.width) / 2)
        let y = expression == .superHappy || expression == .excited ? 15 : 16
        render(.init(mouth, x: x, y: y), 1, 0, 0)
    }

    private func drawCheeks(render: (HaloPixelPalPlacedSprite, Double, Int, Int) -> Void) {
        if expression == .furious { return }
        let sprite: HaloPixelPalSprite
        switch preferences.cheekStyle {
        case .none: return
        case .soft: sprite = HaloPixelPalSprites.cheekSoft
        case .kawaii: sprite = HaloPixelPalSprites.cheekKawaii
        case .shy: sprite = HaloPixelPalSprites.cheekShy
        }
        let opacity: Double = expression == .shy || expression == .love ? 1.0 : 0.90
        render(.init(sprite, x: 2, y: 13), opacity, 0, 0)
        render(.init(sprite, x: max(0, 22 - sprite.width), y: 13, mirrorX: true), opacity, 0, 0)
    }

    private var resolvedAccessory: HaloPixelPalAccessory {
        switch preferences.accessoryMode {
        case .off:
            return .none
        case .manual:
            return preferences.selectedAccessory
        case .contextual:
            return contextualAccessory ?? preferences.selectedAccessory
        case .randomAllowed:
            let choices = preferences.allowedAccessories.filter { $0 != .none }
            guard !choices.isEmpty else { return .none }
            let interval = Int(date.timeIntervalSinceReferenceDate / 45)
            return choices[abs(interval) % choices.count]
        }
    }

    private func drawAccessory(render: (HaloPixelPalPlacedSprite, Double, Int, Int) -> Void) {
        switch resolvedAccessory {
        case .none:
            if preferences.faceStyle == .cat {
                return
            }
        case .bow:
            render(.init(HaloPixelPalSprites.bow, x: 1, y: 1), 1, 0, 0)
        case .catEars:
            render(.init(HaloPixelPalSprites.catEar, x: 3, y: 1), 1, 0, 0)
            render(.init(HaloPixelPalSprites.catEar, x: 16, y: 1, mirrorX: true), 1, 0, 0)
        case .glasses:
            render(.init(HaloPixelPalSprites.glasses, x: 6, y: 8), 0.96, 0, 0)
        case .shades:
            render(.init(HaloPixelPalSprites.shades, x: 6, y: 7), 1, 0, 0)
        case .headphones:
            render(.init(HaloPixelPalSprites.headphones, x: 6, y: 4), 1, 0, 0)
        case .halo:
            render(.init(HaloPixelPalSprites.halo, x: 8, y: 1), 0.94, 0, 0)
        case .horns:
            render(.init(HaloPixelPalSprites.horns, x: 7, y: 1), 1, 0, 0)
        case .flower:
            render(.init(HaloPixelPalSprites.flower, x: 18, y: 2), 1, 0, 0)
        case .sleepingCap:
            render(.init(HaloPixelPalSprites.sleepingCap, x: 7, y: 0), 1, 0, 0)
        case .crown:
            render(.init(HaloPixelPalSprites.crown, x: 9, y: 1), 1, 0, 0)
        case .sprout:
            render(.init(HaloPixelPalSprites.sprout, x: 10, y: 1), 1, 0, 0)
        case .bandage:
            render(.init(HaloPixelPalSprites.bandage, x: 17, y: 4), 0.88, 0, 0)
        }
    }

    private func drawFX(render: (HaloPixelPalPlacedSprite, Double, Int, Int) -> Void) {
        let phase = reduceMotion || preferences.animationIntensity == 0 ? 0 : Int(max(0, animationTime) * max(0.35, preferences.animationSpeed) * 4) % 4
        let lift = -(phase / 2)
        switch fx {
        case .none:
            break
        case .hearts:
            render(.init(HaloPixelPalSprites.heart, x: 1, y: 3), 0.90, 0, lift)
            render(.init(HaloPixelPalSprites.heart, x: 20, y: 2), 0.72, 0, lift - 1)
        case .sparkle:
            render(.init(HaloPixelPalSprites.sparkle, x: 1, y: 2), 0.90, 0, lift)
            render(.init(HaloPixelPalSprites.sparkle, x: 20, y: 5), 0.72, 0, -lift)
        case .dizzy:
            switch phase {
            case 0:
                render(.init(HaloPixelPalSprites.sparkle, x: 2, y: 2), 0.96, 0, 0)
                render(.init(HaloPixelPalSprites.sparkle, x: 19, y: 5), 0.66, 0, 0)
            case 1:
                render(.init(HaloPixelPalSprites.sparkle, x: 7, y: 1), 0.78, 0, 0)
                render(.init(HaloPixelPalSprites.sparkle, x: 14, y: 6), 0.92, 0, 0)
            case 2:
                render(.init(HaloPixelPalSprites.sparkle, x: 19, y: 2), 0.96, 0, 0)
                render(.init(HaloPixelPalSprites.sparkle, x: 2, y: 5), 0.66, 0, 0)
            default:
                render(.init(HaloPixelPalSprites.sparkle, x: 14, y: 1), 0.78, 0, 0)
                render(.init(HaloPixelPalSprites.sparkle, x: 7, y: 6), 0.92, 0, 0)
            }
        case .music:
            render(.init(HaloPixelPalSprites.musicNote, x: 19, y: 1), 0.90, 0, lift)
        case .sweat:
            render(.init(HaloPixelPalSprites.sweat, x: 20, y: 5), 0.92, 0, lift)
        case .tears:
            render(.init(HaloPixelPalSprites.tear, x: 5, y: 12), 0.95, 0, phase / 2)
            render(.init(HaloPixelPalSprites.tear, x: 18, y: 12), 0.95, 0, phase / 2)
        case .alert:
            render(.init(HaloPixelPalSprites.exclamation, x: 21, y: 2), 0.95, 0, reduceMotion ? 0 : -phase % 2)
        case .sleepZ:
            render(.init(HaloPixelPalSprites.zTiny, x: 17, y: 7), 0.52, 0, lift)
            render(.init(HaloPixelPalSprites.zSmall, x: 20, y: 2), 0.88, 0, lift - 1)
        }
    }

    private func logicalMotion() -> (x: Int, y: Int) {
        guard !reduceMotion else { return (0, 0) }
        let speed = max(0.35, preferences.animationSpeed)
        let intensity = preferences.animationIntensity
        let t = max(0, animationTime) * speed
        let one = intensity > 0.28 ? 1 : 0
        let two = intensity > 0.75 ? 2 : one
        if let reactionElapsed {
            if expression == .dizzy {
                return (Int(round(sin(t * 10.5))) * two, Int(round(cos(t * 7.5))) * one)
            }
            if expression == .furious {
                return (Int(round(sin(t * 18.0))) * two, Int(round(cos(t * 13.0))) * one)
            }
            if expression == .annoyed {
                return (Int(round(sin(t * 11.0))) * one, 0)
            }
            return (0, HaloPixelPalAnimationTiming.bounce(elapsed: reactionElapsed * speed,
                                                         intensity: intensity, reduceMotion: reduceMotion))
        }

        switch expression {
        case .happy, .superHappy, .love:
            return (0, Int(round(sin(t * 5.2))) < 0 ? -one : 0)
        case .excited, .music:
            return (Int(round(sin(t * 6.4))) * one, Int(round(cos(t * 6.4))) * one)
        case .shocked, .surprised:
            return (0, Int(round(abs(sin(t * 7.0)))) * -two)
        case .worried, .sad, .crying:
            return (Int(round(sin(t * 2.0))) * one, one)
        case .sleepy:
            return (0, Int(round(sin(t * 1.15))) * one)
        case .bored:
            return (Int(round(sin(t * 0.8))) * one, one)
        case .annoyed:
            return (Int(round(sin(t * 11.0))) * one, 0)
        case .furious:
            return (Int(round(sin(t * 18.0))) * two, Int(round(cos(t * 13.0))) * one)
        case .dizzy:
            return (Int(round(sin(t * 10.5))) * two, Int(round(cos(t * 7.5))) * one)
        case .neutral:
            let phase = t.truncatingRemainder(dividingBy: 8)
            return (0, phase > 6.8 && phase < 7.4 ? -one : 0)
        default:
            return (0, 0)
        }
    }
}

// MARK: - Settings

@MainActor
final class HaloPixelPalSettingsWindowController {
    static let shared = HaloPixelPalSettingsWindowController()
    private var window: NSWindow?

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let controller = NSHostingController(rootView: HaloPixelPalSettingsView())
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 650, height: 790),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Halo · Pixel Pal"
        window.contentViewController = controller
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 600, height: 680)
        window.center()
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct HaloPixelPalSettingsView: View {
    @ObservedObject private var pal = HaloPixelPalStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var previewEpoch = Date()
    @State private var previewExpression: HaloPixelPalExpression = .happy
    @State private var previewAccessory: HaloPixelPalAccessory? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                appearanceSection
                accessorySection
                interactionSection
                contextSection
                expressionSection
                footer
            }
            .padding(22)
        }
        .frame(minWidth: 600, minHeight: 680)
    }

    private var header: some View {
        HStack(spacing: 22) {
            TimelineView(.animation(minimumInterval: reduceMotion ? 0.45 : 1.0 / 24.0)) { timeline in
                HaloPixelPalFace(
                    expression: previewExpression,
                    contextualAccessory: previewAccessory,
                    fx: previewFX,
                    squareSize: 2,
                    preferences: expressionPreviewPreferences,
                    date: timeline.date,
                    reduceMotion: reduceMotion,
                    animationTime: timeline.date.timeIntervalSince(previewEpoch),
                    reactionElapsed: previewExpression == .furious ? timeline.date.timeIntervalSince(previewEpoch) : nil
                )
                .id(previewExpression)
            }
            .frame(width: 150, height: 150)
            .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text("Pixel Pal v2").font(.title2.weight(.bold))
                Text("A premium pixel-art face with authored expressions, accessories and contextual animation.")
                    .foregroundStyle(.secondary)
                Text("24×24 logical canvas · square-only · face-first")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var appearanceSection: some View {
        GroupBox("Appearance") {
            VStack(alignment: .leading, spacing: 13) {
                Text("Face style").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                visualFaceStyleGrid

                Text("Eyes").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                visualEyeStyleGrid

                Picker("Mouth", selection: bind(\.mouthStyle)) {
                    ForEach(HaloPixelPalMouthStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Cheeks", selection: bind(\.cheekStyle)) {
                    ForEach(HaloPixelPalCheekStyle.allCases) { Text($0.rawValue).tag($0) }
                }

                Divider()

                Picker("Palette", selection: bind(\.palette)) {
                    ForEach(HaloPixelPalPalette.allCases) { Text($0.rawValue).tag($0) }
                }
                if pal.preferences.palette == .custom {
                    ColorPicker("Primary pixel color", selection: rgbBinding(\.customColor))
                }
                ColorPicker("Accent / FX color", selection: rgbBinding(\.accentColor))
                ColorPicker("Blush color", selection: rgbBinding(\.blushColor))

                Text("Background display").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Picker("Surface", selection: bind(\.backgroundStyle)) {
                    ForEach(HaloPixelPalBackgroundStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                if pal.preferences.backgroundStyle == .custom {
                    ColorPicker("Surface color", selection: rgbBinding(\.backgroundColor))
                }
                if pal.preferences.backgroundStyle != .transparent {
                    HStack {
                        Text("Surface opacity")
                        Slider(value: bind(\.backgroundOpacity), in: 0...1)
                        Text("\(Int(pal.preferences.backgroundOpacity * 100))%")
                            .font(.caption.monospacedDigit())
                            .frame(width: 38, alignment: .trailing)
                    }
                }
                HStack {
                    Text("Background corner radius")
                    Slider(value: bind(\.backgroundCornerRadius), in: 0...0.5)
                    Text("\(Int(pal.preferences.backgroundCornerRadius * 100))%")
                        .font(.caption.monospacedDigit())
                        .frame(width: 38, alignment: .trailing)
                }
                Text("Rounds the LED display background, including the inactive LED matrix, without clipping the active Pixel Pal pixels.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Toggle("Match inactive LEDs to face color", isOn: bind(\.inactiveLEDUsesFaceColor))
                if !pal.preferences.inactiveLEDUsesFaceColor {
                    ColorPicker("Inactive LED color", selection: rgbBinding(\.inactiveLEDColor))
                }
                HStack {
                    Text("Inactive LED brightness")
                    Slider(value: bind(\.inactiveLEDIntensity), in: 0...0.35)
                    Text("\(Int(pal.preferences.inactiveLEDIntensity * 100))%")
                        .font(.caption.monospacedDigit())
                        .frame(width: 38, alignment: .trailing)
                }
                HStack {
                    Text("Pixel corner radius")
                    Slider(value: bind(\.pixelCornerRadius), in: 0...0.5)
                    Text("\(Int(pal.preferences.pixelCornerRadius * 100))%")
                        .font(.caption.monospacedDigit())
                        .frame(width: 38, alignment: .trailing)
                }

                HStack {
                    Text("Face fill")
                    Slider(value: bind(\.faceScale), in: 0.76...1.0)
                    Text("\(Int(pal.preferences.faceScale * 100))%")
                        .font(.caption.monospacedDigit())
                        .frame(width: 38, alignment: .trailing)
                }
                HStack {
                    Text("Glow")
                    Slider(value: bind(\.glowIntensity), in: 0...1)
                }
            }
            .padding(.top, 5)
        }
    }

    private var visualFaceStyleGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(HaloPixelPalFaceStyle.allCases) { style in
                previewTile(title: style.rawValue, selected: style == pal.preferences.faceStyle) {
                    pal.update(\.faceStyle, style)
                } preview: {
                    HaloPixelPalFace(
                        expression: .happy,
                        contextualAccessory: nil,
                        fx: .none,
                        squareSize: 2,
                        preferences: previewPreferences(faceStyle: style),
                        date: Date(),
                        reduceMotion: true
                    )
                }
            }
        }
    }

    private var visualEyeStyleGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(HaloPixelPalEyeStyle.allCases) { style in
                previewTile(title: style.rawValue, selected: style == pal.preferences.eyeStyle) {
                    pal.update(\.eyeStyle, style)
                    previewExpression = .neutral
                } preview: {
                    HaloPixelPalFace(
                        expression: .neutral,
                        contextualAccessory: nil,
                        fx: .none,
                        squareSize: 2,
                        preferences: previewPreferences(eyeStyle: style),
                        date: Date(),
                        reduceMotion: true
                    )
                }
            }
        }
    }

    private func previewTile<Preview: View>(
        title: String,
        selected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder preview: () -> Preview
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                preview()
                    .frame(width: 64, height: 64)
                    .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(title)
                    .font(.caption2.weight(selected ? .bold : .regular))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? Color.accentColor.opacity(0.75) : Color.secondary.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var accessorySection: some View {
        GroupBox("Accessories") {
            VStack(alignment: .leading, spacing: 11) {
                Picker("Mode", selection: bind(\.accessoryMode)) {
                    ForEach(HaloPixelPalAccessoryMode.allCases) { Text($0.rawValue).tag($0) }
                }
                if pal.preferences.accessoryMode != .off {
                    Picker("Accessory", selection: bind(\.selectedAccessory)) {
                        ForEach(HaloPixelPalAccessory.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .onChange(of: pal.preferences.selectedAccessory) { value in
                        previewAccessory = value == .none ? nil : value
                    }
                }
                if pal.preferences.accessoryMode == .randomAllowed {
                    Text("Random mode rotates through all enabled accessories every ~45 seconds.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Contextual mode can automatically add headphones for music, glasses for Xcode, shades for games, a sleeping cap at night, and more.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    private var interactionSection: some View {
        GroupBox("Animation & interactions") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Animation speed")
                    Slider(value: bind(\.animationSpeed), in: 0.35...2.0)
                }
                HStack {
                    Text("Animation intensity")
                    Slider(value: bind(\.animationIntensity), in: 0...1)
                }
                HStack {
                    Text("Dizzy threshold")
                    Slider(value: bind(\.dizzyRotationThresholdTurns), in: 0.35...2.0, step: 0.05)
                    Text("\(pal.preferences.dizzyRotationThresholdTurns, specifier: "%.2f") turns")
                        .font(.caption.monospacedDigit())
                        .frame(width: 76, alignment: .trailing)
                }
                Text("How much fast circular cursor movement is required before Pixel Pet becomes dizzy. Lower values trigger sooner.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Toggle("Automatic blinking + rare wink", isOn: bind(\.automaticBlinking))
                Toggle("React on hover", isOn: bind(\.hoverReaction))
                Toggle("React on click", isOn: bind(\.tapReaction))
                Toggle("React on double-click", isOn: bind(\.doubleTapReaction))
                Toggle("React on long press", isOn: bind(\.longPressReaction))
            }
            .padding(.top, 4)
        }
    }

    private var contextSection: some View {
        GroupBox("Mac context reactions") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Enable context reactions", isOn: bind(\.contextReactions))
                if pal.preferences.contextReactions {
                    Toggle("Charging", isOn: bind(\.chargingReaction))
                    Toggle("Low battery", isOn: bind(\.lowBatteryReaction))
                    Toggle("Music playback", isOn: bind(\.musicReaction))
                    Toggle("Timer state", isOn: bind(\.timerReaction))
                    Toggle("Xcode and games", isOn: bind(\.appReaction))
                    Toggle("Idle / away", isOn: bind(\.idleReaction))
                    Toggle("Time of day (morning / night)", isOn: bind(\.nightReaction))
                }
            }
            .padding(.top, 4)
        }
    }

    private var expressionSection: some View {
        GroupBox("Expression & animation preview") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Expression", selection: $previewExpression) {
                    ForEach(HaloPixelPalExpression.allCases.filter { $0 != .blink }) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)
                .onChange(of: previewExpression) { expression in
                    previewEpoch = Date()
                    pal.react(expression, seconds: 2.2)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 5), spacing: 7) {
                    ForEach([HaloPixelPalExpression.happy, .superHappy, .love, .dizzy, .furious, .shy, .mischievous, .surprised, .worried, .crying, .wink, .music]) { expression in
                        Button(expression.title) {
                            previewExpression = expression
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private var footer: some View {
        HStack(alignment: .bottom) {
            Text("Pixel Pal v2 uses a 24×24 authored pixel canvas with layered eyes, brows, mouths, cheeks, accessories and FX. It remains face-first at every supported square size.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Reset") { pal.reset() }
        }
    }

    private var expressionPreviewPreferences: HaloPixelPalPreferences {
        var value = pal.preferences
        value.mouthStyle = .automatic
        value.accessoryMode = .contextual
        value.selectedAccessory = .none
        return value
    }

    private var previewFX: HaloPixelPalFX {
        switch previewExpression {
        case .love: return .hearts
        case .superHappy, .excited, .shy: return .sparkle
        case .music: return .music
        case .worried: return .sweat
        case .crying: return .tears
        case .sleepy: return .sleepZ
        case .dizzy: return .dizzy
        case .annoyed, .furious, .surprised, .shocked: return .alert
        default: return .none
        }
    }

    private func previewPreferences(
        faceStyle: HaloPixelPalFaceStyle? = nil,
        eyeStyle: HaloPixelPalEyeStyle? = nil
    ) -> HaloPixelPalPreferences {
        var value = pal.preferences
        if let faceStyle { value.faceStyle = faceStyle }
        if let eyeStyle { value.eyeStyle = eyeStyle }
        value.accessoryMode = .off
        value.backgroundStyle = .black
        value.glowIntensity = 0
        return value
    }

    private func bind<T>(_ path: WritableKeyPath<HaloPixelPalPreferences, T>) -> Binding<T> {
        Binding(
            get: { pal.preferences[keyPath: path] },
            set: { pal.update(path, $0) }
        )
    }

    private func rgbBinding(_ path: WritableKeyPath<HaloPixelPalPreferences, HaloPixelPalRGB>) -> Binding<Color> {
        Binding(
            get: { pal.preferences[keyPath: path].color },
            set: { color in
                guard let ns = NSColor(color).usingColorSpace(.deviceRGB) else { return }
                pal.update(path, HaloPixelPalRGB(red: ns.redComponent, green: ns.greenComponent, blue: ns.blueComponent))
            }
        )
    }
}
