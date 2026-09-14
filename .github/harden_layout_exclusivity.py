from pathlib import Path

surface = Path("Halo/Views/SurfaceView.swift")
text = surface.read_text()

old = """    private var modules: [ModuleID] { layout.normalizedOrder().filter { layout.enabled.contains($0) } }
    private var accent: Color { Color(hue: theme.tint, saturation: 0.65, brightness: 1) }
"""
new = """    private var modules: [ModuleID] { layout.normalizedOrder().filter { layout.enabled.contains($0) } }
    private var usesVisualWorkspace: Bool { layout.resolvedUsesCustomOpenNotchWorkspace }
    private var usesDefaultWorkspace: Bool { !usesVisualWorkspace }
    private var accent: Color { Color(hue: theme.tint, saturation: 0.65, brightness: 1) }
"""
if old not in text:
    raise SystemExit("SurfaceView layout flag anchor not found")
text = text.replace(old, new, 1)

old = """        case .none:
            // Visual Workspace owns the entire opened surface. Never layer the
            // Default/closed-notch strip over it, even if the legacy preference
            // was enabled before the user switched layout systems.
            return layout.resolvedUsesCustomOpenNotchWorkspace ? false : keepClosedContentsWhenOpen
"""
new = """        case .none:
            // The two opened-layout systems are mutually exclusive. The Default
            // layout is the only system allowed to keep its closed-notch strip.
            return usesDefaultWorkspace && keepClosedContentsWhenOpen
"""
if old not in text:
    raise SystemExit("SurfaceView closed-strip anchor not found")
text = text.replace(old, new, 1)

anchor = '!(state.expanded && activeContext == nil && layout.resolvedUsesCustomOpenNotchWorkspace) {'
if anchor not in text:
    raise SystemExit("SurfaceView top-strip anchor not found")
text = text.replace(anchor, '!(state.expanded && activeContext == nil && usesVisualWorkspace) {', 1)

old = """                    } else if layout.resolvedUsesCustomOpenNotchWorkspace {
                        // The Visual Workspace receives one authoritative canvas: exactly the
"""
new = """                    } else if usesVisualWorkspace {
                        // The Visual Workspace receives one authoritative canvas: exactly the
"""
if old not in text:
    raise SystemExit("SurfaceView visual branch anchor not found")
text = text.replace(old, new, 1)

old = "                            openDashboardContent\n"
if old not in text:
    raise SystemExit("SurfaceView default dashboard anchor not found")
text = text.replace(old, "                            legacyOpenDashboardContent\n", 1)

for _ in range(2):
    anchor = 'if state.expanded && activeContext == nil && layout.resolvedUsesCustomOpenNotchWorkspace {'
    if anchor not in text:
        break
    text = text.replace(anchor, 'if state.expanded && activeContext == nil && usesVisualWorkspace {', 1)

old = """    @ViewBuilder private var openDashboardContent: some View {
        if layout.resolvedUsesCustomOpenNotchWorkspace {
            OpenNotchWorkspaceView(layout: layout, store: store, mode: layout.resolvedOpenNotchLayout.resolvedContentMode, page: $page)
        } else {
            legacyOpenDashboardContent
        }
    }
"""
if old in text:
    text = text.replace(old, "", 1)

surface.write_text(text)

settings = Path("Halo/Views/WorkspaceSettingsView.swift")
text = settings.read_text()
old = """        Section("Opened notch behavior") {
            Toggle("Keep closed-notch contents visible when opened", isOn: $keepClosedContentsWhenOpen)
            Text("Keeps the normal Closed Notch widgets and media visible in the top strip. Context Interfaces keep their own layout rules.")
                .font(.caption).foregroundStyle(.secondary)
        }
"""
new = """        if workspace.settings.layout.resolvedUsesCustomOpenNotchWorkspace {
            Section("Opened notch behavior") {
                Label("Visual Workspace owns the opened notch", systemImage: "rectangle.3.group")
                Text("Default-layout chrome and the closed-notch top strip are disabled while Visual Workspace is active. Switch back to Default to use those options.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } else {
            Section("Opened notch behavior") {
                Toggle("Keep closed-notch contents visible when opened", isOn: $keepClosedContentsWhenOpen)
                Text("Keeps the normal Closed Notch widgets and media visible in the top strip. Context Interfaces keep their own layout rules.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
"""
if old not in text:
    raise SystemExit("WorkspaceSettings opened behavior anchor not found")
text = text.replace(old, new, 1)
settings.write_text(text)
