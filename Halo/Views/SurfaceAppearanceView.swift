import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor enum GeometryPreview {
    static func update(expanded: Bool, editing: Bool, display: NSScreen? = nil) {
        var info: [String: Any] = ["expanded": expanded, "editing": editing]
        if let display { info["display"] = WindowManager.displayID(display) }
        NotificationCenter.default.post(name: .init("HaloGeometryPreview"), object: nil, userInfo: info)
    }
}


enum SurfaceGeometryEditorChromeMetrics {
    static let horizontal: CGFloat = 30
    static let top: CGFloat = 24
    static let bottom: CGFloat = 58
    static let handleOffset: CGFloat = 10
}

enum SurfaceGeometryEditingTarget: String, CaseIterable, Identifiable {
    case closed = "Closed notch"
    case opened = "Opened notch"

    var id: String { rawValue }
    var expanded: Bool { self == .opened }
}

struct SurfaceGeometryEditSnapshot: Equatable {
    var compactWidth: Double
    var compactHeight: Double
    var expandedWidth: Double
    var expandedHeight: Double
    var offsets: SurfaceOffsets
    var cornerRadius: Double

    static func capture(theme: Theme, appearance: Appearance) -> SurfaceGeometryEditSnapshot {
        SurfaceGeometryEditSnapshot(
            compactWidth: appearance.compactWidth,
            compactHeight: appearance.surface.compactHeight,
            expandedWidth: theme.width,
            expandedHeight: appearance.expandedHeight,
            offsets: appearance.surface.offsets ?? SurfaceOffsets(),
            cornerRadius: theme.cornerRadius
        )
    }
}

final class SurfaceGeometryEditingSession: ObservableObject {
    static let shared = SurfaceGeometryEditingSession()

    @Published var isEnabled = false
    @Published var target: SurfaceGeometryEditingTarget = .closed
    @Published var displayID: String?
    @Published var previewSnapshot: SurfaceGeometryEditSnapshot?
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    private var undoStack: [SurfaceGeometryEditSnapshot] = []
    private var redoStack: [SurfaceGeometryEditSnapshot] = []
    private var transactionStart: SurfaceGeometryEditSnapshot?

    private init() {}

    func beginTransaction(_ snapshot: SurfaceGeometryEditSnapshot) {
        if transactionStart == nil { transactionStart = snapshot }
    }

    func commitTransaction(_ snapshot: SurfaceGeometryEditSnapshot) {
        guard let start = transactionStart else { return }
        transactionStart = nil
        recordChange(from: start, to: snapshot)
    }

    func cancelTransaction() {
        transactionStart = nil
        previewSnapshot = nil
    }

    func recordChange(from before: SurfaceGeometryEditSnapshot, to after: SurfaceGeometryEditSnapshot) {
        guard before != after else { return }
        transactionStart = nil
        undoStack.append(before)
        if undoStack.count > 80 {
            undoStack.removeFirst(undoStack.count - 80)
        }
        redoStack.removeAll()
        syncAvailability()
    }

    func undo(current: SurfaceGeometryEditSnapshot) -> SurfaceGeometryEditSnapshot? {
        cancelTransaction()
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(current)
        syncAvailability()
        return previous
    }

    func redo(current: SurfaceGeometryEditSnapshot) -> SurfaceGeometryEditSnapshot? {
        cancelTransaction()
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        syncAvailability()
        return next
    }

    func clearHistory() {
        transactionStart = nil
        previewSnapshot = nil
        undoStack.removeAll()
        redoStack.removeAll()
        syncAvailability()
    }

    private func syncAvailability() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}

