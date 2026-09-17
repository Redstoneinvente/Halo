from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)

# --- Data model -------------------------------------------------------------
models_path = Path("Halo/Core/WorkspaceModels.swift")
models = models_path.read_text()

model_anchor = 'enum BackgroundKind: String, Codable, CaseIterable { case gradient, solid, glass, image, video }\n'
model_block = r'''enum BackgroundKind: String, Codable, CaseIterable { case gradient, solid, glass, image, video }

enum NotchSkinPreset: String, Codable, CaseIterable, Identifiable {
    case haloGlow = "Halo Glow"
    case carbonWeave = "Carbon Weave"
    case neonCircuit = "Neon Circuit"
    case retroScanlines = "Retro Scanlines"
    case pixelMatrix = "Pixel Matrix"
    case constellation = "Constellation"
    case custom = "Custom Image"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .haloGlow: return "sparkles"
        case .carbonWeave: return "square.grid.3x3.fill"
        case .neonCircuit: return "point.3.connected.trianglepath.dotted"
        case .retroScanlines: return "line.3.horizontal"
        case .pixelMatrix: return "circle.grid.3x3.fill"
        case .constellation: return "sparkle"
        case .custom: return "photo.on.rectangle.angled"
        }
    }
}

enum NotchSkinVisibility: String, Codable, CaseIterable, Identifiable {
    case always = "Opened + Closed"
    case opened = "Opened only"
    case closed = "Closed only"
    var id: String { rawValue }
}

enum NotchSkinBlend: String, Codable, CaseIterable, Identifiable {
    case normal = "Normal"
    case overlay = "Overlay"
    case softLight = "Soft Light"
    case screen = "Screen"
    case multiply = "Multiply"
    var id: String { rawValue }
}

enum NotchSkinImageMode: String, Codable, CaseIterable, Identifiable {
    case fill = "Fill"
    case fit = "Fit"
    case stretch = "Stretch"
    var id: String { rawValue }
}

struct NotchSkinOptions: Codable, Equatable {
    var enabled = false
    var preset: NotchSkinPreset = .haloGlow
    var visibility: NotchSkinVisibility = .always
    var opacity = 0.30
    var blend: NotchSkinBlend = .screen
    var usesThemeTint = true
    var tint = WidgetColor(red: 0.34, green: 0.72, blue: 1.0)
    var scale = 1.0
    var assetPath = ""
    var imageMode: NotchSkinImageMode = .fill

    func normalized() -> NotchSkinOptions {
        var value = self
        value.opacity = min(1, max(0, opacity.isFinite ? opacity : 0.30))
        value.scale = min(3, max(0.4, scale.isFinite ? scale : 1.0))
        value.tint = (try? tint.validated()) ?? WidgetColor(red: 0.34, green: 0.72, blue: 1.0)
        return value
    }
}
'''
models = replace_once(models, model_anchor, model_block, "insert skin model")
models = replace_once(
    models,
    '    var background: BackgroundKind = .gradient\n    var solidColor: WidgetColor?\n',
    '    var background: BackgroundKind = .gradient\n    var skin = NotchSkinOptions()\n    var solidColor: WidgetColor?\n',
    "Appearance skin property"
)
models = replace_once(
    models,
    '        case grain, backgroundSchedule, surface, background, solidColor, gradientStartColor, gradientEndColor, assetPath, blur, saturation, brightness, expandedHeight, compactWidth, spacing, animation, pauseVideoOnBattery\n',
    '        case grain, backgroundSchedule, surface, background, skin, solidColor, gradientStartColor, gradientEndColor, assetPath, blur, saturation, brightness, expandedHeight, compactWidth, spacing, animation, pauseVideoOnBattery\n',
    "Appearance coding key"
)
models = replace_once(
    models,
    '        background = try c.decodeIfPresent(BackgroundKind.self, forKey: .background) ?? .gradient\n        solidColor = try c.decodeIfPresent(WidgetColor.self, forKey: .solidColor)\n',
    '        background = try c.decodeIfPresent(BackgroundKind.self, forKey: .background) ?? .gradient\n        skin = (try c.decodeIfPresent(NotchSkinOptions.self, forKey: .skin) ?? NotchSkinOptions()).normalized()\n        solidColor = try c.decodeIfPresent(WidgetColor.self, forKey: .solidColor)\n',
    "Appearance skin decode"
)
models_path.write_text(models)

# --- Runtime rendering ------------------------------------------------------
surface_path = Path("Halo/Views/SurfaceView.swift")
surface = surface_path.read_text()
surface = replace_once(
    surface,
    '        .background { surfaceBackgroundLayer }\n        .clipShape(contour)\n',
    '''        .background {
            ZStack {
                surfaceBackgroundLayer
                NotchSkinLayer(options: layout.appearance.skin, theme: theme, expanded: state.expanded)
            }
        }
        .clipShape(contour)
''',
    "surface background layer"
)

