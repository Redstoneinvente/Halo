import AppKit
import SwiftUI
import Combine

@MainActor
final class SurfaceState: ObservableObject {
    @Published var expanded = false
    @Published var pinned = false {
        didSet { if pinned { collapseTask?.cancel(); expanded = true } }
    }
    @Published var renderSize = CGSize(width: 190, height: 40)
    @Published var compactHeight: CGFloat = 40
    @Published var theme = Theme()
    @Published var layoutOverride: WorkspaceLayout?
    var collapseTask: Task<Void, Never>?
    func hover(_ inside: Bool, enabled: Bool) {
        collapseTask?.cancel()
        guard enabled else { return }
        if inside { expanded = true }
        else if !pinned {
            collapseTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 450_000_000)
                guard !Task.isCancelled, let self, !self.pinned else { return }
                self.expanded = false
            }
        }
    }
}

final class HaloPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Only runs a 60 Hz timer during a transition. Retargeting begins at the current frame.
@MainActor
final class SurfaceAnimator {
    private var ticker: AnyCancellable?
    func cancel() { ticker?.cancel(); ticker = nil }
    func move(panel: HaloPanel, state: SurfaceState, target: CGRect, options: SurfaceOptions,
              preset: AnimationPreset, animations: Bool, opening: Bool, style: SurfaceStyle) {
        cancel()
        let transition = opening ? options.opening : options.closing
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        guard animations, !reduceMotion, preset != .none, transition != .instant else {
            panel.alphaValue = 1; state.renderSize = target.size; panel.setFrame(target, display: true); return
        }
        let initial = panel.frame
        let initialAlpha = panel.alphaValue
        let start = ProcessInfo.processInfo.systemUptime
        let duration = options.duration
        ticker = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect().sink { [weak self, weak panel, weak state] _ in
            guard let self, let panel, let state else { self?.cancel(); return }
            let t = min(1, (ProcessInfo.processInfo.systemUptime - start) / duration)
            let p = SurfaceMotion.progress(t, transition: transition, preset: preset, damping: options.damping)
            let width = max(1, initial.width + (target.width - initial.width) * p)
            let height = max(1, initial.height + (target.height - initial.height) * p)
            let centerX = initial.midX + (target.midX - initial.midX) * p
            let top = initial.maxY + (target.maxY - initial.maxY) * p
            var frame = CGRect(x: centerX - width / 2, y: top - height, width: width, height: height)
            // Preserve the selected attachment point during overshoot.
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
            state.renderSize = frame.size
            panel.setFrame(frame, display: true)
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
        store.$configuration.dropFirst().receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reconcile() }.store(in: &subscriptions)
        store.workspace.$settings.map { settings -> Data in
            var key = (try? JSONEncoder().encode(settings.layout.appearance)) ?? Data()
            key.append((try? JSONEncoder().encode(settings.displays)) ?? Data())
            return key
        }.removeDuplicates().dropFirst().debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.reconcile() }.store(in: &subscriptions)
        reconcile()
    }
    func stop() { hosts.values.forEach { $0.stop() }; hosts.removeAll(); subscriptions.removeAll() }
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
            var theme = override?.theme ?? store.configuration.theme
            if store.configuration.simulateNotch && theme.style == .notch { theme.style = .simulated }
            var appearance = override?.layout?.appearance ?? store.workspace.settings.layout.appearance
            appearance.surface = (try? appearance.surface.validated()) ?? SurfaceOptions()
            host.geometry = Self.geometry(screen: screen, theme: theme, appearance: appearance)
            host.animator.cancel()
            host.state.theme = theme
            host.state.layoutOverride = override?.layout
            host.state.compactHeight = host.geometry!.compactHeight
            host.panel.isMovableByWindowBackground = theme.style == .detached
            var target = host.geometry!.frame(expanded: host.state.expanded)
            if existing != nil && theme.style == .detached {
                target.origin.x = min(max(host.panel.frame.midX - target.width / 2, screen.visibleFrame.minX), screen.visibleFrame.maxX - target.width)
                target.origin.y = min(max(host.panel.frame.maxY - target.height, screen.visibleFrame.minY), screen.visibleFrame.maxY - target.height)
            }
            host.state.renderSize = target.size
            host.panel.alphaValue = 1
            host.panel.setFrame(target, display: true)
            if existing == nil {
                let view = NSHostingView(rootView: SurfaceView(store: store, state: host.state, workspace: store.workspace))
                view.sizingOptions = []
                host.panel.contentView = view
                host.subscription = host.state.$expanded.dropFirst().removeDuplicates().receive(on: RunLoop.main).sink { [weak host] expanded in
                    guard let host, let geometry = host.geometry else { return }
                    var target = geometry.frame(expanded: expanded)
                    if geometry.style == .detached {
                        target.origin.x = min(max(host.panel.frame.midX - target.width / 2, geometry.visible.minX), geometry.visible.maxX - target.width)
                        target.origin.y = min(max(host.panel.frame.maxY - target.height, geometry.visible.minY), geometry.visible.maxY - target.height)
                    }
                    host.animator.move(panel: host.panel, state: host.state, target: target, options: geometry.appearance.surface,
                                       preset: geometry.appearance.animation, animations: host.state.theme.animations, opening: expanded, style: geometry.style)
                }
                host.panel.orderFrontRegardless()
                hosts[id] = host
            }
        }
        for id in Array(hosts.keys) where !active.contains(id) { hosts.removeValue(forKey: id)?.stop() }
    }
}