struct HaloContour: Shape {
    var kind: SurfaceShapeKind
    var radius: CGFloat
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    var shoulder: CGFloat
    func path(in rect: CGRect) -> Path {
        let r = min(max(0, radius), min(rect.width, rect.height) / 2)
        switch kind {
        case .rounded: return RoundedRectangle(cornerRadius: r).path(in: rect)
        case .capsule: return Capsule().path(in: rect)
        case .squircle: return RoundedRectangle(cornerRadius: min(rect.width, rect.height) * 0.4, style: .continuous).path(in: rect)
        case .asymmetric: return corners(in: rect, top: topRadius, bottom: bottomRadius)
        case .notch: return corners(in: rect, top: min(4, r), bottom: r)
        case .scoop:
            let s = min(shoulder, min(rect.width / 4, rect.height / 2))
            let bottom = min(r, min((rect.width - 2 * s) / 2, (rect.height - s) / 2))
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX - s, y: rect.minY + s), control: CGPoint(x: rect.maxX - s, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - s, y: rect.maxY - bottom))
            p.addQuadCurve(to: CGPoint(x: rect.maxX - s - bottom, y: rect.maxY), control: CGPoint(x: rect.maxX - s, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX + s + bottom, y: rect.maxY))
            p.addQuadCurve(to: CGPoint(x: rect.minX + s, y: rect.maxY - bottom), control: CGPoint(x: rect.minX + s, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX + s, y: rect.minY + s))
            p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: rect.minX + s, y: rect.minY))
            p.closeSubpath(); return p
        case .chamfer, .tapered:
            let s = min(max(0, shoulder), min(rect.width / 4, rect.height / 2))
            let points: [CGPoint] = kind == .tapered ? [
                CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                CGPoint(x: rect.maxX - s, y: rect.maxY), CGPoint(x: rect.minX + s, y: rect.maxY)
            ] : [
                CGPoint(x: rect.minX + s, y: rect.minY), CGPoint(x: rect.maxX - s, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.minY + s), CGPoint(x: rect.maxX, y: rect.maxY - s),
                CGPoint(x: rect.maxX - s, y: rect.maxY), CGPoint(x: rect.minX + s, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.maxY - s), CGPoint(x: rect.minX, y: rect.minY + s)
            ]
            var p = Path(); p.addLines(points); p.closeSubpath(); return p
        }
    }
    private func corners(in rect: CGRect, top: CGFloat, bottom: CGFloat) -> Path {
        let t = min(max(0, top), min(rect.width, rect.height) / 2)
        let b = min(max(0, bottom), min(rect.width, rect.height) / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + t, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - t, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + t), control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - b))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - b, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + b, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - b), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + t))
        p.addQuadCurve(to: CGPoint(x: rect.minX + t, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath(); return p
    }
}

enum SurfaceAppearanceScope {
    case all, background, geometry, closedGeometry, openedPosition, surfaceGeometry, motion
}

private enum GlassAppearancePreset: String, CaseIterable, Identifiable {
    case crystal = "Crystal"
    case balanced = "Balanced"
    case frosted = "Frosted"
    case smoked = "Smoked"
    case prism = "Prism"

    var id: String { rawValue }

    var options: GlassOptions {
        switch self {
        case .crystal:
            return GlassOptions(
                clarity: 0.94,
                frost: 0.14,
                lightAbsorption: 0.04,
                refraction: 0.06,
                chromaticShift: 0.02,
                tint: WidgetColor(red: 0.80, green: 0.88, blue: 1.0),
                tintAmount: 0.015,
                highlight: 0.10,
                edgeDepth: 0.03
            )
        case .balanced:
            return GlassOptions()
        case .frosted:
            return GlassOptions(
                clarity: 0.46,
                frost: 0.82,
                lightAbsorption: 0.18,
                refraction: 0.20,
                chromaticShift: 0.04,
                tint: WidgetColor(red: 0.76, green: 0.84, blue: 1.0),
                tintAmount: 0.055,
                highlight: 0.18,
                edgeDepth: 0.13
            )
        case .smoked:
            return GlassOptions(
                clarity: 0.62,
                frost: 0.52,
                lightAbsorption: 0.52,
                refraction: 0.13,
                chromaticShift: 0.03,
                tint: WidgetColor(red: 0.24, green: 0.28, blue: 0.34),
                tintAmount: 0.16,
                highlight: 0.07,
                edgeDepth: 0.22
            )
        case .prism:
            return GlassOptions(
                clarity: 0.74,
                frost: 0.38,
                lightAbsorption: 0.10,
                refraction: 0.38,
                chromaticShift: 0.72,
                tint: WidgetColor(red: 0.64, green: 0.78, blue: 1.0),
                tintAmount: 0.07,
                highlight: 0.24,
                edgeDepth: 0.07
            )
        }
    }
}

