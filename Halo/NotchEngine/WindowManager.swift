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
        didSet {
            if pinned {
                hoverExpandTask?.cancel()
                collapseTask?.cancel()
                expanded = true
            }
        }
    }
    let viewport = SurfaceViewport()
    @Published var dashboardWidth: CGFloat = 420
    @Published var compactWidth: CGFloat = 190
    @Published var closedOcclusion: CGRect?
    @Published var compactHeight: CGFloat = 40
    @Published var physicalNotchWidth: CGFloat = 190
    @Published var physicalNotchHeight: CGFloat = 32
    @Published var screenFrame: CGRect = .zero
    @Published var theme = Theme()
    @Published var activationSurfaceOptions = SurfaceOptions()
    @Published var layoutOverride: WorkspaceLayout?
    @Published var contextPreferredSize: CGSize?
    @Published var contextPreferredCompactWidth: CGFloat?
    @Published var contextPreferredCompactHeight: CGFloat?
    @Published var contextMinimumExpandedWidth: CGFloat?
    /// Per-surface drag state keeps Drop CI scoped to the display beneath the dragged item.
    @Published var dropTargeted = false
    @Published var dropItemCount = 0
    var collapseTask: Task<Void, Never>?
    var hoverExpandTask: Task<Void, Never>?
    var dropExitTask: Task<Void, Never>?
    var editingGeometry = false
    private var fileDropAllowed = false

    func setFileDropAllowed(_ allowed: Bool) {
        guard fileDropAllowed != allowed else { return }
        fileDropAllowed = allowed
        if !allowed { cancelFileDrop() }
    }

    func cancelFileDrop() {
        dropExitTask?.cancel()
        dropExitTask = nil
        if dropTargeted { dropTargeted = false }
        if dropItemCount != 0 { dropItemCount = 0 }
    }

    func beginFileDrop(count: Int) {
        guard fileDropAllowed else {
            cancelFileDrop()
            return
        }
        dropExitTask?.cancel()
        hoverExpandTask?.cancel()
        collapseTask?.cancel()
        let nextCount = max(1, count)
        if dropItemCount != nextCount { dropItemCount = nextCount }
        if !dropTargeted { dropTargeted = true }
        if !expanded { expanded = true }
    }

    func endFileDrop(collapseAfterDelay: Bool = true) {
        dropExitTask?.cancel()
        dropExitTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled, let self else { return }
            self.dropTargeted = false
            self.dropItemCount = 0
            guard collapseAfterDelay, !self.pinned, !self.editingGeometry else { return }
            self.collapseTask?.cancel()
            self.collapseTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 420_000_000)
                guard !Task.isCancelled, let self, !self.pinned, !self.editingGeometry, !self.dropTargeted else { return }
                self.expanded = false
            }
        }
    }

    func completeFileDrop() {
        dropExitTask?.cancel()
        dropTargeted = false
        dropItemCount = 0
        guard !pinned, !editingGeometry else { return }
        collapseTask?.cancel()
        collapseTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled, let self, !self.pinned, !self.editingGeometry, !self.dropTargeted else { return }
            self.expanded = false
        }
    }

    func hover(_ inside: Bool, enabled: Bool, openDelay: Double = 0) {
        collapseTask?.cancel()
        if !inside {
            hoverExpandTask?.cancel()
            hoverExpandTask = nil
        }
        guard enabled, !editingGeometry else {
            hoverExpandTask?.cancel()
            hoverExpandTask = nil
            return
        }
        if dropTargeted {
            hoverExpandTask?.cancel()
            hoverExpandTask = nil
            if inside && !expanded { expanded = true }
            return
        }
        if inside {
            guard !expanded else {
                hoverExpandTask?.cancel()
                hoverExpandTask = nil
                return
            }
            let delay = min(10, max(0, openDelay))
            hoverExpandTask?.cancel()
            guard delay > 0.001 else {
                hoverExpandTask = nil
                expanded = true
                return
            }
            hoverExpandTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled,
                      let self,
                      !self.editingGeometry,
                      !self.dropTargeted else { return }
                self.hoverExpandTask = nil
                self.expanded = true
            }
        } else if !pinned {
            collapseTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 450_000_000)
                guard !Task.isCancelled, let self, !self.pinned, !self.editingGeometry, !self.dropTargeted else { return }
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
final class HaloDropHostingView<Content: View>: NSHostingView<Content> {
    var dragStateHandler: ((Bool, Int) -> Void)?
    var dropHandler: (([URL]) -> Void)?

    /// Commercial access is a hard outer boundary. When false, this hosting view
    /// must not register as a drag destination at all — including registrations
    /// requested internally by SwiftUI descendant .dropDestination views.
    var commercialAccessAllowed: (() -> Bool)? {
        didSet { refreshDropRegistration() }
    }

    /// This controls only the surface-wide Drop CI feature. It is deliberately
    /// separate from commercial access so licensed users can disable Drop CI while
    /// retaining legitimate descendant drop targets such as File Shelf.
    var dropEnabled: (() -> Bool)? {
        didSet { refreshDropRegistration() }
    }

    private var dropCIRegistered = false

    required init(rootView: Content) {
        super.init(rootView: rootView)
        refreshDropRegistration()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // Both providers fail closed until WindowManager installs them.
    private var hasCommercialAccess: Bool { commercialAccessAllowed?() ?? false }
    private var acceptsFileDrop: Bool { hasCommercialAccess && (dropEnabled?() ?? false) }

    /// The global file-drag monitor lives outside the normal NSDraggingDestination path.
    /// Expose the same authoritative, in-memory permission so it cannot create a second
    /// unlicensed Drop CI path.
    var permitsGlobalDropCI: Bool { acceptsFileDrop }

    /// Prevent SwiftUI or any descendant from re-registering the locked Halo surface
    /// as a drag destination. Once commercially unlocked, normal NSHostingView
    /// registration is allowed again so File Shelf and other descendant targets work.
    override func registerForDraggedTypes(_ newTypes: [NSPasteboard.PasteboardType]) {
        guard hasCommercialAccess else { return }
        super.registerForDraggedTypes(newTypes)
    }

    /// Drop CI owns only the surface-wide drag destination. Commercial lock is stronger
    /// than the Drop CI setting: while locked, remove every drag registration from this
    /// hosting view and reject any stale in-flight Drop CI state synchronously.
    func refreshDropRegistration() {
        guard hasCommercialAccess else {
            unregisterDraggedTypes()
            dropCIRegistered = false
            rejectFileDrop()
            return
        }

        let shouldRegister = dropEnabled?() ?? false
        guard shouldRegister != dropCIRegistered else { return }

        if shouldRegister {
            registerForDraggedTypes([.fileURL])
        } else {
            unregisterDraggedTypes()
        }

        dropCIRegistered = shouldRegister
        if !shouldRegister { rejectFileDrop() }
    }

    private func rejectFileDrop() {
        dragStateHandler?(false, 0)
    }

    private func fileURLCount(_ sender: NSDraggingInfo) -> Int {
        sender.draggingPasteboard.pasteboardItems?.reduce(into: 0) { count, item in
            if item.availableType(from: [.fileURL]) != nil { count += 1 }
        } ?? 0
    }

    private func fileURLs(_ sender: NSDraggingInfo) -> [URL] {
        let objects = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) ?? []
        return objects.compactMap { object in
            guard let url = object as? NSURL else { return nil }
            return url as URL
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Locked means drag-dead: do not involve the Drop CI and do not hand the drag
        // to SwiftUI/NSHostingView. Licensed + Drop-disabled is different: descendants
        // such as File Shelf may still own their own drop destinations.
        guard hasCommercialAccess else { rejectFileDrop(); return [] }
        guard acceptsFileDrop else { return super.draggingEntered(sender) }

        let count = fileURLCount(sender)
        guard count > 0 else { return super.draggingEntered(sender) }
        dragStateHandler?(true, count)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard hasCommercialAccess else { rejectFileDrop(); return [] }
        guard acceptsFileDrop else { return super.draggingUpdated(sender) }

        let count = fileURLCount(sender)
        guard count > 0 else { return super.draggingUpdated(sender) }
        dragStateHandler?(true, count)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        guard hasCommercialAccess else {
            rejectFileDrop()
            return
        }
        guard acceptsFileDrop else {
            super.draggingExited(sender)
            return
        }
        dragStateHandler?(false, 0)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard hasCommercialAccess else {
            rejectFileDrop()
            return false
        }
        guard acceptsFileDrop else { return super.performDragOperation(sender) }

        let urls = fileURLs(sender)
        guard !urls.isEmpty else {
            dragStateHandler?(false, 0)
            return super.performDragOperation(sender)
        }
        dropHandler?(urls)
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        guard hasCommercialAccess else {
            rejectFileDrop()
            return
        }
        guard acceptsFileDrop else {
            super.concludeDragOperation(sender)
            return
        }
        dragStateHandler?(false, 0)
    }
}

@MainActor
final class SurfaceAnimator {
    private enum HorizontalResizeAnchor { case left, right, center }

