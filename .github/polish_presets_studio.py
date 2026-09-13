from pathlib import Path

workspace_path = Path('Halo/Core/WorkspaceModels.swift')
workspace = workspace_path.read_text()
start = workspace.index('    static func made(_ preset: OpenNotchPreset) -> OpenNotchLayout {')
end = workspace.index('    func validated() throws -> OpenNotchLayout {', start)
replacement = r'''    static func made(_ preset: OpenNotchPreset) -> OpenNotchLayout {
        func item(_ module: ModuleID, _ column: Int, _ row: Int, _ columns: Int, _ rows: Int,
                  _ presentation: OpenNotchPresentation = .automatic,
                  _ priority: OpenNotchPriority = .normal) -> OpenNotchItem {
            var value = OpenNotchItem.moduleItem(module, presentation: presentation, priority: priority)
            value.gridPlacement = OpenNotchGridPlacement(column: column, row: row, columnSpan: columns, rowSpan: rows)
            return value
        }
        func grid(_ columns: Int = 8, _ rows: Int = 4, cellHeight: Double = 96, gap: Double = 9,
                  _ items: [OpenNotchItem]) -> OpenNotchLayout {
            OpenNotchLayout(preset: preset, regions: [], gridItems: items,
                            gridColumns: columns, gridRows: rows, gridGap: gap,
                            gridCellHeight: cellHeight,
                            gridPadding: OpenNotchInsets(top: 10, leading: 12, bottom: 12, trailing: 12))
        }

        switch preset {
        case .minimal:
            // Intentionally sparse: one large clock floating in the center instead of a generic stack.
            return grid(8, 4, cellHeight: 92, gap: 10, [
                item(.clock, 2, 1, 4, 2, .expanded, .alwaysVisible)
            ])

        case .media:
            // Hero player with a dedicated right-side audio/activity rail.
            return grid(8, 4, cellHeight: 104, gap: 10, [
                item(.media,      0, 0, 6, 4, .expanded, .alwaysVisible),
                item(.audio,      6, 0, 2, 2, .expanded, .high),
                item(.activities, 6, 2, 2, 2, .regular,  .normal)
            ])

        case .productivity:
            // Calendar dominates the canvas; notes/timer sit in a purposeful work rail.
            return grid(8, 4, cellHeight: 102, gap: 9, [
                item(.calendar, 0, 0, 5, 3, .expanded, .alwaysVisible),
                item(.notes,    5, 0, 3, 2, .expanded, .high),
                item(.timer,    5, 2, 3, 1, .compact,  .high),
                item(.shelf,    0, 3, 5, 1, .compact,  .normal),
                item(.launcher, 5, 3, 3, 1, .compact,  .normal)
            ])

        case .systemMonitor:
            // Large telemetry dashboard plus a narrow operational status rail.
            return grid(8, 4, cellHeight: 100, gap: 8, [
                item(.system,     0, 0, 5, 4, .expanded, .alwaysVisible),
                item(.activities, 5, 0, 3, 2, .expanded, .high),
                item(.audio,      5, 2, 3, 1, .compact,  .normal),
                item(.clock,      5, 3, 3, 1, .compact,  .high)
            ])

        case .focus:
            // Timer and writing surface get almost all the visual weight; supporting state is quiet.
            return grid(8, 4, cellHeight: 104, gap: 10, [
                item(.timer,      0, 0, 5, 3, .expanded, .alwaysVisible),
                item(.notes,      5, 0, 3, 3, .expanded, .high),
                item(.clock,      0, 3, 4, 1, .compact,  .high),
                item(.activities, 4, 3, 4, 1, .compact,  .low)
            ])

        case .developer:
            // Four equally strong quadrants: observe, launch, capture and jot context.
            return grid(8, 4, cellHeight: 98, gap: 8, [
                item(.system,   0, 0, 4, 2, .expanded, .high),
                item(.launcher, 4, 0, 4, 2, .expanded, .high),
                item(.capture,  0, 2, 4, 2, .expanded, .high),
                item(.notes,    4, 2, 4, 2, .expanded, .normal)
            ])

        case .informationDense:
            // A deliberate six-row mosaic rather than a vertical pile of compact cards.
            return grid(8, 6, cellHeight: 88, gap: 7, [
                item(.clock,      0, 0, 2, 1, .compact, .high),
                item(.timer,      2, 0, 2, 1, .compact, .high),
                item(.audio,      4, 0, 2, 1, .compact, .normal),
                item(.activities, 6, 0, 2, 1, .compact, .normal),
                item(.calendar,   0, 1, 4, 3, .expanded, .high),
                item(.system,     4, 1, 4, 3, .expanded, .high),
                item(.clipboard,  0, 4, 2, 2, .expanded, .normal),
                item(.shelf,      2, 4, 2, 2, .expanded, .normal),
                item(.launcher,   4, 4, 2, 2, .expanded, .normal),
                item(.notes,      6, 4, 2, 2, .expanded, .normal)
            ])

        case .showcase:
            // Asymmetric demo composition: one cinematic hero with a compact feature rail.
            return grid(8, 4, cellHeight: 108, gap: 10, [
                item(.media,      0, 0, 6, 4, .expanded, .alwaysVisible),
                item(.clock,      6, 0, 2, 1, .compact,  .high),
                item(.audio,      6, 1, 2, 1, .compact,  .high),
                item(.activities, 6, 2, 2, 1, .compact,  .normal),
                item(.capture,    6, 3, 2, 1, .compact,  .normal)
            ])

        case .custom:
            return migrated(modules: ModuleID.allCases.filter { $0 != .developer }, horizontal: false)
        }
    }

'''
workspace = workspace[:start] + replacement + workspace[end:]
workspace_path.write_text(workspace)

