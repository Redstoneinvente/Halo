from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"marker not found: {label}")
    return text.replace(old, new, 1)


def replace_between(text: str, start_marker: str, end_marker: str, new: str, label: str) -> str:
    start = text.find(start_marker)
    if start < 0:
        raise SystemExit(f"start marker not found: {label}")
    end = text.find(end_marker, start)
    if end < 0:
        raise SystemExit(f"end marker not found: {label}")
    return text[:start] + new + text[end:]


# -----------------------------------------------------------------------------
# WorkspaceModels.swift — allow a display to reference a real saved profile.
# -----------------------------------------------------------------------------
path = Path("Halo/Core/WorkspaceModels.swift")
text = path.read_text()
text = replace_once(
    text,
    '''struct DisplayOverride: Codable, Identifiable, Equatable {\n    var id: String\n    var enabled = true\n    var theme = Theme()\n    var layout: WorkspaceLayout?\n}\n''',
    '''struct DisplayOverride: Codable, Identifiable, Equatable {\n    var id: String\n    var enabled = true\n    var theme = Theme()\n    var layout: WorkspaceLayout?\n    // When set, this display follows the saved profile live instead of keeping a copied layout.\n    var profileID: UUID?\n}\n''',
    "DisplayOverride profileID"
)
path.write_text(text)


# -----------------------------------------------------------------------------
# WindowManager.swift — resolve per-display profile references live.
# -----------------------------------------------------------------------------
path = Path("Halo/NotchEngine/WindowManager.swift")
text = path.read_text()
text = replace_once(
    text,
    '''        store.workspace.$settings.map { [store] settings in\n            let layout = settings.profiles.first { $0.id == store.workspace.scheduledProfileID }?.layout ?? settings.layout\n            return SurfaceRenderConfiguration(appearance: layout.appearance, displays: settings.displays, closedNotch: layout.closedNotch, clock: layout.widgetStyle(for: .clock), horizontalWidgets: layout.horizontalWidgets, horizontalHeight: layout.horizontalHeight)\n        }\n''',
    '''        store.workspace.$settings.map { [store] settings in\n            let layout = settings.profiles.first { $0.id == store.workspace.scheduledProfileID }?.layout ?? settings.layout\n            let resolvedDisplays = settings.displays.map { item -> DisplayOverride in\n                guard let profileID = item.profileID, let profile = settings.profiles.first(where: { $0.id == profileID }) else { return item }\n                var resolved = item\n                resolved.theme = profile.theme\n                resolved.layout = profile.layout\n                return resolved\n            }\n            return SurfaceRenderConfiguration(appearance: layout.appearance, displays: resolvedDisplays, closedNotch: layout.closedNotch, clock: layout.widgetStyle(for: .clock), horizontalWidgets: layout.horizontalWidgets, horizontalHeight: layout.horizontalHeight)\n        }\n''',
    "WindowManager render configuration"
)
text = replace_once(
    text,
    '''            let override = store.workspace.settings.displays.first { $0.id == id }\n            guard override?.enabled != false else { continue }\n            active.insert(id)\n            let existing = hosts[id]\n            let host = existing ?? Host()\n            var theme = override?.theme ?? store.workspace.scheduledTheme ?? store.configuration.theme\n            if store.configuration.simulateNotch && theme.style == .notch { theme.style = .simulated }\n            var appearance = override?.layout?.appearance ?? store.workspace.effectiveLayout.appearance\n            let effectiveLayout = override?.layout ?? store.workspace.effectiveLayout\n''',
    '''            let override = store.workspace.settings.displays.first { $0.id == id }\n            guard override?.enabled != false else { continue }\n            let displayProfile = override?.profileID.flatMap { profileID in\n                store.workspace.settings.profiles.first { $0.id == profileID }\n            }\n            active.insert(id)\n            let existing = hosts[id]\n            let host = existing ?? Host()\n            var theme = displayProfile?.theme ?? override?.theme ?? store.workspace.scheduledTheme ?? store.configuration.theme\n            if store.configuration.simulateNotch && theme.style == .notch { theme.style = .simulated }\n            let displayLayout = displayProfile?.layout ?? override?.layout\n            var appearance = displayLayout?.appearance ?? store.workspace.effectiveLayout.appearance\n            let effectiveLayout = displayLayout ?? store.workspace.effectiveLayout\n''',
    "WindowManager display profile resolution"
)
text = replace_once(
    text,
    '''            if host.state.layoutOverride != override?.layout { host.state.layoutOverride = override?.layout }\n''',
    '''            if host.state.layoutOverride != displayLayout { host.state.layoutOverride = displayLayout }\n''',
    "WindowManager host layout override"
)
path.write_text(text)


