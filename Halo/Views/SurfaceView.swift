import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum VinylStylePreset: String, Codable, CaseIterable, Identifiable {
    case classic = "Classic"
    case studio = "Studio Gloss"
    case minimal = "Minimal"
    case retro = "Retro"
    case neon = "Neon"
    case smoked = "Smoked"
    case custom = "Custom"
    var id: String { rawValue }
}

enum VinylColorSource: String, Codable, CaseIterable, Identifiable {
    case classic = "Classic black"
    case album = "Album color"
    case custom = "Custom"
    var id: String { rawValue }
}

enum VinylAccentSource: String, Codable, CaseIterable, Identifiable {
    case white = "Neutral"
    case album = "Album color"
    case custom = "Custom"
    var id: String { rawValue }
}

enum VinylLabelStyle: String, Codable, CaseIterable, Identifiable {
    case artwork = "Album artwork"
    case albumColor = "Album color"
    case custom = "Custom color"
    case dark = "Dark label"
    case none = "No label"
    var id: String { rawValue }
}

struct VinylStyleOptions: Codable, Equatable {
    var preset: VinylStylePreset = .classic
    var discColorSource: VinylColorSource = .classic
    var accentSource: VinylAccentSource = .white
    var labelStyle: VinylLabelStyle = .artwork
    var customDiscColor = WidgetColor(red: 0.025, green: 0.025, blue: 0.03)
    var customAccentColor = WidgetColor.white
    var customLabelColor = WidgetColor(red: 0.78, green: 0.16, blue: 0.12)
    var discOpacity = 0.98
    var depth = 0.72
    var grooveCount = 8
    var grooveOpacity = 0.11
    var grooveWidth = 0.006
    var grooveStart = 0.055
    var grooveEnd = 0.34
    var edgeRingOpacity = 0.16
    var edgeRingWidth = 0.008
    var labelScale = 0.46
    var labelOpacity = 1.0
    var labelSaturation = 1.0
    var labelBrightness = 0.0
    var labelBorderOpacity = 0.32
    var labelBorderWidth = 0.007
    var centerCapScale = 0.105
    var centerHoleScale = 0.024
    var highlightIntensity = 0.16
    var highlightArc = 0.23
    var highlightAngle = -28.0
    var highlightWidth = 0.009
    var gloss = 0.14
    var shadowOpacity = 0.36
    var shadowRadius = 0.06
    var shadowYOffset = 0.025
    var glowOpacity = 0.0
    var glowRadius = 0.10
    var rpm = 8.0
    var reverse = false

    static func made(_ preset: VinylStylePreset) -> VinylStyleOptions {
        var value = VinylStyleOptions()
        value.preset = preset
        switch preset {
        case .classic:
            break
        case .studio:
            value.grooveCount = 12
            value.grooveOpacity = 0.13
            value.grooveWidth = 0.0045
            value.edgeRingOpacity = 0.24
            value.highlightIntensity = 0.30
            value.highlightArc = 0.30
            value.gloss = 0.30
            value.shadowOpacity = 0.48
            value.shadowRadius = 0.075
            value.labelBorderOpacity = 0.42
            value.depth = 0.82
        case .minimal:
            value.grooveCount = 3
            value.grooveOpacity = 0.045
            value.edgeRingOpacity = 0.06
            value.highlightIntensity = 0.06
            value.gloss = 0.04
            value.shadowOpacity = 0.20
            value.labelBorderOpacity = 0.12
            value.labelScale = 0.42
            value.centerCapScale = 0.085
        case .retro:
            value.discColorSource = .custom
            value.accentSource = .custom
            value.customDiscColor = WidgetColor(red: 0.075, green: 0.047, blue: 0.035)
            value.customAccentColor = WidgetColor(red: 0.92, green: 0.77, blue: 0.48)
            value.grooveCount = 7
            value.grooveOpacity = 0.16
            value.grooveWidth = 0.0065
            value.labelScale = 0.52
            value.labelSaturation = 0.82
            value.labelBrightness = -0.035
            value.highlightIntensity = 0.11
            value.gloss = 0.08
            value.rpm = 6
        case .neon:
            value.discColorSource = .album
            value.accentSource = .album
            value.grooveCount = 10
            value.grooveOpacity = 0.23
            value.grooveWidth = 0.0065
            value.edgeRingOpacity = 0.34
            value.highlightIntensity = 0.35
            value.gloss = 0.24
            value.glowOpacity = 0.55
            value.glowRadius = 0.16
            value.depth = 0.55
            value.rpm = 10
        case .smoked:
            value.discColorSource = .custom
            value.customDiscColor = WidgetColor(red: 0.075, green: 0.09, blue: 0.11)
            value.discOpacity = 0.90
            value.grooveCount = 14
            value.grooveOpacity = 0.08
            value.grooveWidth = 0.004
            value.highlightIntensity = 0.20
            value.highlightArc = 0.38
            value.gloss = 0.22
            value.depth = 0.42
            value.labelScale = 0.43
        case .custom:
            break
        }
        return value
    }

    func normalized() -> VinylStyleOptions {
        var value = self
        value.discOpacity = min(1, max(0.3, discOpacity))
        value.depth = min(1, max(0, depth))
        value.grooveCount = min(24, max(0, grooveCount))
        value.grooveOpacity = min(0.8, max(0, grooveOpacity))
        value.grooveWidth = min(0.03, max(0.001, grooveWidth))
        value.grooveStart = min(0.32, max(0.01, grooveStart))
        value.grooveEnd = min(0.46, max(value.grooveStart + 0.02, grooveEnd))
        value.edgeRingOpacity = min(1, max(0, edgeRingOpacity))
        value.edgeRingWidth = min(0.04, max(0.001, edgeRingWidth))
        value.labelScale = min(0.72, max(0.18, labelScale))
        value.labelOpacity = min(1, max(0, labelOpacity))
        value.labelSaturation = min(2, max(0, labelSaturation))
        value.labelBrightness = min(0.5, max(-0.5, labelBrightness))
        value.labelBorderOpacity = min(1, max(0, labelBorderOpacity))
        value.labelBorderWidth = min(0.04, max(0.001, labelBorderWidth))
        value.centerCapScale = min(0.32, max(0.03, centerCapScale))
        value.centerHoleScale = min(0.12, max(0.006, centerHoleScale))
        value.highlightIntensity = min(1, max(0, highlightIntensity))
        value.highlightArc = min(0.80, max(0.03, highlightArc))
        value.highlightAngle = min(180, max(-180, highlightAngle))
        value.highlightWidth = min(0.05, max(0.002, highlightWidth))
        value.gloss = min(0.8, max(0, gloss))
        value.shadowOpacity = min(0.9, max(0, shadowOpacity))
        value.shadowRadius = min(0.20, max(0, shadowRadius))
        value.shadowYOffset = min(0.15, max(-0.10, shadowYOffset))
        value.glowOpacity = min(1, max(0, glowOpacity))
        value.glowRadius = min(0.30, max(0, glowRadius))
        value.rpm = min(60, max(0.5, rpm))
        value.customDiscColor = (try? customDiscColor.validated()) ?? VinylStyleOptions().customDiscColor
        value.customAccentColor = (try? customAccentColor.validated()) ?? .white
        value.customLabelColor = (try? customLabelColor.validated()) ?? VinylStyleOptions().customLabelColor
        return value
    }
}