    private let clock = DisplayClock()
    func cancel() { clock.stop() }

    private func publishGeometry(panel: HaloPanel, frame: CGRect) {
        NotificationCenter.default.post(name: .init("HaloPanelGeometryChanged"), object: panel,
                                        userInfo: ["frame": frame])
    }

    private func syncClosedGeometry(state: SurfaceState, frame: CGRect, cameraFrame: CGRect?) {
        if state.compactWidth != frame.width { state.compactWidth = frame.width }
        if state.compactHeight != frame.height { state.compactHeight = frame.height }
        if state.viewport.size != frame.size { state.viewport.size = frame.size }

        let nextOcclusion: CGRect?
        if let cameraFrame {
            let overlap = cameraFrame.intersection(frame)
            if overlap.isNull || overlap.isEmpty {
                nextOcclusion = nil
            } else {
                nextOcclusion = CGRect(x: overlap.minX - frame.minX, y: 0,
                                       width: overlap.width, height: overlap.height)
            }
        } else {
            nextOcclusion = nil
        }
        if state.closedOcclusion != nextOcclusion { state.closedOcclusion = nextOcclusion }
    }

    func move(panel: HaloPanel, state: SurfaceState, target: CGRect, options: SurfaceOptions,
              preset: AnimationPreset, animations: Bool, opening: Bool, style: SurfaceStyle,
              liveViewportResize: Bool = true, fixedHorizontalEdge: CGRectEdge? = nil,
              synchronizeClosedGeometry: Bool = false, closedCameraFrame: CGRect? = nil) {
        cancel()
        let transition = opening ? options.opening : options.closing
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        guard animations, !reduceMotion, preset != .none, transition != .instant else {
            panel.alphaValue = 1
            if synchronizeClosedGeometry {
                syncClosedGeometry(state: state, frame: target, cameraFrame: closedCameraFrame)
            } else {
                state.viewport.size = target.size
            }
            panel.setFrame(target, display: false)
            publishGeometry(panel: panel, frame: target)
            return
        }
        let initial = panel.frame
        let initialAlpha = panel.alphaValue
        let start = CACurrentMediaTime()
        let duration = options.duration
        guard let view = panel.contentView else {
            if synchronizeClosedGeometry {
                syncClosedGeometry(state: state, frame: target, cameraFrame: closedCameraFrame)
            } else {
                state.viewport.size = target.size
            }
            panel.setFrame(target, display: false)
            publishGeometry(panel: panel, frame: target)
            return
        }

        let horizontalAnchor: HorizontalResizeAnchor = {
            switch fixedHorizontalEdge {
            case .minXEdge?: return .left
            case .maxXEdge?: return .right
            default: break
            }
            guard !liveViewportResize, abs(target.width - initial.width) > 0.5 else { return .center }
            let leftMovement = abs(target.minX - initial.minX)
            let rightMovement = abs(target.maxX - initial.maxX)
            let tolerance: CGFloat = 0.75
            if leftMovement <= tolerance && rightMovement > tolerance { return .left }
            if rightMovement <= tolerance && leftMovement > tolerance { return .right }
            return .center
        }()

        clock.start(view: view) { [weak self, weak panel, weak state] timestamp in
            guard let self, let panel, let state else { self?.cancel(); return }
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

            if t >= 1 {
                frame = target
                panel.alphaValue = 1
            }

            if synchronizeClosedGeometry {
                self.syncClosedGeometry(state: state, frame: frame, cameraFrame: closedCameraFrame)
            } else if liveViewportResize, state.viewport.size != frame.size {
                state.viewport.size = frame.size
            }

            panel.setFrame(frame, display: false)
            self.publishGeometry(panel: panel, frame: frame)

            if t >= 1 { self.clock.stop() }
        }
    }
}

@MainActor
final class WindowManager {
    @MainActor private final class Host {
        let panel: HaloPanel
        let ambientPanel: NSPanel
        let geometryEditorPanel: NSPanel
        let state = SurfaceState()
        let animator = SurfaceAnimator()
        var geometry: SurfaceGeometry?
        var targetFrame: CGRect?
        var subscription: AnyCancellable?
        var contextSizeSubscription: AnyCancellable?
        var contextCompactSizeSubscription: AnyCancellable?
        var contextCompactHeightSubscription: AnyCancellable?
        var refreshDropCIRegistration: (() -> Void)?
        var pixelPalCollapseWork: DispatchWorkItem?
        init() {
            panel = HaloPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = true
            panel.hidesOnDeactivate = false; panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            ambientPanel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            ambientPanel.isReleasedWhenClosed = false
            ambientPanel.backgroundColor = .clear; ambientPanel.isOpaque = false; ambientPanel.hasShadow = false
            ambientPanel.hidesOnDeactivate = false; ambientPanel.level = .statusBar
            ambientPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            ambientPanel.ignoresMouseEvents = true
            ambientPanel.acceptsMouseMovedEvents = false
            ambientPanel.animationBehavior = .none

            geometryEditorPanel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            geometryEditorPanel.isReleasedWhenClosed = false
            geometryEditorPanel.backgroundColor = .clear
            geometryEditorPanel.isOpaque = false
            geometryEditorPanel.hasShadow = false
            geometryEditorPanel.hidesOnDeactivate = false
            geometryEditorPanel.level = .statusBar
            geometryEditorPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            geometryEditorPanel.ignoresMouseEvents = false
            geometryEditorPanel.acceptsMouseMovedEvents = true
            geometryEditorPanel.animationBehavior = .none
        }
        func stop() {
            animator.cancel(); state.hoverExpandTask?.cancel(); state.collapseTask?.cancel(); state.dropExitTask?.cancel()
            pixelPalCollapseWork?.cancel()
            subscription?.cancel(); contextSizeSubscription?.cancel(); contextCompactSizeSubscription?.cancel(); contextCompactHeightSubscription?.cancel()
            panel.close(); ambientPanel.close(); geometryEditorPanel.close()
        }
    }

    private enum DynamicSide { case left, right }
    private struct HUDNotchExpansion {
        var side: HaloHUDNotchSide
        var width: Double
        var height: Double
        var vertical: Bool
        var screenFrame: CGRect
        var kind: HaloHUDEventKind
        var collision: HaloHUDCollisionBehavior
        var persistent: Bool
    }

    private var activityExpiry: DispatchWorkItem?
    private var mediaWidthHint: Double?
    private var hudNotchExpansion: HUDNotchExpansion?
    private var hudNotchHideWork: DispatchWorkItem?
    private var hudMonitor: Any?
    private var lastHUDCapsLock = false
    private let store: AppStore
    private let startupActivationContext: ActivationLaunchContext
    private var commercialAccessGranted = false
    private var initialActivationPending = false
    private var hosts: [String: Host] = [:]
    private var subscriptions = Set<AnyCancellable>()
    private var lastContextOffset = CGSize(
        width: UserDefaults.standard.double(forKey: "HaloContextOffsetX"),
        height: UserDefaults.standard.double(forKey: "HaloContextOffsetY")
    )

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
    init(store: AppStore,
         startupActivationContext: ActivationLaunchContext = ActivationLaunchContext(event: .manualLaunch, macJustStarted: false)) {
        self.store = store
        self.startupActivationContext = startupActivationContext
    }

