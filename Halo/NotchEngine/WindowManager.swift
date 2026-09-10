import AppKit
import SwiftUI
import Combine
import QuartzCore

@MainActor
final class SurfaceViewport: ObservableObject {
    @Published var size = CGSize(width: 190, height: 40)
}

@MainActor
final class SurfaceState: ObservableObject {
    @Published var expanded = false
    @Published var pinned = false {
        didSet { if pinned { collapseTask?.cancel(); expanded = true } }
    }
    let viewport = SurfaceViewport()
    @Published var dashboardWidth: CGFloat = 420
    @Published var compactWidth: CGFloat = 190
    @Published var closedOcclusion: CGRect?
    @Published var compactHeight: CGFloat = 40
    @Published var theme = Theme()
    @Published var layoutOverride: WorkspaceLayout?
    var collapseTask: Task<Void, Never>?
    var editingGeometry = false
    func hover(_ inside: Bool, enabled: Bool) {
        collapseTask?.cancel()
        guard enabled, !editingGeometry else { return }
        if inside { expanded = true }
        else if !pinned {
            collapseTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 450_000_000)
                guard !Task.isCancelled, let self, !self.pinned, !self.editingGeometry else { return }
                self.expanded = false
            }
        }
    }
}

final class HaloPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Uses the current display cadence during transitions, up to 120 Hz.
@MainActor
final class SurfaceAnimator {
    private let clock = DisplayClock()
    func cancel() { clock.stop() }
    func move(panel: HaloPanel, state: SurfaceState, target: CGRect, options: SurfaceOptions,
              preset: AnimationPreset, animations: Bool, opening: Bool, style: SurfaceStyle) {
        cancel()
        let transition = opening ? options.opening : options.closing
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        guard animations, !reduceMotion, preset != .none, transition != .instant else {
            panel.alphaValue = 1; state.viewport.size = target.size; panel.setFrame(target, display: false); return
        }
        let initial = panel.frame
        let initialAlpha = panel.alphaValue
        let start = CACurrentMediaTime()
        let duration = options.duration
        guard let view = panel.contentView else {
            state.viewport.size = target.size; panel.setFrame(target, display: false); return
        }
        clock.start(view: view) { [weak self, weak panel, weak state] timestamp in
            guard let self, let panel, let state else { self?.cancel(); return }
            let t = min(1, max(0, timestamp - start) / max(0.01, duration))
            let p = SurfaceMotion.progress(t, transition: transition, preset: preset, damping: options.damping)
            let width = max(1, initial.width + (target.width - initial.width) * p)
            let height = max(1, initial.height + (target.height - initial.height) * p)
            let centerX = initial.midX + (target.midX - initial.midX) * p
            let top = initial.maxY + (target.maxY - initial.maxY) * p
            var frame = CGRect(x: centerX - width / 2, y: top - height, width: width, height: height)
            if style == .bottom { frame.origin.y = target.minY }
            if style == .left { frame.origin.x = target.minX }
            if style == .right { frame.origin.x = target.maxX - width }
            if transition == .scale {
                let inset = 0.04 * sin(.pi * t)
                frame = frame.insetBy(dx: frame.width * inset, dy: frame.height * inset)
            }
            if transition == .slide { frame.origin.y += (style == .bottom ? -1 : 1) * 18 * sin(.pi * t) }
            panel.alphaValue = transition == .fade ? initialAlpha + (1 - initialAlpha) * t - 0.3 * sin(.pi * t) : 1
            if t >= 1 { frame = target; panel.alphaValue = 1; self.cancel() }
            if state.viewport.size != frame.size { state.viewport.size = frame.size }
            panel.setFrame(frame, display: false)
        }
    }
}

@MainActor
final class WindowManager {
    @MainActor private final class Host {
        let panel: HaloPanel
        let state = SurfaceState()
        let animator = SurfaceAnimator()
        var geometry: SurfaceGeometry?
        var targetFrame: CGRect?
        var subscription: AnyCancellable?
        init() {
            panel = HaloPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = true
            panel.hidesOnDeactivate = false; panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }
        func stop() {
            animator.cancel(); state.collapseTask?.cancel(); subscription?.cancel(); panel.close()
        }
    }