skin_view = r'''
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

    var body: some View {
        Group {
            if shouldRender {
                GeometryReader { proxy in
                    skin(in: proxy.size)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .opacity(normalized.opacity)
                .blendMode(normalized.blend.swiftUIBlendMode)
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
                RadialGradient(
                    colors: [tint.opacity(0.72), tint.opacity(0.22), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: max(70, min(size.width, size.height * 5) * 0.68)
                )
                LinearGradient(
                    colors: [.clear, tint.opacity(0.34), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: max(1, 1.4 * normalized.scale))
                .frame(maxHeight: .infinity, alignment: .bottom)
            }

        case .carbonWeave:
            Canvas { context, canvas in
                let spacing = max(6, 10 * normalized.scale)
                let lineWidth = max(0.45, 0.7 * normalized.scale)
                var x = -canvas.height
                while x < canvas.width + canvas.height {
                    var forward = Path()
                    forward.move(to: CGPoint(x: x, y: 0))
                    forward.addLine(to: CGPoint(x: x + canvas.height, y: canvas.height))
                    context.stroke(forward, with: .color(tint.opacity(0.42)), lineWidth: lineWidth)
                    var backward = Path()
                    backward.move(to: CGPoint(x: x + spacing * 0.5, y: canvas.height))
                    backward.addLine(to: CGPoint(x: x + canvas.height + spacing * 0.5, y: 0))
                    context.stroke(backward, with: .color(Color.white.opacity(0.20)), lineWidth: lineWidth * 0.72)
                    x += spacing
                }
            }

        case .neonCircuit:
            Canvas { context, canvas in
                let cell = max(18, 30 * normalized.scale)
                let cols = Int(canvas.width / cell) + 2
                let rows = Int(canvas.height / cell) + 2
                for row in 0..<rows {
                    for column in 0..<cols where (row + column).isMultiple(of: 2) {
                        let x = CGFloat(column) * cell
                        let y = CGFloat(row) * cell
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: y + cell * 0.25))
                        path.addLine(to: CGPoint(x: x + cell * 0.42, y: y + cell * 0.25))
                        path.addLine(to: CGPoint(x: x + cell * 0.42, y: y + cell * 0.72))
                        path.addLine(to: CGPoint(x: x + cell * 0.88, y: y + cell * 0.72))
                        context.stroke(path, with: .color(tint.opacity(0.65)), style: StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round))
                        let node = CGRect(x: x + cell * 0.39, y: y + cell * 0.69, width: 3, height: 3)
                        context.fill(Path(ellipseIn: node), with: .color(Color.white.opacity(0.78)))
                    }
                }
            }

        case .retroScanlines:
            Canvas { context, canvas in
                let spacing = max(3, 5 * normalized.scale)
                var y: CGFloat = 0
                while y <= canvas.height {
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: canvas.width, y: y))
                    context.stroke(line, with: .color(tint.opacity(0.55)), lineWidth: max(0.45, spacing * 0.18))
                    y += spacing
                }
                let vertical = max(32, 58 * normalized.scale)
                var x: CGFloat = vertical * 0.5
                while x < canvas.width {
                    var line = Path()
                    line.move(to: CGPoint(x: x, y: 0))
                    line.addLine(to: CGPoint(x: x, y: canvas.height))
                    context.stroke(line, with: .color(Color.white.opacity(0.08)), lineWidth: 0.5)
                    x += vertical
                }
            }

        case .pixelMatrix:
            Canvas { context, canvas in
                let step = max(7, 11 * normalized.scale)
                let columns = Int(canvas.width / step) + 1
                let rows = Int(canvas.height / step) + 1
                let dot = max(1.1, step * 0.18)
                for row in 0..<rows {
                    for column in 0..<columns {
                        let seed = (column * 37 + row * 61 + column * row * 7) % 13
                        guard seed == 0 || seed == 3 || seed == 8 else { continue }
                        let alpha: Double = seed == 0 ? 0.72 : (seed == 3 ? 0.42 : 0.24)
                        let rect = CGRect(x: CGFloat(column) * step, y: CGFloat(row) * step, width: dot, height: dot)
                        context.fill(Path(rect), with: .color(tint.opacity(alpha)))
                    }
                }
            }

        case .constellation:
            Canvas { context, canvas in
                let count = max(12, min(54, Int((canvas.width * canvas.height) / max(2800, 5200 * normalized.scale))))
                var points: [CGPoint] = []
                for index in 0..<count {
                    let xSeed = (index * 47 + index * index * 11 + 19) % 997
                    let ySeed = (index * 83 + index * index * 5 + 41) % 991
                    let point = CGPoint(
                        x: CGFloat(xSeed) / 996 * canvas.width,
                        y: CGFloat(ySeed) / 990 * canvas.height
                    )
                    points.append(point)
                    let radius: CGFloat = index.isMultiple(of: 5) ? 1.7 : 1.0
                    context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                                 with: .color((index.isMultiple(of: 5) ? Color.white : tint).opacity(index.isMultiple(of: 5) ? 0.86 : 0.62)))
                }
                for index in 1..<points.count where index.isMultiple(of: 3) {
                    let a = points[index - 1]
                    let b = points[index]
                    let distance = hypot(a.x - b.x, a.y - b.y)
                    guard distance < max(90, canvas.width * 0.23) else { continue }
                    var line = Path(); line.move(to: a); line.addLine(to: b)
                    context.stroke(line, with: .color(tint.opacity(0.18)), lineWidth: 0.65)
                }
            }

        case .custom:
            if let image = NSImage(contentsOfFile: normalized.assetPath) {
                customImage(image, size: size)
            }
        }
    }

    @ViewBuilder
    private func customImage(_ image: NSImage, size: CGSize) -> some View {
        switch normalized.imageMode {
        case .fill:
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .scaleEffect(normalized.scale)
                .frame(width: size.width, height: size.height)
                .clipped()
        case .fit:
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(normalized.scale)
                .frame(width: size.width, height: size.height)
        case .stretch:
            Image(nsImage: image)
                .resizable()
                .frame(width: size.width, height: size.height)
        }
    }
}

'''
surface = replace_once(surface, 'private struct OpenNotchBackgroundView: View {\n', skin_view + 'private struct OpenNotchBackgroundView: View {\n', "insert skin renderer")
surface_path.write_text(surface)

