from pathlib import Path

path = Path('Halo/Views/SurfaceView.swift')
s = path.read_text()

# 1) Make TransferContextView represent only the expanded transfer content.
# Remove its own background so the surface background can be replaced at the notch level.
s = s.replace('''        .padding(compact ? 14 : 18)\n        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)\n        .background { transferBackground }\n        .onAppear { surfaceState.contextPreferredSize = CGSize(width: compact ? 430 : 620, height: compact ? 120 : 230) }\n        .onChange(of: compact) { value in surfaceState.contextPreferredSize = CGSize(width: value ? 430 : 620, height: value ? 120 : 230) }\n    }\n\n    @ViewBuilder private var transferBackground: some View {\n        let primary = Color(hue: backgroundPrimaryHue, saturation: backgroundSaturation, brightness: backgroundBrightness)\n        let secondary = Color(hue: backgroundSecondaryHue, saturation: backgroundSaturation, brightness: min(1, backgroundBrightness + 0.12))\n        switch backgroundStyle {\n        case "Black":\n            Color.black.opacity(backgroundOpacity)\n        case "Accent":\n            Color.accentColor.opacity(backgroundOpacity)\n        case "Dynamic":\n            LinearGradient(\n                colors: monitor.direction.contains("Uploading") && !monitor.direction.contains("Downloading")\n                    ? [Color.orange.opacity(backgroundOpacity), primary.opacity(backgroundOpacity)]\n                    : [Color.accentColor.opacity(backgroundOpacity), secondary.opacity(backgroundOpacity)],\n                startPoint: .topLeading,\n                endPoint: .bottomTrailing\n            )\n        case "Glass":\n            ZStack {\n                Rectangle().fill(.ultraThinMaterial)\n                primary.opacity(max(0, min(1, backgroundOpacity * 0.36)))\n            }\n        default:\n            LinearGradient(\n                colors: [primary.opacity(backgroundOpacity), secondary.opacity(backgroundOpacity)],\n                startPoint: .topLeading,\n                endPoint: .bottomTrailing\n            )\n        }\n    }\n''', '''        .padding(compact ? 14 : 18)\n        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)\n        .onAppear { surfaceState.contextPreferredSize = CGSize(width: compact ? 430 : 620, height: compact ? 120 : 230) }\n        .onChange(of: compact) { value in surfaceState.contextPreferredSize = CGSize(width: value ? 430 : 620, height: value ? 120 : 230) }\n    }\n''')

# Insert dedicated compact closed-state content and reusable transfer background.
anchor = 'struct SurfaceViewportView: View {'
if anchor not in s:
    raise SystemExit('SurfaceViewportView anchor missing')
insert = r'''
private struct TransferClosedContextView: View {
    @ObservedObject var monitor: TransferActivityMonitor
    @AppStorage("HaloContextTransferShowDirection") private var showDirection = true
    @AppStorage("HaloContextTransferShowDownload") private var showDownload = true
    @AppStorage("HaloContextTransferShowUpload") private var showUpload = true

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: monitor.direction.contains("Uploading") && !monitor.direction.contains("Downloading") ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            if showDirection {
                Text(shortDirection)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if showDownload {
                Label(speed(monitor.downloadBytesPerSecond), systemImage: "arrow.down")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .lineLimit(1)
            }
            if showUpload {
                Label(speed(monitor.uploadBytesPerSecond), systemImage: "arrow.up")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

'''
s = s.replace(anchor, insert + anchor, 1)

# 2) Transfer must NOT be a full-surface takeover path. It follows normal closed/open notch state.
old = '''    private var contextOwnsFullSurface: Bool {\n        // Transfer CI takes ownership immediately so Halo never flashes the normal notch\n        // while the transfer surface is expanding. Other CIs keep their existing behavior.\n        if activeContext == .transfer { return true }\n        guard state.expanded else { return false }\n        switch activeContext {\n        case .drop: return dropUsesFullNotchArea\n        case .music: return contextMusicUsesFullNotchArea\n        case .bluetooth: return bluetoothUsesFullNotchArea\n        case .retro: return retroUsesFullNotchArea\n        case .teleprompter: return true\n        case .transfer: return true\n        case .none: return false\n        }\n    }'''
new = '''    private var contextOwnsFullSurface: Bool {\n        guard state.expanded else { return false }\n        switch activeContext {\n        case .drop: return dropUsesFullNotchArea\n        case .music: return contextMusicUsesFullNotchArea\n        case .bluetooth: return bluetoothUsesFullNotchArea\n        case .retro: return retroUsesFullNotchArea\n        case .teleprompter: return true\n        case .transfer: return false\n        case .none: return false\n        }\n    }'''
if old not in s:
    raise SystemExit('contextOwnsFullSurface old block missing')
