from pathlib import Path


def replace_braced(source: str, marker: str, replacement: str) -> str:
    start = source.find(marker)
    if start < 0:
        raise SystemExit(f"Missing marker: {marker}")
    brace = source.find("{", start)
    if brace < 0:
        raise SystemExit(f"Missing opening brace after: {marker}")
    depth = 0
    in_string = False
    escaped = False
    i = brace
    while i < len(source):
        ch = source[i]
        if in_string:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_string = False
        else:
            if ch == '"':
                in_string = True
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    end = i + 1
                    return source[:start] + replacement.rstrip() + source[end:]
        i += 1
    raise SystemExit(f"Unbalanced braces after: {marker}")


models_path = Path("Halo/Core/WorkspaceModels.swift")
models = models_path.read_text()

preset = r'''enum NotchSkinPreset: String, CaseIterable, Identifiable, Codable {
    case haloGlow = "Halo Glow"
    case carbonWeave = "Carbon Weave"
    case neonCircuit = "Neon Circuit"
    case retroScanlines = "Retro Scanlines"
    case pixelMatrix = "Pixel Matrix"
    case constellation = "Constellation"
    case aurora = "Aurora"
    case synthwave = "Synthwave Sunset"
    case sakuraNight = "Sakura Night"
    case oceanCurrent = "Ocean Current"
    case emberCore = "Ember Core"
    case blueprint = "Blueprint"
    case matrixRain = "Matrix Rain"
    case nebula = "Nebula"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .haloGlow: return "sparkles"
        case .carbonWeave: return "square.grid.3x3.fill"
        case .neonCircuit: return "point.3.connected.trianglepath.dotted"
        case .retroScanlines: return "line.3.horizontal"
        case .pixelMatrix: return "circle.grid.3x3.fill"
        case .constellation: return "sparkle"
        case .aurora: return "wave.3.right"
        case .synthwave: return "sun.horizon.fill"
        case .sakuraNight: return "leaf.fill"
        case .oceanCurrent: return "water.waves"
        case .emberCore: return "flame.fill"
        case .blueprint: return "ruler.fill"
        case .matrixRain: return "textformat.abc"
        case .nebula: return "cloud.moon.fill"
        }
    }

    // Custom Image existed in early Notch Skins builds. Decode it as Halo Glow so saved
    // profiles continue loading even though image-backed skins are no longer exposed.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? Self.haloGlow.rawValue
        self = raw == "Custom Image" ? .haloGlow : (Self(rawValue: raw) ?? .haloGlow)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}'''
models = replace_braced(models, "enum NotchSkinPreset: String, Codable, CaseIterable, Identifiable {", preset)

if "enum NotchSkinImageMode:" in models:
    models = replace_braced(models, "enum NotchSkinImageMode: String, Codable, CaseIterable, Identifiable {", "")

options = r'''struct NotchSkinOptions: Codable, Equatable {
    var enabled = false
    var preset: NotchSkinPreset = .haloGlow
    var visibility: NotchSkinVisibility = .always
    var opacity = 0.30
    var blend: NotchSkinBlend = .screen
    var usesThemeTint = true
    var tint = WidgetColor(red: 0.34, green: 0.72, blue: 1.0)
    var scale = 1.0

    func normalized() -> NotchSkinOptions {
        var value = self
        value.opacity = min(1, max(0, opacity.isFinite ? opacity : 0.30))
        value.scale = min(3, max(0.4, scale.isFinite ? scale : 1.0))
        value.tint = (try? tint.validated()) ?? WidgetColor(red: 0.34, green: 0.72, blue: 1.0)
        return value
    }
}'''
models = replace_braced(models, "struct NotchSkinOptions: Codable, Equatable {", options)
models_path.write_text(models)

surface_path = Path("Halo/Views/SurfaceView.swift")
surface = surface_path.read_text()

renderer = r'''struct NotchSkinLayer: View {
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
}'''
surface = replace_braced(surface, "struct NotchSkinLayer: View {", renderer)
surface_path.write_text(surface)

settings_path = Path("Halo/Views/WorkspaceSettingsView.swift")
settings = settings_path.read_text()