final class VinylStyleStore: ObservableObject {
    static let shared = VinylStyleStore()
    private let defaults: UserDefaults
    private let key = "HaloVinylStyle.v1"
    @Published var options: VinylStyleOptions {
        didSet { persist() }
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(VinylStyleOptions.self, from: data) {
            options = decoded.normalized()
        } else {
            options = .made(.classic)
        }
    }

    func applyPreset(_ preset: VinylStylePreset) {
        guard preset != .custom else {
            var next = options
            next.preset = .custom
            options = next
            return
        }
        options = .made(preset)
    }

    func update<T>(_ keyPath: WritableKeyPath<VinylStyleOptions, T>, _ newValue: T) {
        var next = options
        next[keyPath: keyPath] = newValue
        next.preset = .custom
        options = next.normalized()
    }

    func reset() { options = .made(.classic) }

    private func persist() {
        guard let data = try? JSONEncoder().encode(options.normalized()) else { return }
        defaults.set(data, forKey: key)
    }
}

@MainActor
final class VinylStyleWindowController {
    static let shared = VinylStyleWindowController()
    private var window: NSWindow?

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let controller = NSHostingController(rootView: VinylStyleSettingsView())
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 570, height: 760),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Halo · Vinyl Studio"
        window.contentViewController = controller
        window.isReleasedWhenClosed = false
        window.minSize = CGSize(width: 520, height: 620)
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

struct VinylRecordView: View {
    let artwork: NSImage?
    let size: Double
    let palette: [WidgetColor]
    let playing: Bool
    let lowPower: Bool
    var interactive = true
    @ObservedObject private var styleStore = VinylStyleStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    private var style: VinylStyleOptions { styleStore.options.normalized() }
    private var albumColor: Color { palette.first?.color ?? Color(hue: 0.58, saturation: 0.72, brightness: 0.95) }
    private var secondaryAlbumColor: Color { palette.dropFirst().first?.color ?? albumColor.opacity(0.72) }
    private var discColor: Color {
        switch style.discColorSource {
        case .classic: return Color(red: 0.018, green: 0.019, blue: 0.024)
        case .album: return albumColor
        case .custom: return style.customDiscColor.color
        }
    }
    private var accentColor: Color {
        switch style.accentSource {
        case .white: return .white
        case .album: return secondaryAlbumColor
        case .custom: return style.customAccentColor.color
        }
    }
    private var shouldAnimate: Bool { playing && !reduceMotion && !lowPower }

    var body: some View {
        Group {
            if shouldAnimate {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !playing)) { context in
                    record
                        .rotationEffect(.degrees(rotationAngle(at: context.date)))
                }
            } else {
                record
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .contextMenu {
            if interactive {
                Button("Open Vinyl Studio…") { VinylStyleWindowController.shared.show() }
                Menu("Preset") {
                    ForEach(VinylStylePreset.allCases.filter { $0 != .custom }) { preset in
                        Button(preset.rawValue) { styleStore.applyPreset(preset) }
                    }
                }
                Divider()
                Button("Reset to Classic") { styleStore.reset() }
            }
        }
        .overlay(alignment: .topTrailing) {
            if interactive && hovering && size >= 26 {
                Button { VinylStyleWindowController.shared.show() } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: min(11, max(7, size * 0.13)), weight: .semibold))
                        .frame(width: min(22, max(12, size * 0.24)), height: min(22, max(12, size * 0.24)))
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .help("Customize vinyl")
                .offset(x: size * 0.02, y: -size * 0.02)
            }
        }
        .onHover { if interactive { hovering = $0 } }
        .help(interactive ? "Right-click to customize the shared vinyl style" : "Vinyl preview")
        .accessibilityLabel("Customizable vinyl record")
    }

    private func rotationAngle(at date: Date) -> Double {
        let direction = style.reverse ? -1.0 : 1.0
        return date.timeIntervalSinceReferenceDate * style.rpm / 60.0 * 360.0 * direction
    }

    private var record: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [
                    discColor.opacity(style.discOpacity),
                    discColor.opacity(max(0.35, style.discOpacity * 0.94)),
                    Color.black.opacity(0.30 + style.depth * 0.62)
                ], center: .center, startRadius: size * 0.04, endRadius: size * 0.52))

            if style.grooveCount > 0 {
                ForEach(0..<style.grooveCount, id: \.self) { index in
                    let denominator = Double(max(1, style.grooveCount - 1))
                    let t = Double(index) / denominator
                    let inset = style.grooveStart + (style.grooveEnd - style.grooveStart) * t
                    Circle()
                        .stroke(accentColor.opacity(style.grooveOpacity * (index.isMultiple(of: 2) ? 1 : 0.62)),
                                lineWidth: max(0.35, size * style.grooveWidth))
                        .padding(size * inset)
                }
            }

            if style.edgeRingOpacity > 0 {
                Circle()
                    .stroke(accentColor.opacity(style.edgeRingOpacity), lineWidth: max(0.45, size * style.edgeRingWidth))
                    .padding(size * 0.018)
            }

            if style.highlightIntensity > 0 {
                Circle()
                    .trim(from: 0.06, to: min(0.94, 0.06 + style.highlightArc))
                    .stroke(accentColor.opacity(style.highlightIntensity),
                            style: StrokeStyle(lineWidth: max(0.5, size * style.highlightWidth), lineCap: .round))
                    .padding(size * 0.052)
                    .rotationEffect(.degrees(style.highlightAngle))
            }

            if style.gloss > 0 {
                Circle()
                    .fill(LinearGradient(colors: [
                        Color.white.opacity(style.gloss),
                        Color.white.opacity(style.gloss * 0.12),
                        Color.clear,
                        Color.black.opacity(style.gloss * 0.18)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .blendMode(.screen)
                    .padding(size * 0.012)
            }

            label

            Circle()
                .stroke(accentColor.opacity(style.labelBorderOpacity), lineWidth: max(0.45, size * style.labelBorderWidth))
                .frame(width: size * min(0.78, style.labelScale + 0.03), height: size * min(0.78, style.labelScale + 0.03))

            Circle()
                .fill(Color.black.opacity(0.92))
                .frame(width: max(3, size * style.centerCapScale), height: max(3, size * style.centerCapScale))

            Circle()
                .fill(accentColor.opacity(0.78))
                .frame(width: max(1, size * style.centerHoleScale), height: max(1, size * style.centerHoleScale))
        }
        .frame(width: size, height: size)
        .shadow(color: accentColor.opacity(style.glowOpacity), radius: size * style.glowRadius)
        .shadow(color: .black.opacity(style.shadowOpacity), radius: size * style.shadowRadius, y: size * style.shadowYOffset)
    }

    @ViewBuilder private var label: some View {
        Group {
            switch style.labelStyle {
            case .artwork:
                if let artwork {
                    Image(nsImage: artwork).resizable().scaledToFill()
                } else {
                    albumColor.overlay(Image(systemName: "music.note").foregroundStyle(Color.black.opacity(0.66)))
                }
            case .albumColor:
                albumColor.overlay(Image(systemName: "music.note").foregroundStyle(Color.black.opacity(0.55)))
            case .custom:
                style.customLabelColor.color
            case .dark:
                Color.black.opacity(0.88)
            case .none:
                Color.clear
            }
        }
        .frame(width: size * style.labelScale, height: size * style.labelScale)
        .clipShape(Circle())
        .opacity(style.labelOpacity)
        .saturation(style.labelSaturation)
        .brightness(style.labelBrightness)
    }
}