# -----------------------------------------------------------------------------
# WorkspaceStore.swift — media/HUD dependency checks include linked profiles.
# -----------------------------------------------------------------------------
path = Path("Halo/Core/WorkspaceStore.swift")
text = path.read_text()
text = replace_once(
    text,
    '''        let activeProfileArtworkInputsChanged: Bool = {\n            guard let id = scheduledProfileID else { return false }\n            let oldLayout = oldValue.profiles.first(where: { $0.id == id })?.layout\n            let newLayout = settings.profiles.first(where: { $0.id == id })?.layout\n            return oldLayout?.contextMusic != newLayout?.contextMusic ||\n                oldLayout?.hud != newLayout?.hud ||\n                oldLayout?.closedNotch != newLayout?.closedNotch ||\n                oldLayout?.enabled != newLayout?.enabled\n        }()\n        if baseArtworkInputsChanged || activeProfileArtworkInputsChanged { updateArtworkPreference() }\n\n        let activeProfileHUDChanged: Bool = {\n''',
    '''        let activeProfileArtworkInputsChanged: Bool = {\n            guard let id = scheduledProfileID else { return false }\n            let oldLayout = oldValue.profiles.first(where: { $0.id == id })?.layout\n            let newLayout = settings.profiles.first(where: { $0.id == id })?.layout\n            return oldLayout?.contextMusic != newLayout?.contextMusic ||\n                oldLayout?.hud != newLayout?.hud ||\n                oldLayout?.closedNotch != newLayout?.closedNotch ||\n                oldLayout?.enabled != newLayout?.enabled\n        }()\n        let displayProfileInputsChanged: Bool = {\n            let ids = Set(settings.displays.compactMap(\\.profileID))\n            return ids.contains { id in\n                oldValue.profiles.first(where: { $0.id == id })?.layout != settings.profiles.first(where: { $0.id == id })?.layout\n            }\n        }()\n        if baseArtworkInputsChanged || activeProfileArtworkInputsChanged || displayProfileInputsChanged { updateArtworkPreference() }\n\n        let activeProfileHUDChanged: Bool = {\n''',
    "WorkspaceStore display profile artwork dependency"
)
text = replace_once(
    text,
    '''        if oldValue.layout.hud != settings.layout.hud || oldValue.displays != settings.displays || activeProfileHUDChanged {\n            hudEngine?.configurationDidChange()\n        }\n''',
    '''        if oldValue.layout.hud != settings.layout.hud || oldValue.displays != settings.displays || activeProfileHUDChanged || displayProfileInputsChanged {\n            hudEngine?.configurationDidChange()\n        }\n''',
    "WorkspaceStore display profile HUD dependency"
)
text = replace_once(
    text,
    '''    private func updateArtworkPreference() {\n        let layouts = [effectiveLayout] + settings.displays.compactMap { $0.enabled ? $0.layout : nil }\n''',
    '''    private func updateArtworkPreference() {\n        let displayLayouts = settings.displays.compactMap { item -> WorkspaceLayout? in\n            guard item.enabled else { return nil }\n            if let profileID = item.profileID, let profile = settings.profiles.first(where: { $0.id == profileID }) { return profile.layout }\n            return item.layout\n        }\n        let layouts = [effectiveLayout] + displayLayouts\n''',
    "WorkspaceStore resolved display layouts"
)
path.write_text(text)


# -----------------------------------------------------------------------------
# SurfaceAppearanceView.swift — mount only the requested group of controls.
# -----------------------------------------------------------------------------
path = Path("Halo/Views/SurfaceAppearanceView.swift")
text = path.read_text()
text = replace_once(
    text,
    '''@MainActor struct SurfaceAppearanceControls: View {\n    @Binding var appearance: Appearance\n    let theme: Theme\n    var screen: NSScreen?\n''',
    '''enum SurfaceAppearanceScope {\n    case all, background, geometry, motion\n}\n\n@MainActor struct SurfaceAppearanceControls: View {\n    @Binding var appearance: Appearance\n    let theme: Theme\n    var screen: NSScreen?\n    var scope: SurfaceAppearanceScope = .all\n''',
    "SurfaceAppearance scope"
)
new_body = '''    var body: some View {\n        if scope == .all || scope == .background {\n            backgroundStyleControls\n            backgroundColorControls\n        }\n\n        if scope == .all || scope == .geometry {\n            Section("Closed size") {\n                PreciseSlider(title: "Width", value: $appearance.compactWidth, range: 16...640, step: 1, suffix: "pt", onEditingChanged: {\n                    GeometryPreview.update(expanded: false, editing: $0, display: screen)\n                })\n                PreciseSlider(title: "Height", value: $appearance.surface.compactHeight, range: 16...100, step: 1, suffix: "pt", onEditingChanged: {\n                    GeometryPreview.update(expanded: false, editing: $0, display: screen)\n                })\n                if let screen {\n                    let geometry = WindowManager.geometry(screen: screen, theme: theme, appearance: appearance)\n                    Text("Effective closed size: \\(Int(geometry.compactWidth)) × \\(Int(geometry.compactHeight)) pt.").font(.caption)\n                    if geometry.attachedToNotch {\n                        Text("16 × 16 pt is allowed. The physical camera cutout stays unchanged; a positive vertical offset moves Halo below it.").font(.caption).foregroundStyle(.secondary)\n                    }\n                }\n            }\n            Section("Position offsets") {\n                Text("Positive X moves right; positive Y moves down. Each state has independent offsets.").font(.caption)\n                offsetControl("Opened X", key: \\.openedX, expanded: true)\n                offsetControl("Opened Y", key: \\.openedY, expanded: true)\n                offsetControl("Closed X", key: \\.closedX, expanded: false)\n                offsetControl("Closed Y", key: \\.closedY, expanded: false)\n                Button("Reset offsets") { appearance.surface.offsets = SurfaceOffsets() }\n            }\n            Section("Context interface position") {\n                Text("These offsets apply only to Context Interfaces. They do not move the normal opened dashboard. Positive X moves right; positive Y moves down.").font(.caption).foregroundStyle(.secondary)\n                PreciseSlider(title: "Context X", value: $contextOffsetX, range: -1000...1000, step: 1, suffix: "pt")\n                PreciseSlider(title: "Context Y", value: $contextOffsetY, range: -1000...1000, step: 1, suffix: "pt")\n                Button("Reset context position") { contextOffsetX = 0; contextOffsetY = 0 }\n            }\n            Section("Shape") {\n                Toggle("Use surface style contour", isOn: Binding(get: { appearance.surface.useStyleContour ?? true }, set: { appearance.surface.useStyleContour = $0 }))\n                Text("Turn off to use a custom contour below.").font(.caption)\n                Picker("Contour", selection: Binding(get: { appearance.surface.shape }, set: { appearance.surface.shape = $0; appearance.surface.useStyleContour = false })) { ForEach(SurfaceShapeKind.allCases) { Text($0.rawValue).tag($0) } }\n                if appearance.surface.shape == .asymmetric {\n                    PreciseSlider(title: "Top corners", value: $appearance.surface.topRadius, range: 0...64, step: 1, suffix: "pt")\n                    PreciseSlider(title: "Bottom corners", value: $appearance.surface.bottomRadius, range: 0...64, step: 1, suffix: "pt")\n                }\n                if [.scoop, .chamfer, .tapered].contains(appearance.surface.shape) {\n                    PreciseSlider(title: "Shoulder / cut depth", value: $appearance.surface.shoulder, range: 0...48, step: 1, suffix: "pt")\n                }\n                HaloContour(kind: appearance.surface.shape, radius: theme.cornerRadius, topRadius: appearance.surface.topRadius,\n                            bottomRadius: appearance.surface.bottomRadius, shoulder: appearance.surface.shoulder)\n                    .fill(Color(hue: theme.tint, saturation: 0.6, brightness: 0.5)).frame(height: 80)\n                    .accessibilityLabel("\\(appearance.surface.shape.rawValue) preview")\n            }\n        }\n\n        if scope == .all || scope == .motion {\n            Section("Transitions") {\n                Picker("Opening", selection: $appearance.surface.opening) { ForEach(SurfaceTransition.allCases) { Text($0.rawValue).tag($0) } }\n                Picker("Closing", selection: $appearance.surface.closing) { ForEach(SurfaceTransition.allCases) { Text($0.rawValue).tag($0) } }\n                PreciseSlider(title: "Duration", value: $appearance.surface.duration, range: 0.1...1.2, step: 0.05, suffix: "s", decimals: 2)\n                if appearance.surface.opening == .spring || appearance.surface.closing == .spring {\n                    PreciseSlider(title: "Spring damping", value: $appearance.surface.damping, range: 0.4...1, step: 0.05, decimals: 2)\n                    Text("Lower damping adds bounce; higher damping settles sooner.").font(.caption)\n                }\n                Text("Reduce Motion and the animation-off setting make transitions immediate.").font(.caption).foregroundStyle(.secondary)\n            }\n        }\n    }\n\n'''
text = replace_between(text, "    var body: some View {\n", "    private var backgroundStyleControls: some View {\n", new_body, "SurfaceAppearance body")
path.write_text(text)


