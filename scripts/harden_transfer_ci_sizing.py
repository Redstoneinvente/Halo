from pathlib import Path

surface_path = Path('Halo/Views/SurfaceView.swift')
window_path = Path('Halo/NotchEngine/WindowManager.swift')

surface = surface_path.read_text()
window = window_path.read_text()

# 1. Add one authoritative sizing model for Transfer CI.
marker = 'private struct TransferContextView: View {'
if 'private enum TransferCISizing {' not in surface:
    helper = r'''private enum TransferCISizing {
    private static func bool(_ key: String, fallback: Bool, defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
    }

    private static func string(_ key: String, fallback: String, defaults: UserDefaults = .standard) -> String {
        defaults.string(forKey: key) ?? fallback
    }

    private static func number(_ key: String, fallback: Double, defaults: UserDefaults = .standard) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }

    static func minimumExpandedWidth(physicalNotchWidth: CGFloat) -> CGFloat {
        max(220, physicalNotchWidth > 0 ? physicalNotchWidth + 28 : 220)
    }

    static func openPreferredSize(defaults: UserDefaults = .standard) -> CGSize {
        let openStyle = string("HaloContextTransferOpenStyle", fallback: "Dashboard", defaults: defaults)
        let compact = bool("HaloContextTransferCompact", fallback: false, defaults: defaults)
        let showDirection = bool("HaloContextTransferShowDirection", fallback: true, defaults: defaults)
        let showDownload = bool("HaloContextTransferShowDownload", fallback: true, defaults: defaults)
        let showUpload = bool("HaloContextTransferShowUpload", fallback: true, defaults: defaults)
        let showPeak = bool("HaloContextTransferShowPeak", fallback: true, defaults: defaults)
        let showSession = bool("HaloContextTransferShowSession", fallback: true, defaults: defaults)
        let showElapsed = bool("HaloContextTransferShowElapsed", fallback: true, defaults: defaults)
        let showGraph = bool("HaloContextTransferShowGraph", fallback: true, defaults: defaults)
        let indicatorStyle = string("HaloContextTransferIndicatorStyle", fallback: "Edge Bar", defaults: defaults)
        let indicatorShowSpeed = bool("HaloContextTransferIndicatorShowSpeed", fallback: true, defaults: defaults)
        let indicatorThickness = number("HaloContextTransferIndicatorThickness", fallback: 3, defaults: defaults)

        let primaryStats = (showDownload ? 1 : 0) + (showUpload ? 1 : 0)

        switch openStyle {
        case "Indicator":
            let baseWidth: Double
            switch indicatorStyle {
            case "Minimal": baseWidth = indicatorShowSpeed ? 270 : 230
            case "Center Pulse": baseWidth = indicatorShowSpeed ? 360 : 290
            case "Dual Rails": baseWidth = indicatorShowSpeed ? 390 : 315
            default: baseWidth = indicatorShowSpeed ? 350 : 285
            }
            let hasMeta = showDirection || showElapsed
            let extraThickness = max(0, indicatorThickness - 3)
            return CGSize(width: baseWidth, height: max(96, 70 + (hasMeta ? 26 : 8) + extraThickness))

        case "Minimal":
            var width = 205.0
            if showDirection { width += 105 }
            width += Double(primaryStats) * 105
            if showElapsed { width += 62 }
            return CGSize(width: min(600, max(260, width)), height: 96)

        default:
            let peakStats = (!compact && showPeak) ? 2 : 0
            let stats = primaryStats + peakStats
            var width = compact ? 300.0 : 330.0
            if stats > 0 { width += Double(stats) * (compact ? 76 : 88) }
            if !showDirection && !showElapsed && stats == 0 { width = 280 }
            width = min(720, max(280, width))

            var height = compact ? 78.0 : 86.0
            if stats > 0 { height += compact ? 58 : 66 }
            if showGraph && !compact { height += 70 }
            if showSession && !compact { height += 34 }
            return CGSize(width: width, height: min(300, max(96, height)))
        }
    }

    static func closedPreferredWidth(physicalNotchWidth: CGFloat, defaults: UserDefaults = .standard) -> CGFloat {
        let closedStyle = string("HaloContextTransferClosedStyle", fallback: "Stats", defaults: defaults)
        let showDirection = bool("HaloContextTransferShowDirection", fallback: true, defaults: defaults)
        let showDownload = bool("HaloContextTransferShowDownload", fallback: true, defaults: defaults)
        let showUpload = bool("HaloContextTransferShowUpload", fallback: true, defaults: defaults)
        let indicatorStyle = string("HaloContextTransferIndicatorStyle", fallback: "Edge Bar", defaults: defaults)
        let indicatorShowSpeed = bool("HaloContextTransferIndicatorShowSpeed", fallback: true, defaults: defaults)

        let contentWidth: CGFloat
        switch closedStyle {
        case "Indicator":
            switch indicatorStyle {
            case "Minimal": contentWidth = indicatorShowSpeed ? 165 : 110
            case "Center Pulse": contentWidth = indicatorShowSpeed ? 245 : 180
            case "Dual Rails": contentWidth = indicatorShowSpeed ? 255 : 195
            default: contentWidth = indicatorShowSpeed ? 235 : 175
            }
        case "Minimal":
            contentWidth = 165
        default:
            var width: CGFloat = 48
            if showDirection { width += 88 }
            if showDownload { width += 96 }
            if showUpload { width += 96 }
            contentWidth = width
        }

        // The physical camera/notch is a hard lower bound on real notched Macs.
        let physicalFloor = physicalNotchWidth > 0 ? physicalNotchWidth + 16 : 110
        return min(520, max(physicalFloor, contentWidth))
    }
}

'''
    surface = surface.replace(marker, helper + marker, 1)

