from pathlib import Path

surface_path = Path('Halo/Views/SurfaceView.swift')
closed_path = Path('Halo/Views/ClosedNotchView.swift')
surface = surface_path.read_text()
closed = closed_path.read_text()

# 1) Surface ownership: during Music CI expansion, retain only the closed-notch visualizer.
anchor = '''    private var keepsClosedContentsWhileExpanded: Bool {
        switch activeContext {
        case .drop: return dropKeepsClosedContents
        case .music: return contextMusicKeepsClosedContents
        case .bluetooth: return bluetoothKeepsClosedContents
        case .retro: return retroKeepsClosedContents
        case .teleprompter: return false
        case .transfer: return false
        case .clipboard: return false
        case .custom: return false
        case .none:
            // The two opened-layout systems are mutually exclusive. The Default
            // layout is the only system allowed to keep its closed-notch strip.
            return usesDefaultWorkspace && keepClosedContentsWhenOpen
        }
    }
'''
addition = anchor + '''    private var hasClosedNotchVisualizer: Bool {
        let closed = layout.closedNotch ?? ClosedNotchOptions()
        return closed.left == .visualizer || closed.right == .visualizer
    }
    /// The closed visualizer is part of the notch strip, not the expanded Music CI body.
    /// Keep only that element alive while Music CI opens even when the general
    /// "keep closed contents" option is disabled.
    private var preservesMusicClosedVisualizer: Bool {
        state.expanded && contextMusicActive && hasClosedNotchVisualizer && workspace.media.hasNowPlayingPresentation
    }
    private var preservesClosedStripWhileExpanded: Bool {
        keepsClosedContentsWhileExpanded || preservesMusicClosedVisualizer
    }
'''
if 'private var preservesMusicClosedVisualizer: Bool' not in surface:
    if anchor not in surface:
        raise SystemExit('keepsClosedContentsWhileExpanded anchor missing')
    surface = surface.replace(anchor, addition, 1)

branch_old = '''                      } else if keepsClosedContentsWhileExpanded {
                        ClosedNotchView(store: store, workspace: workspace, layout: layout, occlusion: state.closedOcclusion, referenceWidth: state.compactWidth)
                      } else { HStack {
'''
branch_new = '''                      } else if keepsClosedContentsWhileExpanded {
                        ClosedNotchView(store: store, workspace: workspace, layout: layout, occlusion: state.closedOcclusion, referenceWidth: state.compactWidth)
                      } else if preservesMusicClosedVisualizer {
                        ClosedNotchView(store: store, workspace: workspace, layout: layout,
                                        occlusion: state.closedOcclusion, referenceWidth: state.compactWidth,
                                        visualizerOnly: true, expandVisualizerToAvailableWidth: true)
                      } else { HStack {
'''
if branch_old in surface:
    surface = surface.replace(branch_old, branch_new, 1)
elif branch_new not in surface:
    raise SystemExit('expanded strip branch missing')

padding_old = '.padding(.horizontal, (!state.expanded || keepsClosedContentsWhileExpanded) ? 0 : max(16, layout.appearance.surface.shoulder + 8))'
padding_new = '.padding(.horizontal, (!state.expanded || preservesClosedStripWhileExpanded) ? 0 : max(16, layout.appearance.surface.shoulder + 8))'
if padding_old in surface:
    surface = surface.replace(padding_old, padding_new, 1)
elif padding_new not in surface:
    raise SystemExit('expanded strip padding anchor missing')

# Full-notch-area Music CI bypasses the header VStack, so retain the visualizer as a zIndex overlay.
full_pos = surface.find('            if contextOwnsFullSurface {')
if full_pos < 0:
    raise SystemExit('contextOwnsFullSurface block missing')
full = surface[full_pos:]
overlay_old = '''                if keepsClosedContentsWhileExpanded {
                    ClosedNotchView(store: store, workspace: workspace, layout: layout,
                                    occlusion: state.closedOcclusion, referenceWidth: state.compactWidth)
                        .frame(height: max(40, state.compactHeight))
                        .zIndex(3)
                }
'''
overlay_new = '''                if keepsClosedContentsWhileExpanded {
                    ClosedNotchView(store: store, workspace: workspace, layout: layout,
                                    occlusion: state.closedOcclusion, referenceWidth: state.compactWidth)
                        .frame(height: max(40, state.compactHeight))
                        .zIndex(3)
                } else if preservesMusicClosedVisualizer {
                    ClosedNotchView(store: store, workspace: workspace, layout: layout,
                                    occlusion: state.closedOcclusion, referenceWidth: state.compactWidth,
                                    visualizerOnly: true, expandVisualizerToAvailableWidth: true)
                        .frame(height: max(40, state.compactHeight))
                        .zIndex(3)
                }
'''
if overlay_old in full:
    full = full.replace(overlay_old, overlay_new, 1)
    surface = surface[:full_pos] + full
elif overlay_new not in full:
    raise SystemExit('full-surface visualizer overlay anchor missing')