# -----------------------------------------------------------------------------
# WorkspaceSettingsView.swift — split Appearance into lightweight pages and make
# display profile references explicit.
# -----------------------------------------------------------------------------
path = Path("Halo/Views/WorkspaceSettingsView.swift")
text = path.read_text()
appearance_case = '''        case "Appearance": AppearanceSettingsPane(store: store, workspace: workspace)\n'''
text = replace_between(text, '        case "Appearance":\n', '        case "Widgets":', appearance_case, "Appearance case")
displays_case = '''        case "Displays": DisplaySettingsPane(store: store, workspace: workspace)\n'''
text = replace_between(text, '        case "Displays":\n', '        case "Plugins":', displays_case, "Displays case")

insert_marker = "@MainActor private struct ProfileLibraryView: View {"
new_views = r'''private enum HaloAppearancePage: String, CaseIterable, Identifiable {
    case basics = "Basics"
    case surface = "Surface"
    case background = "Background"
    case motion = "Motion"
    var id: String { rawValue }
}

@MainActor private struct AppearanceSettingsPane: View {
    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore
    @AppStorage("HaloOpenKeepClosedNotchContents") private var keepClosedContentsWhenOpen = false
    @State private var page: HaloAppearancePage = .basics

    var body: some View {
        Picker("Appearance area", selection: $page) {
            ForEach(HaloAppearancePage.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)

        switch page {
        case .basics: basics
        case .surface: surface
        case .background: background
        case .motion: motion
        }
    }

    @ViewBuilder private var basics: some View {
        Section("Expanded dashboard") {
            Toggle("Keep closed-notch contents visible when opened", isOn: $keepClosedContentsWhenOpen)
            Text("Keeps the normal Closed Notch widgets and media visible in the top strip when Halo's regular dashboard is open. Context Interfaces use their own setting.").font(.caption).foregroundStyle(.secondary)
            Toggle("Horizontal widget layout", isOn: Binding(get: { workspace.settings.layout.horizontalWidgets ?? false }, set: { workspace.settings.layout.horizontalWidgets = $0 }))
            if workspace.settings.layout.horizontalWidgets ?? false {
                Picker("Navigation", selection: Binding(get: { workspace.settings.layout.horizontalPages ?? false }, set: { workspace.settings.layout.horizontalPages = $0 })) {
                    Text("Scroll").tag(false); Text("Pages").tag(true)
                }.pickerStyle(.segmented)
                Slider(value: Binding(get: { workspace.settings.layout.horizontalHeight ?? 260 }, set: { workspace.settings.layout.horizontalHeight = $0 }), in: 200...500) { Text("Horizontal dashboard height") }
            }
            Text("Arrange widgets in a sideways-scrolling row. Turn off for the original vertical layout. Widget order and customizations apply to both.").font(.caption).foregroundStyle(.secondary)
        }
        Section("Surface basics") {
            Picker("Surface", selection: $store.configuration.theme.style) { ForEach(SurfaceStyle.allCases) { Text($0.rawValue).tag($0) } }
            Slider(value: $store.configuration.theme.width, in: 340...640, onEditingChanged: { GeometryPreview.update(expanded: true, editing: $0) }) { Text("Expanded width") }
            Slider(value: $workspace.settings.layout.appearance.expandedHeight, in: 280...800, onEditingChanged: { GeometryPreview.update(expanded: true, editing: $0) }) { Text("Expanded height") }
            Slider(value: $store.configuration.theme.cornerRadius, in: 0...48) { Text("Corner radius") }
            Slider(value: $workspace.settings.layout.appearance.spacing, in: 4...28) { Text("Module spacing") }
            Slider(value: $store.configuration.theme.tint, in: 0...1) { Text("Accent hue") }
            Slider(value: $store.configuration.theme.opacity, in: 0.5...1) { Text("Opacity") }
        }
    }

    @ViewBuilder private var surface: some View {
        SurfaceAppearanceControls(
            appearance: $workspace.settings.layout.appearance,
            theme: store.configuration.theme,
            screen: NSScreen.main ?? NSScreen.screens.first,
            scope: .geometry
        )
    }

    @ViewBuilder private var background: some View {
        SurfaceAppearanceControls(
            appearance: $workspace.settings.layout.appearance,
            theme: store.configuration.theme,
            screen: NSScreen.main ?? NSScreen.screens.first,
            scope: .background
        )
        Section("Background effects") {
            if workspace.settings.layout.appearance.background == .glass {
                Text("Glass blurs the desktop behind Halo. Opacity adjusts its tint; macOS controls the backdrop blur. Reduce Transparency replaces glass with a solid background.").font(.caption)
            } else {
                Slider(value: $workspace.settings.layout.appearance.blur, in: 0...20) { Text("Blur") }
                Slider(value: $workspace.settings.layout.appearance.saturation, in: 0...2) { Text("Saturation") }
                Slider(value: $workspace.settings.layout.appearance.brightness, in: -0.5...0.5) { Text("Brightness") }
            }
            GrainSettingsView(options: Binding(get: { workspace.settings.layout.appearance.grain ?? GrainOptions() }, set: { workspace.settings.layout.appearance.grain = $0 }))
            Toggle("Pause video on battery", isOn: $workspace.settings.layout.appearance.pauseVideoOnBattery)
            Text("Video is muted, loops, and pauses when collapsed. Large videos and blur increase GPU use. Background files are referenced in place.").font(.caption)
        }
    }

    @ViewBuilder private var motion: some View {
        Section("Animation") {
            Toggle("Animate expansion", isOn: $store.configuration.theme.animations)
            Picker("Animation timing", selection: Binding(get: { workspace.settings.layout.appearance.animation.rawValue }, set: { if let v = AnimationPreset(rawValue: $0) { workspace.settings.layout.appearance.animation = v } })) {
                ForEach(AnimationPreset.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0.rawValue) }
            }
        }
        SurfaceAppearanceControls(
            appearance: $workspace.settings.layout.appearance,
            theme: store.configuration.theme,
            screen: NSScreen.main ?? NSScreen.screens.first,
            scope: .motion
        )
        Section("Theme tools") {
            HStack {
                Button("Import theme…") { store.importTheme() }
                Button("Export theme…") { store.exportTheme() }
                Button("Reset") { store.configuration.theme = Theme(); workspace.settings.layout.appearance = Appearance() }
            }
        }
    }
}

@MainActor private struct DisplaySettingsPane: View {
    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore

    var body: some View {
        Toggle("Show on all displays", isOn: $store.configuration.allDisplays)
        ForEach(NSScreen.screens, id: \.localizedName) { screen in
            let id = WindowManager.displayID(screen)
            Section(screen.localizedName) {
                if let index = workspace.settings.displays.firstIndex(where: { $0.id == id }) {
                    Toggle("Show Halo here", isOn: $workspace.settings.displays[index].enabled)
                    if let profileID = workspace.settings.displays[index].profileID,
                       let profile = workspace.settings.profiles.first(where: { $0.id == profileID }) {
                        Picker("Display profile", selection: Binding(
                            get: { workspace.settings.displays[index].profileID ?? profileID },
                            set: { workspace.settings.displays[index].profileID = $0 }
                        )) {
                            ForEach(workspace.settings.profiles) { Text($0.name).tag($0.id) }
                        }
                        Text("This display follows \(profile.name) live. Editing that profile updates this display too.").font(.caption).foregroundStyle(.secondary)
                        Button("Customize this display instead") {
                            workspace.settings.displays[index].theme = profile.theme
                            workspace.settings.displays[index].layout = profile.layout
                            workspace.settings.displays[index].profileID = nil
                        }
                        Button("Follow global profile") { workspace.settings.displays.removeAll { $0.id == id } }
                    } else {
                        Picker("Style", selection: $workspace.settings.displays[index].theme.style) { ForEach(SurfaceStyle.allCases) { Text($0.rawValue).tag($0) } }
                        Slider(value: $workspace.settings.displays[index].theme.width, in: 340...640, onEditingChanged: { GeometryPreview.update(expanded: true, editing: $0, display: screen) }) { Text("Width") }
                        Slider(value: $workspace.settings.displays[index].theme.tint, in: 0...1) { Text("Accent") }
                        Menu("Use a profile on this display") {
                            ForEach(workspace.settings.profiles) { profile in
                                Button(profile.name) {
                                    workspace.settings.displays[index].profileID = profile.id
                                    workspace.settings.displays[index].theme = profile.theme
                                    workspace.settings.displays[index].layout = nil
                                }
                            }
                        }
                        Button("Follow global modules and background") {
                            workspace.settings.displays[index].profileID = nil
                            workspace.settings.displays[index].layout = nil
                        }
                        if workspace.settings.displays[index].layout != nil {
                            SurfaceAppearanceControls(
                                appearance: Binding(
                                    get: { workspace.settings.displays[index].layout?.appearance ?? workspace.settings.layout.appearance },
                                    set: { workspace.settings.displays[index].layout?.appearance = $0 }
                                ),
                                theme: workspace.settings.displays[index].theme,
                                screen: screen,
                                scope: .geometry
                            )
                        } else {
                            Button("Customize closed size, shape and position here") {
                                workspace.settings.displays[index].layout = workspace.settings.layout
                            }
                        }
                        Button("Use global theme") { workspace.settings.displays.removeAll { $0.id == id } }
                    }
                } else {
                    Button("Customize this display") { workspace.settings.displays.append(DisplayOverride(id: id, theme: store.configuration.theme)) }
                }
            }
        }
    }
}

'''
if insert_marker not in text:
    raise SystemExit("ProfileLibrary insertion marker not found")
