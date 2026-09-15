import SwiftUI
import AppKit
import CoreGraphics

// MARK: - Pixel Pal
// Pixel Pal is a face-only retro expression widget.
// It deliberately avoids bodies, habitats, care mechanics, props and status UI.
// Every supported footprint is square. A 1×1 face uses a 5×5 logical pixel grid
// (~25 cells total); larger squares increase expressive resolution, not content.

enum HaloPixelPalExpression: String, Codable, CaseIterable, Identifiable {
    case neutral
    case blink
    case happy
    case excited
    case love
    case sleepy
    case annoyed
    case confused
    case worried
    case surprised
    case focused
    case music
    case bored
    case mischievous

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum HaloPixelPalFaceStyle: String, Codable, CaseIterable, Identifiable {
    case minimal = "Minimal"
    case soft = "Soft"
    case robot = "Robot"
    case cat = "Cat"

    var id: String { rawValue }
}

enum HaloPixelPalEyeStyle: String, Codable, CaseIterable, Identifiable {
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
    case white = "White"
    case green = "Retro Green"
    case amber = "Amber"
    case cyan = "Cyan"
    case pink = "Pink"
    case purple = "Purple"
    case red = "Red"
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
    var version = 3

    // Appearance
    var faceStyle: HaloPixelPalFaceStyle = .soft
    var eyeStyle: HaloPixelPalEyeStyle = .classic
    var mouthStyle: HaloPixelPalMouthStyle = .automatic
    var palette: HaloPixelPalPalette = .white
    var customColor = HaloPixelPalRGB(red: 0.42, green: 1.0, blue: 0.62)
    var accentColor = HaloPixelPalRGB(red: 1.0, green: 0.42, blue: 0.72)
    var backgroundStyle: HaloPixelPalBackgroundStyle = .transparent
    var backgroundColor = HaloPixelPalRGB(red: 0.03, green: 0.03, blue: 0.04)
    var faceScale = 0.96
    var glowIntensity = 0.0
    var showCheeks = true

    // Animation
    var automaticBlinking = true
    var animationSpeed = 1.0

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
        case version, faceStyle, eyeStyle, mouthStyle, palette, customColor, accentColor
        case backgroundStyle, backgroundColor, faceScale, glowIntensity, showCheeks
        case automaticBlinking, animationSpeed
        case hoverReaction, tapReaction, doubleTapReaction, longPressReaction
        case contextReactions, chargingReaction, lowBatteryReaction, musicReaction
        case timerReaction, appReaction, idleReaction, nightReaction
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = 3
        faceStyle = try c.decodeIfPresent(HaloPixelPalFaceStyle.self, forKey: .faceStyle) ?? .soft
        eyeStyle = try c.decodeIfPresent(HaloPixelPalEyeStyle.self, forKey: .eyeStyle) ?? .classic
        mouthStyle = try c.decodeIfPresent(HaloPixelPalMouthStyle.self, forKey: .mouthStyle) ?? .automatic
        palette = try c.decodeIfPresent(HaloPixelPalPalette.self, forKey: .palette) ?? .white
        customColor = try c.decodeIfPresent(HaloPixelPalRGB.self, forKey: .customColor) ?? HaloPixelPalRGB(red: 0.42, green: 1.0, blue: 0.62)
        accentColor = try c.decodeIfPresent(HaloPixelPalRGB.self, forKey: .accentColor) ?? HaloPixelPalRGB(red: 1.0, green: 0.42, blue: 0.72)
        backgroundStyle = try c.decodeIfPresent(HaloPixelPalBackgroundStyle.self, forKey: .backgroundStyle) ?? .transparent
        backgroundColor = try c.decodeIfPresent(HaloPixelPalRGB.self, forKey: .backgroundColor) ?? HaloPixelPalRGB(red: 0.03, green: 0.03, blue: 0.04)
        faceScale = try c.decodeIfPresent(Double.self, forKey: .faceScale) ?? 0.96
        glowIntensity = try c.decodeIfPresent(Double.self, forKey: .glowIntensity) ?? 0
        showCheeks = try c.decodeIfPresent(Bool.self, forKey: .showCheeks) ?? true
        automaticBlinking = try c.decodeIfPresent(Bool.self, forKey: .automaticBlinking) ?? true
        animationSpeed = try c.decodeIfPresent(Double.self, forKey: .animationSpeed) ?? 1
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
        value.version = 3
        value.animationSpeed = min(2.0, max(0.35, animationSpeed))
        value.faceScale = min(1.0, max(0.72, faceScale))
        value.glowIntensity = min(1.0, max(0.0, glowIntensity))
        value.customColor = Self.clamped(customColor)
        value.accentColor = Self.clamped(accentColor)
        value.backgroundColor = Self.clamped(backgroundColor)
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
        case .white: return Color(white: 0.97)
        case .green: return Color(red: 0.40, green: 1.0, blue: 0.52)
        case .amber: return Color(red: 1.0, green: 0.67, blue: 0.20)
        case .cyan: return Color(red: 0.28, green: 0.92, blue: 1.0)
        case .pink: return Color(red: 1.0, green: 0.42, blue: 0.72)
        case .purple: return Color(red: 0.69, green: 0.48, blue: 1.0)
        case .red: return Color(red: 1.0, green: 0.32, blue: 0.28)
        case .custom: return customColor.color
        }
    }
}