# --- Settings navigation + dedicated page ----------------------------------
settings_path = Path("Halo/Views/WorkspaceSettingsView.swift")
settings = settings_path.read_text()
settings = replace_once(
    settings,
    '                items: ["Appearance", "Activation Sequence", "Closed notch", "Notch Ambient", "Context Notch Interface", "HUD"]\n',
    '                items: ["Appearance", "Notch Skins", "Activation Sequence", "Closed notch", "Notch Ambient", "Context Notch Interface", "HUD"]\n',
    "sidebar notch skins"
)
settings = replace_once(
    settings,
    '        case "Appearance": return "paintpalette"\n        case "Activation Sequence": return "power.circle"\n',
    '        case "Appearance": return "paintpalette"\n        case "Notch Skins": return "square.3.layers.3d"\n        case "Activation Sequence": return "power.circle"\n',
    "skin icon"
)
settings = replace_once(
    settings,
    '        case "Appearance": AppearanceSettingsPane(store: store, workspace: workspace)\n        case "Activation Sequence": ActivationSequenceSettingsPane()\n',
    '        case "Appearance": AppearanceSettingsPane(store: store, workspace: workspace)\n        case "Notch Skins": NotchSkinSettingsPane(appearance: $workspace.settings.layout.appearance, theme: store.configuration.theme)\n        case "Activation Sequence": ActivationSequenceSettingsPane()\n',
    "skin settings route"
)