text = text.replace(insert_marker, new_views + insert_marker, 1)
path.write_text(text)


# -----------------------------------------------------------------------------
# HaloApp.swift — display strategy + true global main profile + live onboarding.
# -----------------------------------------------------------------------------
path = Path("Halo/App/HaloApp.swift")
text = path.read_text()
text = replace_once(
    text,
    '''private enum HaloSetupPage: Int, CaseIterable {\n    case welcome, method, manual, guided, displays, review\n}\n\nprivate enum HaloSetupMethod: String {\n    case manual, guided\n}\n''',
    '''private enum HaloSetupPage: Int, CaseIterable {\n    case welcome, method, manual, guided, displayMode, displays, review\n}\n\nprivate enum HaloSetupMethod: String {\n    case manual, guided\n}\n\nprivate enum HaloSetupDisplayMode: String {\n    case shared, independent\n}\n''',
    "Halo setup page/display mode"
)
text = replace_once(
    text,
    '''private struct HaloSetupDisplayDraft: Identifiable {\n    let id: String\n    let name: String\n    let isNotched: Bool\n    var enabled: Bool\n    var theme: Theme\n    var layout: WorkspaceLayout\n}\n''',
    '''private struct HaloSetupDisplayDraft: Identifiable {\n    let id: String\n    let name: String\n    let isNotched: Bool\n    let isMain: Bool\n    var enabled: Bool\n    var theme: Theme\n    var layout: WorkspaceLayout\n}\n''',
    "Halo setup display draft main marker"
)
text = replace_once(
    text,
    '''    @State private var method: HaloSetupMethod?\n    @State private var guidedQuestion = 0\n''',
    '''    @State private var method: HaloSetupMethod?\n    @State private var displayMode: HaloSetupDisplayMode?\n    @State private var guidedQuestion = 0\n''',
    "Halo setup displayMode state"
)
text = replace_once(
    text,
    '''    @State private var selectedDisplay = 0\n    @State private var generatedProfile: Profile?\n\n    private let moduleChoices''',
    '''    @State private var selectedDisplay = 0\n    @State private var generatedProfile: Profile?\n    @State private var didFinish = false\n\n    private let initialTheme: Theme\n    private let initialLayout: WorkspaceLayout\n    private let initialDisplays: [DisplayOverride]\n    private let initialHover: Bool\n    private let initialAllDisplays: Bool\n\n    private let moduleChoices''',
    "Halo setup snapshots"
)
old_init = '''    init(store: AppStore, onComplete: @escaping () -> Void) {\n        self.store = store\n        self.onComplete = onComplete\n        _manualHover = State(initialValue: store.configuration.hoverToExpand)\n        let drafts = NSScreen.screens.map { screen -> HaloSetupDisplayDraft in\n            let id = WindowManager.displayID(screen)\n            let saved = store.workspace.settings.displays.first { $0.id == id }\n            var theme = saved?.theme ?? store.configuration.theme\n            if saved == nil, screen.safeAreaInsets.top <= 0, theme.style == .notch { theme.style = .pill }\n            return HaloSetupDisplayDraft(\n                id: id,\n                name: screen.localizedName,\n                isNotched: screen.safeAreaInsets.top > 0,\n                enabled: saved?.enabled ?? true,\n                theme: theme,\n                layout: saved?.layout ?? store.workspace.settings.layout\n            )\n        }\n        _displayDrafts = State(initialValue: drafts)\n    }\n'''
new_init = '''    init(store: AppStore, onComplete: @escaping () -> Void) {\n        self.store = store\n        self.onComplete = onComplete\n        initialTheme = store.configuration.theme\n        initialLayout = store.workspace.settings.layout\n        initialDisplays = store.workspace.settings.displays\n        initialHover = store.configuration.hoverToExpand\n        initialAllDisplays = store.configuration.allDisplays\n        _manualHover = State(initialValue: store.configuration.hoverToExpand)\n\n        let screens = NSScreen.screens\n        let mainID = (NSScreen.main ?? screens.first).map(WindowManager.displayID)\n        let drafts = screens.map { screen -> HaloSetupDisplayDraft in\n            let id = WindowManager.displayID(screen)\n            let saved = store.workspace.settings.displays.first { $0.id == id }\n            let linkedProfile = saved?.profileID.flatMap { profileID in\n                store.workspace.settings.profiles.first { $0.id == profileID }\n            }\n            var theme = linkedProfile?.theme ?? saved?.theme ?? store.configuration.theme\n            if saved == nil, screen.safeAreaInsets.top <= 0, theme.style == .notch { theme.style = .pill }\n            return HaloSetupDisplayDraft(\n                id: id,\n                name: screen.localizedName,\n                isNotched: screen.safeAreaInsets.top > 0,\n                isMain: id == mainID,\n                enabled: saved?.enabled ?? true,\n                theme: theme,\n                layout: linkedProfile?.layout ?? saved?.layout ?? store.workspace.settings.layout\n            )\n        }.sorted { lhs, rhs in\n            if lhs.isMain != rhs.isMain { return lhs.isMain }\n            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending\n        }\n        _displayDrafts = State(initialValue: drafts)\n    }\n'''
text = replace_once(text, old_init, new_init, "Halo setup init")
text = replace_once(
    text,
    '''        .foregroundStyle(.white)\n        .frame(minWidth: 900, minHeight: 640)\n    }\n''',
    '''        .foregroundStyle(.white)\n        .frame(minWidth: 900, minHeight: 640)\n        .onDisappear {\n            if !didFinish { restoreInitialState() }\n        }\n    }\n''',
    "Halo setup cancel restoration"
)
text = replace_once(
    text,
    '''        case .manual, .guided: return 2\n        case .displays: return 3\n        case .review: return 4\n''',
    '''        case .manual, .guided: return 2\n        case .displayMode, .displays: return 3\n        case .review: return 4\n''',
    "Halo setup progress"
)
text = replace_once(
    text,
    '''        case .manual: manualPage\n        case .guided: guidedPage\n        case .displays: guidedDisplaysPage\n''',
    '''        case .manual: manualPage\n        case .guided: guidedPage\n        case .displayMode: displayModePage\n        case .displays: guidedDisplaysPage\n''',
    "Halo setup page content"
)