pane = r'''@MainActor private struct NotchSkinSettingsPane: View {
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
            Text("Texture skins stay subtle; themed skins bring their own visual identity while remaining below Halo's content.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
                    Label("Halo", systemImage: "sparkles").font(.headline)
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

        Section("Procedural color") {
            Toggle("Use Halo accent", isOn: $appearance.skin.usesThemeTint)
            if !appearance.skin.usesThemeTint {
                ColorPicker("Skin tint", selection: tintBinding, supportsOpacity: false)
            }
            Text("Every skin is generated procedurally, stays sharp at any notch size, and can be recolored. The themed presets also use complementary palette colors where appropriate.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
        Button { applyPreset(preset) } label: {
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

    private func setTint(_ red: Double, _ green: Double, _ blue: Double, useTheme: Bool = false) {
        appearance.skin.usesThemeTint = useTheme
        appearance.skin.tint = WidgetColor(red: red, green: green, blue: blue)
    }

    private func applyPreset(_ preset: NotchSkinPreset) {
        appearance.skin.enabled = true
        appearance.skin.preset = preset
        switch preset {
        case .haloGlow:
            appearance.skin.opacity = 0.34; appearance.skin.blend = .screen; appearance.skin.scale = 1.0; appearance.skin.usesThemeTint = true
        case .carbonWeave:
            appearance.skin.opacity = 0.44; appearance.skin.blend = .normal; appearance.skin.scale = 1.0; appearance.skin.usesThemeTint = true
        case .neonCircuit:
            appearance.skin.opacity = 0.30; appearance.skin.blend = .screen; appearance.skin.scale = 1.0; appearance.skin.usesThemeTint = true
        case .retroScanlines:
            appearance.skin.opacity = 0.40; appearance.skin.blend = .normal; appearance.skin.scale = 1.0; setTint(0.28, 0.95, 0.62)
        case .pixelMatrix:
            appearance.skin.opacity = 0.28; appearance.skin.blend = .screen; appearance.skin.scale = 1.0; appearance.skin.usesThemeTint = true
        case .constellation:
            appearance.skin.opacity = 0.32; appearance.skin.blend = .screen; appearance.skin.scale = 1.0; appearance.skin.usesThemeTint = true
        case .aurora:
            appearance.skin.opacity = 0.52; appearance.skin.blend = .screen; appearance.skin.scale = 1.0; setTint(0.25, 0.95, 0.83)
        case .synthwave:
            appearance.skin.opacity = 0.58; appearance.skin.blend = .screen; appearance.skin.scale = 1.0; setTint(1.0, 0.18, 0.78)
        case .sakuraNight:
            appearance.skin.opacity = 0.52; appearance.skin.blend = .screen; appearance.skin.scale = 1.0; setTint(1.0, 0.46, 0.72)
        case .oceanCurrent:
            appearance.skin.opacity = 0.48; appearance.skin.blend = .screen; appearance.skin.scale = 1.0; setTint(0.16, 0.75, 1.0)
        case .emberCore:
            appearance.skin.opacity = 0.58; appearance.skin.blend = .screen; appearance.skin.scale = 1.0; setTint(1.0, 0.34, 0.08)
        case .blueprint:
            appearance.skin.opacity = 0.44; appearance.skin.blend = .screen; appearance.skin.scale = 1.0; setTint(0.12, 0.68, 1.0)
        case .matrixRain:
            appearance.skin.opacity = 0.52; appearance.skin.blend = .screen; appearance.skin.scale = 1.0; setTint(0.18, 1.0, 0.32)
        case .nebula:
            appearance.skin.opacity = 0.54; appearance.skin.blend = .screen; appearance.skin.scale = 1.0; setTint(0.58, 0.32, 1.0)
        }
    }

    private func presetDescription(_ preset: NotchSkinPreset) -> String {
        switch preset {
        case .haloGlow: return "Soft accent bloom and edge light"
        case .carbonWeave: return "Visible layered carbon-fiber weave"
        case .neonCircuit: return "Futuristic traces and light nodes"
        case .retroScanlines: return "Bold CRT scan bars with phosphor tint"
        case .pixelMatrix: return "Sparse 8-bit LED-style pixels"
        case .constellation: return "Quiet stars with faint connections"
        case .aurora: return "Flowing northern-light ribbons"
        case .synthwave: return "Neon sunset and perspective grid"
        case .sakuraNight: return "Night branch with drifting blossom petals"
        case .oceanCurrent: return "Layered cyan wave currents"
        case .emberCore: return "Warm core glow with rising sparks"
        case .blueprint: return "Technical drafting grid and guides"
        case .matrixRain: return "Falling green digital-code columns"
        case .nebula: return "Purple-blue cosmic clouds and stars"
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
}'''
settings = replace_braced(settings, "@MainActor private struct NotchSkinSettingsPane: View {", pane)
settings_path.write_text(settings)

# Contract checks before the compiler sees the patch.
assert 'case custom = "Custom Image"' not in models
assert 'enum NotchSkinImageMode:' not in models
assert 'var assetPath = ""' not in options
assert 'var imageMode:' not in options
assert 'raw == "Custom Image"' in models
for case in ["aurora", "synthwave", "sakuraNight", "oceanCurrent", "emberCore", "blueprint", "matrixRain", "nebula"]:
    assert f"case {case}" in models
    assert f"case .{case}:" in surface
    assert f"case .{case}:" in settings
assert 'Choose Image' not in settings[settings.find('@MainActor private struct NotchSkinSettingsPane'):settings.find('@MainActor private struct AppearanceSettingsPane')]
assert 'NSOpenPanel()' not in settings[settings.find('@MainActor private struct NotchSkinSettingsPane'):settings.find('@MainActor private struct AppearanceSettingsPane')]
assert 'surfaceBackgroundLayer\n                NotchSkinLayer(options:' in surface
assert 'case .carbonWeave:' in surface and 'forward.closeSubpath()' in surface
assert 'case .retroScanlines:' in surface and 'let thickness = max(CGFloat(1.5)' in surface
print("Notch Skins themed patch applied and contract verified")