    private var dropCISettingEnabled: Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: "HaloContextDropEnabled") == nil
            ? true
            : defaults.bool(forKey: "HaloContextDropEnabled")
    }

    private var dropCIAllowed: Bool {
        commercialAccessGranted && dropCISettingEnabled
    }

    func setCommercialAccessGranted(_ granted: Bool) {
        guard commercialAccessGranted != granted else { return }
        commercialAccessGranted = granted

        hosts.values.forEach { host in
            host.state.setFileDropAllowed(dropCIAllowed)
            host.refreshDropCIRegistration?()
            if !granted {
                // Licensing is a hard boundary, not a normal drag-exit lifecycle.
                // Remove Drop ownership synchronously so no locked surface can retain it.
                host.state.cancelFileDrop()
            }
        }
    }

    func start() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main).sink { [weak self] _ in self?.reconcile() }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: .init("HaloPreviewActivationSequence"))
            .receive(on: RunLoop.main).sink { [weak self] _ in self?.previewActivation() }.store(in: &subscriptions)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main).sink { [weak self] _ in
                self?.playActivation(context: ActivationLaunchContext(event: .wake, macJustStarted: false))
            }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(80), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let defaults = UserDefaults.standard
                self.hosts.values.forEach { host in
                    host.state.setFileDropAllowed(self.dropCIAllowed)
                    host.refreshDropCIRegistration?()
                    if !self.dropCIAllowed && host.state.dropTargeted {
                        host.state.endFileDrop(collapseAfterDelay: true)
                    }
                }
                let next = CGSize(width: defaults.double(forKey: "HaloContextOffsetX"),
                                  height: defaults.double(forKey: "HaloContextOffsetY"))
                guard abs(next.width - self.lastContextOffset.width) >= 0.5 ||
                      abs(next.height - self.lastContextOffset.height) >= 0.5 else { return }
                self.lastContextOffset = next
                self.reconcile()
            }
            .store(in: &subscriptions)
        store.$configuration.dropFirst().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reconcile() }.store(in: &subscriptions)
        NotchAmbientStore.shared.$settings.dropFirst().removeDuplicates()
            .debounce(for: .milliseconds(45), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.reconcile() }.store(in: &subscriptions)
        store.workspace.$settings.map { [store] settings in
            let layout = settings.profiles.first { $0.id == store.workspace.scheduledProfileID }?.layout ?? settings.layout
            let resolvedDisplays = settings.displays.map { item -> DisplayOverride in
                guard let profileID = item.profileID, let profile = settings.profiles.first(where: { $0.id == profileID }) else { return item }
                var resolved = item
                resolved.theme = profile.theme
                resolved.layout = profile.layout
                return resolved
            }
            return SurfaceRenderConfiguration(
                appearance: layout.appearance,
                displays: resolvedDisplays,
                closedNotch: layout.closedNotch,
                clock: layout.widgetStyle(for: .clock),
                horizontalWidgets: layout.horizontalWidgets,
                horizontalPages: layout.horizontalPages,
                horizontalHeight: layout.horizontalHeight,
                openNotchContentMode: layout.openNotchContentMode,
                openHorizontalPadding: layout.openHorizontalPadding,
                openVerticalPadding: layout.openVerticalPadding,
                openFixedColumns: layout.openFixedColumns
            )
        }
            .removeDuplicates().dropFirst()
            .throttle(for: .milliseconds(33), scheduler: DispatchQueue.main, latest: true)
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
                DispatchQueue.main.async { self?.refreshGeometryEditorPanels() }
            }.store(in: &subscriptions)
        SurfaceGeometryEditingSession.shared.$previewSnapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.applyGeometryEditorPreview(snapshot)
            }
            .store(in: &subscriptions)
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

        HaloHUDNotchBridge.shared.$presentation.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] presentation in
                guard let self else { return }
                if let presentation {
                    let notch = presentation.configuration.presentation.resolvedNotch
                    let vertical = notch.usesVerticalExpansion
                    let reservedWidth = vertical ? 0 : notch.width + max(12, notch.horizontalPadding * 2) + abs(notch.horizontalOffset)
                    self.hudNotchExpansion = HUDNotchExpansion(
                        side: presentation.side,
                        width: reservedWidth,
                        height: notch.resolvedVerticalHeight,
                        vertical: vertical,
                        screenFrame: presentation.screenFrame,
                        kind: presentation.event.kind,
                        collision: presentation.configuration.behavior.collision,
                        persistent: presentation.persistent
                    )
                } else {
                    self.hudNotchExpansion = nil
                }
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

        let shouldHideInitialFrame = ActivationSequenceCoordinator.shared.shouldPlay(startupActivationContext)
        initialActivationPending = shouldHideInitialFrame
        reconcile()
        guard shouldHideInitialFrame else { return }
        // Let SwiftUI mount at the already-final closed geometry while the panel is transparent.
        // The presentation is then published before the panel becomes visible, avoiding a one-frame
        // normal-notch flash on cold launch.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.playActivation(context: self.startupActivationContext)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.initialActivationPending = false
                self.hosts.values.forEach { $0.panel.alphaValue = 1 }
            }
        }
    }

    private var activeClosedActivity: LiveActivity? {
        store.workspace.activities.first { activity in
            (activity.progress.map { $0 < 1 } ?? false) || activity.created.addingTimeInterval(12) > Date()
        }
    }

    private func physicalCameraFrame(for geometry: SurfaceGeometry) -> CGRect? {
        guard geometry.safeAreaTop > 0, geometry.physicalNotchWidth > 0 else { return nil }
        return CGRect(x: geometry.screen.midX - geometry.physicalNotchWidth / 2,
                      y: geometry.screen.maxY - geometry.safeAreaTop,
                      width: geometry.physicalNotchWidth,
                      height: geometry.safeAreaTop)
    }

    private func hudScreen(for configuration: HaloHUDConfiguration) -> NSScreen? {
        switch configuration.presentation.displayTarget {
        case .builtIn:
            return NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens.first
        case .main:
            return NSScreen.main ?? NSScreen.screens.first
        case .active:
            return NSScreen.main ?? hudMouseScreen()
        case .mouse:
            return hudMouseScreen()
        }
    }

    private func hudMouseScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func resolvedHUDNotchSide(_ requested: HaloHUDNotchSide) -> HaloHUDNotchSide {
        guard requested == .automatic else { return requested }
        let closed = store.workspace.effectiveLayout.closedNotch ?? ClosedNotchOptions()
        let leftBusy = closed.left != .none
        let rightBusy = closed.right != .none
        if !rightBusy { return .right }
        if !leftBusy { return .left }
        return .right
    }

    private func hudNotchOccupied(_ side: HaloHUDNotchSide) -> Bool {
        let closed = store.workspace.effectiveLayout.closedNotch ?? ClosedNotchOptions()
        switch side {
        case .left: return closed.left != .none
        case .right: return closed.right != .none
        case .full: return closed.left != .none || closed.right != .none
        case .automatic: return false
        }
    }

    private func resolvedHUDConfiguration(kind: HaloHUDEventKind) -> HaloHUDConfiguration? {
        let settings = store.workspace.effectiveLayout.hud ?? HaloHUDSettings()
        guard settings.enabled, settings.isEnabled(kind) else { return nil }
        var configuration = settings.configuration(for: kind)
        let bundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        if let rule = settings.appRules.first(where: { $0.enabled && !$0.bundleIdentifier.isEmpty && $0.bundleIdentifier == bundle }) {
            configuration.presentation.target = rule.target
        }
        return configuration
    }

    private func triggerHUDNotch(kind: HaloHUDEventKind, suppliedConfiguration: HaloHUDConfiguration? = nil,
                                 persistent: Bool = false) {
        let configuration: HaloHUDConfiguration
        if let suppliedConfiguration {
            configuration = suppliedConfiguration
        } else if let resolved = resolvedHUDConfiguration(kind: kind) {
            configuration = resolved
        } else {
            if hudNotchExpansion?.kind == kind { clearHUDNotchExpansion() }
            return
        }

        guard configuration.presentation.target == .notch,
              let screen = hudScreen(for: configuration),
              screen.safeAreaInsets.top > 0 else {
            if hudNotchExpansion?.kind == kind { clearHUDNotchExpansion() }
            return
        }

        let side = resolvedHUDNotchSide(configuration.presentation.notchSide)
        if configuration.behavior.collision == .showExternally && hudNotchOccupied(side) {
            if hudNotchExpansion?.kind == kind { clearHUDNotchExpansion() }
            return
        }

        let notch = configuration.presentation.resolvedNotch
        let outwardOffset: Double
        switch side {
        case .left: outwardOffset = max(0, -notch.horizontalOffset)
        case .right: outwardOffset = max(0, notch.horizontalOffset)
        case .full, .automatic: outwardOffset = abs(notch.horizontalOffset)
        }
        let vertical = notch.usesVerticalExpansion
        let width = vertical ? 0 : notch.width + outwardOffset
        let repeatedContinue = hudNotchExpansion?.kind == kind &&
            configuration.behavior.interrupt == .continue && hudNotchHideWork != nil

        hudNotchExpansion = HUDNotchExpansion(side: side, width: width,
                                              height: notch.resolvedVerticalHeight,
                                              vertical: vertical,
                                              screenFrame: screen.frame, kind: kind,
                                              collision: configuration.behavior.collision,
                                              persistent: persistent)
        refreshDynamicWidths()

        if persistent {
            hudNotchHideWork?.cancel(); hudNotchHideWork = nil
            return
        }
        if repeatedContinue { return }
        hudNotchHideWork?.cancel()
        let delay = min(12, max(0.2, configuration.behavior.displayDuration + configuration.animation.exitDuration))
        let work = DispatchWorkItem { [weak self] in self?.clearHUDNotchExpansion() }
        hudNotchHideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func clearHUDNotchExpansion() {
        hudNotchHideWork?.cancel(); hudNotchHideWork = nil
        guard hudNotchExpansion != nil else { return }
        hudNotchExpansion = nil
        refreshDynamicWidths()
    }

    private func refreshActiveHUDNotchConfiguration() {
        guard let active = hudNotchExpansion else { return }
        triggerHUDNotch(kind: active.kind, persistent: active.persistent)
    }

    private func handleHUDKey(_ key: Int) {
        switch key {
        case 0, 1: triggerHUDNotch(kind: .volume)
        case 7: triggerHUDNotch(kind: .mute)
        case 2, 3: triggerHUDNotch(kind: .displayBrightness)
        case 21, 22, 23: triggerHUDNotch(kind: .keyboardBrightness)
        default: break
        }
    }

    private func handleHUDObservedEvent(_ event: NSEvent) {
        if event.type == .flagsChanged {
            let caps = event.modifierFlags.contains(.capsLock)
            guard caps != lastHUDCapsLock else { return }
            lastHUDCapsLock = caps
            triggerHUDNotch(kind: .capsLock)
            return
        }
        guard event.type == .systemDefined, event.subtype.rawValue == 8 else { return }
        let data = event.data1
        let key = (data & 0xFFFF0000) >> 16
        let keyState = ((data & 0xFFFF) & 0xFF00) >> 8
        guard keyState == 0xA else { return }
        handleHUDKey(key)
    }

    private func handleHUDPreview(_ note: Notification) {
        let raw = note.userInfo?["kind"] as? String ?? "volume"
        let kind: HaloHUDEventKind
        switch raw {
        case "brightness": kind = .displayBrightness
        case "keyboard": kind = .keyboardBrightness
        default: kind = HaloHUDEventKind(rawValue: raw) ?? .volume
        }
        let persistent = note.userInfo?["persistent"] as? Bool ?? false
        if let configuration = note.userInfo?["configuration"] as? HaloHUDConfiguration {
            triggerHUDNotch(kind: kind, suppliedConfiguration: configuration, persistent: persistent)
        } else {
            triggerHUDNotch(kind: kind, persistent: persistent)
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
                               items: (left: ClosedNotchItem, right: ClosedNotchItem),
                               compactHeight: Double)
        -> (side: DynamicSide, badgeWidth: Double, notchMargin: Double, extraSpace: Double)? {
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

        let playing = store.workspace.media.isPlaying
        let side: DynamicSide
        switch settings.side {
        case .left: side = .left
        case .right: side = .right
        case .automatic:
            let rightFree = items.right == .none || ((items.right == .media || items.right == .visualizer) && !playing)
            let leftFree = items.left == .none || ((items.left == .media || items.left == .visualizer) && !playing)
            if rightFree { side = .right }
            else if leftFree { side = .left }
            else { side = .right }
        }

        let metrics = ClosedNotchLayoutMetrics(options: options, height: compactHeight)
        let innerHeight = metrics.contentHeight
        let baseSize = min(options.fontSize, innerHeight / 1.25)
        let size = min(baseSize, max(9, innerHeight * 0.46))
        let normalFont = NSFont.systemFont(ofSize: size, weight: .semibold)
        let digitFont = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .semibold)
        func textWidth(_ value: String, font: NSFont) -> Double {
            ceil((value as NSString).size(withAttributes: [.font: font]).width)
        }
        let iconWidth = max(12, size + 2)
        let labelGap = 4.0
        let horizontalInset = 2.0
        let naturalWidth: Double
        switch style {
        case .off: naturalWidth = 0
        case .icon: naturalWidth = iconWidth + horizontalInset
        case .percent: naturalWidth = textWidth("\(battery)%", font: digitFont) + horizontalInset
        case .iconPercent:
            naturalWidth = iconWidth + labelGap + textWidth("\(battery)%", font: digitFont) + horizontalInset
        case .label:
            naturalWidth = iconWidth + labelGap + textWidth(eventLabel, font: normalFont) + horizontalInset
        }
        let badgeWidth = max(16, naturalWidth)

        func itemIsVisible(_ item: ClosedNotchItem) -> Bool {
            switch item {
            case .none: return false
            case .media, .visualizer: return playing
            case .activity: return activeClosedActivity != nil
            default: return true
            }
        }
        let targetItem = side == .left ? items.left : items.right
        let targetDecoration = side == .left ? options.leftDecoration : options.rightDecoration
        var artwork = options.artworkOptions ?? ClosedArtworkOptions()
        if options.artworkOptions == nil, let legacy = options.mediaOptions, legacy.artwork != .none {
            artwork.enabled = true; artwork.mode = legacy.artwork; artwork.size = legacy.artworkSize
        }
        let hasArtworkSibling: Bool = {
            guard playing, artwork.enabled, artwork.mode != .none, artwork.mode != .background else { return false }
            switch artwork.side {
            case .left: return side == .left
            case .right: return side == .right
            case .automatic:
                if options.left == .media || options.left == .visualizer { return side == .left }
                if options.right == .media || options.right == .visualizer { return side == .right }
                return side == .right
            }
        }()
        let hasSibling = itemIsVisible(targetItem) ||
            (targetDecoration?.isVisible(playing: playing) ?? false) || hasArtworkSibling
        let extraSpace = settings.expandForEvent && !hasSibling ? settings.resolvedExtraEventSpace : 0
        return (side, badgeWidth, settings.resolvedNotchMargin, extraSpace)
    }

    private func configureDynamicWidth(_ host: Host) {
        guard host.geometry != nil else { return }
        host.geometry?.activeCompactHeight = nil
        guard let geometry = host.geometry else { return }
        let layout = host.state.layoutOverride ?? store.workspace.effectiveLayout
        let options = layout.closedNotch ?? ClosedNotchOptions()
        let expansion = options.expansion ?? ClosedExpansionOptions()
        let closedMetrics = ClosedNotchLayoutMetrics(options: options, height: geometry.appearance.surface.compactHeight)
        let items = resolvedClosedItems(options)
        let power = powerReaction(options: options, items: items,
                                  compactHeight: geometry.appearance.surface.compactHeight)
        let sides = fittedClosedSides(host: host, layout: layout, items: items, power: power)
        var leftLive = sideHasLiveReason(item: items.left, decoration: options.leftDecoration)
        var rightLive = sideHasLiveReason(item: items.right, decoration: options.rightDecoration)

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
        // Generic active-width expansion belongs to normal live content. Power events have
        // their own explicit eventWidth and must not inherit the generic Active width as well.
        let leftExpansionLive = leftLive
        let rightExpansionLive = rightLive
        if power?.side == .left { leftLive = true }
        if power?.side == .right { rightLive = true }

        let attached = geometry.attachedToNotch && geometry.physicalNotchWidth > 0
        let notchLike = attached || geometry.style == .notch || geometry.style == .simulated
        let camera = attached ? geometry.physicalNotchWidth : 0
        let baseWidth = max(16, geometry.appearance.compactWidth)
        let autoFit = options.autoFitContent ?? true
        let verticalHUD = hudNotchExpansion.flatMap { $0.screenFrame.equalTo(geometry.screen) && $0.vertical ? $0 : nil }

        guard !host.state.editingGeometry else {
            host.geometry?.activeCompactWidth = nil
            host.geometry?.activeCompactHeight = nil
            host.geometry?.activeCompactCenterOffset = nil
            return
        }

        if notchLike {
            var leftDemand = autoFit ? sides.left : sides.decorationLeft
            var rightDemand = autoFit ? sides.right : sides.decorationRight
            // Transient power events must remain readable even when global auto-fit is disabled.
            if let power {
                if power.side == .left { leftDemand = max(leftDemand, sides.left) }
                else { rightDemand = max(rightDemand, sides.right) }
            }

            if let hud = hudNotchExpansion, hud.screenFrame.equalTo(geometry.screen), !hud.vertical {
                let hudGap = closedMetrics.elementSpacing
                let shell = closedMetrics.normalShell
                func merged(_ existing: Double, _ hudBodyWidth: Double) -> Double {
                    switch hud.collision {
                    case .replace:
                        return hudBodyWidth + shell
                    case .push, .queue, .showExternally:
                        return existing > 0 ? existing + hudGap + hudBodyWidth : hudBodyWidth + shell
                    case .overlay:
                        return max(existing, hudBodyWidth + shell)
                    }
                }
                switch hud.side {
                case .left:
                    leftDemand = merged(leftDemand, hud.width)
                    leftLive = true
                case .right:
                    rightDemand = merged(rightDemand, hud.width)
                    rightLive = true
                case .full:
                    let half = hud.width / 2
                    leftDemand = merged(leftDemand, half)
                    rightDemand = merged(rightDemand, half)
                    leftLive = true
                    rightLive = true
                case .automatic:
                    rightDemand = merged(rightDemand, hud.width)
                    rightLive = true
                }
            }

            let extents = ClosedWingSizing.extents(
                base: baseWidth, camera: camera,
                left: leftDemand,
                right: rightDemand,
                expansion: expansion.enabled ? expansion.width : 0,
                leftLive: leftExpansionLive, rightLive: rightExpansionLive)
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
            if autoFit || power != nil { requested = max(requested, sides.left + sides.right) }
            if expansion.enabled && (leftExpansionLive || rightExpansionLive) { requested = max(requested, expansion.width) }
            host.geometry?.activeCompactWidth = min(geometry.visible.width, requested)
            host.geometry?.activeCompactCenterOffset = nil
        }

        if let verticalHUD {
            let baseHeight = max(16, geometry.appearance.surface.compactHeight)
            host.geometry?.activeCompactHeight = min(220, max(baseHeight, verticalHUD.height))
        }
    }

    private func fittedClosedSides(host: Host, layout: WorkspaceLayout,
                                   items: (left: ClosedNotchItem, right: ClosedNotchItem),
                                   power: (side: DynamicSide, badgeWidth: Double, notchMargin: Double, extraSpace: Double)?) ->
        (left: Double, right: Double, decorationLeft: Double, decorationRight: Double) {
        guard let geometry = host.geometry else { return (0, 0, 0, 0) }
        let options = layout.closedNotch ?? ClosedNotchOptions()
        let playing = store.workspace.media.isPlaying
        let activity = activeClosedActivity
        let baseCompactHeight = max(16, geometry.appearance.surface.compactHeight)
        let metrics = ClosedNotchLayoutMetrics(options: options, height: baseCompactHeight)
        let innerHeight = metrics.contentHeight
        let size = min(options.fontSize, innerHeight / 1.25)
        let font = NSFont.systemFont(ofSize: size)
        let digitFont = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .regular)
        let elementGap = metrics.elementSpacing

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
            let artistValue = store.workspace.media.artist.isEmpty ? store.workspace.media.title : store.workspace.media.artist
            let artist = textWidth(String(artistValue.prefix(120)), font: font)
            let adaptive = media.textMode == .lyrics && media.usesDynamicLyricWidth && mediaWidthHint != nil

            let usesInlineIcon: Bool = {
                guard media.showPlaybackIcon else { return false }
                switch media.textMode {
                case .title, .artist: return true
                case .titleArtist: return media.lines == 1
                case .lyrics:
                    switch media.resolvedLyricDisplay {
                    case .word: return true
                    case .line: return media.lines == 1
                    case .focus: return false
                    }
                }
            }()
            let icon = usesInlineIcon ? max(12, size + 2) + elementGap : 0

            let naturalText: Double
            switch media.textMode {
            case .title: naturalText = title
            case .artist: naturalText = artist
            case .titleArtist:
                naturalText = media.lines == 2
                    ? max(title, artist)
                    : title + (store.workspace.media.artist.isEmpty ? 0 : artist + textWidth(" · ", font: font))
            case .lyrics:
                naturalText = adaptive ? max(28, mediaWidthHint!) : max(90, min(220, title + artist * 0.35))
            }

            if adaptive { return min(320, max(28, naturalText)) }
            let naturalTotal = naturalText + icon
            switch media.overflow {
            case .marquee, .truncate:
                return min(max(24, naturalTotal), media.resolvedHorizontalSpace)
            case .scale:
                return min(max(24, naturalTotal), 260)
            }
        }

        func bluetoothActivityWidth(_ activity: LiveActivity) -> Double? {
            let label: String
            switch activity.title {
            case "Bluetooth connected": label = "Connected"
            case "Bluetooth disconnected": label = "Disconnected"
            case "Bluetooth on": label = "Bluetooth On"
            case "Bluetooth off": label = "Bluetooth Off"
            default: return nil
            }

            let defaults = UserDefaults.standard
            func boolValue(_ key: String, fallback: Bool) -> Bool {
                defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
            }
            let showIcon = boolValue("HaloBluetoothClosedNotchShowIcon", fallback: true)
            let showLabel = boolValue("HaloBluetoothClosedNotchShowLabel", fallback: true)
            let showDevice = boolValue("HaloBluetoothClosedNotchShowDevice", fallback: true)
            let layoutRaw = defaults.string(forKey: "HaloBluetoothClosedNotchLayout") ?? BluetoothClosedNotchLayout.stacked.rawValue
            let layout = BluetoothClosedNotchLayout(rawValue: layoutRaw) ?? .stacked
            let configuredIcon = defaults.object(forKey: "HaloBluetoothClosedNotchIconSize") == nil
                ? 16.0 : defaults.double(forKey: "HaloBluetoothClosedNotchIconSize")
            let iconSize = min(max(8, configuredIcon), max(8, size * 1.8))
            let iconWidth = showIcon ? max(12, iconSize + 2) : 0
            let labelWidth = showLabel ? textWidth(label, font: font) : 0
            let detailFont = NSFont.systemFont(ofSize: max(8, size * 0.76))
            let detailWidth = showDevice && !activity.detail.isEmpty
                ? textWidth(String(activity.detail.prefix(80)), font: detailFont) : 0

            func inlineTextWidth() -> Double {
                let parts = [labelWidth, detailWidth].filter { $0 > 0 }
                guard !parts.isEmpty else { return 0 }
                return parts.reduce(0, +) + Double(max(0, parts.count - 1)) * elementGap
            }
            let stackedText = max(labelWidth, detailWidth)

            switch layout {
            case .iconOnly:
                return iconWidth
            case .textOnly:
                return stackedText
            case .inline:
                let text = inlineTextWidth()
                if iconWidth > 0 && text > 0 { return iconWidth + elementGap + text }
                return max(iconWidth, text)
            case .stacked:
                if iconWidth > 0 && stackedText > 0 { return iconWidth + elementGap + stackedText }
                return max(iconWidth, stackedText)
            }
        }

        func isArtworkOnly(_ side: DynamicSide, item: ClosedNotchItem) -> Bool {
            guard artwork.isArtworkOnly, artworkTarget == side else { return false }
            return item == .media || item == .visualizer
        }

        func itemWidth(_ side: DynamicSide, _ item: ClosedNotchItem) -> Double {
            if isArtworkOnly(side, item: item) { return 0 }
            switch item {
            case .none: return 0
            case .clock:
                let style = layout.widgetStyle(for: .clock)
                let clockFont = style.fontFamily == .custom
                    ? NSFont(name: style.customFont, size: size) ?? font
                    : NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium)
                let template = "88:88" + (style.clock.showSeconds ? ":88" : "") + (style.clock.twentyFourHour ? "" : " PM")
                return textWidth(template, font: clockFont) * 1.04
            case .date:
                return textWidth("Sep 28", font: font)
            case .timer:
                if store.deadline != nil { return textWidth("88:88:88", font: digitFont) }
                let label = store.pausedSeconds > 0 ? "Paused" : store.finished ? "Done" : "Ready"
                return max(12, size + 2) + elementGap + textWidth(label, font: font)
            case .battery:
                guard let battery = store.workspace.system.battery else { return max(12, size + 2) }
                return max(12, size + 2) + elementGap + textWidth("\(battery)%", font: digitFont)
            case .media:
                return mediaWidth()
            case .visualizer:
                return playing ? (options.visualizer ?? VisualizerOptions()).width : 0
            case .mirror:
                return 112
            case .files:
                return max(12, size + 2) + elementGap + textWidth(String(store.files.count), font: digitFont)
            case .activity:
                guard let activity else { return 0 }
                if let bluetooth = bluetoothActivityWidth(activity) { return min(240, max(0, bluetooth)) }
                let title = textWidth(String(activity.title.prefix(80)), font: font)
                let detailFont = NSFont.systemFont(ofSize: max(8, size * 0.76))
                let detail = activity.detail.isEmpty ? 0 : textWidth(String(activity.detail.prefix(80)), font: detailFont)
                let icon = max(12, size)
                let text = max(title, detail)
                let progress = activity.progress == nil ? 0 : elementGap + 38
                return min(240, icon + elementGap + text + progress + 2)
            }
        }

        func decorationWidth(_ decoration: SideDecoration?) -> Double {
            decoration.flatMap {
                $0.isVisible(playing: playing) ? min($0.size, innerHeight) : nil
            } ?? 0
        }

        func append(_ width: Double, to body: inout Double) {
            guard width > 0 else { return }
            if body > 0 { body += elementGap }
            body += width
        }

        var leftBody = itemWidth(.left, items.left)
        var rightBody = itemWidth(.right, items.right)
        let leftDecoration = decorationWidth(options.leftDecoration)
        let rightDecoration = decorationWidth(options.rightDecoration)
        append(leftDecoration, to: &leftBody)
        append(rightDecoration, to: &rightBody)

        if let artworkTarget {
            let renderedArtworkSize = max(1, min(artwork.size, innerHeight - 2 * artwork.padding))
            let artworkWidth = renderedArtworkSize + 2 * artwork.padding + artwork.margin
            if artworkTarget == .left { append(artworkWidth, to: &leftBody) }
            else { append(artworkWidth, to: &rightBody) }
        }

        if let power {
            let powerWidth = power.badgeWidth + power.extraSpace
            if power.side == .left { append(powerWidth, to: &leftBody) }
            else { append(powerWidth, to: &rightBody) }
        }

        func fullWidth(body: Double, powerOnSide: Bool) -> Double {
            guard body > 0 else { return 0 }
            let cameraInset = powerOnSide && power != nil ? power!.notchMargin : metrics.normalCameraInset
            return body + cameraInset + metrics.outerInset
        }

        let leftFull = fullWidth(body: leftBody, powerOnSide: power?.side == .left)
        let rightFull = fullWidth(body: rightBody, powerOnSide: power?.side == .right)
        let leftDecorationFull = leftDecoration > 0 ? leftDecoration + metrics.normalShell : 0
        let rightDecorationFull = rightDecoration > 0 ? rightDecoration + metrics.normalShell : 0
        return (leftFull, rightFull, leftDecorationFull, rightDecorationFull)
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
            let oldHeight = host.geometry?.compactHeight
            let oldOffset = host.geometry?.activeCompactCenterOffset ?? 0
            configureDynamicWidth(host)
            guard let geometry = host.geometry else { continue }
            updateAmbientPanelFrame(host: host, geometry: geometry)
            let newWidth = geometry.compactWidth
            let newHeight = geometry.compactHeight
            let newOffset = geometry.activeCompactCenterOffset ?? 0

            guard !host.state.expanded else {
                host.state.compactWidth = newWidth
                host.state.compactHeight = newHeight
                host.state.closedOcclusion = geometry.closedCameraOcclusion
                continue
            }

            var target = (host.state.contextPreferredCompactWidth != nil || host.state.contextPreferredCompactHeight != nil)
                ? targetFrame(host: host, expanded: false)
                : geometry.frame(expanded: false)
            if geometry.style == .detached {
                target.origin.x = host.panel.frame.midX - target.width / 2
                target.origin.y = host.panel.frame.maxY - target.height
            }

            let geometryChanged = oldWidth != newWidth || oldHeight != newHeight || oldOffset != newOffset
            let frameChanged = host.targetFrame.map { old in
                abs(old.minX - target.minX) >= 0.5 || abs(old.minY - target.minY) >= 0.5 ||
                abs(old.width - target.width) >= 0.5 || abs(old.height - target.height) >= 0.5
            } ?? true
            guard geometryChanged || frameChanged else { continue }

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
                return nil
            }()

            host.targetFrame = target
            var motion = geometry.appearance.surface
            motion.opening = .resize
            motion.closing = .resize
            motion.duration = min(1.2, max(0.10, motion.duration))
            host.animator.move(panel: host.panel, state: host.state, target: target, options: motion,
                               preset: geometry.appearance.animation,
                               animations: host.state.theme.animations && !host.state.editingGeometry,
                               opening: true, style: geometry.style, liveViewportResize: true,
                               fixedHorizontalEdge: fixedEdge,
                               synchronizeClosedGeometry: true,
                               closedCameraFrame: physicalCameraFrame(for: geometry))
        }
    }

    func stop() {
        activityExpiry?.cancel()
        hudNotchHideWork?.cancel(); hudNotchHideWork = nil
        if let hudMonitor { NSEvent.removeMonitor(hudMonitor); self.hudMonitor = nil }
        hosts.values.forEach { $0.stop() }
        hosts.removeAll()
        subscriptions.removeAll()
    }

    func toggleAll() {
        let expand = !hosts.values.contains { $0.state.expanded }
        hosts.values.forEach { $0.state.collapseTask?.cancel(); $0.state.expanded = expand }
    }

    private func adjustedExpandedFrame(host: Host, requested: CGSize?) -> CGRect {
        guard let geometry = host.geometry else { return .zero }
        let base = geometry.frame(expanded: true)
        guard let requested, requested.width.isFinite, requested.height.isFinite else { return base }

        // Context views now report their complete content-safe size, including their
        // own horizontal/top/bottom margins. Adding a second safety shell here produced
        // visible dead space, especially below Music/Audio CI.
        let margin: CGFloat = 12
        let minimumHeight: CGFloat = 96
        let requestedMinimum = host.state.contextMinimumExpandedWidth ?? 360
        let physicalMinimum = geometry.attachedToNotch && geometry.physicalNotchWidth > 0
            ? geometry.physicalNotchWidth + 24 : 160
        let minimumWidth = max(160, max(requestedMinimum, physicalMinimum))
        let maxWidth = max(minimumWidth, geometry.visible.width - margin * 2)
        let width = min(maxWidth, max(minimumWidth, requested.width))
        var height = max(minimumHeight, requested.height)
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

    private func adjustedClosedFrame(host: Host, requestedWidth: CGFloat?, requestedHeight: CGFloat?) -> CGRect {
        guard let geometry = host.geometry else { return .zero }
        let base = geometry.frame(expanded: false)
        guard requestedWidth != nil || requestedHeight != nil else { return base }

        let margin: CGFloat = 8
        let physicalWidthFloor = geometry.attachedToNotch && geometry.physicalNotchWidth > 0
            ? geometry.physicalNotchWidth + 16 : 48
        let physicalHeightFloor = geometry.attachedToNotch && host.state.physicalNotchHeight > 0
            ? host.state.physicalNotchHeight : 16
        let maximumWidth = max(physicalWidthFloor, geometry.visible.width - margin * 2)
        let maximumHeight = min(220, max(physicalHeightFloor, geometry.visible.height - margin * 2))
        let desiredWidth = requestedWidth?.isFinite == true ? requestedWidth! : base.width
        let desiredHeight = requestedHeight?.isFinite == true ? requestedHeight! : base.height
        let width = min(maximumWidth, max(physicalWidthFloor, desiredWidth))
        let height = min(maximumHeight, max(physicalHeightFloor, desiredHeight))
        var frame: CGRect
        if geometry.style == .bottom {
            frame = CGRect(x: base.midX - width / 2, y: base.minY, width: width, height: height)
        } else {
            frame = CGRect(x: base.midX - width / 2, y: base.maxY - height, width: width, height: height)
        }
        if geometry.style == .left { frame.origin.x = base.minX }
        if geometry.style == .right { frame.origin.x = base.maxX - width }
        if frame.minX < geometry.visible.minX + margin { frame.origin.x = geometry.visible.minX + margin }
        if frame.maxX > geometry.visible.maxX - margin { frame.origin.x = geometry.visible.maxX - margin - width }
        return frame
    }

    private func targetFrame(host: Host, expanded: Bool) -> CGRect {
        guard let geometry = host.geometry else { return .zero }
        if host.state.editingGeometry {
            return geometry.frame(expanded: expanded)
        }
        return expanded
            ? adjustedExpandedFrame(host: host, requested: host.state.contextPreferredSize)
            : adjustedClosedFrame(host: host, requestedWidth: host.state.contextPreferredCompactWidth,
                                  requestedHeight: host.state.contextPreferredCompactHeight)
    }

    private func notchAmbientFrame(for geometry: SurfaceGeometry) -> CGRect {
        let settings = NotchAmbientStore.shared.settings.normalized()
        let closed = geometry.frame(expanded: false)
        let notchWidth = geometry.physicalNotchWidth > 0 ? geometry.physicalNotchWidth : min(190, closed.width)
        let notchHeight = geometry.safeAreaTop > 0 ? geometry.safeAreaTop : min(34, closed.height)
        let width = min(geometry.screen.width, max(320, notchWidth + settings.horizontalExtent * 2))
        let height = min(geometry.screen.height, max(100, notchHeight + settings.verticalExtent))
        let top = min(geometry.screen.maxY, closed.maxY)
        var x = closed.midX - width / 2
        x = min(max(geometry.screen.minX, x), geometry.screen.maxX - width)
        let y = max(geometry.screen.minY, top - height)
        return CGRect(x: x, y: y, width: width, height: min(height, top - y))
    }

    private func updateAmbientPanelFrame(host: Host, geometry: SurfaceGeometry) {
        let frame = notchAmbientFrame(for: geometry)
        if host.ambientPanel.frame != frame { host.ambientPanel.setFrame(frame, display: false) }
    }

    private func geometryEditorPanelFrame(around target: CGRect) -> CGRect {
        let naturalWidth = target.width + SurfaceGeometryEditorChromeMetrics.horizontal * 2
        let width = max(250, naturalWidth)
        return CGRect(
            x: target.midX - width / 2,
            y: target.minY - SurfaceGeometryEditorChromeMetrics.bottom,
            width: width,
            height: target.height + SurfaceGeometryEditorChromeMetrics.top + SurfaceGeometryEditorChromeMetrics.bottom
        )
    }

    private func refreshGeometryEditorPanels() {
        let session = SurfaceGeometryEditingSession.shared
        for (id, host) in hosts {
            let selected = session.isEnabled && (session.displayID == nil || session.displayID == id)
            guard selected else {
                if host.geometryEditorPanel.isVisible { host.geometryEditorPanel.orderOut(nil) }
                continue
            }
            let target = host.targetFrame ?? host.panel.frame
            let editorFrame = geometryEditorPanelFrame(around: target)
            if host.geometryEditorPanel.frame != editorFrame {
                host.geometryEditorPanel.setFrame(editorFrame, display: false)
            }
            if host.geometryEditorPanel.contentView != nil {
                host.geometryEditorPanel.order(.above, relativeTo: host.panel.windowNumber)
            }
        }
    }

    private func applyGeometryEditorPreview(_ snapshot: SurfaceGeometryEditSnapshot?) {
        let session = SurfaceGeometryEditingSession.shared
        guard session.isEnabled else {
            refreshGeometryEditorPanels()
            return
        }

        guard let snapshot else {
            reconcile()
            refreshGeometryEditorPanels()
            return
        }

        for (id, host) in hosts {
            guard session.displayID == nil || session.displayID == id,
                  let screen = NSScreen.screens.first(where: { Self.displayID($0) == id }),
                  let currentGeometry = host.geometry else { continue }

            var theme = host.state.theme
            theme.width = snapshot.expandedWidth
            theme.cornerRadius = snapshot.cornerRadius

            var appearance = currentGeometry.appearance
            appearance.compactWidth = snapshot.compactWidth
            appearance.surface.compactHeight = snapshot.compactHeight
            appearance.expandedHeight = snapshot.expandedHeight
            appearance.surface.offsets = snapshot.offsets
            appearance.surface = (try? appearance.surface.validated()) ?? appearance.surface

            let previewGeometry = Self.geometry(screen: screen, theme: theme, appearance: appearance)
            host.geometry = previewGeometry
            if host.state.theme != theme { host.state.theme = theme }

            configureDynamicWidth(host)
            let target = previewGeometry.frame(expanded: session.target.expanded)
            host.targetFrame = target
            host.animator.cancel()
            if host.state.viewport.size != target.size { host.state.viewport.size = target.size }

            if session.target == .closed {
                if host.state.compactWidth != target.width { host.state.compactWidth = target.width }
                if host.state.compactHeight != target.height { host.state.compactHeight = target.height }
                if host.state.closedOcclusion != previewGeometry.closedCameraOcclusion {
                    host.state.closedOcclusion = previewGeometry.closedCameraOcclusion
                }
            } else if host.state.dashboardWidth != target.width {
                host.state.dashboardWidth = target.width
            }

            if host.panel.frame != target { host.panel.setFrame(target, display: false) }
            NotificationCenter.default.post(
                name: .init("HaloPanelGeometryChanged"),
                object: host.panel,
                userInfo: ["frame": target, "screen": id]
            )

            let editorFrame = geometryEditorPanelFrame(around: target)
            if host.geometryEditorPanel.frame != editorFrame {
                host.geometryEditorPanel.setFrame(editorFrame, display: false)
            }
            host.geometryEditorPanel.order(.above, relativeTo: host.panel.windowNumber)
        }
    }

    private func activationDisplays() -> [ActivationDisplayDescriptor] {
        let mainID = NSScreen.main.map(Self.displayID)
        return hosts.compactMap { id, host in
            guard let geometry = host.geometry else { return nil }
            let screen = NSScreen.screens.first(where: { Self.displayID($0) == id })
            return ActivationDisplayDescriptor(
                id: id,
                screenFrame: geometry.screen,
                hasNotch: geometry.safeAreaTop > 0 && geometry.physicalNotchWidth > 0,
                isMain: id == mainID,
                themeTint: host.state.theme.tint,
                wallpaperURL: screen.flatMap { NSWorkspace.shared.desktopImageURL(for: $0) }
            )
        }
    }

    private func currentActivationSystemVolume() -> Float32? {
        store.workspace.audio.refresh()
        return store.workspace.audio.canSetVolume ? store.workspace.audio.volume : nil
    }

    private func playActivation(context: ActivationLaunchContext) {
        let displays = activationDisplays()
        guard !displays.isEmpty else { return }
        ActivationSequenceCoordinator.shared.play(context: context, displays: displays, systemVolume: currentActivationSystemVolume())
    }

    private func previewActivation() {
        let displays = activationDisplays()
        guard !displays.isEmpty else { return }
        ActivationSequenceCoordinator.shared.preview(displays: displays, systemVolume: currentActivationSystemVolume())
    }

    private func layoutContainsVisualWorkspacePixelPal(_ host: Host) -> Bool {
        let layout = host.state.layoutOverride ?? store.workspace.effectiveLayout
        guard layout.resolvedUsesCustomOpenNotchWorkspace else { return false }
        return layout.resolvedOpenNotchLayout.resolvedGridItems.contains {
            $0.module == .pet && !$0.hidden
        }
    }

    private func applyExpandedState(_ expanded: Bool, to host: Host) {
        guard let geometry = host.geometry else { return }
        if !expanded { host.state.contextPreferredSize = nil }

        var target = targetFrame(host: host, expanded: expanded)
        if geometry.style == .detached {
            let oldOffset = geometry.offset(expanded: !expanded)
            let newOffset = geometry.offset(expanded: expanded)
            target.origin.x = host.panel.frame.midX - target.width / 2 + newOffset.width - oldOffset.width
            target.origin.y = host.panel.frame.maxY - target.height + newOffset.height - oldOffset.height
        }

        let baseWidth = geometry.frame(expanded: true).width
        let contentWidth = expanded && host.state.contextPreferredSize != nil ? target.width : baseWidth
        if host.state.dashboardWidth != contentWidth { host.state.dashboardWidth = contentWidth }
        host.targetFrame = target
        host.animator.move(
            panel: host.panel,
            state: host.state,
            target: target,
            options: geometry.appearance.surface,
            preset: geometry.appearance.animation,
            animations: host.state.theme.animations && !host.state.editingGeometry,
            opening: expanded,
            style: geometry.style
        )
    }

    private func schedulePixelPalGatedCollapse(for host: Host) -> Bool {
        guard layoutContainsVisualWorkspacePixelPal(host) else { return false }

        let preferences = HaloPixelPalStore.shared.preferences
        let delay = HaloPixelPalPowerAnimationTiming.closeGateDelay(
            style: preferences.bootDownAnimation,
            speed: preferences.powerAnimationSpeed
        )
        guard delay > 0.001 else { return false }

        host.pixelPalCollapseWork?.cancel()
        let work = DispatchWorkItem { [weak self, weak host] in
            guard let self, let host, !host.state.expanded else { return }
            host.pixelPalCollapseWork = nil
            self.applyExpandedState(false, to: host)
        }
        host.pixelPalCollapseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        return true
    }

    private func reconcile() {
        let screens = store.configuration.allDisplays ? NSScreen.screens : Array(NSScreen.screens.prefix(1))
        var active = Set<String>()
        for screen in screens {
            let id = Self.displayID(screen)
            let override = store.workspace.settings.displays.first { $0.id == id }
            guard override?.enabled != false else { continue }
            let displayProfile = override?.profileID.flatMap { profileID in
                store.workspace.settings.profiles.first { $0.id == profileID }
            }
            active.insert(id)
            let existing = hosts[id]
            let host = existing ?? Host()
            var theme = displayProfile?.theme ?? override?.theme ?? store.workspace.scheduledTheme ?? store.configuration.theme
            if store.configuration.simulateNotch && theme.style == .notch { theme.style = .simulated }
            let displayLayout = displayProfile?.layout ?? override?.layout
            var appearance = displayLayout?.appearance ?? store.workspace.effectiveLayout.appearance
            let effectiveLayout = displayLayout ?? store.workspace.effectiveLayout
            // Preserve the old horizontal-height behavior only for layouts saved before
            // the explicit opened-notch content mode existed. New modes always use the main
            // expanded-height control, so Fixed Canvas, Scroll and Pages get the same roomy space.
            if effectiveLayout.openNotchContentMode == nil, effectiveLayout.horizontalWidgets ?? false {
                let requested = effectiveLayout.horizontalHeight ?? 260
                appearance.expandedHeight = requested.isFinite ? min(1100, max(200, requested)) : 260
            }
            appearance.surface = (try? appearance.surface.validated()) ?? SurfaceOptions()
            if host.state.activationSurfaceOptions != appearance.surface {
                host.state.activationSurfaceOptions = appearance.surface
            }
            let previousOffset = host.geometry?.offset(expanded: host.state.expanded) ?? .zero
            host.geometry = Self.geometry(screen: screen, theme: theme, appearance: appearance)
            if host.state.screenFrame != screen.frame { host.state.screenFrame = screen.frame }
            let ambientPhysicalWidth = host.geometry!.physicalNotchWidth > 0 ? host.geometry!.physicalNotchWidth : min(190, host.geometry!.compactWidth)
            let ambientPhysicalHeight = host.geometry!.safeAreaTop > 0 ? host.geometry!.safeAreaTop : min(34, host.geometry!.compactHeight)
            if host.state.physicalNotchWidth != ambientPhysicalWidth { host.state.physicalNotchWidth = ambientPhysicalWidth }
            if host.state.physicalNotchHeight != ambientPhysicalHeight { host.state.physicalNotchHeight = ambientPhysicalHeight }
            updateAmbientPanelFrame(host: host, geometry: host.geometry!)
            if host.state.theme != theme { host.state.theme = theme }
            if host.state.layoutOverride != displayLayout { host.state.layoutOverride = displayLayout }
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
                let ambientRoot = NotchAmbientOverlayView(store: store, state: host.state, workspace: store.workspace)
                let ambientView = NSHostingView(rootView: ambientRoot)
                ambientView.sizingOptions = []
                host.ambientPanel.contentView = ambientView
                updateAmbientPanelFrame(host: host, geometry: host.geometry!)

                let root = ActivationSequenceSurfaceHost(displayID: id, surfaceState: host.state) {
                    HaloSurfaceRouter(viewport: host.state.viewport,
                                      store: store,
                                      state: host.state,
                                      workspace: store.workspace)
                }
                .environment(\.haloScreenFrame, screen.frame)
                let view = HaloDropHostingView(rootView: root)
                view.sizingOptions = []
                host.state.setFileDropAllowed(dropCIAllowed)
                view.commercialAccessAllowed = { [weak self] in
                    self?.commercialAccessGranted ?? false
                }
                view.dropEnabled = { [weak self] in
                    self?.dropCISettingEnabled ?? false
                }
                host.refreshDropCIRegistration = { [weak view] in
                    view?.refreshDropRegistration()
                }
                view.dragStateHandler = { [weak self, weak host] active, count in
                    guard let self, let host else { return }
                    guard self.dropCIAllowed else {
                        host.state.cancelFileDrop()
                        return
                    }
                    if active {
                        ActivationSequenceCoordinator.shared.cancelForInteraction()
                        host.state.beginFileDrop(count: count)
                    } else if host.state.dropTargeted {
                        host.state.endFileDrop(collapseAfterDelay: true)
                    }
                }
                view.dropHandler = { [weak self, weak host] urls in
                    guard let self, let host else { return }
                    guard self.dropCIAllowed else {
                        host.state.cancelFileDrop()
                        return
                    }
                    host.state.completeFileDrop()
                    self.store.addFiles(urls)
                }
                host.panel.contentView = view

                let geometryEditorRoot = SurfaceGeometryEditorPanelView(
                    store: store,
                    workspace: store.workspace,
                    state: host.state,
                    session: SurfaceGeometryEditingSession.shared
                )
                let geometryEditorView = NSHostingView(rootView: geometryEditorRoot)
                geometryEditorView.sizingOptions = []
                host.geometryEditorPanel.contentView = geometryEditorView
                host.geometryEditorPanel.orderOut(nil)

                if initialActivationPending { host.panel.alphaValue = 0 }
                host.subscription = host.state.$expanded.dropFirst().removeDuplicates().receive(on: DispatchQueue.main).sink { [weak self, weak host] expanded in
                    guard let self, let host else { return }
                    host.pixelPalCollapseWork?.cancel()
                    host.pixelPalCollapseWork = nil

                    if expanded {
                        ActivationSequenceCoordinator.shared.cancelForInteraction()
                        self.applyExpandedState(true, to: host)
                    } else if !self.schedulePixelPalGatedCollapse(for: host) {
                        self.applyExpandedState(false, to: host)
                    }
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
                // Ambient is ordered first and is mouse-pass-through; the normal Halo panel
                // remains the interactive/top owner of the notch.
                host.ambientPanel.orderFrontRegardless()
                host.contextCompactSizeSubscription = host.state.$contextPreferredCompactWidth.dropFirst().removeDuplicates(by: { lhs, rhs in
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
                host.contextCompactHeightSubscription = host.state.$contextPreferredCompactHeight.dropFirst().removeDuplicates(by: { lhs, rhs in
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
                    motion.opening = .resize; motion.closing = .resize
                    motion.duration = min(0.30, max(0.14, motion.duration))
                    host.animator.move(panel: host.panel, state: host.state, target: target, options: motion,
                                       preset: .smooth, animations: host.state.theme.animations && !host.state.editingGeometry,
                                       opening: true, style: geometry.style, liveViewportResize: true,
                                       synchronizeClosedGeometry: true,
                                       closedCameraFrame: self.physicalCameraFrame(for: geometry))
                }
                host.panel.orderFrontRegardless()
                host.ambientPanel.order(.below, relativeTo: host.panel.windowNumber)
                hosts[id] = host
                if SurfaceGeometryEditingSession.shared.isEnabled {
                    refreshGeometryEditorPanels()
                }
            }
        }
        for id in Array(hosts.keys) where !active.contains(id) { hosts.removeValue(forKey: id)?.stop() }
        refreshGeometryEditorPanels()
    }
}