display_mode_views = r'''    private var displayModePage: some View {
        VStack(spacing: 26) {
            VStack(spacing: 7) {
                Text("How should your displays work together?")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Your main display is always the global Halo. Secondary displays can mirror it or become their own profiles.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.58))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 18) {
                displayModeCard(
                    .shared,
                    title: "Same profile everywhere",
                    detail: "One global Halo across every display. Change the global profile later and every display follows automatically.",
                    symbol: "rectangle.on.rectangle",
                    badge: "Simple"
                )
                displayModeCard(
                    .independent,
                    title: "Customize secondary displays",
                    detail: "The main display keeps the global profile. Every secondary display gets its own saved profile and can look or behave differently.",
                    symbol: "display.2",
                    badge: "Independent"
                )
            }
            .frame(maxWidth: 820)
        }
        .padding(46)
    }

    private func displayModeCard(_ value: HaloSetupDisplayMode, title: String, detail: String, symbol: String, badge: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                displayMode = value
                prepareDisplayMode()
            }
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: symbol).font(.system(size: 28, weight: .semibold))
                    Spacer()
                    Text(badge.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.6)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
                Spacer()
                Text(title).font(.system(size: 21, weight: .bold, design: .rounded))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Text(value == .shared ? "Global profile on all displays" : "Global main · own secondary profiles")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Image(systemName: displayMode == value ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .padding(22)
            .frame(width: 380, height: 255, alignment: .leading)
            .background(displayMode == value ? Color.white.opacity(0.12) : Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(displayMode == value ? Color.white.opacity(0.42) : Color.white.opacity(0.08), lineWidth: displayMode == value ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

'''
manual_marker = "    private var manualPage: some View {\n"
if manual_marker not in text:
    raise SystemExit("manual page marker not found")