@MainActor
final class HaloPixelPalStore: ObservableObject {
    static let shared = HaloPixelPalStore()

    @Published var preferences: HaloPixelPalPreferences {
        didSet { persist() }
    }
    @Published private(set) var reaction: HaloPixelPalExpression?
    @Published private(set) var hovering = false

    private let defaults: UserDefaults
    private let preferencesKey = "HaloPixelPal.preferences.v3"
    private let legacyPreferencesKey = "HaloPixelPal.preferences.v2"
    private var clearReactionWork: DispatchWorkItem?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: preferencesKey),
           let decoded = try? JSONDecoder().decode(HaloPixelPalPreferences.self, from: data) {
            preferences = decoded.normalized()
        } else if let legacyData = defaults.data(forKey: legacyPreferencesKey),
                  let decoded = try? JSONDecoder().decode(HaloPixelPalPreferences.self, from: legacyData) {
            preferences = decoded.normalized()
        } else {
            preferences = HaloPixelPalPreferences()
        }
    }

    func update<T>(_ keyPath: WritableKeyPath<HaloPixelPalPreferences, T>, _ value: T) {
        var next = preferences
        next[keyPath: keyPath] = value
        preferences = next.normalized()
    }

    func react(_ expression: HaloPixelPalExpression, seconds: Double = 1.6) {
        clearReactionWork?.cancel()
        reaction = expression
        let work = DispatchWorkItem { [weak self] in self?.reaction = nil }
        clearReactionWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    func setHovering(_ value: Bool) {
        hovering = value
    }

    func tapped() {
        guard preferences.tapReaction else { return }
        let sequence: [HaloPixelPalExpression] = [.happy, .love, .excited, .confused, .mischievous]
        let index = Int(Date().timeIntervalSinceReferenceDate / 1.5) % sequence.count
        react(sequence[index])
    }

    func doubleTapped() {
        guard preferences.doubleTapReaction else { return }
        react(.love, seconds: 2.0)
    }

    func longPressed() {
        guard preferences.longPressReaction else { return }
        react(.sleepy, seconds: 2.2)
    }

    func reset() {
        preferences = HaloPixelPalPreferences()
        reaction = nil
        hovering = false
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(preferences.normalized()) {
            defaults.set(data, forKey: preferencesKey)
        }
    }
}

private struct HaloPixelPalContext {
    let expression: HaloPixelPalExpression

    @MainActor
    static func resolve(
        store: AppStore,
        media: MediaService,
        system: SystemService,
        pal: HaloPixelPalStore,
        date: Date
    ) -> Self {
        if let reaction = pal.reaction { return .init(expression: reaction) }
        let preferences = pal.preferences
        if pal.hovering && preferences.hoverReaction { return .init(expression: .happy) }
        guard preferences.contextReactions else { return .init(expression: .neutral) }

        if preferences.timerReaction && store.finished { return .init(expression: .surprised) }
        if preferences.chargingReaction && system.charging { return .init(expression: .love) }
        if preferences.lowBatteryReaction, let battery = system.battery, battery <= 15 {
            return .init(expression: .worried)
        }
        if preferences.musicReaction && media.isPlaying { return .init(expression: .music) }
        if preferences.timerReaction && (store.deadline != nil || store.pausedSeconds > 0) {
            return .init(expression: .focused)
        }

        if preferences.appReaction {
            let app = NSWorkspace.shared.frontmostApplication
            let bundle = app?.bundleIdentifier?.lowercased() ?? ""
            let appName = app?.localizedName?.lowercased() ?? ""
            if bundle == "com.apple.dt.xcode" || appName == "xcode" {
                return .init(expression: .focused)
            }

            let gameHints = ["steam", "minecraft", "roblox", "retroarch", "whisky", "crossover"]
            if gameHints.contains(where: { bundle.contains($0) || appName.contains($0) }) {
                return .init(expression: .excited)
            }
        }

        if preferences.idleReaction {
            let mouseIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
            let keyboardIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
            if min(mouseIdle, keyboardIdle) > 180 {
                return .init(expression: .bored)
            }
        }

        if preferences.nightReaction {
            let hour = Calendar.autoupdatingCurrent.component(.hour, from: date)
            if hour >= 23 || hour < 6 { return .init(expression: .sleepy) }
        }

        return .init(expression: .neutral)
    }
}