    private enum DynamicSide { case left, right }
    private var activityExpiry: DispatchWorkItem?
    private let store: AppStore
    private var hosts: [String: Host] = [:]
    private var subscriptions = Set<AnyCancellable>()

    static func displayID(_ screen: NSScreen) -> String {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return screen.localizedName }
        return CFUUIDCreateString(nil, uuid) as String
    }
    static func geometry(screen: NSScreen, theme: Theme, appearance: Appearance) -> SurfaceGeometry {
        let width: Double
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea { width = max(0, right.minX - left.maxX) }
        else { width = screen.safeAreaInsets.top > 0 ? 190 : 0 }
        return SurfaceGeometry(screen: screen.frame, visible: screen.visibleFrame, safeAreaTop: screen.safeAreaInsets.top,
                               physicalNotchWidth: width, style: theme.style, appearance: appearance, expandedWidth: theme.width)
    }
    init(store: AppStore) { self.store = store }

    func start() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main).sink { [weak self] _ in self?.reconcile() }.store(in: &subscriptions)
        store.$configuration.dropFirst().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reconcile() }.store(in: &subscriptions)
        store.workspace.$settings.map { [store] settings in
            let layout = settings.profiles.first { $0.id == store.workspace.scheduledProfileID }?.layout ?? settings.layout
            return SurfaceRenderConfiguration(appearance: layout.appearance, displays: settings.displays, closedNotch: layout.closedNotch, clock: layout.widgetStyle(for: .clock))
        }
            .removeDuplicates().dropFirst().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reconcile() }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: .init("HaloGeometryPreview"))
            .receive(on: DispatchQueue.main).sink { [weak self] note in
                let editing = (note.userInfo?["editing"] as? Bool) ?? false
                let expanded = (note.userInfo?["expanded"] as? Bool) ?? false
                let display = note.userInfo?["display"] as? String
                self?.hosts.forEach { id, host in
                    guard display == nil || display == id else { return }
                    host.state.editingGeometry = editing
                    if editing { host.state.collapseTask?.cancel(); host.state.expanded = expanded }
                }
                self?.refreshDynamicWidths()
            }.store(in: &subscriptions)
        store.workspace.$scheduledProfileID.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reconcile() }.store(in: &subscriptions)
        store.workspace.media.$title.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshDynamicWidths() }.store(in: &subscriptions)
        store.workspace.media.$artist.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshDynamicWidths() }.store(in: &subscriptions)
        store.$files.map(\.count).removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshDynamicWidths() }.store(in: &subscriptions)
        store.$pinnedFiles.map { !$0.isEmpty }.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshDynamicWidths() }.store(in: &subscriptions)
        store.workspace.capture.$busy.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshDynamicWidths() }.store(in: &subscriptions)
        store.workspace.media.$isPlaying.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshDynamicWidths() }.store(in: &subscriptions)
        store.workspace.system.$battery.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshDynamicWidths() }.store(in: &subscriptions)
        store.workspace.system.$charging.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshDynamicWidths() }.store(in: &subscriptions)
        store.workspace.system.$onBattery.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshDynamicWidths() }.store(in: &subscriptions)
        store.$deadline.map { $0 != nil }.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshDynamicWidths() }.store(in: &subscriptions)
        store.workspace.$stopwatchStart.map { $0 != nil }.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshDynamicWidths() }.store(in: &subscriptions)
        store.workspace.$activities.receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshDynamicWidths() }.store(in: &subscriptions)
        reconcile()
    }

    private var activeClosedActivity: LiveActivity? {
        store.workspace.activities.first { activity in
            (activity.progress.map { $0 < 1 } ?? false) || activity.created.addingTimeInterval(12) > Date()
        }
    }

    private func resolvedClosedItems(_ options: ClosedNotchOptions) -> (left: ClosedNotchItem, right: ClosedNotchItem) {
        var left = options.left
        var right = options.right
        guard activeClosedActivity != nil, left != .activity, right != .activity else { return (left, right) }
        let playing = store.workspace.media.isPlaying
        let rightAvailable = right == .none || ((right == .media || right == .visualizer) && !playing)
        let leftAvailable = left == .none || ((left == .media || left == .visualizer) && !playing)
        if rightAvailable { right = .activity }
        else if leftAvailable { left = .activity }
        else { right = .activity }
        return (left, right)
    }

    private func sideHasLiveReason(item: ClosedNotchItem, decoration: SideDecoration?) -> Bool {
        if decoration?.visibility == .playing, store.workspace.media.isPlaying { return true }
        switch item {
        case .media, .visualizer: return store.workspace.media.isPlaying
        case .timer: return store.deadline != nil
        case .files: return !store.pinnedFiles.isEmpty
        case .activity: return activeClosedActivity != nil
        default: return false
        }
    }

    private func powerReaction(options: ClosedNotchOptions,
                               items: (left: ClosedNotchItem, right: ClosedNotchItem)) -> (side: DynamicSide, width: Double)? {
        let settings = options.powerReaction ?? PowerReactionOptions()
        guard settings.isEnabled, let battery = store.workspace.system.battery else { return nil }
        let style: PowerReactionStyle
        if battery >= 99 && !store.workspace.system.onBattery { style = settings.charged }
        else if store.workspace.system.charging { style = settings.charging }
        else if store.workspace.system.onBattery && battery <= settings.lowThreshold { style = settings.low }
        else { return nil }
        guard style != .off else { return nil }

        let size = max(10, options.fontSize)
        let estimated: Double
        switch style {
        case .off: estimated = 0
        case .icon: estimated = size + 6
        case .percent: estimated = size * 3.3
        case .iconPercent: estimated = size * 4.4
        case .label: estimated = size * 7.0
        }
        let width = settings.expandForEvent ? max(estimated, settings.eventWidth) : estimated
        let side: DynamicSide
        switch settings.side {
        case .left: side = .left
        case .right: side = .right
        case .automatic:
            let playing = store.workspace.media.isPlaying
            let rightFree = items.right == .none || ((items.right == .media || items.right == .visualizer) && !playing)
            let leftFree = items.left == .none || ((items.left == .media || items.left == .visualizer) && !playing)
            if rightFree { side = .right }
            else if leftFree { side = .left }
            else { side = .right }
        }
        return (side, width)
    }

    private func configureDynamicWidth(_ host: Host) {
        guard let geometry = host.geometry else { return }
        let layout = host.state.layoutOverride ?? store.workspace.effectiveLayout
        let options = layout.closedNotch ?? ClosedNotchOptions()
        let expansion = options.expansion ?? ClosedExpansionOptions()
        let items = resolvedClosedItems(options)
        let power = powerReaction(options: options, items: items)
        let sides = fittedClosedSides(host: host, layout: layout, items: items, power: power)
        var leftLive = sideHasLiveReason(item: items.left, decoration: options.leftDecoration)
        var rightLive = sideHasLiveReason(item: items.right, decoration: options.rightDecoration)
        if power?.side == .left { leftLive = true }
        if power?.side == .right { rightLive = true }

        let attached = geometry.attachedToNotch && geometry.physicalNotchWidth > 0
        let camera = attached ? geometry.physicalNotchWidth : 0
        let baseWidth = max(16, geometry.appearance.compactWidth)
        let autoFit = options.autoFitContent ?? true

        guard !host.state.editingGeometry else {
            host.geometry?.activeCompactWidth = nil
            host.geometry?.activeCompactCenterOffset = nil
            return
        }

        if attached {
            let baseSide = max(0, (baseWidth - camera) / 2)
            var leftExtent = baseSide
            var rightExtent = baseSide
            if autoFit {
                leftExtent = max(leftExtent, sides.left)
                rightExtent = max(rightExtent, sides.right)
            } else {
                leftExtent = max(leftExtent, sides.decorationLeft)
                rightExtent = max(rightExtent, sides.decorationRight)
            }

            var required = camera + leftExtent + rightExtent
            if expansion.enabled && (leftLive || rightLive), expansion.width > required {
                let extra = expansion.width - required
                if leftLive && !rightLive { leftExtent += extra }
                else if rightLive && !leftLive { rightExtent += extra }
                else { leftExtent += extra / 2; rightExtent += extra / 2 }
                required = camera + leftExtent + rightExtent
            }

            let maxWidth = geometry.visible.width
            if required > maxWidth {
                let overflow = required - maxWidth
                if leftExtent >= rightExtent { leftExtent = max(0, leftExtent - overflow) }
                else { rightExtent = max(0, rightExtent - overflow) }
                required = camera + leftExtent + rightExtent
            }
            host.geometry?.activeCompactWidth = max(baseWidth, required)
            host.geometry?.activeCompactCenterOffset = (rightExtent - leftExtent) / 2
        } else {
            var requested = baseWidth
            if autoFit { requested = max(requested, sides.left + sides.right) }
            if expansion.enabled && (leftLive || rightLive) { requested = max(requested, expansion.width) }
            host.geometry?.activeCompactWidth = min(geometry.visible.width, requested)
            host.geometry?.activeCompactCenterOffset = nil
        }
    }

    private func fittedClosedSides(host: Host, layout: WorkspaceLayout,
                                   items: (left: ClosedNotchItem, right: ClosedNotchItem),
                                   power: (side: DynamicSide, width: Double)?) ->
        (left: Double, right: Double, decorationLeft: Double, decorationRight: Double) {
        guard let geometry = host.geometry else { return (0, 0, 0, 0) }
        let options = layout.closedNotch ?? ClosedNotchOptions()
        let playing = store.workspace.media.isPlaying
        let activity = activeClosedActivity
        let size = min(options.fontSize, max(1, geometry.compactHeight - 2 * options.contentPaddingY) / 1.25)
        let font = NSFont.systemFont(ofSize: size)
        func textWidth(_ text: String, font: NSFont) -> Double {
            ceil((text as NSString).size(withAttributes: [.font: font]).width) + 4
        }
        func mediaWidth() -> Double {
            guard playing else { return 0 }
            let media = options.mediaOptions ?? ClosedMediaOptions()
            let title = textWidth(String(store.workspace.media.title.prefix(120)), font: font)
            let artist = textWidth(String(store.workspace.media.artist.prefix(120)), font: font)
            let natural: Double
            switch media.textMode {
            case .title: natural = title
            case .artist: natural = max(size * 3, artist)
            case .titleArtist: natural = media.lines == 2 ? max(title, artist) : title + (store.workspace.media.artist.isEmpty ? 0 : artist + size)
            case .lyrics: natural = max(140, min(260, title + artist * 0.5))
            }
            let textTarget: Double
            switch media.overflow {
            case .marquee: textTarget = min(max(120, natural * 0.55), 220)
            case .truncate: textTarget = min(natural, 220)
            case .scale: textTarget = min(natural, 260)
            }
            let icon = media.showPlaybackIcon ? size + 5 : 0
            return textTarget + icon
        }
        func measurements(_ item: ClosedNotchItem, _ decoration: SideDecoration?) -> (full: Double, decoration: Double) {
            let content: Double
            switch item {
            case .none: content = 0
            case .clock:
                let style = layout.widgetStyle(for: .clock)
                let clockFont = style.fontFamily == .custom ? NSFont(name: style.customFont, size: size) ?? font : NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium)
                let template = "88:88" + (style.clock.showSeconds ? ":88" : "") + (style.clock.twentyFourHour ? "" : " PM")
                content = textWidth(template, font: clockFont) * 1.08
            case .date: content = textWidth("Sep 28", font: font)
            case .timer: content = textWidth("88:88:88", font: font) + size
            case .battery: content = textWidth("100%", font: font) + size + 5
            case .media: content = mediaWidth()
            case .visualizer: content = playing ? (options.visualizer ?? VisualizerOptions()).width : 0
            case .files: content = textWidth(String(store.files.count), font: font) + size + 5
            case .activity:
                content = activity.map {
                    let title = textWidth(String($0.title.prefix(80)), font: font)
                    let detail = $0.detail.isEmpty ? 0 : textWidth(String($0.detail.prefix(80)), font: NSFont.systemFont(ofSize: max(8, size * 0.78)))
                    return max(title, detail) + size + ($0.progress == nil ? 5 : 46)
                } ?? 0
            }
            let ornament = decoration.flatMap { $0.isVisible(playing: playing) ? min($0.size, max(1, geometry.compactHeight - 2 * options.contentPaddingY)) : nil } ?? 0
            guard content > 0 || ornament > 0 else { return (0, 0) }
            let spacing = content > 0 && ornament > 0 ? 5.0 : 0
            let margins = 2 * options.contentPaddingX + options.contentSideMargin + options.contentOuterMargin
            return (content + ornament + spacing + margins, ornament > 0 ? ornament + margins : 0)
        }
        let left = measurements(items.left, options.leftDecoration)
        let right = measurements(items.right, options.rightDecoration)
        var leftFull = left.full
        var rightFull = right.full

        var artwork = options.artworkOptions ?? ClosedArtworkOptions()
        if options.artworkOptions == nil, let legacy = options.mediaOptions, legacy.artwork != .none {
            artwork.enabled = true; artwork.mode = legacy.artwork; artwork.size = legacy.artworkSize
            artwork.vinylRPM = legacy.vinylRPM; artwork.backgroundOpacity = legacy.backgroundOpacity
        }
        if playing && artwork.enabled && artwork.mode != .none && artwork.mode != .background {
            let width = artwork.size + 2 * artwork.padding + artwork.margin
            switch artwork.side {
            case .left: leftFull += width
            case .right: rightFull += width
            case .automatic:
                if options.left == .media || options.left == .visualizer { leftFull += width }
                else { rightFull += width }
            }
        }

        let gap = 6.0
        let leftPower = power?.side == .left ? power!.width + (leftFull > 0 ? gap : 0) : 0
        let rightPower = power?.side == .right ? power!.width + (rightFull > 0 ? gap : 0) : 0
        return (leftFull + leftPower, rightFull + rightPower, left.decoration, right.decoration)
    }

    private func refreshDynamicWidths() {
        activityExpiry?.cancel()
        if let next = store.workspace.activities.map({ $0.created.addingTimeInterval(12) }).filter({ $0 > Date() }).min() {
            let work = DispatchWorkItem { [weak self] in self?.refreshDynamicWidths() }
            activityExpiry = work
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0.01, next.timeIntervalSinceNow), execute: work)
        }
        for host in hosts.values {
            let oldWidth = host.geometry?.compactWidth
            let oldOffset = host.geometry?.activeCompactCenterOffset
            configureDynamicWidth(host)
            guard let geometry = host.geometry,
                  oldWidth != geometry.compactWidth || oldOffset != geometry.activeCompactCenterOffset else { continue }
            host.state.compactWidth = geometry.compactWidth
            host.state.closedOcclusion = geometry.closedCameraOcclusion
            guard !host.state.expanded else { continue }
            var target = geometry.frame(expanded: false)
            if geometry.style == .detached {
                target.origin.x = host.panel.frame.midX - target.width / 2
                target.origin.y = host.panel.frame.maxY - target.height
            }
            host.targetFrame = target
            var motion = geometry.appearance.surface
            motion.opening = .resize; motion.closing = .resize; motion.duration = 0.34
            host.animator.move(panel: host.panel, state: host.state, target: target, options: motion,
                               preset: .smooth, animations: host.state.theme.animations && !host.state.editingGeometry,
                               opening: true, style: geometry.style)
        }
    }

    func stop() { activityExpiry?.cancel(); hosts.values.forEach { $0.stop() }; hosts.removeAll(); subscriptions.removeAll() }
    func toggleAll() {
        let expand = !hosts.values.contains { $0.state.expanded }
        hosts.values.forEach { $0.state.collapseTask?.cancel(); $0.state.expanded = expand }
    }

    private func reconcile() {
        let screens = store.configuration.allDisplays ? NSScreen.screens : Array(NSScreen.screens.prefix(1))
        var active = Set<String>()
        for screen in screens {
            let id = Self.displayID(screen)
            let override = store.workspace.settings.displays.first { $0.id == id }
            guard override?.enabled != false else { continue }
            active.insert(id)
            let existing = hosts[id]
            let host = existing ?? Host()
            var theme = override?.theme ?? store.workspace.scheduledTheme ?? store.configuration.theme
            if store.configuration.simulateNotch && theme.style == .notch { theme.style = .simulated }
            var appearance = override?.layout?.appearance ?? store.workspace.effectiveLayout.appearance
            appearance.surface = (try? appearance.surface.validated()) ?? SurfaceOptions()
            let previousOffset = host.geometry?.offset(expanded: host.state.expanded) ?? .zero
            host.geometry = Self.geometry(screen: screen, theme: theme, appearance: appearance)
            if host.state.theme != theme { host.state.theme = theme }
            if host.state.layoutOverride != override?.layout { host.state.layoutOverride = override?.layout }
            configureDynamicWidth(host)
            if host.state.dashboardWidth != host.geometry!.frame(expanded: true).width { host.state.dashboardWidth = host.geometry!.frame(expanded: true).width }
            if host.state.compactHeight != host.geometry!.compactHeight { host.state.compactHeight = host.geometry!.compactHeight }
            if host.state.compactWidth != host.geometry!.compactWidth { host.state.compactWidth = host.geometry!.compactWidth }
            if host.state.closedOcclusion != host.geometry!.closedCameraOcclusion { host.state.closedOcclusion = host.geometry!.closedCameraOcclusion }
            host.panel.isMovableByWindowBackground = theme.style == .detached
            var target = host.geometry!.frame(expanded: host.state.expanded)
            if existing != nil && theme.style == .detached {
                let delta = host.geometry!.offset(expanded: host.state.expanded)
                target.origin.x = host.panel.frame.midX - target.width / 2 + delta.width - previousOffset.width
                target.origin.y = host.panel.frame.maxY - target.height + delta.height - previousOffset.height
            }
            if host.targetFrame != target {
                host.targetFrame = target; host.animator.cancel()
                if host.state.viewport.size != target.size { host.state.viewport.size = target.size }
                host.panel.alphaValue = 1
                if host.panel.frame != target { host.panel.setFrame(target, display: false) }
            }
            if existing == nil {
                let view = NSHostingView(rootView: SurfaceViewportView(viewport: host.state.viewport, content: SurfaceView(store: store, state: host.state, workspace: store.workspace)))
                view.sizingOptions = []
                host.panel.contentView = view
                host.subscription = host.state.$expanded.dropFirst().removeDuplicates().receive(on: DispatchQueue.main).sink { [weak host] expanded in
                    guard let host, let geometry = host.geometry else { return }
                    var target = geometry.frame(expanded: expanded)
                    if geometry.style == .detached {
                        let oldOffset = geometry.offset(expanded: !expanded), newOffset = geometry.offset(expanded: expanded)
                        target.origin.x = host.panel.frame.midX - target.width / 2 + newOffset.width - oldOffset.width
                        target.origin.y = host.panel.frame.maxY - target.height + newOffset.height - oldOffset.height
                    }
                    host.targetFrame = target
                    host.animator.move(panel: host.panel, state: host.state, target: target, options: geometry.appearance.surface,
                                       preset: geometry.appearance.animation, animations: host.state.theme.animations && !host.state.editingGeometry, opening: expanded, style: geometry.style)
                }
                host.panel.orderFrontRegardless()
                hosts[id] = host
            }
        }
        for id in Array(hosts.keys) where !active.contains(id) { hosts.removeValue(forKey: id)?.stop() }
    }
}