text = text.replace(manual_marker, display_mode_views + manual_marker, 1)

new_manual = r'''    private var manualPage: some View {
        VStack(spacing: 18) {
            pageHeading(
                displayMode == .independent ? "Tune each Halo" : "Tune your global Halo",
                displayMode == .independent
                    ? "The main display edits the global profile. Secondary displays are independent and update live as you change them."
                    : "These changes are live and every connected display follows the same global profile."
            )
            if displayMode == .independent { displaySelector }
            if displayDrafts.indices.contains(activeDisplayIndex) {
                manualEditor(index: activeDisplayIndex)
            }
        }
        .padding(.horizontal, 38)
        .padding(.vertical, 24)
    }

'''
text = replace_between(text, "    private var manualPage: some View {\n", "    private var displaySelector: some View {\n", new_manual, "manual page")

new_selector = r'''    private var displaySelector: some View {
        HStack(spacing: 8) {
            ForEach(displayDrafts.indices, id: \.self) { index in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedDisplay = index }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: displayDrafts[index].isNotched ? "laptopcomputer" : "display")
                        VStack(alignment: .leading, spacing: 1) {
                            Text(displayDrafts[index].name)
                            Text(displayDrafts[index].isMain ? "Global profile" : "Own profile")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.white.opacity(0.48))
                        }
                        if !displayDrafts[index].enabled { Image(systemName: "minus.circle.fill").opacity(0.55) }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(selectedDisplay == index ? Color.white.opacity(0.16) : Color.white.opacity(0.055), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(selectedDisplay == index ? 0.28 : 0.07), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

'''
text = replace_between(text, "    private var displaySelector: some View {\n", "    private func manualEditor(index: Int) -> some View {\n", new_selector, "display selector")

text = replace_once(
    text,
    '''                    Toggle("Use Halo on this display", isOn: displayBinding(index, \\.enabled))\n                    Picker("Style", selection: themeBinding(index, \\.style)) {\n''',
    '''                    if displayDrafts[index].isMain {\n                        Label(displayMode == .shared ? "Global profile · shared across all displays" : "Main display · global profile", systemImage: "globe")\n                            .font(.system(size: 10, weight: .semibold))\n                            .foregroundStyle(.white.opacity(0.62))\n                    } else {\n                        Toggle("Use Halo on this display", isOn: displayBinding(index, \\.enabled))\n                    }\n                    Picker("Style", selection: themeBinding(index, \\.style)) {\n''',
    "manual editor display ownership"
)
text = replace_once(
    text,
    '''                    Toggle("Expand when I hover", isOn: $manualHover)\n''',
    '''                    Toggle("Expand when I hover", isOn: liveHoverBinding)\n''',
    "manual hover live binding"
)
text = replace_once(
    text,
    '''                Button {\n                    if enabled { displayDrafts[index].layout.enabled.remove(module) }\n                    else { displayDrafts[index].layout.enabled.insert(module) }\n                } label: {\n''',
    '''                Button {\n                    if enabled { displayDrafts[index].layout.enabled.remove(module) }\n                    else { displayDrafts[index].layout.enabled.insert(module) }\n                    applyLivePreview()\n                } label: {\n''',
    "module live preview"
)
text = replace_once(text, "{ useCase = option }", "{ useCase = option; refreshGuidedPreview() }", "guided use case live preview")
text = replace_once(text, "{ priority = option }", "{ priority = option; refreshGuidedPreview() }", "guided priority live preview")
text = replace_once(text, "{ density = option }", "{ density = option; refreshGuidedPreview() }", "guided density live preview")
text = replace_once(text, "{ motion = option }", "{ motion = option; refreshGuidedPreview() }", "guided motion live preview")