struct VinylStyleSettingsView: View {
    @ObservedObject private var store = VinylStyleStore.shared
    private var options: VinylStyleOptions { store.options.normalized() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 24) {
                    VinylRecordView(artwork: NSApp.applicationIconImage,
                                    size: 154,
                                    palette: [WidgetColor(red: 0.42, green: 0.68, blue: 1.0), WidgetColor(red: 0.82, green: 0.28, blue: 0.72)],
                                    playing: true, lowPower: false, interactive: false)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Vinyl Studio").font(.title.bold())
                        Text("One vinyl design, shared everywhere Halo shows a record — Closed Notch and Music CI update together.")
                            .font(.callout).foregroundStyle(.secondary)
                        Picker("Preset", selection: Binding(get: { options.preset }, set: { store.applyPreset($0) })) {
                            ForEach(VinylStylePreset.allCases) { Text($0.rawValue).tag($0) }
                        }
                        HStack {
                            Button("Classic") { store.applyPreset(.classic) }
                            Button("Reset") { store.reset() }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Disc & palette") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Disc color", selection: binding(\.discColorSource)) {
                            ForEach(VinylColorSource.allCases) { Text($0.rawValue).tag($0) }
                        }
                        if options.discColorSource == .custom { colorPicker("Custom disc color", \.customDiscColor) }
                        Picker("Detail color", selection: binding(\.accentSource)) {
                            ForEach(VinylAccentSource.allCases) { Text($0.rawValue).tag($0) }
                        }
                        if options.accentSource == .custom { colorPicker("Custom detail color", \.customAccentColor) }
                        slider("Disc opacity", \.discOpacity, 0.3...1, value: { String(format: "%.2f", $0) })
                        slider("Radial depth", \.depth, 0...1, value: { String(format: "%.2f", $0) })
                    }.padding(.vertical, 4)
                }

                GroupBox("Center label") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Label", selection: binding(\.labelStyle)) {
                            ForEach(VinylLabelStyle.allCases) { Text($0.rawValue).tag($0) }
                        }
                        if options.labelStyle == .custom { colorPicker("Label color", \.customLabelColor) }
                        slider("Label size", \.labelScale, 0.18...0.72, value: percent)
                        slider("Label opacity", \.labelOpacity, 0...1, value: percent)
                        slider("Artwork saturation", \.labelSaturation, 0...2, value: { String(format: "%.2fx", $0) })
                        slider("Artwork brightness", \.labelBrightness, -0.5...0.5, value: { String(format: "%+.2f", $0) })
                        slider("Label ring opacity", \.labelBorderOpacity, 0...1, value: percent)
                        slider("Label ring width", \.labelBorderWidth, 0.001...0.04, value: { String(format: "%.3f", $0) })
                        slider("Center cap size", \.centerCapScale, 0.03...0.32, value: percent)
                        slider("Center hole size", \.centerHoleScale, 0.006...0.12, value: percent)
                    }.padding(.vertical, 4)
                }

                GroupBox("Grooves & edge") {
                    VStack(alignment: .leading, spacing: 12) {
                        Stepper("Grooves: \(options.grooveCount)", value: binding(\.grooveCount), in: 0...24)
                        slider("Groove opacity", \.grooveOpacity, 0...0.8, value: percent)
                        slider("Groove width", \.grooveWidth, 0.001...0.03, value: { String(format: "%.3f", $0) })
                        slider("Outer groove inset", \.grooveStart, 0.01...0.32, value: percent)
                        slider("Inner groove inset", \.grooveEnd, max(0.03, options.grooveStart + 0.02)...0.46, value: percent)
                        slider("Edge ring opacity", \.edgeRingOpacity, 0...1, value: percent)
                        slider("Edge ring width", \.edgeRingWidth, 0.001...0.04, value: { String(format: "%.3f", $0) })
                    }.padding(.vertical, 4)
                }

                GroupBox("Light, gloss & depth") {
                    VStack(alignment: .leading, spacing: 12) {
                        slider("Specular highlight", \.highlightIntensity, 0...1, value: percent)
                        slider("Highlight arc", \.highlightArc, 0.03...0.80, value: percent)
                        slider("Highlight angle", \.highlightAngle, -180...180, value: { "\(Int($0))°" })
                        slider("Highlight width", \.highlightWidth, 0.002...0.05, value: { String(format: "%.3f", $0) })
                        slider("Surface gloss", \.gloss, 0...0.8, value: percent)
                        slider("Shadow opacity", \.shadowOpacity, 0...0.9, value: percent)
                        slider("Shadow radius", \.shadowRadius, 0...0.20, value: percent)
                        slider("Shadow Y offset", \.shadowYOffset, -0.10...0.15, value: percent)
                        slider("Accent glow", \.glowOpacity, 0...1, value: percent)
                        slider("Glow radius", \.glowRadius, 0...0.30, value: percent)
                    }.padding(.vertical, 4)
                }

                GroupBox("Motion") {
                    VStack(alignment: .leading, spacing: 12) {
                        slider("Rotation speed", \.rpm, 0.5...60, value: { String(format: "%.1f rpm", $0) })
                        Toggle("Reverse rotation", isOn: binding(\.reverse))
                        Text("Reduce Motion and Low Power Mode still stop continuous rotation where Halo already respects those system preferences.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                }

                Text("Vinyl Studio is global by design: changing the record here immediately updates every vinyl instance in Halo, including the closed notch and Music CI.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .frame(minWidth: 500, minHeight: 600)
    }

    private func binding<T>(_ keyPath: WritableKeyPath<VinylStyleOptions, T>) -> Binding<T> {
        Binding(get: { store.options[keyPath: keyPath] }, set: { store.update(keyPath, $0) })
    }

    private func colorPicker(_ title: String, _ keyPath: WritableKeyPath<VinylStyleOptions, WidgetColor>) -> some View {
        ColorPicker(title, selection: Binding(get: { store.options[keyPath: keyPath].color }, set: { store.update(keyPath, WidgetColor($0)) }), supportsOpacity: false)
    }

    private func slider(_ title: String, _ keyPath: WritableKeyPath<VinylStyleOptions, Double>, _ range: ClosedRange<Double>, value formatter: @escaping (Double) -> String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text(title); Spacer(); Text(formatter(store.options[keyPath: keyPath])).font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
            SwiftUI.Slider(value: binding(keyPath), in: range)
        }
    }

    private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
}

struct SurfaceViewportView: View {
    @ObservedObject var viewport: SurfaceViewport
    let content: SurfaceView
    var body: some View {
        content.frame(width: viewport.size.width, height: viewport.size.height, alignment: .top).clipped()
    }
}

struct SurfaceView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var state: SurfaceState
    @ObservedObject var workspace: WorkspaceStore
    private var theme: Theme { state.theme }
    private var layout: WorkspaceLayout { state.layoutOverride ?? workspace.effectiveLayout }
    private var contextOptions: ContextMusicOptions { layout.contextMusic ?? ContextMusicOptions() }
    private var contextMusicActive: Bool { contextOptions.enabled && workspace.media.isPlaying }
    private var closedBackgroundOptions: ClosedNotchOptions {
        var value = layout.closedNotch ?? ClosedNotchOptions()
        if var artwork = value.artworkOptions, artwork.usesBackgroundArtwork, artwork.mode != .background {
            artwork.mode = .background
            value.artworkOptions = artwork
        }
        return value
    }
    private var contour: HaloContour {
        HaloContour(kind: effectiveShape, radius: (layout.appearance.surface.useStyleContour ?? true) ? (theme.style == .menuBar ? 4 : theme.style == .pill ? 40 : theme.cornerRadius) : theme.cornerRadius,
                    topRadius: layout.appearance.surface.topRadius, bottomRadius: layout.appearance.surface.bottomRadius,
                    shoulder: layout.appearance.surface.shoulder)
    }
    private var effectiveShape: SurfaceShapeKind {
        guard layout.appearance.surface.useStyleContour ?? true else { return layout.appearance.surface.shape }
        switch theme.style {
        case .pill: return state.expanded ? .rounded : .capsule
        case .island: return state.expanded ? .rounded : .capsule
        case .simulated, .notch: return .scoop
        case .shelf: return .chamfer
        case .detached: return .rounded
        case .menuBar: return .rounded
        default: return layout.appearance.surface.shape
        }
    }
    @State private var page = 0
    private var modules: [ModuleID] { layout.normalizedOrder().filter { layout.enabled.contains($0) } }
    @State private var targeted = false
    private var accent: Color { Color(hue: theme.tint, saturation: 0.65, brightness: 1) }
    var body: some View {
        VStack(spacing: 0) {
            Group {
              if !state.expanded && (state.compactWidth < 48 || state.compactHeight < 16) {
                Circle().fill(store.deadline == nil ? accent : .green).frame(width: 6, height: 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
              } else if !state.expanded {
                ClosedNotchView(store: store, workspace: workspace, layout: layout, occlusion: state.closedOcclusion, referenceWidth: state.compactWidth)
              } else { HStack {
                Circle().fill(store.deadline == nil ? accent : .green).frame(width: 7, height: 7)
                Spacer()
                Image(systemName: state.pinned ? "pin.fill" : "chevron.up").font(.system(size: 9, weight: .bold))
              } }
            }
            .padding(.horizontal, !state.expanded ? 0 : max(16, layout.appearance.surface.shoulder + 8))
            .frame(height: state.expanded ? max(40, state.compactHeight) : state.compactHeight)
            .contentShape(Rectangle())
            .onTapGesture {
                if state.expanded && state.pinned { return }
                state.expanded.toggle()
            }
            .accessibilityLabel("Toggle Halo dashboard")
            .accessibilityAddTraits(.isButton)
            if state.expanded {
                if contextMusicActive {
                    ContextMusicView(media: workspace.media, options: contextOptions,
                                     visualizer: layout.closedNotch?.visualizer ?? VisualizerOptions(), surfaceState: state)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Your space, within reach.").font(.headline)
                                Text("HALO / PERSONAL WORKSPACE").font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(accent)
                            }
                            Spacer()
                            Button { state.pinned.toggle() } label: { Image(systemName: state.pinned ? "pin.fill" : "pin") }
                                .help("Keep expanded").accessibilityLabel("Keep expanded")
                        }
                        if layout.horizontalWidgets ?? false {
                            if layout.horizontalPages ?? false {
                                VStack(spacing: 8) {
                                    if !modules.isEmpty {
                                        let index = min(page, modules.count - 1)
                                        horizontalWidget(modules[index])
                                        HStack {
                                            Button { page = max(0, index - 1) } label: { Image(systemName: "chevron.left") }
                                                .disabled(index == 0).accessibilityLabel("Previous widget")
                                            Spacer()
                                            Text("\(modules[index].title) · \(index + 1) / \(modules.count)").font(.caption)
                                            Spacer()
                                            Button { page = min(modules.count - 1, index + 1) } label: { Image(systemName: "chevron.right") }
                                                .disabled(index == modules.count - 1).accessibilityLabel("Next widget")
                                        }
                                    } else { Text("Enable widgets in Settings → Modules.").foregroundStyle(.secondary) }
                                }
                            } else { ScrollView(.horizontal) {
                                LazyHStack(alignment: .top, spacing: layout.appearance.spacing) {
                                    widgetCards(horizontal: true)
                                }
                            } }
                        } else {
                            ScrollView {
                                LazyVStack(spacing: layout.appearance.spacing) {
                                    widgetCards(horizontal: false)
                                }
                            }
                        }
                        HStack {
                            Spacer()
                            Button("Settings") { NotificationCenter.default.post(name: Notification.Name("HaloOpenSettings"), object: nil) }
                        }
                    }.padding(.horizontal, max(20, layout.appearance.surface.shoulder + 12)).padding(.vertical, 20).frame(width: state.dashboardWidth).transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            ZStack {
                SurfaceBackground(appearance: layout.appearance, theme: theme, expanded: state.expanded, system: workspace.system)
                if !state.expanded || layout.closedNotch?.applyBackgroundWhenOpened == true {
                    AlbumNotchBackground(options: closedBackgroundOptions, media: workspace.media, system: workspace.system)
                }
            }
        }
        .clipShape(contour)
        .contentShape(contour)
        .overlay(contour.stroke(targeted ? accent : .white.opacity(0.12), lineWidth: 1))
        .foregroundStyle(.white).preferredColorScheme(.dark)
        .buttonStyle(.borderless)
        .contextMenu {
            Button(state.pinned ? "Unpin" : "Keep open") { state.pinned.toggle() }
            ForEach(workspace.settings.profiles) { profile in Button(profile.name) { workspace.apply(profile) } }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in store.expireFiles() }
        .onHover { state.hover($0, enabled: store.configuration.hoverToExpand) }
        .onChange(of: targeted) { active in
            if active { state.collapseTask?.cancel(); state.expanded = true }
        }
        .onChange(of: contextMusicActive) { active in
            if !active { state.contextPreferredSize = nil }
        }
        .onChange(of: state.expanded) { expanded in
            if !expanded { state.contextPreferredSize = nil }
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $targeted) { providers in
            state.expanded = true
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in store.addFiles([url]) }
                }
            }
            return !providers.isEmpty
        }
    }
    private func horizontalWidget(_ module: ModuleID) -> some View {
        GeometryReader { proxy in
            WidgetCard(style: layout.widgetStyle(for: module), availableHeight: proxy.size.height) {
                BuiltinOrIntegrationWidget(module: module, store: store)
            }
        }
    }
    @ViewBuilder private func widgetCards(horizontal: Bool) -> some View {
        ForEach(layout.normalizedOrder().filter { layout.enabled.contains($0) }) { module in
            if horizontal {
                horizontalWidget(module).frame(width: max(240, state.dashboardWidth - 64))
            } else {
                WidgetCard(style: layout.widgetStyle(for: module)) {
                    BuiltinOrIntegrationWidget(module: module, store: store)
                }
            }
        }
    }
}