# Context Music must reserve the top strip if it owns the full surface.
call_old = 'visualizer: layout.closedNotch?.visualizer ?? VisualizerOptions(), surfaceState: state)'
call_new = '''visualizer: layout.closedNotch?.visualizer ?? VisualizerOptions(), surfaceState: state,
                                             preserveClosedVisualizerStrip: preservesMusicClosedVisualizer)'''
count = surface.count(call_old)
if count:
    if count != 2:
        raise SystemExit(f'expected 2 ContextMusicView calls, found {count}')
    surface = surface.replace(call_old, call_new)
elif surface.count('preserveClosedVisualizerStrip: preservesMusicClosedVisualizer)') != 2:
    raise SystemExit('ContextMusicView call sites changed')

decl_old = '''    let visualizer: VisualizerOptions
    @ObservedObject var surfaceState: SurfaceState
'''
decl_new = '''    let visualizer: VisualizerOptions
    @ObservedObject var surfaceState: SurfaceState
    let preserveClosedVisualizerStrip: Bool
'''
if decl_old in surface:
    surface = surface.replace(decl_old, decl_new, 1)
elif decl_new not in surface:
    raise SystemExit('ContextMusicView declaration changed')

inset_old = '''        } else if keepsClosedNotchContents {
            base = max(16, surfaceState.compactHeight + max(6, options.resolvedSpacing * 0.5))
'''
inset_new = '''        } else if keepsClosedNotchContents || preserveClosedVisualizerStrip {
            base = max(16, surfaceState.compactHeight + max(6, options.resolvedSpacing * 0.5))
'''
if inset_old in surface:
    surface = surface.replace(inset_old, inset_new, 1)
elif inset_new not in surface:
    raise SystemExit('ContextMusicView content top inset changed')

controls_old = '''        let base = usesFullNotchArea && keepsClosedNotchContents
            ? max(12, surfaceState.compactHeight + 6)
'''
controls_new = '''        let base = usesFullNotchArea && (keepsClosedNotchContents || preserveClosedVisualizerStrip)
            ? max(12, surfaceState.compactHeight + 6)
'''
if controls_old in surface:
    surface = surface.replace(controls_old, controls_new, 1)
elif controls_new not in surface:
    raise SystemExit('ContextMusicView controls top inset changed')

size_old = 'String(usesFullNotchArea), String(keepsClosedNotchContents)].joined(separator: "|")'
size_new = 'String(usesFullNotchArea), String(keepsClosedNotchContents), String(preserveClosedVisualizerStrip)].joined(separator: "|")'
if size_old in surface:
    surface = surface.replace(size_old, size_new, 1)
elif size_new not in surface:
    raise SystemExit('ContextMusicView sizing key changed')

# 2) ClosedNotchView gets a visualizer-only presentation mode.
props_old = '''    let layout: WorkspaceLayout
    let occlusion: CGRect?
    let referenceWidth: CGFloat
    private var options: ClosedNotchOptions { layout.closedNotch ?? ClosedNotchOptions() }
'''
props_new = '''    let layout: WorkspaceLayout
    let occlusion: CGRect?
    let referenceWidth: CGFloat
    var visualizerOnly = false
    var expandVisualizerToAvailableWidth = false
    private var options: ClosedNotchOptions { layout.closedNotch ?? ClosedNotchOptions() }
'''
if props_old in closed:
    closed = closed.replace(props_old, props_new, 1)
elif props_new not in closed:
    raise SystemExit('ClosedNotchView properties changed')

vertical_old = '''    private var verticalHUD: HaloHUDNotchPresentation? {
        guard let hud = activeHUD,
'''
vertical_new = '''    private var verticalHUD: HaloHUDNotchPresentation? {
        guard !visualizerOnly, let hud = activeHUD,
'''
if vertical_old in closed:
    closed = closed.replace(vertical_old, vertical_new, 1)
elif vertical_new not in closed:
    raise SystemExit('verticalHUD changed')

items_old = '''    private var resolvedItems: (left: ClosedNotchItem, right: ClosedNotchItem) {
        var left = options.left
        var right = options.right
'''
items_new = '''    private var resolvedItems: (left: ClosedNotchItem, right: ClosedNotchItem) {
        if visualizerOnly {
            return (options.left == .visualizer ? .visualizer : .none,
                    options.right == .visualizer ? .visualizer : .none)
        }
        var left = options.left
        var right = options.right
'''
if items_old in closed:
    closed = closed.replace(items_old, items_new, 1)
elif items_new not in closed:
    raise SystemExit('resolvedItems changed')

hud_old = '''    private func hud(for side: ClosedNotchSide) -> HaloHUDNotchPresentation? {
        guard let hud = activeHUD else { return nil }
'''
hud_new = '''    private func hud(for side: ClosedNotchSide) -> HaloHUDNotchPresentation? {
        guard !visualizerOnly, let hud = activeHUD else { return nil }
'''
if hud_old in closed:
    closed = closed.replace(hud_old, hud_new, 1)
elif hud_new not in closed:
    raise SystemExit('hud(for:) changed')

