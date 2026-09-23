import SwiftUI
import AppKit
import CoreGraphics
import UniformTypeIdentifiers
import Darwin

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


// MARK: - Transfer Context Interface

@MainActor
final class TransferActivityMonitor: ObservableObject {
    static let shared = TransferActivityMonitor()

    @Published private(set) var downloadBytesPerSecond: Double = 0
    @Published private(set) var uploadBytesPerSecond: Double = 0
    @Published private(set) var peakDownloadBytesPerSecond: Double = 0
    @Published private(set) var peakUploadBytesPerSecond: Double = 0
    @Published private(set) var sessionDownloadedBytes: Double = 0
    @Published private(set) var sessionUploadedBytes: Double = 0
    @Published private(set) var sessionStartedAt: Date?
    @Published private(set) var isActive = false
    @Published private(set) var direction = "Idle"
    @Published private(set) var downloadHistory: [Double] = []
    @Published private(set) var uploadHistory: [Double] = []

    private var timer: Timer?
    private var previousBytes: (received: UInt64, sent: UInt64)?
    private var previousDate = Date()
    private var lastBusyDate = Date.distantPast
    private var busySamples = 0

    private init() {
        previousBytes = networkByteTotals()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    private func preference(_ key: String, fallback: Double) -> Double {
        guard UserDefaults.standard.object(forKey: key) != nil else { return fallback }
        return UserDefaults.standard.double(forKey: key)
    }

    private func preference(_ key: String, fallback: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return fallback }
        return UserDefaults.standard.bool(forKey: key)
    }

    private func sample() {
        let now = Date()
        let totals = networkByteTotals()
        guard let previousBytes else {
            self.previousBytes = totals
            previousDate = now
            return
        }
        self.previousBytes = totals
        let elapsed = max(0.1, now.timeIntervalSince(previousDate))
        previousDate = now

        let receivedDelta = totals.received >= previousBytes.received ? totals.received - previousBytes.received : 0
        let sentDelta = totals.sent >= previousBytes.sent ? totals.sent - previousBytes.sent : 0
        downloadBytesPerSecond = Double(receivedDelta) / elapsed
        uploadBytesPerSecond = Double(sentDelta) / elapsed

        let historyLimit = 60
        downloadHistory.append(downloadBytesPerSecond)
        uploadHistory.append(uploadBytesPerSecond)
        if downloadHistory.count > historyLimit { downloadHistory.removeFirst(downloadHistory.count - historyLimit) }
        if uploadHistory.count > historyLimit { uploadHistory.removeFirst(uploadHistory.count - historyLimit) }

        let threshold = max(0.01, preference("HaloContextTransferThresholdMBps", fallback: 0.35)) * 1_000_000
        let reactDownloads = preference("HaloContextTransferReactDownloads", fallback: true)
        let reactUploads = preference("HaloContextTransferReactUploads", fallback: true)
        let downloadBusy = reactDownloads && downloadBytesPerSecond >= threshold
        let uploadBusy = reactUploads && uploadBytesPerSecond >= threshold
        let busy = downloadBusy || uploadBusy

        if downloadBusy && uploadBusy { direction = "Uploading + Downloading" }
        else if downloadBusy { direction = "Downloading" }
        else if uploadBusy { direction = "Uploading" }
        else if isActive { direction = downloadBytesPerSecond >= uploadBytesPerSecond ? "Downloading" : "Uploading" }
        else { direction = "Idle" }

        if busy {
            busySamples += 1
            lastBusyDate = now
            if !isActive && busySamples >= 2 {
                isActive = true
                sessionStartedAt = now
                sessionDownloadedBytes = 0
                sessionUploadedBytes = 0
                peakDownloadBytesPerSecond = 0
                peakUploadBytesPerSecond = 0
            }
        } else {
            busySamples = 0
        }

        if isActive {
            sessionDownloadedBytes += Double(receivedDelta)
            sessionUploadedBytes += Double(sentDelta)
            peakDownloadBytesPerSecond = max(peakDownloadBytesPerSecond, downloadBytesPerSecond)
            peakUploadBytesPerSecond = max(peakUploadBytesPerSecond, uploadBytesPerSecond)
            let linger = max(0, preference("HaloContextTransferLingerSeconds", fallback: 2.5))
            if !busy && now.timeIntervalSince(lastBusyDate) > linger {
                isActive = false
                direction = "Idle"
                sessionStartedAt = nil
            }
        }
    }

    private func networkByteTotals() -> (received: UInt64, sent: UInt64) {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return (0, 0) }
        defer { freeifaddrs(pointer) }
        var received: UInt64 = 0
        var sent: UInt64 = 0
        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let item = current {
            let entry = item.pointee
            let flags = Int32(entry.ifa_flags)
            if (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0, let raw = entry.ifa_data {
                let data = raw.assumingMemoryBound(to: if_data.self).pointee
                received &+= UInt64(data.ifi_ibytes)
                sent &+= UInt64(data.ifi_obytes)
            }
            current = entry.ifa_next
        }
        return (received, sent)
    }
}

private struct TransferHistoryGraph: View {
    let download: [Double]
    let upload: [Double]