struct BuiltinOrIntegrationWidget: View {
    let module: ModuleID
    @ObservedObject var store: AppStore
    @Environment(\.widgetStyle) private var style
    @ViewBuilder var body: some View {
        switch module {
        case .clock: WidgetClock(style: style)
        case .timer: timer
        case .shelf: shelf
        default: ModuleRegistry().view(for: module, store: store)
        }
    }
    private var timer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if style.showTitle { Label("Focus", systemImage: "timer").font(style.font()) }
                Spacer()
                if let deadline = store.deadline { Text(deadline, style: .timer).monospacedDigit() }
                else if store.pausedSeconds > 0 { Text("Paused · \(Int(store.pausedSeconds))s").font(style.font(scale: 0.85)) }
                else if store.finished { Text("Session complete").foregroundStyle(.green) }
                else { Text("Make room for deep work").font(style.font(scale: 0.85)).foregroundStyle(.secondary) }
            }
            HStack {
                if store.deadline != nil || store.pausedSeconds > 0 {
                    Button(store.deadline == nil ? "Resume" : "Pause") { store.pauseResume() }
                    Button("Reset") { store.resetTimer() }
                } else {
                    ForEach([5, 15, 25], id: \.self) { minutes in Button("\(minutes) min") { store.startTimer(minutes: minutes) } }
                }
            }.buttonStyle(.bordered)
        }
    }
    private var shelf: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if style.showTitle { Label("File shelf", systemImage: "tray").font(style.font()) }
                Spacer()
                Button { store.chooseFiles() } label: { Image(systemName: "plus") }.accessibilityLabel("Add files")
            }
            if store.files.isEmpty { Text("Drop files here. Originals stay untouched.").font(style.font(scale: 0.85)).foregroundStyle(.secondary).padding(.vertical, 8) }
            ForEach(store.files, id: \.self) { url in
                HStack {
                    ShelfFileInfo(url: url)
                    Spacer()
                    Button { store.toggleFilePin(url) } label: { Image(systemName: store.pinnedFiles.contains(url) ? "pin.fill" : "pin") }.help("Keep this file on the shelf")
                    Button { store.shelfPreview.show(url) } label: { Image(systemName: "eye") }.help("Quick Look")
                    Button { NSWorkspace.shared.activateFileViewerSelecting([url]) } label: { Image(systemName: "folder") }.help("Reveal in Finder")
                    Button { NSWorkspace.shared.open(url) } label: { Image(systemName: "arrow.up.forward.app") }.help("Open file")
                    ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                    Button { store.removeFile(url) } label: { Image(systemName: "xmark") }.help("Remove reference from shelf")
                }.onDrag { NSItemProvider(object: url as NSURL) }
            }
        }
    }
}