# 2. Use the authoritative sizing model and ensure indicator customizations affect size.
old = '''    private var visibleStatCount: Int {
        (showDownload ? 1 : 0) + (showUpload ? 1 : 0) + ((!compact && showPeak) ? 2 : 0)
    }
    private var preferredSize: CGSize {
        switch openStyle {
        case "Indicator":
            return CGSize(width: 360, height: showElapsed ? 96 : 82)
        case "Minimal":
            let width = 300 + Double(max(0, min(2, visibleStatCount))) * 75
            return CGSize(width: width, height: showDirection || showElapsed ? 112 : 92)
        default:
            let statColumns = max(1, min(4, visibleStatCount))
            let width = compact ? (300 + Double(statColumns) * 72) : (360 + Double(statColumns) * 72)
            var height = compact ? 112.0 : 128.0
            if showGraph && !compact { height += 70 }
            if showSession && !compact { height += 34 }
            return CGSize(width: min(680, max(340, width)), height: min(280, height))
        }
    }
    private var sizingSignature: String {
        [openStyle, compact.description, showDirection.description, showDownload.description,
         showUpload.description, showPeak.description, showSession.description,
         showElapsed.description, showGraph.description].joined(separator: "|")
    }
'''
new = '''    @AppStorage("HaloContextTransferIndicatorStyle") private var indicatorStyle = "Edge Bar"
    @AppStorage("HaloContextTransferIndicatorShowSpeed") private var indicatorShowSpeed = true
    @AppStorage("HaloContextTransferIndicatorThickness") private var indicatorThickness = 3.0

    private var primaryStatCount: Int { (showDownload ? 1 : 0) + (showUpload ? 1 : 0) }
    private var dashboardStatCount: Int { primaryStatCount + ((!compact && showPeak) ? 2 : 0) }
    private var preferredSize: CGSize { TransferCISizing.openPreferredSize() }
    private var sizingSignature: String {
        [openStyle, compact.description, showDirection.description, showDownload.description,
         showUpload.description, showPeak.description, showSession.description,
         showElapsed.description, showGraph.description, indicatorStyle,
         indicatorShowSpeed.description, String(format: "%.2f", indicatorThickness)].joined(separator: "|")
    }
'''
if old not in surface:
    raise SystemExit('TransferContextView sizing block not found')
