from pathlib import Path

surface_path = Path('Halo/Views/SurfaceView.swift')
closed_path = Path('Halo/Views/ClosedNotchView.swift')

surface = surface_path.read_text()
closed = closed_path.read_text()

# -----------------------------------------------------------------------------
# SurfaceView: preserve the *closed-notch visualizer* while Music CI is expanded.
# Do not preserve all closed-notch widgets unless the existing user option asks for it.
# -----------------------------------------------------------------------------
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
insert = anchor + '''    private var hasClosedNotchVisualizer: Bool {
        let closed = layout.closedNotch ?? ClosedNotchOptions()
        return closed.left == .visualizer || closed.right == .visualizer
    }
    /// Music CI is special: the visualizer belongs to the physical closed-notch strip and
    /// should survive the transition even when the rest of the closed widgets are hidden.
    private var preservesMusicClosedVisualizer: Bool {
        state.expanded && contextMusicActive && hasClosedNotchVisualizer && workspace.media.hasNowPlayingPresentation
    }
    private var preservesClosedStripWhileExpanded: Bool {
        keepsClosedContentsWhileExpanded || preservesMusicClosedVisualizer
    }
'''
if 'private var preservesMusicClosedVisualizer: Bool' not in surface:
    if anchor not in surface:
        raise SystemExit('SurfaceView keepsClosedContents contract changed')
    surface = surface.replace(anchor, insert, 1)

old_branch = '''                      } else if keepsClosedContentsWhileExpanded {
                        ClosedNotchView(store: store, workspace: workspace, layout: layout, occlusion: state.closedOcclusion, referenceWidth: state.compactWidth)
                      } else { HStack {
'''
new_branch = '''                      } else if keepsClosedContentsWhileExpanded {
                        ClosedNotchView(store: store, workspace: workspace, layout: layout, occlusion: state.closedOcclusion, referenceWidth: state.compactWidth)
                      } else if preservesMusicClosedVisualizer {
                        // Keep only the visualizer from the closed notch alive above Music CI.
                        // It receives the live expanded width, so it grows with the notch instead
                        // of being removed and then appearing to slide underneath the CI.
                        ClosedNotchView(store: store, workspace: workspace, layout: layout,
                                        occlusion: state.closedOcclusion, referenceWidth: state.compactWidth,
                                        visualizerOnly: true, expandVisualizerToAvailableWidth: true)
                      } else { HStack {
'''
if old_branch in surface:
    surface = surface.replace(old_branch, new_branch, 1)
elif new_branch not in surface:
    raise SystemExit('SurfaceView expanded strip branch changed')

old_padding = '.padding(.horizontal, (!state.expanded || keepsClosedContentsWhileExpanded) ? 0 : max(16, layout.appearance.surface.shoulder + 8))'
new_padding = '.padding(.horizontal, (!state.expanded || preservesClosedStripWhileExpanded) ? 0 : max(16, layout.appearance.surface.shoulder + 8))'
if old_padding in surface:
    surface = surface.replace(old_padding, new_padding, 1)
elif new_padding not in surface:
    raise SystemExit('SurfaceView strip padding contract changed')