new_guided_displays = r'''    private var guidedDisplaysPage: some View {
        VStack(spacing: 18) {
            pageHeading(
                displayMode == .independent ? "Fine-tune each display" : "Fine-tune the shared profile",
                displayMode == .independent
                    ? "Your main display stays global. Secondary display profiles can now diverge, and every change previews live."
                    : "Every connected display follows this same global profile. Changes preview immediately."
            )
            if displayMode == .independent { displaySelector }
            if displayDrafts.indices.contains(activeDisplayIndex) {
                let index = activeDisplayIndex
                setupPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        if displayDrafts[index].isMain {
                            Label(displayMode == .shared ? "Global profile · all displays" : "Main display · global profile", systemImage: "globe")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.62))
                        } else {
                            Toggle("Use Halo on \(displayDrafts[index].name)", isOn: displayBinding(index, \.enabled))
                        }
                        Picker("Surface", selection: themeBinding(index, \.style)) {
                            ForEach(surfaceChoices) { style in Text(style.rawValue).tag(style) }
                        }
                        Slider(value: themeBinding(index, \.width), in: 340...640, step: 10) { Text("Open width") }
                        Slider(value: appearanceBinding(index, \.expandedHeight), in: 280...720, step: 10) { Text("Open height") }
                        HStack(spacing: 8) {
                            Image(systemName: displayDrafts[index].isNotched ? "camera.metering.center.weighted" : "display")
                            Text(displayDrafts[index].isNotched ? "Halo detected a physical notch on this display." : "This display has no physical notch; choose the surface that feels best here.")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                .frame(maxWidth: 650)
            }
        }
        .padding(.horizontal, 42)
        .padding(.vertical, 26)
    }

'''
text = replace_between(text, "    private var guidedDisplaysPage: some View {\n", "    private var reviewPage: some View {\n", new_guided_displays, "guided displays page")
text = replace_once(
    text,
    '''                reviewCard("Displays", "\\(displayDrafts.filter(\\.enabled).count) enabled", "display.2")\n''',
    '''                reviewCard("Displays", displayMode == .independent ? "Independent profiles" : "Shared global profile", "display.2")\n''',
    "review display strategy"
)

new_navigation_logic = r'''    private func advance() {
        withAnimation(.easeInOut(duration: 0.2)) {
            switch page {
            case .welcome:
                page = .method
            case .method:
                if method == .guided {
                    refreshGuidedPreview()
                    page = .guided
                } else if displayDrafts.count > 1 {
                    page = .displayMode
                } else {
                    displayMode = .shared
                    prepareDisplayMode()
                    page = .manual
                }
            case .manual:
                generatedProfile = nil
                page = .review
            case .guided:
                if guidedQuestion < 3 {
                    guidedQuestion += 1
                } else {
                    buildGuidedDrafts()
                    if displayDrafts.count > 1 { page = .displayMode }
                    else { displayMode = .shared; prepareDisplayMode(); page = .displays }
                }
            case .displayMode:
                prepareDisplayMode()
                page = method == .guided ? .displays : .manual
            case .displays:
                page = .review
            case .review:
                commitSetup()
            }
        }
    }

    private func goBack() {
        withAnimation(.easeInOut(duration: 0.2)) {
            switch page {
            case .welcome: break
            case .method: page = .welcome
            case .manual: page = displayDrafts.count > 1 ? .displayMode : .method
            case .guided:
                if guidedQuestion > 0 { guidedQuestion -= 1 }
                else { page = .method }
            case .displayMode:
                if method == .guided { guidedQuestion = 3; page = .guided }
                else { page = .method }
            case .displays:
                if displayDrafts.count > 1 { page = .displayMode }
                else { guidedQuestion = 3; page = .guided }
            case .review:
                page = method == .guided ? .displays : .manual
            }
        }
    }

'''
text = replace_between(text, "    private func advance() {\n", "    private func buildGuidedDrafts() {\n", new_navigation_logic, "onboarding navigation")

new_build_guided = r'''    private func buildGuidedDrafts() {
        refreshGuidedPreview()
        if displayMode == .independent { prepareDisplayMode() }
    }

    private func refreshGuidedPreview() {
        let profile = makeGuidedProfile()
        generatedProfile = profile
        manualHover = true
        guard displayDrafts.indices.contains(mainDraftIndex) else { return }
        displayDrafts[mainDraftIndex].layout = profile.layout
        displayDrafts[mainDraftIndex].theme = profile.theme
        if displayMode != .independent {
            for index in displayDrafts.indices where index != mainDraftIndex {
                displayDrafts[index].layout = profile.layout
                displayDrafts[index].theme = profile.theme
            }
        }
        applyLivePreview()
    }

    private func prepareDisplayMode() {
        guard let displayMode, displayDrafts.indices.contains(mainDraftIndex) else { return }
        let globalTheme = displayDrafts[mainDraftIndex].theme
        let globalLayout = displayDrafts[mainDraftIndex].layout
        for index in displayDrafts.indices where index != mainDraftIndex {
            displayDrafts[index].enabled = true
            displayDrafts[index].theme = globalTheme
            displayDrafts[index].layout = globalLayout
            if displayMode == .independent, !displayDrafts[index].isNotched, displayDrafts[index].theme.style == .notch {
                displayDrafts[index].theme.style = .pill
            }
        }
        selectedDisplay = mainDraftIndex
        applyLivePreview()
    }

'''
text = replace_between(text, "    private func buildGuidedDrafts() {\n", "    private func makeGuidedProfile() -> Profile {\n", new_build_guided, "guided draft/live preview")

