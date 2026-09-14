from pathlib import Path

surface_path = Path('Halo/Views/SurfaceView.swift')
settings_path = Path('Halo/Views/WorkspaceSettingsView.swift')

surface = surface_path.read_text()
settings = settings_path.read_text()

# --- Transfer background customization in SurfaceView ---
needle = '''    @AppStorage("HaloContextTransferShowGraph") private var showGraph = true

    private var elapsed: String {'''
replacement = '''    @AppStorage("HaloContextTransferShowGraph") private var showGraph = true
    @AppStorage("HaloContextTransferBackgroundStyle") private var backgroundStyle = "Gradient"
    @AppStorage("HaloContextTransferBackgroundPrimaryHue") private var backgroundPrimaryHue = 0.58
    @AppStorage("HaloContextTransferBackgroundSecondaryHue") private var backgroundSecondaryHue = 0.72
    @AppStorage("HaloContextTransferBackgroundSaturation") private var backgroundSaturation = 0.72
    @AppStorage("HaloContextTransferBackgroundBrightness") private var backgroundBrightness = 0.30
    @AppStorage("HaloContextTransferBackgroundOpacity") private var backgroundOpacity = 1.0

    private var elapsed: String {'''
if needle not in surface:
    raise SystemExit('Transfer appearance storage anchor missing')
surface = surface.replace(needle, replacement, 1)

needle = '''        .padding(compact ? 14 : 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { surfaceState.contextPreferredSize = CGSize(width: compact ? 430 : 620, height: compact ? 120 : 230) }'''
replacement = '''        .padding(compact ? 14 : 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background { transferBackground }
        .onAppear { surfaceState.contextPreferredSize = CGSize(width: compact ? 430 : 620, height: compact ? 120 : 230) }'''
if needle not in surface:
    raise SystemExit('Transfer background insertion anchor missing')
surface = surface.replace(needle, replacement, 1)

needle = '''    private func stat(_ title: String, value: String, symbol: String) -> some View {'''
replacement = '''    @ViewBuilder private var transferBackground: some View {
        let primary = Color(hue: backgroundPrimaryHue, saturation: backgroundSaturation, brightness: backgroundBrightness)
        let secondary = Color(hue: backgroundSecondaryHue, saturation: backgroundSaturation, brightness: min(1, backgroundBrightness + 0.12))
        switch backgroundStyle {
        case "Black":
            Color.black.opacity(backgroundOpacity)
        case "Accent":
            Color.accentColor.opacity(backgroundOpacity)
        case "Dynamic":
            LinearGradient(
                colors: monitor.direction.contains("Uploading") && !monitor.direction.contains("Downloading")
                    ? [Color.orange.opacity(backgroundOpacity), primary.opacity(backgroundOpacity)]
                    : [Color.accentColor.opacity(backgroundOpacity), secondary.opacity(backgroundOpacity)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "Glass":
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                primary.opacity(max(0, min(1, backgroundOpacity * 0.36)))
            }
        default:
            LinearGradient(
                colors: [primary.opacity(backgroundOpacity), secondary.opacity(backgroundOpacity)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func stat(_ title: String, value: String, symbol: String) -> some View {'''
if needle not in surface:
    raise SystemExit('Transfer background helper anchor missing')
surface = surface.replace(needle, replacement, 1)

# --- Transfer-only exclusive notch ownership ---
needle = '''    private var contextOwnsFullSurface: Bool {
        guard state.expanded else { return false }
        switch activeContext {
        case .drop: return dropUsesFullNotchArea
        case .music: return contextMusicUsesFullNotchArea
        case .bluetooth: return bluetoothUsesFullNotchArea
        case .retro: return retroUsesFullNotchArea
        case .teleprompter: return true
        case .transfer: return transferUsesFullNotchArea
        case .none: return false
        }
    }'''
replacement = '''    private var contextOwnsFullSurface: Bool {
        // Transfer CI takes ownership immediately so Halo never flashes the normal notch
        // while the transfer surface is expanding. Other CIs keep their existing behavior.
        if activeContext == .transfer { return true }
        guard state.expanded else { return false }
        switch activeContext {
        case .drop: return dropUsesFullNotchArea
        case .music: return contextMusicUsesFullNotchArea
        case .bluetooth: return bluetoothUsesFullNotchArea
        case .retro: return retroUsesFullNotchArea
        case .teleprompter: return true
        case .transfer: return true
        case .none: return false
        }
    }'''
if needle not in surface:
    raise SystemExit('contextOwnsFullSurface anchor missing')
surface = surface.replace(needle, replacement, 1)

surface = surface.replace('''        case .transfer: return transferKeepsClosedContents''', '''        case .transfer: return false''', 1)
surface = surface.replace('''                        guard !teleprompterActive else { return }''', '''                        guard !teleprompterActive && !transferContextActive else { return }''', 1)

needle = '''        .onHover { hovering in
            if teleprompterContextActive {
                state.collapseTask?.cancel()
                if !state.pinned { state.expanded = false }
            } else {
                state.hover(hovering, enabled: store.configuration.hoverToExpand)
            }
        }'''
replacement = '''        .onHover { hovering in
            if teleprompterContextActive {
                state.collapseTask?.cancel()
                if !state.pinned { state.expanded = false }
            } else if transferContextActive {
                // Transfer CI owns the surface. Ignore normal notch hover expansion/collapse
                // until the transfer releases ownership.
                state.collapseTask?.cancel()
            } else {
                state.hover(hovering, enabled: store.configuration.hoverToExpand)
            }
        }'''