surface_path = Path('Halo/Views/SurfaceView.swift')
surface = surface_path.read_text()

surface = surface.replace(
'''    case neon = "Neon"\n    case smoked = "Smoked"\n    case custom = "Custom"''',
'''    case neon = "Neon"\n    case smoked = "Smoked"\n    case chrome = "Chrome"\n    case aurora = "Aurora"\n    case translucent = "Translucent"\n    case custom = "Custom"''', 1)

start = surface.index('    static func made(_ preset: VinylStylePreset) -> VinylStyleOptions {')
end = surface.index('    func normalized() -> VinylStyleOptions {', start)
vinyl_made = r'''    static func made(_ preset: VinylStylePreset) -> VinylStyleOptions {
        var value = VinylStyleOptions()
        value.preset = preset
        switch preset {
        case .classic:
            value.grooveCount = 10
            value.grooveOpacity = 0.13
            value.edgeRingOpacity = 0.18
            value.highlightIntensity = 0.18
            value.gloss = 0.16
            value.depth = 0.78
            value.rpm = 8

        case .studio:
            value.grooveCount = 16
            value.grooveOpacity = 0.16
            value.grooveWidth = 0.004
            value.edgeRingOpacity = 0.34
            value.edgeRingWidth = 0.011
            value.highlightIntensity = 0.52
            value.highlightArc = 0.34
            value.highlightWidth = 0.013
            value.gloss = 0.48
            value.shadowOpacity = 0.55
            value.shadowRadius = 0.085
            value.labelBorderOpacity = 0.52
            value.depth = 0.92
            value.rpm = 9

        case .minimal:
            value.grooveCount = 1
            value.grooveOpacity = 0.028
            value.edgeRingOpacity = 0.035
            value.highlightIntensity = 0.035
            value.gloss = 0.025
            value.shadowOpacity = 0.14
            value.labelBorderOpacity = 0.06
            value.labelScale = 0.36
            value.centerCapScale = 0.07
            value.depth = 0.34
            value.rpm = 5

        case .retro:
            value.discColorSource = .custom
            value.accentSource = .custom
            value.labelStyle = .custom
            value.customDiscColor = WidgetColor(red: 0.105, green: 0.058, blue: 0.028)
            value.customAccentColor = WidgetColor(red: 0.96, green: 0.73, blue: 0.34)
            value.customLabelColor = WidgetColor(red: 0.64, green: 0.10, blue: 0.07)
            value.grooveCount = 7
            value.grooveOpacity = 0.24
            value.grooveWidth = 0.0075
            value.labelScale = 0.56
            value.highlightIntensity = 0.09
            value.gloss = 0.06
            value.edgeRingOpacity = 0.28
            value.rpm = 5.5

        case .neon:
            value.discColorSource = .album
            value.accentSource = .album
            value.labelStyle = .albumColor
            value.discOpacity = 0.96
            value.grooveCount = 13
            value.grooveOpacity = 0.34
            value.grooveWidth = 0.007
            value.edgeRingOpacity = 0.62
            value.edgeRingWidth = 0.014
            value.highlightIntensity = 0.44
            value.gloss = 0.30
            value.glowOpacity = 0.88
            value.glowRadius = 0.20
            value.depth = 0.50
            value.rpm = 12

        case .smoked:
            value.discColorSource = .custom
            value.accentSource = .custom
            value.customDiscColor = WidgetColor(red: 0.065, green: 0.085, blue: 0.11)
            value.customAccentColor = WidgetColor(red: 0.58, green: 0.72, blue: 0.82)
            value.discOpacity = 0.78
            value.grooveCount = 18
            value.grooveOpacity = 0.10
            value.grooveWidth = 0.0036
            value.edgeRingOpacity = 0.16
            value.highlightIntensity = 0.28
            value.highlightArc = 0.42
            value.gloss = 0.26
            value.depth = 0.22
            value.labelScale = 0.40
            value.shadowOpacity = 0.50

        case .chrome:
            value.discColorSource = .custom
            value.accentSource = .custom
            value.customDiscColor = WidgetColor(red: 0.20, green: 0.22, blue: 0.25)
            value.customAccentColor = WidgetColor(red: 0.92, green: 0.95, blue: 1.0)
            value.grooveCount = 20
            value.grooveOpacity = 0.22
            value.grooveWidth = 0.0035
            value.edgeRingOpacity = 0.74
            value.edgeRingWidth = 0.015
            value.highlightIntensity = 0.78
            value.highlightArc = 0.18
            value.highlightWidth = 0.019
            value.gloss = 0.68
            value.depth = 0.86
            value.shadowOpacity = 0.38
            value.labelBorderOpacity = 0.68
            value.rpm = 7

        case .aurora:
            value.discColorSource = .album
            value.accentSource = .album
            value.labelStyle = .artwork
            value.discOpacity = 0.92
            value.grooveCount = 9
            value.grooveOpacity = 0.18
            value.edgeRingOpacity = 0.48
            value.highlightIntensity = 0.34
            value.highlightArc = 0.48
            value.gloss = 0.22
            value.glowOpacity = 0.72
            value.glowRadius = 0.28
            value.depth = 0.46
            value.rpm = 8.5

        case .translucent:
            value.discColorSource = .custom
            value.accentSource = .custom
            value.customDiscColor = WidgetColor(red: 0.16, green: 0.24, blue: 0.30)
            value.customAccentColor = WidgetColor(red: 0.62, green: 0.93, blue: 0.96)
            value.discOpacity = 0.58
            value.grooveCount = 14
            value.grooveOpacity = 0.12
            value.grooveWidth = 0.004
            value.edgeRingOpacity = 0.38
            value.highlightIntensity = 0.32
            value.gloss = 0.22
            value.depth = 0.10
            value.labelScale = 0.38
            value.shadowOpacity = 0.26
            value.glowOpacity = 0.18
            value.glowRadius = 0.12
            value.rpm = 6.5

        case .custom:
            break
        }
        return value
    }

'''
surface = surface[:start] + vinyl_made + surface[end:]