@MainActor struct SurfaceAppearanceControls: View {
    @Binding var appearance: Appearance
    let theme: Theme
    var screen: NSScreen?
    var scope: SurfaceAppearanceScope = .all
    var previewSurface: ((Bool) -> Void)? = nil
    @AppStorage("HaloContextOffsetX") private var contextOffsetX = 0.0
    @AppStorage("HaloContextOffsetY") private var contextOffsetY = 0.0
    @AppStorage("HaloContextUsesOpenedPosition") private var contextUsesOpenedPosition = true

    private let solidPresets: [WidgetColor] = [
        WidgetColor(red: 0.02, green: 0.02, blue: 0.025),
        WidgetColor(red: 0.06, green: 0.08, blue: 0.12),
        WidgetColor(red: 0.08, green: 0.06, blue: 0.14),
        WidgetColor(red: 0.12, green: 0.055, blue: 0.055),
        WidgetColor(red: 0.045, green: 0.11, blue: 0.095),
        WidgetColor(red: 0.16, green: 0.16, blue: 0.17)
    ]

    private let gradientPresets: [(WidgetColor, WidgetColor)] = [
        (WidgetColor(red: 0.06, green: 0.16, blue: 0.34), WidgetColor(red: 0.01, green: 0.015, blue: 0.03)),
        (WidgetColor(red: 0.22, green: 0.08, blue: 0.42), WidgetColor(red: 0.02, green: 0.015, blue: 0.08)),
        (WidgetColor(red: 0.04, green: 0.38, blue: 0.34), WidgetColor(red: 0.02, green: 0.05, blue: 0.12)),
        (WidgetColor(red: 0.55, green: 0.15, blue: 0.12), WidgetColor(red: 0.16, green: 0.025, blue: 0.10)),
        (WidgetColor(red: 0.16, green: 0.22, blue: 0.42), WidgetColor(red: 0.23, green: 0.08, blue: 0.28)),
        (WidgetColor(red: 0.22, green: 0.22, blue: 0.24), WidgetColor(red: 0.015, green: 0.015, blue: 0.02))
    ]