    var body: some View {
        GeometryReader { proxy in
            let maxValue = max(1, (download + upload).max() ?? 1)
            ZStack {
                path(values: download, size: proxy.size, maxValue: maxValue)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                path(values: upload, size: proxy.size, maxValue: maxValue)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func path(values: [Double], size: CGSize, maxValue: Double) -> Path {
        Path { path in
            guard values.count > 1 else { return }
            for (index, value) in values.enumerated() {
                let x = size.width * CGFloat(index) / CGFloat(max(1, values.count - 1))
                let y = size.height - size.height * CGFloat(min(1, max(0, value / maxValue)))
                if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
        }
    }
}

private struct TransferActivityIndicator: View {
    @ObservedObject var monitor: TransferActivityMonitor
    let compact: Bool
    @AppStorage("HaloContextTransferIndicatorStyle") private var style = "Edge Bar"
    @AppStorage("HaloContextTransferIndicatorShowSpeed") private var showSpeed = true
    @AppStorage("HaloContextTransferIndicatorThickness") private var thickness = 3.0
    @AppStorage("HaloContextTransferIndicatorIntensity") private var intensity = 1.0
    @AppStorage("HaloContextTransferThresholdMBps") private var thresholdMBps = 0.35

    private var uploadOnly: Bool {
        monitor.direction.contains("Uploading") && !monitor.direction.contains("Downloading")
    }
    private var accent: Color { uploadOnly ? .orange : .accentColor }
    private var currentSpeed: Double { max(monitor.downloadBytesPerSecond, monitor.uploadBytesPerSecond) }
    private var activity: Double {
        let threshold = max(50_000, thresholdMBps * 1_000_000)
        return min(1, max(0.10, currentSpeed / (threshold * 5)))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                switch style {
                case "Center Pulse":
                    HStack(spacing: 8) {
                        Image(systemName: uploadOnly ? "arrow.up" : "arrow.down")
                            .font(.system(size: compact ? 10 : 14, weight: .bold))
                        Capsule()
                            .fill(accent.opacity(0.18))
                            .frame(width: compact ? 56 : 110, height: max(2, thickness))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(accent.opacity(0.95 * intensity))
                                    .frame(width: (compact ? 56 : 110) * activity)
                                    .animation(.easeOut(duration: 0.25), value: activity)
                            }
                        if showSpeed { Text(speed(currentSpeed)).monospacedDigit() }
                    }
                    .font(.system(size: compact ? 9 : 11, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case "Dual Rails":
                    VStack(spacing: max(2, thickness)) {
                        rail(value: monitor.downloadBytesPerSecond, threshold: thresholdMBps, color: .accentColor, width: proxy.size.width)
                        rail(value: monitor.uploadBytesPerSecond, threshold: thresholdMBps, color: .orange, width: proxy.size.width)
                    }
                    .padding(.horizontal, compact ? 8 : 14)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .overlay(alignment: .center) {
                        if showSpeed {
                            Text(speed(currentSpeed))
                                .font(.system(size: compact ? 8 : 10, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.black.opacity(0.52), in: Capsule())
                        }
                    }

                case "Minimal":
                    HStack(spacing: 6) {
                        Image(systemName: uploadOnly ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .foregroundStyle(accent)
                        if showSpeed { Text(speed(currentSpeed)).monospacedDigit() }
                    }
                    .font(.system(size: compact ? 9 : 11, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                default:
                    VStack(spacing: 0) {
                        Spacer()
                        Capsule()
                            .fill(.white.opacity(0.10))
                            .frame(height: max(2, thickness))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(accent.opacity(0.95 * intensity))
                                    .frame(width: max(8, proxy.size.width * activity), height: max(2, thickness))
                                    .animation(.easeOut(duration: 0.25), value: activity)
                            }
                    }
                    .overlay(alignment: .center) {
                        HStack(spacing: 6) {
                            Image(systemName: uploadOnly ? "arrow.up" : "arrow.down")
                            if showSpeed { Text(speed(currentSpeed)).monospacedDigit() }
                        }
                        .font(.system(size: compact ? 9 : 11, weight: .semibold, design: .rounded))
                    }
                }
            }
        }
    }

    private func rail(value: Double, threshold: Double, color: Color, width: CGFloat) -> some View {
        let floor = max(50_000, threshold * 1_000_000)
        let fraction = min(1, max(0.05, value / (floor * 5)))
        return Capsule()
            .fill(color.opacity(0.12))
            .frame(height: max(2, thickness))
            .overlay(alignment: .leading) {
                Capsule().fill(color.opacity(0.92 * intensity))
                    .frame(width: max(5, width * fraction), height: max(2, thickness))
                    .animation(.easeOut(duration: 0.25), value: fraction)
            }
    }

    private func speed(_ value: Double) -> String {
        if value >= 1_000_000_000 { return String(format: "%.1f GB/s", value / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1f MB/s", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.0f KB/s", value / 1_000) }
        return String(format: "%.0f B/s", value)
    }
}

private enum TransferCISizing {
    private static func bool(_ key: String, fallback: Bool, defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
    }

    private static func string(_ key: String, fallback: String, defaults: UserDefaults = .standard) -> String {
        defaults.string(forKey: key) ?? fallback
    }

    private static func number(_ key: String, fallback: Double, defaults: UserDefaults = .standard) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }

    static func minimumExpandedWidth(physicalNotchWidth: CGFloat) -> CGFloat {
        max(220, physicalNotchWidth > 0 ? physicalNotchWidth + 28 : 220)
    }

    static func openPreferredSize(stripHeight: CGFloat = 40, defaults: UserDefaults = .standard) -> CGSize {
        let body = bodyPreferredSize(defaults: defaults)
        return CGSize(width: body.width, height: body.height + max(40, stripHeight))
    }

    private static func bodyPreferredSize(defaults: UserDefaults) -> CGSize {
        let openStyle = string("HaloContextTransferOpenStyle", fallback: "Dashboard", defaults: defaults)
        let compact = bool("HaloContextTransferCompact", fallback: false, defaults: defaults)
        let showDirection = bool("HaloContextTransferShowDirection", fallback: true, defaults: defaults)
        let showDownload = bool("HaloContextTransferShowDownload", fallback: true, defaults: defaults)
        let showUpload = bool("HaloContextTransferShowUpload", fallback: true, defaults: defaults)
        let showPeak = bool("HaloContextTransferShowPeak", fallback: true, defaults: defaults)
        let showSession = bool("HaloContextTransferShowSession", fallback: true, defaults: defaults)
        let showElapsed = bool("HaloContextTransferShowElapsed", fallback: true, defaults: defaults)
        let showGraph = bool("HaloContextTransferShowGraph", fallback: true, defaults: defaults)
        let indicatorStyle = string("HaloContextTransferIndicatorStyle", fallback: "Edge Bar", defaults: defaults)
        let indicatorShowSpeed = bool("HaloContextTransferIndicatorShowSpeed", fallback: true, defaults: defaults)
        let indicatorThickness = number("HaloContextTransferIndicatorThickness", fallback: 3, defaults: defaults)

        let primaryStats = (showDownload ? 1 : 0) + (showUpload ? 1 : 0)

        switch openStyle {
        case "Indicator":
            let baseWidth: CGFloat
            switch indicatorStyle {
            case "Minimal": baseWidth = indicatorShowSpeed ? 270 : 230
            case "Center Pulse": baseWidth = indicatorShowSpeed ? 360 : 290
            case "Dual Rails": baseWidth = indicatorShowSpeed ? 390 : 315
            default: baseWidth = indicatorShowSpeed ? 350 : 285
            }
            let hasMeta = showDirection || showElapsed
            let extraThickness = CGFloat(max(0, indicatorThickness - 3))
            return CGSize(width: baseWidth, height: max(CGFloat(96), CGFloat(70 + (hasMeta ? 26 : 8)) + extraThickness))

        case "Minimal":
            var width: CGFloat = 205
            if showDirection { width += 105 }
            width += CGFloat(primaryStats) * 105
            if showElapsed { width += 62 }
            return CGSize(width: min(600, max(260, width)), height: 96)

        default:
            let peakStats = (!compact && showPeak) ? 2 : 0
            let stats = primaryStats + peakStats
            var width: CGFloat = compact ? 300 : 330
            if stats > 0 { width += CGFloat(stats) * (compact ? 76 : 88) }
            if !showDirection && !showElapsed && stats == 0 { width = 280 }
            width = min(720, max(280, width))

            var height: CGFloat = compact ? 78 : 86
            if stats > 0 { height += compact ? 58 : 66 }
            if showGraph && !compact { height += 70 }
            if showSession && !compact { height += 34 }
            return CGSize(width: width, height: min(300, max(96, height)))
        }
    }

    static func closedPreferredWidth(physicalNotchWidth: CGFloat, defaults: UserDefaults = .standard) -> CGFloat {
        let closedStyle = string("HaloContextTransferClosedStyle", fallback: "Stats", defaults: defaults)
        let showDirection = bool("HaloContextTransferShowDirection", fallback: true, defaults: defaults)
        let showDownload = bool("HaloContextTransferShowDownload", fallback: true, defaults: defaults)
        let showUpload = bool("HaloContextTransferShowUpload", fallback: true, defaults: defaults)
        let indicatorStyle = string("HaloContextTransferIndicatorStyle", fallback: "Edge Bar", defaults: defaults)
        let indicatorShowSpeed = bool("HaloContextTransferIndicatorShowSpeed", fallback: true, defaults: defaults)

        let contentWidth: CGFloat
        switch closedStyle {
        case "Indicator":
            switch indicatorStyle {
            case "Minimal": contentWidth = indicatorShowSpeed ? 165 : 110
            case "Center Pulse": contentWidth = indicatorShowSpeed ? 245 : 180
            case "Dual Rails": contentWidth = indicatorShowSpeed ? 255 : 195
            default: contentWidth = indicatorShowSpeed ? 235 : 175
            }
        case "Minimal":
            contentWidth = 165
        default:
            var width: CGFloat = 48
            if showDirection { width += 88 }
            if showDownload { width += 96 }
            if showUpload { width += 96 }
            contentWidth = width
        }

        // The physical camera/notch is a hard lower bound on real notched Macs.
        let physicalFloor = physicalNotchWidth > 0 ? physicalNotchWidth + 16 : 110
        return min(520, max(physicalFloor, contentWidth))
    }
}

private struct TransferContextView: View {
    @ObservedObject var monitor: TransferActivityMonitor
    @ObservedObject var surfaceState: SurfaceState
    @AppStorage("HaloContextTransferOpenStyle") private var openStyle = "Dashboard"
    @AppStorage("HaloContextTransferCompact") private var compact = false
    @AppStorage("HaloContextTransferShowDirection") private var showDirection = true
    @AppStorage("HaloContextTransferShowDownload") private var showDownload = true
    @AppStorage("HaloContextTransferShowUpload") private var showUpload = true
    @AppStorage("HaloContextTransferShowPeak") private var showPeak = true
    @AppStorage("HaloContextTransferShowSession") private var showSession = true
    @AppStorage("HaloContextTransferShowElapsed") private var showElapsed = true
    @AppStorage("HaloContextTransferShowGraph") private var showGraph = true

    private var elapsed: String {
        guard let start = monitor.sessionStartedAt else { return "0:00" }
        let seconds = max(0, Int(Date().timeIntervalSince(start)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    @AppStorage("HaloContextTransferIndicatorStyle") private var indicatorStyle = "Edge Bar"
    @AppStorage("HaloContextTransferIndicatorShowSpeed") private var indicatorShowSpeed = true
    @AppStorage("HaloContextTransferIndicatorThickness") private var indicatorThickness = 3.0

    private var primaryStatCount: Int { (showDownload ? 1 : 0) + (showUpload ? 1 : 0) }
    private var dashboardStatCount: Int { primaryStatCount + ((!compact && showPeak) ? 2 : 0) }
    @State private var measuredContentHeight: CGFloat = 0
    private var preferredSize: CGSize {
        var size = TransferCISizing.openPreferredSize(stripHeight: surfaceState.compactHeight)
        if measuredContentHeight > 0 {
            size.height = measuredContentHeight + max(40, surfaceState.compactHeight)
        }
        return size
    }
    private var sizingSignature: String {
        [openStyle, compact.description, showDirection.description, showDownload.description,
         showUpload.description, showPeak.description, showSession.description,
         showElapsed.description, showGraph.description, indicatorStyle,
         indicatorShowSpeed.description, String(format: "%.2f", indicatorThickness)].joined(separator: "|")
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
        Group {
            if openStyle == "Indicator" {
                VStack(spacing: 8) {
                    TransferActivityIndicator(monitor: monitor, compact: false)
                        .frame(height: 34)
                    if showDirection || showElapsed {
                        HStack {
                            if showDirection { Text(monitor.direction).font(.caption.weight(.semibold)) }
                            Spacer()
                            if showElapsed { Label(elapsed, systemImage: "clock").font(.caption.monospacedDigit()) }
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            } else if openStyle == "Minimal" {
                HStack(spacing: 12) {
                    Image(systemName: monitor.direction.contains("Uploading") && !monitor.direction.contains("Downloading") ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.system(size: 22, weight: .semibold)).foregroundStyle(Color.accentColor)
                    if showDirection {
                        Text(monitor.direction).font(.headline)
                    }
                    if showDownload { compactStat("↓", speed(monitor.downloadBytesPerSecond)) }
                    if showUpload { compactStat("↑", speed(monitor.uploadBytesPerSecond)) }
                    Spacer(minLength: 4)
                    if showElapsed { Text(elapsed).font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
                }
                .padding(.horizontal, 16).padding(.vertical, 13)
            } else {
                VStack(alignment: .leading, spacing: compact ? 9 : 14) {
                    HStack(spacing: 10) {
                        Image(systemName: monitor.direction.contains("Uploading") && !monitor.direction.contains("Downloading") ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .font(.system(size: compact ? 18 : 23, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            if showDirection { Text(monitor.direction).font(compact ? .headline : .title3.bold()) }
                            Text("LIVE TRANSFER").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if showElapsed { Label(elapsed, systemImage: "clock").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
                    }

                    if dashboardStatCount > 0 {
                        HStack(spacing: compact ? 10 : 14) {
                            if showDownload { stat("Download", value: speed(monitor.downloadBytesPerSecond), symbol: "arrow.down") }
                            if showUpload { stat("Upload", value: speed(monitor.uploadBytesPerSecond), symbol: "arrow.up") }
                            if showPeak && !compact {
                                stat("Peak ↓", value: speed(monitor.peakDownloadBytesPerSecond), symbol: "gauge")
                                stat("Peak ↑", value: speed(monitor.peakUploadBytesPerSecond), symbol: "gauge")
                            }
                        }
                    }

                    if showGraph && !compact {
                        TransferHistoryGraph(download: monitor.downloadHistory, upload: monitor.uploadHistory)
                            .frame(height: 56).padding(.vertical, 2)
                    }

                    if showSession && !compact {
                        HStack {
                            Label("↓ \(bytes(monitor.sessionDownloadedBytes))", systemImage: "tray.and.arrow.down")
                            Label("↑ \(bytes(monitor.sessionUploadedBytes))", systemImage: "tray.and.arrow.up")
                            Spacer()
                            Text("Session \(bytes(monitor.sessionDownloadedBytes + monitor.sessionUploadedBytes))")
                        }
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                .padding(compact ? 14 : 18)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: SurfaceContentSizeKey.self, value: proxy.size)
            }
        }
        }
        .onPreferenceChange(SurfaceContentSizeKey.self) { size in
            guard surfaceState.expanded, abs(size.width - surfaceState.dashboardWidth) < 1,
                  size.height > 0, abs(size.height - measuredContentHeight) >= 1 else { return }
            measuredContentHeight = size.height
            updateSizing()
        }
        .onAppear { updateSizing() }
        .onChange(of: sizingSignature) { _ in updateSizing() }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in updateSizing() }
    }

    private func updateSizing() {
        surfaceState.contextMinimumExpandedWidth = TransferCISizing.minimumExpandedWidth(physicalNotchWidth: surfaceState.physicalNotchWidth)
        surfaceState.contextPreferredSize = preferredSize
        surfaceState.contextPreferredCompactWidth = TransferCISizing.closedPreferredWidth(physicalNotchWidth: surfaceState.physicalNotchWidth)
    }

    private func compactStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
        }
    }

    private func stat(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: compact ? 15 : 18, weight: .semibold, design: .rounded)).monospacedDigit()
        }
        .padding(.horizontal, compact ? 10 : 12).padding(.vertical, compact ? 7 : 9)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func speed(_ value: Double) -> String {
        if value >= 1_000_000_000 { return String(format: "%.2f GB/s", value / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1f MB/s", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.0f KB/s", value / 1_000) }
        return String(format: "%.0f B/s", value)
    }

    private func bytes(_ value: Double) -> String {
        if value >= 1_000_000_000 { return String(format: "%.2f GB", value / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1f MB", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.0f KB", value / 1_000) }
        return String(format: "%.0f B", value)
    }
}

private struct TransferClosedContextView: View {
    @ObservedObject var monitor: TransferActivityMonitor
    @ObservedObject var surfaceState: SurfaceState
    @AppStorage("HaloContextTransferClosedStyle") private var closedStyle = "Stats"
    @AppStorage("HaloContextTransferShowDirection") private var showDirection = true
    @AppStorage("HaloContextTransferShowDownload") private var showDownload = true
    @AppStorage("HaloContextTransferShowUpload") private var showUpload = true
    @AppStorage("HaloContextTransferIndicatorStyle") private var indicatorStyle = "Edge Bar"
    @AppStorage("HaloContextTransferIndicatorShowSpeed") private var indicatorShowSpeed = true

    private var sizingSignature: String {
        [closedStyle, showDirection.description, showDownload.description, showUpload.description,
         indicatorStyle, indicatorShowSpeed.description].joined(separator: "|")
    }

    var body: some View {
        Group {
            if closedStyle == "Indicator" {
                TransferActivityIndicator(monitor: monitor, compact: true)
                    .padding(.horizontal, 5)
            } else if closedStyle == "Minimal" {
                HStack(spacing: 6) {
                    Image(systemName: monitor.direction.contains("Uploading") && !monitor.direction.contains("Downloading") ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.accentColor)
                    Text(speed(max(monitor.downloadBytesPerSecond, monitor.uploadBytesPerSecond)))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced)).lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: monitor.direction.contains("Uploading") && !monitor.direction.contains("Downloading") ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.accentColor)
                    if showDirection {
                        Text(shortDirection).font(.system(size: 10, weight: .semibold, design: .rounded)).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if showDownload {
                        Label(speed(monitor.downloadBytesPerSecond), systemImage: "arrow.down")
                            .font(.system(size: 9, weight: .medium, design: .monospaced)).lineLimit(1)
                    }
                    if showUpload {
                        Label(speed(monitor.uploadBytesPerSecond), systemImage: "arrow.up")
                            .font(.system(size: 9, weight: .medium, design: .monospaced)).lineLimit(1)
                    }
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { updateSizing() }
        .onChange(of: sizingSignature) { _ in updateSizing() }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in updateSizing() }
    }

    private func updateSizing() {
        surfaceState.contextMinimumExpandedWidth = TransferCISizing.minimumExpandedWidth(physicalNotchWidth: surfaceState.physicalNotchWidth)
        surfaceState.contextPreferredCompactWidth = TransferCISizing.closedPreferredWidth(physicalNotchWidth: surfaceState.physicalNotchWidth)
        // Prime the next open target while still closed, so opening goes directly to the
        // correct content-driven size instead of opening large and resizing a frame later.
        if !surfaceState.expanded {
            surfaceState.contextPreferredSize = TransferCISizing.openPreferredSize(stripHeight: surfaceState.compactHeight)
        }
    }

    private var shortDirection: String {
        if monitor.direction.contains("Uploading + Downloading") { return "Transfer" }
        if monitor.direction.contains("Uploading") { return "Uploading" }
        if monitor.direction.contains("Downloading") { return "Downloading" }
        return "Transfer"
    }

    private func speed(_ value: Double) -> String {
        if value >= 1_000_000_000 { return String(format: "%.1fG/s", value / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1fM/s", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.0fK/s", value / 1_000) }
        return String(format: "%.0fB/s", value)
    }
}

private struct TransferSurfaceBackground: View {
    @ObservedObject var monitor: TransferActivityMonitor
    @AppStorage("HaloContextTransferBackgroundStyle") private var style = "Gradient"
    @AppStorage("HaloContextTransferBackgroundPrimaryHue") private var primaryHue = 0.58
    @AppStorage("HaloContextTransferBackgroundSecondaryHue") private var secondaryHue = 0.72
    @AppStorage("HaloContextTransferBackgroundSaturation") private var saturation = 0.72
    @AppStorage("HaloContextTransferBackgroundBrightness") private var brightness = 0.30
    @AppStorage("HaloContextTransferBackgroundOpacity") private var opacity = 1.0

    var body: some View {
        let primary = Color(hue: primaryHue, saturation: saturation, brightness: brightness)
        let secondary = Color(hue: secondaryHue, saturation: saturation, brightness: min(1, brightness + 0.12))
        switch style {
        case "Black":
            Color.black.opacity(opacity)
        case "Accent":
            Color.accentColor.opacity(opacity)
        case "Dynamic":
            LinearGradient(
                colors: monitor.direction.contains("Uploading") && !monitor.direction.contains("Downloading")
                    ? [Color.orange.opacity(opacity), primary.opacity(opacity)]
                    : [Color.accentColor.opacity(opacity), secondary.opacity(opacity)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "Glass":
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                primary.opacity(max(0, min(1, opacity * 0.36)))
            }
        default:
            LinearGradient(
                colors: [primary.opacity(opacity), secondary.opacity(opacity)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct SurfaceViewportView: View {
    @ObservedObject var viewport: SurfaceViewport
    let content: SurfaceView
    var body: some View {
        content.frame(width: viewport.size.width, height: viewport.size.height, alignment: .top).clipped()
    }
}


private enum ClipboardContextKind: String {
    case link = "Link"
    case email = "Email"
    case phone = "Phone"
    case file = "File"
    case image = "Image"
    case video = "Video"
    case json = "JSON"
    case address = "Address"
    case text = "Text"

    var symbol: String {
        switch self {
        case .link: return "link"
        case .email: return "envelope.fill"
        case .phone: return "phone.fill"
        case .file: return "doc.fill"
        case .image: return "photo.fill"
        case .video: return "film.fill"
        case .json: return "curlybraces"
        case .address: return "mappin.and.ellipse"
        case .text: return "text.alignleft"
        }
    }

    var accent: Color {
        switch self {
        case .link: return Color(hue: 0.58, saturation: 0.72, brightness: 1.0)
        case .email: return Color(hue: 0.52, saturation: 0.62, brightness: 0.98)
        case .phone: return Color(hue: 0.37, saturation: 0.66, brightness: 0.92)
        case .file: return Color(hue: 0.10, saturation: 0.70, brightness: 1.0)
        case .image: return Color(hue: 0.88, saturation: 0.52, brightness: 1.0)
        case .video: return Color(hue: 0.73, saturation: 0.62, brightness: 1.0)
        case .json: return Color(hue: 0.78, saturation: 0.58, brightness: 1.0)
        case .address: return Color(hue: 0.02, saturation: 0.72, brightness: 1.0)
        case .text: return Color(hue: 0.62, saturation: 0.16, brightness: 0.98)
        }
    }

    var isMedia: Bool { self == .image || self == .video }
}

private struct ClipboardContextAction: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
}

private struct ClipboardHistoryItem: Identifiable {
    let id = UUID()
    let text: String
    let kind: ClipboardContextKind
    let sourceAppName: String
    let copiedAt: Date
    let image: NSImage?
    let fileURL: URL?

    var preview: String {
        if let fileURL { return fileURL.lastPathComponent }
        if kind == .image { return text.isEmpty ? "Copied image" : text }
        let collapsed = text
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return String(collapsed.prefix(90))
    }
}

@MainActor
private final class ClipboardContextMonitor: ObservableObject {
    static let shared = ClipboardContextMonitor()

    @Published private(set) var text = ""
    @Published private(set) var kind: ClipboardContextKind = .text
    @Published private(set) var image: NSImage?
    @Published private(set) var fileURL: URL?
    @Published private(set) var history: [ClipboardHistoryItem] = []
    @Published private(set) var manualPresentation = false
    @Published private(set) var isActive = false
    @Published private(set) var copiedAt: Date?
    @Published private(set) var expiresAt: Date?
    @Published private(set) var remainingFraction = 0.0
    @Published private(set) var remainingSeconds = 0.0
    @Published private(set) var sourceAppName = ""
    @Published private(set) var eventSerial = 0

    private var changeCount = NSPasteboard.general.changeCount
    private var timer: Timer?
    private var interactionActive = false
    private var pasteTargetPID: pid_t?
    private let interval = 0.20

    private init() {
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    var triggerMode: String {
        UserDefaults.standard.string(forKey: "HaloContextClipboardTriggerMode") ?? "Hover to Open"
    }

    var preview: String {
        if let fileURL { return fileURL.lastPathComponent }
        if kind == .image { return text.isEmpty ? "Copied image" : text }
        let collapsed = text
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return String(collapsed.prefix(220))
    }

    var actions: [ClipboardContextAction] {
        var result: [ClipboardContextAction] = []
        switch kind {
        case .link:
            result += [
                .init(id: "open", title: "Open Link", symbol: "safari"),
                .init(id: "search", title: "Search", symbol: "magnifyingglass")
            ]
        case .email:
            result += [
                .init(id: "compose", title: "New Email", symbol: "envelope.badge"),
                .init(id: "search", title: "Search", symbol: "magnifyingglass")
            ]
        case .phone:
            result += [
                .init(id: "facetime", title: "FaceTime", symbol: "video.fill"),
                .init(id: "search", title: "Search", symbol: "magnifyingglass")
            ]
        case .file:
            result += [
                .init(id: "openFile", title: "Open", symbol: "arrow.up.forward.app"),
                .init(id: "reveal", title: "Reveal", symbol: "folder")
            ]
        case .image:
            if fileURL != nil {
                result += [
                    .init(id: "openFile", title: "Open Image", symbol: "photo"),
                    .init(id: "reveal", title: "Reveal", symbol: "folder")
                ]
            } else {
                result.append(.init(id: "saveImage", title: "Save Image", symbol: "square.and.arrow.down"))
            }
        case .video:
            result += [
                .init(id: "openFile", title: "Open Video", symbol: "play.rectangle.fill"),
                .init(id: "reveal", title: "Reveal", symbol: "folder")
            ]
        case .json:
            result += [
                .init(id: "pretty", title: "Pretty Copy", symbol: "curlybraces.square"),
                .init(id: "search", title: "Search", symbol: "magnifyingglass")
            ]
        case .address:
            result += [
                .init(id: "maps", title: "Open in Maps", symbol: "map.fill"),
                .init(id: "search", title: "Search", symbol: "magnifyingglass")
            ]
        case .text:
            if boolDefault("HaloContextClipboardShowSearch", true) {
                result.append(.init(id: "search", title: "Search Web", symbol: "magnifyingglass"))
            }
            if boolDefault("HaloContextClipboardShowTranslate", true) {
                result.append(.init(id: "translate", title: "Translate", symbol: "character.bubble.fill"))
            }
            if boolDefault("HaloContextClipboardShowTransforms", true) {
                result += [
                    .init(id: "trim", title: "Trim + Copy", symbol: "scissors"),
                    .init(id: "upper", title: "UPPERCASE", symbol: "textformat.size.larger"),
                    .init(id: "lower", title: "lowercase", symbol: "textformat.size.smaller")
                ]
            }
        }

        // Paste is deliberately first so it remains visible even when the user
        // limits the number of contextual actions.
        result.insert(.init(id: "paste", title: "Paste", symbol: "doc.on.clipboard.fill"), at: 0)

        let copyTitle: String
        switch kind {
        case .image: copyTitle = "Copy Image"
        case .video: copyTitle = "Copy Video"
        case .file: copyTitle = "Copy Path"
        default: copyTitle = "Copy"
        }
        result.append(.init(id: "copy", title: copyTitle, symbol: "doc.on.doc"))
        let configured = UserDefaults.standard.object(forKey: "HaloContextClipboardMaxActions") == nil
            ? 5
            : UserDefaults.standard.integer(forKey: "HaloContextClipboardMaxActions")
        return Array(result.prefix(min(8, max(2, configured))))
    }

    func setInteractionActive(_ active: Bool) {
        interactionActive = active
    }

    /// Opens Clipboard CI intentionally, independent of whether a fresh copy event occurred.
    /// The most recent in-memory history item is preferred, then the current pasteboard.
    @discardableResult
    func presentHistory() -> Bool {
        rememberPasteTarget()
        manualPresentation = true

        if isActive, !text.isEmpty {
            restartTimeout()
            eventSerial &+= 1
            return true
        }

        if let latest = history.first {
            activateHistory(latest)
            manualPresentation = true
            return true
        }

        capture(NSPasteboard.general)
        manualPresentation = isActive
        return isActive
    }

    func dismiss() {
        deactivate()
    }

    func clearHistory() {
        history.removeAll()
    }

    func activateHistory(_ item: ClipboardHistoryItem) {
        text = item.text
        kind = item.kind
        image = item.image
        fileURL = item.fileURL
        sourceAppName = item.sourceAppName
        copiedAt = item.copiedAt
        restartTimeout()
        eventSerial &+= 1
        isActive = true
    }

    func perform(_ action: ClipboardContextAction) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch action.id {
        case "open":
            if let url = URL(string: trimmed), ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                NSWorkspace.shared.open(url)
            }
        case "openFile":
            if let url = fileURL ?? existingFileURL(from: trimmed) { NSWorkspace.shared.open(url) }
        case "reveal":
            if let url = fileURL ?? existingFileURL(from: trimmed) {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        case "compose":
            var components = URLComponents()
            components.scheme = "mailto"
            components.path = trimmed
            if let url = components.url { NSWorkspace.shared.open(url) }
        case "facetime":
            let allowed = CharacterSet(charactersIn: "+0123456789")
            let clean = trimmed.unicodeScalars.filter { allowed.contains($0) }.map { String($0) }.joined()
            if let url = URL(string: "facetime://\(clean)") { NSWorkspace.shared.open(url) }
        case "maps":
            var components = URLComponents(string: "https://maps.apple.com/")
            components?.queryItems = [URLQueryItem(name: "q", value: trimmed)]
            if let url = components?.url { NSWorkspace.shared.open(url) }
        case "search":
            openSearch(trimmed)
        case "translate":
            openTranslation(trimmed)
        case "paste":
            pasteCurrentPayload()
        case "pretty":
            if let data = trimmed.data(using: .utf8),
               let object = try? JSONSerialization.jsonObject(with: data),
               JSONSerialization.isValidJSONObject(object),
               let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
               let string = String(data: pretty, encoding: .utf8) {
                writeToPasteboard(string)
            }
        case "trim":
            writeToPasteboard(trimmed)
        case "upper":
            writeToPasteboard(text.uppercased())
        case "lower":
            writeToPasteboard(text.lowercased())
        case "saveImage":
            if let image { saveImage(image) }
        case "copy":
            if kind == .image, let image {
                writeImageToPasteboard(image)
            } else if (kind == .video || kind == .image), let fileURL {
                writeFileToPasteboard(fileURL)
            } else {
                writeToPasteboard(text)
            }
        default:
            break
        }

        if boolDefault("HaloContextClipboardAutoCloseAfterAction", true) {
            deactivate()
        }
    }

    private func poll() {
        let board = NSPasteboard.general
        let enabled = boolDefault("HaloContextClipboardEnabled", true)
        guard enabled else {
            changeCount = board.changeCount
            if isActive { deactivate() }
            return
        }

        if board.changeCount != changeCount {
            changeCount = board.changeCount
            capture(board)
        }

        guard isActive, let expiry = expiresAt else { return }
        // Hovering the Clipboard CI pauses its lifetime regardless of trigger mode.
        // This is pointer-driven, not merely "the notch happens to be expanded".
        if interactionActive {
            expiresAt = expiry.addingTimeInterval(interval)
        }
        let timeout = timeoutSeconds
        let remaining = max(0, expiresAt?.timeIntervalSinceNow ?? 0)
        remainingSeconds = remaining
        remainingFraction = min(1, remaining / max(0.1, timeout))
        if remaining <= 0 { deactivate() }
    }

    private func capture(_ board: NSPasteboard) {
        let app = NSWorkspace.shared.frontmostApplication
        let bundleID = app?.bundleIdentifier ?? ""
        let excluded = Set((UserDefaults.standard.string(forKey: "HaloContextClipboardExcludedApps") ?? "")
            .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty })
        guard !excluded.contains(bundleID) else { deactivate(); return }

        let sensitive = [
            "org.nspasteboard.ConcealedType",
            "org.nspasteboard.TransientType",
            "org.nspasteboard.AutoGeneratedType"
        ]
        if sensitive.contains(where: { board.types?.contains(NSPasteboard.PasteboardType($0)) == true }) {
            deactivate()
            return
        }

        var capturedText: String?
        var capturedKind: ClipboardContextKind = .text
        var capturedImage: NSImage?
        var capturedFileURL: URL?

        if let rawFile = board.string(forType: .fileURL),
           let url = URL(string: rawFile), url.isFileURL {
            capturedFileURL = url
            capturedText = url.path
            capturedKind = classifyFile(url)
            if capturedKind == .image { capturedImage = NSImage(contentsOf: url) }
        } else if let pastedImage = readImage(from: board) {
            capturedImage = pastedImage
            capturedKind = .image
            let size = pastedImage.size
            capturedText = "Copied image · \(Int(size.width.rounded()))×\(Int(size.height.rounded()))"
        } else if let raw = board.string(forType: .string),
                  !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  raw.utf8.count <= 250_000 {
            capturedText = raw
            capturedKind = classify(raw)
        }

        guard let capturedText else {
            deactivate()
            return
        }

        text = capturedText
        kind = capturedKind
        image = capturedImage
        fileURL = capturedFileURL
        sourceAppName = app?.localizedName ?? "Mac"
        if app?.bundleIdentifier != Bundle.main.bundleIdentifier {
            pasteTargetPID = app?.processIdentifier
        }
        manualPresentation = false
        copiedAt = Date()
        restartTimeout()
        appendCurrentToHistory()
        eventSerial &+= 1
        isActive = true
    }

    private func classify(_ raw: String) -> ClipboardContextKind {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if FileManager.default.fileExists(atPath: value) { return classifyFile(URL(fileURLWithPath: value)) }

        if let url = URL(string: value),
           ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
           !value.contains(where: { $0.isWhitespace }) {
            return .link
        }

        if value.range(of: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#,
                       options: [.regularExpression, .caseInsensitive]) != nil {
            return .email
        }

        let phoneAllowed = CharacterSet(charactersIn: "+()-. 0123456789")
        let phoneScalars = value.unicodeScalars
        let digitCount = phoneScalars.filter { CharacterSet.decimalDigits.contains($0) }.count
        if digitCount >= 7, digitCount <= 15, phoneScalars.allSatisfy({ phoneAllowed.contains($0) }) {
            return .phone
        }

        if let data = value.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data),
           object is [Any] || object is [String: Any] {
            return .json
        }

        let nsLength = (value as NSString).length
        if nsLength >= 6,
           let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue),
           let match = detector.firstMatch(in: value, range: NSRange(location: 0, length: nsLength)),
           match.resultType == .address,
           match.range.location == 0, match.range.length == nsLength {
            return .address
        }
        return .text
    }

    private func classifyFile(_ url: URL) -> ClipboardContextKind {
        if let type = UTType(filenameExtension: url.pathExtension) {
            if type.conforms(to: .image) { return .image }
            if type.conforms(to: .movie) { return .video }
        }
        return .file
    }

    private func readImage(from board: NSPasteboard) -> NSImage? {
        let types: [NSPasteboard.PasteboardType] = [
            NSPasteboard.PasteboardType("public.png"),
            NSPasteboard.PasteboardType("public.jpeg"),
            .tiff
        ]
        for type in types {
            if let data = board.data(forType: type), data.count <= 30_000_000,
               let image = NSImage(data: data) {
                return image
            }
        }
        return nil
    }

    private func appendCurrentToHistory() {
        guard boolDefault("HaloContextClipboardHistoryEnabled", true) else { return }
        let limit = historyLimit
        let item = ClipboardHistoryItem(
            text: text,
            kind: kind,
            sourceAppName: sourceAppName,
            copiedAt: copiedAt ?? Date(),
            image: image,
            fileURL: fileURL
        )
        history.insert(item, at: 0)
        if history.count > limit { history.removeLast(history.count - limit) }
    }

    private var historyLimit: Int {
        let defaults = UserDefaults.standard
        let configured = defaults.object(forKey: "HaloContextClipboardHistoryLimit") == nil
            ? 8 : defaults.integer(forKey: "HaloContextClipboardHistoryLimit")
        return min(20, max(2, configured))
    }

    private func restartTimeout() {
        let timeout = timeoutSeconds
        let now = Date()
        expiresAt = now.addingTimeInterval(timeout)
        remainingSeconds = timeout
        remainingFraction = 1
    }

    private var timeoutSeconds: Double {
        let defaults = UserDefaults.standard
        let value = defaults.object(forKey: "HaloContextClipboardTimeoutSeconds") == nil
            ? 8.0
            : defaults.double(forKey: "HaloContextClipboardTimeoutSeconds")
        return min(120, max(1, value))
    }

    private func boolDefault(_ key: String, _ defaultValue: Bool) -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }

    private func deactivate() {
        manualPresentation = false
        isActive = false
        expiresAt = nil
        remainingFraction = 0
        remainingSeconds = 0
        interactionActive = false
    }

    private func existingFileURL(from value: String) -> URL? {
        guard FileManager.default.fileExists(atPath: value) else { return nil }
        return URL(fileURLWithPath: value)
    }

    private func writeToPasteboard(_ value: String) {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(value, forType: .string)
        changeCount = board.changeCount
    }

    private func writeImageToPasteboard(_ image: NSImage) {
        let board = NSPasteboard.general
        board.clearContents()
        board.writeObjects([image])
        changeCount = board.changeCount
    }

    private func writeFileToPasteboard(_ url: URL) {
        let board = NSPasteboard.general
        board.clearContents()
        board.writeObjects([url as NSURL])
        changeCount = board.changeCount
    }

    private func saveImage(_ image: NSImage) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "Clipboard Image.png"
        guard panel.runModal() == .OK, let url = panel.url,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            // Write directly to the Powerbox-authorized destination. An atomic write can
            // require creating a sibling temporary file that the sandbox did not grant.
            try data.write(to: url)
        } catch {
            NSSound.beep()
        }
    }

    private func rememberPasteTarget() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        pasteTargetPID = app.processIdentifier
    }

    private func writeCurrentPayloadToPasteboard() {
        if let fileURL, kind == .file || kind == .video || kind == .image {
            writeFileToPasteboard(fileURL)
        } else if kind == .image, let image {
            writeImageToPasteboard(image)
        } else {
            writeToPasteboard(text)
        }
    }

    private func pasteCurrentPayload() {
        writeCurrentPayloadToPasteboard()
        guard let pid = pasteTargetPID,
              let target = NSRunningApplication(processIdentifier: pid) else { return }

        // Posting Command-V is the only general way to paste into an arbitrary macOS app.
        // Request this capability lazily: users who never use direct Paste never see a prompt.
        guard CGPreflightPostEventAccess() || CGRequestPostEventAccess() else {
            NSSound.beep()
            return
        }

        target.activate(options: [.activateIgnoringOtherApps])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            let source = CGEventSource(stateID: .combinedSessionState)
            let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(9), keyDown: true)
            let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(9), keyDown: false)
            down?.flags = .maskCommand
            up?.flags = .maskCommand
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }

    private func openTranslation(_ value: String) {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        let defaults = UserDefaults.standard
        let provider = defaults.string(forKey: "HaloContextClipboardTranslateProvider") ?? "Google Translate"
        let target = defaults.string(forKey: "HaloContextClipboardTranslateTarget") ?? "en"

        if provider == "DeepL" {
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-._~")
            let escaped = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            if let url = URL(string: "https://www.deepl.com/translator#auto/\(target)/\(escaped)") {
                NSWorkspace.shared.open(url)
            }
            return
        }

        var components = URLComponents(string: "https://translate.google.com/")
        components?.queryItems = [
            URLQueryItem(name: "sl", value: "auto"),
            URLQueryItem(name: "tl", value: target),
            URLQueryItem(name: "text", value: value),
            URLQueryItem(name: "op", value: "translate")
        ]
        if let url = components?.url { NSWorkspace.shared.open(url) }
    }

    private func openSearch(_ query: String) {
        let engine = UserDefaults.standard.string(forKey: "HaloContextClipboardSearchEngine") ?? "Google"
        let base: String
        switch engine {
        case "DuckDuckGo": base = "https://duckduckgo.com/"
        case "Bing": base = "https://www.bing.com/search"
        default: base = "https://www.google.com/search"
        }
        var components = URLComponents(string: base)
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        if let url = components?.url { NSWorkspace.shared.open(url) }
    }
}

private enum ClipboardCISizing {
    static func minimumExpandedWidth(physicalNotchWidth: CGFloat) -> CGFloat {
        max(360, physicalNotchWidth > 0 ? physicalNotchWidth + 120 : 360)
    }

    @MainActor
    static func closedPreferredWidth(monitor: ClipboardContextMonitor, physicalNotchWidth: CGFloat) -> CGFloat {
        let defaults = UserDefaults.standard
        let showPreview = defaults.object(forKey: "HaloContextClipboardShowClosedPreview") == nil
            ? true : defaults.bool(forKey: "HaloContextClipboardShowClosedPreview")
        let showType = defaults.object(forKey: "HaloContextClipboardShowType") == nil
            ? true : defaults.bool(forKey: "HaloContextClipboardShowType")
        func width(_ text: String, weight: NSFont.Weight) -> CGFloat {
            let base = NSFont.systemFont(ofSize: 9.5, weight: weight)
            let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 9.5) } ?? base
            return ceil((text as NSString).size(withAttributes: [.font: font]).width)
        }
        let leading = CGFloat(18) + (showType ? 8 + width(monitor.kind.rawValue, weight: .semibold) : 0)
        let preview = showPreview ? min(280, width(monitor.preview, weight: .medium)) + 8 : 0
        let trailing = preview + 42 // countdown badge, including spacing
        if physicalNotchWidth > 0 {
            return physicalNotchWidth + 2 * (max(leading, trailing) + 40)
        }
        return max(156, leading + trailing + 48)
    }

    static func openPreferredSize(actionCount: Int? = nil, historyCount: Int = 0, kind: ClipboardContextKind = .text) -> CGSize {
        let defaults = UserDefaults.standard
        let compact = defaults.bool(forKey: "HaloContextClipboardCompact")
        let lines = defaults.object(forKey: "HaloContextClipboardPreviewLines") == nil
            ? 3 : min(6, max(1, defaults.integer(forKey: "HaloContextClipboardPreviewLines")))
        let historyEnabled = defaults.object(forKey: "HaloContextClipboardHistoryEnabled") == nil
            ? true : defaults.bool(forKey: "HaloContextClipboardHistoryEnabled")
        let showHistory = defaults.object(forKey: "HaloContextClipboardShowHistory") == nil
            ? true : defaults.bool(forKey: "HaloContextClipboardShowHistory")
        let count = max(1, actionCount ?? 5)
        let columns = compact ? min(3, count) : min(4, count)
        let rows = Int(ceil(Double(count) / Double(max(1, columns))))
        let width: CGFloat = compact ? max(410, CGFloat(columns) * 126 + 48) : max(520, CGFloat(columns) * 138 + 54)
        let baseHeight: CGFloat = compact ? 116 : 144
        let previewHeight: CGFloat
        switch kind {
        case .image: previewHeight = compact ? 94 : 132
        case .video: previewHeight = compact ? 62 : 78
        default: previewHeight = CGFloat(lines) * (compact ? 13 : 16)
        }
        let actionHeight = CGFloat(rows) * (compact ? 38 : 44)
        let historyHeight: CGFloat = historyEnabled && showHistory && historyCount > 1 ? (compact ? 62 : 74) : 0
        return CGSize(width: min(780, width), height: min(520, baseHeight + previewHeight + actionHeight + historyHeight))
    }
}

private struct ClipboardSurfaceBackground: View {
    @ObservedObject var monitor: ClipboardContextMonitor
    @AppStorage("HaloContextClipboardBackgroundStyle") private var style = "Adaptive"

    var body: some View {
        Group {
            switch style {
            case "Glass":
                Rectangle().fill(.ultraThinMaterial).overlay(Color.black.opacity(0.48))
            case "Black":
                Color.black
            default:
                LinearGradient(
                    colors: [monitor.kind.accent.opacity(0.28), Color.black.opacity(0.98), Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }
}

private struct ClipboardClosedContextView: View {
    @ObservedObject var monitor: ClipboardContextMonitor
    @ObservedObject var surfaceState: SurfaceState
    @AppStorage("HaloContextClipboardShowClosedPreview") private var showPreview = true
    @AppStorage("HaloContextClipboardShowType") private var showType = true

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: monitor.kind.symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(monitor.kind.accent)
                    .frame(width: 18, height: 18)
                    .background(monitor.kind.accent.opacity(0.12), in: Circle())
                if showType {
                    Text(monitor.kind.rawValue)
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
            .frame(width: surfaceState.closedOcclusion == nil ? nil :
                max(0, (surfaceState.compactWidth - surfaceState.physicalNotchWidth) / 2 - 40), alignment: .leading)
            if surfaceState.closedOcclusion != nil {
                Color.clear.frame(width: surfaceState.physicalNotchWidth + 16)
            }
            if showPreview {
                Text(monitor.preview)
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("\(max(0, Int(ceil(monitor.remainingSeconds))))s")
                .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.46))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.white.opacity(0.055), in: Capsule())
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { updateSizing() }
        .onChange(of: monitor.eventSerial) { _ in updateSizing() }
        .onChange(of: showPreview) { _ in updateSizing() }
        .onChange(of: showType) { _ in updateSizing() }
    }

    private func updateSizing() {
        surfaceState.contextPreferredCompactHeight = max(32, surfaceState.physicalNotchHeight)
        surfaceState.contextMinimumExpandedWidth = ClipboardCISizing.minimumExpandedWidth(physicalNotchWidth: surfaceState.physicalNotchWidth)
        surfaceState.contextPreferredCompactWidth = ClipboardCISizing.closedPreferredWidth(monitor: monitor, physicalNotchWidth: surfaceState.closedOcclusion == nil ? 0 : surfaceState.physicalNotchWidth)
        if !surfaceState.expanded {
            surfaceState.contextPreferredSize = ClipboardCISizing.openPreferredSize(
                actionCount: monitor.actions.count,
                historyCount: monitor.history.count,
                kind: monitor.kind
            )
        }
    }
}

private struct SurfaceContentSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

private struct ClipboardContextView: View {
    @ObservedObject var monitor: ClipboardContextMonitor
    @ObservedObject var surfaceState: SurfaceState
    @AppStorage("HaloContextClipboardCompact") private var compact = false
    @AppStorage("HaloContextClipboardPreviewLines") private var previewLines = 3
    @AppStorage("HaloContextClipboardShowType") private var showType = true
    @AppStorage("HaloContextClipboardShowSource") private var showSource = true
    @AppStorage("HaloContextClipboardShowCharacterCount") private var showCharacterCount = true
    @AppStorage("HaloContextClipboardMaxActions") private var maxActions = 5
    @AppStorage("HaloContextClipboardHistoryEnabled") private var historyEnabled = true
    @AppStorage("HaloContextClipboardShowHistory") private var showHistory = true
    @AppStorage("HaloContextClipboardHistoryLimit") private var historyLimit = 8

    @State private var measuredContentHeight: CGFloat = 0

    private var sizingSignature: String {
        [compact.description, String(previewLines), showType.description, showSource.description,
         showCharacterCount.description, String(maxActions), String(monitor.actions.count),
         historyEnabled.description, showHistory.description, String(historyLimit),
         String(monitor.history.count), monitor.kind.rawValue].joined(separator: "|")
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
        VStack(alignment: .leading, spacing: compact ? 9 : 12) {
            HStack(spacing: 9) {
                Image(systemName: monitor.kind.symbol)
                    .font(.system(size: compact ? 12 : 14, weight: .semibold))
                    .foregroundStyle(monitor.kind.accent)
                    .frame(width: compact ? 25 : 30, height: compact ? 25 : 30)
                    .background(monitor.kind.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    if showType { Text(monitor.kind.rawValue).font(.system(size: compact ? 11 : 12.5, weight: .semibold, design: .rounded)) }
                    if showSource, !monitor.sourceAppName.isEmpty {
                        Text("Copied from \(monitor.sourceAppName)")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.42))
                    }
                }
                Spacer()
                Text("\(max(0, Int(ceil(monitor.remainingSeconds))))s")
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.40))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.055), in: Capsule())
                    .help("Time remaining — pauses while the pointer is over Clipboard CI")
                Button { monitor.dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .background(.white.opacity(0.055), in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.62))
                .help("Dismiss Clipboard CI")
            }

            payloadPreview

            let actions = monitor.actions
            LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 104 : 118, maximum: 180), spacing: 7)], spacing: 7) {
                ForEach(actions) { action in
                    Button { monitor.perform(action) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: action.symbol).font(.system(size: 10, weight: .semibold))
                            Text(action.title).font(.system(size: 9.5, weight: .semibold, design: .rounded)).lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 9)
                        .frame(height: compact ? 30 : 34)
                        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(.white.opacity(0.055), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.78))
                }
            }

            if historyEnabled && showHistory && monitor.history.count > 1 {
                historyStrip
            }

            footer
        }
        .padding(.horizontal, compact ? 13 : 16)
        .padding(.vertical, compact ? 11 : 14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: SurfaceContentSizeKey.self, value: proxy.size)
            }
        }
        }
        .onPreferenceChange(SurfaceContentSizeKey.self) { size in
            // Ignore intermediate opening widths: reflow must not restart the window
            // animation on every frame. dashboardWidth is the final clamped target.
            guard surfaceState.expanded, abs(size.width - surfaceState.dashboardWidth) < 1,
                  size.height > 0, abs(size.height - measuredContentHeight) >= 1 else { return }
            measuredContentHeight = size.height
            updateSizing()
        }
        .onAppear { updateSizing() }
        .onChange(of: monitor.eventSerial) { _ in updateSizing() }
        .onChange(of: sizingSignature) { _ in updateSizing() }
    }

    @ViewBuilder private var payloadPreview: some View {
        if monitor.kind == .image, let image = monitor.image {
            ZStack(alignment: .bottomLeading) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: compact ? 92 : 128)
                Text(monitor.preview)
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.58), in: Capsule())
                    .padding(7)
            }
            .frame(maxWidth: .infinity, minHeight: compact ? 82 : 112, maxHeight: compact ? 94 : 132)
            .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        } else if monitor.kind == .video {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(monitor.kind.accent.opacity(0.12))
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(monitor.kind.accent)
                }
                .frame(width: compact ? 46 : 58, height: compact ? 46 : 58)
                VStack(alignment: .leading, spacing: 4) {
                    Text(monitor.fileURL?.lastPathComponent ?? "Copied video")
                        .font(.system(size: compact ? 10.5 : 12, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    if let ext = monitor.fileURL?.pathExtension, !ext.isEmpty {
                        Text(ext.uppercased() + " video")
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.42))
                    }
                }
                Spacer()
            }
            .padding(compact ? 8 : 10)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            Text(monitor.text)
                .font(.system(size: compact ? 10.5 : 12, weight: .medium, design: monitor.kind == .json ? .monospaced : .rounded))
                .foregroundStyle(.white.opacity(0.90))
                .lineLimit(min(6, max(1, previewLines)))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, compact ? 9 : 11)
                .padding(.vertical, compact ? 7 : 9)
                .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.white.opacity(0.055), lineWidth: 0.5))
        }
    }

    private var historyStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("History", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                Text("\(monitor.history.count)")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.30))
                Spacer()
                Button("Clear") { monitor.clearHistory() }
                    .buttonStyle(.plain)
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(monitor.history.prefix(min(20, max(2, historyLimit))))) { item in
                        Button { monitor.activateHistory(item) } label: {
                            HStack(spacing: 7) {
                                if item.kind == .image, let image = item.image {
                                    Image(nsImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 28, height: 28)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                } else {
                                    Image(systemName: item.kind.symbol)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(item.kind.accent)
                                        .frame(width: 28, height: 28)
                                        .background(item.kind.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.preview)
                                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.72))
                                        .lineLimit(1)
                                    Text(item.kind.rawValue)
                                        .font(.system(size: 7.5, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.32))
                                }
                            }
                            .padding(.horizontal, 7)
                            .frame(width: compact ? 126 : 148, height: compact ? 38 : 44, alignment: .leading)
                            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder private var footer: some View {
        if showCharacterCount {
            HStack(spacing: 8) {
                if monitor.kind == .image, let image = monitor.image {
                    Text("\(Int(image.size.width.rounded())) × \(Int(image.size.height.rounded()))")
                    Text("•")
                    Text("image")
                } else if monitor.kind == .video {
                    Text(monitor.fileURL?.pathExtension.uppercased() ?? "VIDEO")
                    Text("•")
                    Text("media file")
                } else {
                    Text("\(monitor.text.count) characters")
                    Text("•")
                    Text("\(monitor.text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count) words")
                }
                Spacer()
                Text(monitor.triggerMode == "Pop Up" ? "Auto popup" : "Hover to open")
            }
            .font(.system(size: 8.5, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.32))
        }
    }

    private func updateSizing() {
        surfaceState.contextPreferredCompactHeight = max(32, surfaceState.physicalNotchHeight)
        surfaceState.contextMinimumExpandedWidth = ClipboardCISizing.minimumExpandedWidth(physicalNotchWidth: surfaceState.physicalNotchWidth)
        surfaceState.contextPreferredCompactWidth = ClipboardCISizing.closedPreferredWidth(monitor: monitor, physicalNotchWidth: surfaceState.closedOcclusion == nil ? 0 : surfaceState.physicalNotchWidth)
        var size = ClipboardCISizing.openPreferredSize(
            actionCount: monitor.actions.count,
            historyCount: monitor.history.count,
            kind: monitor.kind
        )
        if measuredContentHeight > 0 {
            // WindowManager expects the whole surface, including the toggle strip.
            size.height = measuredContentHeight + max(40, surfaceState.compactHeight)
        }
        surfaceState.contextPreferredSize = size
    }
}

private enum ActiveContextInterface: String {
    case drop, teleprompter, transfer, clipboard, custom, integration, music, bluetooth, retro, liveActivity
}

private struct SurfaceContextCandidate {
    let interface: ActiveContextInterface
    let arbitration: CIArbitrationCandidate
}


private enum SurfaceDirectGeometryHandle {
    case move
    case topLeft, top, topRight
    case left, right
    case bottomLeft, bottom, bottomRight
    case cornerRadius

    var movesLeft: Bool { self == .left || self == .topLeft || self == .bottomLeft }
    var movesRight: Bool { self == .right || self == .topRight || self == .bottomRight }
    var movesTop: Bool { self == .top || self == .topLeft || self == .topRight }
    var movesBottom: Bool { self == .bottom || self == .bottomLeft || self == .bottomRight }

    var cursor: NSCursor {
        switch self {
        case .move: return .openHand
        case .left, .right: return .resizeLeftRight
        case .top, .bottom: return .resizeUpDown
        case .topLeft, .bottomRight: return .crosshair
        case .topRight, .bottomLeft: return .crosshair
        case .cornerRadius: return .crosshair
        }
    }
}