surface = surface.replace(old, new, 1)
surface = surface.replace('if visibleStatCount > 0 {', 'if dashboardStatCount > 0 {', 1)

old = '''        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { updatePreferredSize() }
        .onChange(of: sizingSignature) { _ in updatePreferredSize() }
    }

    private func updatePreferredSize() {
        surfaceState.contextPreferredSize = preferredSize
    }
'''
new = '''        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { updateSizing() }
        .onChange(of: sizingSignature) { _ in updateSizing() }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in updateSizing() }
    }

    private func updateSizing() {
        surfaceState.contextMinimumExpandedWidth = TransferCISizing.minimumExpandedWidth(physicalNotchWidth: surfaceState.physicalNotchWidth)
        surfaceState.contextPreferredSize = preferredSize
        surfaceState.contextPreferredCompactWidth = TransferCISizing.closedPreferredWidth(physicalNotchWidth: surfaceState.physicalNotchWidth)
    }
'''
if old not in surface:
    raise SystemExit('TransferContextView update block not found')
surface = surface.replace(old, new, 1)

# 3. Closed Transfer CI actively requests a content-safe closed width and primes the next opened size.
old = '''private struct TransferClosedContextView: View {
    @ObservedObject var monitor: TransferActivityMonitor
    @AppStorage("HaloContextTransferClosedStyle") private var closedStyle = "Stats"
    @AppStorage("HaloContextTransferShowDirection") private var showDirection = true
    @AppStorage("HaloContextTransferShowDownload") private var showDownload = true
    @AppStorage("HaloContextTransferShowUpload") private var showUpload = true

    var body: some View {
'''
new = '''private struct TransferClosedContextView: View {
    @ObservedObject var monitor: TransferActivityMonitor
    @ObservedObject var surfaceState: SurfaceState
    @AppStorage("HaloContextTransferClosedStyle") private var closedStyle = "Stats"
    @AppStorage("HaloContextTransferShowDirection") private var showDirection = true
    @AppStorage("HaloContextTransferShowDownload") private var showDownload = true
    @AppStorage("HaloContextTransferShowUpload") private var showUpload = true
    @AppStorage("HaloContextTransferIndicatorStyle") private var indicatorStyle = "Edge Bar"
    @AppStorage("HaloContextTransferIndicatorShowSpeed") private var indicatorShowSpeed = true

    private var sizingSignature: String {
        [closedStyle, showDirection.description, showDownload.description, showUpload.description,
         indicatorStyle, indicatorShowSpeed.description].joined(separator: "|")
    }

    var body: some View {
'''
if old not in surface:
    raise SystemExit('TransferClosedContextView header not found')
surface = surface.replace(old, new, 1)

old = '''        }
    }

    private var shortDirection: String {
'''
# Replace only the first occurrence after TransferClosedContextView by splitting.
idx = surface.index('private struct TransferClosedContextView: View')
sub = surface[idx:]
pos = sub.index(old)
replacement = '''        }
        .onAppear { updateSizing() }
        .onChange(of: sizingSignature) { _ in updateSizing() }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in updateSizing() }
    }

    private func updateSizing() {
        surfaceState.contextMinimumExpandedWidth = TransferCISizing.minimumExpandedWidth(physicalNotchWidth: surfaceState.physicalNotchWidth)
        surfaceState.contextPreferredCompactWidth = TransferCISizing.closedPreferredWidth(physicalNotchWidth: surfaceState.physicalNotchWidth)
        // Prime the next open target while still closed, so opening goes directly to the
        // correct content-driven size instead of opening large and resizing a frame later.
        if !surfaceState.expanded {
            surfaceState.contextPreferredSize = TransferCISizing.openPreferredSize()
        }
    }

    private var shortDirection: String {
'''
sub = sub[:pos] + sub[pos:].replace(old, replacement, 1)
surface = surface[:idx] + sub