slot_old = '''                ClosedNotchSlot(item: item, decoration: decoration, side: side, availableHeight: height, availableWidth: width,
                                options: options, clock: layout.widgetStyle(for: .clock), store: store, workspace: workspace,
                                media: workspace.media, system: workspace.system, activity: activeActivity, hud: hud(for: side))
'''
slot_new = '''                ClosedNotchSlot(item: item, decoration: visualizerOnly ? nil : decoration, side: side,
                                availableHeight: height, availableWidth: width,
                                options: options, clock: layout.widgetStyle(for: .clock), store: store, workspace: workspace,
                                media: workspace.media, system: workspace.system, activity: activeActivity, hud: hud(for: side),
                                visualizerOnly: visualizerOnly,
                                expandVisualizerToAvailableWidth: expandVisualizerToAvailableWidth)
'''
if slot_old in closed:
    closed = closed.replace(slot_old, slot_new, 1)
elif slot_new not in closed:
    raise SystemExit('ClosedNotchSlot call changed')

slot_props_old = '''    let activity: LiveActivity?
    let hud: HaloHUDNotchPresentation?
    private var layoutMetrics: ClosedNotchLayoutMetrics { ClosedNotchLayoutMetrics(options: options, height: availableHeight) }
'''
slot_props_new = '''    let activity: LiveActivity?
    let hud: HaloHUDNotchPresentation?
    var visualizerOnly = false
    var expandVisualizerToAvailableWidth = false
    private var layoutMetrics: ClosedNotchLayoutMetrics { ClosedNotchLayoutMetrics(options: options, height: availableHeight) }
'''
if slot_props_old in closed:
    closed = closed.replace(slot_props_old, slot_props_new, 1)
elif slot_props_new not in closed:
    raise SystemExit('ClosedNotchSlot properties changed')

art_old = 'guard media.hasNowPlayingPresentation, artwork.enabled, artwork.mode != .none, artwork.mode != .background else { return nil }'
art_new = 'guard !visualizerOnly, media.hasNowPlayingPresentation, artwork.enabled, artwork.mode != .none, artwork.mode != .background else { return nil }'
if art_old in closed:
    closed = closed.replace(art_old, art_new, 1)
elif art_new not in closed:
    raise SystemExit('artworkTargetSide changed')

power_old = '''    private var powerEvent: PowerEventInfo? {
        let settings = options.powerReaction ?? PowerReactionOptions()
'''
power_new = '''    private var powerEvent: PowerEventInfo? {
        guard !visualizerOnly else { return nil }
        let settings = options.powerReaction ?? PowerReactionOptions()
'''
if power_old in closed:
    closed = closed.replace(power_old, power_new, 1)
elif power_new not in closed:
    raise SystemExit('powerEvent changed')

deco_old = '''    private var decorationSize: Double {
        guard let decoration, decoration.isVisible(playing: media.isPlaying) else { return 0 }
'''
deco_new = '''    private var decorationSize: Double {
        guard !visualizerOnly, let decoration, decoration.isVisible(playing: media.isPlaying) else { return 0 }
'''
if deco_old in closed:
    closed = closed.replace(deco_old, deco_new, 1)
elif deco_new not in closed:
    raise SystemExit('decorationSize changed')

vizopt_old = '''    private var visualizerOptions: VisualizerOptions {
        var v = options.visualizer ?? VisualizerOptions()
        v.height = min(v.height, innerHeight)
        return v
    }
'''
vizopt_new = '''    private var visualizerOptions: VisualizerOptions {
        var v = options.visualizer ?? VisualizerOptions()
        if expandVisualizerToAvailableWidth { v.width = max(1, innerWidth) }
        v.height = min(v.height, innerHeight)
        return v
    }
'''
if vizopt_old in closed:
    closed = closed.replace(vizopt_old, vizopt_new, 1)
elif vizopt_new not in closed:
    raise SystemExit('visualizerOptions changed')

viz_old = '''        case .visualizer:
            if media.hasNowPlayingPresentation {
                PlaybackVisualizer(
                    kind: options.animation,
                    playing: true,
                    enabled: options.animate && !system.lowPower,
                    options: visualizerOptions,
                    palette: media.artworkColors,
                    fallback: effectiveTextColor
                )
            }
'''
viz_new = '''        case .visualizer:
            if media.hasNowPlayingPresentation {
                if expandVisualizerToAvailableWidth {
                    PlaybackVisualizer(
                        kind: options.animation,
                        playing: true,
                        enabled: options.animate && !system.lowPower,
                        options: visualizerOptions,
                        palette: media.artworkColors,
                        fallback: effectiveTextColor
                    )
                    .frame(width: max(1, innerWidth), height: innerHeight)
                    .layoutPriority(3)
                } else {
                    PlaybackVisualizer(
                        kind: options.animation,
                        playing: true,
                        enabled: options.animate && !system.lowPower,
                        options: visualizerOptions,
                        palette: media.artworkColors,
                        fallback: effectiveTextColor
                    )
                }
            }
'''
if viz_old in closed:
    closed = closed.replace(viz_old, viz_new, 1)
elif viz_new not in closed:
    raise SystemExit('visualizer case changed')

surface_path.write_text(surface)
closed_path.write_text(closed)
print('Applied parent-level closed visualizer retention for Music CI expansion')