@MainActor
struct SurfaceGeometryEditorPanelView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore
    @ObservedObject var state: SurfaceState
    @ObservedObject var session: SurfaceGeometryEditingSession

    @State private var activeHandle: SurfaceDirectGeometryHandle?
    @State private var hoveredHandle: SurfaceDirectGeometryHandle?
    @State private var dragStartMouse: CGPoint?
    @State private var dragStartFrame: CGRect?
    @State private var dragStartSnapshot: SurfaceGeometryEditSnapshot?

    private let metrics = SurfaceGeometryEditorChromeMetrics.self

    private var persistedSnapshot: SurfaceGeometryEditSnapshot {
        SurfaceGeometryEditSnapshot.capture(
            theme: store.configuration.theme,
            appearance: workspace.settings.layout.appearance
        )
    }

    private var displayedSnapshot: SurfaceGeometryEditSnapshot {
        session.previewSnapshot ?? persistedSnapshot
    }

    private var editingScreen: NSScreen? {
        if let displayID = session.displayID,
           let screen = NSScreen.screens.first(where: { WindowManager.displayID($0) == displayID }) {
            return screen
        }
        return NSScreen.screens.first(where: { $0.frame.equalTo(state.screenFrame) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    var body: some View {
        GeometryReader { proxy in
            let notchWidth = min(max(1, state.viewport.size.width), max(1, proxy.size.width))
            let notchHeight = min(max(1, state.viewport.size.height), max(1, proxy.size.height - metrics.top - metrics.bottom))
            let minX = (proxy.size.width - notchWidth) / 2
            let maxX = minX + notchWidth
            let minY = metrics.top
            let maxY = minY + notchHeight
            let midX = (minX + maxX) / 2
            let midY = (minY + maxY) / 2
            let o = metrics.handleOffset

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        Color.accentColor.opacity(activeHandle == nil ? 0.62 : 0.92),
                        style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])
                    )
                    .frame(width: max(1, maxX - minX + 8), height: max(1, maxY - minY + 8))
                    .position(x: midX, y: midY)
                    .allowsHitTesting(false)

                resizeHandle(.topLeft).position(x: minX - o, y: editorTouchesTop ? minY + 12 : minY - o)
                if !editorTouchesTop {
                    resizeHandle(.top).position(x: midX, y: minY - o)
                }
                resizeHandle(.topRight).position(x: maxX + o, y: editorTouchesTop ? minY + 12 : minY - o)
                resizeHandle(.left).position(x: minX - o, y: midY)
                resizeHandle(.right).position(x: maxX + o, y: midY)
                resizeHandle(.bottomLeft).position(x: minX - o, y: maxY + o)
                resizeHandle(.bottom).position(x: midX, y: maxY + o)
                resizeHandle(.bottomRight).position(x: maxX + o, y: maxY + o)

                radiusHandle
                    .position(x: maxX + 15, y: minY + 18)

                moveBar
                    .position(x: midX, y: maxY + 34)

            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Direct notch geometry editor")
    }

    private var editorTouchesTop: Bool {
        guard let screen = editingScreen else { return false }
        return geometryFrame(for: displayedSnapshot, on: screen).maxY >= screen.frame.maxY - 4
    }

    private var sizeLabel: String {
        let snapshot = displayedSnapshot
        if session.target == .closed {
            return "\(Int(snapshot.compactWidth.rounded())) × \(Int(snapshot.compactHeight.rounded())) · r\(Int(snapshot.cornerRadius.rounded()))"
        }
        let totalHeight = snapshot.expandedHeight + max(40, snapshot.compactHeight)
        return "\(Int(snapshot.expandedWidth.rounded())) × \(Int(totalHeight.rounded())) · r\(Int(snapshot.cornerRadius.rounded()))"
    }

    private var moveBar: some View {
        HStack(spacing: 7) {
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 10, weight: .bold))
            Text("Move")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
            Text(sizeLabel)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.62))
        }
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, 11)
        .frame(height: 26)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.accentColor.opacity(activeHandle == .move ? 0.95 : 0.45), lineWidth: 1))
        .shadow(radius: activeHandle == .move ? 8 : 4, y: 2)
        .scaleEffect(activeHandle == .move ? 1.03 : hoveredHandle == .move ? 1.02 : 1)
        .contentShape(Capsule())
        .onHover { hovering in
            hoveredHandle = hovering ? .move : (hoveredHandle == .move ? nil : hoveredHandle)
            if hovering { NSCursor.openHand.set() } else if activeHandle == nil { NSCursor.arrow.set() }
        }
        .gesture(dragGesture(.move))
        .animation(.interactiveSpring(response: 0.16, dampingFraction: 0.84), value: activeHandle)
        .animation(.easeOut(duration: 0.10), value: hoveredHandle)
        .accessibilityLabel("Move notch")
    }

    private func resizeHandle(_ handle: SurfaceDirectGeometryHandle) -> some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.58))
                .frame(width: 18, height: 18)
            Circle()
                .fill(.white)
                .frame(width: activeHandle == handle ? 9 : 8, height: activeHandle == handle ? 9 : 8)
                .overlay(Circle().stroke(Color.accentColor, lineWidth: activeHandle == handle ? 2.5 : 2))
        }
        .frame(width: 28, height: 28)
        .contentShape(Circle())
        .scaleEffect(activeHandle == handle ? 1.14 : hoveredHandle == handle ? 1.08 : 1)
        .shadow(radius: activeHandle == handle ? 6 : 3)
        .onHover { hovering in
            hoveredHandle = hovering ? handle : (hoveredHandle == handle ? nil : hoveredHandle)
            if hovering { handle.cursor.set() } else if activeHandle == nil { NSCursor.arrow.set() }
        }
        .gesture(dragGesture(handle))
        .animation(.interactiveSpring(response: 0.14, dampingFraction: 0.82), value: activeHandle)
        .animation(.easeOut(duration: 0.10), value: hoveredHandle)
        .accessibilityLabel("Resize notch")
    }

    private var radiusHandle: some View {
        ZStack {
            Circle().fill(.black.opacity(0.62))
            Image(systemName: "circle.dotted")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: 24, height: 24)
        .overlay(Circle().stroke(.white.opacity(0.76), lineWidth: 1))
        .shadow(radius: activeHandle == .cornerRadius ? 7 : 3)
        .scaleEffect(activeHandle == .cornerRadius ? 1.12 : hoveredHandle == .cornerRadius ? 1.07 : 1)
        .contentShape(Circle())
        .onHover { hovering in
            hoveredHandle = hovering ? .cornerRadius : (hoveredHandle == .cornerRadius ? nil : hoveredHandle)
            if hovering { NSCursor.crosshair.set() } else if activeHandle == nil { NSCursor.arrow.set() }
        }
        .gesture(dragGesture(.cornerRadius))
        .animation(.interactiveSpring(response: 0.14, dampingFraction: 0.82), value: activeHandle)
        .accessibilityLabel("Adjust corner radius")
    }

    private func dragGesture(_ handle: SurfaceDirectGeometryHandle) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in updateDrag(handle) }
            .onEnded { _ in finishDrag() }
    }

    private func beginDrag(_ handle: SurfaceDirectGeometryHandle) {
        guard activeHandle == nil, let screen = editingScreen else { return }
        let snapshot = displayedSnapshot
        activeHandle = handle
        dragStartMouse = NSEvent.mouseLocation
        dragStartSnapshot = snapshot
        dragStartFrame = geometryFrame(for: snapshot, on: screen)
        session.beginTransaction(snapshot)
        handle.cursor.set()
    }

    private func updateDrag(_ handle: SurfaceDirectGeometryHandle) {
        if activeHandle == nil { beginDrag(handle) }
        guard activeHandle == handle,
              let startMouse = dragStartMouse,
              let startFrame = dragStartFrame,
              let startSnapshot = dragStartSnapshot,
              let screen = editingScreen else { return }

        let mouse = NSEvent.mouseLocation
        let delta = CGSize(width: mouse.x - startMouse.x, height: mouse.y - startMouse.y)

        if handle == .cornerRadius {
            var next = startSnapshot
            next.cornerRadius = min(48, max(0, startSnapshot.cornerRadius - Double(delta.width + delta.height) * 0.5))
            session.previewSnapshot = next
            return
        }

        var desired = startFrame
        if handle == .move {
            desired.origin.x += delta.width
            desired.origin.y += delta.height
        } else {
            desired = resizedFrame(startFrame, handle: handle, delta: delta, snapshot: startSnapshot, screen: screen)
        }

        desired = constrainedToScreen(desired, screen: screen)
        session.previewSnapshot = snapshot(startingFrom: startSnapshot, matching: desired, on: screen)
    }

    private func finishDrag() {
        guard activeHandle != nil else { return }
        let finalSnapshot = session.previewSnapshot ?? displayedSnapshot
        session.commitTransaction(finalSnapshot)
        applyPersisted(finalSnapshot)
        session.previewSnapshot = nil
        activeHandle = nil
        dragStartMouse = nil
        dragStartFrame = nil
        dragStartSnapshot = nil
        NSCursor.arrow.set()
    }

    private func applyPersisted(_ snapshot: SurfaceGeometryEditSnapshot) {
        var theme = store.configuration.theme
        var appearance = workspace.settings.layout.appearance
        theme.width = snapshot.expandedWidth
        theme.cornerRadius = snapshot.cornerRadius
        appearance.compactWidth = snapshot.compactWidth
        appearance.surface.compactHeight = snapshot.compactHeight
        appearance.expandedHeight = snapshot.expandedHeight
        appearance.surface.offsets = snapshot.offsets
        store.configuration.theme = theme
        workspace.settings.layout.appearance = appearance
    }

    private func geometryFrame(for snapshot: SurfaceGeometryEditSnapshot, on screen: NSScreen) -> CGRect {
        var theme = store.configuration.theme
        var appearance = workspace.settings.layout.appearance
        theme.width = snapshot.expandedWidth
        theme.cornerRadius = snapshot.cornerRadius
        appearance.compactWidth = snapshot.compactWidth
        appearance.surface.compactHeight = snapshot.compactHeight
        appearance.expandedHeight = snapshot.expandedHeight
        appearance.surface.offsets = snapshot.offsets
        if store.configuration.simulateNotch && theme.style == .notch { theme.style = .simulated }
        return WindowManager.geometry(screen: screen, theme: theme, appearance: appearance)
            .frame(expanded: session.target.expanded)
    }

    private func snapshot(
        startingFrom start: SurfaceGeometryEditSnapshot,
        matching desired: CGRect,
        on screen: NSScreen
    ) -> SurfaceGeometryEditSnapshot {
        var next = start
        if session.target == .closed {
            next.compactWidth = min(640, max(16, Double(desired.width)))
            next.compactHeight = min(100, max(16, Double(desired.height)))
        } else {
            next.expandedWidth = min(1200, max(340, Double(desired.width)))
            let closedStrip = max(40, next.compactHeight)
            next.expandedHeight = min(1100, max(280, Double(desired.height) - closedStrip))
        }

        var zeroed = next
        if session.target == .closed {
            zeroed.offsets.closedX = 0
            zeroed.offsets.closedY = 0
        } else {
            zeroed.offsets.openedX = 0
            zeroed.offsets.openedY = 0
        }

        let base = geometryFrame(for: zeroed, on: screen)
        let offsetX = min(1000, max(-1000, Double(desired.minX - base.minX)))
        let offsetY = min(1000, max(-1000, Double(base.minY - desired.minY)))
        if session.target == .closed {
            next.offsets.closedX = offsetX
            next.offsets.closedY = offsetY
        } else {
            next.offsets.openedX = offsetX
            next.offsets.openedY = offsetY
        }
        return next
    }

    private func resizedFrame(
        _ start: CGRect,
        handle: SurfaceDirectGeometryHandle,
        delta: CGSize,
        snapshot: SurfaceGeometryEditSnapshot,
        screen: NSScreen
    ) -> CGRect {
        var minX = start.minX, maxX = start.maxX, minY = start.minY, maxY = start.maxY
        if handle.movesLeft { minX += delta.width }
        if handle.movesRight { maxX += delta.width }
        if handle.movesTop { maxY += delta.height }
        if handle.movesBottom { minY += delta.height }

        let screenWidth = max(16, screen.frame.width - 8)
        let screenHeight = max(16, screen.frame.height - 8)
        let minWidth: CGFloat = session.target == .closed ? 16 : 340
        let maxWidth: CGFloat = min(session.target == .closed ? 640 : 1200, screenWidth)
        let closedStrip = max(40, snapshot.compactHeight)
        let minHeight: CGFloat = session.target == .closed ? 16 : CGFloat(280 + closedStrip)
        let maxHeight: CGFloat = min(session.target == .closed ? 100 : CGFloat(1100 + closedStrip), screenHeight)

        let width = maxX - minX
        if width < minWidth {
            if handle.movesLeft { minX = maxX - minWidth } else { maxX = minX + minWidth }
        } else if width > maxWidth {
            if handle.movesLeft { minX = maxX - maxWidth } else { maxX = minX + maxWidth }
        }

        let height = maxY - minY
        if height < minHeight {
            if handle.movesBottom { minY = maxY - minHeight } else { maxY = minY + minHeight }
        } else if height > maxHeight {
            if handle.movesBottom { minY = maxY - maxHeight } else { maxY = minY + maxHeight }
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func constrainedToScreen(_ frame: CGRect, screen: NSScreen) -> CGRect {
        let bounds = screen.frame.insetBy(dx: 4, dy: 4)
        var result = frame
        if result.width > bounds.width { result.size.width = bounds.width }
        if result.height > bounds.height { result.size.height = bounds.height }
        if result.minX < bounds.minX { result.origin.x = bounds.minX }
        if result.maxX > bounds.maxX { result.origin.x = bounds.maxX - result.width }
        if result.minY < bounds.minY { result.origin.y = bounds.minY }
        if result.maxY > bounds.maxY { result.origin.y = bounds.maxY - result.height }
        return result
    }
}

private enum RetainedClosedNotchGeometry {
    static func horizontalBias(width: CGFloat, occlusion: CGRect?) -> CGFloat {
        guard width > 0, let occlusion else { return 0 }
        return width / 2 - occlusion.midX
    }

    static func centeredRequiredWidth(width: CGFloat, occlusion: CGRect?) -> CGFloat {
        max(0, width) + abs(horizontalBias(width: width, occlusion: occlusion)) * 2
    }
}

struct SurfaceView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var state: SurfaceState
    @ObservedObject var workspace: WorkspaceStore
    @ObservedObject private var bluetooth = BluetoothStateService.shared
    @ObservedObject private var transfer = TransferActivityMonitor.shared
    @ObservedObject private var clipboardCI = ClipboardContextMonitor.shared
    @ObservedObject private var customCI = HaloCustomCIRuntimeStore.shared
    @ObservedObject private var integrationCI = IntegrationCIRuntime.shared
    @ObservedObject private var commercialSurfaceGate = HaloCommercialSurfaceGate.shared
    @State private var clipboardOpenedNotch = false
    @State private var integrationAutoOpeningSurface = false
    @State private var teleprompterActive = false
    @State private var visualWorkspaceSurfacePresented = false
    @AppStorage("HaloContextTeleprompterEnabled") private var teleprompterCIEnabled = true
    @AppStorage("HaloContextTeleprompterPriority") private var teleprompterPriority = 70.0
    @AppStorage("HaloContextTransferEnabled") private var transferCIEnabled = true
    @AppStorage("HaloContextTransferPriority") private var transferPriority = 65.0
    @AppStorage("HaloContextClipboardEnabled") private var clipboardCIEnabled = true
    @AppStorage("HaloContextClipboardPriority") private var clipboardPriority = 68.0
    @AppStorage("HaloDisableCustomCI") private var disableCustomCI = false
    @AppStorage("HaloContextTransferUseFullNotchArea") private var transferUsesFullNotchArea = true
    @AppStorage("HaloContextTransferKeepClosedNotchContents") private var transferKeepsClosedContents = false
    @AppStorage("HaloOpenKeepClosedNotchContents") private var keepClosedContentsWhenOpen = false
    @AppStorage("HaloContextMusicUseFullNotchArea") private var contextMusicUsesFullNotchArea = false
    @AppStorage("HaloContextMusicKeepClosedNotchContents") private var contextMusicKeepsClosedContents = false
    @AppStorage("HaloContextMusicPriority") private var contextMusicPriority = 60.0
    @AppStorage("HaloContextDropEnabled") private var dropCIEnabled = true
    @AppStorage("HaloContextDropUseFullNotchArea") private var dropUsesFullNotchArea = true
    @AppStorage("HaloContextDropKeepClosedNotchContents") private var dropKeepsClosedContents = false
    @AppStorage("HaloContextDropPriority") private var dropPriority = 100.0
    @AppStorage("HaloContextBluetoothEnabled") private var bluetoothCIEnabled = false
    @AppStorage("HaloContextBluetoothShowWhileConnected") private var bluetoothShowWhileConnected = true
    @AppStorage("HaloContextBluetoothShowOnChanges") private var bluetoothShowOnChanges = true
    @AppStorage("HaloContextBluetoothUseFullNotchArea") private var bluetoothUsesFullNotchArea = false
    @AppStorage("HaloContextBluetoothKeepClosedNotchContents") private var bluetoothKeepsClosedContents = false
    @AppStorage("HaloContextBluetoothPriority") private var bluetoothPriority = 50.0
    @AppStorage("HaloContextRetroEnabled") private var retroCIEnabled = false
    @AppStorage("HaloContextRetroUseFullNotchArea") private var retroUsesFullNotchArea = false
    @AppStorage("HaloContextRetroKeepClosedNotchContents") private var retroKeepsClosedContents = false
    @AppStorage("HaloContextRetroPriority") private var retroPriority = 80.0
    @AppStorage("HaloLiveActivitiesEnabled") private var liveActivitiesEnabled = true
    @AppStorage("HaloLiveActivitiesPriority") private var liveActivitiesPriority = 82.0
    @AppStorage("HaloLiveActivitiesUseFullNotchArea") private var liveActivitiesUseFullNotchArea = false
    @AppStorage("HaloLiveActivitiesKeepClosedNotchContents") private var liveActivitiesKeepClosedContents = false
    @State private var retroGameRequested = false
    private var theme: Theme { state.theme }
    private var layout: WorkspaceLayout { state.layoutOverride ?? workspace.effectiveLayout }
    private var contextOptions: ContextMusicOptions { layout.contextMusic ?? ContextMusicOptions() }
    private var bluetoothEligible: Bool {
        guard bluetoothCIEnabled else { return false }
        return (bluetoothShowOnChanges && bluetooth.lastEvent != nil) ||
            (bluetoothShowWhileConnected && !bluetooth.connectedDevices.isEmpty)
    }
    private var liveActivityCandidate: LiveActivity? {
        guard liveActivitiesEnabled else { return nil }
        return LiveActivitySelection.primary(in: workspace.activities, excluding: [.bluetooth])
    }
    private var builtInContextCandidates: [(interface: ActiveContextInterface, priority: Double, tieRank: Int)] {
        var candidates: [(interface: ActiveContextInterface, priority: Double, tieRank: Int)] = []
        if dropCIEnabled && state.dropTargeted { candidates.append((.drop, dropPriority, 4)) }
        if retroCIEnabled && retroGameRequested { candidates.append((.retro, retroPriority, 4)) }
        if teleprompterCIEnabled && teleprompterActive { candidates.append((.teleprompter, teleprompterPriority, 3)) }
        if transferCIEnabled && transfer.isActive { candidates.append((.transfer, transferPriority, 3)) }
        if clipboardCIEnabled && clipboardCI.isActive { candidates.append((.clipboard, clipboardCI.manualPresentation ? 1000 : clipboardPriority, 3)) }
        if liveActivityCandidate != nil { candidates.append((.liveActivity, liveActivitiesPriority, 3)) }
        if contextOptions.enabled && workspace.media.hasNowPlayingPresentation { candidates.append((.music, contextMusicPriority, 2)) }
        if bluetoothEligible { candidates.append((.bluetooth, bluetoothPriority, 1)) }
        return candidates
    }
    private var activeCustomCandidate: HaloCustomCICandidate? {
        customCI.activeCandidate(workspace: workspace, globalDisabled: disableCustomCI, blockingPriority: nil)
    }
    private var surfaceContextCandidates: [SurfaceContextCandidate] {
        // Locked Direct surfaces are activation/account UI only. No built-in, custom, or
        // partner CI is allowed to win arbitration until commercial startup reaches ready.
        guard commercialSurfaceGate.isReady else { return [] }

        // Notch Bubble "Open Notch" is an explicit user navigation action.
        // .normal bypasses every CI for this opening. .music forces Music CI only when
        // the user's Music CI is enabled and live media is actually available.
        switch state.explicitOpenDestination {
        case .normal:
            return []
        case .music:
            guard contextOptions.enabled,
                  workspace.media.isPlaying,
                  workspace.media.hasNowPlayingPresentation else { return [] }
            return [
                SurfaceContextCandidate(
                    interface: .music,
                    arbitration: CIArbitrationCandidate(
                        owner: .builtIn(ActiveContextInterface.music.rawValue),
                        ciID: "builtin." + ActiveContextInterface.music.rawValue,
                        priority: 10_000,
                        tieRank: 100
                    )
                )
            ]
        case .none:
            break
        }

        var result = builtInContextCandidates.map { item in
            SurfaceContextCandidate(
                interface: item.interface,
                arbitration: CIArbitrationCandidate(
                    owner: .builtIn(item.interface.rawValue),
                    ciID: "builtin." + item.interface.rawValue,
                    priority: item.priority,
                    tieRank: item.tieRank
                )
            )
        }
        if let custom = activeCustomCandidate {
            result.append(
                SurfaceContextCandidate(
                    interface: .custom,
                    arbitration: CIArbitrationCandidate(
                        owner: .custom(custom.registration.id),
                        ciID: custom.registration.id,
                        priority: custom.priority,
                        tieRank: custom.manual ? 100 : 3
                    )
                )
            )
        }
        for candidate in integrationCI.eligibleCandidates(displayID: state.displayID) {
            result.append(
                SurfaceContextCandidate(
                    interface: .integration,
                    arbitration: CIArbitrationCandidate(
                        owner: .integration(candidate.registration.id),
                        ciID: candidate.registration.id,
                        priority: candidate.priority,
                        tieRank: 3
                    )
                )
            )
        }
        return result
    }
    private var activeContextCandidate: SurfaceContextCandidate? {
        guard let winner = CIArbitrationEngine.winner(in: surfaceContextCandidates.map(\.arbitration)) else { return nil }
        return surfaceContextCandidates.first(where: { $0.arbitration == winner })
    }
    private var activeContext: ActiveContextInterface? { activeContextCandidate?.interface }
    private var activeIntegrationCandidate: CIEligibleCandidate? {
        guard activeContext == .integration,
              let ciID = activeContextCandidate?.arbitration.ciID else { return nil }
        return integrationCI.candidate(ciID: ciID, displayID: state.displayID)
    }
    private var activeIntegrationRegistration: CIRegistration? { activeIntegrationCandidate?.registration }
    private var activeIntegrationConfiguration: CIConfiguration? {
        guard let registration = activeIntegrationRegistration else { return nil }
        return integrationCI.configuration(for: registration)
    }
    private var dropContextActive: Bool { activeContext == .drop }
    private var contextMusicActive: Bool { activeContext == .music }
    private var bluetoothContextActive: Bool { activeContext == .bluetooth }
    private var retroContextActive: Bool { activeContext == .retro }
    private var teleprompterContextActive: Bool { activeContext == .teleprompter }
    private var transferContextActive: Bool { activeContext == .transfer }
    private var clipboardContextActive: Bool { activeContext == .clipboard }
    private var customContextActive: Bool { activeContext == .custom }
    private var integrationContextActive: Bool { activeContext == .integration }
    private var liveActivityContextActive: Bool { activeContext == .liveActivity }
    /// Logical expansion flips as soon as close is requested. Presentation expansion
    /// remains true until WindowManager reports that the physical retract animation ended.
    private var visuallyExpanded: Bool { state.expanded || state.presentationExpanded }
    private var reportsOpenedNotchVisible: Bool {
        visuallyExpanded &&
        (activeContext == nil || transferContextActive || clipboardContextActive || customContextActive || integrationContextActive || liveActivityContextActive)
    }
    private var contextOwnsFullSurface: Bool {
        guard visuallyExpanded else { return false }
        switch activeContext {
        case .drop: return dropUsesFullNotchArea
        case .music: return contextMusicUsesFullNotchArea
        case .bluetooth: return bluetoothUsesFullNotchArea
        case .retro: return retroUsesFullNotchArea
        case .liveActivity: return liveActivitiesUseFullNotchArea
        case .teleprompter: return true
        case .transfer: return false
        case .clipboard: return false
        case .custom: return true
        case .integration:
            guard let registration = activeIntegrationRegistration else { return false }
            return activeIntegrationConfiguration?.presentation.usesFullSurface
                ?? registration.presentation.usesFullSurface
        case .none: return false
        }
    }
    private var keepsClosedContentsWhileExpanded: Bool {
        switch activeContext {
        case .drop: return dropKeepsClosedContents
        case .music: return contextMusicKeepsClosedContents
        case .bluetooth: return bluetoothKeepsClosedContents
        case .retro: return retroKeepsClosedContents
        case .liveActivity: return liveActivitiesKeepClosedContents
        case .teleprompter: return false
        case .transfer: return false
        case .clipboard: return false
        case .custom: return false
        case .integration:
            guard let registration = activeIntegrationRegistration else { return false }
            return activeIntegrationConfiguration?.presentation.keepsClosedContents
                ?? registration.presentation.keepsClosedContents
        case .none:
            // The two opened-layout systems are mutually exclusive. The Default
            // layout is the only system allowed to keep its closed-notch strip.
            return usesDefaultWorkspace && keepClosedContentsWhenOpen
        }
    }
    private var hasClosedNotchVisualizer: Bool {
        let closed = layout.closedNotch ?? ClosedNotchOptions()
        return closed.left == .visualizer || closed.right == .visualizer
    }
    /// The closed visualizer is part of the notch strip, not the expanded Music CI body.
    /// Respect the user's retained-content setting for the visualizer too.
    private var preservesMusicClosedVisualizer: Bool {
        visuallyExpanded && contextMusicActive && contextMusicKeepsClosedContents && hasClosedNotchVisualizer && workspace.media.hasNowPlayingPresentation
    }
    private var preservesClosedStripWhileExpanded: Bool {
        keepsClosedContentsWhileExpanded || preservesMusicClosedVisualizer
    }
    private var retainedMusicClosedNotchBias: CGFloat {
        guard contextMusicActive, contextMusicKeepsClosedContents else { return 0 }
        return RetainedClosedNotchGeometry.horizontalBias(
            width: state.compactWidth,
            occlusion: state.closedOcclusion
        )
    }
    @ViewBuilder
    private var retainedMusicClosedNotch: some View {
        ClosedNotchView(
            store: store,
            workspace: workspace,
            layout: layout,
            occlusion: state.closedOcclusion,
            referenceWidth: state.compactWidth
        )
        .frame(width: state.compactWidth, height: max(40, state.compactHeight))
        .offset(x: retainedMusicClosedNotchBias)
    }
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
        case .pill: return visuallyExpanded ? .rounded : .capsule
        case .island: return visuallyExpanded ? .rounded : .capsule
        case .simulated, .notch: return .scoop
        case .shelf: return .chamfer
        case .detached: return .rounded
        case .menuBar: return .rounded
        default: return layout.appearance.surface.shape
        }
    }
    @State private var page = 0
    @State private var openVisibilityToken = UUID()
    private var modules: [ModuleID] { layout.normalizedOrder().filter { layout.enabled.contains($0) } }
    private var usesVisualWorkspace: Bool { layout.resolvedUsesCustomOpenNotchWorkspace }
    private var usesDefaultWorkspace: Bool { !usesVisualWorkspace }
    private var presentsVisualWorkspaceSurface: Bool {
        usesVisualWorkspace && activeContext == nil && (visuallyExpanded || visualWorkspaceSurfacePresented)
    }
    private var accent: Color { Color(hue: theme.tint, saturation: 0.65, brightness: 1) }

    @ViewBuilder
    private var integrationSurfaceContent: some View {
        if let candidate = activeIntegrationCandidate,
           let session = integrationCI.currentSession(displayID: state.displayID),
           session.ciID == candidate.registration.id {
            IntegrationCIView(
                candidate: candidate,
                session: session,
                surfaceState: state,
                runtime: integrationCI
            )
        } else if let candidate = activeIntegrationCandidate {
            VStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(candidate.registration.metadata.name)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Preparing \(candidate.registration.metadata.name)")
        }
    }

    var body: some View {
        GeometryReader { surfaceProxy in
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                if !contextOwnsFullSurface &&
                    !presentsVisualWorkspaceSurface {
                    Group {
                      if !visuallyExpanded && integrationContextActive {
                        IntegrationCICompactView(candidate: activeIntegrationCandidate)
                      } else if !visuallyExpanded && customContextActive, let candidate = activeCustomCandidate {
                        HaloCustomCISurfaceView(package: candidate.package, surfaceState: state, workspace: workspace)
                      } else if !visuallyExpanded && (state.compactWidth < 48 || state.compactHeight < 16) {
                        Circle().fill(store.deadline == nil ? accent : .green).frame(width: 6, height: 6)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                      } else if !visuallyExpanded {
                        if transferContextActive {
                            TransferClosedContextView(monitor: transfer, surfaceState: state)
                        } else if clipboardContextActive {
                            ClipboardClosedContextView(monitor: clipboardCI, surfaceState: state)
                        } else {
                            ClosedNotchView(store: store, workspace: workspace, layout: layout, occlusion: state.closedOcclusion, referenceWidth: state.compactWidth)
                        }
                      } else if keepsClosedContentsWhileExpanded {
                        if contextMusicActive {
                            retainedMusicClosedNotch
                        } else {
                            ClosedNotchView(store: store, workspace: workspace, layout: layout,
                                            occlusion: state.closedOcclusion, referenceWidth: state.compactWidth)
                        }
                      } else if preservesMusicClosedVisualizer {
                        ClosedNotchView(store: store, workspace: workspace, layout: layout,
                                        occlusion: state.closedOcclusion, referenceWidth: state.compactWidth,
                                        visualizerOnly: true, expandVisualizerToAvailableWidth: true)
                      } else { HStack {
                        Circle().fill(store.deadline == nil ? accent : .green).frame(width: 7, height: 7)
                        Spacer()
                        Image(systemName: state.pinned ? "pin.fill" : "chevron.up").font(.system(size: 9, weight: .bold))
                      } }
                    }
                    .padding(.horizontal, (!visuallyExpanded || preservesClosedStripWhileExpanded) ? 0 : max(16, layout.appearance.surface.shoulder + 8))
                    .frame(height: visuallyExpanded ? max(40, state.compactHeight) : state.compactHeight)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !teleprompterActive else { return }
                        if state.expanded && state.pinned { return }
                        state.expanded.toggle()
                    }
                    .accessibilityLabel("Toggle Halo dashboard")
                    .accessibilityAddTraits(.isButton)
                }
                if visuallyExpanded || presentsVisualWorkspaceSurface {
                    if integrationContextActive {
                        integrationSurfaceContent
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    } else if customContextActive, let candidate = activeCustomCandidate {
                        HaloCustomCISurfaceView(package: candidate.package, surfaceState: state, workspace: workspace)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    } else if liveActivityContextActive, let activity = liveActivityCandidate {
                        if !liveActivitiesUseFullNotchArea {
                            LiveActivityContextView(activity: activity, workspace: workspace, surfaceState: state)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .transition(.opacity.combined(with: .scale(scale: 0.985)))
                        }
                    } else if transferContextActive {
                        TransferContextView(monitor: transfer, surfaceState: state)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    } else if clipboardContextActive {
                        ClipboardContextView(monitor: clipboardCI, surfaceState: state)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    } else if dropContextActive {
                        if !dropUsesFullNotchArea {
                            DropContextView(itemCount: state.dropItemCount, surfaceState: state)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .transition(.opacity.combined(with: .scale(scale: 0.985)))
                        }
                    } else if contextMusicActive {
                        if !contextMusicUsesFullNotchArea {
                            ContextMusicView(media: workspace.media, options: contextOptions,
                                             visualizer: layout.closedNotch?.visualizer ?? VisualizerOptions(), surfaceState: state,
                                             preserveClosedVisualizerStrip: preservesMusicClosedVisualizer)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .transition(.opacity.combined(with: .scale(scale: 0.985)))
                        }
                    } else if bluetoothContextActive {
                        if !bluetoothUsesFullNotchArea {
                            BluetoothContextView(bluetooth: bluetooth, surfaceState: state)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .transition(.opacity.combined(with: .scale(scale: 0.985)))
                        }
                    } else if retroContextActive {
                        if !retroUsesFullNotchArea {
                            RetroGameContextView(surfaceState: state)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .transition(.opacity.combined(with: .scale(scale: 0.985)))
                        }
                    } else if usesVisualWorkspace {
                        // The Visual Workspace receives one authoritative canvas: exactly the
                        // expanded surface proposed by the notch window. Region percentages are
                        // resolved only against this rectangle, never against intrinsic content.
                        GeometryReader { surfaceProxy in
                            OpenNotchWorkspaceView(
                                layout: layout,
                                store: store,
                                mode: layout.resolvedOpenNotchLayout.resolvedContentMode,
                                page: $page,
                                closingPowerOnly: state.pixelPalCloseGateActive && presentsVisualWorkspaceSurface
                            )
                                .environment(\.haloPixelPalHostExpanded, state.expanded)
                                .environment(\.haloPixelPalHostTransitionDuration, layout.appearance.surface.duration)
                                .frame(width: surfaceProxy.size.width,
                                       height: surfaceProxy.size.height,
                                       alignment: .topLeading)
                        }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .overlay(alignment: .bottomTrailing) {
                                HStack(spacing: 5) {
                                    Button { state.pinned.toggle() } label: {
                                        Image(systemName: state.pinned ? "pin.fill" : "pin")
                                    }
                                    .help("Keep expanded")
                                    Button {
                                        NotificationCenter.default.post(name: Notification.Name("HaloOpenSettings"), object: nil)
                                    } label: {
                                        Image(systemName: "gearshape")
                                    }
                                    .help("Settings")
                                }
                                .controlSize(.small)
                                .padding(.horizontal, 7).padding(.vertical, 5)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(10)
                                .opacity(state.expanded ? 1 : 0)
                                .allowsHitTesting(state.expanded)
                            }
                            .overlay(alignment: .top) {
                                if keepsClosedContentsWhileExpanded {
                                    // Preserve the existing option without stealing layout space:
                                    // closed-notch content floats over the full workspace instead.
                                    ClosedNotchView(store: store, workspace: workspace, layout: layout,
                                                    occlusion: state.closedOcclusion,
                                                    referenceWidth: state.compactWidth)
                                        .frame(height: max(40, state.compactHeight))
                                        .zIndex(3)
                                }
                            }
                            .transition(.opacity)
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
                            legacyOpenDashboardContent
                            HStack {
                                Spacer()
                                Button("Settings") { NotificationCenter.default.post(name: Notification.Name("HaloOpenSettings"), object: nil) }
                            }
                        }
                        .padding(.horizontal, CGFloat(layout.resolvedOpenHorizontalPadding))
                        .padding(.vertical, CGFloat(layout.resolvedOpenVerticalPadding))
                        .frame(width: state.dashboardWidth)
                        .transition(.opacity)
                    }
                }
            }

            if contextOwnsFullSurface {
                Group {
                    if integrationContextActive {
                        integrationSurfaceContent
                    } else if dropContextActive {
                        DropContextView(itemCount: state.dropItemCount, surfaceState: state)
                    } else if contextMusicActive {
                        ContextMusicView(media: workspace.media, options: contextOptions,
                                         visualizer: layout.closedNotch?.visualizer ?? VisualizerOptions(), surfaceState: state,
                                             preserveClosedVisualizerStrip: preservesMusicClosedVisualizer)
                    } else if bluetoothContextActive {
                        BluetoothContextView(bluetooth: bluetooth, surfaceState: state)
                    } else if liveActivityContextActive, let activity = liveActivityCandidate {
                        LiveActivityContextView(activity: activity, workspace: workspace, surfaceState: state)
                    } else if retroContextActive {
                        RetroGameContextView(surfaceState: state)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
                .zIndex(2)

                if keepsClosedContentsWhileExpanded {
                    if contextMusicActive {
                        retainedMusicClosedNotch
                            .zIndex(3)
                    } else {
                        ClosedNotchView(store: store, workspace: workspace, layout: layout,
                                        occlusion: state.closedOcclusion, referenceWidth: state.compactWidth)
                            .frame(height: max(40, state.compactHeight))
                            .zIndex(3)
                    }
                } else if preservesMusicClosedVisualizer {
                    ClosedNotchView(store: store, workspace: workspace, layout: layout,
                                    occlusion: state.closedOcclusion, referenceWidth: state.compactWidth,
                                    visualizerOnly: true, expandVisualizerToAvailableWidth: true)
                        .frame(height: max(40, state.compactHeight))
                        .zIndex(3)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Fixed-size dashboard/CI children may exceed the proposal during retract.
        // Keep the background and contour on the live viewport, before clipping.
        .frame(width: surfaceProxy.size.width, height: surfaceProxy.size.height, alignment: .top)
        .background {
            ZStack {
                surfaceBackgroundLayer
                NotchSkinLayer(options: layout.appearance.skin, theme: theme, expanded: visuallyExpanded)
            }
        }
        .clipShape(contour)
        .contentShape(contour)
        .overlay { surfaceOverlayLayer }
        }
        .foregroundStyle(.white).preferredColorScheme(.dark)
        .buttonStyle(.borderless)
        .contextMenu {
            Button(state.pinned ? "Unpin" : "Keep open") { state.pinned.toggle() }
            Toggle("Keep closed-notch contents when opened", isOn: $keepClosedContentsWhenOpen)
            ForEach(workspace.settings.profiles) { profile in Button(profile.name) { workspace.apply(profile) } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("HaloCustomCIOpenRequested"))) { note in
            guard !disableCustomCI, let requestedID = note.object as? String else { return }
            guard customContextActive, activeCustomCandidate?.package.manifest.id == requestedID else {
                customCI.clearManualActivation()
                customCI.notice = "Custom CI did not open because a higher-priority CI currently owns the notch."
                return
            }
            state.collapseTask?.cancel()
            state.expanded = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("HaloCustomCICloseRequested"))) { _ in
            state.contextPreferredSize = nil
            state.contextPreferredCompactWidth = nil
            state.contextPreferredCompactHeight = nil
            state.contextMinimumExpandedWidth = nil
            if !state.pinned { state.expanded = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("HaloClipboardCIToggle"))) { _ in
            guard clipboardCIEnabled else { return }
            if clipboardContextActive && state.expanded {
                clipboardCI.dismiss()
                clipboardOpenedNotch = false
                if !state.pinned { state.expanded = false }
                return
            }
            guard clipboardCI.presentHistory() else { return }
            DispatchQueue.main.async {
                guard clipboardCIEnabled, clipboardCI.isActive else { return }
                state.collapseTask?.cancel()
                clipboardOpenedNotch = true
                state.expanded = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("HaloRetroGameToggle"))) { _ in
            guard retroCIEnabled else { return }
            retroGameRequested.toggle()
            state.collapseTask?.cancel()
            if retroGameRequested {
                state.expanded = true
            } else if !state.pinned {
                state.expanded = false
            }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in store.expireFiles() }
        .onReceive(NotificationCenter.default.publisher(for: .init("HaloTeleprompterVisibilityChanged"))) { note in
            let requestedActive = (note.userInfo?["active"] as? Bool) ?? false
            let active = requestedActive && commercialSurfaceGate.isReady
            teleprompterActive = active

            if requestedActive && !commercialSurfaceGate.isReady {
                // Defensive backstop for any stale/late trigger emitted while Halo is locked.
                TeleprompterCoordinator.shared.hidePrompt()
            }

            DispatchQueue.main.async {
                let owns = teleprompterCIEnabled && teleprompterActive && activeContext == .teleprompter
                NotificationCenter.default.post(name: .init("HaloTeleprompterCIOwnershipChanged"), object: nil, userInfo: ["owns": owns])
                if owns {
                    state.collapseTask?.cancel()
                    if !state.pinned { state.expanded = false }
                }
            }
        }
        .environment(\.openNotchInteractionHold) { held in
            state.setExternalInteractionHeld(held)
        }
        .onHover { hovering in
            if hovering {
                HaloHoverHaptics.pulse(
                    id: "surface." + state.displayID,
                    strength: store.configuration.resolvedHoverHapticStrength,
                    pattern: store.configuration.resolvedHoverHapticPattern
                )
            }

            if clipboardContextActive {
                clipboardCI.setInteractionActive(hovering)
            } else {
                clipboardCI.setInteractionActive(false)
            }
            if teleprompterContextActive {
                state.collapseTask?.cancel()
                if !state.pinned { state.expanded = false }
            } else {
                let clipboardHover = clipboardContextActive && clipboardCI.triggerMode == "Hover to Open"
                state.hover(
                    hovering,
                    enabled: store.configuration.hoverToExpand || clipboardHover,
                    openDelay: store.configuration.hoverToExpand ? store.configuration.resolvedHoverOpenDelay : 0,
                    closeDelay: store.configuration.hoverToExpand ? store.configuration.resolvedHoverCloseDelay : 0
                )
            }
        }
        .onChange(of: state.dropTargeted) { active in
            if active && dropCIEnabled {
                state.collapseTask?.cancel()
                state.expanded = true
            }
        }
        .onAppear {
            if !commercialSurfaceGate.isReady {
                teleprompterActive = false
                TeleprompterCoordinator.shared.hidePrompt()
            }
            workspace.setOpenedNotchVisible(reportsOpenedNotchVisible, token: openVisibilityToken)
            visualWorkspaceSurfacePresented = visuallyExpanded && usesVisualWorkspace && activeContext == nil
        }
        .onChange(of: commercialSurfaceGate.isReady) { ready in
            if !ready {
                teleprompterActive = false
                clipboardOpenedNotch = false
                integrationAutoOpeningSurface = false
                TeleprompterCoordinator.shared.hidePrompt()
                state.cancelFileDrop()
                if !state.pinned { state.expanded = false }
            }
            synchronizeSurfaceCIOwnership()
        }
        .onDisappear { workspace.setOpenedNotchVisible(false, token: openVisibilityToken) }
        .onReceive(state.viewport.$size) { size in
            guard visualWorkspaceSurfacePresented, !state.expanded else { return }
            let atCompactSize =
                abs(size.width - state.compactWidth) <= 1 &&
                abs(size.height - state.compactHeight) <= 1
            if atCompactSize {
                visualWorkspaceSurfacePresented = false
            }
        }
        .onChange(of: usesVisualWorkspace) { active in
            if !active {
                visualWorkspaceSurfacePresented = false
            } else if visuallyExpanded && activeContext == nil {
                visualWorkspaceSurfacePresented = true
            }
        }
        .onChange(of: state.expanded) { expanded in
            if expanded && usesVisualWorkspace && activeContext == nil {
                visualWorkspaceSurfacePresented = true
            }
            if teleprompterContextActive && expanded {
                state.expanded = false
                workspace.setOpenedNotchVisible(reportsOpenedNotchVisible, token: openVisibilityToken)
                return
            }
            workspace.setOpenedNotchVisible(reportsOpenedNotchVisible, token: openVisibilityToken)
        }
        .onChange(of: state.presentationExpanded) { presentationExpanded in
            workspace.setOpenedNotchVisible(reportsOpenedNotchVisible, token: openVisibilityToken)
            guard !presentationExpanded, !state.expanded else { return }

            // Open-only state is torn down only after the physical retract finishes.
            // This prevents the panel from animating around an already-empty SwiftUI tree.
            state.contextPreferredSize = nil
            if transferContextActive {
                // Preserve the content-driven open target while Transfer remains active,
                // so the next hover/click opens directly to the correct size.
                DispatchQueue.main.async {
                    guard transferContextActive, !state.expanded else { return }
                    state.contextMinimumExpandedWidth = TransferCISizing.minimumExpandedWidth(physicalNotchWidth: state.physicalNotchWidth)
                    state.contextPreferredCompactWidth = TransferCISizing.closedPreferredWidth(physicalNotchWidth: state.physicalNotchWidth)
                    state.contextPreferredSize = TransferCISizing.openPreferredSize(stripHeight: state.compactHeight)
                }
            } else if clipboardContextActive {
                DispatchQueue.main.async {
                    guard clipboardContextActive, !state.expanded else { return }
                    state.contextMinimumExpandedWidth = ClipboardCISizing.minimumExpandedWidth(physicalNotchWidth: state.physicalNotchWidth)
                    state.contextPreferredCompactWidth = ClipboardCISizing.closedPreferredWidth(monitor: clipboardCI, physicalNotchWidth: state.closedOcclusion == nil ? 0 : state.physicalNotchWidth)
                    state.contextPreferredSize = ClipboardCISizing.openPreferredSize(actionCount: clipboardCI.actions.count, historyCount: clipboardCI.history.count, kind: clipboardCI.kind)
                }
            }
            retroGameRequested = false
        }
        .onChange(of: clipboardCI.eventSerial) { _ in
            guard clipboardCIEnabled, clipboardCI.isActive, clipboardCI.triggerMode == "Pop Up" else { return }
            DispatchQueue.main.async {
                guard clipboardCIEnabled, clipboardCI.isActive, activeContext == .clipboard, !state.pinned else { return }
                if !state.expanded {
                    clipboardOpenedNotch = true
                    state.collapseTask?.cancel()
                    state.expanded = true
                }
            }
        }
        .onChange(of: clipboardCI.isActive) { active in
            if !active {
                clipboardCI.setInteractionActive(false)
                if clipboardOpenedNotch && !state.pinned { state.expanded = false }
                clipboardOpenedNotch = false
            }
        }
        .onChange(of: state.expanded) { expanded in
            if !expanded { clipboardOpenedNotch = false }
            if integrationCI.currentSession(displayID: state.displayID) != nil,
               !integrationAutoOpeningSurface {
                integrationCI.noteUserSurfaceOverride(displayID: state.displayID)
            }
        }
        .onAppear {
            synchronizeSurfaceCIOwnership()
        }
        .onChange(of: activeContextCandidate?.arbitration.ciID) { _ in
            synchronizeSurfaceCIOwnership()
        }
        .onChange(of: state.displayID) { _ in
            synchronizeSurfaceCIOwnership()
        }
        .onChange(of: activeContext) { _ in
            if activeContext == nil, visuallyExpanded, usesVisualWorkspace {
                visualWorkspaceSurfacePresented = true
            } else if activeContext != nil {
                visualWorkspaceSurfacePresented = false
            }
            let owns = teleprompterCIEnabled && teleprompterActive && activeContext == .teleprompter
            NotificationCenter.default.post(name: .init("HaloTeleprompterCIOwnershipChanged"), object: nil, userInfo: ["owns": owns])
            if owns {
                state.collapseTask?.cancel()
                if !state.pinned { state.expanded = false }
            }
            if clipboardContextActive {
                state.contextMinimumExpandedWidth = ClipboardCISizing.minimumExpandedWidth(physicalNotchWidth: state.physicalNotchWidth)
                state.contextPreferredCompactWidth = ClipboardCISizing.closedPreferredWidth(monitor: clipboardCI, physicalNotchWidth: state.closedOcclusion == nil ? 0 : state.physicalNotchWidth)
                state.contextPreferredSize = ClipboardCISizing.openPreferredSize(actionCount: clipboardCI.actions.count, historyCount: clipboardCI.history.count, kind: clipboardCI.kind)
                if clipboardCI.triggerMode == "Pop Up", !state.expanded, !state.pinned {
                    clipboardOpenedNotch = true
                    state.collapseTask?.cancel()
                    state.expanded = true
                }
            } else {
                clipboardCI.setInteractionActive(false)
                if activeContext != nil { clipboardOpenedNotch = false }
            }
            if !transferContextActive && !clipboardContextActive && !customContextActive && !integrationContextActive {
                state.contextPreferredCompactWidth = nil
                state.contextPreferredCompactHeight = nil
                state.contextMinimumExpandedWidth = nil
                if activeContext != nil && !contextMusicActive { state.contextPreferredSize = nil }
            }
            workspace.setOpenedNotchVisible(reportsOpenedNotchVisible, token: openVisibilityToken)
        }
    }

    private func synchronizeSurfaceCIOwnership() {
        let winnerID = activeContextCandidate?.arbitration.ciID
        if state.activeCIIdentifier != winnerID {
            state.activeCIIdentifier = winnerID
        }

        let integrationWinnerID = integrationContextActive ? winnerID : nil
        let decision = integrationCI.surfaceWinnerDidChange(
            ciID: integrationWinnerID,
            displayID: state.displayID,
            surfaceExpanded: state.expanded,
            pinned: state.pinned
        )

        if decision.shouldOpenSurface, !state.expanded {
            integrationAutoOpeningSurface = true
            state.collapseTask?.cancel()
            state.expanded = true
            DispatchQueue.main.async {
                integrationAutoOpeningSurface = false
            }
        } else {
            integrationAutoOpeningSurface = false
        }

        if dropContextActive && state.dropTargeted {
            // Drop CI is a normal consumer of the same drag event. It may expand only after
            // winning the central arbitration above.
            state.activateDropOwnership()
        } else if decision.shouldCollapseSurface,
                  activeContext == nil,
                  !state.pinned {
            state.expanded = false
        }
    }

    @ViewBuilder private var surfaceBackgroundLayer: some View {
        ZStack {
            if transferContextActive {
                TransferSurfaceBackground(monitor: transfer)
            } else if clipboardContextActive {
                ClipboardSurfaceBackground(monitor: clipboardCI)
            } else if customContextActive, let candidate = activeCustomCandidate {
                HaloCustomCIBackgroundView(contract: candidate.package.manifest.surface.background, expanded: visuallyExpanded)
            } else if usesVisualWorkspace && activeContext == nil {
                // Visual Workspace owns the surface background in both open and closed
                // states. Falling back to the legacy/default SurfaceBackground while
                // collapsed can stack two different appearances (for example legacy
                // Glass behind a black Visual Workspace) and look like a second notch.
                OpenNotchBackgroundView(
                    options: layout.resolvedOpenNotchLayout.appearance,
                    fallback: layout.appearance,
                    theme: theme,
                    system: workspace.system
                )
            } else {
                SurfaceBackground(
                    appearance: layout.appearance,
                    theme: theme,
                    expanded: visuallyExpanded,
                    system: workspace.system
                )
            }
            if !transferContextActive && !clipboardContextActive && !customContextActive && !integrationContextActive &&
                ((!visuallyExpanded && !presentsVisualWorkspaceSurface) || layout.closedNotch?.applyBackgroundWhenOpened == true) {
                AlbumNotchBackground(options: closedBackgroundOptions, media: workspace.media, system: workspace.system)
            }
        }
    }

    @ViewBuilder private var surfaceOverlayLayer: some View {
        let dropOverlayActive = dropCIEnabled && state.dropTargeted
        let outlineEnabled = layout.appearance.surface.outlineEnabled ?? true

        // Keep the drag/drop ownership highlight even when the decorative outer
        // outline is disabled; it communicates an active drop target.
        if dropOverlayActive || outlineEnabled {
            contour.stroke(
                dropOverlayActive ? accent : .white.opacity(0.12),
                lineWidth: dropOverlayActive ? 1.6 : 1
            )
        }

        if presentsVisualWorkspaceSurface {
            OpenNotchSurfaceChrome(contour: contour, options: layout.resolvedOpenNotchLayout.appearance)
        }
    }

    private func legacyHorizontalWidget(_ module: ModuleID) -> some View {
        GeometryReader { proxy in
            WidgetCard(style: layout.widgetStyle(for: module), availableHeight: proxy.size.height, availableWidth: proxy.size.width) {
                BuiltinOrIntegrationWidget(module: module, store: store)
            }
        }
    }


    @ViewBuilder private var legacyOpenDashboardContent: some View {
        switch layout.resolvedOpenNotchContentMode {
        case .fixed:
            GeometryReader { proxy in
                if modules.isEmpty {
                    Text("Enable widgets in Settings → Modules.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    let columns = max(1, min(layout.resolvedOpenFixedColumns, modules.count))
                    let rows = max(1, Int(ceil(Double(modules.count) / Double(columns))))
                    let gap = CGFloat(layout.appearance.spacing)
                    let cellHeight = max(1, (proxy.size.height - gap * CGFloat(max(0, rows - 1))) / CGFloat(rows))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gap), count: columns), spacing: gap) {
                        ForEach(modules) { module in legacyHorizontalWidget(module).frame(height: cellHeight) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        case .scroll:
            if layout.horizontalWidgets ?? false {
                ScrollView(.horizontal) { LazyHStack(alignment: .top, spacing: layout.appearance.spacing) { legacyWidgetCards(horizontal: true) } }
            } else {
                ScrollView { LazyVStack(spacing: layout.appearance.spacing) { legacyWidgetCards(horizontal: false) } }
            }
        case .pages:
            VStack(spacing: 8) {
                if !modules.isEmpty {
                    let index = min(max(0, page), modules.count - 1)
                    legacyHorizontalWidget(modules[index])
                    HStack {
                        Button { page = max(0, index - 1) } label: { Image(systemName: "chevron.left") }.disabled(index == 0).accessibilityLabel("Previous widget")
                        Spacer(); Text("\(modules[index].title) · \(index + 1) / \(modules.count)").font(.caption); Spacer()
                        Button { page = min(modules.count - 1, index + 1) } label: { Image(systemName: "chevron.right") }.disabled(index == modules.count - 1).accessibilityLabel("Next widget")
                    }
                } else { Text("Enable widgets in Settings → Modules.").foregroundStyle(.secondary) }
            }
        }
    }

    @ViewBuilder private func legacyWidgetCards(horizontal: Bool) -> some View {
        ForEach(modules) { module in
            if horizontal {
                legacyHorizontalWidget(module).frame(width: max(240, state.dashboardWidth - 64))
            } else {
                WidgetCard(style: layout.widgetStyle(for: module)) { BuiltinOrIntegrationWidget(module: module, store: store) }
            }
        }
    }
}



// MARK: - Notch skins

private extension NotchSkinBlend {
    var swiftUIBlendMode: BlendMode {
        switch self {
        case .normal: return .normal
        case .overlay: return .overlay
        case .softLight: return .softLight
        case .screen: return .screen
        case .multiply: return .multiply
        }
    }
}

/// Decorative middle layer for the notch surface. It intentionally lives above the selected
/// background and below every widget / Context Interface element so skins never steal hierarchy
/// from useful content.
struct NotchSkinLayer: View {
    let options: NotchSkinOptions
    let theme: Theme
    let expanded: Bool

    private var normalized: NotchSkinOptions { options.normalized() }
    private var scale: CGFloat { CGFloat(normalized.scale) }
    private var shouldRender: Bool {
        guard normalized.enabled else { return false }
        switch normalized.visibility {
        case .always: return true
        case .opened: return expanded
        case .closed: return !expanded
        }
    }
    private var tint: Color {
        if normalized.usesThemeTint {
            return Color(hue: theme.tint, saturation: 0.72, brightness: 1.0)
        }
        return normalized.tint.color
    }
    private var blendMode: BlendMode {
        switch normalized.blend {
        case .normal: return .normal
        case .overlay: return .overlay
        case .softLight: return .softLight
        case .screen: return .screen
        case .multiply: return .multiply
        }
    }

    var body: some View {
        Group {
            if shouldRender {
                GeometryReader { proxy in
                    skin(in: proxy.size)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
                .opacity(normalized.opacity)
                .blendMode(blendMode)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private func skin(in size: CGSize) -> some View {
        switch normalized.preset {
        case .haloGlow:
            ZStack {
                RadialGradient(colors: [tint.opacity(0.82), tint.opacity(0.28), .clear], center: .top, startRadius: 0, endRadius: max(size.width, size.height) * 0.72)
                LinearGradient(colors: [tint.opacity(0.28), .clear, tint.opacity(0.18)], startPoint: .leading, endPoint: .trailing)
            }

        case .carbonWeave:
            // Filled ribbons stay visible after the surface opacity/blend pass. The old
            // sub-pixel strokes could disappear almost completely on a dark background.
            Canvas { context, canvas in
                let tile = max(CGFloat(8), 12 * scale)
                var row = -1
                var y = -tile
                while y < canvas.height + tile {
                    var col = -1
                    var x = -tile
                    while x < canvas.width + tile {
                        let offset = row.isMultiple(of: 2) ? CGFloat.zero : tile * 0.5
                        let ox = x + offset
                        let bright = (row + col).isMultiple(of: 2)
                        var forward = Path()
                        forward.move(to: CGPoint(x: ox, y: y + tile * 0.08))
                        forward.addLine(to: CGPoint(x: ox + tile * 0.82, y: y + tile * 0.08))
                        forward.addLine(to: CGPoint(x: ox + tile, y: y + tile * 0.42))
                        forward.addLine(to: CGPoint(x: ox + tile * 0.18, y: y + tile * 0.42))
                        forward.closeSubpath()
                        context.fill(forward, with: .color((bright ? tint : Color.white).opacity(bright ? 0.62 : 0.30)))

                        var reverse = Path()
                        reverse.move(to: CGPoint(x: ox + tile * 0.18, y: y + tile * 0.54))
                        reverse.addLine(to: CGPoint(x: ox + tile, y: y + tile * 0.54))
                        reverse.addLine(to: CGPoint(x: ox + tile * 0.82, y: y + tile * 0.88))
                        reverse.addLine(to: CGPoint(x: ox, y: y + tile * 0.88))
                        reverse.closeSubpath()
                        context.fill(reverse, with: .color(Color.black.opacity(bright ? 0.48 : 0.66)))
                        x += tile
                        col += 1
                    }
                    y += tile
                    row += 1
                }
            }

        case .neonCircuit:
            Canvas { context, canvas in
                let spacing = max(CGFloat(18), 30 * scale)
                var x: CGFloat = spacing * 0.5
                var index = 0
                while x < canvas.width + spacing {
                    let y = CGFloat((index * 37) % max(1, Int(canvas.height)))
                    var path = Path()
                    path.move(to: CGPoint(x: x - spacing, y: y))
                    path.addLine(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x, y: min(canvas.height, y + spacing * 0.7)))
                    path.addLine(to: CGPoint(x: min(canvas.width, x + spacing * 0.72), y: min(canvas.height, y + spacing * 0.7)))
                    context.stroke(path, with: .color(tint.opacity(0.78)), lineWidth: max(1.1, 1.7 * scale))
                    let node = CGRect(x: x - 2.8 * scale, y: y - 2.8 * scale, width: 5.6 * scale, height: 5.6 * scale)
                    context.fill(Path(ellipseIn: node), with: .color(Color.white.opacity(0.82)))
                    x += spacing
                    index += 1
                }
            }

        case .retroScanlines:
            ZStack {
                LinearGradient(colors: [.clear, tint.opacity(0.18), .clear], startPoint: .leading, endPoint: .trailing)
                Canvas { context, canvas in
                    let spacing = max(CGFloat(4), 6.5 * scale)
                    let thickness = max(CGFloat(1.5), 2.15 * scale)
                    var y: CGFloat = 0
                    var index = 0
                    while y <= canvas.height {
                        let alpha = index.isMultiple(of: 4) ? 0.68 : 0.38
                        let bar = CGRect(x: 0, y: y, width: canvas.width, height: thickness)
                        context.fill(Path(bar), with: .color((index.isMultiple(of: 4) ? tint : Color.white).opacity(alpha)))
                        if index.isMultiple(of: 8) {
                            let shadow = CGRect(x: 0, y: y + thickness, width: canvas.width, height: max(1, thickness * 0.55))
                            context.fill(Path(shadow), with: .color(Color.black.opacity(0.45)))
                        }
                        y += spacing
                        index += 1
                    }
                }
            }

        case .pixelMatrix:
            Canvas { context, canvas in
                let spacing = max(CGFloat(8), 13 * scale)
                let dot = max(CGFloat(1.5), 2.4 * scale)
                var row = 0
                var y: CGFloat = spacing * 0.5
                while y < canvas.height {
                    var col = 0
                    var x: CGFloat = spacing * 0.5
                    while x < canvas.width {
                        if ((row * 5 + col * 3) % 7) < 3 {
                            let rect = CGRect(x: x - dot * 0.5, y: y - dot * 0.5, width: dot, height: dot)
                            context.fill(Path(rect), with: .color(tint.opacity(((row + col) % 3 == 0) ? 0.95 : 0.52)))
                        }
                        x += spacing; col += 1
                    }
                    y += spacing; row += 1
                }
            }

        case .constellation:
            Canvas { context, canvas in
                let count = 22
                var points: [CGPoint] = []
                for i in 0..<count {
                    let x = canvas.width * CGFloat((i * 47 + 13) % 101) / 100
                    let y = canvas.height * CGFloat((i * 31 + 17) % 97) / 96
                    points.append(CGPoint(x: x, y: y))
                }
                for i in 1..<points.count where i % 3 != 0 {
                    var line = Path(); line.move(to: points[i - 1]); line.addLine(to: points[i])
                    context.stroke(line, with: .color(tint.opacity(0.24)), lineWidth: max(0.7, 0.9 * scale))
                }
                for (i, point) in points.enumerated() {
                    let r = max(CGFloat(1.2), CGFloat((i % 3) + 1) * 0.75 * scale)
                    context.fill(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)), with: .color((i % 5 == 0 ? Color.white : tint).opacity(0.82)))
                }
            }

        case .aurora:
            ZStack {
                LinearGradient(colors: [Color.cyan.opacity(0.13), Color.purple.opacity(0.12), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                Canvas { context, canvas in
                    let colors: [Color] = [tint, .cyan, .purple, .green]
                    for i in 0..<4 {
                        let base = canvas.height * (0.20 + CGFloat(i) * 0.18)
                        var path = Path()
                        path.move(to: CGPoint(x: -20, y: base))
                        path.addCurve(to: CGPoint(x: canvas.width * 0.52, y: base + canvas.height * 0.12), control1: CGPoint(x: canvas.width * 0.14, y: base - canvas.height * 0.22), control2: CGPoint(x: canvas.width * 0.36, y: base + canvas.height * 0.25))
                        path.addCurve(to: CGPoint(x: canvas.width + 20, y: base - canvas.height * 0.05), control1: CGPoint(x: canvas.width * 0.70, y: base - canvas.height * 0.16), control2: CGPoint(x: canvas.width * 0.88, y: base + canvas.height * 0.12))
                        context.stroke(path, with: .color(colors[i].opacity(0.54)), lineWidth: max(8, 18 * scale))
                    }
                }
                .blur(radius: max(2, 4 * scale))
            }

        case .synthwave:
            Canvas { context, canvas in
                let horizon = canvas.height * 0.48
                let centerX = canvas.width * 0.50
                let sunSize = min(canvas.width, canvas.height) * 0.42
                let sunRect = CGRect(x: centerX - sunSize * 0.5, y: horizon - sunSize * 0.78, width: sunSize, height: sunSize)
                context.fill(Path(ellipseIn: sunRect), with: .color(Color.orange.opacity(0.74)))
                var stripeY = sunRect.minY + sunSize * 0.48
                while stripeY < sunRect.maxY {
                    context.fill(Path(CGRect(x: sunRect.minX, y: stripeY, width: sunSize, height: max(1, 2.0 * scale))), with: .color(Color.pink.opacity(0.76)))
                    stripeY += max(4, 6 * scale)
                }
                for i in -7...7 {
                    var ray = Path(); ray.move(to: CGPoint(x: centerX, y: horizon)); ray.addLine(to: CGPoint(x: centerX + CGFloat(i) * canvas.width / 7, y: canvas.height))
                    context.stroke(ray, with: .color(tint.opacity(0.56)), lineWidth: max(0.8, 1.1 * scale))
                }
                for i in 0..<8 {
                    let t = CGFloat(i) / 7
                    let y = horizon + (canvas.height - horizon) * t * t
                    var line = Path(); line.move(to: CGPoint(x: 0, y: y)); line.addLine(to: CGPoint(x: canvas.width, y: y))
                    context.stroke(line, with: .color(Color.purple.opacity(0.62)), lineWidth: max(0.8, 1.1 * scale))
                }
            }

        case .sakuraNight:
            ZStack {
                RadialGradient(colors: [Color.pink.opacity(0.22), Color.purple.opacity(0.10), .clear], center: .topTrailing, startRadius: 0, endRadius: max(size.width, size.height) * 0.8)
                Canvas { context, canvas in
                    var branch = Path(); branch.move(to: CGPoint(x: -10, y: canvas.height * 0.78)); branch.addCurve(to: CGPoint(x: canvas.width * 0.72, y: -10), control1: CGPoint(x: canvas.width * 0.22, y: canvas.height * 0.70), control2: CGPoint(x: canvas.width * 0.42, y: canvas.height * 0.22))
                    context.stroke(branch, with: .color(Color(red: 0.40, green: 0.20, blue: 0.30).opacity(0.76)), lineWidth: max(2.2, 4.2 * scale))
                    for i in 0..<34 {
                        let x = canvas.width * CGFloat((i * 43 + 11) % 101) / 100
                        let y = canvas.height * CGFloat((i * 29 + 7) % 97) / 96
                        let w = max(CGFloat(2.5), CGFloat(3 + i % 4) * scale)
                        let rect = CGRect(x: x - w * 0.5, y: y - w * 0.32, width: w, height: w * 0.64)
                        context.fill(Path(ellipseIn: rect), with: .color((i % 4 == 0 ? Color.white : Color.pink).opacity(0.72)))
                    }
                }
            }

        case .oceanCurrent:
            ZStack {
                LinearGradient(colors: [Color.blue.opacity(0.15), Color.cyan.opacity(0.08), .clear], startPoint: .bottomLeading, endPoint: .topTrailing)
                Canvas { context, canvas in
                    for i in 0..<7 {
                        let y = canvas.height * (0.12 + CGFloat(i) * 0.13)
                        var wave = Path(); wave.move(to: CGPoint(x: -20, y: y))
                        wave.addCurve(to: CGPoint(x: canvas.width * 0.52, y: y), control1: CGPoint(x: canvas.width * 0.14, y: y - 18 * scale), control2: CGPoint(x: canvas.width * 0.34, y: y + 18 * scale))
                        wave.addCurve(to: CGPoint(x: canvas.width + 20, y: y), control1: CGPoint(x: canvas.width * 0.68, y: y - 18 * scale), control2: CGPoint(x: canvas.width * 0.88, y: y + 18 * scale))
                        context.stroke(wave, with: .color((i.isMultiple(of: 2) ? Color.cyan : tint).opacity(0.56)), lineWidth: max(1.3, 2.3 * scale))
                    }
                }
            }

        case .emberCore:
            ZStack {
                RadialGradient(colors: [Color.orange.opacity(0.48), Color.red.opacity(0.20), .clear], center: .bottom, startRadius: 0, endRadius: max(size.width, size.height) * 0.72)
                Canvas { context, canvas in
                    for i in 0..<30 {
                        let x = canvas.width * CGFloat((i * 53 + 9) % 101) / 100
                        let y = canvas.height * CGFloat((i * 67 + 21) % 97) / 96
                        let r = max(CGFloat(1.2), CGFloat(1 + i % 3) * scale)
                        context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color((i % 3 == 0 ? Color.yellow : Color.orange).opacity(0.78)))
                        if i % 4 == 0 {
                            var streak = Path(); streak.move(to: CGPoint(x: x, y: y)); streak.addLine(to: CGPoint(x: x + 2 * scale, y: y - 10 * scale))
                            context.stroke(streak, with: .color(Color.red.opacity(0.52)), lineWidth: max(0.9, 1.2 * scale))
                        }
                    }
                }
            }

        case .blueprint:
            Canvas { context, canvas in
                let minor = max(CGFloat(8), 12 * scale)
                let major = minor * 4
                var x: CGFloat = 0
                while x <= canvas.width {
                    var line = Path(); line.move(to: CGPoint(x: x, y: 0)); line.addLine(to: CGPoint(x: x, y: canvas.height))
                    let isMajor = Int((x / minor).rounded()).isMultiple(of: 4)
                    context.stroke(line, with: .color((isMajor ? Color.cyan : tint).opacity(isMajor ? 0.60 : 0.24)), lineWidth: isMajor ? 1.2 : 0.7)
                    x += minor
                }
                var y: CGFloat = 0
                while y <= canvas.height {
                    var line = Path(); line.move(to: CGPoint(x: 0, y: y)); line.addLine(to: CGPoint(x: canvas.width, y: y))
                    let isMajor = Int((y / minor).rounded()).isMultiple(of: 4)
                    context.stroke(line, with: .color((isMajor ? Color.cyan : tint).opacity(isMajor ? 0.60 : 0.24)), lineWidth: isMajor ? 1.2 : 0.7)
                    y += minor
                }
                let guide = CGRect(x: canvas.width * 0.62, y: canvas.height * 0.16, width: min(major * 1.35, canvas.width * 0.30), height: min(major * 1.35, canvas.height * 0.62))
                context.stroke(Path(ellipseIn: guide), with: .color(Color.white.opacity(0.34)), lineWidth: 1)
            }

        case .matrixRain:
            Canvas { context, canvas in
                let column = max(CGFloat(8), 13 * scale)
                let cell = max(CGFloat(2), 3.4 * scale)
                var x: CGFloat = column * 0.5
                var col = 0
                while x < canvas.width {
                    let head = CGFloat((col * 41 + 17) % max(1, Int(canvas.height + 80))) - 20
                    for segment in 0..<10 {
                        let y = head - CGFloat(segment) * cell * 1.9
                        guard y >= -cell && y <= canvas.height + cell else { continue }
                        let alpha = max(0.10, 0.90 - Double(segment) * 0.085)
                        let rect = CGRect(x: x - cell * 0.36, y: y, width: cell * 0.72, height: cell * 1.25)
                        context.fill(Path(rect), with: .color((segment == 0 ? Color.white : Color.green).opacity(alpha)))
                    }
                    x += column; col += 1
                }
            }

        case .nebula:
            ZStack {
                RadialGradient(colors: [Color.purple.opacity(0.48), Color.blue.opacity(0.18), .clear], center: UnitPoint(x: 0.28, y: 0.36), startRadius: 0, endRadius: max(size.width, size.height) * 0.72)
                RadialGradient(colors: [Color.pink.opacity(0.34), tint.opacity(0.15), .clear], center: UnitPoint(x: 0.76, y: 0.68), startRadius: 0, endRadius: max(size.width, size.height) * 0.62)
                Canvas { context, canvas in
                    for i in 0..<38 {
                        let x = canvas.width * CGFloat((i * 59 + 5) % 101) / 100
                        let y = canvas.height * CGFloat((i * 37 + 23) % 97) / 96
                        let r = max(CGFloat(0.8), CGFloat((i % 3) + 1) * 0.65 * scale)
                        context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Color.white.opacity(i % 6 == 0 ? 0.90 : 0.52)))
                    }
                }
            }
        }
    }
}

private struct OpenNotchBackgroundView: View {
    let options: OpenNotchAppearance
    let fallback: Appearance
    let theme: Theme
    @ObservedObject var system: SystemService

    private var effectiveAppearance: Appearance { options.baseAppearance(fallback) }

    var body: some View {
        filteredBackground
            .overlay((options.tintColor ?? WidgetColor(red: 0.35, green: 0.55, blue: 1)).color.opacity(options.tintOpacity ?? 0))
            .overlay(Color.orange.opacity(max(0, options.warmth ?? 0) * 0.06))
            .overlay(Color.blue.opacity(max(0, -(options.warmth ?? 0)) * 0.05))
            .overlay {
                if (options.grain ?? 0) > 0 {
                    Canvas { context, size in
                        let amount = min(0.35, max(0, options.grain ?? 0))
                        let step: CGFloat = 7
                        var x: CGFloat = 1
                        var seed: UInt64 = UInt64(size.width * 31 + size.height * 17)
                        while x < size.width {
                            var y: CGFloat = 1
                            while y < size.height {
                                seed = seed &* 2862933555777941757 &+ 3037000493
                                let n = Double((seed >> 33) & 255) / 255.0
                                if n > 0.64 { context.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(.white.opacity(amount * 0.18))) }
                                y += step
                            }
                            x += step
                        }
                    }.allowsHitTesting(false)
                }
            }
    }

    @ViewBuilder private var filteredBackground: some View {
        if effectiveAppearance.background == .glass {
            // Preserve NSVisualEffectView's behind-window sampling; SwiftUI image filters
            // around the native glass can flatten it into an offscreen texture.
            SurfaceBackground(appearance: effectiveAppearance, theme: theme, expanded: true, system: system)
        } else {
            SurfaceBackground(appearance: effectiveAppearance, theme: theme, expanded: true, system: system)
                .contrast(options.contrast ?? 1)
        }
    }

}

private struct OpenNotchSurfaceChrome: View {
    let contour: HaloContour
    let options: OpenNotchAppearance
    var body: some View {
        ZStack {
            if (options.borderWidth ?? 0) > 0 {
                contour.stroke((options.borderColor ?? .white).color.opacity(options.borderOpacity ?? 0.2), lineWidth: options.borderWidth ?? 0)
            }
            if (options.innerHighlight ?? 0) > 0 {
                contour.stroke(.white.opacity(options.innerHighlight ?? 0), lineWidth: 1).padding(1)
            }
            if (options.glow ?? 0) > 0 {
                contour.stroke(.white.opacity((options.glow ?? 0) * 0.32), lineWidth: 1.2)
                    .shadow(color: .white.opacity(options.glow ?? 0), radius: 12)
            }
            if (options.shadowOpacity ?? 0) > 0 {
                contour.stroke(.black.opacity(options.shadowOpacity ?? 0), lineWidth: 1)
                    .shadow(color: .black.opacity(options.shadowOpacity ?? 0), radius: options.shadowBlur ?? 12, y: 3)
            }
        }.allowsHitTesting(false)
    }
}

@MainActor
private struct OpenNotchRuntimeContext {
    let store: AppStore
    var battery: Double? { store.workspace.system.battery.map(Double.init) }
    var cpu: Double { store.workspace.system.cpuUsage }
    var valueForMetric: (OpenNotchVisibilityMetric) -> Double? {
        { metric in
            switch metric {
            case .always: return 1
            case .batteryLevel: return battery
            case .charging: return store.workspace.system.charging ? 1 : 0
            case .mediaPlaying: return store.workspace.media.isPlaying ? 1 : 0
            case .timerActive: return (store.deadline != nil || store.pausedSeconds > 0) ? 1 : 0
            case .stopwatchRunning: return store.workspace.stopwatchStart != nil ? 1 : 0
            case .cpuUsage: return cpu
            case .lowPowerMode: return store.workspace.system.lowPower ? 1 : 0
            }
        }
    }
    func matches(_ rule: OpenNotchVisibilityRule) -> Bool {
        guard let lhs = valueForMetric(rule.metric) else { return false }
        let rhs = rule.value
        switch rule.comparison {
        case .equal: return abs(lhs - rhs) < 0.0001
        case .notEqual: return abs(lhs - rhs) >= 0.0001
        case .lessThan: return lhs < rhs
        case .lessThanOrEqual: return lhs <= rhs
        case .greaterThan: return lhs > rhs
        case .greaterThanOrEqual: return lhs >= rhs
        }
    }
    func isVisible(_ item: OpenNotchItem) -> Bool {
        guard !item.hidden else { return false }
        guard !item.visibilityRules.isEmpty else { return true }
        switch item.visibilityLogic {
        case .all: return item.visibilityRules.allSatisfy(matches)
        case .any: return item.visibilityRules.contains(where: matches)
        }
    }
}

private struct OpenNotchWorkspaceView: View {
    let layout: WorkspaceLayout
    @ObservedObject var store: AppStore
    let mode: OpenNotchContentMode
    @Binding var page: Int
    let closingPowerOnly: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var opened: OpenNotchLayout { layout.resolvedOpenNotchLayout }
    private var regions: [OpenNotchRegion] { opened.regions.sorted { $0.placement.sortIndex < $1.placement.sortIndex } }
    private var groups: [OpenNotchGroup] { regions.flatMap(\.groups) }
    private var gap: CGFloat { max(4, CGFloat(layout.appearance.spacing)) }

    var body: some View {
        Group {
            switch mode {
            case .fixed: directFixedCanvas
            case .scroll: directScrollCanvas
            case .pages: directPagesCanvas
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86), value: opened)
        .clipped()
    }

    private var directItems: [OpenNotchItem] {
        let runtime = OpenNotchRuntimeContext(store: store)
        let visible = opened.resolvedGridItems.filter(runtime.isVisible)
        return closingPowerOnly ? visible.filter { $0.module == .pet } : visible
    }

    private var directColumns: Int { opened.resolvedGridColumns }
    private var directRows: Int { opened.requiredGridRows }
    private var directGap: CGFloat { CGFloat(opened.resolvedGridGap) }
    private var directPadding: OpenNotchInsets {
        let configured = opened.resolvedGridPadding
        // Top keeps its contour-safe minimum. The other workspace margins are
        // intentionally user-controlled all the way down to zero.
        return OpenNotchInsets(
            top: max(configured.top, 10),
            leading: max(configured.leading, 0),
            bottom: max(configured.bottom, 0),
            trailing: max(configured.trailing, 0)
        )
    }

    private var directFixedCanvas: some View {
        GeometryReader { proxy in
            let rows = max(1, directRows)
            directGrid(items: directItems, canvasSize: proxy.size, rows: rows, rowOffset: 0,
                       fixedCellHeight: nil)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var directScrollCanvas: some View {
        GeometryReader { proxy in
            let rows = max(1, directRows)
            let padding = directPadding
            let contentHeight = CGFloat(padding.top + padding.bottom)
                + CGFloat(rows) * CGFloat(opened.resolvedGridCellHeight)
                + CGFloat(max(0, rows - 1)) * directGap
            ScrollView(.vertical) {
                directGrid(items: directItems, canvasSize: CGSize(width: proxy.size.width, height: contentHeight),
                           rows: rows, rowOffset: 0, fixedCellHeight: CGFloat(opened.resolvedGridCellHeight))
                    .frame(width: proxy.size.width, height: contentHeight)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var directPagesCanvas: some View {
        let rowsPerPage = max(1, opened.resolvedGridRows)
        let pageCount = max(1, Int(ceil(Double(max(1, directRows)) / Double(rowsPerPage))))
        let safePage = min(max(0, page), pageCount - 1)
        return VStack(spacing: 5) {
            GeometryReader { proxy in
                let startRow = safePage * rowsPerPage
                let pageItems = directItems.filter { item in
                    guard let placement = item.gridPlacement else { return false }
                    return placement.row < startRow + rowsPerPage && placement.row + placement.rowSpan > startRow
                }
                directGrid(items: pageItems, canvasSize: proxy.size, rows: rowsPerPage,
                           rowOffset: startRow, fixedCellHeight: nil)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
            if pageCount > 1 {
                HStack(spacing: 10) {
                    Button { page = max(0, safePage - 1) } label: { Image(systemName: "chevron.left") }.disabled(safePage == 0)
                    Text("Page \(safePage + 1) of \(pageCount)").font(.caption2).foregroundStyle(.secondary)
                    Button { page = min(pageCount - 1, safePage + 1) } label: { Image(systemName: "chevron.right") }.disabled(safePage == pageCount - 1)
                }
                .controlSize(.mini)
            }
        }
    }

    private func directGrid(items: [OpenNotchItem], canvasSize: CGSize, rows: Int,
                            rowOffset: Int, fixedCellHeight: CGFloat?) -> some View {
        let padding = directPadding
        let innerWidth = max(1, canvasSize.width - CGFloat(padding.leading + padding.trailing))
        let innerHeight = max(1, canvasSize.height - CGFloat(padding.top + padding.bottom))
        let columns = max(1, directColumns)
        let safeRows = max(1, rows)
        let cellWidth = max(1, (innerWidth - directGap * CGFloat(max(0, columns - 1))) / CGFloat(columns))
        let cellHeight = fixedCellHeight ?? max(1, (innerHeight - directGap * CGFloat(max(0, safeRows - 1))) / CGFloat(safeRows))
        return ZStack(alignment: .topLeading) {
            ForEach(items) { item in
                if let raw = item.gridPlacement {
                    let placement = raw.clamped(columns: columns)
                    let localRow = placement.row - rowOffset
                    let visibleStart = max(0, localRow)
                    let visibleEnd = min(safeRows, localRow + placement.rowSpan)
                    if visibleEnd > visibleStart {
                        let visibleRows = visibleEnd - visibleStart
                        let width = cellWidth * CGFloat(placement.columnSpan) + directGap * CGFloat(max(0, placement.columnSpan - 1))
                        let height = cellHeight * CGFloat(visibleRows) + directGap * CGFloat(max(0, visibleRows - 1))
                        let x = CGFloat(padding.leading) + CGFloat(placement.column) * (cellWidth + directGap)
                        let y = CGFloat(padding.top) + CGFloat(visibleStart) * (cellHeight + directGap)
                        let slot = CGSize(width: max(1, width), height: max(1, height))
                        OpenNotchItemView(item: item, layout: layout, store: store,
                                          compression: compressionForDirectSlot(slot), slotSize: slot)
                            .frame(width: slot.width, height: slot.height)
                            .position(x: x + slot.width / 2, y: y + slot.height / 2)
                    }
                }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
    }

    private func compressionForDirectSlot(_ size: CGSize) -> Int {
        let widthRatio = size.width / 300
        let heightRatio = size.height / 180
        let ratio = min(widthRatio, heightRatio)
        if ratio >= 1 { return 0 }
        if ratio >= 0.82 { return 1 }
        if ratio >= 0.66 { return 2 }
        if ratio >= 0.50 { return 3 }
        if ratio >= 0.36 { return 4 }
        return 5
    }

    @ViewBuilder private var fixedCanvas: some View {
        if opened.usesFreeformRegions {
            freeformCanvas
        } else {
            legacyFixedCanvas
        }
    }

    private var freeformCanvas: some View {
        GeometryReader { proxy in
            let canvas = proxy.size
            ZStack(alignment: .topLeading) {
                ForEach(regions) { region in
                    let raw = region.frame ?? fallbackFrame(for: region.placement)
                    let x = min(1, max(0, raw.x))
                    let y = min(1, max(0, raw.y))
                    let width = min(1 - x, max(0.01, raw.width))
                    let height = min(1 - y, max(0.01, raw.height))
                    let regionWidth = max(1, canvas.width * CGFloat(width))
                    let regionHeight = max(1, canvas.height * CGFloat(height))
                    OpenNotchRegionView(region: region, layout: layout, store: store)
                        .frame(width: regionWidth, height: regionHeight)
                        .position(x: canvas.width * CGFloat(x) + regionWidth / 2,
                                  y: canvas.height * CGFloat(y) + regionHeight / 2)
                }
            }
            .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        }
    }

    private var legacyFixedCanvas: some View {
        GeometryReader { proxy in
            let heights = trackSizes(total: proxy.size.height, weights: effectiveRowWeights, gaps: 2)
            VStack(spacing: gap) {
                regionRow([.topLeft, .topCenter, .topRight], height: heights[0])
                regionRow([.middleLeft, .middleCenter, .middleRight], height: heights[1])
                regionRow([.bottomLeft, .bottomCenter, .bottomRight], height: heights[2])
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
    }

    private func fallbackFrame(for placement: OpenNotchRegionPlacement) -> OpenNotchRegionFrame {
        let column: Double
        let row: Double
        switch placement {
        case .topLeft, .middleLeft, .bottomLeft: column = 0
        case .topCenter, .middleCenter, .bottomCenter: column = 1
        case .topRight, .middleRight, .bottomRight: column = 2
        }
        switch placement {
        case .topLeft, .topCenter, .topRight: row = 0
        case .middleLeft, .middleCenter, .middleRight: row = 1
        case .bottomLeft, .bottomCenter, .bottomRight: row = 2
        }
        return OpenNotchRegionFrame(x: column / 3, y: row / 3, width: 1.0 / 3, height: 1.0 / 3)
    }

    private func regionRow(_ placements: [OpenNotchRegionPlacement], height: CGFloat) -> some View {
        GeometryReader { proxy in
            let widths = trackSizes(total: proxy.size.width, weights: effectiveColumnWeights, gaps: 2)
            HStack(spacing: gap) {
                ForEach(0..<3, id: \.self) { index in
                    let placement = placements[index]
                    let cellWidth = widths[index]
                    ZStack(alignment: placement.regionAlignment) {
                        if let value = region(placement) {
                            OpenNotchRegionView(region: value, layout: layout, store: store)
                                .frame(width: max(1, cellWidth * CGFloat(value.resolvedWidthFraction)),
                                       height: max(1, height * CGFloat(value.resolvedHeightFraction)),
                                       alignment: placement.regionAlignment)
                                .clipped()
                        }
                    }
                    .frame(width: cellWidth, height: max(0, height), alignment: placement.regionAlignment)
                    .clipped()
                }
            }
        }
        .frame(height: max(0, height))
    }

    private var scrollCanvas: some View {
        Group {
            if layout.horizontalWidgets ?? false {
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: layout.appearance.spacing) {
                        ForEach(groups) { group in OpenNotchGroupView(group: group, layout: layout, store: store).frame(minWidth: 220) }
                    }
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: layout.appearance.spacing) {
                        ForEach(groups) { group in OpenNotchGroupView(group: group, layout: layout, store: store) }
                    }
                }
            }
        }
    }

    private var pagesCanvas: some View {
        VStack(spacing: 8) {
            if groups.isEmpty {
                Text("Enable widgets or add opened-notch elements in Settings.").foregroundStyle(.secondary)
            } else {
                let index = min(max(0, page), groups.count - 1)
                OpenNotchGroupView(group: groups[index], layout: layout, store: store, constrained: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack {
                    Button { page = max(0, index - 1) } label: { Image(systemName: "chevron.left") }.disabled(index == 0)
                    Spacer(); Text("\(groups[index].name) · \(index + 1) / \(groups.count)").font(.caption); Spacer()
                    Button { page = min(groups.count - 1, index + 1) } label: { Image(systemName: "chevron.right") }.disabled(index == groups.count - 1)
                }
            }
        }
    }

    private var effectiveRowWeights: [Double] {
        let occupied = [0, 1, 2].map { row in regions.contains { $0.placement.rowIndex == row } }
        return zip(opened.resolvedRowWeights, occupied).map { $1 ? $0 : 0 }
    }
    private var effectiveColumnWeights: [Double] {
        let occupied = [0, 1, 2].map { column in regions.contains { $0.placement.columnIndex == column } }
        return zip(opened.resolvedColumnWeights, occupied).map { $1 ? $0 : 0 }
    }
    private func trackSizes(total: CGFloat, weights: [Double], gaps: Int) -> [CGFloat] {
        let usable = max(0, total - gap * CGFloat(gaps))
        let positive = weights.map { max(0, $0) }
        let sum = positive.reduce(0, +)
        guard sum > 0 else { return [usable / 3, usable / 3, usable / 3] }
        return positive.map { usable * CGFloat($0 / sum) }
    }
    private func region(_ placement: OpenNotchRegionPlacement) -> OpenNotchRegion? { regions.first { $0.placement == placement } }
}

private struct OpenNotchRegionView: View {
    let region: OpenNotchRegion
    let layout: WorkspaceLayout
    @ObservedObject var store: AppStore
    var body: some View {
        GeometryReader { proxy in
            let groupGap = max(4, CGFloat(layout.appearance.spacing))
            let innerWidth = max(0, proxy.size.width - CGFloat(region.padding.leading + region.padding.trailing))
            let innerHeight = max(0, proxy.size.height - CGFloat(region.padding.top + region.padding.bottom))
            let count = max(1, region.groups.count)
            let groupHeight = max(0, (innerHeight - groupGap * CGFloat(max(0, count - 1))) / CGFloat(count))
            VStack(spacing: groupGap) {
                ForEach(region.groups) { group in
                    OpenNotchGroupView(group: group, layout: layout, store: store, constrained: true, standardBlocks: true)
                        .frame(width: innerWidth, height: groupHeight)
                }
            }
            .padding(.top, region.padding.top).padding(.leading, region.padding.leading)
            .padding(.bottom, region.padding.bottom).padding(.trailing, region.padding.trailing)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: region.placement.regionAlignment)
        }
    }
}

private struct OpenNotchGroupView: View {
    let group: OpenNotchGroup
    let layout: WorkspaceLayout
    @ObservedObject var store: AppStore
    var constrained = false
    var standardBlocks = false
    private var context: OpenNotchRuntimeContext { OpenNotchRuntimeContext(store: store) }

    var body: some View {
        GeometryReader { proxy in
            let innerWidth = max(0, proxy.size.width - CGFloat(group.padding.leading + group.padding.trailing))
            let innerHeight = max(0, proxy.size.height - CGFloat(group.padding.top + group.padding.bottom))
            let candidates = group.items.filter { $0.kind == .module && $0.module != nil }.filter(context.isVisible)
            let mainAvailable = group.axis == .horizontal ? innerWidth : innerHeight
            let crossAvailable = group.axis == .horizontal ? innerHeight : innerWidth
            let wanted = preferredLength(of: candidates) + max(0, CGFloat(candidates.count - 1)) * CGFloat(group.spacing)
            let mainCompression = compressionLevel(available: mainAvailable, wanted: wanted)
            let crossCompression = compressionLevel(available: crossAvailable, wanted: preferredCrossLength(of: candidates))
            let compression = max(mainCompression, crossCompression)
            let spacing = max(2, CGFloat(group.spacing) * (compression >= 1 ? 0.62 : 1))
            // A module explicitly placed in a Visual Workspace region is structural content.
            // Never remove the whole widget just because its slot is small; its internals
            // collapse first. Priority-based removal still applies to lightweight elements.
            let visible = candidates.filter { item in
                if standardBlocks && item.kind == .module { return true }
                return item.priority.remainsVisible(at: compression)
            }
            let lengths = allocatedLengths(items: visible, available: mainAvailable, spacing: spacing, compression: compression)
            let minimumNeeded = minimumLength(of: visible) + max(0, CGFloat(visible.count - 1)) * spacing

            Group {
                if !standardBlocks && compression >= 5 && minimumNeeded > mainAvailable + 1 {
                    ScrollView(group.axis == .horizontal ? .horizontal : .vertical) {
                        stack(items: visible, spacing: spacing, compression: compression, crossAvailable: crossAvailable, lengths: lengths)
                    }
                } else {
                    stack(items: visible, spacing: spacing, compression: compression, crossAvailable: crossAvailable, lengths: lengths)
                }
            }
            .frame(width: innerWidth, height: innerHeight, alignment: group.alignment.horizontalFrameAlignment)
            .padding(.top, group.padding.top).padding(.leading, group.padding.leading)
            .padding(.bottom, group.padding.bottom).padding(.trailing, group.padding.trailing)
        }
        .frame(minHeight: constrained ? 0 : estimatedHeight, maxHeight: constrained ? .infinity : nil)
    }

    @ViewBuilder private func stack(items: [OpenNotchItem], spacing: CGFloat, compression: Int,
                                    crossAvailable: CGFloat, lengths: [UUID: CGFloat]) -> some View {
        if group.axis == .horizontal {
            HStack(alignment: group.alignment.verticalAlignment, spacing: standardBlocks ? 0 : spacing) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let size = CGSize(width: max(1, lengths[item.id] ?? CGFloat(item.sizing.minimumWidth)), height: max(1, crossAvailable))
                    OpenNotchItemView(item: item, layout: layout, store: store, compression: compression, slotSize: size)
                    if standardBlocks && index < items.count - 1 { Divider().opacity(0.20).padding(.vertical, 8) }
                }
            }.frame(maxHeight: .infinity, alignment: group.alignment.horizontalFrameAlignment)
        } else {
            VStack(alignment: group.alignment.horizontalAlignment, spacing: standardBlocks ? 0 : spacing) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let size = CGSize(width: max(1, crossAvailable), height: max(1, lengths[item.id] ?? CGFloat(item.sizing.minimumHeight)))
                    OpenNotchItemView(item: item, layout: layout, store: store, compression: compression, slotSize: size)
                    if standardBlocks && index < items.count - 1 { Divider().opacity(0.20).padding(.horizontal, 8) }
                }
            }.frame(maxWidth: .infinity, alignment: group.alignment.horizontalFrameAlignment)
        }
    }

    private func preferredLength(of items: [OpenNotchItem]) -> CGFloat {
        items.reduce(0) { partial, item in
            partial + CGFloat(group.axis == .horizontal ? item.sizing.preferredWidth : item.sizing.preferredHeight)
        }
    }
    private func minimumLength(of items: [OpenNotchItem]) -> CGFloat {
        items.reduce(0) { partial, item in
            partial + CGFloat(group.axis == .horizontal ? item.sizing.minimumWidth : item.sizing.minimumHeight)
        }
    }
    private func preferredCrossLength(of items: [OpenNotchItem]) -> CGFloat {
        items.map { item in
            CGFloat(group.axis == .horizontal ? item.sizing.preferredHeight : item.sizing.preferredWidth)
        }.max() ?? 0
    }
    private func bounds(for item: OpenNotchItem) -> (min: CGFloat, preferred: CGFloat, max: CGFloat) {
        if group.axis == .horizontal {
            return (CGFloat(item.sizing.minimumWidth), CGFloat(item.sizing.preferredWidth), CGFloat(item.sizing.maximumWidth))
        }
        return (CGFloat(item.sizing.minimumHeight), CGFloat(item.sizing.preferredHeight), CGFloat(item.sizing.maximumHeight))
    }
    private func allocatedLengths(items: [OpenNotchItem], available: CGFloat, spacing: CGFloat, compression: Int) -> [UUID: CGFloat] {
        guard !items.isEmpty else { return [:] }
        let effectiveSpacing: CGFloat = standardBlocks ? 0 : spacing
        let usable = max(0, available - effectiveSpacing * CGFloat(max(0, items.count - 1)))
        if standardBlocks {
            let share = max(1, usable / CGFloat(items.count))
            return Dictionary(uniqueKeysWithValues: items.map { ($0.id, share) })
        }
        var values: [UUID: CGFloat] = [:]
        for item in items {
            let b = bounds(for: item)
            let start: CGFloat
            switch item.sizing.mode {
            case .fill: start = b.min
            case .fixed, .fitContent, .flexible: start = min(b.max, max(b.min, b.preferred))
            }
            values[item.id] = start
        }

        var total = values.values.reduce(0, +)
        if total > usable {
            var deficit = total - usable
            for _ in 0..<3 where deficit > 0.5 {
                let shrinkable = items.filter { (values[$0.id] ?? 0) > bounds(for: $0).min + 0.5 }
                guard !shrinkable.isEmpty else { break }
                let capacity = shrinkable.reduce(CGFloat(0)) { $0 + max(0, (values[$1.id] ?? 0) - bounds(for: $1).min) }
                guard capacity > 0 else { break }
                for item in shrinkable {
                    let current = values[item.id] ?? 0
                    let minValue = bounds(for: item).min
                    let share = (current - minValue) / capacity
                    let cut = min(current - minValue, deficit * share)
                    values[item.id] = current - cut
                }
                total = values.values.reduce(0, +); deficit = max(0, total - usable)
            }
            // Before the final scroll stage, the slot remains authoritative even
            // if a user's minimum sizes cannot all fit. This prevents overlap.
            if deficit > 0.5 && compression < 5 && total > 0 {
                let scale = max(0.1, usable / total)
                for item in items { values[item.id] = max(1, (values[item.id] ?? 1) * scale) }
            }
        } else if total < usable {
            var extra = usable - total
            let growers = items.filter { $0.sizing.mode == .fill || $0.sizing.mode == .flexible }
            for _ in 0..<3 where extra > 0.5 && !growers.isEmpty {
                let active = growers.filter { (values[$0.id] ?? 0) < bounds(for: $0).max - 0.5 }
                guard !active.isEmpty else { break }
                let weightTotal = active.reduce(CGFloat(0)) { $0 + ($1.sizing.mode == .fill ? 2 : 1) }
                for item in active {
                    let current = values[item.id] ?? 0
                    let maxValue = bounds(for: item).max
                    let weight: CGFloat = item.sizing.mode == .fill ? 2 : 1
                    let add = min(maxValue - current, extra * weight / weightTotal)
                    values[item.id] = current + add
                }
                total = values.values.reduce(0, +); extra = max(0, usable - total)
            }
        }
        return values
    }
    private var estimatedHeight: CGFloat {
        let widgetItems = group.items.filter { $0.kind == .module && $0.module != nil }
        let h = widgetItems.reduce(0.0) { $0 + min($1.sizing.preferredHeight, 260) } + max(0, Double(widgetItems.count - 1)) * group.spacing
        return CGFloat(min(720, max(54, h + group.padding.top + group.padding.bottom)))
    }
    private func compressionLevel(available: CGFloat, wanted: CGFloat) -> Int {
        guard wanted > 0, available > 0 else { return 0 }
        let ratio = available / wanted
        if ratio >= 1 { return 0 }
        if ratio >= 0.86 { return 1 }
        if ratio >= 0.72 { return 2 }
        if ratio >= 0.58 { return 3 }
        if ratio >= 0.44 { return 4 }
        return 5
    }
}

private struct OpenNotchItemView: View {
    let item: OpenNotchItem
    let layout: WorkspaceLayout
    @ObservedObject var store: AppStore
    let compression: Int
    let slotSize: CGSize
    @State private var hover = false

    var body: some View {
        let presentation = resolvedPresentation
        let style = adaptedWidgetStyle(presentation: presentation)
        let itemStyle = item.style ?? WidgetElementStyle()
        Group {
            switch item.kind {
            case .module:
                if let module = item.module {
                    // Visual Workspace items own their own presence and visibility.
                    // Do not also gate them through layout.enabled, which belongs to
                    // the legacy Modules/dashboard system and can become out of sync
                    // with saved Visual Workspace items across profiles.
                    WidgetCard(style: style, availableHeight: slotSize.height, availableWidth: slotSize.width, fillsCell: module == .pet) {
                        BuiltinOrIntegrationWidget(module: module, store: store)
                    }
                    .environment(\.openNotchPresentation, presentation)
                    .environment(\.openNotchCompressionLevel, compression)
                    .environment(\.openNotchAvailableWidth, slotSize.width)
                    .environment(\.openNotchAvailableHeight, slotSize.height)
                    .environment(\.openNotchGridColumnSpan, item.gridPlacement?.columnSpan)
                    .environment(\.openNotchGridRowSpan, item.gridPlacement?.rowSpan)
                    .environment(\.openNotchBlockVerticalAlignment, item.resolvedVerticalAlignment)
                }
            case .element:
                if let element = item.element {
                    WidgetElementSurface(element: itemStyle, widgetStyle: style, defaultPriority: item.priority) {
                        OpenNotchLightweightElement(kind: element, item: item, store: store)
                    }
                    .environment(\.openNotchPresentation, presentation)
                    .environment(\.openNotchCompressionLevel, compression)
                    .environment(\.openNotchAvailableWidth, slotSize.width)
                    .environment(\.openNotchAvailableHeight, slotSize.height)
                }
            case .spacer:
                Color.clear
            case .divider:
                Divider().opacity(itemStyle.opacity)
            }
        }
        .frame(width: slotSize.width, height: slotSize.height, alignment: itemStyle.alignment?.alignment ?? .center)
        // Visual Workspace slots are hard layout boundaries. Compact content may reflow,
        // but it must never draw into a neighbouring slot or back into the notch margin.
        .clipped()
        .contentShape(Rectangle())
        .opacity(hover ? 1 : 0.985)
        .onHover { hover = $0 }
        .modifier(OpenNotchInteractionModifier(item: item, store: store))
        .transition(.opacity.combined(with: .scale(scale: 0.975)))
    }

    private var resolvedPresentation: OpenNotchPresentation {
        let width = max(1, slotSize.width)
        let height = max(1, slotSize.height)
        let aspect = width / height
        let area = width * height
        let hardCompact = width < 132 || height < 58
        let shapeCompact = (aspect > 2.35 && height < 158) || (aspect < 0.62 && width < 205)
        let compact = hardCompact || shapeCompact || width < 225 || height < 104 || compression >= 3
        let expandedPossible = width >= 330 && height >= 185 && area >= 68_000 && compression < 2
        if hardCompact { return .compact }
        switch item.presentation {
        case .automatic:
            if compact { return .compact }
            return expandedPossible ? .expanded : .regular
        case .expanded:
            if compact { return .compact }
            return expandedPossible ? .expanded : .regular
        case .regular:
            return compact ? .compact : .regular
        case .compact:
            return .compact
        }
    }
    private func adaptedWidgetStyle(presentation: OpenNotchPresentation) -> WidgetStyle {
        guard let module = item.module else { return WidgetStyle() }
        var style = item.widgetStyle ?? layout.widgetStyle(for: module).visualWorkspacePolished(for: module)
        // The designed slot owns geometry in the custom workspace. A legacy
        // per-widget width must never push a card outside its region.
        style.width = 0
        style.minimumHeight = 0
        switch presentation {
        case .compact: style.layoutMode = .compact
        case .expanded: style.layoutMode = .hero
        case .regular, .automatic: style.layoutMode = .standard
        }
        let widthScale = min(1, max(0.50, slotSize.width / 300))
        let heightScale = min(1, max(0.50, slotSize.height / 170))
        let shapePressure = min(1, max(0.68, min(slotSize.width / max(1, slotSize.height), slotSize.height / max(1, slotSize.width)) * 1.8))
        let scale = min(widthScale, heightScale) * shapePressure
        style.padding *= max(0.48, scale)
        style.fontSize *= max(0.62, scale)
        var content = style.resolvedContent
        content.spacing = max(2, content.spacing * scale)
        content.iconSize = max(9, content.iconSize * scale)
        if compression >= 1 || slotSize.height < 155 || slotSize.width < 255 {
            content.showSecondaryText = false
            content.mediaShowArtist = slotSize.height >= 88 && slotSize.width >= 180
            content.mediaShowSource = false
            content.calendarShowTimes = slotSize.height >= 125 && slotSize.width >= 230
            content.shelfShowDetails = false
            content.activitiesShowDetail = false
        }
        if compression >= 2 || slotSize.height < 125 || slotSize.width < 215 {
            content.controlSize = .small
            content.showStatus = false
            content.maxItems = min(3, content.maxItems)
        }
        if compression >= 3 || slotSize.height < 100 || slotSize.width < 185 {
            content.controlSize = .mini
            content.maxItems = min(2, content.maxItems)
            content.showFooter = false
            content.showQuickActions = false
            content.showSearch = slotSize.height >= 92 && slotSize.width >= 175
        } else if slotSize.height < 180 {
            content.maxItems = min(3, content.maxItems)
        }
        if compression >= 4 || slotSize.width < 155 || slotSize.height < 78 {
            content.mediaTitleLines = 1
            content.maxItems = min(1, content.maxItems)
            content.calendarShowJoin = false
        }
        if compression >= 5 || slotSize.width < 125 || slotSize.height < 68 {
            style.showTitle = false
            style.showHeaderIcon = false
            style.padding = min(style.padding, 2)
            style.fontSize = min(style.fontSize, 11)
            content.spacing = min(content.spacing, 2)
            content.controlSize = .mini
            content.maxItems = 1
            content.showSecondaryText = false
            content.showStatus = false
            content.showFooter = false
            content.showQuickActions = false
            content.showSearch = false
            content.mediaShowArtist = false
            content.mediaShowSource = false
            content.calendarShowTimes = false
            content.calendarShowJoin = false
            content.shelfShowDetails = false
            content.activitiesShowDetail = false
        }
        style.content = content
        return style
    }
}

private struct OpenNotchLightweightElement: View {
    let kind: OpenNotchElementKind
    let item: OpenNotchItem
    @ObservedObject var store: AppStore
    @State private var image: NSImage?
    var body: some View {
        let workspace = store.workspace
        switch kind {
        case .clock:
            TimelineView(.periodic(from: .now, by: 1)) { context in Text(context.date, style: .time).monospacedDigit() }
        case .date: Text(Date(), style: .date)
        case .battery:
            if let battery = workspace.system.battery { Label("\(battery)%", systemImage: workspace.system.charging ? "battery.100.bolt" : "battery.100") }
        case .batteryPercentage:
            if let battery = workspace.system.battery { Text("\(battery)%").monospacedDigit() }
        case .chargingState:
            if workspace.system.charging { Label("Charging", systemImage: "bolt.fill") }
        case .appIcon:
            if let icon = NSWorkspace.shared.frontmostApplication?.icon { Image(nsImage: icon).resizable().scaledToFit().frame(width: item.style?.iconSize ?? 24, height: item.style?.iconSize ?? 24) }
        case .appName: Text(NSWorkspace.shared.frontmostApplication?.localizedName ?? "")
        case .volume:
            if workspace.audio.canSetVolume {
                HStack { Image(systemName: "speaker.wave.2"); Slider(value: Binding(get: { Double(workspace.audio.volume) }, set: { workspace.audio.setVolume(Float($0)) }), in: 0...1) { Text("Volume") }; Text("\(Int(workspace.audio.volume * 100))%").monospacedDigit() }
            }
        case .brightness:
            if let brightness = workspace.system.brightness {
                HStack { Image(systemName: "sun.max"); Slider(value: Binding(get: { brightness }, set: { workspace.system.setBrightness($0) }), in: 0...1) { Text("Brightness") } }
            }
        case .timer:
            if let deadline = store.deadline { Text(deadline, style: .timer).monospacedDigit() }
            else if store.pausedSeconds > 0 { Text("Paused · \(Int(store.pausedSeconds))s").monospacedDigit() }
            else { Text("Timer ready") }
        case .stopwatch:
            TimelineView(.periodic(from: .now, by: 0.2)) { context in
                let elapsed = workspace.stopwatchElapsed + (workspace.stopwatchStart.map { context.date.timeIntervalSince($0) } ?? 0)
                Text(String(format: "%02d:%02d:%02d", Int(elapsed) / 3600, Int(elapsed) / 60 % 60, Int(elapsed) % 60)).monospacedDigit()
            }
        case .mediaTitle: if workspace.media.connectedApp != nil { Text(workspace.media.title).lineLimit(1) }
        case .artist: if !workspace.media.artist.isEmpty { Text(workspace.media.artist).lineLimit(1) }
        case .albumArt:
            if let art = workspace.media.artworkImage { Image(nsImage: art).resizable().scaledToFill().clipShape(RoundedRectangle(cornerRadius: 8)) }
        case .playbackControls:
            if workspace.media.connectedApp != nil {
                HStack {
                    Button { workspace.media.perform("previous track", app: workspace.settings.mediaApp) } label: { Image(systemName: "backward.end.fill") }
                    Button { workspace.media.perform("playpause", app: workspace.settings.mediaApp) } label: { Image(systemName: workspace.media.isPlaying ? "pause.fill" : "play.fill") }
                    Button { workspace.media.perform("next track", app: workspace.settings.mediaApp) } label: { Image(systemName: "forward.end.fill") }
                }
            }
        case .playbackProgress:
            if workspace.media.duration > 0 {
                Slider(value: Binding(get: { workspace.media.position }, set: { workspace.media.seek(to: $0) }), in: 0...max(1, workspace.media.duration)) { Text("Playback progress") }
            }
        case .cpu: Label(String(format: "CPU %.0f%%", workspace.system.cpuUsage), systemImage: "cpu")
        case .ram: Label(String(format: "RAM %.0f%%", workspace.system.memoryUsage), systemImage: "memorychip")
        case .storage: Label(String(format: "Disk %.0f%%", workspace.system.diskUsage), systemImage: "internaldrive")
        case .networkActivity:
            Label("↓ \(Self.rate(workspace.system.networkDownPerSecond))  ↑ \(Self.rate(workspace.system.networkUpPerSecond))", systemImage: "network")
        case .customText: Text(item.customText)
        case .customIcon: Image(systemName: item.customIcon.isEmpty ? "sparkles" : item.customIcon).font(.system(size: item.style?.iconSize ?? 20))
        case .customImage, .customGIF:
            if let image { Image(nsImage: image).resizable().scaledToFit() }
            else { Image(systemName: "photo").foregroundStyle(.secondary).task { image = NSImage(contentsOfFile: item.customAssetPath) } }
        case .button:
            Button(item.buttonLabel) { if let url = URL(string: item.buttonURL), ["https", "http", "shortcuts"].contains(url.scheme?.lowercased() ?? "") { NSWorkspace.shared.open(url) } }
        case .spacer: Spacer(minLength: 8)
        case .divider: Divider()
        }
    }
    private static func rate(_ value: Double) -> String { ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file) + "/s" }
}

private struct OpenNotchInteractionModifier: ViewModifier {
    let item: OpenNotchItem
    @ObservedObject var store: AppStore
    func body(content: Content) -> some View {
        content
            .onTapGesture(count: 2) { perform(item.interactions.doubleClick) }
            .simultaneousGesture(TapGesture(count: 1).onEnded {
                let modifiers = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
                perform(modifiers.isEmpty ? item.interactions.singleClick : item.interactions.modifierClick)
            })
            .contextMenu {
                if item.interactions.rightClick != .none { Button(item.interactions.rightClick.rawValue) { perform(item.interactions.rightClick) } }
            }
            .background {
                if item.interactions.scroll != .none { OpenNotchScrollCapture { perform(item.interactions.scroll, delta: $0) }.allowsHitTesting(true) }
            }
            .onDrag {
                if item.interactions.drag != .none { perform(item.interactions.drag) }
                return NSItemProvider(object: item.id.uuidString as NSString)
            }
    }
    private func perform(_ action: OpenNotchInteractionAction, delta: Double = 0) {
        let workspace = store.workspace
        switch action {
        case .none: break
        case .togglePlayback: workspace.media.perform("playpause", app: workspace.settings.mediaApp)
        case .nextTrack: workspace.media.perform("next track", app: workspace.settings.mediaApp)
        case .previousTrack: workspace.media.perform("previous track", app: workspace.settings.mediaApp)
        case .openPlayer:
            if let id = workspace.media.connectedApp, let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first { app.activate(options: .activateIgnoringOtherApps) }
        case .adjustVolume:
            guard workspace.audio.canSetVolume else { return }
            workspace.audio.setVolume(min(1, max(0, workspace.audio.volume + Float(delta > 0 ? 0.04 : -0.04))))
        case .seekMedia: if workspace.media.duration > 0 { workspace.media.seek(to: min(workspace.media.duration, max(0, workspace.media.position + (delta > 0 ? 5 : -5)))) }
        case .toggleTimer:
            if store.deadline != nil || store.pausedSeconds > 0 { store.pauseResume() } else { store.startTimer(minutes: 25) }
        case .toggleStopwatch: workspace.toggleStopwatch()
        case .openSystemSettings:
            if let url = URL(string: "x-apple.systempreferences:") { NSWorkspace.shared.open(url) }
        }
    }
}

private struct OpenNotchScrollCapture: NSViewRepresentable {
    let onScroll: (Double) -> Void
    final class View: NSView {
        var callback: ((Double) -> Void)?
        override func scrollWheel(with event: NSEvent) { callback?(event.scrollingDeltaY == 0 ? event.scrollingDeltaX : event.scrollingDeltaY) }
    }
    func makeNSView(context: Context) -> View { let v = View(); v.callback = onScroll; return v }
    func updateNSView(_ nsView: View, context: Context) { nsView.callback = onScroll }
}

private extension OpenNotchRegionPlacement {
    var sortIndex: Int { OpenNotchRegionPlacement.allCases.firstIndex(of: self) ?? 0 }
    var rowIndex: Int {
        switch self { case .topLeft, .topCenter, .topRight: return 0; case .middleLeft, .middleCenter, .middleRight: return 1; case .bottomLeft, .bottomCenter, .bottomRight: return 2 }
    }
    var columnIndex: Int {
        switch self { case .topLeft, .middleLeft, .bottomLeft: return 0; case .topCenter, .middleCenter, .bottomCenter: return 1; case .topRight, .middleRight, .bottomRight: return 2 }
    }
    var regionAlignment: Alignment {
        switch self {
        case .topLeft: return .topLeading; case .topCenter: return .top; case .topRight: return .topTrailing
        case .middleLeft: return .leading; case .middleCenter: return .center; case .middleRight: return .trailing
        case .bottomLeft: return .bottomLeading; case .bottomCenter: return .bottom; case .bottomRight: return .bottomTrailing
        }
    }
}
private extension OpenNotchGroupAlignment {
    var horizontalAlignment: HorizontalAlignment { switch self { case .center: return .center; case .trailing: return .trailing; default: return .leading } }
    var verticalAlignment: VerticalAlignment { switch self { case .center: return .center; case .trailing: return .bottom; default: return .top } }
    var horizontalFrameAlignment: Alignment { switch self { case .center: return .center; case .trailing: return .trailing; default: return .leading } }
}

private struct DropContextView: View {
    let itemCount: Int
    @ObservedObject var surfaceState: SurfaceState
    @ObservedObject private var dropZones = HaloDropZoneSettingsStore.shared
    @AppStorage("HaloContextDropUseFullNotchArea") private var usesFullNotchArea = true
    @AppStorage("HaloContextDropKeepClosedNotchContents") private var keepsClosedNotchContents = false

    private var count: Int { max(1, itemCount) }
    private var topInset: Double {
        if usesFullNotchArea && keepsClosedNotchContents { return max(24, surfaceState.compactHeight + 14) }
        if usesFullNotchArea { return max(22, surfaceState.compactHeight * 0.72) }
        return 22
    }
    private var preferredSize: CGSize {
        let configuration = dropZones.configuration
        let count = max(1, configuration.zones.count)
        let columns: Int
        switch configuration.layout {
        case .vertical: columns = 1
        case .horizontal: columns = count
        case .twoColumns: columns = 2
        case .threeColumns: columns = 3
        case .fourColumns: columns = 4
        case .spotlight: columns = 2
        case .adaptive: columns = count <= 2 ? count : count <= 4 ? 2 : count <= 6 ? 3 : 4
        }
        let rows = max(1, Int(ceil(Double(count) / Double(max(1, columns)))))
        let width: Double
        switch configuration.layout {
        case .vertical: width = 520
        case .horizontal: width = min(760, max(560, 118 * Double(count)))
        case .spotlight: width = 680
        default: width = count >= 5 ? 680 : 600
        }
        let rowHeight = count > 4 ? 76.0 : 92.0
        let height = 112 + Double(rows) * rowHeight + Double(max(0, rows - 1)) * configuration.zoneSpacing + max(0, topInset - 22)
        return CGSize(width: width, height: min(700, max(270, height)))
    }

    var body: some View {
        HaloDropCIBackgroundView(configuration: dropZones.configuration)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: usesFullNotchArea ? 0 : 20, style: .continuous))
            .task { publishPreferredSize() }
            .onChange(of: itemCount) { _ in publishPreferredSize() }
            .onChange(of: dropZones.configuration) { _ in publishPreferredSize() }
            .onDisappear {
                guard surfaceState.activeCIIdentifier == nil else { return }
                surfaceState.contextPreferredSize = nil
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Drop CI background for \(count) item\(count == 1 ? "" : "s")")
    }

    private func publishPreferredSize() {
        let next = preferredSize
        DispatchQueue.main.async { [surfaceState] in
            if let current = surfaceState.contextPreferredSize,
               abs(current.width - next.width) < 1, abs(current.height - next.height) < 1 { return }
            surfaceState.contextPreferredSize = next
        }
    }
}

struct BuiltinOrIntegrationWidget: View {
    let module: ModuleID
    @ObservedObject var store: AppStore
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchPresentation) private var presentation
    @Environment(\.openNotchCompressionLevel) private var compression
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @Environment(\.openNotchGridColumnSpan) private var gridColumnSpan
    @Environment(\.openNotchGridRowSpan) private var gridRowSpan
    @ViewBuilder var body: some View {
        switch module {
        case .clock: WidgetClock(style: style, workspace: store.workspace, store: store)
        case .timer:
            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceTimerView(store: store) }
            else { timer }
        case .shelf:
            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceAdaptiveModuleView(module: .shelf, store: store, workspace: store.workspace) }
            else { shelf }
        default: ModuleRegistry().view(for: module, store: store)
        }
    }

    @ViewBuilder
    private var timer: some View {
        let options = style.resolvedContent
        let remaining = max(0, store.deadline?.timeIntervalSinceNow ?? store.pausedSeconds)
        let duration = max(0, store.timerDurationSeconds)
        let progress = duration > 0 ? min(1, max(0, 1 - remaining / duration)) : (store.finished ? 1 : 0)
        let idle = store.deadline == nil && store.pausedSeconds <= 0 && !store.finished
        let footprintWidth = availableWidth ?? 390
        let footprintHeight = availableHeight ?? 310
        let horizontallyDominant =
            footprintWidth >= 300 &&
            footprintHeight >= 145 &&
            footprintWidth / max(1, footprintHeight) >= 1.45

        if idle && horizontallyDominant {
            HaloTimerHorizontalDurationComposer(
                accent: style.accentColor.color,
                textColor: style.textColor.color,
                quickPresets: [
                    options.timerPresetA,
                    options.timerPresetB,
                    options.timerPresetC,
                    45,
                    60
                ],
                initialMinutes: options.timerPresetB,
                compact: footprintHeight < 185
            ) { duration in
                store.startTimer(duration: duration)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

        } else {
            VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
                if style.showTitle {
                    HStack(spacing: max(4, options.spacing * 0.55)) {
                        if style.showsHeaderIcon {
                            Image(systemName: "timer")
                                .font(.system(size: options.iconSize))
                                .foregroundStyle(style.accentColor.color)
                        }
                        Text("Focus").font(style.font())
                    }
                }

                WidgetElement(key: "countdown") {
                    if let deadline = store.deadline {
                        Text(deadline, style: .timer)
                            .font(style.font(scale: 1.35))
                            .monospacedDigit()
                    } else if store.pausedSeconds > 0 {
                        Text(formatDuration(store.pausedSeconds))
                            .font(style.font(scale: 1.35))
                            .monospacedDigit()
                    } else {
                        Text("Ready").font(style.font(scale: 1.15))
                    }
                }

                if presentation != .compact {
                    WidgetElement(key: "progress", defaultPriority: .normal) {
                        ProgressView(value: progress)
                    }
                }

                if presentation == .expanded {
                    WidgetElement(key: "endTime", defaultVisible: false, defaultPriority: .low) {
                        if let deadline = store.deadline {
                            HStack {
                                Text("Finishes")
                                Spacer()
                                Text(deadline, style: .time)
                            }
                        } else if store.pausedSeconds > 0 {
                            Text("Paused with \(formatDuration(store.pausedSeconds)) remaining")
                        } else {
                            Text("Choose a duration to begin")
                        }
                    }
                }

                if options.showSecondaryText && presentation != .compact {
                    WidgetElement(key: "status") {
                        Label(
                            store.finished
                                ? "Session complete"
                                : store.deadline != nil
                                    ? "Deep work in progress"
                                    : store.pausedSeconds > 0
                                        ? "Session paused"
                                        : "Make room for deep work",
                            systemImage: store.finished
                                ? "checkmark.circle.fill"
                                : store.deadline != nil
                                    ? "brain.head.profile"
                                    : store.pausedSeconds > 0
                                        ? "pause.circle"
                                        : "sparkles"
                        )
                    }
                }

                if options.showControls {
                    if idle {
                        WidgetElement(key: "presets") {
                            let roomForTallComposer =
                                presentation != .compact &&
                                footprintWidth >= 400 &&
                                footprintHeight >= 500

                            if roomForTallComposer {
                                HaloTimerDurationComposer(
                                    accent: style.accentColor.color,
                                    textColor: style.textColor.color,
                                    quickPresets: [
                                        options.timerPresetA,
                                        options.timerPresetB,
                                        options.timerPresetC,
                                        45,
                                        60
                                    ],
                                    initialMinutes: options.timerPresetB,
                                    compact: false
                                ) { duration in
                                    store.startTimer(duration: duration)
                                }
                                .frame(maxWidth: min(390, footprintWidth))
                            } else {
                                HaloTimerDurationPopoverButton(
                                    accent: style.accentColor.color,
                                    textColor: style.textColor.color,
                                    quickPresets: [
                                        options.timerPresetA,
                                        options.timerPresetB,
                                        options.timerPresetC
                                    ],
                                    initialMinutes: options.timerPresetB,
                                    label: "Set timer"
                                ) { duration in
                                    store.startTimer(duration: duration)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    } else {
                        WidgetElement(key: "controls") {
                            HStack(spacing: max(6, options.spacing)) {
                                Button {
                                    store.pauseResume()
                                } label: {
                                    Label(
                                        store.deadline == nil ? "Resume" : "Pause",
                                        systemImage: store.deadline == nil ? "play.fill" : "pause.fill"
                                    )
                                }

                                Button {
                                    store.addTimer(minutes: 1)
                                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                                } label: {
                                    Label("+1 min", systemImage: "plus")
                                }

                                Button(role: .destructive) {
                                    store.resetTimer()
                                } label: {
                                    Label("Reset", systemImage: "arrow.counterclockwise")
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: options.alignment.alignment)
        }
    }

    private var microShelf: some View {
        Group {
            if let url = store.files.last {
                ZStack {
                    if store.files.count > 2 { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(style.accentColor.color.opacity(0.10)).frame(width: 52, height: 52).offset(x: 7, y: 6) }
                    if store.files.count > 1 { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(style.textColor.color.opacity(0.08)).frame(width: 52, height: 52).offset(x: 3, y: 3) }
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().scaledToFit().padding(12)
                        .frame(width: 58, height: 58).background(style.textColor.color.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    if store.files.count > 1 { Text("\(store.files.count)").font(.system(size: 7, weight: .bold, design: .rounded)).padding(4).background(style.accentColor.color, in: Circle()).foregroundStyle(.white).offset(x: 25, y: -25) }
                }
                .haloMicroInteraction(accent: style.accentColor.color, help: "File Shelf · click top file · hold to browse") {
                    NSWorkspace.shared.open(url)
                } popover: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("File Shelf").font(.headline); Spacer(); Button { store.chooseFiles() } label: { Image(systemName: "plus") } }
                        ForEach(Array(store.files.reversed().prefix(6)), id: \.self) { file in
                            Button { NSWorkspace.shared.open(file) } label: { HStack { Image(nsImage: NSWorkspace.shared.icon(forFile: file.path)).resizable().frame(width: 22, height: 22); Text(file.lastPathComponent).lineLimit(1); Spacer() } }.buttonStyle(.plain)
                        }
                    }.frame(width: 280)
                }
                .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider(object: url.path as NSString) }
            } else {
                Button { store.chooseFiles() } label: {
                    VStack(spacing: 5) { Image(systemName: "tray").font(.system(size: 24, weight: .semibold)); Text("ADD").font(.caption2).fontWeight(.bold) }
                        .foregroundStyle(style.accentColor.color).frame(maxWidth: .infinity, maxHeight: .infinity)
                }.buttonStyle(.plain).help("Add files to shelf")
            }
        }
    }

    private var shelf: some View {
        let options = style.resolvedContent
        return VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if style.showTitle {
                HStack(spacing: max(4, options.spacing * 0.55)) {
                    if style.showsHeaderIcon { Image(systemName: "tray").font(.system(size: options.iconSize)).foregroundStyle(style.accentColor.color) }
                    Text("File shelf").font(style.font())
                }
            }
            WidgetElement(key: "summary") {
                HStack {
                    Label("\(store.files.count) item\(store.files.count == 1 ? "" : "s")", systemImage: "tray.full")
                    Spacer()
                    Text("\(store.pinnedFiles.count) pinned")
                }
            }
            if presentation == .compact {
                if options.showQuickActions { WidgetElement(key: "actions", defaultPriority: .high) { Button("Add files…") { store.chooseFiles() } } }
            } else if store.files.isEmpty, options.showSecondaryText {
                WidgetElement(key: "files") { Text("Drop files here. Originals stay untouched.").foregroundStyle(.secondary) }
            } else {
                WidgetElement(key: "files") {
                    VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
                        ForEach(Array(store.files.prefix(presentation == .compact ? 1 : presentation == .expanded ? options.maxItems : min(3, options.maxItems))), id: \.self) { url in
                            HStack(spacing: options.spacing) {
                                ShelfFileInfo(url: url, iconSize: options.shelfIconSize, showDetail: options.shelfShowDetails && presentation != .compact && compression < 2)
                                Spacer()
                                if options.shelfShowActions && options.showControls {
                                    Button { store.toggleFilePin(url) } label: { Image(systemName: store.pinnedFiles.contains(url) ? "pin.fill" : "pin") }.help("Pin")
                                    Button { store.shelfPreview.show(url) } label: { Image(systemName: "eye") }.help("Quick Look")
                                    Button { NSWorkspace.shared.activateFileViewerSelecting([url]) } label: { Image(systemName: "folder") }.help("Reveal")
                                    Button { NSWorkspace.shared.open(url) } label: { Image(systemName: "arrow.up.forward.app") }.help("Open")
                                    ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                                    Button { store.removeFile(url) } label: { Image(systemName: "xmark") }.help("Remove")
                                }
                            }.onDrag { NSItemProvider(object: url as NSURL) }
                        }
                    }
                }
            }
            if options.showQuickActions && presentation == .expanded {
                WidgetElement(key: "actions", defaultPriority: .normal) {
                    HStack {
                        Button("Add files…") { store.chooseFiles() }
                        Button("Clear shelf") { store.clearShelf() }.disabled(store.files.isEmpty)
                    }
                }
            }
            if options.showFooter && store.files.count > options.maxItems {
                WidgetElement(key: "footer") { Text("+\(store.files.count - options.maxItems) more items") }
            }
        }
        .frame(maxWidth: .infinity, alignment: options.alignment.alignment)
        .dropDestination(for: URL.self) { urls, _ in
            let files = urls.filter(\.isFileURL)
            guard !files.isEmpty else { return false }
            store.addFiles(files)
            return true
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds.rounded()))
        return value >= 3600 ? String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60) : String(format: "%02d:%02d", value / 60, value % 60)
    }
}

