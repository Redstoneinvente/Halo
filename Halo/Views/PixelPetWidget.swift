import SwiftUI
import AppKit
import CoreGraphics
import UniformTypeIdentifiers

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
    case curious
    case sneeze
    case hiccup
    case yawn
    case panic
    case judging
    case petting
    case poked
    case chasing
    case peek
    case satisfied
    case full
    case proud
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


enum HaloPixelPalPersonality: String, Codable, CaseIterable, Identifiable {
    case cute = "Cute"
    case chaotic = "Chaotic"
    case chill = "Chill"
    case grumpy = "Grumpy"
    case shy = "Shy"

    var id: String { rawValue }

    var chaseChance: Double {
        switch self {
        case .cute: return 0.14
        case .chaotic: return 0.34
        case .chill: return 0.05
        case .grumpy: return 0.11
        case .shy: return 0.08
        }
    }

    var ambientScale: Double {
        switch self {
        case .cute: return 1.0
        case .chaotic: return 1.45
        case .chill: return 0.62
        case .grumpy: return 0.82
        case .shy: return 0.76
        }
    }
}

struct HaloPixelPalPreferences: Codable, Equatable {
    // Legacy persisted field retained so Codable stays backward-compatible.
    var showCheeks: Bool = true
    var version = 12

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
    // Optional fully opaque contrast layer behind the pixel matrix.
    // Kept separate from the legacy Background display modes so users can
    // preserve those looks while forcing Pixel Pal to stay readable.
    var pixelBackdropEnabled = false
    var pixelBackdropColor = HaloPixelPalRGB(red: 0.0, green: 0.0, blue: 0.0)
    var backgroundCornerRadius = 0.0
    var pixelCornerRadius = 0.0
    var ledShape: HaloPixelPalLEDShape = .square
    var pixelSpacing = 1.0
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
    var personality: HaloPixelPalPersonality = .cute
    var bootUpAnimation: HaloPixelPalPowerAnimationStyle = .scanline
    var bootDownAnimation: HaloPixelPalPowerAnimationStyle = .scanline
    var bootUpLEDShape: HaloPixelPalLEDShape = .square
    var bootDownLEDShape: HaloPixelPalLEDShape = .square
    var powerAnimationSpeed = 1.0