settings_pane = r'''
@MainActor private struct NotchSkinSettingsPane: View {
    @Binding var appearance: Appearance
    let theme: Theme

    private let columns = [GridItem(.adaptive(minimum: 132), spacing: 10)]

    var body: some View {
        Section("Notch skins") {
            Toggle("Enable notch skin", isOn: $appearance.skin.enabled)
            Text("Skins are rendered above Halo's background but below widgets, controls and Context Interface content. They decorate the surface without covering useful UI.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("Skin library") {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(NotchSkinPreset.allCases) { preset in
                    skinCard(preset)
                }
            }
        }

        Section("Preview") {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.025, green: 0.03, blue: 0.055), Color(red: 0.07, green: 0.025, blue: 0.11)],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )
                NotchSkinLayer(options: previewOptions, theme: theme, expanded: true)
                HStack(spacing: 18) {
                    Label("Halo", systemImage: "sparkles")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "waveform")
                    Image(systemName: "timer")
                    Image(systemName: "battery.100percent")
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
            }
            .frame(height: 116)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.12)))
        }

        Section("Behavior") {
            Picker("Show skin", selection: $appearance.skin.visibility) {
                ForEach(NotchSkinVisibility.allCases) { Text($0.rawValue).tag($0) }
            }
            Picker("Blend mode", selection: $appearance.skin.blend) {
                ForEach(NotchSkinBlend.allCases) { Text($0.rawValue).tag($0) }
            }
            PreciseSlider(title: "Intensity", value: $appearance.skin.opacity, range: 0...1, step: 0.05, decimals: 2)
            PreciseSlider(title: "Pattern scale", value: $appearance.skin.scale, range: 0.4...3, step: 0.05, decimals: 2)
        }

        if appearance.skin.preset != .custom {
            Section("Procedural color") {
                Toggle("Use Halo accent", isOn: $appearance.skin.usesThemeTint)
                if !appearance.skin.usesThemeTint {
                    ColorPicker("Skin tint", selection: tintBinding, supportsOpacity: false)
                }
                Text("Procedural skins stay resolution-independent and automatically adapt to the current notch size.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        if appearance.skin.preset == .custom {
            Section("Custom skin") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appearance.skin.assetPath.isEmpty ? "No image selected" : URL(fileURLWithPath: appearance.skin.assetPath).lastPathComponent)
                            .lineLimit(1)
                        Text("Transparent PNGs work especially well because the selected Halo background remains visible underneath.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Choose Image…") { chooseCustomSkin() }
                }
                Picker("Image layout", selection: $appearance.skin.imageMode) {
                    ForEach(NotchSkinImageMode.allCases) { Text($0.rawValue).tag($0) }
                }
                if !appearance.skin.assetPath.isEmpty {
                    Button("Remove custom image", role: .destructive) { appearance.skin.assetPath = "" }
                }
            }
        }

        Section {
            Button("Reset skin settings") { appearance.skin = NotchSkinOptions() }
        }
    }

    private var previewOptions: NotchSkinOptions {
        var value = appearance.skin
        value.enabled = true
        return value
    }

    @ViewBuilder
    private func skinCard(_ preset: NotchSkinPreset) -> some View {
        let selected = appearance.skin.preset == preset
        Button {
            applyPreset(preset)
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: preset.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    Spacer()
                    if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor) }
                }
                Text(preset.rawValue).font(.callout.weight(.semibold)).foregroundStyle(.primary)
                Text(presetDescription(preset))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
            .background(selected ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(selected ? Color.accentColor.opacity(0.72) : Color.white.opacity(0.08), lineWidth: selected ? 1.4 : 1))
        }
        .buttonStyle(.plain)
    }

    private func applyPreset(_ preset: NotchSkinPreset) {
        appearance.skin.enabled = true
        appearance.skin.preset = preset
        switch preset {
        case .haloGlow:
            appearance.skin.opacity = 0.34; appearance.skin.blend = .screen; appearance.skin.scale = 1.0
        case .carbonWeave:
            appearance.skin.opacity = 0.25; appearance.skin.blend = .softLight; appearance.skin.scale = 1.0
        case .neonCircuit:
            appearance.skin.opacity = 0.28; appearance.skin.blend = .screen; appearance.skin.scale = 1.0
        case .retroScanlines:
            appearance.skin.opacity = 0.20; appearance.skin.blend = .overlay; appearance.skin.scale = 1.0
        case .pixelMatrix:
            appearance.skin.opacity = 0.24; appearance.skin.blend = .screen; appearance.skin.scale = 1.0
        case .constellation:
            appearance.skin.opacity = 0.30; appearance.skin.blend = .screen; appearance.skin.scale = 1.0
        case .custom:
            appearance.skin.opacity = 0.55; appearance.skin.blend = .overlay; appearance.skin.scale = 1.0
            if appearance.skin.assetPath.isEmpty { chooseCustomSkin() }
        }
    }

    private func presetDescription(_ preset: NotchSkinPreset) -> String {
        switch preset {
        case .haloGlow: return "Soft accent bloom and edge light"
        case .carbonWeave: return "Subtle technical diagonal weave"
        case .neonCircuit: return "Futuristic traces and light nodes"
        case .retroScanlines: return "CRT-inspired horizontal texture"
        case .pixelMatrix: return "Sparse 8-bit LED-style pixels"
        case .constellation: return "Quiet stars with faint connections"
        case .custom: return "Import your own transparent artwork"
        }
    }

    private var tintBinding: Binding<Color> {
        Binding(
            get: { appearance.skin.tint.color },
            set: { color in appearance.skin.tint = widgetColor(from: color) }
        )
    }

    private func widgetColor(from color: Color) -> WidgetColor {
        let ns = NSColor(color)
        let rgb = ns.usingColorSpace(.deviceRGB) ?? ns
        return WidgetColor(red: Double(rgb.redComponent), green: Double(rgb.greenComponent), blue: Double(rgb.blueComponent))
    }

    private func chooseCustomSkin() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.message = "Choose an image to layer above Halo's background and below its content."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        appearance.skin.assetPath = url.path
        appearance.skin.preset = .custom
        appearance.skin.enabled = true
    }
}

'''
settings = replace_once(settings, '@MainActor private struct AppearanceSettingsPane: View {\n', settings_pane + '@MainActor private struct AppearanceSettingsPane: View {\n', "insert skin settings pane")
settings_path.write_text(settings)

print("Notch Skins patch applied")