# Add active index/live preview helpers before commitSetup.
helper_marker = "    private func commitSetup() {\n"
helpers = r'''    private var mainDraftIndex: Int {
        displayDrafts.firstIndex(where: { $0.isMain }) ?? 0
    }

    private var activeDisplayIndex: Int {
        displayMode == .independent ? selectedDisplay : mainDraftIndex
    }

    private var liveHoverBinding: Binding<Bool> {
        Binding(get: { manualHover }, set: { value in
            manualHover = value
            applyLivePreview()
        })
    }

    private func applyLivePreview() {
        guard displayDrafts.indices.contains(mainDraftIndex) else { return }
        let main = displayDrafts[mainDraftIndex]
        store.configuration.hoverToExpand = manualHover
        store.configuration.allDisplays = displayDrafts.count > 1
        store.configuration.theme = main.theme
        store.workspace.settings.layout = main.layout

        let currentIDs = Set(displayDrafts.map(\.id))
        let preserved = initialDisplays.filter { !currentIDs.contains($0.id) }
        if displayMode == .independent {
            var overrides = displayDrafts.filter { !$0.isMain }.map { draft in
                DisplayOverride(id: draft.id, enabled: draft.enabled, theme: draft.theme, layout: draft.layout, profileID: nil)
            }
            if !main.enabled {
                overrides.append(DisplayOverride(id: main.id, enabled: false, theme: main.theme, layout: nil, profileID: nil))
            }
            store.workspace.settings.displays = preserved + overrides
        } else {
            store.workspace.settings.displays = preserved
        }
    }

    private func restoreInitialState() {
        store.configuration.hoverToExpand = initialHover
        store.configuration.allDisplays = initialAllDisplays
        store.configuration.theme = initialTheme
        store.workspace.settings.layout = initialLayout
        store.workspace.settings.displays = initialDisplays
    }

    private func upsertOnboardingProfile(_ value: Profile, marker: String) -> UUID {
        var profile = value
        profile.description = marker
        if let index = store.workspace.settings.profiles.firstIndex(where: { $0.description == marker }) {
            profile.id = store.workspace.settings.profiles[index].id
            store.workspace.settings.profiles[index] = profile
            return profile.id
        }
        store.workspace.settings.profiles.append(profile)
        return profile.id
    }

'''
if helper_marker not in text:
    raise SystemExit("commitSetup helper marker not found")
text = text.replace(helper_marker, helpers + helper_marker, 1)

new_commit = r'''    private func commitSetup() {
        guard displayDrafts.indices.contains(mainDraftIndex) else { return }
        let main = displayDrafts[mainDraftIndex]
        applyLivePreview()

        var globalProfile: Profile
        if method == .guided {
            globalProfile = generatedProfile ?? makeGuidedProfile()
            globalProfile.theme = main.theme
            globalProfile.layout = main.layout
        } else {
            globalProfile = Profile(name: "My Halo", theme: main.theme, layout: main.layout)
            globalProfile.icon = "slider.horizontal.3"
        }
        _ = upsertOnboardingProfile(globalProfile, marker: "Halo Setup Profile")

        let currentIDs = Set(displayDrafts.map(\.id))
        let preserved = initialDisplays.filter { !currentIDs.contains($0.id) }
        if displayMode == .independent {
            var overrides: [DisplayOverride] = []
            for draft in displayDrafts where !draft.isMain {
                var profile = Profile(name: "\(draft.name) Halo", theme: draft.theme, layout: draft.layout)
                profile.icon = draft.isNotched ? "laptopcomputer" : "display"
                let marker = "Halo Display Profile:\(draft.id)"
                let profileID = upsertOnboardingProfile(profile, marker: marker)
                overrides.append(DisplayOverride(id: draft.id, enabled: draft.enabled, theme: draft.theme, layout: nil, profileID: profileID))
            }
            if !main.enabled {
                overrides.append(DisplayOverride(id: main.id, enabled: false, theme: main.theme, layout: nil, profileID: nil))
            }
            store.workspace.settings.displays = preserved + overrides
        } else {
            store.workspace.settings.displays = preserved
        }

        didFinish = true
        store.flushConfiguration()
        onComplete()
    }

'''
text = replace_between(text, "    private func commitSetup() {\n", "    private func displayBinding<T>", new_commit, "commit setup")

new_bindings = r'''    private func displayBinding<T>(_ index: Int, _ keyPath: WritableKeyPath<HaloSetupDisplayDraft, T>) -> Binding<T> {
        Binding(
            get: { displayDrafts[index][keyPath: keyPath] },
            set: { value in
                displayDrafts[index][keyPath: keyPath] = value
                applyLivePreview()
            }
        )
    }

    private func themeBinding<T>(_ index: Int, _ keyPath: WritableKeyPath<Theme, T>) -> Binding<T> {
        Binding(
            get: { displayDrafts[index].theme[keyPath: keyPath] },
            set: { value in
                displayDrafts[index].theme[keyPath: keyPath] = value
                if displayMode == .shared, index == mainDraftIndex {
                    for other in displayDrafts.indices where other != mainDraftIndex { displayDrafts[other].theme[keyPath: keyPath] = value }
                }
                applyLivePreview()
            }
        )
    }

    private func appearanceBinding<T>(_ index: Int, _ keyPath: WritableKeyPath<Appearance, T>) -> Binding<T> {
        Binding(
            get: { displayDrafts[index].layout.appearance[keyPath: keyPath] },
            set: { value in
                displayDrafts[index].layout.appearance[keyPath: keyPath] = value
                if displayMode == .shared, index == mainDraftIndex {
                    for other in displayDrafts.indices where other != mainDraftIndex { displayDrafts[other].layout.appearance[keyPath: keyPath] = value }
                }
                applyLivePreview()
            }
        )
    }
}


'''
text = replace_between(text, "    private func displayBinding<T>", "enum HaloHUDKeys {", new_bindings, "live onboarding bindings")

# canAdvance needs the new display mode step.
text = replace_once(
    text,
    '''        case .method: return method != nil\n        case .manual, .displays, .review: return hasEnabledDisplay\n''',
    '''        case .method: return method != nil\n        case .displayMode: return displayMode != nil\n        case .manual, .displays, .review: return hasEnabledDisplay\n''',
    "canAdvance display mode"
)
path.write_text(text)

print("Refined onboarding profile strategy, live preview, and Appearance performance")