    // Personality micro-behaviours
    var alwaysCookie = true
    var pettingReaction = true
    var pokeReaction = true
    var chaseReaction = true
    var peekReaction = true
    var fileCuriosityReaction = true
    var ambientReaction = true
    var rareReaction = true
    var seasonalReaction = true
    var shortTermMoodReaction = true

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
        case backgroundStyle, backgroundColor, backgroundOpacity, pixelBackdropEnabled, pixelBackdropColor, backgroundCornerRadius, pixelCornerRadius, ledShape, pixelSpacing, inactiveLEDIntensity, inactiveLEDUsesFaceColor, inactiveLEDColor, faceScale, glowIntensity
        case accessoryMode, selectedAccessory, allowedAccessories
        case automaticBlinking, animationSpeed, animationIntensity, dizzyRotationThresholdTurns, personality
        case bootUpAnimation, bootDownAnimation, bootUpLEDShape, bootDownLEDShape, powerAnimationSpeed
        case alwaysCookie, pettingReaction, pokeReaction, chaseReaction, peekReaction
        case fileCuriosityReaction, ambientReaction, rareReaction, seasonalReaction, shortTermMoodReaction
        case hoverReaction, tapReaction, doubleTapReaction, longPressReaction
        case contextReactions, chargingReaction, lowBatteryReaction, musicReaction
        case timerReaction, appReaction, idleReaction, nightReaction
        // v3 legacy
        case showCheeks
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = 12
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
        pixelBackdropEnabled = try c.decodeIfPresent(Bool.self, forKey: .pixelBackdropEnabled) ?? false
        pixelBackdropColor = try c.decodeIfPresent(HaloPixelPalRGB.self, forKey: .pixelBackdropColor) ?? HaloPixelPalRGB(red: 0.0, green: 0.0, blue: 0.0)
        backgroundCornerRadius = try c.decodeIfPresent(Double.self, forKey: .backgroundCornerRadius) ?? 0.0
        pixelCornerRadius = try c.decodeIfPresent(Double.self, forKey: .pixelCornerRadius) ?? 0.0
        ledShape = try c.decodeIfPresent(HaloPixelPalLEDShape.self, forKey: .ledShape) ?? .square
        pixelSpacing = try c.decodeIfPresent(Double.self, forKey: .pixelSpacing) ?? 1.0
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
        personality = try c.decodeIfPresent(HaloPixelPalPersonality.self, forKey: .personality) ?? .cute
        bootUpAnimation = try c.decodeIfPresent(HaloPixelPalPowerAnimationStyle.self, forKey: .bootUpAnimation) ?? .scanline
        bootDownAnimation = try c.decodeIfPresent(HaloPixelPalPowerAnimationStyle.self, forKey: .bootDownAnimation) ?? .scanline
        bootUpLEDShape = try c.decodeIfPresent(HaloPixelPalLEDShape.self, forKey: .bootUpLEDShape) ?? ledShape
        bootDownLEDShape = try c.decodeIfPresent(HaloPixelPalLEDShape.self, forKey: .bootDownLEDShape) ?? ledShape
        powerAnimationSpeed = try c.decodeIfPresent(Double.self, forKey: .powerAnimationSpeed) ?? 1.0
        alwaysCookie = try c.decodeIfPresent(Bool.self, forKey: .alwaysCookie) ?? true
        pettingReaction = try c.decodeIfPresent(Bool.self, forKey: .pettingReaction) ?? true
        pokeReaction = try c.decodeIfPresent(Bool.self, forKey: .pokeReaction) ?? true
        chaseReaction = try c.decodeIfPresent(Bool.self, forKey: .chaseReaction) ?? true
        peekReaction = try c.decodeIfPresent(Bool.self, forKey: .peekReaction) ?? true
        fileCuriosityReaction = try c.decodeIfPresent(Bool.self, forKey: .fileCuriosityReaction) ?? true
        ambientReaction = try c.decodeIfPresent(Bool.self, forKey: .ambientReaction) ?? true
        rareReaction = try c.decodeIfPresent(Bool.self, forKey: .rareReaction) ?? true
        seasonalReaction = try c.decodeIfPresent(Bool.self, forKey: .seasonalReaction) ?? true
        shortTermMoodReaction = try c.decodeIfPresent(Bool.self, forKey: .shortTermMoodReaction) ?? true

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
        value.version = 12
        value.animationSpeed = min(2.0, max(0.35, animationSpeed))
        value.animationIntensity = min(1.0, max(0.0, animationIntensity))
        value.powerAnimationSpeed = min(1.75, max(0.5, powerAnimationSpeed))
        value.dizzyRotationThresholdTurns = min(2.0, max(0.35, dizzyRotationThresholdTurns))
        value.faceScale = min(1.0, max(0.76, faceScale))
        value.glowIntensity = min(1.0, max(0.0, glowIntensity))
        value.backgroundOpacity = min(1.0, max(0.0, backgroundOpacity))
        value.backgroundCornerRadius = min(0.5, max(0.0, backgroundCornerRadius))
        value.pixelCornerRadius = min(0.5, max(0.0, pixelCornerRadius))
        value.pixelSpacing = min(3.0, max(0.0, pixelSpacing.rounded()))
        value.inactiveLEDIntensity = min(0.35, max(0.0, inactiveLEDIntensity))
        value.customColor = Self.clamped(customColor)
        value.accentColor = Self.clamped(accentColor)
        value.blushColor = Self.clamped(blushColor)
        value.backgroundColor = Self.clamped(backgroundColor)
        value.pixelBackdropColor = Self.clamped(pixelBackdropColor)
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
    static let mouthLick = HaloPixelPalSprite(rows: [
        "p...p",
        ".ppp.",
        "...aa"
    ])
    static let fileIcon = HaloPixelPalSprite(rows: [
        "ppppp.",
        "p...pp",
        "p....p",
        "p.aa.p",
        "p....p",
        "pppppp"
    ])
    static let ghost = HaloPixelPalSprite(rows: [
        ".www.",
        "wwwww",
        "wpwpw",
        "wwwww",
        "w.w.w"
    ])
    static let butterfly = HaloPixelPalSprite(rows: [
        "a...a",
        "aa.aa",
        ".apa.",
        "aa.aa",
        "a...a"
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


enum HaloPixelPalStrokeEvent {
    case petting
    case zigzag
}

struct HaloPixelPalStrokeDetector {
    private struct Sample {
        let time: TimeInterval
        let x: Double
        let y: Double
    }

    private var samples: [Sample] = []
    private var lastTrigger = -Double.infinity
    static let window: TimeInterval = 0.95
    static let cooldown: TimeInterval = 1.45

    mutating func register(location: CGPoint, size: CGSize, at now: TimeInterval) -> HaloPixelPalStrokeEvent? {
        guard size.width > 1, size.height > 1 else {
            resetPath()
            return nil
        }
        if now - lastTrigger < Self.cooldown {
            resetPath()
            return nil
        }

        let x = Double(location.x / size.width)
        let y = Double(location.y / size.height)
        guard x >= 0, x <= 1, y >= 0, y <= 1 else {
            resetPath()
            return nil
        }

        if let last = samples.last, now - last.time > 0.24 {
            resetPath()
        }
        samples.append(.init(time: now, x: x, y: y))
        samples.removeAll { now - $0.time > Self.window }
        guard samples.count >= 7, let first = samples.first, let last = samples.last else { return nil }

        let duration = max(0.001, last.time - first.time)
        var path = 0.0
        var horizontalPath = 0.0
        var directionChanges = 0
        var lastDirection = 0
        var minX = 1.0, maxX = 0.0, minY = 1.0, maxY = 0.0

        for index in samples.indices {
            let sample = samples[index]
            minX = min(minX, sample.x); maxX = max(maxX, sample.x)
            minY = min(minY, sample.y); maxY = max(maxY, sample.y)
            guard index > samples.startIndex else { continue }
            let previous = samples[index - 1]
            let dx = sample.x - previous.x
            let dy = sample.y - previous.y
            path += hypot(dx, dy)
            horizontalPath += abs(dx)
            let direction = dx > 0.008 ? 1 : (dx < -0.008 ? -1 : 0)
            if direction != 0 {
                if lastDirection != 0 && direction != lastDirection { directionChanges += 1 }
                lastDirection = direction
            }
        }

        let speed = path / duration
        let horizontalSpan = maxX - minX
        let verticalSpread = maxY - minY
        let upperFace = samples.filter { $0.y <= 0.58 }.count >= Int(Double(samples.count) * 0.78)

        if upperFace,
           speed >= 0.18, speed <= 1.35,
           horizontalPath >= 0.28,
           horizontalSpan >= 0.16,
           verticalSpread <= 0.20,
           directionChanges >= 2 {
            lastTrigger = now
            resetPath()
            return .petting
        }

        if speed >= 1.55,
           horizontalPath >= 0.50,
           directionChanges >= 4,
           verticalSpread <= 0.45 {
            lastTrigger = now
            resetPath()
            return .zigzag
        }

        return nil
    }

    mutating func resetPath() {
        samples.removeAll(keepingCapacity: true)
    }
}

struct HaloPixelPalMoodSnapshot {
    let affection: Double
    let irritation: Double
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
    @Published private(set) var cookieFeedStarted: Date?
    @Published private(set) var cookieSatisfactionStarted: Date?
    @Published private(set) var cookieFeedOrdinal = 0
    private var tapIndex = 0
    private var pressIndex = 0
    private var tapBurst = HaloPixelPalTapBurst()

    private let defaults: UserDefaults
    private let preferencesKey = "HaloPixelPal.preferences.v4"
    private let legacyKeys = ["HaloPixelPal.preferences.v3", "HaloPixelPal.preferences.v2"]
    private var clearReactionWork: DispatchWorkItem?
    private var cookieRescueWork: DispatchWorkItem?
    private var cookieSequenceWorks: [DispatchWorkItem] = []
    private var lastCookieAt: Date?
    private var moodUpdatedAt = Date()
    private var affectionPoints = 0.0
    private var irritationPoints = 0.0
    private var lastChaseRoll = Date.distantPast

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
            recordIrritation(escalation == .furious ? 1.4 : 0.75)
            react(escalation, seconds: escalation == .furious ? 2.82 : 3.4)
            return
        }
        if preferences.pokeReaction {
            recordIrritation(0.34)
            react(.poked, seconds: 0.72)
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
        recordAffection(0.75)
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
        cancelCookieSequence()

        let started = Date()
        cookieRescueStarted = started
        cookieFeedOrdinal = 1
        recordAffection(1.0)

        let beginChew = DispatchWorkItem { [weak self] in
            guard let self, self.reaction == .furious, self.cookieRescueStarted == started else { return }
            self.cookieFeedStarted = Date()
        }
        let satisfy = DispatchWorkItem { [weak self] in
            guard let self, self.reaction == .furious, self.cookieRescueStarted == started else { return }
            self.cookieRescueStarted = nil
            self.cookieFeedStarted = nil
            self.cookieSatisfactionStarted = Date()
            self.reactionStarted = Date()
            self.reaction = .satisfied
        }
        let settle = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.cookieSatisfactionStarted = nil
            self.react(.happy, seconds: 2.4)
        }

        cookieSequenceWorks = [beginChew, satisfy, settle]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55, execute: beginChew)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.16, execute: satisfy)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.78, execute: settle)
    }

    func feedCookie() {
        if reaction == .furious {
            feedFuryCookie()
            return
        }
        guard preferences.alwaysCookie,
              cookieFeedStarted == nil,
              cookieSatisfactionStarted == nil else { return }

        let now = Date()
        if let lastCookieAt, now.timeIntervalSince(lastCookieAt) > 18 {
            cookieFeedOrdinal = 0
        }
        lastCookieAt = now
        cookieFeedOrdinal += 1

        if cookieFeedOrdinal >= 4 {
            recordAffection(0.12)
            react(.full, seconds: 2.0)
            return
        }

        cancelCookieSequence()
        clearReactionWork?.cancel()
        cookieFeedStarted = now
        cookieSatisfactionStarted = nil
        reactionStarted = now
        reaction = cookieFeedOrdinal == 2 ? .superHappy : .happy
        recordAffection(cookieFeedOrdinal == 2 ? 0.95 : 0.62)

        let ordinal = cookieFeedOrdinal
        let satisfy = DispatchWorkItem { [weak self] in
            guard let self, self.cookieFeedStarted == now else { return }
            self.cookieFeedStarted = nil
            self.cookieSatisfactionStarted = Date()
            self.reactionStarted = Date()
            self.reaction = .satisfied
        }
        let settle = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.cookieSatisfactionStarted = nil
            let final: HaloPixelPalExpression = ordinal == 2 ? .superHappy : (ordinal == 3 ? .shy : .happy)
            self.react(final, seconds: ordinal == 2 ? 2.4 : 1.9)
        }
        cookieSequenceWorks = [satisfy, settle]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.96, execute: satisfy)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.62, execute: settle)
    }

    func petted() {
        guard preferences.pettingReaction, reaction != .furious else { return }
        recordAffection(0.68)
        react(.petting, seconds: 1.15)
    }

    func peeked() {
        guard preferences.peekReaction, reaction == nil else { return }
        react(.peek, seconds: 0.92)
    }

    func fileCuriosity(dropped: Bool) {
        guard preferences.fileCuriosityReaction, reaction != .furious else { return }
        recordAffection(dropped ? 0.18 : 0.05)
        if dropped {
            react(.proud, seconds: 1.15)
        }
    }

    func considerChase(at now: Date) {
        guard preferences.chaseReaction,
              reaction == nil,
              now.timeIntervalSince(lastChaseRoll) >= 4.2 else { return }
        lastChaseRoll = now
        let mood = moodSnapshot(at: now)
        var chance = preferences.personality.chaseChance
        if mood.irritation > mood.affection + 0.8 { chance *= 1.45 }
        if Double.random(in: 0...1) < chance {
            react(preferences.personality == .shy ? .peek : .chasing, seconds: 1.18)
        }
    }

    func moodSnapshot(at date: Date) -> HaloPixelPalMoodSnapshot {
        let elapsed = max(0, date.timeIntervalSince(moodUpdatedAt))
        return .init(
            affection: max(0, affectionPoints - elapsed * 0.028),
            irritation: max(0, irritationPoints - elapsed * 0.040)
        )
    }

    private func applyMoodDecay(at date: Date) {
        let snapshot = moodSnapshot(at: date)
        affectionPoints = snapshot.affection
        irritationPoints = snapshot.irritation
        moodUpdatedAt = date
    }

    private func recordAffection(_ amount: Double) {
        guard preferences.shortTermMoodReaction else { return }
        let now = Date()
        applyMoodDecay(at: now)
        affectionPoints = min(4.0, affectionPoints + amount)
        irritationPoints = max(0, irritationPoints - amount * 0.34)
    }

    private func recordIrritation(_ amount: Double) {
        guard preferences.shortTermMoodReaction else { return }
        let now = Date()
        applyMoodDecay(at: now)
        irritationPoints = min(4.0, irritationPoints + amount)
        affectionPoints = max(0, affectionPoints - amount * 0.18)
    }

    private func cancelCookieSequence() {
        cookieRescueWork?.cancel()
        cookieSequenceWorks.forEach { $0.cancel() }
        cookieSequenceWorks.removeAll(keepingCapacity: true)
    }

    func longPressed() {
        guard preferences.longPressReaction else { return }
        let sequence: [HaloPixelPalExpression] = [.sleepy, .shy, .smug]
        recordAffection(0.24)
        react(sequence[pressIndex % sequence.count], seconds: 2.4)
        pressIndex += 1
    }

    func reset() {
        preferences = HaloPixelPalPreferences()
        reaction = nil
        clearReactionWork?.cancel()
        cookieRescueWork?.cancel()
        cancelCookieSequence()
        cookieRescueStarted = nil
        cookieFeedStarted = nil
        cookieSatisfactionStarted = nil
        cookieFeedOrdinal = 0
        lastCookieAt = nil
        affectionPoints = 0
        irritationPoints = 0
        moodUpdatedAt = Date()
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
    case file, dreamCookie, dreamHeart, dreamMusic, ghost, butterfly
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
        fileTargeted: Bool,
        audio: AudioSpectrumSnapshot,
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

        if fileTargeted && p.fileCuriosityReaction {
            let peek = Int(date.timeIntervalSinceReferenceDate * 2.0) % 5 == 0
            return .init(expression: peek ? .peek : .curious, accessory: nil, fx: .file)
        }

        if hovering && p.shortTermMoodReaction {
            let mood = pal.moodSnapshot(at: date)
            if mood.irritation >= 2.2 {
                return .init(expression: .annoyed, accessory: .horns, fx: .alert)
            }
            if mood.affection >= 2.25 {
                return .init(expression: .love, accessory: nil, fx: .hearts)
            }
        }

        guard p.contextReactions else { return resting }

        let mouseIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let keyboardIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let idleSeconds = min(mouseIdle, keyboardIdle)

        if p.timerReaction && store.finished {
            return .init(expression: .shocked, accessory: nil, fx: .alert)
        }

        if p.lowBatteryReaction, let battery = system.battery {
            if battery <= 5 {
                return .init(expression: .panic, accessory: .bandage, fx: .tears)
            }
            if battery <= 10 {
                return .init(expression: .worried, accessory: .bandage, fx: .sweat)
            }
            if battery <= 15 {
                return .init(expression: .worried, accessory: .bandage, fx: .sweat)
            }
        }

        if p.chargingReaction, let battery = system.battery, battery >= 100, !system.onBattery {
            return .init(expression: .superHappy, accessory: .crown, fx: .sparkle)
        }
        if p.chargingReaction && system.charging {
            if let battery = system.battery, battery <= 15 {
                return .init(expression: .superHappy, accessory: .halo, fx: .hearts)
            }
            return .init(expression: .love, accessory: .halo, fx: .hearts)
        }

        if p.musicReaction && media.isPlaying {
            if audio.available && (audio.bass > 0.68 || audio.overall > 0.62) {
                return .init(expression: .excited, accessory: .headphones, fx: .music)
            }
            return .init(expression: .music, accessory: .headphones, fx: .music)
        }

        if p.timerReaction, let deadline = store.deadline {
            let remaining = max(0, deadline.timeIntervalSince(date))
            if remaining <= 3.2 {
                return .init(expression: .shocked, accessory: nil, fx: .alert)
            }
            if remaining <= 10 {
                return .init(expression: .surprised, accessory: nil, fx: .alert)
            }
            return .init(expression: .focused, accessory: nil, fx: .none)
        }
        if p.timerReaction && store.pausedSeconds > 0 {
            return .init(expression: .focused, accessory: nil, fx: .none)
        }

        if p.appReaction {
            let app = NSWorkspace.shared.frontmostApplication
            let bundle = app?.bundleIdentifier?.lowercased() ?? ""
            let appName = app?.localizedName?.lowercased() ?? ""

            if bundle == "com.apple.dt.xcode" || appName == "xcode"
                || bundle.contains("unity3d") || appName == "unity" {
                return .init(expression: .focused, accessory: .glasses, fx: .none)
            }

            let gameHints = ["steam", "minecraft", "roblox", "retroarch", "whisky", "crossover"]
            if gameHints.contains(where: { bundle.contains($0) || appName.contains($0) }) {
                return .init(expression: .excited, accessory: .shades, fx: .sparkle)
            }

            let callHints = ["zoom", "facetime", "msteams", "teams"]
            if callHints.contains(where: { bundle.contains($0) || appName.contains($0) }) {
                return .init(expression: .shy, accessory: .flower, fx: .sparkle)
            }

            if bundle == "com.apple.finder" || appName == "finder" {
                return .init(expression: .curious, accessory: nil, fx: .none)
            }
        }

        if p.nightReaction {
            let hour = Calendar.autoupdatingCurrent.component(.hour, from: date)
            if hour >= 23 || hour < 5 {
                let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 36)
                if hour >= 2 && hour < 5 && idleSeconds < 30 && phase < 2.2 {
                    return .init(expression: .judging, accessory: .sleepingCap, fx: .none)
                }
                if phase < 3.0 {
                    return .init(expression: .yawn, accessory: .sleepingCap, fx: .sleepZ)
                }
                if phase < 12 {
                    return .init(expression: .sleepy, accessory: .sleepingCap, fx: .sleepZ)
                }
                if phase < 20 {
                    return .init(expression: .sleepy, accessory: .sleepingCap, fx: .dreamCookie)
                }
                if phase < 28 {
                    return .init(expression: .sleepy, accessory: .sleepingCap, fx: .dreamHeart)
                }
                return .init(expression: .sleepy, accessory: .sleepingCap, fx: .dreamMusic)
            }

            if hour >= 5 && hour < 9 {
                let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 28)
                if phase < 1.8 {
                    return .init(expression: .yawn, accessory: .sleepingCap, fx: .sleepZ)
                }
                if phase < 3.4 {
                    return .init(expression: .sleepy, accessory: .sprout, fx: .none)
                }
                return .init(expression: .happy, accessory: .sprout, fx: .sparkle)
            }
        }

        if p.seasonalReaction {
            let components = Calendar.autoupdatingCurrent.dateComponents([.month, .day], from: date)
            let month = components.month ?? 0
            let day = components.day ?? 0
            let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 50)
            if month == 10 && day >= 28 && phase < 2.2 {
                return .init(expression: .mischievous, accessory: .horns, fx: .ghost)
            }
            if month == 12 && day >= 20 && phase < 2.2 {
                return .init(expression: .proud, accessory: .crown, fx: .sparkle)
            }
            if month == 1 && day == 1 && phase < 4.0 {
                return .init(expression: .superHappy, accessory: .crown, fx: .sparkle)
            }
        }

        if p.ambientReaction && !hovering {
            let scale = max(0.5, p.personality.ambientScale)
            let cycleLength = 173.0 / scale
            let raw = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycleLength)
            let phase = raw / cycleLength * 173.0

            if phase >= 12 && phase < 12.85 {
                return .init(expression: .sneeze, accessory: nil, fx: .sparkle)
            }
            if phase >= 49 && phase < 51.2 {
                return .init(expression: .hiccup, accessory: nil, fx: .alert)
            }
            if phase >= 91 && phase < 93.0 {
                return .init(expression: .curious, accessory: nil, fx: .sparkle)
            }
            if p.rareReaction && phase >= 141 && phase < 143.2 {
                let day = Calendar.autoupdatingCurrent.ordinality(of: .day, in: .era, for: date) ?? 0
                return .init(expression: .surprised,
                             accessory: nil,
                             fx: day.isMultiple(of: 2) ? .butterfly : .ghost)
            }
        }

        if hovering && p.hoverReaction { return resting }

        if p.idleReaction && idleSeconds > 180 {
            return .init(expression: .bored, accessory: nil, fx: .none)
        }

        return resting
    }

    private static func fx(for expression: HaloPixelPalExpression) -> HaloPixelPalFX {
        switch expression {
        case .love: return .hearts
        case .superHappy, .excited, .shy, .proud, .satisfied, .petting: return .sparkle
        case .music: return .music
        case .worried: return .sweat
        case .crying, .panic: return .tears
        case .sleepy, .yawn: return .sleepZ
        case .dizzy: return .dizzy
        case .hiccup, .poked, .annoyed, .furious, .shocked, .surprised: return .alert
        default: return .none
        }
    }
}