struct ShelfFileInfo: View {
    let url: URL
    var iconSize = 24.0
    var showDetail = true
    @Environment(\.widgetStyle) private var style
    @State private var icon: NSImage?
    @State private var detail = ""
    var body: some View {
        HStack(spacing: style.resolvedContent.spacing) {
            if let icon { Image(nsImage: icon).resizable().frame(width: iconSize, height: iconSize) }
            VStack(alignment: style.resolvedContent.alignment.horizontal) {
                Text(url.lastPathComponent).font(style.font(scale: 0.85)).lineLimit(1)
                if showDetail { Text(detail).font(style.font(scale: 0.75)).foregroundStyle(.secondary).lineLimit(1) }
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

private struct BluetoothContextView: View {
    @ObservedObject var bluetooth: BluetoothStateService
    @ObservedObject var surfaceState: SurfaceState
    @AppStorage("HaloContextBluetoothUseFullNotchArea") private var usesFullNotchArea = false
    @AppStorage("HaloContextBluetoothKeepClosedNotchContents") private var keepsClosedNotchContents = false
    @AppStorage("HaloContextBluetoothShowPaired") private var showPaired = true
    @AppStorage("HaloContextBluetoothShowAddresses") private var showAddresses = false
    @AppStorage("HaloContextBluetoothPriority") private var priority = 50.0

    private var visibleDevices: [BluetoothDeviceSnapshot] {
        showPaired ? bluetooth.pairedDevices : bluetooth.connectedDevices
    }
    private var connectedCount: Int { bluetooth.connectedDevices.count }
    private var topInset: Double {
        if usesFullNotchArea && keepsClosedNotchContents { return max(16, surfaceState.compactHeight + 10) }
        if usesFullNotchArea { return max(16, surfaceState.compactHeight * 0.68) }
        return 16
    }
    private var sizingKey: String {
        let deviceKey = visibleDevices.map { "\($0.id):\($0.connected)" }.joined(separator: "|")
        return "\(bluetooth.poweredOn)|\(deviceKey)|\(bluetooth.lastEvent?.id.uuidString ?? "")|\(usesFullNotchArea)|\(keepsClosedNotchContents)"
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.blue.opacity(0.20), Color.cyan.opacity(0.08), Color.black.opacity(0.55)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if let event = bluetooth.lastEvent { eventCard(event) }
                    statusCard
                    if bluetooth.poweredOn {
                        if visibleDevices.isEmpty {
                            Label(showPaired ? "No paired Bluetooth devices" : "No Bluetooth devices connected", systemImage: "wave.3.right")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 72)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 225), spacing: 10)], spacing: 10) {
                                ForEach(visibleDevices) { device in deviceCard(device) }
                            }
                        }
                    }
                    if let error = bluetooth.connectionError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    HStack {
                        Button("Open Bluetooth Settings") { openBluetoothSettings() }
                        Button("Refresh") { bluetooth.refresh() }
                        Spacer()
                        Text(showPaired ? "Showing paired devices" : "Showing connected devices")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, topInset)
                .padding(.bottom, 16)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: usesFullNotchArea ? 0 : 18, style: .continuous))
        .task(id: sizingKey) { publishPreferredSize() }
        .onDisappear {
            guard surfaceState.activeCIIdentifier == nil else { return }
            surfaceState.contextPreferredSize = nil
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.blue.opacity(0.20)).frame(width: 42, height: 42)
                Image(systemName: bluetooth.poweredOn ? "wave.3.right" : "wave.3.right.slash")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(bluetooth.poweredOn ? Color.blue : Color.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Bluetooth").font(.title3.bold())
                Text(bluetooth.poweredOn ? (connectedCount == 1 ? "1 device connected" : "\(connectedCount) devices connected") : "Bluetooth is off")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("P\(Int(priority))").font(.caption2.monospacedDigit()).foregroundStyle(.secondary).help("CI priority")
            Button {
                if !surfaceState.pinned { surfaceState.expanded = false }
            } label: { Image(systemName: "chevron.up") }
                .buttonStyle(.plain).disabled(surfaceState.pinned).help("Close Halo")
            Button { surfaceState.pinned.toggle() } label: { Image(systemName: surfaceState.pinned ? "pin.fill" : "pin") }
                .buttonStyle(.plain).help(surfaceState.pinned ? "Allow Halo to close" : "Keep Halo open")
            Menu {
                Toggle("Use full notch area", isOn: $usesFullNotchArea)
                Toggle("Keep closed-notch contents visible", isOn: $keepsClosedNotchContents)
                Divider()
                Toggle("Show paired devices", isOn: $showPaired)
                Toggle("Show device addresses", isOn: $showAddresses)
                Divider()
                Text("CI priority: \(Int(priority))")
            } label: { Image(systemName: "slider.horizontal.3") }
                .menuStyle(.borderlessButton).frame(width: 24).help("Bluetooth CI options")
            Button { NotificationCenter.default.post(name: Notification.Name("HaloOpenSettings"), object: nil) } label: { Image(systemName: "gearshape.fill") }
                .buttonStyle(.plain).help("Open Halo settings")
        }
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: bluetooth.poweredOn ? "checkmark.circle.fill" : "power.circle.fill")
                .font(.system(size: 22)).foregroundStyle(bluetooth.poweredOn ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(bluetooth.poweredOn ? "Bluetooth available" : "Bluetooth unavailable").font(.headline)
                Text(bluetooth.poweredOn ? "Connect or disconnect paired devices directly from the cards below." : "Turn Bluetooth on to see and control devices.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func eventCard(_ event: BluetoothConnectionEvent) -> some View {
        HStack(spacing: 12) {
            BluetoothDeviceIcon(visual: event.deviceVisual, fallbackSymbol: event.symbol, size: 23).foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(.headline)
                Text(event.detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Text("Now").font(.caption2.weight(.semibold)).foregroundStyle(.blue)
        }
        .padding(13)
        .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Color.blue.opacity(0.22)))
    }

    private func deviceCard(_ device: BluetoothDeviceSnapshot) -> some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill((device.connected ? Color.blue : Color.secondary).opacity(0.13))
                    .frame(width: 38, height: 38)
                BluetoothDeviceIcon(visual: device.visual, size: 23)
                    .foregroundStyle(device.connected ? Color.blue : Color.secondary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(device.name).font(.callout.weight(.semibold)).lineLimit(1)
                HStack(spacing: 5) {
                    Circle().fill(device.connected ? Color.green : Color.secondary.opacity(0.6)).frame(width: 6, height: 6)
                    Text(device.connected ? "Connected" : "Paired").font(.caption).foregroundStyle(.secondary)
                }
                if showAddresses && !device.address.isEmpty {
                    Text(device.address).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if bluetooth.isChangingConnection(for: device) {
                ProgressView().controlSize(.small).frame(width: 54)
            } else {
                Button(device.connected ? "Disconnect" : "Connect") {
                    bluetooth.toggleConnection(for: device)
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
                .disabled(!bluetooth.poweredOn)
            }
        }
        .padding(10)
        .background(Color.white.opacity(device.connected ? 0.065 : 0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.07)))
    }

    private func publishPreferredSize() {
        let count = min(6, visibleDevices.count)
        let rows = Int(ceil(Double(count) / 2.0))
        let eventHeight = bluetooth.lastEvent == nil ? 0.0 : 66.0
        let height = min(620, max(220, 178 + eventHeight + Double(rows) * 64))
        let next = CGSize(width: 560, height: height)
        DispatchQueue.main.async { [surfaceState] in
            if let current = surfaceState.contextPreferredSize,
               abs(current.width - next.width) < 1, abs(current.height - next.height) < 1 { return }
            surfaceState.contextPreferredSize = next
        }
    }

    private func openBluetoothSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct ContextLyricTransitionModifier: ViewModifier {
    let opacity: Double
    let blurRadius: CGFloat
    let yOffset: CGFloat
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .blur(radius: blurRadius)
            .offset(y: yOffset)
            .scaleEffect(scale)
    }
}

