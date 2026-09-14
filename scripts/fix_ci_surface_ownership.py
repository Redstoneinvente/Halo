from pathlib import Path

p = Path('Halo/Views/SurfaceView.swift')
s = p.read_text()

old = '''    private var contextOwnsFullSurface: Bool {
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
    }
    private var keepsClosedContentsWhileExpanded: Bool {
        switch activeContext {
        case .drop: return dropKeepsClosedContents
        case .music: return contextMusicKeepsClosedContents
        case .bluetooth: return bluetoothKeepsClosedContents
        case .retro: return retroKeepsClosedContents
        case .teleprompter: return false
        case .transfer: return transferKeepsClosedContents
        case .none:
            // The two opened-layout systems are mutually exclusive. The Default
            // layout is the only system allowed to keep its closed-notch strip.
            return usesDefaultWorkspace && keepClosedContentsWhenOpen
        }
    }'''
new = '''    private var contextOwnsFullSurface: Bool {
        // A winning embedded CI replaces Halo's normal notch surface completely.
        // Teleprompter is presented in its own panel and suppresses this surface instead.
        guard state.expanded else { return false }
        switch activeContext {
        case .drop, .music, .bluetooth, .retro, .transfer: return true
        case .teleprompter, .none: return false
        }
    }
    private var keepsClosedContentsWhileExpanded: Bool {
        // Context Interfaces own the notch. Closed-notch content must never be layered
        // above or alongside a winning CI.
        if activeContext != nil { return false }
        return usesDefaultWorkspace && keepClosedContentsWhenOpen
    }'''
if old not in s:
    raise SystemExit('ownership block anchor missing')
s = s.replace(old, new, 1)

old = '''                    .onTapGesture {
                        guard !teleprompterActive else { return }
                        if state.expanded && state.pinned { return }
                        state.expanded.toggle()
                    }'''
new = '''                    .onTapGesture {
                        guard activeContext == nil else { return }
                        if state.expanded && state.pinned { return }
                        state.expanded.toggle()
                    }'''
if old not in s:
    raise SystemExit('tap ownership anchor missing')
s = s.replace(old, new, 1)

old = '''        .onHover { hovering in
            if teleprompterContextActive {
                state.collapseTask?.cancel()
                if !state.pinned { state.expanded = false }
            } else {
                state.hover(hovering, enabled: store.configuration.hoverToExpand)
            }
        }'''
new = '''        .onHover { hovering in
            if teleprompterContextActive {
                state.collapseTask?.cancel()
                if !state.pinned { state.expanded = false }
            } else if activeContext != nil {
                // A winning CI owns the surface; normal notch hover expansion/collapse
                // must not run until CI ownership is released.
                state.collapseTask?.cancel()
            } else {
                state.hover(hovering, enabled: store.configuration.hoverToExpand)
            }
        }'''
if old not in s:
    raise SystemExit('hover ownership anchor missing')
s = s.replace(old, new, 1)

old = '''    @ViewBuilder private var surfaceBackgroundLayer: some View {
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
new = '''    @ViewBuilder private var surfaceBackgroundLayer: some View {
        ZStack {
            if activeContext != nil {
                // CI owns the surface. Do not leak the user's normal notch background
                // or album-art layer into a Context Interface.
                Color.black
            } else if state.expanded && usesVisualWorkspace {
                OpenNotchBackgroundView(options: layout.resolvedOpenNotchLayout.appearance, fallback: layout.appearance, theme: theme, system: workspace.system)
            } else {
                SurfaceBackground(appearance: layout.appearance, theme: theme, expanded: state.expanded, system: workspace.system)
            }
            if activeContext == nil && (!state.expanded || layout.closedNotch?.applyBackgroundWhenOpened == true) {
                AlbumNotchBackground(options: closedBackgroundOptions, media: workspace.media, system: workspace.system)
            }
        }
    }'''
if old not in s:
    raise SystemExit('background ownership anchor missing')
s = s.replace(old, new, 1)

# Make the transfer UI wording match the ownership invariant. Keep existing AppStorage
# keys for backwards-compatible settings migration, but no longer expose an option that
# can violate CI ownership.
s = s.replace('''            Toggle("Use full notch area", isOn: $useFullNotchArea)
            Toggle("Keep closed-notch contents visible", isOn: $keepClosedNotchContents)
            Text("Transfer CI requests the space it needs automatically and releases it when transfer activity ends.")
                .font(.caption).foregroundStyle(.secondary)''', '''            Label("Transfer CI takes full ownership of the notch while active.", systemImage: "rectangle.inset.filled")
            Text("The normal Halo notch is hidden until the transfer ends or another higher-priority CI wins ownership.")
                .font(.caption).foregroundStyle(.secondary)''')

p.write_text(s)