// MARK: - Widget

private struct HaloPixelPalHostExpandedKey: EnvironmentKey {
    static let defaultValue = true
}

private struct HaloPixelPalHostTransitionDurationKey: EnvironmentKey {
    static let defaultValue = 0.3
}

extension EnvironmentValues {
    var haloPixelPalHostExpanded: Bool {
        get { self[HaloPixelPalHostExpandedKey.self] }
        set { self[HaloPixelPalHostExpandedKey.self] = newValue }
    }

    var haloPixelPalHostTransitionDuration: Double {
        get { self[HaloPixelPalHostTransitionDurationKey.self] }
        set { self[HaloPixelPalHostTransitionDurationKey.self] = newValue }
    }
}

private enum HaloPixelPalPowerPhase: Equatable {
    case on
    case off
    case bootingUp(Date, HaloPixelPalPowerAnimationStyle, TimeInterval)
    case bootingDown(Date, HaloPixelPalPowerAnimationStyle, TimeInterval)

    var pausesTimeline: Bool {
        if case .off = self { return true }
        return false
    }

    var isPoweredOn: Bool { self == .on }

    var timelineIdentity: Int {
        switch self {
        case .off: return 0
        case .on: return 1
        case .bootingUp: return 2
        case .bootingDown: return 3
        }
    }
}

@MainActor
private final class HaloPixelPalSurfacePowerController: ObservableObject {
    @Published private(set) var phase: HaloPixelPalPowerPhase = .off

    private var hostExpanded = false
    private var openingPending = false
    private var bootUpStyle: HaloPixelPalPowerAnimationStyle = .scanline
    private var bootDownStyle: HaloPixelPalPowerAnimationStyle = .scanline
    private var animationSpeed = 1.0
    private var settleWork: DispatchWorkItem?
    private var fallbackWork: DispatchWorkItem?
    private var phaseWork: DispatchWorkItem?

    func prepareForAppearance(
        expanded: Bool,
        transitionDuration: Double,
        bootUpStyle: HaloPixelPalPowerAnimationStyle,
        bootDownStyle: HaloPixelPalPowerAnimationStyle,
        animationSpeed: Double
    ) {
        cancelScheduledWork()
        configure(bootUpStyle: bootUpStyle, bootDownStyle: bootDownStyle, animationSpeed: animationSpeed)
        hostExpanded = expanded
        openingPending = false
        phase = .off

        if expanded {
            beginOpening(transitionDuration: transitionDuration)
        }
    }

    func setHostExpanded(
        _ expanded: Bool,
        transitionDuration: Double,
        bootUpStyle: HaloPixelPalPowerAnimationStyle,
        bootDownStyle: HaloPixelPalPowerAnimationStyle,
        animationSpeed: Double
    ) {
        configure(bootUpStyle: bootUpStyle, bootDownStyle: bootDownStyle, animationSpeed: animationSpeed)

        if expanded == hostExpanded {
            if expanded, phase == .off, !openingPending {
                beginOpening(transitionDuration: transitionDuration)
            }
            return
        }

        hostExpanded = expanded
        if expanded {
            beginOpening(transitionDuration: transitionDuration)
        } else {
            beginClosing()
        }
    }

    func noteGeometryChange() {
        guard hostExpanded, openingPending else { return }

        settleWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.beginBootUpIfReady()
        }
        settleWork = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + HaloPixelPalPowerAnimationTiming.geometrySettleDelay,
            execute: work
        )
    }

    private func configure(
        bootUpStyle: HaloPixelPalPowerAnimationStyle,
        bootDownStyle: HaloPixelPalPowerAnimationStyle,
        animationSpeed: Double
    ) {
        self.bootUpStyle = bootUpStyle
        self.bootDownStyle = bootDownStyle
        self.animationSpeed = min(1.75, max(0.5, animationSpeed.isFinite ? animationSpeed : 1))
    }

    private func beginOpening(transitionDuration: Double) {
        settleWork?.cancel()
        fallbackWork?.cancel()
        phaseWork?.cancel()

        openingPending = true
        phase = .off

        let fallback = DispatchWorkItem { [weak self] in
            self?.beginBootUpIfReady()
        }
        fallbackWork = fallback
        DispatchQueue.main.asyncAfter(
            deadline: .now() + HaloPixelPalPowerAnimationTiming.fallbackBootDelay(surfaceDuration: transitionDuration),
            execute: fallback
        )
    }

    private func beginClosing() {
        openingPending = false
        settleWork?.cancel()
        fallbackWork?.cancel()
        phaseWork?.cancel()

        guard phase != .off else { return }
        beginBootDown()
    }

    private func beginBootUpIfReady() {
        guard hostExpanded, openingPending else { return }

        openingPending = false
        settleWork?.cancel()
        fallbackWork?.cancel()
        phaseWork?.cancel()

        let duration = HaloPixelPalPowerAnimationTiming.duration(
            style: bootUpStyle,
            direction: .up,
            speed: animationSpeed
        )
        guard duration > 0.001 else {
            phase = .on
            return
        }

        let started = Date()
        let targetPhase = HaloPixelPalPowerPhase.bootingUp(started, bootUpStyle, duration)
        phase = targetPhase

        let work = DispatchWorkItem { [weak self] in
            guard let self, self.hostExpanded, self.phase == targetPhase else { return }
            self.phase = .on
        }
        phaseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func beginBootDown() {
        let duration = HaloPixelPalPowerAnimationTiming.duration(
            style: bootDownStyle,
            direction: .down,
            speed: animationSpeed
        )
        guard duration > 0.001 else {
            phase = .off
            return
        }

        let started = Date()
        let targetPhase = HaloPixelPalPowerPhase.bootingDown(started, bootDownStyle, duration)
        phase = targetPhase

        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.hostExpanded, self.phase == targetPhase else { return }
            self.phase = .off
        }
        phaseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func cancelScheduledWork() {
        settleWork?.cancel()
        fallbackWork?.cancel()
        phaseWork?.cancel()
        settleWork = nil
        fallbackWork = nil
        phaseWork = nil
    }
}