private struct AudioCIScrubber: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let trackColor: Color
    let fillColor: Color
    let thumbColor: Color
    let onEditingChanged: (Bool) -> Void
    @State private var dragging = false

    private func fraction(for value: Double) -> Double {
        let span = max(0.0001, range.upperBound - range.lowerBound)
        return min(1, max(0, (value - range.lowerBound) / span))
    }

    private func resolvedValue(at x: CGFloat, width: CGFloat) -> Double {
        let fraction = min(1, max(0, Double(x / max(1, width))))
        return range.lowerBound + fraction * (range.upperBound - range.lowerBound)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width)
            let progress = CGFloat(fraction(for: value))
            let thumbSize: CGFloat = 11
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor)
                    .frame(height: 4)
                Capsule()
                    .fill(fillColor)
                    .frame(width: max(2, width * progress), height: 4)
                Circle()
                    .fill(thumbColor)
                    .overlay(Circle().stroke(fillColor.opacity(0.55), lineWidth: 1))
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.24), radius: 2, y: 1)
                    .offset(x: min(max(0, width * progress - thumbSize / 2), max(0, width - thumbSize)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !dragging {
                            dragging = true
                            onEditingChanged(true)
                        }
                        value = resolvedValue(at: gesture.location.x, width: width)
                    }
                    .onEnded { gesture in
                        value = resolvedValue(at: gesture.location.x, width: width)
                        if dragging {
                            dragging = false
                            onEditingChanged(false)
                        }
                    }
            )
        }
        .frame(height: 16)
        .accessibilityElement()
        .accessibilityLabel("Playback position")
        .accessibilityValue("\(Int(value.rounded())) seconds")
        .accessibilityAdjustableAction { direction in
            let step = max(1, (range.upperBound - range.lowerBound) / 100)
            onEditingChanged(true)
            switch direction {
            case .increment:
                value = min(range.upperBound, value + step)
            case .decrement:
                value = max(range.lowerBound, value - step)
            @unknown default:
                break
            }
            onEditingChanged(false)
        }
    }
}

