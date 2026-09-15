import SwiftUI
import AppKit
import CoreGraphics

// MARK: - Pixel Pal
// Pixel Pal is intentionally tiny in concept: a face, expressions, and nothing else.
// No body, habitat, care loop, props, stats, room, furniture, status card, or decorative UI.
// The face is rendered from hard-edged logical pixels. A 1×1 tile targets roughly
// two dozen illuminated pixel blocks; larger square tiles preserve the same retro
// language while giving the face more resolution.

enum HaloPixelPalExpression: String, Codable, CaseIterable {
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
}

enum HaloPixelPalPalette: String, Codable, CaseIterable, Identifiable {
    case white = "White"
    case green = "Retro Green"
    case amber = "Amber"
    case cyan = "Cyan"
    case pink = "Pink"
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
    var version = 2
    var palette: HaloPixelPalPalette = .white
    var customColor = HaloPixelPalRGB(red: 0.42, green: 1.0, blue: 0.62)
    var contextReactions = true
    var automaticBlinking = true
    var animationSpeed = 1.0

    func normalized() -> Self {
        var value = self
        value.version = 2
        value.animationSpeed = min(2.0, max(0.35, animationSpeed))
        value.customColor.red = min(1, max(0, customColor.red))
        value.customColor.green = min(1, max(0, customColor.green))
        value.customColor.blue = min(1, max(0, customColor.blue))
        return value
    }