struct HaloPixelPetWidget: View {
    @Environment(\.openNotchGridColumnSpan) private var gridColumnSpan
    @Environment(\.openNotchGridRowSpan) private var gridRowSpan
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.5 : 1.0 / 12.0, paused: false)) { timeline in
            GeometryReader { proxy in
                let columns = min(4, max(1, gridColumnSpan ?? 1))
                let rows = min(4, max(1, gridRowSpan ?? columns))
                let squareSize = min(columns, rows)
                let context = HaloPixelPalContext.resolve(
                    store: store,
                    media: media,
                    system: system,
                    pal: pal,
                    date: timeline.date
                )
                let expression = resolvedExpression(base: context.expression, date: timeline.date)
                let side = max(1, min(proxy.size.width, proxy.size.height))

                HaloPixelPalFace(
                    expression: expression,
                    squareSize: squareSize,
                    preferences: pal.preferences,
                    date: timeline.date,
                    reduceMotion: reduceMotion
                )
                .frame(width: side, height: side)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
        .contentShape(Rectangle())
        .onHover { pal.setHovering($0) }
        .onTapGesture(count: 2) { pal.doubleTapped() }
        .onTapGesture(count: 1) { pal.tapped() }
        .onLongPressGesture(minimumDuration: 0.6) { pal.longPressed() }
        .contextMenu {
            Menu("Expression") {
                ForEach(HaloPixelPalExpression.allCases.filter { $0 != .blink }) { expression in
                    Button(expression.title) { pal.react(expression, seconds: 2) }
                }
            }
            Divider()
            Button("Pixel Pal Settings…") { HaloPixelPalSettingsWindowController.shared.show() }
        }
        .accessibilityLabel("Halo Pixel Pal")
        .help("Click, double-click, hover or long-press the face · right-click for settings")
    }

    private func resolvedExpression(base: HaloPixelPalExpression, date: Date) -> HaloPixelPalExpression {
        guard base == .neutral, pal.preferences.automaticBlinking, !reduceMotion else { return base }
        let speed = max(0.35, pal.preferences.animationSpeed)
        let cycle = date.timeIntervalSinceReferenceDate * speed
        let phase = cycle.truncatingRemainder(dividingBy: 5.4)
        return phase > 5.12 ? .blink : .neutral
    }
}

private struct HaloPixelPalFace: View {
    let expression: HaloPixelPalExpression
    let squareSize: Int
    let preferences: HaloPixelPalPreferences
    let date: Date
    let reduceMotion: Bool

    private var faceColor: Color { preferences.faceColor }
    private var accentColor: Color { preferences.accentColor.color }

    var body: some View {
        ZStack {
            background
            Canvas { context, size in
                drawFace(context: &context, size: size)
            }
            .shadow(color: faceColor.opacity(preferences.glowIntensity * 0.55), radius: 2 + 8 * preferences.glowIntensity)
        }
        .clipped()
    }