old_full_overlay = '''                if keepsClosedContentsWhileExpanded {
                    ClosedNotchView(store: store, workspace: workspace, layout: layout,
                                    occlusion: state.closedOcclusion, referenceWidth: state.compactWidth)
                        .frame(height: max(40, state.compactHeight))
                        .zIndex(3)
                }
'''
new_full_overlay = '''                if keepsClosedContentsWhileExpanded {
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
# There is one full-surface overlay. Replace only the occurrence after contextOwnsFullSurface.
full_pos = surface.find('            if contextOwnsFullSurface {')
if full_pos < 0:
    raise SystemExit('contextOwnsFullSurface block missing')
sub = surface[full_pos:]
if old_full_overlay in sub:
    sub = sub.replace(old_full_overlay, new_full_overlay, 1)
    surface = surface[:full_pos] + sub
elif new_full_overlay not in sub:
    raise SystemExit('full-surface closed strip overlay changed')

# Tell ContextMusicView that the full-surface layout must reserve the visualizer strip.
call_old = 'visualizer: layout.closedNotch?.visualizer ?? VisualizerOptions(), surfaceState: state)'
call_new = '''visualizer: layout.closedNotch?.visualizer ?? VisualizerOptions(), surfaceState: state,
                                             preserveClosedVisualizerStrip: preservesMusicClosedVisualizer)'''
count = surface.count(call_old)
if count:
    if count != 3:
        raise SystemExit(f'expected 3 ContextMusicView calls, found {count}')
    surface = surface.replace(call_old, call_new)
elif surface.count('preserveClosedVisualizerStrip: preservesMusicClosedVisualizer)') != 3:
    raise SystemExit('ContextMusicView call contract changed')

music_decl_old = '''    let visualizer: VisualizerOptions
    @ObservedObject var surfaceState: SurfaceState
'''
music_decl_new = '''    let visualizer: VisualizerOptions
    @ObservedObject var surfaceState: SurfaceState
    let preserveClosedVisualizerStrip: Bool