private struct ContextMusicView: View {
    @ObservedObject var media: MediaService
    let options: ContextMusicOptions
    let visualizer: VisualizerOptions
    @ObservedObject var surfaceState: SurfaceState
    let preserveClosedVisualizerStrip: Bool
    @AppStorage("HaloContextVisualizerFullWidth") private var visualizerFullWidth = false
    @AppStorage("HaloContextMusicUseFullNotchArea") private var usesFullNotchArea = false
    @AppStorage("HaloContextMusicKeepClosedNotchContents") private var keepsClosedNotchContents = false
    @AppStorage("HaloContextMusicPriority") private var priority = 60.0
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
    private var safeInset: Double { options.resolvedHorizontalMargin }
    private var contentTopInset: Double {
        let base: Double
        if !usesFullNotchArea {
            base = max(16, max(18, options.resolvedSpacing * 1.25) * 0.75)
        } else if keepsClosedNotchContents || preserveClosedVisualizerStrip {
            base = max(16, surfaceState.compactHeight + max(6, options.resolvedSpacing * 0.5))
        } else {
            base = max(16, surfaceState.compactHeight * 0.68)
        }
        return base + options.resolvedTopMargin
    }
    private var controlsTopInset: Double {
        let base = usesFullNotchArea && (keepsClosedNotchContents || preserveClosedVisualizerStrip)
            ? max(12, surfaceState.compactHeight + 6)
            : max(12, max(18, options.resolvedSpacing * 1.25) * 0.65)
        return base + options.resolvedTopMargin
    }
    private var artworkKey: String {
        "\(media.connectedApp ?? "")|\(media.title)|\(media.artist)|\(options.resolvedForegroundArtwork.rawValue)|\(options.usesArtworkBackground)"
    }
    private var playbackKey: String { "\(media.connectedApp ?? "")|\(media.title)|\(media.artist)|\(media.isPlaying)|\(Int(media.duration.rounded()))" }
    private var lyricKey: String { playbackKey + "|lyrics|\(media.album)|\(options.showsLyrics)|\(options.usesOnlineLyrics)" }
    private var sizingKey: String {
        [options.resolvedLayoutMode.rawValue, options.resolvedForegroundArtwork.rawValue,
         String(options.artworkSize), String(options.showTitle), String(options.showArtist), String(options.showControls),
         String(options.showVisualizer), String(options.showsLyrics), options.resolvedLyricDisplay.rawValue,
         String(options.resolvedLyricFontSize), options.resolvedVisualizerStyle.rawValue,
         String(options.resolvedSpacing), String(options.resolvedControlSize), String(visualizerFullWidth),
         String(options.resolvedHorizontalMargin), String(options.resolvedTopMargin), String(options.resolvedBottomMargin),
         String(usesFullNotchArea), String(keepsClosedNotchContents), String(preserveClosedVisualizerStrip),
         keepsClosedNotchContents ? String(Int(surfaceState.compactWidth.rounded())) : "compact-width-ignored",
         keepsClosedNotchContents ? String(Int((surfaceState.closedOcclusion?.midX ?? 0).rounded())) : "compact-bias-ignored"].joined(separator: "|")
    }
    private var metadataReservedHeight: Double {
        let titleLineHeight = options.fontSize * 1.22
        let titleHeight = options.showTitle ? titleLineHeight * 2 : 0
        let artistFontSize = max(10, options.fontSize * 0.68)
        let artistHeight = options.showArtist ? artistFontSize * 1.22 : 0
        let gap = options.showTitle && options.showArtist ? max(2, options.resolvedSpacing * 0.28) : 0
        return titleHeight + artistHeight + gap
    }
    private var activeArtwork: NSImage? { media.artworkImage ?? artwork }
    private var rawSongPalette: [WidgetColor] { media.artworkColors }
    private var songColors: [Color] { rawSongPalette.map(\.color) }
    private var foregroundContrastBackgrounds: [WidgetColor] {
        guard !rawSongPalette.isEmpty else { return [.black] }
        if options.usesArtworkBackground {
            return rawSongPalette.prefix(4).map {
                AlbumForegroundColorResolver.blend(
                    $0,
                    toward: .black,
                    amount: options.resolvedArtworkBackgroundDim
                )
            }
        }
        if options.usesSongBackgroundColors {
            let opacity = options.background == .gradient
                ? options.backgroundOpacity
                : min(0.62, max(0.12, options.backgroundOpacity * 0.82))
            return rawSongPalette.prefix(4).map {
                AlbumForegroundColorResolver.blend(.black, toward: $0, amount: opacity)
            }
        }
        return [.black]
    }
    private var generatedSongForeground: WidgetColor? {
        guard let dominant = rawSongPalette.first else { return nil }
        return AlbumForegroundColorResolver.readable(dominant, against: foregroundContrastBackgrounds)
    }
    private var semanticSongColors: AudioCISemanticColors? {
        guard options.usesAdaptiveElementColors, !rawSongPalette.isEmpty else { return nil }
        return AudioCISemanticColorResolver.resolve(
            album: rawSongPalette,
            backgrounds: foregroundContrastBackgrounds,
            distribution: options.resolvedAdaptiveColorDistribution
        )
    }
    private var baseTextColor: Color { options.textColor.color }
    private var primarySongColor: Color {
        if options.usesReadableSongForegroundColors, let generatedSongForeground { return generatedSongForeground.color }
        return rawSongPalette.first?.color ?? baseTextColor
    }
    private var effectiveTextColor: Color { options.usesSongTextColors && !rawSongPalette.isEmpty ? primarySongColor : baseTextColor }
    private var effectiveControlColor: Color { options.usesSongControlColors && !rawSongPalette.isEmpty ? primarySongColor : baseTextColor }
    private var effectiveVisualizerColor: Color { options.usesSongVisualizerColors && !rawSongPalette.isEmpty ? primarySongColor : baseTextColor }
    private var primaryTextColor: Color { semanticSongColors?.primaryText.color ?? effectiveTextColor }
    private var secondaryTextColor: Color { semanticSongColors?.secondaryText.color ?? effectiveTextColor.opacity(0.72) }
    private var unavailableTextColor: Color { semanticSongColors?.secondaryText.color ?? effectiveTextColor.opacity(0.55) }
    private var primaryControlColor: Color { semanticSongColors?.primaryControl.color ?? effectiveControlColor }
    private var secondaryControlColor: Color { semanticSongColors?.secondaryControl.color ?? effectiveControlColor }
    private var timestampColor: Color { semanticSongColors?.secondaryText.color ?? effectiveTextColor.opacity(0.62) }
    private var visualizerChromeColor: Color { semanticSongColors?.secondaryControl.color ?? effectiveControlColor.opacity(0.72) }
    private var progressFillColor: Color { semanticSongColors?.progressFill.color ?? effectiveControlColor }
    private var progressTrackColor: Color { semanticSongColors?.progressTrack.color ?? effectiveControlColor.opacity(0.20) }
    private var progressThumbColor: Color { semanticSongColors?.progressThumb.color ?? effectiveControlColor }
    private var lyricCurrentColor: Color { semanticSongColors?.lyricCurrent.color ?? effectiveTextColor }
    private var lyricUpcomingColor: Color { semanticSongColors?.lyricUpcoming.color ?? effectiveTextColor.opacity(0.35) }
    private var lyricInactiveWordColor: Color { semanticSongColors?.lyricUpcoming.color ?? effectiveTextColor.opacity(0.5) }
    private var visualizerPalette: [WidgetColor] {
        if let semanticSongColors { return semanticSongColors.visualizer }
        guard options.usesSongVisualizerColors else { return [] }
        if options.usesReadableSongForegroundColors, let generatedSongForeground { return [generatedSongForeground] }
        return rawSongPalette
    }
    private var backgroundGradientColors: [Color] {
        options.usesSongBackgroundColors && !songColors.isEmpty ? Array(songColors.prefix(3)) : [.blue, .purple]
    }
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
                .padding(.top, contentTopInset)
                .padding(.bottom, options.resolvedBottomMargin)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: usesFullNotchArea ? 0 : options.resolvedCornerRadius, style: .continuous))
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 12) {
                    Text("P\(Int(priority))").font(.system(size: 9, weight: .semibold, design: .monospaced)).opacity(0.55).help("CI priority")
                    Button {
                        if !surfaceState.pinned { surfaceState.expanded = false }
                    } label: {
                        Image(systemName: "chevron.up").font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(secondaryControlColor)
                    .disabled(surfaceState.pinned)
                    .help(surfaceState.pinned ? "Unpin Halo before closing" : "Close Halo")
                    .accessibilityLabel("Close Halo")
                    Button { surfaceState.pinned.toggle() } label: {
                        Image(systemName: surfaceState.pinned ? "pin.fill" : "pin").font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(secondaryControlColor)
                    .help(surfaceState.pinned ? "Allow Halo to close" : "Keep Halo open")
                    .accessibilityLabel(surfaceState.pinned ? "Unpin Halo" : "Keep Halo open")
                    Menu {
                        Toggle("Use full notch area", isOn: $usesFullNotchArea)
                        Toggle("Keep closed-notch contents visible", isOn: $keepsClosedNotchContents)
                        Divider()
                        Text("CI priority: \(Int(priority))")
                        Text(usesFullNotchArea ? "CI owns the whole expanded surface" : "CI starts below the notch strip")
                    } label: {
                        Image(systemName: "rectangle.inset.filled.and.person.filled").font(.system(size: 12, weight: .semibold))
                    }
                    .menuStyle(.borderlessButton)
                    .foregroundStyle(secondaryControlColor)
                    .help("Context interface layout")
                    Button { NotificationCenter.default.post(name: Notification.Name("HaloOpenSettings"), object: nil) } label: {
                        Image(systemName: "gearshape.fill").font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(secondaryControlColor)
                    .help("Open Halo settings")
                }
                .padding(.top, controlsTopInset)
                .padding(.trailing, safeInset)
            }
            .foregroundStyle(primaryTextColor)
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
        .onChange(of: surfaceState.contextPreferredSize) { requested in
            guard surfaceState.expanded, requested == nil else { return }
            publishPreferredSize()
        }
        .onDisappear {
            let owned = preferredSurfaceSize
            if let current = surfaceState.contextPreferredSize,
               abs(current.width - owned.width) < 1,
               abs(current.height - owned.height) < 1 {
                surfaceState.contextPreferredSize = nil
            }
        }
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
        let metadataHeight = metadataReservedHeight
        let lyricsHeight = options.showsLyrics ? options.resolvedLyricFontSize * (options.resolvedLyricDisplay == .word ? 1.25 : 2.05) : 0
        // Keep the Audio CI geometry stable for the lifetime of the music surface.
        // MediaRemote can briefly omit duration while metadata refreshes; tying preferred size
        // to that transient value makes the notch randomly grow/shrink when the scrubber appears.
        // Reserve the progress-row footprint even while duration is temporarily unavailable.
        let scrubHeight = 30.0
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
        let legacyHorizontalMargin = max(18, options.resolvedSpacing * 1.25)
        let extraHorizontalSpace = max(0, options.resolvedHorizontalMargin - legacyHorizontalMargin) * 2
        let audioRequestedWidth = min(760, width + extraHorizontalSpace)
        let retainedClosedWidth = keepsClosedNotchContents
            ? Double(RetainedClosedNotchGeometry.centeredRequiredWidth(
                width: surfaceState.compactWidth,
                occlusion: surfaceState.closedOcclusion
            ))
            : 0
        let requestedWidth = max(audioRequestedWidth, retainedClosedWidth)
        let requestedHeight = innerHeight + contentTopInset + options.resolvedBottomMargin
        return CGSize(width: requestedWidth, height: min(700, max(150, requestedHeight)))
    }

    @ViewBuilder private func contextBackground(size: CGSize) -> some View {
        ZStack {
            switch options.background {
            case .glass:
                Rectangle().fill(.ultraThinMaterial).opacity(max(0.12, options.backgroundOpacity))
            case .gradient:
                LinearGradient(colors: backgroundGradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .opacity(options.backgroundOpacity)
            default:
                Color.black.opacity(options.backgroundOpacity)
            }
            if options.usesSongBackgroundColors, !songColors.isEmpty, options.background != .gradient {
                LinearGradient(colors: Array(songColors.prefix(2)), startPoint: .topLeading, endPoint: .bottomTrailing)
                    .opacity(min(0.62, max(0.12, options.backgroundOpacity * 0.82)))
                    .blendMode(.plusLighter)
            }
            if options.usesArtworkBackground, let activeArtwork {
                Image(nsImage: activeArtwork)
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
            if options.resolvedForegroundArtwork != .none { foregroundArtwork(size: options.artworkSize) }
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
            if options.resolvedForegroundArtwork != .none { foregroundArtwork(size: options.artworkSize) }
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
            if options.resolvedForegroundArtwork != .none { foregroundArtwork(size: options.artworkSize) }
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
            if options.resolvedForegroundArtwork != .none { foregroundArtwork(size: options.artworkSize) }
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
                    if let activeArtwork { Image(nsImage: activeArtwork).resizable().scaledToFill() }
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
        VinylRecordView(artwork: activeArtwork,
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
                Text(media.title)
                    .font(.system(size: options.fontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(2)
                    .multilineTextAlignment(textAlignment)
            }
            if options.showArtist {
                Text(media.artist.isEmpty ? "Unknown artist" : media.artist)
                    .font(.system(size: max(10, options.fontSize * 0.68), weight: .medium))
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity,
               minHeight: CGFloat(metadataReservedHeight),
               maxHeight: CGFloat(metadataReservedHeight),
               alignment: frameAlignment)
    }

    @ViewBuilder private var lyricsView: some View {
        if options.showsLyrics {
            if lyricsLoading && lyrics.isEmpty {
                Label("Loading lyrics…", systemImage: "text.quote")
                    .font(.system(size: options.resolvedLyricFontSize))
                    .foregroundStyle(secondaryTextColor)
            } else if lyrics.isEmpty {
                Text("Synced lyrics unavailable")
                    .font(.system(size: options.resolvedLyricFontSize))
                    .foregroundStyle(unavailableTextColor)
            } else {
                TimelineView(.animation(minimumInterval: 0.06, paused: !media.isPlaying)) { _ in
                    let position = (isScrubbing ? scrubValue : playbackPosition) + options.resolvedLyricSyncOffset
                    let lines = ContextLyricTimeline.parse(lyrics)
                    if let frame = ContextLyricTimeline.frame(lines: lines, position: max(0, position), duration: playbackDuration) {
                        animatedContextLyric(frame)
                    }
                }
            }
        }
    }

    private var lyricLineTransition: AnyTransition {
        guard !reduceMotion else { return .identity }

        switch options.resolvedLyricTransition {
        case .none:
            return .identity
        case .fade:
            return .opacity
        case .slide:
            return .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            )
        case .lift:
            return .asymmetric(
                insertion: .modifier(
                    active: ContextLyricTransitionModifier(opacity: 0, blurRadius: 0, yOffset: 10, scale: 1),
                    identity: ContextLyricTransitionModifier(opacity: 1, blurRadius: 0, yOffset: 0, scale: 1)
                ),
                removal: .modifier(
                    active: ContextLyricTransitionModifier(opacity: 0, blurRadius: 0, yOffset: -6, scale: 1),
                    identity: ContextLyricTransitionModifier(opacity: 1, blurRadius: 0, yOffset: 0, scale: 1)
                )
            )
        case .scale:
            return .scale(scale: 0.92).combined(with: .opacity)
        case .blur:
            return .asymmetric(
                insertion: .modifier(
                    active: ContextLyricTransitionModifier(opacity: 0, blurRadius: 7, yOffset: 3, scale: 0.985),
                    identity: ContextLyricTransitionModifier(opacity: 1, blurRadius: 0, yOffset: 0, scale: 1)
                ),
                removal: .modifier(
                    active: ContextLyricTransitionModifier(opacity: 0, blurRadius: 5, yOffset: -2, scale: 0.99),
                    identity: ContextLyricTransitionModifier(opacity: 1, blurRadius: 0, yOffset: 0, scale: 1)
                )
            )
        }
    }

    private var lyricLineAnimation: Animation? {
        guard !reduceMotion, options.resolvedLyricTransition != .none else { return nil }
        return .easeInOut(duration: options.resolvedLyricTransitionDuration)
    }

    private func animatedContextLyric(_ frame: ContextLyricFrame) -> some View {
        ZStack(alignment: frameAlignment) {
            contextLyric(frame)
                .id(frame.current.id)
                .transition(lyricLineTransition)
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .animation(lyricLineAnimation, value: frame.current.id)
    }

    @ViewBuilder private func contextLyric(_ frame: ContextLyricFrame) -> some View {
        switch options.resolvedLyricDisplay {
        case .line:
            VStack(alignment: horizontalAlignment, spacing: 3) {
                Text(frame.current.text)
                    .font(.system(size: options.resolvedLyricFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(lyricCurrentColor)
                    .lineLimit(2)
                    .multilineTextAlignment(textAlignment)
                if let next = frame.next {
                    Text(next.text)
                        .font(.system(size: max(10, options.resolvedLyricFontSize * 0.74)))
                        .foregroundStyle(lyricUpcomingColor)
                        .lineLimit(1)
                }
            }
        case .word:
            let words = frame.current.text.split(whereSeparator: \.isWhitespace).map { String($0) }
            Text(words.indices.contains(frame.wordIndex) ? words[frame.wordIndex] : frame.current.text)
                .font(.system(size: options.resolvedLyricFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(lyricCurrentColor)
                .lineLimit(1)
        case .focus:
            focusedLyricLine(frame.current.text, activeWord: frame.wordIndex)
        }
    }

    private func focusedLyricLine(_ text: String, activeWord: Int) -> some View {
        let words = text.split(whereSeparator: \.isWhitespace).map { String($0) }
        var result = Text("")
        for (index, word) in words.enumerated() {
            result = result + Text((index == 0 ? "" : " ") + word)
                .fontWeight(index == activeWord ? .bold : .regular)
                .foregroundColor(index == activeWord ? lyricCurrentColor : lyricInactiveWordColor)
        }
        return result.font(.system(size: options.resolvedLyricFontSize, design: .rounded)).lineLimit(2).multilineTextAlignment(textAlignment)
    }

    @ViewBuilder private var scrubber: some View {
        if playbackDuration > 0.5 {
            VStack(spacing: 3) {
                if semanticSongColors != nil {
                    AudioCIScrubber(
                        value: Binding(
                            get: { isScrubbing ? scrubValue : min(playbackDuration, max(0, playbackPosition)) },
                            set: { newValue in
                                if !isScrubbing { scrubValue = playbackPosition }
                                scrubValue = min(playbackDuration, max(0, newValue))
                            }
                        ),
                        range: 0...max(1, playbackDuration),
                        trackColor: progressTrackColor,
                        fillColor: progressFillColor,
                        thumbColor: progressThumbColor
                    ) { editing in
                        if editing {
                            scrubValue = min(playbackDuration, max(0, playbackPosition))
                            isScrubbing = true
                        } else {
                            let target = min(playbackDuration, max(0, scrubValue))
                            playbackPosition = target
                            isScrubbing = false
                            media.seek(to: target)
                        }
                    }
                } else {
                    Slider(value: Binding(
                        get: { isScrubbing ? scrubValue : min(playbackDuration, max(0, playbackPosition)) },
                        set: { newValue in
                            if !isScrubbing { scrubValue = playbackPosition }
                            isScrubbing = true
                            scrubValue = min(playbackDuration, max(0, newValue))
                        }
                    ), in: 0...max(1, playbackDuration), onEditingChanged: { editing in
                        if editing {
                            scrubValue = min(playbackDuration, max(0, playbackPosition))
                            isScrubbing = true
                        } else {
                            let target = min(playbackDuration, max(0, scrubValue))
                            playbackPosition = target
                            isScrubbing = false
                            media.seek(to: target)
                        }
                    })
                    .controlSize(.small)
                    .tint(effectiveControlColor)
                }
                HStack {
                    Text(formatTime(isScrubbing ? scrubValue : playbackPosition))
                    Spacer()
                    Text("−" + formatTime(max(0, playbackDuration - (isScrubbing ? scrubValue : playbackPosition))))
                }
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(timestampColor)
            }
            .frame(maxWidth: 440)
        }
    }

    @ViewBuilder private var controls: some View {
        if options.showControls {
            HStack(spacing: options.resolvedControlSize * 1.05) {
                control("backward.end.fill", action: "previous track", label: "Previous track", color: secondaryControlColor)
                control(media.isPlaying ? "pause.fill" : "play.fill", action: "playpause", label: "Play or pause", color: primaryControlColor)
                control("forward.end.fill", action: "next track", label: "Next track", color: secondaryControlColor)
            }
            .font(.system(size: options.resolvedControlSize, weight: .semibold))
            .disabled(media.busy)
        }
    }

    @ViewBuilder private var visualizerView: some View {
        if options.showVisualizer {
            let configured = contextVisualizerOptions
            PlaybackVisualizer(kind: options.resolvedVisualizerStyle, playing: media.hasNowPlayingPresentation, enabled: true,
                               options: configured, palette: visualizerPalette, fallback: semanticSongColors?.primaryControl.color ?? effectiveVisualizerColor)
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
                    .foregroundStyle(visualizerChromeColor)
                    .help(visualizerFullWidth ? "Use visualizer's normal width" : "Fill the interface width")
                    .padding(.trailing, 2)
                }
        }
    }

    private var contextVisualizerOptions: VisualizerOptions {
        var value = visualizer
        value.dynamicColors = options.usesAdaptiveElementColors || options.usesSongVisualizerColors
        value.width = visualizerFullWidth ? max(120, surfaceState.dashboardWidth - safeInset * 2) : max(value.width, 120)
        return value
    }

    @ViewBuilder private var errorView: some View {
        if let error = media.error { Text(error).font(.caption).foregroundStyle(.orange) }
    }

    private var textAlignment: TextAlignment {
        switch options.resolvedContentAlignment { case .leading: return .leading; case .center: return .center; case .trailing: return .trailing }
    }

    private func control(_ symbol: String, action: String, label: String, color: Color) -> some View {
        Button {
            if let app = media.connectedApp { media.perform(action, app: app) }
            else { media.performSystem(action) }
        } label: { Image(systemName: symbol) }
            .buttonStyle(.plain)
            .foregroundStyle(color)
            .accessibilityLabel(label)
    }

    private func playbackLoop() async {
        playbackPosition = media.position
        playbackDuration = media.duration
        while !Task.isCancelled {
            if !isScrubbing {
                if let sample = await MediaAssetReader.playbackTime(app: media.connectedApp) {
                    playbackPosition = sample.position
                    playbackDuration = sample.duration
                } else if media.duration > 0 {
                    playbackDuration = media.duration
                    // MediaRemote updates roughly on Halo's normal poll. Interpolate between those
                    // samples so synced Safari lyrics remain fluid rather than stepping every 2 s.
                    if abs(media.position - playbackPosition) > 1.35 {
                        playbackPosition = media.position
                    } else if media.isPlaying {
                        playbackPosition = min(playbackDuration, playbackPosition + 0.5)
                    } else {
                        playbackPosition = min(playbackDuration, max(0, media.position))
                    }
                }
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    private func loadLyrics() async {
        lyrics = ""; lyricsLoading = false
        guard options.showsLyrics else { return }
        lyricsLoading = true

        let sharedKey = "\(media.connectedApp ?? "")|\(media.title)|\(media.artist)"
        let initial = await MediaAssetReader.playbackTime(app: media.connectedApp)
        guard !Task.isCancelled else { return }
        if playbackDuration <= 0, let initial {
            playbackPosition = initial.position
            playbackDuration = initial.duration
        } else if playbackDuration <= 0, media.duration > 0 {
            playbackPosition = media.position
            playbackDuration = media.duration
        }
        let duration = playbackDuration > 0 ? playbackDuration : (initial?.duration ?? (media.duration > 0 ? media.duration : nil))
        let loaded = await MediaAssetReader.lyrics(app: media.connectedApp,
                                                   key: sharedKey,
                                                   title: media.title,
                                                   artist: media.artist,
                                                   duration: duration,
                                                   onlineFallback: options.usesOnlineLyrics)
        guard !Task.isCancelled else { return }
        lyrics = loaded
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
        let rawLines = value.split(whereSeparator: \.isNewline).map { String($0) }
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

// MARK: - Installed app integration CI renderer

private struct IntegrationCICompactView: View {
    let candidate: CIEligibleCandidate?

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "app.connected.to.app.below.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(candidate?.registration.metadata.name ?? "Integration")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private enum IntegrationOptionDraftError: LocalizedError {
    case invalid(name: String, type: String)

    var errorDescription: String? {
        switch self {
        case .invalid(let name, let type):
            return "\(name) must be a valid \(type) value."
        }
    }
}

@MainActor
private final class IntegrationActionDropTargetProbeNSView: NSView {
    var onFrameChange: ((CGRect) -> Void)?
    var onRemoval: (() -> Void)?
    private var lastPublishedFrame: CGRect?

    override func layout() {
        super.layout()
        publishFrame()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            onRemoval?()
            lastPublishedFrame = nil
        } else {
            publishFrame()
        }
    }

    func publishFrame() {
        guard let window else { return }
        let frameInWindow = convert(bounds, to: nil)
        let frameInScreen = window.convertToScreen(frameInWindow)
        guard frameInScreen.width > 1, frameInScreen.height > 1,
              frameInScreen != lastPublishedFrame else { return }
        lastPublishedFrame = frameInScreen
        onFrameChange?(frameInScreen)
    }
}

@MainActor
private struct IntegrationActionDropTargetProbe: NSViewRepresentable {
    let displayID: String
    let ciID: String
    let sessionID: UUID
    let actionID: String
    let enabled: Bool

    func makeNSView(context: Context) -> IntegrationActionDropTargetProbeNSView {
        let view = IntegrationActionDropTargetProbeNSView(frame: .zero)
        configure(view)
        return view
    }

    func updateNSView(_ nsView: IntegrationActionDropTargetProbeNSView, context: Context) {
        configure(nsView)
        DispatchQueue.main.async { [weak nsView] in
            nsView?.publishFrame()
        }
    }

    static func dismantleNSView(_ nsView: IntegrationActionDropTargetProbeNSView, coordinator: ()) {
        nsView.onRemoval?()
        nsView.onFrameChange = nil
        nsView.onRemoval = nil
    }

    private func configure(_ view: IntegrationActionDropTargetProbeNSView) {
        let unregister = {
            IntegrationActionDropTargetRegistry.shared.unregister(
                sessionID: sessionID,
                actionID: actionID
            )
        }
        view.onRemoval = unregister

        guard enabled else {
            unregister()
            view.onFrameChange = nil
            return
        }

        view.onFrameChange = { frame in
            IntegrationActionDropTargetRegistry.shared.register(
                displayID: displayID,
                ciID: ciID,
                sessionID: sessionID,
                actionID: actionID,
                screenFrame: frame
            )
        }
    }
}

@MainActor
private struct IntegrationCIView: View {
    let candidate: CIEligibleCandidate
    let session: CIActivationSession
    @ObservedObject var surfaceState: SurfaceState
    @ObservedObject var runtime: IntegrationCIRuntime
    @ObservedObject private var actionDropTargets = IntegrationActionDropTargetRegistry.shared

    @State private var textDrafts: [String: String] = [:]
    @State private var boolDrafts: [String: Bool] = [:]
    @State private var isExecuting = false
    @State private var actionError: String?

    private var registration: CIRegistration { candidate.registration }
    private var configuration: CIConfiguration { runtime.configuration(for: registration) }
    private var liveSession: CIActivationSession {
        guard let current = runtime.currentSession(displayID: session.displayID),
              current.id == session.id else { return session }
        return current
    }
    private var payloadCommitted: Bool { runtime.isPayloadCommitted(session: liveSession) }
    private var committedActionID: String? { liveSession.committedActionID }
    private var hoveredActionID: String? {
        actionDropTargets.hoveredActionID(displayID: session.displayID)
    }
    private var actions: [CIActionDefinition] {
        registration.supportedActions.filter {
            session.eligibleActionIDs.contains($0.id) && configuration.actionEnabled($0.id)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            integrationHeader
            payloadNotice
            errorNotice
            actionList
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            publishSizingIfCurrent()
        }
        .onChange(of: runtime.revision) { _ in
            publishSizingIfCurrent()
        }
    }

    private var integrationHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "app.connected.to.app.below.fill")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.accentColor.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(registration.metadata.name)
                    .font(.headline)
                Text("Third-party integration · \(registration.metadata.version)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                let shouldCollapse = runtime.dismiss(
                    displayID: session.displayID,
                    pinned: surfaceState.pinned
                )
                if shouldCollapse && !surfaceState.pinned {
                    surfaceState.expanded = false
                }
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Close \(registration.metadata.name)")
        }
    }

    @ViewBuilder
    private var payloadNotice: some View {
        if session.payloadHandle != nil && !payloadCommitted {
            Label(payloadCommitMessage, systemImage: "arrow.down.doc.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
        }
    }

    @ViewBuilder
    private var errorNotice: some View {
        if let message = actionError ?? runtime.lastError {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var actionList: some View {
        if actions.isEmpty {
            emptyActionsView
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(actions) { action in
                        actionCard(action)
                    }
                }
            }
        }
    }

    private var emptyActionsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "switch.2")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.secondary)
            Text("No enabled actions")
                .font(.headline)
            Text("Enable an advertised action in Context Interface Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private func actionCard(_ action: CIActionDefinition) -> some View {
        let isHovered = hoveredActionID == action.id && !payloadCommitted
        let isCommittedAction = committedActionID == action.id
        let isLockedToAnotherAction = committedActionID != nil && !isCommittedAction

        VStack(alignment: .leading, spacing: 9) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(action.name)
                        .font(.subheadline.weight(.semibold))
                    switch action.input.type {
                    case .none:
                        Text("No file input required")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    case .files:
                        Text(fileInputSummary(action.input))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if isHovered {
                        Text(actionNeedsUserInput(action) ? "Drop to configure" : "Drop to run")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    } else if isCommittedAction && payloadCommitted {
                        Label("File ready", systemImage: "checkmark.circle.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button("Run") { run(action) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(
                        isExecuting ||
                        isLockedToAnotherAction ||
                        (action.input.type == .files && liveSession.payloadHandle != nil && !payloadCommitted)
                    )
            }

            if !action.options.isEmpty {
                Divider().opacity(0.35)
                ForEach(action.options) { option in
                    optionEditor(option, actionID: action.id)
                        .disabled(isLockedToAnotherAction)
                }
            }
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovered ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.055))
        )
        .background(
            IntegrationActionDropTargetProbe(
                displayID: liveSession.displayID,
                ciID: registration.id,
                sessionID: liveSession.id,
                actionID: action.id,
                enabled: liveSession.payloadHandle != nil && !payloadCommitted
            )
            .allowsHitTesting(false)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isHovered ? Color.accentColor.opacity(0.9) : Color.white.opacity(0.08),
                    lineWidth: isHovered ? 1.5 : 1
                )
        }
        .opacity(isLockedToAnotherAction ? 0.5 : 1)
    }

    @ViewBuilder
    private func optionEditor(_ option: CIActionOptionDefinition, actionID: String) -> some View {
        let key = actionID + "::" + option.key
        if option.type == "boolean" {
            Toggle(option.name, isOn: Binding(
                get: { boolDrafts[key] ?? defaultBool(option, actionID: actionID) },
                set: { boolDrafts[key] = $0 }
            ))
            .toggleStyle(.switch)
            .font(.caption)
        } else {
            LabeledContent(option.name + (option.required ? " *" : "")) {
                TextField(option.key, text: Binding(
                    get: { textDrafts[key] ?? defaultText(option, actionID: actionID) },
                    set: { textDrafts[key] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 160, idealWidth: 220)
            }
            .font(.caption)
        }
    }

    private func run(_ action: CIActionDefinition) {
        guard !isExecuting else { return }
        do {
            let options = try typedOverrides(for: action)
            actionError = nil
            isExecuting = true
            Task { @MainActor in
                defer { isExecuting = false }
                do {
                    let shouldCollapse = try await runtime.executeAction(
                        ciID: registration.id,
                        actionID: action.id,
                        activationSessionID: session.id,
                        options: options,
                        parentWindow: nil,
                        pinned: surfaceState.pinned
                    )
                    if shouldCollapse && !surfaceState.pinned {
                        surfaceState.expanded = false
                    }
                } catch {
                    actionError = error.localizedDescription
                }
            }
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func actionNeedsUserInput(_ action: CIActionDefinition) -> Bool {
        let configuredDefaults = configuration.actions[action.id]?.optionDefaults ?? [:]
        return action.options.contains { option in
            option.required &&
            configuredDefaults[option.key] == nil &&
            option.defaultValue == nil
        }
    }

    private var payloadCommitMessage: String {
        guard let drag = candidate.event.fileDrag else {
            return "Drop the files to commit this payload."
        }
        let noun = drag.itemCount == 1 ? "item" : "items"
        return "Drop \(drag.itemCount) \(noun) to commit this payload."
    }

    private func typedOverrides(for action: CIActionDefinition) throws -> [String: CIValue] {
        var result: [String: CIValue] = [:]
        for option in action.options {
            let key = action.id + "::" + option.key
            if option.type == "boolean" {
                if let value = boolDrafts[key] { result[option.key] = .boolean(value) }
                continue
            }
            guard let raw = textDrafts[key] else { continue }
            guard let value = parse(raw, type: option.type) else {
                throw IntegrationOptionDraftError.invalid(name: option.name, type: option.type)
            }
            result[option.key] = value
        }
        return result
    }

    private func parse(_ raw: String, type: String) -> CIValue? {
        switch type {
        case "string": return .string(raw)
        case "integer": return Int(raw).map(CIValue.integer)
        case "double": return Double(raw).map(CIValue.double)
        case "stringArray":
            return .stringArray(csv(raw))
        case "integerArray":
            let parts = csv(raw)
            let parsed = parts.compactMap(Int.init)
            return parsed.count == parts.count ? .integerArray(parsed) : nil
        case "doubleArray":
            let parts = csv(raw)
            let parsed = parts.compactMap(Double.init)
            return parsed.count == parts.count ? .doubleArray(parsed) : nil
        default:
            return nil
        }
    }

    private func csv(_ raw: String) -> [String] {
        raw.split(separator: ",", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func defaultValue(_ option: CIActionOptionDefinition, actionID: String) -> CIValue? {
        configuration.actions[actionID]?.optionDefaults[option.key] ?? option.defaultValue
    }

    private func defaultBool(_ option: CIActionOptionDefinition, actionID: String) -> Bool {
        guard case .boolean(let value)? = defaultValue(option, actionID: actionID) else { return false }
        return value
    }

    private func defaultText(_ option: CIActionOptionDefinition, actionID: String) -> String {
        guard let value = defaultValue(option, actionID: actionID) else { return "" }
        switch value {
        case .string(let value): return value
        case .integer(let value): return String(value)
        case .double(let value): return String(value)
        case .boolean(let value): return value ? "true" : "false"
        case .stringArray(let value): return value.joined(separator: ", ")
        case .integerArray(let value): return value.map { String($0) }.joined(separator: ", ")
        case .doubleArray(let value): return value.map { String($0) }.joined(separator: ", ")
        }
    }

    private func fileInputSummary(_ input: CIActionInputDefinition) -> String {
        if input.extensions.contains("*") {
            return input.multiple ? "Accepts multiple files" : "Accepts one file"
        }
        let formats = input.extensions.map { "." + $0 }.joined(separator: ", ")
        return (input.multiple ? "Files: " : "One file: ") + formats
    }

    private func publishSizingIfCurrent() {
        guard runtime.isCurrent(sessionID: session.id, ciID: registration.id, displayID: session.displayID) else {
            return
        }
        let presentation = registration.presentation
        surfaceState.contextMinimumExpandedWidth = CGFloat(presentation.preferredExpandedWidth)
        surfaceState.contextPreferredSize = CGSize(
            width: CGFloat(presentation.preferredExpandedWidth),
            height: CGFloat(presentation.preferredExpandedHeight)
        )
        surfaceState.contextPreferredCompactWidth = presentation.preferredCompactWidth.map { CGFloat($0) }
        surfaceState.contextPreferredCompactHeight = presentation.preferredCompactHeight.map { CGFloat($0) }
    }
}

// MARK: - Declarative Custom CI renderer

private struct HaloCustomCIContentSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > 0 && next.height > 0 { value = next }
    }
}

private struct HaloCustomCISurfaceView: View {
    let package: HaloCIParsedPackage
    @ObservedObject var surfaceState: SurfaceState
    @ObservedObject var workspace: WorkspaceStore
    @ObservedObject private var runtime = HaloCustomCIRuntimeStore.shared
    @State private var measuredClosed: CGSize = .zero
    @State private var measuredExpanded: CGSize = .zero

    private var expanded: Bool { surfaceState.expanded }
    private var root: HaloCIComponent? { expanded ? package.interface.expanded : package.interface.closed }
    private var data: [String: String] { runtime.dataBus(for: package, workspace: workspace, expanded: expanded) }
    private var dynamicSizing: Bool { package.manifest.surface.sizing.mode == "dynamic" }

    @ViewBuilder private var renderedContent: some View {
        if let root {
            HaloCustomCIComponentRenderer(package: package, workspace: workspace, runtime: runtime, data: data).render(root)
        } else {
            HStack(spacing: 7) {
                Image(systemName: "rectangle.3.group.bubble.left.fill").font(.system(size: 10, weight: .semibold))
                Text(package.manifest.name).font(.system(size: 10, weight: .semibold, design: .rounded)).lineLimit(1)
            }.padding(.horizontal, 10)
        }
    }

    var body: some View {
        Group {
            if dynamicSizing {
                renderedContent
                    .fixedSize(horizontal: true, vertical: true)
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: HaloCustomCIContentSizePreferenceKey.self, value: proxy.size)
                    })
            } else {
                renderedContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
        .onPreferenceChange(HaloCustomCIContentSizePreferenceKey.self) { size in
            guard dynamicSizing, size.width > 0, size.height > 0 else { return }
            if expanded { measuredExpanded = size } else { measuredClosed = size }
            publishSizing()
        }
        .onAppear { publishSizing() }
        .onChange(of: expanded) { _ in publishSizing() }
        .onChange(of: runtime.contextRevision) { _ in publishSizing() }
    }

    private func resolved(_ rule: HaloCISizeRule, measured: CGSize, closed: Bool) -> CGSize {
        let sizing = package.manifest.surface.sizing
        if sizing.mode == "static" {
            return CGSize(width: rule.width ?? (closed ? 190 : 560), height: rule.height ?? (closed ? 40 : 260))
        }
        let preferred = CGSize(width: rule.preferredWidth ?? (closed ? 190 : 560),
                               height: rule.preferredHeight ?? (closed ? 40 : 260))
        let source = measured.width > 0 && measured.height > 0 ? measured : preferred
        return CGSize(width: min(rule.maxWidth ?? source.width, max(rule.minWidth ?? source.width, source.width)),
                      height: min(rule.maxHeight ?? source.height, max(rule.minHeight ?? source.height, source.height)))
    }

    private func publishSizing() {
        let sizing = package.manifest.surface.sizing
        let expandedSize = resolved(sizing.expanded, measured: measuredExpanded, closed: false)
        surfaceState.contextMinimumExpandedWidth = sizing.mode == "dynamic"
            ? (sizing.expanded.minWidth ?? expandedSize.width)
            : expandedSize.width
        surfaceState.contextPreferredSize = expandedSize
        if let closed = sizing.closed {
            let closedSize = resolved(closed, measured: measuredClosed, closed: true)
            surfaceState.contextPreferredCompactWidth = closedSize.width
            surfaceState.contextPreferredCompactHeight = closedSize.height
        } else {
            surfaceState.contextPreferredCompactWidth = nil
            surfaceState.contextPreferredCompactHeight = nil
        }
    }
}

private struct HaloCustomCIBackgroundView: View {
    let contract: HaloCIBackgroundContract
    let expanded: Bool
    private var style: HaloCIBackgroundStyle { expanded ? contract.expanded : (contract.closed ?? contract.expanded) }
    var body: some View {
        let opacity = min(1, max(0, style.opacity ?? 1))
        ZStack {
            switch style.type {
            case "gradient":
                LinearGradient(colors: [color(style.color ?? "#101014"), color(style.secondaryColor ?? style.color ?? "#101014")],
                               startPoint: .topLeading, endPoint: .bottomTrailing).opacity(opacity)
            case "glass":
                color(style.color ?? "#101014").opacity(min(1, opacity * 0.72))
                Rectangle().fill(.ultraThinMaterial).opacity(min(1, 0.30 + (style.blur ?? 0) / 60))
            case "clear":
                Color.clear
            default:
                color(style.color ?? "#101014").opacity(opacity)
            }
        }.allowsHitTesting(false)
    }

    private func color(_ raw: String) -> Color {
        switch raw.lowercased() {
        case "accent": return .accentColor; case "white": return .white; case "black": return .black
        case "clear": return .clear; case "secondary": return .white.opacity(0.62); case "green": return .green
        case "orange": return .orange; case "red": return .red; case "blue": return .blue
        default:
            var hex = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if hex.hasPrefix("#") { hex.removeFirst() }
            guard (hex.count == 6 || hex.count == 8), let value = UInt64(hex, radix: 16) else { return .black }
            if hex.count == 6 {
                return Color(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
            }
            return Color(red: Double((value >> 24) & 255) / 255, green: Double((value >> 16) & 255) / 255,
                         blue: Double((value >> 8) & 255) / 255, opacity: Double(value & 255) / 255)
        }
    }
}

@MainActor
private struct HaloCustomCIComponentRenderer {
    let package: HaloCIParsedPackage
    let workspace: WorkspaceStore
    let runtime: HaloCustomCIRuntimeStore
    let data: [String: String]

    func render(_ component: HaloCIComponent) -> AnyView {
        let raw: AnyView
        switch component.type {
        case "Text":
            raw = AnyView(textView(component))
        case "Image":
            raw = AnyView(imageView(component))
        case "Icon":
            raw = AnyView(Image(systemName: component.systemName ?? "sparkles").resizable().scaledToFit())
        case "Button":
            raw = AnyView(Button {
                if let action = component.action { runtime.perform(action, package: package, workspace: workspace, data: data) }
            } label: {
                if let children = component.children, !children.isEmpty {
                    childStack(children, axis: "horizontal", spacing: component.spacing ?? 7)
                } else {
                    Label(resolve(component.text ?? "Action"), systemImage: component.systemName ?? "arrow.right.circle.fill")
                }
            }.buttonStyle(.borderless))
        case "Toggle":
            let key = component.stateKey ?? "toggle"
            raw = AnyView(Toggle(resolve(component.text ?? "Option"), isOn: Binding(
                get: { runtime.boolState(packageID: package.manifest.id, key: key, default: component.defaultBool ?? false) },
                set: { runtime.setBoolState($0, packageID: package.manifest.id, key: key) }
            )).toggleStyle(.switch))
        case "Slider":
            let key = component.stateKey ?? "slider"
            let minimum = component.minimum ?? 0
            let maximum = max(minimum + 0.000001, component.maximum ?? 1)
            let step = max(0.000001, component.step ?? ((maximum - minimum) / 100))
            raw = AnyView(Slider(value: Binding(
                get: { min(maximum, max(minimum, runtime.numberState(packageID: package.manifest.id, key: key, default: component.defaultNumber ?? minimum))) },
                set: { runtime.setNumberState($0, packageID: package.manifest.id, key: key) }
            ), in: minimum...maximum, step: step))
        case "Progress":
            raw = AnyView(ProgressView(value: normalizedProgress(component.value)))
        case "ProgressRing":
            let progress = normalizedProgress(component.value)
            raw = AnyView(ZStack {
                Circle().stroke(Color.white.opacity(0.12), lineWidth: 4)
                Circle().trim(from: 0, to: progress).stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
                Text("\(Int((progress * 100).rounded()))%").font(.system(size: 9, weight: .semibold, design: .rounded))
            }.aspectRatio(1, contentMode: .fit))
        case "Spacer": raw = AnyView(Spacer(minLength: component.width ?? 4))
        case "Divider": raw = AnyView(Divider().opacity(0.45))
        case "HStack": raw = AnyView(childStack(component.children ?? [], axis: "horizontal", spacing: component.spacing ?? 8))
        case "VStack": raw = AnyView(childStack(component.children ?? [], axis: "vertical", spacing: component.spacing ?? 8))
        case "ZStack": raw = AnyView(ZStack { childViews(component.children ?? []) })
        case "Grid":
            let columns = min(8, max(1, component.columns ?? 2))
            raw = AnyView(LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: component.spacing ?? 8), count: columns), spacing: component.spacing ?? 8) { childViews(component.children ?? []) })
        case "ScrollView":
            if component.axis == "horizontal" {
                raw = AnyView(ScrollView(.horizontal, showsIndicators: false) { childStack(component.children ?? [], axis: "horizontal", spacing: component.spacing ?? 8) })
            } else {
                raw = AnyView(ScrollView(.vertical, showsIndicators: false) { childStack(component.children ?? [], axis: "vertical", spacing: component.spacing ?? 8) })
            }
        case "Badge":
            raw = AnyView(Text(resolve(component.text ?? "Badge")).font(.system(size: 9, weight: .semibold, design: .rounded)).padding(.horizontal, 8).padding(.vertical, 4).background(Color.white.opacity(0.10), in: Capsule()))
        case "NotchContainer":
            raw = AnyView(childStack(component.children ?? [], axis: component.axis == "horizontal" ? "horizontal" : "vertical", spacing: component.spacing ?? 8))
        case "MediaArtwork":
            if runtime.hasPermission(package.manifest.id, "Media.ReadState"), let image = workspace.media.artworkImage {
                raw = AnyView(Image(nsImage: image).resizable().scaledToFill().clipShape(RoundedRectangle(cornerRadius: component.cornerRadius ?? 10, style: .continuous)))
            } else {
                raw = AnyView(placeholder(symbol: "music.note", title: runtime.hasPermission(package.manifest.id, "Media.ReadState") ? "No artwork" : "Media permission off"))
            }
        case "AppIcon":
            if runtime.hasPermission(package.manifest.id, "Applications.Observe"), let icon = NSWorkspace.shared.frontmostApplication?.icon {
                raw = AnyView(Image(nsImage: icon).resizable().scaledToFit())
            } else {
                raw = AnyView(placeholder(symbol: "app", title: runtime.hasPermission(package.manifest.id, "Applications.Observe") ? "No app" : "App permission off"))
            }
        case "DeviceBattery":
            let level = Double(workspace.system.battery ?? 0) / 100
            raw = AnyView(HStack(spacing: 6) {
                Image(systemName: workspace.system.charging ? "battery.100percent.bolt" : "battery.100percent")
                ProgressView(value: level)
                if let battery = workspace.system.battery { Text("\(battery)%").monospacedDigit() }
            }.font(.caption))
        case "SystemMetric": raw = AnyView(systemMetric(component.metric ?? "cpu"))
        case "ActivityIndicator": raw = AnyView(ProgressView().controlSize(.small))
        default: raw = AnyView(EmptyView())
        }
        return applyStyle(raw, component: component)
    }

    private func textView(_ component: HaloCIComponent) -> some View {
        let text = Text(resolve(component.text ?? component.value ?? ""))
        switch component.style {
        case "title": return AnyView(text.font(.title3.bold()))
        case "headline": return AnyView(text.font(.headline))
        case "caption": return AnyView(text.font(.caption))
        case "monospaced": return AnyView(text.font(.system(.body, design: .monospaced)))
        default: return AnyView(text.font(.body))
        }
    }

    private func imageView(_ component: HaloCIComponent) -> some View {
        Group {
            if let source = component.source,
               let url = runtime.assetURL(packageID: package.manifest.id, source: source),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                placeholder(symbol: "photo", title: "Asset unavailable")
            }
        }
    }

    private func childViews(_ children: [HaloCIComponent]) -> some View {
        ForEach(Array(children.enumerated()), id: \.offset) { _, child in render(child) }
    }

    @ViewBuilder
    private func childStack(_ children: [HaloCIComponent], axis: String, spacing: Double) -> some View {
        if axis == "horizontal" {
            HStack(alignment: .center, spacing: spacing) { childViews(children) }
        } else {
            VStack(alignment: .leading, spacing: spacing) { childViews(children) }
        }
    }

    private func systemMetric(_ metric: String) -> some View {
        let title: String
        let value: String
        let symbol: String
        switch metric {
        case "battery": title = "Battery"; value = workspace.system.battery.map { "\($0)%" } ?? "—"; symbol = "battery.100percent"
        case "memory": title = "Memory"; value = String(format: "%.0f%%", workspace.system.memoryUsage); symbol = "memorychip"
        case "storage": title = "Storage"; value = String(format: "%.0f%%", workspace.system.diskUsage); symbol = "internaldrive"
        case "networkDown": title = "Down"; value = byteRate(workspace.system.networkDownPerSecond); symbol = "arrow.down"
        case "networkUp": title = "Up"; value = byteRate(workspace.system.networkUpPerSecond); symbol = "arrow.up"
        case "thermal": title = "Thermal"; value = workspace.system.thermalState; symbol = "thermometer.medium"
        default: title = "CPU"; value = String(format: "%.0f%%", workspace.system.cpuUsage); symbol = "cpu"
        }
        return AnyView(HStack(spacing: 7) {
            Image(systemName: symbol).foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                Text(value).font(.caption.weight(.semibold)).monospacedDigit()
            }
        })
    }

    private func placeholder(symbol: String, title: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol).font(.title3)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func applyStyle(_ view: AnyView, component: HaloCIComponent) -> AnyView {
        var result = view
        if let width = component.width, let height = component.height {
            result = AnyView(result.frame(width: width, height: height))
        } else if let width = component.width {
            result = AnyView(result.frame(width: width))
        } else if let height = component.height {
            result = AnyView(result.frame(height: height))
        }
        if let lineLimit = component.lineLimit { result = AnyView(result.lineLimit(lineLimit)) }
        if let foreground = component.foreground, let color = color(foreground) { result = AnyView(result.foregroundStyle(color)) }
        if let padding = component.padding { result = AnyView(result.padding(padding)) }
        if let background = component.background, let color = color(background) {
            let radius = component.cornerRadius ?? 0
            result = AnyView(result.background(color, in: RoundedRectangle(cornerRadius: radius, style: .continuous)))
        }
        if let label = component.accessibilityLabel, !label.isEmpty { result = AnyView(result.accessibilityLabel(label)) }
        return result
    }

    private func resolve(_ value: String) -> String { HaloCIBindingResolver.resolve(value, data: data) }
    private func normalizedProgress(_ value: String?) -> Double {
        guard let value else { return 0 }
        let resolved = resolve(value).trimmingCharacters(in: .whitespacesAndNewlines)
        guard var number = Double(resolved), number.isFinite else { return 0 }
        if number > 1 { number /= 100 }
        return min(1, max(0, number))
    }

    private func color(_ raw: String) -> Color? {
        switch raw.lowercased() {
        case "accent": return .accentColor
        case "white": return .white
        case "black": return .black
        case "clear": return .clear
        case "secondary": return .white.opacity(0.62)
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "blue": return .blue
        default:
            var hex = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if hex.hasPrefix("#") { hex.removeFirst() }
            guard hex.count == 6 || hex.count == 8, let value = UInt64(hex, radix: 16) else { return nil }
            if hex.count == 6 {
                return Color(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
            }
            return Color(red: Double((value >> 24) & 0xFF) / 255, green: Double((value >> 16) & 0xFF) / 255, blue: Double((value >> 8) & 0xFF) / 255, opacity: Double(value & 0xFF) / 255)
        }
    }

    private func byteRate(_ bytes: Double) -> String {
        if bytes >= 1_000_000_000 { return String(format: "%.1f GB/s", bytes / 1_000_000_000) }
        if bytes >= 1_000_000 { return String(format: "%.1f MB/s", bytes / 1_000_000) }
        if bytes >= 1_000 { return String(format: "%.0f KB/s", bytes / 1_000) }
        return String(format: "%.0f B/s", bytes)
    }
}


private struct LiveActivityContextView: View {
    let activity: LiveActivity
    @ObservedObject var workspace: WorkspaceStore
    @ObservedObject var surfaceState: SurfaceState

    @AppStorage("HaloLiveActivitiesHorizontalMargin") private var horizontalMargin = 24.0
    @AppStorage("HaloLiveActivitiesVerticalMargin") private var verticalMargin = 18.0
    @AppStorage("HaloLiveActivitiesSpacing") private var spacing = 12.0
    @AppStorage("HaloLiveActivitiesCornerRadius") private var cornerRadius = 18.0

    @State private var composerActionID: String?
    @State private var actionInput = ""
    @State private var performingActionID: String?
    @State private var actionError: String?

    private var preferredSize: CGSize {
        let detailRows = activity.detail.isEmpty ? 0.0 : 24.0
        let callRows = activity.resolvedKind == .call ? 28.0 : 0.0
        let progressRows = activity.progress == nil ? 0.0 : 24.0
        let actionRows = activity.resolvedActions.isEmpty ? 0.0 : 38.0
        let composerRows = composerActionID == nil ? 0.0 : 42.0
        let errorRows = actionError == nil ? 0.0 : 28.0
        return CGSize(
            width: min(820, max(440, 520 + horizontalMargin * 2)),
            height: min(
                600,
                max(180, 168 + verticalMargin * 2 + detailRows + callRows + progressRows + actionRows + composerRows + errorRows)
            )
        )
    }

    private var sourceIcon: NSImage? {
        guard let bundleID = activity.sourceBundleIdentifier else { return nil }
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
           let icon = running.icon {
            return icon
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: max(4, spacing)) {
            HStack(alignment: .top, spacing: max(8, spacing)) {
                activityIcon
                VStack(alignment: .leading, spacing: max(3, spacing * 0.35)) {
                    if let source = activity.sourceName, !source.isEmpty {
                        Text(source.uppercased())
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Text(activity.title)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .lineLimit(2)
                    if !activity.detail.isEmpty {
                        Text(activity.detail)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
                Spacer(minLength: 8)
                stateBadge
            }

            if activity.resolvedKind == .call,
               activity.resolvedState == .active,
               let startedAt = activity.startedAt {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack(spacing: 7) {
                        Image(systemName: "phone.fill")
                        Text(Self.durationString(context.date.timeIntervalSince(startedAt)))
                            .monospacedDigit()
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
            }

            if let progress = activity.progress {
                VStack(alignment: .leading, spacing: 5) {
                    ProgressView(value: progress)
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if !activity.resolvedActions.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("ACTIONS")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)

                    HStack(spacing: max(7, spacing * 0.6)) {
                        ForEach(Array(activity.resolvedActions.prefix(4))) { action in
                            Button {
                                begin(action)
                            } label: {
                                Label(action.title, systemImage: action.symbolName ?? "bolt.fill")
                                    .lineLimit(1)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(performingActionID != nil)
                            .foregroundStyle(action.role == .destructive ? Color.red : Color.primary)
                        }

                        if performingActionID != nil {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
            }

            if let composerAction {
                HStack(spacing: max(7, spacing * 0.6)) {
                    TextField(composerAction.inputPlaceholder ?? "Reply…", text: $actionInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { submitComposerAction(composerAction) }

                    Button {
                        submitComposerAction(composerAction)
                    } label: {
                        Label("Send", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(
                        actionInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        performingActionID != nil
                    )

                    Button {
                        composerActionID = nil
                        actionInput = ""
                        actionError = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                    .help("Cancel reply")
                }
            }

            if let actionError {
                Label(actionError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            HStack(spacing: max(8, spacing * 0.75)) {
                if activity.sourceBundleIdentifier != nil {
                    Button {
                        openSourceApplication()
                    } label: {
                        Label("Open App", systemImage: "arrow.up.forward.app")
                    }
                }
                Spacer()
                Button {
                    workspace.dismissLiveActivity(id: activity.id)
                } label: {
                    Label("Hide", systemImage: "xmark")
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, max(0, horizontalMargin))
        .padding(.vertical, max(0, verticalMargin))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            if activity.resolvedKind == .call {
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.18), Color.black.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color.clear
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: max(0, cornerRadius), style: .continuous))
        .task(id: sizingKey) { publishPreferredSize() }
        .onChange(of: surfaceState.contextPreferredSize) { requested in
            guard surfaceState.expanded, requested == nil else { return }
            publishPreferredSize()
        }
        .onDisappear { releasePreferredSizeIfOwned() }
    }

    @ViewBuilder
    private var activityIcon: some View {
        if let sourceIcon {
            Image(nsImage: sourceIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            Image(systemName: activity.resolvedSymbolName)
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 42, height: 42)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    @ViewBuilder
    private var stateBadge: some View {
        let text: String = {
            switch activity.resolvedState {
            case .incoming: return "Incoming"
            case .active: return activity.resolvedKind == .call ? "Live" : "Active"
            case .ended: return "Ended"
            }
        }()
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.08), in: Capsule())
            .foregroundStyle(.secondary)
    }

    private var sizingKey: String {
        [
            activity.id.uuidString,
            activity.detail,
            String(activity.progress ?? -1),
            activity.resolvedState.rawValue,
            activity.resolvedActions.map(\.id).joined(separator: ","),
            composerActionID ?? "",
            actionError ?? "",
            String(horizontalMargin),
            String(verticalMargin),
            String(spacing)
        ].joined(separator: "|")
    }

    private var composerAction: LiveActivityAction? {
        guard let composerActionID else { return nil }
        return activity.resolvedActions.first(where: { $0.id == composerActionID })
    }

    private func begin(_ action: LiveActivityAction) {
        actionError = nil
        if action.kind == .textReply {
            composerActionID = action.id
            actionInput = ""
            return
        }
        execute(action, input: nil)
    }

    private func submitComposerAction(_ action: LiveActivityAction) {
        let trimmed = actionInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        execute(action, input: trimmed)
    }

    private func execute(_ action: LiveActivityAction, input: String?) {
        guard performingActionID == nil else { return }
        performingActionID = action.id
        actionError = nil

        Task { @MainActor in
            let error = await workspace.performLiveActivityAction(
                activityID: activity.id,
                actionID: action.id,
                input: input
            )
            performingActionID = nil
            actionError = error
            if error == nil, action.kind == .textReply {
                composerActionID = nil
                actionInput = ""
            }
        }
    }

    private func publishPreferredSize() {
        let next = preferredSize
        if let current = surfaceState.contextPreferredSize,
           abs(current.width - next.width) < 1,
           abs(current.height - next.height) < 1 {
            return
        }
        surfaceState.contextPreferredSize = next
    }

    private func releasePreferredSizeIfOwned() {
        guard let current = surfaceState.contextPreferredSize else { return }
        let owned = preferredSize
        guard abs(current.width - owned.width) < 1,
              abs(current.height - owned.height) < 1 else { return }
        surfaceState.contextPreferredSize = nil
    }

    private func openSourceApplication() {
        guard let bundleID = activity.sourceBundleIdentifier else { return }
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            running.activate(options: [.activateAllWindows])
            return
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in }
    }

    private static func durationString(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, seconds) }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