surface = surface.replace('TransferClosedContextView(monitor: transfer)', 'TransferClosedContextView(monitor: transfer, surfaceState: state)', 1)

# 4. Clear Transfer-only geometry when Transfer loses ownership or ends, and fix open visibility consistency.
old = '''        .onReceive(transfer.$isActive.removeDuplicates()) { active in
            if !active {
                state.contextPreferredSize = nil
            }
        }
'''
new = '''        .onReceive(transfer.$isActive.removeDuplicates()) { active in
            if !active {
                state.contextPreferredSize = nil
                state.contextPreferredCompactWidth = nil
                state.contextMinimumExpandedWidth = nil
            }
        }
'''
if old not in surface:
    raise SystemExit('transfer isActive block not found')
surface = surface.replace(old, new, 1)

surface = surface.replace('workspace.setOpenedNotchVisible(expanded && activeContext == nil, token: openVisibilityToken)',
                          'workspace.setOpenedNotchVisible(expanded && (activeContext == nil || transferContextActive), token: openVisibilityToken)', 1)

old = '''        .onChange(of: activeContext) { _ in
            let owns = teleprompterCIEnabled && teleprompterActive && activeContext == .teleprompter
            NotificationCenter.default.post(name: .init("HaloTeleprompterCIOwnershipChanged"), object: nil, userInfo: ["owns": owns])
            if owns {
                state.collapseTask?.cancel()
                if !state.pinned { state.expanded = false }
            }
            workspace.setOpenedNotchVisible(state.expanded && (activeContext == nil || transferContextActive), token: openVisibilityToken)
        }
'''
new = '''        .onChange(of: activeContext) { _ in
            let owns = teleprompterCIEnabled && teleprompterActive && activeContext == .teleprompter
            NotificationCenter.default.post(name: .init("HaloTeleprompterCIOwnershipChanged"), object: nil, userInfo: ["owns": owns])
            if owns {
                state.collapseTask?.cancel()
                if !state.pinned { state.expanded = false }
            }
            if !transferContextActive {
                state.contextPreferredCompactWidth = nil
                state.contextMinimumExpandedWidth = nil
                if activeContext != nil { state.contextPreferredSize = nil }
            }
            workspace.setOpenedNotchVisible(state.expanded && (activeContext == nil || transferContextActive), token: openVisibilityToken)
        }
'''
if old not in surface:
    raise SystemExit('activeContext change block not found')
surface = surface.replace(old, new, 1)

# WindowManager plumbing for Transfer-only adaptive closed width and a lower per-context opened minimum.
window = window.replace('''    @Published var contextPreferredSize: CGSize?\n''', '''    @Published var contextPreferredSize: CGSize?\n    @Published var contextPreferredCompactWidth: CGFloat?\n    @Published var contextMinimumExpandedWidth: CGFloat?\n''', 1)
window = window.replace('''        var contextSizeSubscription: AnyCancellable?\n''', '''        var contextSizeSubscription: AnyCancellable?\n        var contextCompactSizeSubscription: AnyCancellable?\n''', 1)
window = window.replace('''            subscription?.cancel(); contextSizeSubscription?.cancel(); panel.close(); ambientPanel.close()\n''', '''            subscription?.cancel(); contextSizeSubscription?.cancel(); contextCompactSizeSubscription?.cancel(); panel.close(); ambientPanel.close()\n''', 1)

old = '''        let margin: CGFloat = 12
        let minimumHeight: CGFloat = 96
        let maxWidth = max(360, geometry.visible.width - margin * 2)
        let width = min(maxWidth, max(360, requested.width))
'''
new = '''        let margin: CGFloat = 12
        let minimumHeight: CGFloat = 96
        let requestedMinimum = host.state.contextMinimumExpandedWidth ?? 360
        let physicalMinimum = geometry.attachedToNotch && geometry.physicalNotchWidth > 0
            ? geometry.physicalNotchWidth + 24 : 160
        let minimumWidth = max(160, max(requestedMinimum, physicalMinimum))
        let maxWidth = max(minimumWidth, geometry.visible.width - margin * 2)
        let width = min(maxWidth, max(minimumWidth, requested.width))
'''
if old not in window:
    raise SystemExit('adjustedExpandedFrame width block not found')