    @ViewBuilder
    private var background: some View {
        switch preferences.backgroundStyle {
        case .transparent:
            Color.clear
        case .black:
            Color.black
        case .custom:
            preferences.backgroundColor.color
        case .glow:
            ZStack {
                Color.black.opacity(0.82)
                RadialGradient(
                    colors: [faceColor.opacity(0.18 + 0.30 * preferences.glowIntensity), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 160
                )
            }
        }
    }

    private func drawFace(context: inout GraphicsContext, size: CGSize) {
        let level = min(4, max(1, squareSize))
        let gridByLevel = [5, 7, 9, 11]
        let grid = gridByLevel[level - 1]
        let targetSide = min(size.width, size.height) * preferences.faceScale
        let pixel = max(1, floor(targetSide / CGFloat(grid)))
        let rendered = pixel * CGFloat(grid)
        let origin = CGPoint(
            x: floor((size.width - rendered) / 2),
            y: floor((size.height - rendered) / 2)
        )

        func block(_ x: Int, _ y: Int, _ w: Int = 1, _ h: Int = 1, _ tone: Color? = nil, opacity: Double = 1) {
            guard x >= 0, y >= 0, w > 0, h > 0, x + w <= grid, y + h <= grid else { return }
            let rect = CGRect(
                x: origin.x + CGFloat(x) * pixel,
                y: origin.y + CGFloat(y) * pixel,
                width: CGFloat(w) * pixel,
                height: CGFloat(h) * pixel
            )
            context.fill(Path(rect), with: .color((tone ?? faceColor).opacity(opacity)))
        }

        let center = grid / 2
        let eyeY = max(1, Int(Double(grid) * 0.28))
        let leftEyeX = max(0, Int(Double(grid) * 0.20))
        let rightEyeX = min(grid - 1, Int(Double(grid) * 0.70))
        let mouthY = min(grid - 1, Int(Double(grid) * 0.68))
        let eyeShift = neutralEyeShift(grid: grid)

        func standardEye(_ x: Int, _ y: Int, mirror: Bool = false) {
            let resolvedX = min(grid - 1, max(0, x + eyeShift))
            switch preferences.eyeStyle {
            case .dot:
                block(resolvedX, y)
            case .wide:
                block(max(0, resolvedX - (mirror ? 1 : 0)), y, min(2, grid - max(0, resolvedX - (mirror ? 1 : 0))), 1)
            case .digital:
                block(resolvedX, y)
                if y + 1 < grid { block(resolvedX, y + 1) }
            case .sparkle:
                block(resolvedX, y)
                if level > 1 {
                    if resolvedX > 0 { block(resolvedX - 1, y) }
                    if resolvedX + 1 < grid { block(resolvedX + 1, y) }
                    if y > 0 { block(resolvedX, y - 1) }
                    if y + 1 < grid { block(resolvedX, y + 1) }
                }
            case .classic:
                block(resolvedX, y)
                if level > 1, y + 1 < grid { block(resolvedX, y + 1) }
            }
        }

        func lineEye(_ x: Int, _ y: Int) {
            let width = level == 1 ? 1 : 2
            block(min(grid - width, max(0, x)), y, width, 1)
        }

        func happyEye(_ x: Int, _ y: Int, mirror: Bool) {
            if level == 1 {
                block(x, y)
            } else if mirror {
                block(max(0, x - 1), min(grid - 1, y + 1))
                block(x, y)
            } else {
                block(x, y)
                block(min(grid - 1, x + 1), min(grid - 1, y + 1))
            }
        }

        func heartEye(_ x: Int, _ y: Int) {
            if level == 1 {
                block(x, y, 1, 1, accentColor)
            } else {
                block(x, y, 1, 1, accentColor)
                if x + 1 < grid { block(x + 1, y, 1, 1, accentColor) }
                if y + 1 < grid { block(x, y + 1, min(2, grid - x), 1, accentColor) }
            }
        }

        func drawMouth(_ suggested: HaloPixelPalMouthStyle) {
            let mode = preferences.mouthStyle == .automatic ? suggested : preferences.mouthStyle
            switch mode {
            case .none:
                break
            case .tiny:
                block(center, mouthY)
            case .flat:
                let width = level == 1 ? 1 : min(3, grid)
                block(max(0, center - width / 2), mouthY, width, 1)
            case .smile:
                if level == 1 {
                    block(center, mouthY)
                    if mouthY > 0 { block(max(0, center - 1), mouthY - 1) }
                    if mouthY > 0, center + 1 < grid { block(center + 1, mouthY - 1) }
                } else {
                    block(max(0, center - 2), max(0, mouthY - 1))
                    block(max(0, center - 1), mouthY, min(3, grid - max(0, center - 1)), 1)
                    if center + 2 < grid { block(center + 2, max(0, mouthY - 1)) }
                }
            case .automatic:
                break
            }
        }

        func cheeks() {
            guard preferences.showCheeks, preferences.faceStyle == .soft, level > 1 else { return }
            let y = min(grid - 1, mouthY - 1)
            block(0, y, 1, 1, accentColor, opacity: 0.72)
            block(grid - 1, y, 1, 1, accentColor, opacity: 0.72)
        }

        func styleAccents() {
            switch preferences.faceStyle {
            case .minimal:
                break
            case .soft:
                cheeks()
            case .robot:
                if level > 1 {
                    block(0, center, 1, 1, accentColor, opacity: 0.55)
                    block(grid - 1, center, 1, 1, accentColor, opacity: 0.55)
                }
            case .cat:
                if level > 1 {
                    block(0, 0)
                    block(grid - 1, 0)
                    if level > 2 {
                        block(1, 1, 1, 1, accentColor, opacity: 0.75)
                        block(grid - 2, 1, 1, 1, accentColor, opacity: 0.75)
                    }
                }
            }
        }

        switch expression {
        case .neutral:
            standardEye(leftEyeX, eyeY)
            standardEye(rightEyeX, eyeY, mirror: true)
            drawMouth(.tiny)

        case .blink:
            lineEye(leftEyeX, eyeY)
            lineEye(rightEyeX, eyeY)
            drawMouth(.tiny)

        case .happy:
            happyEye(leftEyeX, eyeY, mirror: false)
            happyEye(rightEyeX, eyeY, mirror: true)
            drawMouth(.smile)

        case .excited:
            standardEye(leftEyeX, eyeY)
            standardEye(rightEyeX, eyeY, mirror: true)
            if preferences.mouthStyle == .none {
                break
            }
            if level == 1 {
                block(center, mouthY, 1, 1, accentColor)
            } else {
                block(max(0, center - 1), mouthY, min(3, grid - max(0, center - 1)), min(2, grid - mouthY), accentColor)
            }

        case .love:
            heartEye(leftEyeX, eyeY)
            heartEye(rightEyeX, eyeY)
            drawMouth(.smile)

        case .sleepy:
            lineEye(leftEyeX, eyeY)
            lineEye(rightEyeX, eyeY)
            drawMouth(.flat)

        case .annoyed:
            lineEye(leftEyeX, eyeY)
            lineEye(rightEyeX, eyeY)
            if level > 1 {
                block(max(0, leftEyeX - 1), max(0, eyeY - 1), min(2, grid - max(0, leftEyeX - 1)), 1)
                block(max(0, rightEyeX), max(0, eyeY - 1), min(2, grid - rightEyeX), 1)
            }
            drawMouth(.flat)

        case .confused:
            standardEye(leftEyeX, eyeY)
            lineEye(rightEyeX, eyeY)
            if level > 1, rightEyeX + 1 < grid, eyeY + 1 < grid { block(rightEyeX + 1, eyeY + 1) }
            drawMouth(.tiny)

        case .worried:
            standardEye(leftEyeX, eyeY)
            standardEye(rightEyeX, eyeY, mirror: true)
            if level > 1 {
                block(max(0, leftEyeX - 1), max(0, eyeY - 1), 1, 1)
                block(min(grid - 1, rightEyeX + 1), max(0, eyeY - 1), 1, 1)
            }
            drawMouth(.flat)

        case .surprised:
            standardEye(leftEyeX, eyeY)
            standardEye(rightEyeX, eyeY, mirror: true)
            if preferences.mouthStyle != .none {
                block(center, mouthY)
                if level > 1, mouthY + 1 < grid { block(center, mouthY + 1) }
            }

        case .focused:
            standardEye(leftEyeX, eyeY)
            standardEye(rightEyeX, eyeY, mirror: true)
            if level > 1 {
                block(max(0, leftEyeX - 1), max(0, eyeY - 1), min(2, grid - max(0, leftEyeX - 1)), 1)
                block(max(0, rightEyeX), max(0, eyeY - 1), min(2, grid - rightEyeX), 1)
            }
            drawMouth(.tiny)

        case .music:
            happyEye(leftEyeX, eyeY, mirror: false)
            happyEye(rightEyeX, eyeY, mirror: true)
            drawMouth(.smile)
            if level > 2 {
                block(grid - 2, 0, 1, 2, accentColor)
                block(grid - 3, 1, 1, 1, accentColor)
            }

        case .bored:
            lineEye(leftEyeX, min(grid - 1, eyeY + 1))
            lineEye(rightEyeX, min(grid - 1, eyeY + 1))
            drawMouth(.flat)

        case .mischievous:
            standardEye(leftEyeX, eyeY)
            lineEye(rightEyeX, eyeY)
            drawMouth(.smile)
        }

        styleAccents()
    }

    private func neutralEyeShift(grid: Int) -> Int {
        guard expression == .neutral, !reduceMotion else { return 0 }
        let cycle = Int(date.timeIntervalSinceReferenceDate * max(0.35, preferences.animationSpeed) / 2.2) % 8
        if cycle == 2 { return -1 }
        if cycle == 5 { return 1 }
        return 0
    }
}

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
            contentRect: CGRect(x: 0, y: 0, width: 560, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Halo · Pixel Pal"
        window.contentViewController = controller
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 520, height: 620)
        window.center()
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct HaloPixelPalSettingsView: View {
    @ObservedObject private var pal = HaloPixelPalStore.shared
    @State private var previewExpression: HaloPixelPalExpression = .happy

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                appearanceSection
                interactionSection
                contextSection
                expressionSection
                footer
            }
            .padding(22)
        }
        .frame(minWidth: 520, minHeight: 620)
    }

    private var header: some View {
        HStack(spacing: 18) {
            HaloPixelPalFace(
                expression: previewExpression,
                squareSize: 1,
                preferences: pal.preferences,
                date: Date(),
                reduceMotion: true
            )
            .frame(width: 112, height: 112)
            .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text("Pixel Pal").font(.title2.weight(.bold))
                Text("A face-only 8-bit expression living in Halo.")
                    .foregroundStyle(.secondary)
                Text("1×1 starts at 5×5 logical pixels · square sizes only.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var appearanceSection: some View {
        GroupBox("Appearance") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Face style", selection: bind(\.faceStyle)) {
                    ForEach(HaloPixelPalFaceStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Eyes", selection: bind(\.eyeStyle)) {
                    ForEach(HaloPixelPalEyeStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Mouth", selection: bind(\.mouthStyle)) {
                    ForEach(HaloPixelPalMouthStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                Toggle("Cheek accents", isOn: bind(\.showCheeks))

                Divider()

                Picker("Pixel color", selection: bind(\.palette)) {
                    ForEach(HaloPixelPalPalette.allCases) { Text($0.rawValue).tag($0) }
                }
                if pal.preferences.palette == .custom {
                    ColorPicker("Custom pixel color", selection: rgbBinding(\.customColor))
                }
                ColorPicker("Accent color", selection: rgbBinding(\.accentColor))

                Picker("Background", selection: bind(\.backgroundStyle)) {
                    ForEach(HaloPixelPalBackgroundStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                if pal.preferences.backgroundStyle == .custom {
                    ColorPicker("Background color", selection: rgbBinding(\.backgroundColor))
                }

                HStack {
                    Text("Face fill")
                    Slider(value: bind(\.faceScale), in: 0.72...1.0)
                    Text("\(Int(pal.preferences.faceScale * 100))%")
                        .font(.caption.monospacedDigit())
                        .frame(width: 38, alignment: .trailing)
                }
                HStack {
                    Text("Glow")
                    Slider(value: bind(\.glowIntensity), in: 0...1)
                }
                HStack {
                    Text("Animation speed")
                    Slider(value: bind(\.animationSpeed), in: 0.35...2.0)
                }
                Toggle("Automatic blinking", isOn: bind(\.automaticBlinking))
            }
            .padding(.top, 4)
        }
    }

    private var interactionSection: some View {
        GroupBox("Interactions") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("React on hover", isOn: bind(\.hoverReaction))
                Toggle("React on click", isOn: bind(\.tapReaction))
                Toggle("React on double-click", isOn: bind(\.doubleTapReaction))
                Toggle("React on long press", isOn: bind(\.longPressReaction))
                Text("Click reactions rotate through cute expressions. Double-click gives a love reaction; long press makes the face sleepy.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    Toggle("Night / sleep", isOn: bind(\.nightReaction))
                }
            }
            .padding(.top, 4)
        }
    }

    private var expressionSection: some View {
        GroupBox("Expression preview") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Expression", selection: $previewExpression) {
                    ForEach(HaloPixelPalExpression.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)

                HStack {
                    Button("Happy") { previewExpression = .happy; pal.react(.happy, seconds: 2) }
                    Button("Love") { previewExpression = .love; pal.react(.love, seconds: 2) }
                    Button("Excited") { previewExpression = .excited; pal.react(.excited, seconds: 2) }
                    Button("Sleepy") { previewExpression = .sleepy; pal.react(.sleepy, seconds: 2) }
                    Button("Mischievous") { previewExpression = .mischievous; pal.react(.mischievous, seconds: 2) }
                }
            }
            .padding(.top, 4)
        }
    }

    private var footer: some View {
        HStack(alignment: .bottom) {
            Text("Pixel Pal always maximizes its square canvas. 1×1 uses a 5×5 logical grid; 2×2, 3×3 and 4×4 increase resolution while remaining face-only.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Reset") { pal.reset() }
        }
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