    var body: some View {
        if scope == .all || scope == .background {
            backgroundStyleControls
            backgroundColorControls
        }

        if scope == .all || scope == .geometry || scope == .closedGeometry {
            Section {
                PreciseSlider(title: "Width", value: $appearance.compactWidth, range: 16...640, step: 1, suffix: "pt", onEditingChanged: {
                    GeometryPreview.update(expanded: false, editing: $0, display: screen)
                })
                PreciseSlider(title: "Height", value: $appearance.surface.compactHeight, range: 16...100, step: 1, suffix: "pt", onEditingChanged: {
                    GeometryPreview.update(expanded: false, editing: $0, display: screen)
                })

                if let screen {
                    let geometry = WindowManager.geometry(screen: screen, theme: theme, appearance: appearance)
                    Text("Effective size: \(Int(geometry.compactWidth)) × \(Int(geometry.compactHeight)) pt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                OffsetPositionPad(
                    x: offsetBinding(\.closedX),
                    y: offsetBinding(\.closedY),
                    constraint: surfaceOffsetConstraint(expanded: false),
                    onEditingChanged: {
                        GeometryPreview.update(expanded: false, editing: $0, display: screen)
                    }
                )

                offsetControl("Horizontal", key: \.closedX, expanded: false)
                offsetControl("Vertical", key: \.closedY, expanded: false)

                HStack {
                    Spacer()
                    Button {
                        var offsets = appearance.surface.offsets ?? SurfaceOffsets()
                        offsets.closedX = 0
                        offsets.closedY = 0
                        appearance.surface.offsets = offsets
                        GeometryPreview.update(expanded: false, editing: false, display: screen)
                    } label: {
                        Label("Reset position", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderless)
                }
            } header: {
                geometryPreviewHeader("Closed notch size & position", expanded: false)
            }
        }

        if scope == .all || scope == .geometry || scope == .openedPosition {
            Section {
                OffsetPositionPad(
                    x: offsetBinding(\.openedX),
                    y: offsetBinding(\.openedY),
                    constraint: surfaceOffsetConstraint(expanded: true),
                    onEditingChanged: {
                        GeometryPreview.update(expanded: true, editing: $0, display: screen)
                    }
                )

                offsetControl("Horizontal", key: \.openedX, expanded: true)
                offsetControl("Vertical", key: \.openedY, expanded: true)

                HStack {
                    Spacer()
                    Button {
                        var offsets = appearance.surface.offsets ?? SurfaceOffsets()
                        offsets.openedX = 0
                        offsets.openedY = 0
                        appearance.surface.offsets = offsets
                        GeometryPreview.update(expanded: true, editing: false, display: screen)
                    } label: {
                        Label("Reset position", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderless)
                }
            } header: {
                geometryPreviewHeader("Opened position", expanded: true)
            }

            Section {
                Toggle("Follow opened notch position", isOn: $contextUsesOpenedPosition)
                    .onChange(of: contextUsesOpenedPosition) { followsOpened in
                        if followsOpened {
                            contextOffsetX = 0
                            contextOffsetY = 0
                        }
                    }

                if contextUsesOpenedPosition {
                    Text("Context Interfaces use the same position as the opened notch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Add an extra offset only when a Context Interface is active.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    OffsetPositionPad(x: $contextOffsetX, y: $contextOffsetY)
                    PreciseSlider(title: "Horizontal offset", value: $contextOffsetX, range: -1000...1000, step: 1, suffix: "pt")
                    PreciseSlider(title: "Vertical offset", value: $contextOffsetY, range: -1000...1000, step: 1, suffix: "pt")

                    HStack {
                        Spacer()
                        Button {
                            contextOffsetX = 0
                            contextOffsetY = 0
                        } label: {
                            Label("Reset offset", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            } header: {
                geometryPreviewHeader("Context Interface position", expanded: true)
            }
            .onAppear {
                // Preserve existing custom CI offsets from older builds.
                if abs(contextOffsetX) >= 0.5 || abs(contextOffsetY) >= 0.5 {
                    contextUsesOpenedPosition = false
                }
            }
        }

        if scope == .all || scope == .geometry || scope == .surfaceGeometry {
            Section("Shape") {
                Toggle("Use surface style contour", isOn: Binding(get: { appearance.surface.useStyleContour ?? true }, set: { appearance.surface.useStyleContour = $0 }))
                Text("Turn off to use a custom contour below.").font(.caption)

                Toggle(
                    "Show outer outline",
                    isOn: Binding(
                        get: { appearance.surface.outlineEnabled ?? true },
                        set: { appearance.surface.outlineEnabled = $0 }
                    )
                )
                Text("Disables Halo's default thin outer contour. Visual Workspace Border, Glow and Shadow remain independently configurable in its Edge & depth section.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Contour", selection: Binding(get: { appearance.surface.shape }, set: { appearance.surface.shape = $0; appearance.surface.useStyleContour = false })) { ForEach(SurfaceShapeKind.allCases) { Text($0.rawValue).tag($0) } }
                if appearance.surface.shape == .asymmetric {
                    PreciseSlider(title: "Top corners", value: $appearance.surface.topRadius, range: 0...64, step: 1, suffix: "pt")
                    PreciseSlider(title: "Bottom corners", value: $appearance.surface.bottomRadius, range: 0...64, step: 1, suffix: "pt")
                }
                if [.scoop, .chamfer, .tapered].contains(appearance.surface.shape) {
                    PreciseSlider(title: "Shoulder / cut depth", value: $appearance.surface.shoulder, range: 0...48, step: 1, suffix: "pt")
                }
                HaloContour(kind: appearance.surface.shape, radius: theme.cornerRadius, topRadius: appearance.surface.topRadius,
                            bottomRadius: appearance.surface.bottomRadius, shoulder: appearance.surface.shoulder)
                    .fill(Color(hue: theme.tint, saturation: 0.6, brightness: 0.5)).frame(height: 80)
                    .accessibilityLabel("\(appearance.surface.shape.rawValue) preview")
            }
        }

        if scope == .all || scope == .motion {
            Section("Transitions") {
                GroupBox("Opening") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Transition", selection: $appearance.surface.opening) { ForEach(SurfaceTransition.allCases) { Text($0.rawValue).tag($0) } }
                        PreciseSlider(title: "Duration", value: Binding(
                            get: { appearance.surface.resolvedOpeningDuration },
                            set: { appearance.surface.openingDuration = $0 }
                        ), range: 0.1...1.2, step: 0.05, suffix: "s", decimals: 2)
                        if appearance.surface.opening == .spring {
                            PreciseSlider(title: "Spring damping", value: Binding(
                                get: { appearance.surface.resolvedOpeningDamping },
                                set: { appearance.surface.openingDamping = $0 }
                            ), range: 0.4...1, step: 0.05, decimals: 2)
                        }
                    }.padding(4)
                }
                GroupBox("Closing") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Transition", selection: $appearance.surface.closing) { ForEach(SurfaceTransition.allCases) { Text($0.rawValue).tag($0) } }
                        PreciseSlider(title: "Duration", value: Binding(
                            get: { appearance.surface.resolvedClosingDuration },
                            set: { appearance.surface.closingDuration = $0 }
                        ), range: 0.1...1.2, step: 0.05, suffix: "s", decimals: 2)
                        if appearance.surface.closing == .spring {
                            PreciseSlider(title: "Spring damping", value: Binding(
                                get: { appearance.surface.resolvedClosingDamping },
                                set: { appearance.surface.closingDamping = $0 }
                            ), range: 0.4...1, step: 0.05, decimals: 2)
                        }
                    }.padding(4)
                }
                if appearance.surface.opening == .spring || appearance.surface.closing == .spring {
                    Text("Lower damping adds bounce; higher damping settles sooner. Each direction is tuned independently.").font(.caption)
                }
                Text("Reduce Motion and the animation-off setting make transitions immediate.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var backgroundStyleControls: some View {
        Section("Background style") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                backgroundStyleButton(.solid, title: "Solid", symbol: "circle.fill")
                backgroundStyleButton(.gradient, title: "Gradient", symbol: "circle.lefthalf.filled")
                backgroundStyleButton(.glass, title: "Glass", symbol: "square.on.square")
                backgroundStyleButton(.image, title: "Image", symbol: "photo.fill")
                backgroundStyleButton(.video, title: "Video", symbol: "film.fill")
            }
            Text("Choose the background type visually. Image and Video keep a local file reference and can be changed below.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var backgroundColorControls: some View {
        if appearance.background == .solid {
            Section("Background color") {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(solidColor)
                    .frame(height: 72)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.12)))

                HStack(spacing: 9) {
                    ForEach(Array(solidPresets.enumerated()), id: \.offset) { _, preset in
                        Button { appearance.solidColor = preset } label: {
                            Circle().fill(preset.color).frame(width: 30, height: 30)
                                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .help("Apply color preset")
                    }
                }

                ColorPicker("Custom background color", selection: solidColorBinding, supportsOpacity: false)
                Button("Reset to Halo black") { appearance.solidColor = nil }
            }
        } else if appearance.background == .gradient {
            Section("Gradient") {
                LinearGradient(colors: [gradientStartColor, gradientEndColor], startPoint: .bottomLeading, endPoint: .topTrailing)
                    .frame(height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.12)))

                Text("Presets").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                HStack(spacing: 9) {
                    ForEach(Array(gradientPresets.enumerated()), id: \.offset) { _, preset in
                        Button {
                            appearance.gradientStartColor = preset.0
                            appearance.gradientEndColor = preset.1
                        } label: {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(LinearGradient(colors: [preset.0.color, preset.1.color], startPoint: .bottomLeading, endPoint: .topTrailing))
                                .frame(width: 48, height: 30)
                                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Color.white.opacity(0.15)))
                        }
                        .buttonStyle(.plain)
                        .help("Apply gradient preset")
                    }
                }

                HStack(spacing: 16) {
                    ColorPicker("Start", selection: gradientStartBinding, supportsOpacity: false)
                    ColorPicker("End", selection: gradientEndBinding, supportsOpacity: false)
                    Button {
                        let start = appearance.gradientStartColor ?? widgetColor(from: gradientStartColor)
                        let end = appearance.gradientEndColor ?? widgetColor(from: gradientEndColor)
                        appearance.gradientStartColor = end
                        appearance.gradientEndColor = start
                    } label: {
                        Label("Swap", systemImage: "arrow.left.arrow.right")
                    }
                }

                Button("Reset to Halo gradient") {
                    appearance.gradientStartColor = nil
                    appearance.gradientEndColor = nil
                }
            }
        } else if appearance.background == .glass {
            Section("Glass behavior") {
                Text("Halo keeps macOS's live backdrop sampling and layers optical controls on top. Frost changes the native material family; clarity changes how strongly that material is composited.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 7) {
                        ForEach(GlassAppearancePreset.allCases) { preset in
                            Button(preset.rawValue) { appearance.glass = preset.options }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                    Menu("Glass preset") {
                        ForEach(GlassAppearancePreset.allCases) { preset in
                            Button(preset.rawValue) { appearance.glass = preset.options }
                        }
                    }
                }

                PreciseSlider(title: "Clarity", value: $appearance.glass.clarity, range: 0...1, step: 0.01, decimals: 2)
                PreciseSlider(title: "Frost", value: $appearance.glass.frost, range: 0...1, step: 0.01, decimals: 2)
                PreciseSlider(title: "Light absorption", value: $appearance.glass.lightAbsorption, range: 0...1, step: 0.01, decimals: 2)
                PreciseSlider(title: "Refraction", value: $appearance.glass.refraction, range: 0...1, step: 0.01, decimals: 2)
                Text("Refraction controls how strongly Halo participates in the native Liquid Glass effect.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                PreciseSlider(title: "Chromatic alteration", value: $appearance.glass.chromaticShift, range: 0...1, step: 0.01, decimals: 2)

                ColorPicker("Glass tint", selection: Binding(
                    get: { appearance.glass.tint.color },
                    set: { appearance.glass.tint = widgetColor(from: $0) }
                ), supportsOpacity: false)
                PreciseSlider(title: "Tint strength", value: $appearance.glass.tintAmount, range: 0...0.5, step: 0.01, decimals: 2)
                PreciseSlider(title: "Specular highlight", value: $appearance.glass.highlight, range: 0...1, step: 0.01, decimals: 2)
                PreciseSlider(title: "Edge depth", value: $appearance.glass.edgeDepth, range: 0...1, step: 0.01, decimals: 2)

                Button("Reset glass") { appearance.glass = GlassOptions() }
            }
        } else if appearance.background == .image || appearance.background == .video {
            Section(appearance.background == .image ? "Image background" : "Video background") {
                HStack(spacing: 12) {
                    Image(systemName: appearance.background == .image ? "photo.fill" : "film.fill")
                        .font(.system(size: 24, weight: .medium))
                        .frame(width: 46, height: 46)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(appearance.assetPath.isEmpty ? "No file selected" : URL(fileURLWithPath: appearance.assetPath).lastPathComponent)
                            .font(.callout.weight(.medium)).lineLimit(1)
                        Text(appearance.background == .image ? "Use a local image as Halo's surface background." : "Use a muted, looping local video as Halo's surface background.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Button(appearance.assetPath.isEmpty ? "Choose file…" : "Change file…") {
                    chooseBackgroundFile(for: appearance.background)
                }
                if !appearance.assetPath.isEmpty {
                    Button("Clear selected file", role: .destructive) { appearance.assetPath = "" }
                }
            }
        }
    }

    private func backgroundStyleButton(_ kind: BackgroundKind, title: String, symbol: String) -> some View {
        let selected = appearance.background == kind
        return Button {
            appearance.background = kind
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(backgroundPreview(for: kind))
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .frame(height: 48)
                Text(title).font(.caption.weight(selected ? .semibold : .regular))
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(selected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(selected ? Color.accentColor.opacity(0.8) : Color.primary.opacity(0.08), lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

    private func backgroundPreview(for kind: BackgroundKind) -> AnyShapeStyle {
        switch kind {
        case .solid:
            return AnyShapeStyle(solidColor)
        case .gradient:
            return AnyShapeStyle(LinearGradient(colors: [gradientStartColor, gradientEndColor], startPoint: .bottomLeading, endPoint: .topTrailing))
        case .glass:
            return AnyShapeStyle(LinearGradient(colors: [Color.white.opacity(0.24), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
        case .image:
            return AnyShapeStyle(LinearGradient(colors: [Color.indigo.opacity(0.72), Color.blue.opacity(0.34)], startPoint: .topLeading, endPoint: .bottomTrailing))
        case .video:
            return AnyShapeStyle(LinearGradient(colors: [Color.purple.opacity(0.66), Color.black.opacity(0.74)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    private var solidColor: Color { appearance.solidColor?.color ?? .black }
    private var gradientStartColor: Color {
        appearance.gradientStartColor?.color ?? Color(hue: theme.tint, saturation: 0.7, brightness: 0.35)
    }
    private var gradientEndColor: Color { appearance.gradientEndColor?.color ?? .black }

    private var solidColorBinding: Binding<Color> {
        Binding(get: { solidColor }, set: { appearance.solidColor = widgetColor(from: $0) })
    }
    private var gradientStartBinding: Binding<Color> {
        Binding(get: { gradientStartColor }, set: { appearance.gradientStartColor = widgetColor(from: $0) })
    }
    private var gradientEndBinding: Binding<Color> {
        Binding(get: { gradientEndColor }, set: { appearance.gradientEndColor = widgetColor(from: $0) })
    }

    private func widgetColor(from color: Color) -> WidgetColor {
        guard let rgb = NSColor(color).usingColorSpace(.deviceRGB) else { return .accent }
        return WidgetColor(red: Double(rgb.redComponent), green: Double(rgb.greenComponent), blue: Double(rgb.blueComponent))
    }

    private func chooseBackgroundFile(for kind: BackgroundKind) {
        guard kind == .image || kind == .video else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = kind == .image ? [.image] : [.movie]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        appearance.assetPath = url.path
        appearance.background = kind
    }

    @ViewBuilder
    private func geometryPreviewHeader(_ title: String, expanded: Bool) -> some View {
        HStack(spacing: 10) {
            Text(title)
            Spacer()
            if let previewSurface {
                Button {
                    previewSurface(expanded)
                } label: {
                    Label("Preview", systemImage: expanded ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help(expanded ? "Keep Halo open while previewing this section" : "Keep Halo closed while previewing this section")
            }
        }
    }

    private func surfaceOffsetConstraint(expanded: Bool) -> ((Double, Double) -> OffsetDragResult)? {
        guard let screen else { return nil }

        return { rawX, rawY in
            var previewAppearance = appearance
            var offsets = previewAppearance.surface.offsets ?? SurfaceOffsets()

            if expanded {
                offsets.openedX = rawX
                offsets.openedY = rawY
            } else {
                offsets.closedX = rawX
                offsets.closedY = rawY
            }
            previewAppearance.surface.offsets = offsets

            let geometry = WindowManager.geometry(screen: screen, theme: theme, appearance: previewAppearance)
            let frame = geometry.frame(expanded: expanded)
            let bounds = screen.frame
            let contactTolerance: CGFloat = 0.75
            let stickyDistance: CGFloat = 24
            let releaseScale: CGFloat = 0.38

            var adjustedX = rawX
            var adjustedY = rawY
            var edges = Set<OffsetPadEdge>()

            if frame.minX <= bounds.minX + contactTolerance {
                edges.insert(.left)
                let overshoot = bounds.minX - frame.minX
                if overshoot > 0 {
                    let boundary = rawX + Double(overshoot)
                    adjustedX = overshoot <= stickyDistance
                        ? boundary
                        : boundary - Double((overshoot - stickyDistance) * releaseScale)
                }
            } else if frame.maxX >= bounds.maxX - contactTolerance {
                edges.insert(.right)
                let overshoot = frame.maxX - bounds.maxX
                if overshoot > 0 {
                    let boundary = rawX - Double(overshoot)
                    adjustedX = overshoot <= stickyDistance
                        ? boundary
                        : boundary + Double((overshoot - stickyDistance) * releaseScale)
                }
            }

            // UI Y grows downward, while AppKit screen Y grows upward.
            if frame.minY <= bounds.minY + contactTolerance {
                edges.insert(.bottom)
                let overshoot = bounds.minY - frame.minY
                if overshoot > 0 {
                    let boundary = rawY - Double(overshoot)
                    adjustedY = overshoot <= stickyDistance
                        ? boundary
                        : boundary + Double((overshoot - stickyDistance) * releaseScale)
                }
            } else if frame.maxY >= bounds.maxY - contactTolerance {
                edges.insert(.top)
                let overshoot = frame.maxY - bounds.maxY
                if overshoot > 0 {
                    let boundary = rawY + Double(overshoot)
                    adjustedY = overshoot <= stickyDistance
                        ? boundary
                        : boundary - Double((overshoot - stickyDistance) * releaseScale)
                }
            }

            return OffsetDragResult(x: adjustedX, y: adjustedY, edges: edges)
        }
    }

    private func offsetBinding(_ key: WritableKeyPath<SurfaceOffsets, Double>) -> Binding<Double> {
        Binding(
            get: { (appearance.surface.offsets ?? SurfaceOffsets())[keyPath: key] },
            set: {
                var offsets = appearance.surface.offsets ?? SurfaceOffsets()
                offsets[keyPath: key] = $0
                appearance.surface.offsets = offsets
            }
        )
    }

    private func offsetControl(_ title: String, key: WritableKeyPath<SurfaceOffsets, Double>, expanded: Bool) -> some View {
        PreciseSlider(
            title: title,
            value: offsetBinding(key),
            range: -1000...1000,
            step: 1,
            suffix: "pt",
            onEditingChanged: {
                GeometryPreview.update(expanded: expanded, editing: $0, display: screen)
            }
        )
    }
}

private enum OffsetPadEdge: Hashable {
    case left, right, top, bottom
}

private struct OffsetDragResult {
    var x: Double
    var y: Double
    var edges: Set<OffsetPadEdge> = []
}

private struct OffsetPositionPad: View {
    @Binding var x: Double
    @Binding var y: Double

    var range: ClosedRange<Double> = -160...160
    var constraint: ((Double, Double) -> OffsetDragResult)? = nil
    var onEditingChanged: ((Bool) -> Void)? = nil

    @State private var dragging = false
    @State private var contactEdges = Set<OffsetPadEdge>()
    @State private var lastHapticX: Int?
    @State private var lastHapticY: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Drag to position")
                    .font(.caption.weight(.medium))
                Spacer()
                Text("X \(Int(x.rounded()))   Y \(Int(y.rounded()))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                let size = proxy.size

                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.035))

                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.10), lineWidth: 1)

                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 1)

                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 1)

                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white.opacity(0.75), lineWidth: 1))
                        .shadow(radius: 2)
                        .position(
                            x: position(for: x, length: size.width),
                            y: position(for: y, length: size.height)
                        )
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            if !dragging {
                                dragging = true
                                let initial = constraint?(x, y) ?? OffsetDragResult(x: x, y: y)
                                contactEdges = initial.edges
                                lastHapticX = hapticIndex(x)
                                lastHapticY = hapticIndex(y)
                                onEditingChanged?(true)
                            }

                            let rawX = value(for: gesture.location.x, length: size.width)
                            let rawY = value(for: gesture.location.y, length: size.height)
                            let result = constraint?(rawX, rawY) ?? OffsetDragResult(x: rawX, y: rawY)
                            let newlyTouched = result.edges.subtracting(contactEdges)

                            if !newlyTouched.isEmpty {
                                performEdgeHaptic()
                            } else {
                                performDragHapticIfNeeded(x: result.x, y: result.y)
                            }

                            contactEdges = result.edges
                            x = result.x
                            y = result.y
                        }
                        .onEnded { _ in
                            dragging = false
                            contactEdges.removeAll()
                            lastHapticX = nil
                            lastHapticY = nil
                            onEditingChanged?(false)
                        }
                )
            }
            .frame(height: 108)

            Text("Edges have a magnetic stop. Push a little farther to move Halo beyond the screen.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func hapticIndex(_ value: Double) -> Int {
        Int((value / 10).rounded())
    }

    private func performDragHapticIfNeeded(x: Double, y: Double) {
        let nextX = hapticIndex(x)
        let nextY = hapticIndex(y)
        guard nextX != lastHapticX || nextY != lastHapticY else { return }
        lastHapticX = nextX
        lastHapticY = nextY
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    private func performEdgeHaptic() {
        let performer = NSHapticFeedbackManager.defaultPerformer
        performer.perform(.levelChange, performanceTime: .now)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.045) {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
    }

    private func position(for value: Double, length: CGFloat) -> CGFloat {
        guard length > 0, range.upperBound > range.lowerBound else { return length / 2 }
        let clamped = min(range.upperBound, max(range.lowerBound, value))
        let fraction = (clamped - range.lowerBound) / (range.upperBound - range.lowerBound)
        return CGFloat(fraction) * length
    }

    private func value(for position: CGFloat, length: CGFloat) -> Double {
        guard length > 0, range.upperBound > range.lowerBound else { return 0 }
        let fraction = min(1, max(0, Double(position / length)))
        let raw = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
        return raw.rounded()
    }
}