private struct HaloPixelPalPowerTransitionView: View {
    let phase: HaloPixelPalPowerPhase
    let preferences: HaloPixelPalPreferences
    let date: Date
    let reduceMotion: Bool

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        ZStack {
            background
            if preferences.pixelBackdropEnabled {
                preferences.pixelBackdropColor.color
            }
            Canvas { context, size in
                drawPowerAnimation(context: &context, size: size)
            }
        }
        .clipShape(HaloPixelPalRelativeRoundedRectangle(radiusFraction: preferences.backgroundCornerRadius))
        .allowsHitTesting(false)
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
                    colors: [preferences.faceColor.opacity(0.12 + 0.18 * preferences.glowIntensity), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 180
                )
                .opacity(preferences.backgroundOpacity)
            }
        }
    }

    private func drawPowerAnimation(context: inout GraphicsContext, size: CGSize) {
        let geometry = HaloPixelPalDisplayGeometry(
            size: size,
            scale: displayScale,
            fill: preferences.faceScale,
            spacing: preferences.pixelSpacing
        )
        let primary = preferences.faceColor
        let accent = preferences.accentColor.color
        let powerLEDShape: HaloPixelPalLEDShape
        switch phase {
        case .bootingUp:
            powerLEDShape = preferences.bootUpLEDShape
        case .bootingDown:
            powerLEDShape = preferences.bootDownLEDShape
        case .on, .off:
            powerLEDShape = preferences.ledShape
        }

        func paint(_ x: Int, _ y: Int, color: Color, opacity: Double = 1) {
            guard x >= 0, y >= 0,
                  x < HaloPixelPalDisplayGeometry.grid,
                  y < HaloPixelPalDisplayGeometry.grid else { return }
            let rect = geometry.led(x: x, y: y)
            HaloPixelPalLEDDrawing.fill(
                context: &context,
                rect: rect,
                color: color,
                opacity: opacity,
                shape: powerLEDShape,
                cornerRadiusFraction: preferences.pixelCornerRadius
            )
        }

        func drawEyes(opacity: Double) {
            for baseX in [6, 15] {
                for dy in 0...2 {
                    for dx in 0...2 {
                        paint(baseX + dx, 8 + dy, color: primary, opacity: opacity)
                    }
                }
                paint(baseX + 1, 8, color: .white, opacity: opacity * 0.92)
            }
        }

        func drawSmile(opacity: Double) {
            for x in 9...14 {
                let y = (x == 9 || x == 14) ? 16 : 17
                paint(x, y, color: primary, opacity: opacity)
            }
        }

        let style: HaloPixelPalPowerAnimationStyle
        let progress: Double
        let opening: Bool

        switch phase {
        case .on, .off:
            return
        case .bootingUp(let started, let selected, let duration):
            style = selected
            progress = HaloPixelPalPowerAnimationTiming.progress(
                elapsed: date.timeIntervalSince(started),
                duration: duration
            )
            opening = true
        case .bootingDown(let started, let selected, let duration):
            style = selected
            progress = HaloPixelPalPowerAnimationTiming.progress(
                elapsed: date.timeIntervalSince(started),
                duration: duration
            )
            opening = false
        }

        if style == .none { return }

        if reduceMotion {
            drawEyes(opacity: opening
                     ? HaloPixelPalPowerAnimationTiming.smoothstep(progress)
                     : 1 - HaloPixelPalPowerAnimationTiming.smoothstep(progress))
            return
        }

        switch style {
        case .scanline:
            if opening {
                let lineProgress = HaloPixelPalPowerAnimationTiming.smoothstep(progress / 0.34)
                let halfWidth = min(11, max(0, Int((11 * lineProgress).rounded())))
                let lineOpacity = 0.98 - 0.30 * HaloPixelPalPowerAnimationTiming.smoothstep((progress - 0.45) / 0.35)
                for x in max(0, 11 - halfWidth)...min(23, 12 + halfWidth) {
                    paint(x, 11, color: primary, opacity: lineOpacity)
                    paint(x, 12, color: primary, opacity: lineOpacity * 0.72)
                }
                if progress > 0.34 {
                    drawEyes(opacity: HaloPixelPalPowerAnimationTiming.smoothstep((progress - 0.34) / 0.34))
                }
                if progress > 0.64 {
                    let sparkle = HaloPixelPalPowerAnimationTiming.smoothstep((progress - 0.64) / 0.22)
                    for point in [(3, 5), (20, 4), (4, 18), (19, 19)] {
                        paint(point.0, point.1, color: accent, opacity: sparkle * 0.88)
                    }
                }
                if progress > 0.76 {
                    drawSmile(opacity: HaloPixelPalPowerAnimationTiming.smoothstep((progress - 0.76) / 0.20))
                }
            } else {
                let eyeOpacity = 1 - HaloPixelPalPowerAnimationTiming.smoothstep((progress - 0.04) / 0.36)
                if eyeOpacity > 0.001 { drawEyes(opacity: eyeOpacity) }
                let lineOpacity = HaloPixelPalPowerAnimationTiming.smoothstep((progress - 0.10) / 0.22)
                let shrink = HaloPixelPalPowerAnimationTiming.smoothstep((progress - 0.28) / 0.66)
                let halfWidth = min(11, max(0, Int((11 * (1 - shrink)).rounded())))
                if lineOpacity > 0.001 {
                    for x in max(0, 11 - halfWidth)...min(23, 12 + halfWidth) {
                        paint(x, 11, color: primary, opacity: lineOpacity)
                        paint(x, 12, color: primary, opacity: lineOpacity * 0.72)
                    }
                }
                if progress > 0.80 {
                    let dot = 1 - HaloPixelPalPowerAnimationTiming.smoothstep((progress - 0.80) / 0.20)
                    paint(11, 11, color: accent, opacity: dot)
                    paint(12, 11, color: accent, opacity: dot)
                }
            }

        case .cascade:
            let wave = progress * 28.0
            for y in 0..<24 {
                let rowIndex = opening ? Double(y) : Double(23 - y)
                let arrival = wave - rowIndex
                guard arrival > 0 else { continue }
                let rowOpacity = min(1, arrival / 3.2) * (opening ? 0.72 : max(0, 1 - progress * 0.62))
                for x in 0..<24 where (x * 3 + y * 5) % 7 == 0 {
                    paint(x, y, color: ((x + y) % 4 == 0) ? accent : primary, opacity: rowOpacity)
                }
            }
            if opening {
                if progress > 0.46 {
                    drawEyes(opacity: HaloPixelPalPowerAnimationTiming.smoothstep((progress - 0.46) / 0.30))
                }
                if progress > 0.73 {
                    drawSmile(opacity: HaloPixelPalPowerAnimationTiming.smoothstep((progress - 0.73) / 0.22))
                }
            } else {
                let fade = 1 - HaloPixelPalPowerAnimationTiming.smoothstep(progress / 0.48)
                if fade > 0.001 { drawEyes(opacity: fade) }
            }

        case .corePulse:
            let centerX = 11.5
            let centerY = 11.5
            let radius = opening
                ? 1.0 + HaloPixelPalPowerAnimationTiming.smoothstep(progress) * 15.0
                : 16.0 * (1 - HaloPixelPalPowerAnimationTiming.smoothstep(progress))
            for y in 0..<24 {
                for x in 0..<24 {
                    let distance = hypot(Double(x) - centerX, Double(y) - centerY)
                    let band = abs(distance - radius)
                    if band < 0.82 {
                        let opacity = max(0, 1 - band / 0.82)
                        paint(x, y, color: distance.truncatingRemainder(dividingBy: 2.6) < 1.3 ? primary : accent, opacity: opacity)
                    }
                }
            }
            if opening {
                if progress > 0.48 {
                    drawEyes(opacity: HaloPixelPalPowerAnimationTiming.smoothstep((progress - 0.48) / 0.30))
                }
                if progress > 0.76 {
                    drawSmile(opacity: HaloPixelPalPowerAnimationTiming.smoothstep((progress - 0.76) / 0.20))
                }
            } else {
                let fade = 1 - HaloPixelPalPowerAnimationTiming.smoothstep(progress / 0.50)
                if fade > 0.001 { drawEyes(opacity: fade) }
                if progress > 0.78 {
                    let core = 1 - HaloPixelPalPowerAnimationTiming.smoothstep((progress - 0.78) / 0.22)
                    for y in 11...12 {
                        for x in 11...12 {
                            paint(x, y, color: accent, opacity: core)
                        }
                    }
                }
            }

        case .sparkle:
            let points: [(Int, Int)] = [
                (2, 4), (19, 2), (7, 1), (14, 5), (21, 9), (3, 12),
                (9, 7), (16, 11), (5, 18), (20, 17), (11, 3), (1, 20),
                (13, 20), (18, 7), (8, 15), (22, 21), (4, 8), (15, 16)
            ]
            let litCount = Int((Double(points.count) * (opening ? progress : (1 - progress))).rounded())
            if litCount > 0 {
                for index in 0..<min(points.count, litCount) {
                    let point = points[index]
                    let pulse = 0.55 + 0.45 * sin((progress * 10 + Double(index)) * .pi)
                    paint(point.0, point.1, color: index.isMultiple(of: 3) ? accent : primary, opacity: max(0.18, pulse))
                    if index.isMultiple(of: 4) {
                        paint(point.0 + 1, point.1, color: accent, opacity: 0.46)
                        paint(point.0, point.1 + 1, color: accent, opacity: 0.46)
                    }
                }
            }
            if opening {
                if progress > 0.42 {
                    drawEyes(opacity: HaloPixelPalPowerAnimationTiming.smoothstep((progress - 0.42) / 0.28))
                }
                if progress > 0.72 {
                    drawSmile(opacity: HaloPixelPalPowerAnimationTiming.smoothstep((progress - 0.72) / 0.22))
                }
            } else {
                let fade = 1 - HaloPixelPalPowerAnimationTiming.smoothstep(progress / 0.44)
                if fade > 0.001 { drawEyes(opacity: fade) }
            }

        case .none:
            break
        }
    }
}