window = window.replace(old, new, 1)

old = '''    private func targetFrame(host: Host, expanded: Bool) -> CGRect {
        guard let geometry = host.geometry else { return .zero }
        return expanded ? adjustedExpandedFrame(host: host, requested: host.state.contextPreferredSize) : geometry.frame(expanded: false)
    }
'''
new = '''    private func adjustedClosedFrame(host: Host, requestedWidth: CGFloat?) -> CGRect {
        guard let geometry = host.geometry else { return .zero }
        let base = geometry.frame(expanded: false)
        guard let requestedWidth, requestedWidth.isFinite else { return base }

        let margin: CGFloat = 8
        let physicalFloor = geometry.attachedToNotch && geometry.physicalNotchWidth > 0
            ? geometry.physicalNotchWidth + 16 : 64
        let maximum = max(physicalFloor, geometry.visible.width - margin * 2)
        let width = min(maximum, max(physicalFloor, requestedWidth))
        var frame = CGRect(x: base.midX - width / 2, y: base.minY, width: width, height: base.height)
        if frame.minX < geometry.visible.minX + margin { frame.origin.x = geometry.visible.minX + margin }
        if frame.maxX > geometry.visible.maxX - margin { frame.origin.x = geometry.visible.maxX - margin - width }
        return frame
    }

    private func targetFrame(host: Host, expanded: Bool) -> CGRect {
        guard host.geometry != nil else { return .zero }
        return expanded
            ? adjustedExpandedFrame(host: host, requested: host.state.contextPreferredSize)
            : adjustedClosedFrame(host: host, requestedWidth: host.state.contextPreferredCompactWidth)
    }
'''
if old not in window:
    raise SystemExit('targetFrame block not found')
window = window.replace(old, new, 1)

# Install a live closed-size subscriber next to the existing opened context-size subscriber.
needle = '''                host.contextSizeSubscription = host.state.$contextPreferredSize.dropFirst().removeDuplicates(by: { lhs, rhs in
'''
pos = window.find(needle)
if pos == -1:
    raise SystemExit('contextSizeSubscription not found')
# Find the end of that sink by anchoring on panel orderFront which follows host setup.
anchor = '''                host.panel.orderFrontRegardless()'''
end = window.find(anchor, pos)
if end == -1:
    raise SystemExit('host panel orderFront anchor not found')
insert = r'''                host.contextCompactSizeSubscription = host.state.$contextPreferredCompactWidth.dropFirst().removeDuplicates(by: { lhs, rhs in
                    switch (lhs, rhs) {
                    case (nil, nil): return true
                    case let (a?, b?): return abs(a - b) < 1
                    default: return false
                    }
                }).receive(on: DispatchQueue.main).sink { [weak self, weak host] _ in
                    guard let self, let host, let geometry = host.geometry, !host.state.expanded else { return }
                    let target = self.targetFrame(host: host, expanded: false)
                    guard host.targetFrame != target else { return }
                    host.targetFrame = target
                    var motion = geometry.appearance.surface
                    motion.opening = .resize
                    motion.closing = .resize
                    motion.duration = min(0.30, max(0.14, motion.duration))
                    host.animator.move(panel: host.panel, state: host.state, target: target, options: motion,
                                       preset: .smooth,
                                       animations: host.state.theme.animations && !host.state.editingGeometry,
                                       opening: true, style: geometry.style, liveViewportResize: true,
                                       synchronizeClosedGeometry: true,
                                       closedCameraFrame: self.physicalCameraFrame(for: geometry))
                }
'''
window = window[:end] + insert + window[end:]

surface_path.write_text(surface)
window_path.write_text(window)
print('Hardened Transfer CI customization wiring and adaptive sizing.')