    var faceColor: Color {
        switch palette {
        case .white: return Color(white: 0.96)
        case .green: return Color(red: 0.40, green: 1.0, blue: 0.52)
        case .amber: return Color(red: 1.0, green: 0.67, blue: 0.20)
        case .cyan: return Color(red: 0.28, green: 0.92, blue: 1.0)
        case .pink: return Color(red: 1.0, green: 0.42, blue: 0.72)
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

    private let defaults: UserDefaults
    private let preferencesKey = "HaloPixelPal.preferences.v2"
    private var clearReactionWork: DispatchWorkItem?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: preferencesKey),
           let decoded = try? JSONDecoder().decode(HaloPixelPalPreferences.self, from: data),
           decoded.version == 2 {
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

    func tapped() {
        let sequence: [HaloPixelPalExpression] = [.happy, .love, .excited, .confused]
        let index = Int(Date().timeIntervalSinceReferenceDate / 1.5) % sequence.count
        react(sequence[index])
    }

    func reset() {
        preferences = HaloPixelPalPreferences()
        reaction = nil
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
        guard pal.preferences.contextReactions else { return .init(expression: .neutral) }

        if store.finished { return .init(expression: .surprised) }
        if system.charging { return .init(expression: .love) }
        if let battery = system.battery, battery <= 15 { return .init(expression: .worried) }
        if media.isPlaying { return .init(expression: .music) }
        if store.deadline != nil || store.pausedSeconds > 0 { return .init(expression: .focused) }

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

        let mouseIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let keyboardIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        if min(mouseIdle, keyboardIdle) > 180 {
            return .init(expression: .bored)
        }

        let hour = Calendar.autoupdatingCurrent.component(.hour, from: date)
        if hour >= 23 || hour < 6 { return .init(expression: .sleepy) }
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

                HaloPixelPalFace(
                    expression: expression,
                    squareSize: squareSize,
                    color: pal.preferences.faceColor,
                    date: timeline.date,
                    animationSpeed: pal.preferences.animationSpeed,
                    reduceMotion: reduceMotion
                )
                .frame(width: min(proxy.size.width, proxy.size.height),
                       height: min(proxy.size.width, proxy.size.height))
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { pal.tapped() }
        .contextMenu {
            Button("Happy") { pal.react(.happy) }
            Button("Love") { pal.react(.love) }
            Button("Surprised") { pal.react(.surprised) }
            Divider()
            Button("Pixel Pal Settings…") { HaloPixelPalSettingsWindowController.shared.show() }
        }
        .accessibilityLabel("Halo Pixel Pal")
        .help("Click the face for a reaction · right-click for settings")
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
    let color: Color
    let date: Date
    let animationSpeed: Double
    let reduceMotion: Bool

    var body: some View {
        Canvas { context, size in
            let level = min(4, max(1, squareSize))
            // 1×1 uses a 9×9 logical face. Only roughly two dozen blocks are lit,
            // keeping the result extremely chunky and readable at notch scale.
            let grid = 9 * level
            let pixel = max(1, floor(min(size.width, size.height) / CGFloat(grid)))
            let rendered = pixel * CGFloat(grid)
            let origin = CGPoint(
                x: floor((size.width - rendered) / 2),
                y: floor((size.height - rendered) / 2)
            )
            let scale = level
            let eyeShift = neutralEyeShift(level: level)

            func block(_ x: Int, _ y: Int, _ w: Int = 1, _ h: Int = 1, _ tone: Color? = nil) {
                let rect = CGRect(
                    x: origin.x + CGFloat(x * scale) * pixel,
                    y: origin.y + CGFloat(y * scale) * pixel,
                    width: CGFloat(w * scale) * pixel,
                    height: CGFloat(h * scale) * pixel
                )
                let resolved = tone ?? color
                context.fill(Path(rect), with: .color(resolved))
            }

            func eye(_ x: Int, _ y: Int, width: Int = 2, height: Int = 3) {
                block(x + eyeShift, y, width, height)
            }

            func horizontalEye(_ x: Int, _ y: Int, width: Int = 3) {
                block(x, y, width, 1)
            }

            func happyEye(_ x: Int, _ y: Int) {
                block(x, y + 1)
                block(x + 1, y)
                block(x + 2, y + 1)
            }

            func heartEye(_ x: Int, _ y: Int) {
                block(x, y)
                block(x + 2, y)
                block(x, y + 1, 3, 1)
                block(x + 1, y + 2)
            }

            func worriedEye(_ x: Int, _ y: Int, mirror: Bool) {
                if mirror {
                    block(x, y)
                    block(x + 1, y + 1)
                    block(x + 1, y + 2)
                } else {
                    block(x + 1, y)
                    block(x, y + 1)
                    block(x, y + 2)
                }
            }

            func mouthSmile() {
                block(2, 6)
                block(3, 7, 3, 1)
                block(6, 6)
            }

            func mouthTiny() { block(4, 6) }
            func mouthFlat() { block(3, 6, 3, 1) }
            func mouthOpen() {
                block(3, 6, 3, 1)
                block(3, 7)
                block(5, 7)
                block(3, 8, 3, 1)
            }

            switch expression {
            case .neutral:
                eye(1, 2)
                eye(6, 2)
                mouthTiny()

            case .blink:
                horizontalEye(1, 3, width: 2)
                horizontalEye(6, 3, width: 2)
                mouthTiny()

            case .happy:
                happyEye(0, 3)
                happyEye(6, 3)
                mouthSmile()

            case .excited:
                happyEye(0, 2)
                happyEye(6, 2)
                mouthOpen()

            case .love:
                heartEye(0, 2)
                heartEye(6, 2)
                mouthSmile()

            case .sleepy:
                horizontalEye(1, 3, width: 2)
                horizontalEye(6, 3, width: 2)
                block(4, 6, 2, 1)

            case .annoyed:
                block(0, 2, 3, 1)
                block(6, 2, 3, 1)
                eye(1, 3, width: 2, height: 2)
                eye(6, 3, width: 2, height: 2)
                mouthFlat()

            case .confused:
                eye(1, 2, width: 2, height: 2)
                block(6, 2, 2, 1)
                block(7, 3)
                block(6, 4)
                block(7, 5)
                block(4, 7)

            case .worried:
                worriedEye(1, 2, mirror: false)
                worriedEye(6, 2, mirror: true)
                block(2, 6)
                block(3, 5, 3, 1)
                block(6, 6)

            case .surprised:
                eye(1, 2, width: 2, height: 3)
                eye(6, 2, width: 2, height: 3)
                block(4, 6, 2, 2)

            case .focused:
                block(0, 2, 3, 1)
                block(6, 2, 3, 1)
                eye(1, 3, width: 2, height: 2)
                eye(6, 3, width: 2, height: 2)
                mouthTiny()

            case .music:
                happyEye(0, 3)
                happyEye(6, 3)
                mouthSmile()

            case .bored:
                horizontalEye(1, 4, width: 2)
                horizontalEye(6, 4, width: 2)
                mouthFlat()
            }
        }
        .drawingGroup(opaque: false, colorMode: .nonLinear)
    }

    private func neutralEyeShift(level: Int) -> Int {
        guard expression == .neutral, !reduceMotion else { return 0 }
        let cycle = Int(date.timeIntervalSinceReferenceDate * max(0.35, animationSpeed) / 2.2) % 8
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
            contentRect: CGRect(x: 0, y: 0, width: 470, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Halo · Pixel Pal"
        window.contentViewController = controller
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct HaloPixelPalSettingsView: View {
    @ObservedObject private var pal = HaloPixelPalStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 18) {
                HaloPixelPalFace(
                    expression: .happy,
                    squareSize: 1,
                    color: pal.preferences.faceColor,
                    date: Date(),
                    animationSpeed: pal.preferences.animationSpeed,
                    reduceMotion: true
                )
                .frame(width: 92, height: 92)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text("Pixel Pal").font(.title2.weight(.bold))
                    Text("A retro face that turns Mac state into expressions.")
                        .foregroundStyle(.secondary)
                    Text("Square sizes only · face only · no care mechanics.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            GroupBox("Face") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Pixel color", selection: bind(\.palette)) {
                        ForEach(HaloPixelPalPalette.allCases) { palette in
                            Text(palette.rawValue).tag(palette)
                        }
                    }
                    if pal.preferences.palette == .custom {
                        ColorPicker("Custom color", selection: customColor)
                    }
                    Toggle("React to Mac context", isOn: bind(\.contextReactions))
                    Toggle("Automatic blinking", isOn: bind(\.automaticBlinking))
                    HStack {
                        Text("Animation speed")
                        Slider(value: bind(\.animationSpeed), in: 0.35...2.0)
                    }
                }
                .padding(.top, 4)
            }

            GroupBox("Test expressions") {
                HStack {
                    Button("Happy") { pal.react(.happy, seconds: 2) }
                    Button("Love") { pal.react(.love, seconds: 2) }
                    Button("Excited") { pal.react(.excited, seconds: 2) }
                    Button("Sleepy") { pal.react(.sleepy, seconds: 2) }
                    Button("Confused") { pal.react(.confused, seconds: 2) }
                }
                .padding(.top, 4)
            }

            HStack {
                Text("1×1 uses roughly two dozen illuminated pixel blocks. 2×2, 3×3 and 4×4 keep the same face-only language at progressively higher resolution.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Reset") { pal.reset() }
            }
        }
        .padding(22)
        .frame(width: 470, height: 520)
    }

    private func bind<T>(_ path: WritableKeyPath<HaloPixelPalPreferences, T>) -> Binding<T> {
        Binding(
            get: { pal.preferences[keyPath: path] },
            set: { pal.update(path, $0) }
        )
    }

    private var customColor: Binding<Color> {
        Binding(
            get: { pal.preferences.customColor.color },
            set: { color in
                guard let ns = NSColor(color).usingColorSpace(.deviceRGB) else { return }
                pal.update(\.customColor, HaloPixelPalRGB(red: ns.redComponent, green: ns.greenComponent, blue: ns.blueComponent))
            }
        )
    }
}
