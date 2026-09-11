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
    @Published var contextPreferredSize: CGSize?
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

@MainActor
final class SurfaceAnimator {
    private enum HorizontalResizeAnchor { case left, right, center }

    private let clock = DisplayClock()
    private weak var animatedView: NSView?

    func cancel() {
        clock.stop()
        if let animatedView { setContentTranslation(0, on: animatedView) }
        animatedView = nil
    }

    private func publishGeometry(panel: HaloPanel, frame: CGRect) {
        NotificationCenter.default.post(name: .init("HaloPanelGeometryChanged"), object: panel,
                                        userInfo: ["frame": frame])
    }

    private func setContentTranslation(_ x: CGFloat, on view: NSView) {
        view.wantsLayer = true
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        view.layer?.masksToBounds = true
        view.layer?.sublayerTransform = CATransform3DMakeTranslation(x, 0, 0)
        CATransaction.commit()
    }

    func move(panel: HaloPanel, state: SurfaceState, target: CGRect, options: SurfaceOptions,
              preset: AnimationPreset, animations: Bool, opening: Bool, style: SurfaceStyle,
              liveViewportResize: Bool = true, fixedHorizontalEdge: CGRectEdge? = nil) {
        cancel()
        let transition = opening ? options.opening : options.closing
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        guard animations, !reduceMotion, preset != .none, transition != .instant else {
            panel.alphaValue = 1
            state.viewport.size = target.size
            panel.setFrame(target, display: false)
            publishGeometry(panel: panel, frame: target)
            return
        }
        let initial = panel.frame
        let initialAlpha = panel.alphaValue
        let start = CACurrentMediaTime()
        let duration = options.duration
        guard let view = panel.contentView else {
            state.viewport.size = target.size
            panel.setFrame(target, display: false)
            publishGeometry(panel: panel, frame: target)
            return
        }
        animatedView = view

        // Closed-notch resizing has an explicit fixed edge. Do not infer this from the current
        // NSPanel frame: that frame may already be mid-animation or slightly stale when media,
        // power or activity state changes. The geometry layer knows which wing changed.
        let horizontalAnchor: HorizontalResizeAnchor = {
            if !liveViewportResize {
                switch fixedHorizontalEdge {
                case .minXEdge?: return .left
                case .maxXEdge?: return .right
                default: break
                }
            }
            guard !liveViewportResize, abs(target.width - initial.width) > 0.5 else { return .center }
            let leftMovement = abs(target.minX - initial.minX)
            let rightMovement = abs(target.maxX - initial.maxX)
            let tolerance: CGFloat = 0.75
            if leftMovement <= tolerance && rightMovement > tolerance { return .left }
            if rightMovement <= tolerance && leftMovement > tolerance { return .right }
            return .center
        }()

        // Keep closed content laid out at the larger of the start/end widths. Expansion then
        // reveals prepared content; contraction clips the existing content. This avoids doing
        // a full SwiftUI hierarchy relayout every display frame.
        let presentationSize = liveViewportResize
            ? initial.size
            : CGSize(width: max(initial.width, target.width), height: max(initial.height, target.height))
        if !liveViewportResize, state.viewport.size != presentationSize {
            state.viewport.size = presentationSize
        }

        // NSHostingView centers a fixed-width SwiftUI root when that root is wider than the
        // panel. Counter-translate the rendered sublayers so clipping happens only on the side
        // that is actually resizing.
        func contentTranslation(panelWidth: CGFloat, contentWidth: CGFloat) -> CGFloat {
            let overflow = max(0, contentWidth - panelWidth)
            switch horizontalAnchor {
            case .left: return overflow / 2
            case .right: return -overflow / 2
            case .center: return 0
            }
        }
        if !liveViewportResize {
            setContentTranslation(contentTranslation(panelWidth: initial.width, contentWidth: presentationSize.width), on: view)
        } else {
            setContentTranslation(0, on: view)
        }

        clock.start(view: view) { [weak self, weak panel, weak state, weak view] timestamp in
            guard let self, let panel, let state, let view else { self?.cancel(); return }
            let t = min(1, max(0, timestamp - start) / max(0.01, duration))
            let p = SurfaceMotion.progress(t, transition: transition, preset: preset, damping: options.damping)
            let width = max(1, initial.width + (target.width - initial.width) * p)
            let height = max(1, initial.height + (target.height - initial.height) * p)
            let centerX = initial.midX + (target.midX - initial.midX) * p
            let top = initial.maxY + (target.maxY - initial.maxY) * p
            let x: CGFloat
            switch horizontalAnchor {
            case .left: x = initial.minX
            case .right: x = initial.maxX - width
            case .center: x = centerX - width / 2
            }
            var frame = CGRect(x: x, y: top - height, width: width, height: height)
            if style == .bottom { frame.origin.y = target.minY }
            if style == .left { frame.origin.x = target.minX }
            if style == .right { frame.origin.x = target.maxX - width }
            if transition == .scale {
                let inset = 0.04 * sin(.pi * t)
                frame = frame.insetBy(dx: frame.width * inset, dy: frame.height * inset)
            }
            if transition == .slide { frame.origin.y += (style == .bottom ? -1 : 1) * 18 * sin(.pi * t) }
            panel.alphaValue = transition == .fade ? initialAlpha + (1 - initialAlpha) * t - 0.3 * sin(.pi * t) : 1

            if !liveViewportResize {
                let contracting = target.width < initial.width - 0.5
                let useFinalLayout = contracting && t >= 0.985
                let contentWidth = useFinalLayout ? target.width : presentationSize.width
                if useFinalLayout, state.viewport.size != target.size { state.viewport.size = target.size }
                self.setContentTranslation(useFinalLayout ? 0 : contentTranslation(panelWidth: width, contentWidth: contentWidth), on: view)
            }

            if t >= 1 {
                frame = target
                panel.alphaValue = 1
                if state.viewport.size != target.size { state.viewport.size = target.size }
                self.setContentTranslation(0, on: view)
                self.clock.stop()
                self.animatedView = nil
            } else if liveViewportResize, state.viewport.size != frame.size {
                state.viewport.size = frame.size
            }
            panel.setFrame(frame, display: false)
            self.publishGeometry(panel: panel, frame: frame)
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
        var contextSizeSubscription: AnyCancellable?
        init() {
            panel = HaloPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = true
            panel.hidesOnDeactivate = false; panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }
        func stop() {
            animator.cancel(); state.collapseTask?.cancel(); subscription?.cancel(); contextSizeSubscription?.cancel(); panel.close()
        }
    }

    private enum DynamicSide { case left, right }
    private var activityExpiry: DispatchWorkItem?
    private var mediaWidthHint: Double?
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
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main).sink { [weak self] _ in
                // Demo Studio writes playback/marketing knobs into UserDefaults. They are not
                // geometry preferences; reconciling for them cancels the closed-notch animation
                // and is the source of the visible jump in the supplied recording.
                guard !UserDefaults.standard.bool(forKey: DemoMarketingStudio.enabledKey) else { return }
                self?.reconcile()
            }.store(in: &subscriptions)
        store.$configuration.dropFirst().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reconcile() }.store(in: &subscriptions)
        store.workspace.$settings.map { [store] settings in
            let layout = settings.profiles.first { $0.id == store.workspace.scheduledProfileID }?.layout ?? settings.layout
            return SurfaceRenderConfiguration(appearance: layout.appearance, displays: settings.displays, closedNotch: layout.closedNotch, clock: layout.widgetStyle(for: .clock), horizontalWidgets: layout.horizontalWidgets, horizontalHeight: layout.horizontalHeight)
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
        NotificationCenter.default.publisher(for: .init("HaloClosedMediaWidthHint"))
            .receive(on: DispatchQueue.main).sink { [weak self] note in
                guard let self,
                      let raw = note.userInfo?["width"] as? Double,
                      raw.isFinite else { return }
                let next = min(320, max(24, raw))
                guard self.mediaWidthHint.map({ abs($0 - next) >= 3 }) ?? true else { return }
                self.mediaWidthHint = next
                self.refreshDynamicWidths()
            }.store(in: &subscriptions)
        store.workspace.$scheduledProfileID.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reconcile() }.store(in: &subscriptions)
        store.workspace.media.$title.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.mediaWidthHint = nil; self?.refreshDynamicWidths() }.store(in: &subscriptions)
        store.workspace.media.$artist.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshDynamicWidths() }.store(in: &subscriptions)
        store.$files.map(\.count).removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshDynamicWidths() }.store(in: &subscriptions)
        store.$pinnedFiles.map { !$0.isEmpty }.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshDynamicWidths() }.store(in: &subscriptions)
        store.workspace.capture.$busy.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshDynamicWidths() }.store(in: &subscriptions)
        store.workspace.media.$isPlaying.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] playing in
                if !playing { self?.mediaWidthHint = nil }
                self?.refreshDynamicWidths()
            }.store(in: &subscriptions)
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
                               items: (left: ClosedNotchItem, right: ClosedNotchItem))
        -> (side: DynamicSide, badgeWidth: Double, minimumSideWidth: Double)? {
        let settings = options.powerReaction ?? PowerReactionOptions()
        guard settings.isEnabled, let battery = store.workspace.system.battery else { return nil }
        let style: PowerReactionStyle
        let eventLabel: String
        if battery >= 99 && !store.workspace.system.onBattery {
            style = settings.charged; eventLabel = "Charged"
        } else if store.workspace.system.charging {
            style = settings.charging; eventLabel = "Charging"
        } else if store.workspace.system.onBattery && battery <= settings.lowThreshold {
            style = settings.low; eventLabel = "Low battery"
        } else { return nil }
        guard style != .off else { return nil }

        let size = max(10, options.fontSize)
        let font = NSFont.systemFont(ofSize: size, weight: .regular)
        func textWidth(_ value: String) -> Double {
            ceil((value as NSString).size(withAttributes: [.font: font]).width)
        }
        let iconWidth = max(12, size * 1.05)
        let labelGap = 4.0
        let horizontalPadding = 4.0
        let naturalWidth: Double
        switch style {
        case .off: naturalWidth = 0
        case .icon: naturalWidth = iconWidth + horizontalPadding
        case .percent: naturalWidth = textWidth("100%") + horizontalPadding
        case .iconPercent: naturalWidth = iconWidth + labelGap + textWidth("100%") + horizontalPadding
        case .label: naturalWidth = iconWidth + labelGap + textWidth(eventLabel) + horizontalPadding
        }
        let badgeWidth = max(18, naturalWidth)
        let minimumSideWidth = settings.expandForEvent ? max(badgeWidth, settings.eventWidth) : badgeWidth

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
        return (side, badgeWidth, minimumSideWidth)
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

        let mediaSettings = options.mediaOptions ?? ClosedMediaOptions()
        let adaptiveLyrics = store.workspace.media.isPlaying && mediaSettings.textMode == .lyrics && mediaSettings.usesDynamicLyricWidth
        let constrainedMedia = store.workspace.media.isPlaying && (mediaSettings.overflow == .truncate || mediaSettings.overflow == .marquee)
        if adaptiveLyrics || constrainedMedia {
            if items.left == .media {
                leftLive = options.leftDecoration?.visibility == .playing && store.workspace.media.isPlaying
            }
            if items.right == .media {
                rightLive = options.rightDecoration?.visibility == .playing && store.workspace.media.isPlaying
            }
        }

        let attached = geometry.attachedToNotch && geometry.physicalNotchWidth > 0
        let notchLike = attached || geometry.style == .notch || geometry.style == .simulated
        let camera = attached ? geometry.physicalNotchWidth : 0
        let baseWidth = max(16, geometry.appearance.compactWidth)
        let autoFit = options.autoFitContent ?? true

        guard !host.state.editingGeometry else {
            host.geometry?.activeCompactWidth = nil
            host.geometry?.activeCompactCenterOffset = nil
            return
        }

        if notchLike {
            let extents = ClosedWingSizing.extents(
                base: baseWidth, camera: camera,
                left: autoFit ? sides.left : sides.decorationLeft,
                right: autoFit ? sides.right : sides.decorationRight,
                expansion: expansion.enabled ? expansion.width : 0,
                leftLive: leftLive, rightLive: rightLive)
            let baseCenter = attached ? geometry.screen.midX : geometry.visible.midX
            let center = baseCenter + geometry.offset(expanded: false).width
            let leftLimit = max(0, center - camera / 2 - geometry.visible.minX - 12)
            let rightLimit = max(0, geometry.visible.maxX - 12 - center - camera / 2)
            let leftExtent = min(extents.left, leftLimit)
            let rightExtent = min(extents.right, rightLimit)
            let required = camera + leftExtent + rightExtent
            host.geometry?.activeCompactWidth = min(geometry.visible.width, max(baseWidth, required))
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
                                   power: (side: DynamicSide, badgeWidth: Double, minimumSideWidth: Double)?) ->
        (left: Double, right: Double, decorationLeft: Double, decorationRight: Double) {
        guard let geometry = host.geometry else { return (0, 0, 0, 0) }
        let options = layout.closedNotch ?? ClosedNotchOptions()
        let playing = store.workspace.media.isPlaying
        let activity = activeClosedActivity
        let size = min(options.fontSize, max(1, geometry.compactHeight - 2 * options.contentPaddingY) / 1.25)
        let font = NSFont.systemFont(ofSize: size)
        let slotMargins = 2 * options.contentPaddingX + options.contentSideMargin + options.contentOuterMargin
        let elementGap = 6.0

        var artwork = options.artworkOptions ?? ClosedArtworkOptions()
        if options.artworkOptions == nil, let legacy = options.mediaOptions, legacy.artwork != .none {
            artwork.enabled = true; artwork.mode = legacy.artwork; artwork.size = legacy.artworkSize
            artwork.vinylRPM = legacy.vinylRPM; artwork.backgroundOpacity = legacy.backgroundOpacity
        }

        let artworkTarget: DynamicSide? = {
            guard playing, artwork.enabled, artwork.mode != .none, artwork.mode != .background else { return nil }
            switch artwork.side {
            case .left: return .left
            case .right: return .right
            case .automatic:
                if options.left == .media || options.left == .visualizer { return .left }
                if options.right == .media || options.right == .visualizer { return .right }
                return .right
            }
        }()

        func textWidth(_ text: String, font: NSFont) -> Double {
            ceil((text as NSString).size(withAttributes: [.font: font]).width) + 2
        }
        func mediaWidth() -> Double {
            guard playing else { return 0 }
            let media = options.mediaOptions ?? ClosedMediaOptions()
            let title = textWidth(String(store.workspace.media.title.prefix(120)), font: font)
            let artist = textWidth(String(store.workspace.media.artist.prefix(120)), font: font)
            let adaptive = media.textMode == .lyrics && media.usesDynamicLyricWidth && mediaWidthHint != nil
            let icon = media.showPlaybackIcon ? size + 5 : 0
            let naturalText: Double
            switch media.textMode {
            case .title: naturalText = title
            case .artist: naturalText = max(size * 3, artist)
            case .titleArtist: naturalText = media.lines == 2 ? max(title, artist) : title + (store.workspace.media.artist.isEmpty ? 0 : artist + size)
            case .lyrics:
                naturalText = adaptive ? max(28, mediaWidthHint!) : max(90, min(220, title + artist * 0.35))
            }
            let naturalTotal = naturalText + (adaptive ? 0 : icon)
            if adaptive { return min(320, max(28, naturalText)) }
            switch media.overflow {
            case .marquee: return min(max(120, naturalTotal * 0.55), 220)
            case .truncate: return min(naturalTotal, 220)
            case .scale: return min(naturalTotal, 260)
            }
        }

        func isArtworkOnly(_ side: DynamicSide, item: ClosedNotchItem) -> Bool {
            guard artwork.isArtworkOnly, artworkTarget == side else { return false }
            return item == .media || item == .visualizer
        }

        func measurements(_ side: DynamicSide, _ item: ClosedNotchItem, _ decoration: SideDecoration?) -> (full: Double, decoration: Double) {
            let content: Double
            if isArtworkOnly(side, item: item) {
                content = 0
            } else {
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
                case .mirror: content = 112
                case .files: content = textWidth(String(store.files.count), font: font) + size + 5
                case .activity:
                    content = activity.map {
                        let title = textWidth(String($0.title.prefix(80)), font: font)
                        let detailFont = NSFont.systemFont(ofSize: max(8, size * 0.76))
                        let detail = $0.detail.isEmpty ? 0 : textWidth(String($0.detail.prefix(80)), font: detailFont)
                        let icon = max(12, size)
                        let text = max(title, detail)
                        let progress = $0.progress == nil ? 0 : elementGap + 38
                        return icon + elementGap + text + progress + 2
                    } ?? 0
                }
            }
            let ornament = decoration.flatMap { $0.isVisible(playing: playing) ? min($0.size, max(1, geometry.compactHeight - 2 * options.contentPaddingY)) : nil } ?? 0
            guard content > 0 || ornament > 0 else { return (0, 0) }
            let spacing = content > 0 && ornament > 0 ? elementGap : 0
            return (content + ornament + spacing + slotMargins, ornament > 0 ? ornament + slotMargins : 0)
        }

        let left = measurements(.left, items.left, options.leftDecoration)
        let right = measurements(.right, items.right, options.rightDecoration)
        var leftFull = left.full
        var rightFull = right.full

        if let artworkTarget {
            let artworkWidth = artwork.size + 2 * artwork.padding + artwork.margin
            switch artworkTarget {
            case .left:
                leftFull = leftFull > 0 ? leftFull + elementGap + artworkWidth : slotMargins + artworkWidth
            case .right:
                rightFull = rightFull > 0 ? rightFull + elementGap + artworkWidth : slotMargins + artworkWidth
            }
        }

        if let power {
            switch power.side {
            case .left:
                let withBadge = leftFull > 0 ? leftFull + elementGap + power.badgeWidth : slotMargins + power.badgeWidth
                leftFull = max(withBadge, power.minimumSideWidth)
            case .right:
                let withBadge = rightFull > 0 ? rightFull + elementGap + power.badgeWidth : slotMargins + power.badgeWidth
                rightFull = max(withBadge, power.minimumSideWidth)
            }
        }
        return (leftFull, rightFull, left.decoration, right.decoration)
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
            let oldOffset = host.geometry?.activeCompactCenterOffset ?? 0
            configureDynamicWidth(host)
            guard let geometry = host.geometry else { continue }
            let newWidth = geometry.compactWidth
            let newOffset = geometry.activeCompactCenterOffset ?? 0
            guard oldWidth != newWidth || oldOffset != newOffset else { continue }

            // Work out which logical panel edge did not move. This is independent of the
            // NSPanel's current animation frame, so right-wing media growth always keeps minX
            // fixed and left-wing growth always keeps maxX fixed.
            let oldLogicalWidth = oldWidth ?? newWidth
            let oldLeft = oldOffset - oldLogicalWidth / 2
            let oldRight = oldOffset + oldLogicalWidth / 2
            let newLeft = newOffset - newWidth / 2
            let newRight = newOffset + newWidth / 2
            let leftDelta = abs(newLeft - oldLeft)
            let rightDelta = abs(newRight - oldRight)
            let fixedEdge: CGRectEdge? = {
                let tolerance = 0.75
                if leftDelta <= tolerance && rightDelta > tolerance { return .minXEdge }
                if rightDelta <= tolerance && leftDelta > tolerance { return .maxXEdge }
                if leftDelta + tolerance < rightDelta { return .minXEdge }
                if rightDelta + tolerance < leftDelta { return .maxXEdge }
                return nil
            }()

            host.state.compactWidth = newWidth
            host.state.closedOcclusion = geometry.closedCameraOcclusion
            guard !host.state.expanded else { continue }
            var target = geometry.frame(expanded: false)
            if geometry.style == .detached {
                target.origin.x = host.panel.frame.midX - target.width / 2
                target.origin.y = host.panel.frame.maxY - target.height
            }
            host.targetFrame = target
            var motion = geometry.appearance.surface
            motion.opening = .resize
            motion.closing = .resize
            motion.duration = min(1.2, max(0.10, motion.duration))
            host.animator.move(panel: host.panel, state: host.state, target: target, options: motion,
                               preset: geometry.appearance.animation,
                               animations: host.state.theme.animations && !host.state.editingGeometry,
                               opening: true, style: geometry.style, liveViewportResize: false,
                               fixedHorizontalEdge: fixedEdge)
        }
    }

    func stop() { activityExpiry?.cancel(); hosts.values.forEach { $0.stop() }; hosts.removeAll(); subscriptions.removeAll() }
    func toggleAll() {
        let expand = !hosts.values.contains { $0.state.expanded }
        hosts.values.forEach { $0.state.collapseTask?.cancel(); $0.state.expanded = expand }
    }

    private func adjustedExpandedFrame(host: Host, requested: CGSize?) -> CGRect {
        guard let geometry = host.geometry else { return .zero }
        let base = geometry.frame(expanded: true)
        guard let requested, requested.width.isFinite, requested.height.isFinite else { return base }

        let contextHorizontalSafety: CGFloat = 56
        let contextVerticalSafety: CGFloat = 64
        let margin: CGFloat = 12
        let minimumHeight = geometry.compactHeight + 112
        let maxWidth = max(360, geometry.visible.width - margin * 2)
        let width = min(maxWidth, max(360, requested.width + contextHorizontalSafety))
        var height = max(minimumHeight, requested.height + contextVerticalSafety)
        var frame: CGRect

        switch geometry.style {
        case .bottom:
            let anchorBottom = base.minY
            let topLimit = geometry.visible.maxY - margin
            let availableHeight = max(minimumHeight, topLimit - anchorBottom)
            height = min(height, availableHeight)
            frame = CGRect(x: base.midX - width / 2, y: anchorBottom, width: width, height: height)
        default:
            let anchorTop = base.maxY
            let bottomLimit = geometry.visible.minY + margin
            let availableHeight = max(minimumHeight, anchorTop - bottomLimit)
            height = min(height, availableHeight)
            frame = CGRect(x: base.midX - width / 2, y: anchorTop - height, width: width, height: height)
            if geometry.style == .left { frame.origin.x = base.minX }
            if geometry.style == .right { frame.origin.x = base.maxX - width }
        }

        let defaults = UserDefaults.standard
        let contextX = CGFloat(defaults.double(forKey: "HaloContextOffsetX"))
        let contextY = CGFloat(defaults.double(forKey: "HaloContextOffsetY"))
        frame.origin.x += contextX
        frame.origin.y -= contextY

        if frame.minX < geometry.visible.minX + margin { frame.origin.x = geometry.visible.minX + margin }
        if frame.maxX > geometry.visible.maxX - margin { frame.origin.x = geometry.visible.maxX - margin - width }

        let bottomLimit = geometry.visible.minY + margin
        let topLimit = max(base.maxY, geometry.visible.maxY - margin)
        if frame.minY < bottomLimit { frame.origin.y = bottomLimit }
        if frame.maxY > topLimit { frame.origin.y = topLimit - height }
        return frame
    }

    private func targetFrame(host: Host, expanded: Bool) -> CGRect {
        guard let geometry = host.geometry else { return .zero }
        return expanded ? adjustedExpandedFrame(host: host, requested: host.state.contextPreferredSize) : geometry.frame(expanded: false)
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
            let effectiveLayout = override?.layout ?? store.workspace.effectiveLayout
            if effectiveLayout.horizontalWidgets ?? false {
                let requested = effectiveLayout.horizontalHeight ?? 260
                appearance.expandedHeight = requested.isFinite ? min(500, max(200, requested)) : 260
            }
            appearance.surface = (try? appearance.surface.validated()) ?? SurfaceOptions()
            let previousOffset = host.geometry?.offset(expanded: host.state.expanded) ?? .zero
            host.geometry = Self.geometry(screen: screen, theme: theme, appearance: appearance)
            if host.state.theme != theme { host.state.theme = theme }
            if host.state.layoutOverride != override?.layout { host.state.layoutOverride = override?.layout }
            configureDynamicWidth(host)
            let baseDashboardWidth = host.geometry!.frame(expanded: true).width
            if host.state.contextPreferredSize == nil && host.state.dashboardWidth != baseDashboardWidth { host.state.dashboardWidth = baseDashboardWidth }
            if host.state.compactHeight != host.geometry!.compactHeight { host.state.compactHeight = host.geometry!.compactHeight }
            if host.state.compactWidth != host.geometry!.compactWidth { host.state.compactWidth = host.geometry!.compactWidth }
            if host.state.closedOcclusion != host.geometry!.closedCameraOcclusion { host.state.closedOcclusion = host.geometry!.closedCameraOcclusion }
            host.panel.isMovableByWindowBackground = theme.style == .detached
            var target = targetFrame(host: host, expanded: host.state.expanded)
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
                NotificationCenter.default.post(name: .init("HaloPanelGeometryChanged"), object: host.panel,
                                                userInfo: ["frame": target, "screen": id])
            }
            if existing == nil {
                let view = NSHostingView(rootView: SurfaceViewportView(viewport: host.state.viewport, content: SurfaceView(store: store, state: host.state, workspace: store.workspace)))
                view.sizingOptions = []
                host.panel.contentView = view
                host.subscription = host.state.$expanded.dropFirst().removeDuplicates().receive(on: DispatchQueue.main).sink { [weak self, weak host] expanded in
                    guard let self, let host, let geometry = host.geometry else { return }
                    if !expanded { host.state.contextPreferredSize = nil }
                    var target = self.targetFrame(host: host, expanded: expanded)
                    if geometry.style == .detached {
                        let oldOffset = geometry.offset(expanded: !expanded), newOffset = geometry.offset(expanded: expanded)
                        target.origin.x = host.panel.frame.midX - target.width / 2 + newOffset.width - oldOffset.width
                        target.origin.y = host.panel.frame.maxY - target.height + newOffset.height - oldOffset.height
                    }
                    let baseWidth = geometry.frame(expanded: true).width
                    let contentWidth = expanded && host.state.contextPreferredSize != nil ? target.width : baseWidth
                    if host.state.dashboardWidth != contentWidth { host.state.dashboardWidth = contentWidth }
                    host.targetFrame = target
                    host.animator.move(panel: host.panel, state: host.state, target: target, options: geometry.appearance.surface,
                                       preset: geometry.appearance.animation, animations: host.state.theme.animations && !host.state.editingGeometry, opening: expanded, style: geometry.style)
                }
                host.contextSizeSubscription = host.state.$contextPreferredSize.dropFirst().removeDuplicates(by: { lhs, rhs in
                    switch (lhs, rhs) {
                    case (nil, nil): return true
                    case let (a?, b?): return abs(a.width - b.width) < 1 && abs(a.height - b.height) < 1
                    default: return false
                    }
                }).receive(on: DispatchQueue.main).sink { [weak self, weak host] requested in
                    guard let self, let host, let geometry = host.geometry, host.state.expanded else { return }
                    let target = self.targetFrame(host: host, expanded: true)
                    guard host.targetFrame != target || abs(host.state.dashboardWidth - target.width) >= 1 else { return }
                    let baseWidth = geometry.frame(expanded: true).width
                    let contentWidth = requested == nil ? baseWidth : target.width
                    if host.state.dashboardWidth != contentWidth { host.state.dashboardWidth = contentWidth }
                    host.targetFrame = target
                    var motion = geometry.appearance.surface
                    motion.opening = .resize; motion.closing = .resize; motion.duration = min(0.32, max(0.16, motion.duration))
                    host.animator.move(panel: host.panel, state: host.state, target: target, options: motion,
                                       preset: .smooth, animations: host.state.theme.animations && !host.state.editingGeometry,
                                       opening: true, style: geometry.style)
                }
                host.panel.orderFrontRegardless()
                hosts[id] = host
            }
        }
        for id in Array(hosts.keys) where !active.contains(id) { hosts.removeValue(forKey: id)?.stop() }
    }
}