if needle not in surface:
    raise SystemExit('Transfer hover ownership anchor missing')
surface = surface.replace(needle, replacement, 1)

# Prevent normal notch background / artwork from leaking behind Transfer CI.
needle = '''    @ViewBuilder private var surfaceBackgroundLayer: some View {
        ZStack {
            if state.expanded && activeContext == nil && usesVisualWorkspace {
                OpenNotchBackgroundView(options: layout.resolvedOpenNotchLayout.appearance, fallback: layout.appearance, theme: theme, system: workspace.system)
            } else {
                SurfaceBackground(appearance: layout.appearance, theme: theme, expanded: state.expanded, system: workspace.system)
            }
            if !state.expanded || layout.closedNotch?.applyBackgroundWhenOpened == true {
                AlbumNotchBackground(options: closedBackgroundOptions, media: workspace.media, system: workspace.system)
            }
        }
    }'''
replacement = '''    @ViewBuilder private var surfaceBackgroundLayer: some View {
        ZStack {
            if transferContextActive {
                // TransferContextView draws its own fully customizable background.
                Color.clear
            } else if state.expanded && activeContext == nil && usesVisualWorkspace {
                OpenNotchBackgroundView(options: layout.resolvedOpenNotchLayout.appearance, fallback: layout.appearance, theme: theme, system: workspace.system)
            } else {
                SurfaceBackground(appearance: layout.appearance, theme: theme, expanded: state.expanded, system: workspace.system)
            }
            if !transferContextActive && (!state.expanded || layout.closedNotch?.applyBackgroundWhenOpened == true) {
                AlbumNotchBackground(options: closedBackgroundOptions, media: workspace.media, system: workspace.system)
            }
        }
    }'''
if needle not in surface:
    raise SystemExit('surface background ownership anchor missing')
surface = surface.replace(needle, replacement, 1)

# --- Transfer settings: exclusive ownership + background controls ---
settings = settings.replace('''    @AppStorage("HaloContextTransferUseFullNotchArea") private var useFullNotchArea = true
    @AppStorage("HaloContextTransferKeepClosedNotchContents") private var keepClosedContents = false
''', '', 1)

needle = '''    @AppStorage("HaloContextTransferShowGraph") private var showGraph = true
    var body: some View {'''
replacement = '''    @AppStorage("HaloContextTransferShowGraph") private var showGraph = true
    @AppStorage("HaloContextTransferBackgroundStyle") private var backgroundStyle = "Gradient"
    @AppStorage("HaloContextTransferBackgroundPrimaryHue") private var backgroundPrimaryHue = 0.58
    @AppStorage("HaloContextTransferBackgroundSecondaryHue") private var backgroundSecondaryHue = 0.72
    @AppStorage("HaloContextTransferBackgroundSaturation") private var backgroundSaturation = 0.72
    @AppStorage("HaloContextTransferBackgroundBrightness") private var backgroundBrightness = 0.30
    @AppStorage("HaloContextTransferBackgroundOpacity") private var backgroundOpacity = 1.0
    var body: some View {'''
if needle not in settings:
    raise SystemExit('Transfer settings appearance anchor missing')
settings = settings.replace(needle, replacement, 1)

needle = '''        Section("CI surface") { Toggle("Use full notch area", isOn: $useFullNotchArea); Toggle("Keep closed-notch contents visible", isOn: $keepClosedContents) }
        Section("What Halo can detect")'''
replacement = '''        Section("Surface ownership") {
            Label("Transfer CI replaces the normal Halo notch while it is active.", systemImage: "rectangle.inset.filled")
            Text("When Transfer CI wins priority, the closed notch, opened dashboard and normal notch hover/tap behavior are suspended until the transfer ends. This applies only to Transfer CI.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Background") {
            Picker("Style", selection: $backgroundStyle) {
                Text("Gradient").tag("Gradient")
                Text("Dynamic").tag("Dynamic")
                Text("Accent").tag("Accent")
                Text("Glass").tag("Glass")
                Text("Black").tag("Black")
            }
            if backgroundStyle == "Gradient" || backgroundStyle == "Dynamic" || backgroundStyle == "Glass" {
                LabeledContent("Primary hue") { Slider(value: $backgroundPrimaryHue, in: 0...1) }
            }
            if backgroundStyle == "Gradient" {
                LabeledContent("Secondary hue") { Slider(value: $backgroundSecondaryHue, in: 0...1) }
            }
            if backgroundStyle == "Gradient" || backgroundStyle == "Dynamic" || backgroundStyle == "Glass" {
                LabeledContent("Saturation") { Slider(value: $backgroundSaturation, in: 0...1) }
                LabeledContent("Brightness") { Slider(value: $backgroundBrightness, in: 0.05...1) }
            }
            LabeledContent("Background opacity") {
                Slider(value: $backgroundOpacity, in: 0.15...1)
                Text("\\(Int((backgroundOpacity * 100).rounded()))%").font(.caption.monospacedDigit()).frame(width: 42)
            }
            Text(backgroundStyle == "Dynamic" ? "Dynamic background shifts toward download/accent colors or upload/orange colors based on the active transfer direction." : "This background belongs only to Transfer CI and does not change your normal Halo notch appearance.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("What Halo can detect")'''
if needle not in settings:
    raise SystemExit('Transfer CI surface settings anchor missing')
settings = settings.replace(needle, replacement, 1)

surface_path.write_text(surface)
settings_path.write_text(settings)
print('Transfer CI ownership and background customization patched.')