s = s.replace(old, new, 1)

# 3) Closed state: swap normal ClosedNotchView with Transfer closed content.
old = '''                      } else if !state.expanded {\n                        ClosedNotchView(store: store, workspace: workspace, layout: layout, occlusion: state.closedOcclusion, referenceWidth: state.compactWidth)\n                      } else if keepsClosedContentsWhileExpanded {'''
new = '''                      } else if !state.expanded {\n                        if transferContextActive {\n                            TransferClosedContextView(monitor: transfer)\n                        } else {\n                            ClosedNotchView(store: store, workspace: workspace, layout: layout, occlusion: state.closedOcclusion, referenceWidth: state.compactWidth)\n                        }\n                      } else if keepsClosedContentsWhileExpanded {'''
if old not in s:
    raise SystemExit('closed notch branch missing')
s = s.replace(old, new, 1)

# 4) Restore normal notch click handling while Transfer is active.
s = s.replace('guard !teleprompterActive && !transferContextActive else { return }', 'guard !teleprompterActive else { return }', 1)

# 5) Expanded state: Transfer replaces the opened notch contents in-place.
old = '''                if state.expanded {\n                    if dropContextActive {'''
new = '''                if state.expanded {\n                    if transferContextActive {\n                        TransferContextView(monitor: transfer, surfaceState: state)\n                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)\n                            .transition(.opacity.combined(with: .scale(scale: 0.985)))\n                    } else if dropContextActive {'''
if old not in s:
    raise SystemExit('expanded content anchor missing')
s = s.replace(old, new, 1)

# 6) Remove Transfer from full-surface overlay renderer so it cannot duplicate.
s = s.replace('''                    } else if transferContextActive {\n                        TransferContextView(monitor: transfer, surfaceState: state)\n                    } else if contextMusicActive {''', '''                    } else if contextMusicActive {''', 1)

# 7) Transfer activity no longer forces the notch open/closed. It only selects the CI.
old = '''        .onReceive(transfer.$isActive.removeDuplicates()) { active in\n            if active && transferCIEnabled && activeContext == .transfer {\n                state.collapseTask?.cancel()\n                state.expanded = true\n            } else if !active && !state.pinned && activeContext == nil {\n                state.expanded = false\n                state.contextPreferredSize = nil\n            }\n        }'''
new = '''        .onReceive(transfer.$isActive.removeDuplicates()) { active in\n            if !active {\n                state.contextPreferredSize = nil\n            }\n        }'''
if old not in s:
    raise SystemExit('transfer onReceive block missing')
s = s.replace(old, new, 1)

# 8) Restore normal hover behavior while Transfer is active.
old = '''        .onHover { hovering in\n            if teleprompterContextActive {\n                state.collapseTask?.cancel()\n                if !state.pinned { state.expanded = false }\n            } else if transferContextActive {\n                // Transfer CI owns the surface. Ignore normal notch hover expansion/collapse\n                // until the transfer releases ownership.\n                state.collapseTask?.cancel()\n            } else {\n                state.hover(hovering, enabled: store.configuration.hoverToExpand)\n            }\n        }'''
new = '''        .onHover { hovering in\n            if teleprompterContextActive {\n                state.collapseTask?.cancel()\n                if !state.pinned { state.expanded = false }\n            } else {\n                state.hover(hovering, enabled: store.configuration.hoverToExpand)\n            }\n        }'''
if old not in s:
    raise SystemExit('hover block missing')
s = s.replace(old, new, 1)

# 9) Transfer owns styling only: replace normal notch background while selected, in either closed or opened state.
old = '''    @ViewBuilder private var surfaceBackgroundLayer: some View {\n        ZStack {\n            if transferContextActive {\n                // TransferContextView draws its own fully customizable background.\n                Color.clear\n            } else if state.expanded && activeContext == nil && usesVisualWorkspace {'''
new = '''    @ViewBuilder private var surfaceBackgroundLayer: some View {\n        ZStack {\n            if transferContextActive {\n                TransferSurfaceBackground(monitor: transfer)\n            } else if state.expanded && activeContext == nil && usesVisualWorkspace {'''
if old not in s:
    raise SystemExit('surface background transfer branch missing')
s = s.replace(old, new, 1)

# Make opened-notch visibility reflect the notch's actual state even when Transfer CI replaces contents.
s = s.replace('workspace.setOpenedNotchVisible(state.expanded && activeContext == nil, token: openVisibilityToken)', 'workspace.setOpenedNotchVisible(state.expanded && (activeContext == nil || transferContextActive), token: openVisibilityToken)')

path.write_text(s)
print('Transfer CI corrected to follow normal notch state machine')