struct HaloPixelPetWidget: View {
    @Environment(\.openNotchGridColumnSpan) private var gridColumnSpan
    @Environment(\.openNotchGridRowSpan) private var gridRowSpan
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.haloPixelPalHostExpanded) private var hostSurfaceExpanded
    @Environment(\.haloPixelPalHostTransitionDuration) private var hostSurfaceTransitionDuration

    @StateObject private var surfacePower = HaloPixelPalSurfacePowerController()
    @State private var hovering = false
    @State private var pointer = CGPoint.zero
    @State private var precisePointer = CGPoint.zero
    @State private var cookieLingerStartedAt: Date?
    @State private var animationEpoch = Date()
    @State private var orbitDetector = HaloPixelPalCursorOrbitDetector()
    @State private var strokeDetector = HaloPixelPalStrokeDetector()
    @State private var fileDragTargeted = false

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

    private var timelineMinimumInterval: TimeInterval {
        if surfacePower.phase.isPoweredOn {
            return reduceMotion ? 0.45 : 1.0 / 24.0
        }
        return reduceMotion ? 1.0 / 24.0 : 1.0 / 60.0
    }

    private var pixelPalTimeline: some View {
        TimelineView(.animation(
            minimumInterval: timelineMinimumInterval,
            paused: surfacePower.phase.pausesTimeline
        )) { timeline in
            GeometryReader { proxy in
                let columns = min(4, max(1, gridColumnSpan ?? 1))
                let rows = min(4, max(1, gridRowSpan ?? columns))
                let squareSize = min(columns, rows)
                let side = max(1, min(proxy.size.width, proxy.size.height))

                if surfacePower.phase.isPoweredOn {
                    let audioSnapshot = AudioSpectrumService.shared.snapshot()
                let state = HaloPixelPalContext.resolve(
                    store: store,
                    media: media,
                    system: system,
                    pal: pal,
                    hovering: hovering,
                    fileTargeted: fileDragTargeted,
                    audio: audioSnapshot,
                    date: timeline.date
                )
                    let expression = resolvedExpression(base: state.expression, date: timeline.date)
                    let cookieHotzoneActive = isPointerOnCookie(expression: expression, date: timeline.date)

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
                    cookieFeedElapsed: pal.cookieFeedStarted.map { timeline.date.timeIntervalSince($0) },
                    cookieSatisfactionElapsed: pal.cookieSatisfactionStarted.map { timeline.date.timeIntervalSince($0) },
                    cookieFeedOrdinal: pal.cookieFeedOrdinal,
                    audioEnergy: audioSnapshot.available ? max(audioSnapshot.overall, audioSnapshot.bass * 0.9) : 0,
                    pointer: pal.preferences.hoverReaction && hovering ? pointer : .zero,
                    cookiePointer: hovering ? precisePointer : nil,
                    cookieLingerElapsed: cookieHotzoneActive ? cookieLingerStartedAt.map { max(0, timeline.date.timeIntervalSince($0)) } : nil,
                    showAlwaysCookie: pal.preferences.alwaysCookie,
                    onCookieTap: { pal.feedCookie() }
                )
                .frame(width: side, height: side)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .task(id: cookieHotzoneActive) {
                    guard cookieHotzoneActive else {
                        cookieLingerStartedAt = nil
                        return
                    }

                    let started = Date()
                    cookieLingerStartedAt = started
                    try? await Task.sleep(nanoseconds: 2_400_000_000)
                    guard !Task.isCancelled,
                          cookieLingerStartedAt == started,
                          isPointerOnCookie(expression: expression, date: Date()) else { return }

                    cookieLingerStartedAt = nil
                    pal.feedCookie()
                }
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        let now = Date()
                        let entering = !hovering
                        hovering = true

                        if entering,
                           pal.preferences.peekReaction,
                           (location.x <= side * 0.18 || location.x >= side * 0.82 || location.y <= side * 0.16) {
                            pal.peeked()
                        }

                        let orbitTriggered = orbitDetector.register(
                            location: location,
                            size: CGSize(width: side, height: side),
                            at: now.timeIntervalSinceReferenceDate,
                            minimumRotationTurns: pal.preferences.dizzyRotationThresholdTurns
                        )
                        if orbitTriggered {
                            strokeDetector.resetPath()
                            pal.react(.dizzy, seconds: 1.9)
                        } else if let event = strokeDetector.register(
                            location: location,
                            size: CGSize(width: side, height: side),
                            at: now.timeIntervalSinceReferenceDate
                        ) {
                            switch event {
                            case .petting: pal.petted()
                            case .zigzag: pal.react(.confused, seconds: 1.25)
                            }
                        }

                        pal.considerChase(at: now)

                        let precise = CGPoint(
                            x: (location.x / max(1, side) - 0.5) * 2,
                            y: (location.y / max(1, side) - 0.5) * 2
                        )
                        if precisePointer != precise { precisePointer = precise }
                        let next = CGPoint(x: precise.x.rounded(), y: precise.y.rounded())
                        if pointer != next { pointer = next }

                    case .ended:
                        hovering = false
                        pointer = .zero
                        precisePointer = .zero
                        cookieLingerStartedAt = nil
                        orbitDetector.resetPath()
                        strokeDetector.resetPath()
                    }
                }
                } else {
                    HaloPixelPalPowerTransitionView(
                        phase: surfacePower.phase,
                        preferences: pal.preferences,
                        date: timeline.date,
                        reduceMotion: reduceMotion
                    )
                    .frame(width: side, height: side)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
            }
        }
        .id(surfacePower.phase.timelineIdentity)
    }

    var body: some View {
        pixelPalTimeline
        .onReceive(NotificationCenter.default.publisher(for: .init("HaloPanelGeometryChanged"))) { _ in
            surfacePower.noteGeometryChange()
        }
        .contentShape(Rectangle())
        .allowsHitTesting(surfacePower.phase.isPoweredOn)
        .gesture(
            LongPressGesture(minimumDuration: 0.55)
                .onEnded { _ in pal.longPressed() }
                .exclusively(before:
                    TapGesture(count: 2).onEnded { pal.doubleTapped() }
                        .exclusively(before: TapGesture().onEnded { pal.tapped() })
                )
        )
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $fileDragTargeted) { _ in
            pal.fileCuriosity(dropped: true)
            return false
        }
        .onChange(of: fileDragTargeted) { targeted in
            if targeted { pal.fileCuriosity(dropped: false) }
        }
        .onAppear {
            surfacePower.prepareForAppearance(
                expanded: hostSurfaceExpanded,
                transitionDuration: hostSurfaceTransitionDuration,
                bootUpStyle: pal.preferences.bootUpAnimation,
                bootDownStyle: pal.preferences.bootDownAnimation,
                animationSpeed: pal.preferences.powerAnimationSpeed
            )
            syncAudioSpectrum()
        }
        .onChange(of: hostSurfaceExpanded) { expanded in
            surfacePower.setHostExpanded(
                expanded,
                transitionDuration: hostSurfaceTransitionDuration,
                bootUpStyle: pal.preferences.bootUpAnimation,
                bootDownStyle: pal.preferences.bootDownAnimation,
                animationSpeed: pal.preferences.powerAnimationSpeed
            )
        }
        .onChange(of: media.isPlaying) { _ in syncAudioSpectrum() }
        .onChange(of: surfacePower.phase) { _ in syncAudioSpectrum() }
        .onChange(of: pal.preferences.musicReaction) { _ in syncAudioSpectrum() }
        .onChange(of: pal.preferences.contextReactions) { _ in syncAudioSpectrum() }
        .onDisappear {
            hovering = false
            pointer = .zero
            precisePointer = .zero
            cookieLingerStartedAt = nil
            orbitDetector.resetPath()
            strokeDetector.resetPath()
            AudioSpectrumService.shared.setActive(false, owner: "pixel-pal")
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { pal.tapped() }
        .accessibilityAction(named: Text("Show affection")) { pal.doubleTapped() }
        .accessibilityAction(named: Text("Feed cookie")) { pal.feedCookie() }
        .contextMenu {
            Button("Feed Cookie") { pal.feedCookie() }
            Menu("Expression") {
                ForEach(HaloPixelPalExpression.allCases.filter { $0 != .blink }) { expression in
                    Button(expression.title) { pal.react(expression, seconds: 2.2) }
                }
            }
            Divider()
            Button("Pixel Pal Settings…") { HaloPixelPalSettingsWindowController.shared.show() }
        }
        .accessibilityLabel("Halo Pixel Pal")
        .help("Pet, poke, feed, drag files over, click, double-click, long-press, or draw quick cursor gestures around Pixel Pal · right-click for settings")
    }

    private func isPointerOnCookie(expression: HaloPixelPalExpression, date: Date) -> Bool {
        guard hovering else { return false }

        let target: CGPoint?
        if expression == .furious,
           pal.cookieRescueStarted == nil,
           pal.reaction == .furious {
            let elapsed = date.timeIntervalSince(pal.reactionStarted)
            target = (elapsed >= 1.05 && elapsed < 2.15) ? .zero : nil
        } else if pal.preferences.alwaysCookie,
                  expression != .furious,
                  pal.cookieFeedStarted == nil,
                  pal.cookieSatisfactionStarted == nil {
            target = CGPoint(x: 0.64, y: 0.64)
        } else {
            target = nil
        }

        guard let target else { return false }
        let dx = Double(precisePointer.x - target.x)
        let dy = Double(precisePointer.y - target.y)
        return hypot(dx, dy) <= 0.20
    }

    private func syncAudioSpectrum() {
        AudioSpectrumService.shared.setActive(
            surfacePower.phase.isPoweredOn &&
                pal.preferences.contextReactions &&
                pal.preferences.musicReaction &&
                media.isPlaying,
            owner: "pixel-pal"
        )
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

private enum HaloPixelPalLEDDrawing {
    static func path(
        in rect: CGRect,
        shape: HaloPixelPalLEDShape,
        cornerRadiusFraction: Double
    ) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        switch shape {
        case .square:
            let radius = min(rect.width, rect.height) * min(0.5, max(0, cornerRadiusFraction))
            return Path(roundedRect: rect, cornerRadius: radius)
        case .circle:
            return Path(ellipseIn: rect)
        case .triangle:
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            return path
        case .diamond:
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.closeSubpath()
            return path
        case .star:
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let outer = min(rect.width, rect.height) * 0.5
            let inner = outer * 0.45
            var path = Path()
            for index in 0..<10 {
                let angle = -Double.pi / 2 + Double(index) * Double.pi / 5
                let radius = index.isMultiple(of: 2) ? outer : inner
                let point = CGPoint(
                    x: center.x + CGFloat(cos(angle)) * radius,
                    y: center.y + CGFloat(sin(angle)) * radius
                )
                if index == 0 { path.move(to: point) }
                else { path.addLine(to: point) }
            }
            path.closeSubpath()
            return path
        case .hexagon:
            var path = Path()
            let points = [
                CGPoint(x: rect.minX + rect.width * 0.25, y: rect.minY),
                CGPoint(x: rect.minX + rect.width * 0.75, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.midY),
                CGPoint(x: rect.minX + rect.width * 0.75, y: rect.maxY),
                CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.midY)
            ]
            path.move(to: points[0])
            for point in points.dropFirst() { path.addLine(to: point) }
            path.closeSubpath()
            return path
        case .cross:
            var path = Path()
            let x1 = rect.minX + rect.width * 0.34
            let x2 = rect.minX + rect.width * 0.66
            let y1 = rect.minY + rect.height * 0.34
            let y2 = rect.minY + rect.height * 0.66
            let points = [
                CGPoint(x: x1, y: rect.minY), CGPoint(x: x2, y: rect.minY),
                CGPoint(x: x2, y: y1), CGPoint(x: rect.maxX, y: y1),
                CGPoint(x: rect.maxX, y: y2), CGPoint(x: x2, y: y2),
                CGPoint(x: x2, y: rect.maxY), CGPoint(x: x1, y: rect.maxY),
                CGPoint(x: x1, y: y2), CGPoint(x: rect.minX, y: y2),
                CGPoint(x: rect.minX, y: y1), CGPoint(x: x1, y: y1)
            ]
            path.move(to: points[0])
            for point in points.dropFirst() { path.addLine(to: point) }
            path.closeSubpath()
            return path
        }
    }

    static func fill(
        context: inout GraphicsContext,
        rect: CGRect,
        color: Color,
        opacity: Double = 1,
        shape: HaloPixelPalLEDShape,
        cornerRadiusFraction: Double
    ) {
        let antialias = shape != .square || cornerRadiusFraction > 0.001
        context.fill(
            path(in: rect, shape: shape, cornerRadiusFraction: cornerRadiusFraction),
            with: .color(color.opacity(min(1, max(0, opacity)))),
            style: FillStyle(antialiased: antialias)
        )
    }
}

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
    var cookieFeedElapsed: TimeInterval? = nil
    var cookieSatisfactionElapsed: TimeInterval? = nil
    var cookieFeedOrdinal: Int = 0
    var audioEnergy: Double = 0
    var pointer: CGPoint = .zero
    var cookiePointer: CGPoint? = nil
    var cookieLingerElapsed: TimeInterval? = nil
    var showAlwaysCookie = true
    var onCookieTap: (() -> Void)? = nil
    @Environment(\.displayScale) private var displayScale

    private let logicalGrid = 24

    private var isEatingFuryCookie: Bool {
        guard expression == .furious, let rescue = cookieRescueElapsed else { return false }
        return rescue >= 0.55 && rescue < 1.16
    }

    private var isEatingSnackCookie: Bool {
        guard let elapsed = cookieFeedElapsed else { return false }
        return elapsed >= 0 && elapsed < 0.96
    }

    private var isEatingAnyCookie: Bool { isEatingFuryCookie || isEatingSnackCookie }

    private var cookieChewElapsed: TimeInterval {
        if isEatingFuryCookie { return max(0, (cookieRescueElapsed ?? 0) - 0.55) }
        return max(0, cookieFeedElapsed ?? 0)
    }

    private var isCookieSatisfied: Bool {
        expression == .satisfied || cookieSatisfactionElapsed != nil
    }

    /// Cookie positions use the same -1...1 normalized coordinate space as the
    /// pointer. The normal snack lives at 82%/82% of the face; the fury rescue
    /// cookie is centered behind the shutter.
    private var cookieTargetCenter: CGPoint? {
        if expression == .furious,
           cookieRescueElapsed == nil,
           let reactionElapsed,
           reactionElapsed >= 1.05,
           reactionElapsed < 2.15,
           onCookieTap != nil {
            return .zero
        }
        if showAlwaysCookie,
           expression != .furious,
           !isEatingSnackCookie,
           !isCookieSatisfied,
           onCookieTap != nil {
            return CGPoint(x: 0.64, y: 0.64)
        }
        return nil
    }

    /// Smooth 0...1 anticipation value. It begins before the cursor reaches the
    /// cookie hit target, so the pet visibly notices food approaching.
    private var cookieApproachIntensity: Double {
        guard let cursor = cookiePointer, let target = cookieTargetCenter else { return 0 }
        let dx = Double(cursor.x - target.x)
        let dy = Double(cursor.y - target.y)
        let distance = hypot(dx, dy)
        let outerRadius = expression == .furious ? 0.78 : 0.72
        let innerRadius = 0.10
        let linear = min(1.0, max(0.0, (outerRadius - distance) / (outerRadius - innerRadius)))
        return linear * linear * (3.0 - 2.0 * linear)
    }

    private var isCookieAnticipating: Bool {
        !isEatingAnyCookie && cookieApproachIntensity > 0.035
    }

    private var cookieTeaseElapsed: TimeInterval {
        max(0, cookieLingerElapsed ?? 0)
    }

    private var isCookieDrooling: Bool {
        !isEatingAnyCookie && cookieLingerElapsed != nil && cookieTeaseElapsed >= 0.90
    }

    private var isCookieReaching: Bool {
        !isEatingAnyCookie && cookieLingerElapsed != nil && cookieTeaseElapsed >= 1.65
    }

    private var cookieReachProgress: Double {
        min(1.0, max(0.0, (cookieTeaseElapsed - 1.65) / 0.75))
    }

    private var faceColor: Color {
        expression == .furious && !isEatingFuryCookie ? Color(red: 1.0, green: 0.11, blue: 0.07) : preferences.faceColor
    }
    private var accentColor: Color {
        expression == .furious && !isEatingFuryCookie ? Color(red: 1.0, green: 0.52, blue: 0.08) : preferences.accentColor.color
    }
    private var blushColor: Color {
        expression == .furious && !isEatingFuryCookie ? Color(red: 0.62, green: 0.02, blue: 0.02) : preferences.blushColor.color
    }

    var body: some View {
        ZStack {
            ZStack {
                background
                if preferences.pixelBackdropEnabled {
                    preferences.pixelBackdropColor.color
                }
                if preferences.inactiveLEDIntensity > 0.001 {
                    Canvas { context, size in
                        let geometry = HaloPixelPalDisplayGeometry(size: size, scale: displayScale, fill: preferences.faceScale, spacing: preferences.pixelSpacing)
                        let inactiveColor = preferences.inactiveLEDUsesFaceColor ? faceColor : preferences.inactiveLEDColor.color
                        for y in 0..<logicalGrid {
                            for x in 0..<logicalGrid {
                                let rect = geometry.led(x: x, y: y)
                                HaloPixelPalLEDDrawing.fill(
                                    context: &context,
                                    rect: rect,
                                    color: inactiveColor,
                                    opacity: preferences.inactiveLEDIntensity,
                                    shape: preferences.ledShape,
                                    cornerRadiusFraction: preferences.pixelCornerRadius
                                )
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

            if isEatingSnackCookie, let elapsed = cookieFeedElapsed {
                Canvas { context, size in
                    drawFuryCookie(
                        context: &context,
                        size: size,
                        consumeProgress: min(1.0, max(0.0, elapsed / 0.90))
                    )
                }
                .allowsHitTesting(false)
            }

            if showAlwaysCookie,
               expression != .furious,
               !isEatingSnackCookie,
               !isCookieSatisfied,
               let onCookieTap {
                Canvas { context, size in
                    drawCookieBadge(context: &context, size: size)
                }
                .allowsHitTesting(false)

                GeometryReader { proxy in
                    let side = min(proxy.size.width, proxy.size.height)
                    let hitSize = max(24.0, side * 0.24)
                    Button(action: onCookieTap) {
                        Color.clear
                            .frame(width: hitSize, height: hitSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(x: proxy.size.width * 0.82, y: proxy.size.height * 0.82)
                    .accessibilityLabel("Feed Pixel Pal a cookie")
                    .help("Feed Pixel Pal")
                }
            }

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

                if let rescue = cookieRescueElapsed, rescue >= 0.55 {
                    Canvas { context, size in
                        drawFuryCookie(
                            context: &context,
                            size: size,
                            consumeProgress: min(1.0, max(0.0, (rescue - 0.55) / 0.52))
                        )
                    }
                    .allowsHitTesting(false)
                }

                if cookieRescueElapsed == nil, reactionElapsed >= 1.05, reactionElapsed < 2.15, let onCookieTap {
                    GeometryReader { proxy in
                        let hitSize = max(26.0, min(proxy.size.width, proxy.size.height) * 0.34)
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


    private func drawCookieBadge(context: inout GraphicsContext, size: CGSize) {
        let pattern = [
            ".bbb.",
            "bbdbb",
            "bbbbb",
            "bdbdb",
            ".bbb."
        ]
        let pixel = max(1.0, min(size.width, size.height) / 34.0)
        let badgeSide = pixel * 5.0
        let origin = CGPoint(
            x: size.width * 0.82 - badgeSide / 2.0,
            y: size.height * 0.82 - badgeSide / 2.0
        )
        let dough = Color(red: 0.94, green: 0.58, blue: 0.19)
        let edge = Color(red: 0.66, green: 0.30, blue: 0.075)
        let chip = Color(red: 0.24, green: 0.08, blue: 0.02)

        for (y, row) in pattern.enumerated() {
            for (x, value) in row.enumerated() where value != "." {
                let rect = CGRect(
                    x: origin.x + CGFloat(x) * pixel,
                    y: origin.y + CGFloat(y) * pixel,
                    width: pixel,
                    height: pixel
                )
                let outer = x == 0 || x == 4 || y == 0 || y == 4
                HaloPixelPalLEDDrawing.fill(
                    context: &context,
                    rect: cookieLEDRect(rect),
                    color: value == "d" ? chip : (outer ? edge : dough),
                    shape: preferences.ledShape,
                    cornerRadiusFraction: preferences.pixelCornerRadius
                )
            }
        }
    }

    private func cookieLEDRect(_ rect: CGRect) -> CGRect {
        let backing = max(1, displayScale)
        let requestedGap = CGFloat(min(3.0, max(0.0, preferences.pixelSpacing.rounded()))) / backing
        let inset = min(
            requestedGap * 0.5,
            max(0, min(rect.width, rect.height) * 0.5 - 0.5 / backing)
        )
        return rect.insetBy(dx: inset, dy: inset)
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
        let ledUnit = max(1.0, min(size.width, size.height) / CGFloat(logicalGrid))

        func paintRect(_ rect: CGRect, _ color: Color) {
            let radius = min(min(rect.width, rect.height) * 0.5, ledUnit * preferences.pixelCornerRadius)
            context.fill(
                Path(roundedRect: rect, cornerRadius: radius),
                with: .color(color),
                style: FillStyle(antialiased: preferences.pixelCornerRadius > 0.001)
            )
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

        if cookieRescueElapsed != nil {
            drawFuryCookie(context: &context, size: size, consumeProgress: 0)
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
        let pixel = max(1.0, min(size.width, size.height) / 27.0)
        let cookieSide = pixel * 7.0
        let origin = CGPoint(x: (size.width - cookieSide) / 2.0, y: (size.height - cookieSide) / 2.0)
        let visibleColumns = max(0, min(7, Int(ceil(7.0 * (1.0 - consumeProgress)))))
        let dough = Color(red: 0.92, green: 0.55, blue: 0.18)
        let edge = Color(red: 0.62, green: 0.28, blue: 0.07)
        let chip = Color(red: 0.25, green: 0.09, blue: 0.025)

        func paintCookiePixel(_ rect: CGRect, _ color: Color) {
            HaloPixelPalLEDDrawing.fill(
                context: &context,
                rect: cookieLEDRect(rect),
                color: color,
                shape: preferences.ledShape,
                cornerRadiusFraction: preferences.pixelCornerRadius
            )
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
        let geometry = HaloPixelPalDisplayGeometry(size: size, scale: displayScale, fill: preferences.faceScale, spacing: preferences.pixelSpacing)

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
                    HaloPixelPalLEDDrawing.fill(
                        context: &context,
                        rect: rect,
                        color: color(for: role),
                        opacity: opacity,
                        shape: preferences.ledShape,
                        cornerRadiusFraction: preferences.pixelCornerRadius
                    )
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

    private enum EyePose { case open, happy, closed, heart, star, winkLeft, winkRight, confused, dizzy, cookieAnticipation, cookieMunch, furious, smug }

    private var eyePose: EyePose {
        if isEatingAnyCookie { return .cookieMunch }
        if isCookieAnticipating { return .cookieAnticipation }
        switch expression {
        case .blink, .sleepy, .bored: return .closed
        case .happy, .superHappy, .music, .shy, .petting, .satisfied, .proud: return .happy
        case .love: return .heart
        case .excited, .shocked, .panic: return .star
        case .wink, .mischievous, .peek: return .winkRight
        case .confused, .curious, .judging: return .confused
        case .sneeze, .yawn: return .closed
        case .hiccup, .poked: return .winkLeft
        case .chasing: return .open
        case .full: return .smug
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
        case .cookieAnticipation:
            let happy = HaloPixelPalSprites.happyEye(preferences.eyeStyle)
            if cookieApproachIntensity >= 0.62 {
                let star = HaloPixelPalSprites.starEye
                render(.init(star, x: leftX, y: y), 1, 0, 0)
                render(.init(star, x: rightX, y: y, mirrorX: true), 1, 0, 0)
            } else {
                render(.init(happy, x: leftX, y: y + 1), 1, 0, 0)
                render(.init(happy, x: rightX, y: y + 1, mirrorX: true), 1, 0, 0)
            }
        case .cookieMunch:
            let happy = HaloPixelPalSprites.happyEye(preferences.eyeStyle)
            let closed = HaloPixelPalSprites.closedEye(preferences.eyeStyle)
            let chewPhase = Int(cookieChewElapsed * (cookieFeedOrdinal == 2 ? 18.0 : 14.0)) % 2
            if cookieFeedOrdinal == 2 {
                let star = HaloPixelPalSprites.starEye
                if chewPhase == 0 {
                    render(.init(star, x: leftX, y: y), 1, 0, 0)
                    render(.init(happy, x: rightX, y: y + 1, mirrorX: true), 1, 0, 0)
                } else {
                    render(.init(happy, x: leftX, y: y + 1), 1, 0, 0)
                    render(.init(star, x: rightX, y: y, mirrorX: true), 1, 0, 0)
                }
            } else if chewPhase == 0 {
                render(.init(happy, x: leftX, y: y + 1), 1, 0, 0)
                render(.init(closed, x: rightX, y: y + 2, mirrorX: true), 1, 0, 0)
            } else {
                render(.init(closed, x: leftX, y: y + 2), 1, 0, 0)
                render(.init(happy, x: rightX, y: y + 1, mirrorX: true), 1, 0, 0)
            }
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
        if isEatingAnyCookie || isCookieSatisfied { return }
        let leftX = 3
        if isCookieAnticipating {
            if cookieApproachIntensity < 0.62 {
                render(.init(HaloPixelPalSprites.raisedBrow, x: leftX, y: 3), 0.94, 0, 0)
                render(.init(HaloPixelPalSprites.raisedBrow, x: 16, y: 3, mirrorX: true), 0.94, 0, 0)
            }
            return
        }
        let rightX = 16
        let y = 4
        switch expression {
        case .worried, .sad, .crying, .shy, .panic:
            render(.init(HaloPixelPalSprites.worriedBrow, x: leftX, y: y), 0.95, 0, 0)
            render(.init(HaloPixelPalSprites.worriedBrow, x: rightX, y: y, mirrorX: true), 0.95, 0, 0)
        case .furious:
            render(.init(HaloPixelPalSprites.furiousBrow, x: leftX, y: 2), 1, 0, 0)
            render(.init(HaloPixelPalSprites.furiousBrow, x: rightX, y: 2, mirrorX: true), 1, 0, 0)
        case .annoyed, .focused, .judging, .full:
            render(.init(HaloPixelPalSprites.annoyedBrow, x: leftX, y: y), 0.95, 0, 0)
            render(.init(HaloPixelPalSprites.annoyedBrow, x: rightX, y: y, mirrorX: true), 0.95, 0, 0)
        case .surprised, .shocked, .hiccup, .poked:
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
        case .confused, .dizzy, .curious, .hiccup, .poked, .panic: return HaloPixelPalSprites.mouthO
        case .blink, .sleepy, .bored, .judging: return HaloPixelPalSprites.mouthFlat
        case .happy, .music, .petting, .proud: return HaloPixelPalSprites.mouthSmile
        case .superHappy, .excited, .love: return HaloPixelPalSprites.mouthBigSmile
        case .surprised, .shocked, .sneeze, .yawn: return HaloPixelPalSprites.mouthOpen
        case .worried, .sad, .crying, .annoyed: return HaloPixelPalSprites.mouthFrown
        case .furious: return HaloPixelPalSprites.mouthGrimace
        case .shy: return HaloPixelPalSprites.mouthTiny
        case .mischievous, .smug, .wink, .chasing, .peek, .full: return HaloPixelPalSprites.mouthSmug
        case .satisfied: return HaloPixelPalSprites.mouthLick
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
    let mouth: HaloPixelPalSprite?
    if isEatingAnyCookie {
        let chewPhase = Int(cookieChewElapsed * (cookieFeedOrdinal == 2 ? 18.0 : 14.0)) % 2
        mouth = chewPhase == 0 ? HaloPixelPalSprites.mouthOpen : HaloPixelPalSprites.mouthTiny
    } else if isCookieAnticipating {
        mouth = cookieApproachIntensity >= 0.62 ? HaloPixelPalSprites.mouthOpen : HaloPixelPalSprites.mouthBigSmile
    } else {
        mouth = selectedMouth()
    }
    guard let mouth else { return }
    let x = max(0, (logicalGrid - mouth.width) / 2)
    let y = (isEatingAnyCookie || isCookieAnticipating) ? 15 : (expression == .superHappy || expression == .excited ? 15 : 16)
    render(.init(mouth, x: x, y: y), 1, 0, 0)
}

    private func drawCheeks(render: (HaloPixelPalPlacedSprite, Double, Int, Int) -> Void) {
    if expression == .furious && !isEatingFuryCookie { return }
    let sprite: HaloPixelPalSprite
    if isEatingAnyCookie || isCookieSatisfied || isCookieAnticipating {
        sprite = HaloPixelPalSprites.cheekKawaii
    } else {
        switch preferences.cheekStyle {
        case .none: return
        case .soft: sprite = HaloPixelPalSprites.cheekSoft
        case .kawaii: sprite = HaloPixelPalSprites.cheekKawaii
        case .shy: sprite = HaloPixelPalSprites.cheekShy
        }
    }
    let opacity: Double = isEatingAnyCookie || isCookieSatisfied || isCookieAnticipating || expression == .shy || expression == .love || expression == .petting ? 1.0 : 0.90
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
        let accessory = resolvedAccessory
        if (isEatingAnyCookie || isCookieSatisfied) && accessory == .horns { return }
        switch accessory {
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
        if isEatingAnyCookie { return }
        let phase = reduceMotion || preferences.animationIntensity == 0 ? 0 : Int(max(0, animationTime) * max(0.35, preferences.animationSpeed) * 4) % 4
        let lift = -(phase / 2)
        if isCookieDrooling {
            let drip = reduceMotion ? 0 : Int((cookieTeaseElapsed * 4.0).truncatingRemainder(dividingBy: 3.0))
            render(.init(HaloPixelPalSprites.tear, x: 13, y: 18), 0.96, 0, drip)
            if isCookieReaching {
                render(.init(HaloPixelPalSprites.sparkle, x: 1, y: 3), 0.92, 0, lift)
                render(.init(HaloPixelPalSprites.sparkle, x: 20, y: 2), 0.82, 0, -lift)
            }
            return
        }
        if isCookieAnticipating && cookieApproachIntensity >= 0.72 {
            render(.init(HaloPixelPalSprites.sparkle, x: 1, y: 3), 0.82, 0, lift)
            render(.init(HaloPixelPalSprites.sparkle, x: 20, y: 2), 0.72, 0, -lift)
            return
        }
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
        case .file:
            render(.init(HaloPixelPalSprites.fileIcon, x: 9, y: 1), 0.88, 0, lift)
        case .dreamCookie:
            render(.init(HaloPixelPalSprites.heart, x: 19, y: 3), 0.28, 0, lift)
            render(.init(HaloPixelPalSprites.sparkle, x: 21, y: 1), 0.42, 0, lift - 1)
        case .dreamHeart:
            render(.init(HaloPixelPalSprites.heart, x: 20, y: 2), 0.72, 0, lift)
        case .dreamMusic:
            render(.init(HaloPixelPalSprites.musicNote, x: 20, y: 2), 0.68, 0, lift)
        case .ghost:
            render(.init(HaloPixelPalSprites.ghost, x: 19, y: 2), 0.72, 0, lift)
        case .butterfly:
            render(.init(HaloPixelPalSprites.butterfly, x: 19, y: 3), 0.78, 0, -lift)
        }
    }

    private func logicalMotion() -> (x: Int, y: Int) {
        guard !reduceMotion else { return (0, 0) }
        let speed = max(0.35, preferences.animationSpeed)
        let intensity = preferences.animationIntensity
        let t = max(0, animationTime) * speed
        let one = intensity > 0.28 ? 1 : 0
        let two = intensity > 0.75 ? 2 : one
        if isCookieReaching {
            let target = cookieTargetCenter ?? .zero
            let reach = Int(round(cookieReachProgress * Double(max(1, two))))
            let xDirection = target.x > 0.08 ? 1 : (target.x < -0.08 ? -1 : 0)
            let yDirection = target.y > 0.08 ? 1 : (target.y < -0.08 ? -1 : 0)
            let tremble = Int(round(sin(t * 14.0))) * one
            return (xDirection * reach + tremble, yDirection * reach)
        }
        if isCookieAnticipating {
            let eagerness = cookieApproachIntensity
            let hopRate = 5.0 + eagerness * 4.5
            let hop = Int(round(sin(t * hopRate))) < 0 ? -one : 0
            let wiggle = eagerness >= 0.70 ? Int(round(sin(t * 8.5))) * one : 0
            return (wiggle, hop)
        }
        if let reactionElapsed {
            if isEatingAnyCookie {
                let chew = Int(cookieChewElapsed * (cookieFeedOrdinal == 2 ? 18.0 : 14.0)) % 2
                return (0, chew == 0 ? -one : 0)
            }
            if expression == .dizzy {
                return (Int(round(sin(t * 10.5))) * two, Int(round(cos(t * 7.5))) * one)
            }
            if expression == .petting {
                return (Int(pointer.x) * one, Int(round(sin(t * 4.0))) < 0 ? -one : 0)
            }
            if expression == .poked {
                return (-Int(pointer.x) * one, Int(round(abs(sin(t * 9.5)))) * -one)
            }
            if expression == .chasing {
                return (Int(pointer.x) * two, Int(pointer.y) * one)
            }
            if expression == .peek {
                return (Int(pointer.x) * two, 0)
            }
            if expression == .sneeze {
                return (Int(round(sin(t * 16.0))) * one, Int(round(abs(sin(t * 8.0)))) * one)
            }
            if expression == .hiccup {
                return (0, Int(round(abs(sin(t * 7.0)))) * -two)
            }
            if expression == .panic {
                return (Int(round(sin(t * 17.0))) * two, Int(round(cos(t * 13.0))) * one)
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
        case .music:
            let beat = audioEnergy > 0.68 ? two : (audioEnergy > 0.34 ? one : 0)
            return (Int(round(sin(t * 6.4))) * one, -beat)
        case .excited:
            let beat = audioEnergy > 0.62 ? two : one
            return (Int(round(sin(t * 6.4))) * one, Int(round(cos(t * 6.4))) * beat)
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
        case .petting:
            return (Int(pointer.x) * one, Int(round(sin(t * 3.8))) < 0 ? -one : 0)
        case .poked:
            return (-Int(pointer.x) * one, -one)
        case .chasing:
            return (Int(pointer.x) * two, Int(pointer.y) * one)
        case .peek:
            return (Int(pointer.x) * two, 0)
        case .sneeze:
            return (Int(round(sin(t * 15.0))) * one, one)
        case .hiccup:
            return (0, Int(round(abs(sin(t * 7.0)))) * -two)
        case .panic:
            return (Int(round(sin(t * 17.0))) * two, Int(round(cos(t * 12.0))) * one)
        case .yawn:
            return (0, Int(round(sin(t * 1.2))) * one)
        case .satisfied, .proud:
            return (0, Int(round(sin(t * 3.1))) < 0 ? -one : 0)
        case .judging, .full:
            return (0, one)
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
    @State private var powerPreviewPhase: HaloPixelPalPowerPhase = .on
    @State private var powerPreviewToken = UUID()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                appearanceSection
                accessorySection
                powerAnimationSection
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

                Divider()

                Toggle("Solid pixel backdrop", isOn: bind(\.pixelBackdropEnabled))
                if pal.preferences.pixelBackdropEnabled {
                    ColorPicker("Backdrop color", selection: rgbBinding(\.pixelBackdropColor), supportsOpacity: false)
                }
                Text("Adds a solid color behind Pixel Pal so it always remains visible, no matter the background color. You can turn this off at any time.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

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
                Text("LED shape").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ledShapeGrid
                if pal.preferences.ledShape == .square {
                    HStack {
                        Text("Pixel corner radius")
                        Slider(value: bind(\.pixelCornerRadius), in: 0...0.5)
                        Text("\(Int(pal.preferences.pixelCornerRadius * 100))%")
                            .font(.caption.monospacedDigit())
                            .frame(width: 38, alignment: .trailing)
                    }
                }
                HStack {
                    Text("Pixel spacing")
                    Slider(value: bind(\.pixelSpacing), in: 0...3, step: 1)
                    Text("\(Int(pal.preferences.pixelSpacing)) px")
                        .font(.caption.monospacedDigit())
                        .frame(width: 38, alignment: .trailing)
                }
                Text("Sets the gap between logical LEDs in physical display pixels. Small Pixel Pal sizes automatically cap the gap so LEDs remain visible.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

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

    private var ledShapeGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(HaloPixelPalLEDShape.allCases) { shape in
                previewTile(title: shape.rawValue, selected: shape == pal.preferences.ledShape) {
                    pal.update(\.ledShape, shape)
                } preview: {
                    Canvas { context, size in
                        let columns = 3
                        let spacing: CGFloat = 5
                        let cell = min(
                            (size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns),
                            (size.height - spacing * CGFloat(columns - 1)) / CGFloat(columns)
                        )
                        let total = cell * CGFloat(columns) + spacing * CGFloat(columns - 1)
                        let origin = CGPoint(x: (size.width - total) / 2, y: (size.height - total) / 2)

                        for y in 0..<columns {
                            for x in 0..<columns {
                                let rect = CGRect(
                                    x: origin.x + CGFloat(x) * (cell + spacing),
                                    y: origin.y + CGFloat(y) * (cell + spacing),
                                    width: cell,
                                    height: cell
                                )
                                HaloPixelPalLEDDrawing.fill(
                                    context: &context,
                                    rect: rect,
                                    color: pal.preferences.faceColor,
                                    shape: shape,
                                    cornerRadiusFraction: pal.preferences.pixelCornerRadius
                                )
                            }
                        }
                    }
                }
            }
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

    private var powerAnimationSection: some View {
        GroupBox("Power animations") {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 11) {
                    Picker("Boot up", selection: bind(\.bootUpAnimation)) {
                        ForEach(HaloPixelPalPowerAnimationStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Boot down", selection: bind(\.bootDownAnimation)) {
                        ForEach(HaloPixelPalPowerAnimationStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Boot up LED shape", selection: bind(\.bootUpLEDShape)) {
                        ForEach(HaloPixelPalLEDShape.allCases) { shape in
                            Text(shape.rawValue).tag(shape)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Boot down LED shape", selection: bind(\.bootDownLEDShape)) {
                        ForEach(HaloPixelPalLEDShape.allCases) { shape in
                            Text(shape.rawValue).tag(shape)
                        }
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Text("Power animation speed")
                        Slider(value: bind(\.powerAnimationSpeed), in: 0.5...1.75)
                        Text("\(pal.preferences.powerAnimationSpeed, specifier: "%.2f")×")
                            .font(.caption.monospacedDigit())
                            .frame(width: 48, alignment: .trailing)
                    }

                    HStack {
                        Button("Preview boot up") { previewPowerAnimation(opening: true) }
                        Button("Preview boot down") { previewPowerAnimation(opening: false) }
                    }

                    Text("Boot up finishes before the live face appears. Boot down finishes before Halo starts retracting.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 24.0 : 1.0 / 60.0)) { timeline in
                    Group {
                        if powerPreviewPhase.isPoweredOn {
                            HaloPixelPalFace(
                                expression: .happy,
                                contextualAccessory: nil,
                                fx: .none,
                                squareSize: 2,
                                preferences: pal.preferences,
                                date: timeline.date,
                                reduceMotion: reduceMotion,
                                animationTime: timeline.date.timeIntervalSince(previewEpoch)
                            )
                        } else {
                            HaloPixelPalPowerTransitionView(
                                phase: powerPreviewPhase,
                                preferences: pal.preferences,
                                date: timeline.date,
                                reduceMotion: reduceMotion
                            )
                        }
                    }
                }
                .id(powerPreviewPhase.timelineIdentity)
                .frame(width: 118, height: 118)
                .background(Color.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.top, 4)
        }
    }

    private func previewPowerAnimation(opening: Bool) {
        let style = opening ? pal.preferences.bootUpAnimation : pal.preferences.bootDownAnimation
        let direction: HaloPixelPalPowerAnimationDirection = opening ? .up : .down
        let duration = HaloPixelPalPowerAnimationTiming.duration(
            style: style,
            direction: direction,
            speed: pal.preferences.powerAnimationSpeed
        )
        let token = UUID()
        powerPreviewToken = token

        guard duration > 0.001 else {
            powerPreviewPhase = opening ? .on : .off
            return
        }

        let started = Date()
        powerPreviewPhase = opening
            ? .bootingUp(started, style, duration)
            : .bootingDown(started, style, duration)

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            guard powerPreviewToken == token else { return }
            powerPreviewPhase = opening ? .on : .off
        }
    }

    private var interactionSection: some View {
        GroupBox("Animation & interactions") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Personality", selection: bind(\.personality)) {
                    ForEach(HaloPixelPalPersonality.allCases) { Text($0.rawValue).tag($0) }
                }
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
                Text("How much fast circular cursor movement is required before Pixel Pal becomes dizzy. Lower values trigger sooner.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Toggle("Always show feed cookie", isOn: bind(\.alwaysCookie))
                Toggle("Cursor petting", isOn: bind(\.pettingReaction))
                Toggle("Cursor poking", isOn: bind(\.pokeReaction))
                Toggle("Random cursor chase / avoidance", isOn: bind(\.chaseReaction))
                Toggle("Peek from edges", isOn: bind(\.peekReaction))
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
                Toggle("File-drag curiosity", isOn: bind(\.fileCuriosityReaction))
                Toggle("Short-term affection / irritation memory", isOn: bind(\.shortTermMoodReaction))
                Toggle("Ambient micro-events (sneeze, hiccup, curiosity)", isOn: bind(\.ambientReaction))
                Toggle("Rare encounters", isOn: bind(\.rareReaction))
                Toggle("Seasonal reactions", isOn: bind(\.seasonalReaction))

                if pal.preferences.contextReactions {
                    Toggle("Charging", isOn: bind(\.chargingReaction))
                    Toggle("Low battery", isOn: bind(\.lowBatteryReaction))
                    Toggle("Music playback + beat response", isOn: bind(\.musicReaction))
                    Toggle("Timer anticipation", isOn: bind(\.timerReaction))
                    Toggle("Xcode, Unity, games, Finder and calls", isOn: bind(\.appReaction))
                    Toggle("Idle / away", isOn: bind(\.idleReaction))
                    Toggle("Time of day (wake-up / sleep / dreams)", isOn: bind(\.nightReaction))
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
                    ForEach([HaloPixelPalExpression.happy, .superHappy, .love, .curious, .petting, .poked, .sneeze, .hiccup, .satisfied, .full, .dizzy, .furious, .shy, .mischievous, .surprised, .worried, .crying, .wink, .music]) { expression in
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
            Text("Pixel Pal v2 uses a 24×24 authored pixel canvas with layered expressions, accessories, contextual FX and a bounded personality engine. It remains face-first: no hunger bars, rooms, inventory loops or pet-care chores.")
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
        case .superHappy, .excited, .shy, .proud, .satisfied, .petting: return .sparkle
        case .music: return .music
        case .worried: return .sweat
        case .crying, .panic: return .tears
        case .sleepy, .yawn: return .sleepZ
        case .dizzy: return .dizzy
        case .hiccup, .poked, .annoyed, .furious, .surprised, .shocked: return .alert
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