old_window = '''        window.title = "Halo · Vinyl Studio"\n        window.contentViewController = controller\n        window.isReleasedWhenClosed = false\n        window.minSize = CGSize(width: 520, height: 620)\n        window.center()'''
new_window = '''        window.title = "Halo · Vinyl Studio"\n        window.titleVisibility = .visible\n        window.titlebarAppearsTransparent = false\n        window.contentViewController = controller\n        window.isReleasedWhenClosed = false\n        window.minSize = CGSize(width: 520, height: 620)\n        window.standardWindowButton(.closeButton)?.isHidden = false\n        window.standardWindowButton(.closeButton)?.isEnabled = true\n        window.center()'''
if old_window not in surface:
    raise SystemExit('Vinyl window anchor not found')
surface = surface.replace(old_window, new_window, 1)

controller_end = '''        window.makeKeyAndOrderFront(nil)\n    }\n}\n\nstruct VinylRecordView'''
controller_replacement = '''        window.makeKeyAndOrderFront(nil)\n    }\n\n    func close() {\n        window?.performClose(nil)\n    }\n}\n\nstruct VinylRecordView'''
if controller_end not in surface:
    raise SystemExit('Vinyl controller end anchor not found')
surface = surface.replace(controller_end, controller_replacement, 1)

view_start = '''    var body: some View {\n        ScrollView {\n            VStack(alignment: .leading, spacing: 16) {'''
view_replacement = '''    var body: some View {\n        VStack(spacing: 0) {\n            HStack(spacing: 10) {\n                Label("Vinyl Studio", systemImage: "opticaldisc")\n                    .font(.headline)\n                Text(options.preset.rawValue)\n                    .font(.caption.weight(.semibold))\n                    .foregroundStyle(.secondary)\n                    .padding(.horizontal, 8)\n                    .padding(.vertical, 4)\n                    .background(.quaternary, in: Capsule())\n                Spacer()\n                Button("Reset") { store.reset() }\n                    .buttonStyle(.borderless)\n                Button { VinylStyleWindowController.shared.close() } label: {\n                    Label("Close", systemImage: "xmark")\n                }\n                .keyboardShortcut(.cancelAction)\n            }\n            .padding(.horizontal, 16)\n            .padding(.vertical, 11)\n            .background(Color(nsColor: .windowBackgroundColor))\n            Divider()\n\n            ScrollView {\n                VStack(alignment: .leading, spacing: 16) {'''
if view_start not in surface:
    raise SystemExit('Vinyl settings body anchor not found')
surface = surface.replace(view_start, view_replacement, 1)

surface = surface.replace('''                        Text("Vinyl Studio").font(.title.bold())''', '''                        Text("Live Record Preview").font(.title2.bold())''', 1)

view_end = '''            .padding(20)\n        }\n        .frame(minWidth: 500, minHeight: 600)\n    }\n\n    private func binding'''
view_end_replacement = '''                .padding(20)\n            }\n        }\n        .frame(minWidth: 500, minHeight: 600)\n    }\n\n    private func binding'''
if view_end not in surface:
    raise SystemExit('Vinyl settings end anchor not found')
surface = surface.replace(view_end, view_end_replacement, 1)

surface_path.write_text(surface)
print('Polished Workspace presets and Vinyl Studio.')