struct ShelfFileInfo: View {
    let url: URL
    @Environment(\.widgetStyle) private var style
    @State private var icon: NSImage?
    @State private var detail = ""
    var body: some View {
        HStack {
            if let icon { Image(nsImage: icon).resizable().frame(width: 24, height: 24) }
            VStack(alignment: .leading) {
                Text(url.lastPathComponent).font(style.font(scale: 0.85)).lineLimit(1)
                Text(detail).font(style.font(scale: 0.75)).foregroundStyle(.secondary).lineLimit(1)
            }
        }.onAppear {
            guard icon == nil else { return }
            icon = NSWorkspace.shared.icon(forFile: url.path)
            detail = fileDetail(url)
        }
    }
    private func fileDetail(_ url: URL) -> String {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]) else { return "Original unavailable" }
        if values.isDirectory == true { return "Folder" }
        return url.pathExtension.uppercased() + " · " + ByteCountFormatter.string(fromByteCount: Int64(values.fileSize ?? 0), countStyle: .file)
    }
}

private struct ContextMusicView: View {
    @ObservedObject var media: MediaService
    let options: ContextMusicOptions
    let visualizer: VisualizerOptions
    @ObservedObject var surfaceState: SurfaceState
    @AppStorage("HaloContextVisualizerFullWidth") private var visualizerFullWidth = false
    @State private var artwork: NSImage?
    @State private var playbackPosition = 0.0
    @State private var playbackDuration = 0.0
    @State private var scrubValue = 0.0
    @State private var isScrubbing = false
    @State private var lyrics = ""
    @State private var lyricsLoading = false
    @State private var vinylRotation = 0.0
    @State private var vinylLastTick = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var safeInset: Double { max(18, options.resolvedSpacing * 1.25) }
    private var artworkKey: String {
        "\(media.connectedApp ?? "")|\(media.title)|\(media.artist)|\(options.resolvedForegroundArtwork.rawValue)|\(options.usesArtworkBackground)"
    }
    private var playbackKey: String { "\(media.connectedApp ?? "")|\(media.title)|\(media.artist)|\(media.isPlaying)" }
    private var lyricKey: String { playbackKey + "|lyrics|\(options.showsLyrics)|\(options.usesOnlineLyrics)" }
    private var sizingKey: String {
        [options.resolvedLayoutMode.rawValue, options.resolvedForegroundArtwork.rawValue,
         String(options.artworkSize), String(options.showTitle), String(options.showArtist), String(options.showControls),
         String(options.showVisualizer), String(options.showsLyrics), options.resolvedLyricDisplay.rawValue,
         String(options.resolvedLyricFontSize), options.resolvedVisualizerStyle.rawValue,
         String(options.resolvedSpacing), String(options.resolvedControlSize), String(visualizerFullWidth)].joined(separator: "|")
    }
    private var songColors: [Color] { media.artworkColors.map(\.color) }
    private var primarySongColor: Color { songColors.first ?? options.textColor.color }
    private var effectiveTextColor: Color { options.usesSongTextColors && !songColors.isEmpty ? primarySongColor : options.textColor.color }
    private var effectiveControlColor: Color { options.usesSongControlColors && !songColors.isEmpty ? primarySongColor : effectiveTextColor }
    private var horizontalAlignment: HorizontalAlignment {
        switch options.resolvedContentAlignment { case .leading: return .leading; case .center: return .center; case .trailing: return .trailing }
    }
    private var frameAlignment: Alignment {
        switch options.resolvedContentAlignment { case .leading: return .leading; case .center: return .center; case .trailing: return .trailing }
    }
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                contextBackground(size: proxy.size)
                Group {
                    switch options.resolvedLayoutMode {
                    case .hero: heroLayout(proxy: proxy)
                    case .split: splitLayout(proxy: proxy)
                    case .compact: compactLayout(proxy: proxy)
                    case .minimal: minimalLayout(proxy: proxy)
                    }
                }
                .padding(.horizontal, safeInset)
                .padding(.top, max(16, safeInset * 0.75))
                .padding(.bottom, max(10, safeInset * 0.55))
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: options.resolvedCornerRadius, style: .continuous))
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 12) {
                    Button { surfaceState.pinned.toggle() } label: {
                        Image(systemName: surfaceState.pinned ? "pin.fill" : "pin").font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(effectiveControlColor)
                    .help(surfaceState.pinned ? "Allow Halo to close" : "Keep Halo open")
                    .accessibilityLabel(surfaceState.pinned ? "Unpin Halo" : "Keep Halo open")
                    Button { NotificationCenter.default.post(name: Notification.Name("HaloOpenSettings"), object: nil) } label: {
                        Image(systemName: "gearshape.fill").font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(effectiveControlColor)
                    .help("Open Halo settings")
                }
                .padding(.top, max(12, safeInset * 0.65))
                .padding(.trailing, safeInset)
            }
            .foregroundStyle(effectiveTextColor)
        }
        .task(id: artworkKey) {
            artwork = nil
            let needsArtwork = options.resolvedForegroundArtwork != .none || options.usesArtworkBackground
            guard needsArtwork else { return }
            let result = await ContextMusicArtworkReader.artwork(app: media.connectedApp, key: artworkKey)
            guard !Task.isCancelled else { return }
            artwork = result
        }
        .task(id: playbackKey) { await playbackLoop() }
        .task(id: lyricKey) { await loadLyrics() }
        .task(id: sizingKey) { publishPreferredSize() }
        .onChange(of: playbackDuration) { _ in publishPreferredSize() }
        .onDisappear { surfaceState.contextPreferredSize = nil }
    }

    private func publishPreferredSize() {
        let next = preferredSurfaceSize
        DispatchQueue.main.async { [surfaceState] in
            if let current = surfaceState.contextPreferredSize,
               abs(current.width - next.width) < 1, abs(current.height - next.height) < 1 { return }
            surfaceState.contextPreferredSize = next
        }
    }

    private var preferredSurfaceSize: CGSize {
        let spacing = options.resolvedSpacing
        let metadataHeight = (options.showTitle ? options.fontSize * 1.35 : 0) + (options.showArtist ? max(12, options.fontSize * 0.72) : 0)
        let lyricsHeight = options.showsLyrics ? options.resolvedLyricFontSize * (options.resolvedLyricDisplay == .word ? 1.25 : 2.05) : 0
        let scrubHeight = playbackDuration > 0.5 ? 30.0 : 0
        let controlsHeight = options.showControls ? options.resolvedControlSize * 1.35 : 0
        let visualizerHeight = options.showVisualizer ? max(18, min(64, visualizer.height)) : 0
        let artworkSize = options.resolvedForegroundArtwork == .none ? 0 : options.artworkSize
        let activeBlocks = [metadataHeight, lyricsHeight, scrubHeight, controlsHeight, visualizerHeight].filter { $0 > 0 }.count
        let gaps = Double(max(0, activeBlocks - 1)) * spacing
        let textColumn = metadataHeight + lyricsHeight + scrubHeight + controlsHeight + visualizerHeight + gaps
        let innerHeight: Double
        let width: Double
        switch options.resolvedLayoutMode {
        case .hero:
            innerHeight = artworkSize + textColumn + (artworkSize > 0 && textColumn > 0 ? spacing : 0)
            width = max(360, min(640, max(420, artworkSize * 2.4)))
        case .split:
            innerHeight = max(artworkSize, textColumn)
            width = max(430, min(700, 310 + artworkSize))
        case .compact:
            innerHeight = max(artworkSize, textColumn)
            width = max(440, min(720, 340 + artworkSize))
        case .minimal:
            innerHeight = artworkSize + textColumn + (artworkSize > 0 && textColumn > 0 ? spacing * 0.7 : 0)
            width = max(340, min(580, max(380, artworkSize * 2.15)))
        }
        // WindowManager already contributes the panel-level safety budget and top strip.
        // Keep this estimate close to the content itself so the player does not accumulate dead space.
        return CGSize(width: width, height: min(700, max(150, innerHeight + 18)))
    }

    @ViewBuilder private func contextBackground(size: CGSize) -> some View {
        ZStack {
            switch options.background {
            case .glass:
                Rectangle().fill(.ultraThinMaterial).opacity(max(0.12, options.backgroundOpacity))
            case .gradient:
                LinearGradient(colors: songColors.isEmpty ? [.blue, .purple] : Array(songColors.prefix(3)), startPoint: .topLeading, endPoint: .bottomTrailing)
                    .opacity(options.backgroundOpacity)
            default:
                Color.black.opacity(options.backgroundOpacity)
            }
            if options.usesSongBackgroundColors, !songColors.isEmpty {
                LinearGradient(colors: Array(songColors.prefix(2)), startPoint: .topLeading, endPoint: .bottomTrailing)
                    .opacity(min(0.78, max(0.16, options.backgroundOpacity)))
                    .blendMode(.plusLighter)
            }
            if options.usesArtworkBackground, let artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .blur(radius: options.resolvedArtworkBackgroundBlur)
                    .overlay(Color.black.opacity(options.resolvedArtworkBackgroundDim))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private func heroLayout(proxy: GeometryProxy) -> some View {
        VStack(alignment: horizontalAlignment, spacing: options.resolvedSpacing) {
            if options.resolvedForegroundArtwork != .none { foregroundArtwork(size: min(options.artworkSize, max(48, proxy.size.height * 0.34))) }
            metadata
            lyricsView
            scrubber
            controls
            visualizerView
            errorView
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func splitLayout(proxy: GeometryProxy) -> some View {
        HStack(spacing: options.resolvedSpacing * 1.4) {
            if options.resolvedForegroundArtwork != .none { foregroundArtwork(size: min(options.artworkSize, max(52, proxy.size.height * 0.50))) }
            VStack(alignment: horizontalAlignment, spacing: options.resolvedSpacing) {
                metadata
                lyricsView
                scrubber
                controls
                visualizerView
                errorView
            }
            .frame(maxWidth: .infinity, alignment: frameAlignment)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func compactLayout(proxy: GeometryProxy) -> some View {
        HStack(spacing: options.resolvedSpacing) {
            if options.resolvedForegroundArtwork != .none { foregroundArtwork(size: min(options.artworkSize, max(42, proxy.size.height * 0.24))) }
            VStack(alignment: .leading, spacing: max(3, options.resolvedSpacing * 0.45)) {
                metadata
                lyricsView
                scrubber
                visualizerView
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            controls
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func minimalLayout(proxy: GeometryProxy) -> some View {
        VStack(alignment: horizontalAlignment, spacing: max(4, options.resolvedSpacing * 0.6)) {
            if options.resolvedForegroundArtwork != .none { foregroundArtwork(size: min(options.artworkSize, max(36, proxy.size.height * 0.20))) }
            metadata
            lyricsView
            scrubber
            controls
            visualizerView
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private func foregroundArtwork(size: Double) -> some View {
        Group {
            switch options.resolvedForegroundArtwork {
            case .none:
                EmptyView()
            case .cover:
                Group {
                    if let artwork { Image(nsImage: artwork).resizable().scaledToFill() }
                    else { artworkPlaceholder }
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: min(options.resolvedCornerRadius, size * 0.18), style: .continuous))
                .shadow(color: .black.opacity(0.28), radius: size * 0.055, y: size * 0.025)
            case .vinyl:
                vinylArtwork(size: size)
            }
        }
        .id(options.resolvedForegroundArtwork.rawValue)
    }

    private func vinylArtwork(size: Double) -> some View {
        VinylRecordView(artwork: artwork,
                        size: size,
                        palette: media.artworkColors,
                        playing: media.isPlaying,
                        lowPower: false)
    }

    private var artworkPlaceholder: some View {
        ZStack { Color.white.opacity(0.07); Image(systemName: "music.note").font(.system(size: 28, weight: .medium)).opacity(0.75) }
    }

    private var metadata: some View {
        VStack(alignment: horizontalAlignment, spacing: max(2, options.resolvedSpacing * 0.28)) {
            if options.showTitle {
                Text(media.title).font(.system(size: options.fontSize, weight: .semibold, design: .rounded)).lineLimit(2).multilineTextAlignment(textAlignment)
            }
            if options.showArtist {
                Text(media.artist.isEmpty ? "Unknown artist" : media.artist).font(.system(size: max(10, options.fontSize * 0.68), weight: .medium)).opacity(0.72).lineLimit(1)
            }
        }
        .foregroundStyle(effectiveTextColor)
        .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    @ViewBuilder private var lyricsView: some View {
        if options.showsLyrics {
            if lyricsLoading && lyrics.isEmpty {
                Label("Loading lyrics…", systemImage: "text.quote").font(.system(size: options.resolvedLyricFontSize)).opacity(0.72)
            } else if lyrics.isEmpty {
                Text("Synced lyrics unavailable").font(.system(size: options.resolvedLyricFontSize)).opacity(0.55)
            } else {
                TimelineView(.animation(minimumInterval: 0.06, paused: !media.isPlaying)) { _ in
                    let position = (isScrubbing ? scrubValue : playbackPosition) + options.resolvedLyricSyncOffset
                    let lines = ContextLyricTimeline.parse(lyrics)
                    if let frame = ContextLyricTimeline.frame(lines: lines, position: max(0, position), duration: playbackDuration) {
                        contextLyric(frame)
                    }
                }
            }
        }
    }

    @ViewBuilder private func contextLyric(_ frame: ContextLyricFrame) -> some View {
        switch options.resolvedLyricDisplay {
        case .line:
            VStack(alignment: horizontalAlignment, spacing: 3) {
                Text(frame.current.text).font(.system(size: options.resolvedLyricFontSize, weight: .semibold, design: .rounded)).lineLimit(2).multilineTextAlignment(textAlignment)
                if let next = frame.next { Text(next.text).font(.system(size: max(10, options.resolvedLyricFontSize * 0.74))).opacity(0.35).lineLimit(1) }
            }
        case .word:
            let words = frame.current.text.split(whereSeparator: \.isWhitespace).map(String.init)
            Text(words.indices.contains(frame.wordIndex) ? words[frame.wordIndex] : frame.current.text)
                .font(.system(size: options.resolvedLyricFontSize, weight: .bold, design: .rounded)).lineLimit(1)
        case .focus:
            focusedLyricLine(frame.current.text, activeWord: frame.wordIndex)
        }
    }

    private func focusedLyricLine(_ text: String, activeWord: Int) -> some View {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        var result = Text("")
        for (index, word) in words.enumerated() {
            result = result + Text((index == 0 ? "" : " ") + word)
                .fontWeight(index == activeWord ? .bold : .regular)
                .foregroundColor(index == activeWord ? primarySongColor : effectiveTextColor.opacity(0.5))
        }
        return result.font(.system(size: options.resolvedLyricFontSize, design: .rounded)).lineLimit(2).multilineTextAlignment(textAlignment)
    }

    @ViewBuilder private var scrubber: some View {
        if playbackDuration > 0.5 {
            VStack(spacing: 3) {
                Slider(value: Binding(
                    get: { isScrubbing ? scrubValue : min(playbackDuration, max(0, playbackPosition)) },
                    set: { newValue in
                        if !isScrubbing { scrubValue = playbackPosition }
                        isScrubbing = true
                        scrubValue = min(playbackDuration, max(0, newValue))
                    }
                ), in: 0...max(1, playbackDuration), onEditingChanged: { editing in
                    if editing {
                        scrubValue = min(playbackDuration, max(0, playbackPosition)); isScrubbing = true
                    } else {
                        let target = min(playbackDuration, max(0, scrubValue)); playbackPosition = target; isScrubbing = false
                        Task {
                            let result = await ContextMusicArtworkReader.seek(app: media.connectedApp, position: target)
                            guard !Task.isCancelled, let result else { return }
                            playbackPosition = result.position; playbackDuration = result.duration
                        }
                    }
                }).controlSize(.small).tint(effectiveControlColor)
                HStack {
                    Text(formatTime(isScrubbing ? scrubValue : playbackPosition)); Spacer()
                    Text("−" + formatTime(max(0, playbackDuration - (isScrubbing ? scrubValue : playbackPosition))))
                }.font(.system(size: 9, weight: .medium, design: .monospaced)).opacity(0.62)
            }.frame(maxWidth: 440)
        }
    }

    @ViewBuilder private var controls: some View {
        if options.showControls {
            HStack(spacing: options.resolvedControlSize * 1.05) {
                control("backward.end.fill", action: "previous track", label: "Previous track")
                control(media.isPlaying ? "pause.fill" : "play.fill", action: "playpause", label: "Play or pause")
                control("forward.end.fill", action: "next track", label: "Next track")
            }
            .font(.system(size: options.resolvedControlSize, weight: .semibold))
            .foregroundStyle(effectiveControlColor)
            .disabled(media.busy)
        }
    }

    @ViewBuilder private var visualizerView: some View {
        if options.showVisualizer {
            let configured = contextVisualizerOptions
            PlaybackVisualizer(kind: options.resolvedVisualizerStyle, playing: media.isPlaying, enabled: true,
                               options: configured, palette: media.artworkColors, fallback: effectiveControlColor)
                .frame(maxWidth: visualizerFullWidth ? .infinity : CGFloat(configured.width), alignment: .center)
                .frame(height: max(18, min(64, configured.height)))
                .contentShape(Rectangle())
                .contextMenu {
                    Toggle("Fill interface width", isOn: $visualizerFullWidth)
                }
                .overlay(alignment: .topTrailing) {
                    Button { visualizerFullWidth.toggle() } label: {
                        Image(systemName: visualizerFullWidth ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(effectiveControlColor.opacity(0.72))
                    .help(visualizerFullWidth ? "Use visualizer's normal width" : "Fill the interface width")
                    .padding(.trailing, 2)
                }
        }
    }

    private var contextVisualizerOptions: VisualizerOptions {
        var value = visualizer
        value.dynamicColors = options.usesSongVisualizerColors
        value.width = visualizerFullWidth ? max(120, surfaceState.dashboardWidth - safeInset * 2) : max(value.width, 120)
        return value
    }

    @ViewBuilder private var errorView: some View {
        if let error = media.error { Text(error).font(.caption).foregroundStyle(.orange) }
    }

    private var textAlignment: TextAlignment {
        switch options.resolvedContentAlignment { case .leading: return .leading; case .center: return .center; case .trailing: return .trailing }
    }

    private func control(_ symbol: String, action: String, label: String) -> some View {
        Button { if let app = media.connectedApp { media.perform(action, app: app) } } label: { Image(systemName: symbol) }
            .buttonStyle(.plain).accessibilityLabel(label)
    }

    private func playbackLoop() async {
        playbackPosition = 0; playbackDuration = 0
        while !Task.isCancelled {
            if !isScrubbing, let sample = await ContextMusicArtworkReader.playback(app: media.connectedApp) {
                playbackPosition = sample.position; playbackDuration = sample.duration
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    private func loadLyrics() async {
        lyrics = ""; lyricsLoading = false
        guard options.showsLyrics else { return }
        lyricsLoading = true
        let duration = playbackDuration > 0 ? playbackDuration : (await ContextMusicArtworkReader.playback(app: media.connectedApp))?.duration
        lyrics = await ContextMusicArtworkReader.lyrics(app: media.connectedApp, key: lyricKey, title: media.title,
                                                        artist: media.artist, duration: duration,
                                                        onlineFallback: options.usesOnlineLyrics)
        lyricsLoading = false
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down)); let hours = total / 3600; let minutes = (total % 3600) / 60; let secs = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, secs) : String(format: "%d:%02d", minutes, secs)
    }
}

private struct ContextLyricLine: Identifiable {
    let id: Int
    let time: Double
    let text: String
}
private struct ContextLyricFrame {
    let current: ContextLyricLine
    let next: ContextLyricLine?
    let wordIndex: Int
}
private enum ContextLyricTimeline {
    static func parse(_ value: String) -> [ContextLyricLine] {
        let rawLines = value.split(whereSeparator: \.isNewline).map(String.init)
        let offset = rawLines.compactMap { raw -> Double? in
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.lowercased().hasPrefix("[offset:"), let close = line.firstIndex(of: "]") else { return nil }
            let start = line.index(line.startIndex, offsetBy: 8)
            return Double(line[start..<close]).map { $0 / 1000 }
        }.first ?? 0
        var lines: [ContextLyricLine] = []
        for raw in rawLines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.lowercased().hasPrefix("[offset:"), line.first == "[", let close = line.firstIndex(of: "]") else { continue }
            let stamp = String(line[line.index(after: line.startIndex)..<close])
            let text = String(line[line.index(after: close)...]).trimmingCharacters(in: .whitespaces)
            let parts = stamp.split(separator: ":")
            guard parts.count == 2, let minutes = Double(parts[0]), let seconds = Double(parts[1]), !text.isEmpty else { continue }
            lines.append(ContextLyricLine(id: lines.count, time: max(0, minutes * 60 + seconds + offset), text: text))
        }
        return lines.sorted { $0.time < $1.time }.enumerated().map { ContextLyricLine(id: $0.offset, time: $0.element.time, text: $0.element.text) }
    }
    static func frame(lines: [ContextLyricLine], position: Double, duration: Double) -> ContextLyricFrame? {
        guard !lines.isEmpty else { return nil }
        let index = lines.lastIndex(where: { $0.time <= position + 0.035 }) ?? 0
        let current = lines[index]; let next = index + 1 < lines.count ? lines[index + 1] : nil
        let end = max(current.time + 0.35, next?.time ?? (duration > current.time ? duration : current.time + 4))
        let words = current.text.split(whereSeparator: \.isWhitespace)
        let progress = min(0.999, max(0, (position - current.time) / max(0.35, end - current.time)))
        return ContextLyricFrame(current: current, next: next, wordIndex: words.isEmpty ? 0 : min(words.count - 1, Int(progress * Double(words.count))))
    }
}

private enum ContextMusicArtworkReader {
    struct PlaybackSample { let position: Double; let duration: Double }
    private struct LRCLyrics: Decodable { let duration: Double?; let plainLyrics: String?; let syncedLyrics: String? }
    private static let queue = DispatchQueue(label: "Halo.ContextMusicArtwork", qos: .utility)
    private static let lock = NSLock()
    private static var cache: [String: Data] = [:]
    private static var lyricsCache: [String: String] = [:]

    static func artwork(app: String?, key: String) async -> NSImage? {
        guard let app else { return nil }
        lock.lock(); let cached = cache[key]; lock.unlock()
        if let cached { return NSImage(data: cached) }
        let payload: (Data?, String?) = await withCheckedContinuation { continuation in
            queue.async {
                let artworkExpression = app == "com.spotify.client" ? "artwork url of current track" : "raw data of artwork 1 of current track"
                let source = """
                if application id "\(app)" is not running then return {"", ""}
                with timeout of 5 seconds
                    tell application id "\(app)"
                        return {(name of current track as text), \(artworkExpression)}
                    end tell
                end timeout
                """
                var failure: NSDictionary?; let result = NSAppleScript(source: source)?.executeAndReturnError(&failure)
                if failure != nil { continuation.resume(returning: (nil, nil)); return }
                continuation.resume(returning: (app == "com.apple.Music" ? result?.atIndex(2)?.data : nil,
                                                app == "com.spotify.client" ? result?.atIndex(2)?.stringValue : nil))
            }
        }
        var data = payload.0
        if data == nil, let urlString = payload.1, let url = URL(string: urlString), url.scheme == "https" {
            var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 8); request.setValue("Halo/1.0", forHTTPHeaderField: "User-Agent")
            if let (downloaded, response) = try? await URLSession.shared.data(for: request), downloaded.count <= 5_000_000,
               (response as? HTTPURLResponse)?.statusCode == 200 { data = downloaded }
        }
        guard let data, data.count <= 5_000_000 else { return nil }
        lock.lock(); cache[key] = data; lock.unlock(); return NSImage(data: data)
    }

    static func playback(app: String?) async -> PlaybackSample? {
        guard let app, ["com.apple.Music", "com.spotify.client"].contains(app) else { return nil }
        return await withCheckedContinuation { continuation in
            queue.async {
                let source = """
                if application id "\(app)" is not running then return {-1, -1}
                with timeout of 2 seconds
                    tell application id "\(app)"
                        try
                            return {(player position as real), (duration of current track as real)}
                        on error
                            return {-1, -1}
                        end try
                    end tell
                end timeout
                """
                var failure: NSDictionary?; let result = NSAppleScript(source: source)?.executeAndReturnError(&failure)
                guard failure == nil, let position = result?.atIndex(1)?.doubleValue, let duration = result?.atIndex(2)?.doubleValue,
                      position >= 0, duration > 0 else { continuation.resume(returning: nil); return }
                continuation.resume(returning: PlaybackSample(position: min(duration, position), duration: duration))
            }
        }
    }

    static func seek(app: String?, position: Double) async -> PlaybackSample? {
        guard let app, ["com.apple.Music", "com.spotify.client"].contains(app), position.isFinite else { return nil }
        let requested = max(0, position)
        return await withCheckedContinuation { continuation in
            queue.async {
                let source = """
                if application id "\(app)" is not running then return {-1, -1}
                with timeout of 3 seconds
                    tell application id "\(app)"
                        try
                            set player position to \(requested)
                            return {(player position as real), (duration of current track as real)}
                        on error
                            return {-1, -1}
                        end try
                    end tell
                end timeout
                """
                var failure: NSDictionary?; let result = NSAppleScript(source: source)?.executeAndReturnError(&failure)
                guard failure == nil, let actual = result?.atIndex(1)?.doubleValue, let duration = result?.atIndex(2)?.doubleValue,
                      actual >= 0, duration > 0 else { continuation.resume(returning: nil); return }
                continuation.resume(returning: PlaybackSample(position: min(duration, actual), duration: duration))
            }
        }
    }

    static func lyrics(app: String?, key: String, title: String, artist: String, duration: Double?, onlineFallback: Bool) async -> String {
        let cacheKey = key + "|duration:" + (duration.map { String(Int($0.rounded())) } ?? "unknown")
        lock.lock(); let cached = lyricsCache[cacheKey]; lock.unlock(); if let cached { return cached }
        var value = ""
        if onlineFallback { value = await onlineLyrics(title: title, artist: artist, duration: duration) }
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, app == "com.apple.Music" { value = await embeddedAppleMusicLyrics() }
        let bounded = String(value.prefix(20_000)); lock.lock(); lyricsCache[cacheKey] = bounded; lock.unlock(); return bounded
    }

    private static func embeddedAppleMusicLyrics() async -> String {
        await withCheckedContinuation { continuation in queue.async {
            let source = """
            if application id "com.apple.Music" is not running then return ""
            with timeout of 4 seconds
                tell application id "com.apple.Music"
                    try
                        return (get lyrics of current track) as text
                    on error
                        return ""
                    end try
                end tell
            end timeout
            """
            var failure: NSDictionary?; let result = NSAppleScript(source: source)?.executeAndReturnError(&failure)
            continuation.resume(returning: failure == nil ? (result?.stringValue ?? "") : "")
        } }
    }

    private static func onlineLyrics(title: String, artist: String, duration: Double?) async -> String {
        guard !title.isEmpty, !artist.isEmpty else { return "" }
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [URLQueryItem(name: "track_name", value: title), URLQueryItem(name: "artist_name", value: artist)]
        if let duration, duration >= 1, duration <= 3600 { components.queryItems?.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded())))) }
        guard let url = components.url else { return "" }
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 8)
        request.setValue("Halo/1.0 (https://github.com/Redstoneinvente/Halo)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request), (response as? HTTPURLResponse)?.statusCode == 200,
              data.count <= 1_000_000, let result = try? JSONDecoder().decode(LRCLyrics.self, from: data) else { return "" }
        if let requested = duration, let returned = result.duration, abs(requested - returned) > 2.5 { return "" }
        return result.syncedLyrics ?? ""
    }
}