'''
if music_decl_old in surface:
    surface = surface.replace(music_decl_old, music_decl_new, 1)
elif music_decl_new not in surface:
    raise SystemExit('ContextMusicView declaration changed')

surface = surface.replace(
    '} else if keepsClosedNotchContents {\n            base = max(16, surfaceState.compactHeight + max(6, options.resolvedSpacing * 0.5))',
    '} else if keepsClosedNotchContents || preserveClosedVisualizerStrip {\n            base = max(16, surfaceState.compactHeight + max(6, options.resolvedSpacing * 0.5))',
    1,
)
surface = surface.replace(
    'let base = usesFullNotchArea && keepsClosedNotchContents\n            ? max(12, surfaceState.compactHeight + 6)',
    'let base = usesFullNotchArea && (keepsClosedNotchContents || preserveClosedVisualizerStrip)\n            ? max(12, surfaceState.compactHeight + 6)',
    1,
)
old_sizing_tail = 'String(usesFullNotchArea), String(keepsClosedNotchContents)].joined(separator: "|")'
new_sizing_tail = 'String(usesFullNotchArea), String(keepsClosedNotchContents), String(preserveClosedVisualizerStrip)].joined(separator: "|")'
if old_sizing_tail in surface:
    surface = surface.replace(old_sizing_tail, new_sizing_tail, 1)
elif new_sizing_tail not in surface:
    raise SystemExit('ContextMusicView sizing key changed')

# -----------------------------------------------------------------------------
# ClosedNotchView: visualizer-only render mode used only by the Music CI overlay.
# It deliberately suppresses artwork/decorations/HUD/power so only the configured closed
# visualizer remains, and gives that visualizer the actual live side width.
# -----------------------------------------------------------------------------
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
    raise SystemExit('ClosedNotchView property contract changed')

vertical_old = '''    private var verticalHUD: HaloHUDNotchPresentation? {
        guard let hud = activeHUD,
'''
vertical_new = '''    private var verticalHUD: HaloHUDNotchPresentation? {
        guard !visualizerOnly, let hud = activeHUD,
'''
if vertical_old in closed:
    closed = closed.replace(vertical_old, vertical_new, 1)
elif vertical_new not in closed:
    raise SystemExit('ClosedNotchView vertical HUD contract changed')

resolved_old = '''    private var resolvedItems: (left: ClosedNotchItem, right: ClosedNotchItem) {
        var left = options.left
        var right = options.right
'''
resolved_new = '''    private var resolvedItems: (left: ClosedNotchItem, right: ClosedNotchItem) {
        if visualizerOnly {
            return (options.left == .visualizer ? .visualizer : .none,
                    options.right == .visualizer ? .visualizer : .none)
        }
        var left = options.left
        var right = options.right
'''
if resolved_old in closed:
    closed = closed.replace(resolved_old, resolved_new, 1)
elif resolved_new not in closed:
    raise SystemExit('ClosedNotchView resolvedItems contract changed')

hud_old = '''    private func hud(for side: ClosedNotchSide) -> HaloHUDNotchPresentation? {
        guard let hud = activeHUD else { return nil }
'''
hud_new = '''    private func hud(for side: ClosedNotchSide) -> HaloHUDNotchPresentation? {
        guard !visualizerOnly, let hud = activeHUD else { return nil }
'''
if hud_old in closed:
    closed = closed.replace(hud_old, hud_new, 1)
elif hud_new not in closed:
    raise SystemExit('ClosedNotchView HUD contract changed')

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
    raise SystemExit('ClosedNotchView slot contract changed')

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
    raise SystemExit('ClosedNotchSlot property contract changed')

closed = closed.replace(
    'guard media.hasNowPlayingPresentation, artwork.enabled, artwork.mode != .none, artwork.mode != .background else { return nil }',
    'guard !visualizerOnly, media.hasNowPlayingPresentation, artwork.enabled, artwork.mode != .none, artwork.mode != .background else { return nil }',
    1,
)
closed = closed.replace(
    '        guard powerEvent != nil else { return nil }\n        let settings = options.powerReaction ?? PowerReactionOptions()',
    '        guard !visualizerOnly, powerEvent != nil else { return nil }\n        let settings = options.powerReaction ?? PowerReactionOptions()',
    1,
)
# powerEvent itself must also be suppressed before it can influence padding/width.
power_event_old = '''    private var powerEvent: PowerEventInfo? {
        let settings = options.powerReaction ?? PowerReactionOptions()
'''
power_event_new = '''    private var powerEvent: PowerEventInfo? {
        guard !visualizerOnly else { return nil }
        let settings = options.powerReaction ?? PowerReactionOptions()
'''
if power_event_old in closed:
    closed = closed.replace(power_event_old, power_event_new, 1)
elif power_event_new not in closed:
    raise SystemExit('ClosedNotchSlot power event contract changed')

decoration_old = '''    private var decorationSize: Double {
        guard let decoration, decoration.isVisible(playing: media.isPlaying) else { return 0 }
'''
decoration_new = '''    private var decorationSize: Double {
        guard !visualizerOnly, let decoration, decoration.isVisible(playing: media.isPlaying) else { return 0 }
'''
if decoration_old in closed:
    closed = closed.replace(decoration_old, decoration_new, 1)
elif decoration_new not in closed:
    raise SystemExit('ClosedNotchSlot decoration contract changed')

viz_options_old = '''    private var visualizerOptions: VisualizerOptions {
        var v = options.visualizer ?? VisualizerOptions()
        v.height = min(v.height, innerHeight)
        return v
    }
'''
viz_options_new = '''    private var visualizerOptions: VisualizerOptions {
        var v = options.visualizer ?? VisualizerOptions()
        if expandVisualizerToAvailableWidth { v.width = max(1, innerWidth) }
        v.height = min(v.height, innerHeight)
        return v
    }
'''
if viz_options_old in closed:
    closed = closed.replace(viz_options_old, viz_options_new, 1)
elif viz_options_new not in closed:
    raise SystemExit('ClosedNotchSlot visualizer options contract changed')

viz_case_old = '''        case .visualizer:
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
viz_case_new = '''        case .visualizer:
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
if viz_case_old in closed:
    closed = closed.replace(viz_case_old, viz_case_new, 1)
elif viz_case_new not in closed:
    raise SystemExit('Closed visualizer case changed')

surface_path.write_text(surface)
closed_path.write_text(closed)
print('Preserved closed-notch visualizer through Music CI expansion and bound it to live available width')
