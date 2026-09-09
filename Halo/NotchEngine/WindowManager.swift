import AppKit
import SwiftUI
import Combine

@MainActor
final class SurfaceState: ObservableObject {
    @Published var expanded = false
    @Published var pinned = false
    var collapsedWidth: CGFloat = 190
    var topClearance: CGFloat = 32
    var collapseTask: Task<Void, Never>?
    func hover(_ inside: Bool, enabled: Bool) {
        collapseTask?.cancel()
        guard enabled else { return }
        if inside { expanded = true }
        else if !pinned {
            collapseTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 450_000_000)
                guard !Task.isCancelled else { return }
                self?.expanded = false
            }
        }
    }
}

final class HaloPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class WindowManager {
    private let store: AppStore
    private var panels: [HaloPanel] = []
    private var states: [SurfaceState] = []
    private var subscriptions = Set<AnyCancellable>()
    private var layouts = Set<AnyCancellable>()
    private var displayIDs: [String] = []
    static func displayID(_ screen: NSScreen) -> String {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return screen.localizedName }
        return CFUUIDCreateString(nil, uuid) as String
    }
    init(store: AppStore) { self.store = store }
    func start() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main).sink { [weak self] _ in self?.rebuild() }.store(in: &subscriptions)
        store.$configuration.dropFirst().receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuild() }.store(in: &subscriptions)
        store.workspace.$settings.map { settings -> Data in
            var key = (try? JSONEncoder().encode(settings.layout.appearance)) ?? Data()
            key.append((try? JSONEncoder().encode(settings.displays)) ?? Data())
            return key
        }.removeDuplicates().dropFirst().debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.rebuild() }.store(in: &subscriptions)
        rebuild()
    }
    func stop() {
        states.forEach { $0.collapseTask?.cancel() }
        panels.forEach { $0.close() }
        panels.removeAll(); states.removeAll(); layouts.removeAll(); subscriptions.removeAll()
    }
    func toggleAll() { states.forEach { $0.expanded.toggle() } }
    private func rebuild() {
        let previous = Dictionary(uniqueKeysWithValues: zip(displayIDs, states).map { ($0.0, ($0.1.expanded, $0.1.pinned)) })
        states.forEach { $0.collapseTask?.cancel() }
        panels.forEach { $0.close() }
        panels.removeAll(); states.removeAll(); layouts.removeAll()
        displayIDs.removeAll()
        let screens = store.configuration.allDisplays ? NSScreen.screens : Array(NSScreen.screens.prefix(1))
        for screen in screens {
            let id = Self.displayID(screen)
            let override = store.workspace.settings.displays.first { $0.id == id }
            guard override?.enabled != false else { continue }
            let state = SurfaceState()
            state.expanded = previous[id]?.0 ?? false; state.pinned = previous[id]?.1 ?? false
            let theme = override?.theme ?? store.configuration.theme
            let appearance = override?.layout?.appearance ?? store.workspace.settings.layout.appearance
            state.collapsedWidth = appearance.compactWidth
            let notched = screen.safeAreaInsets.top > 0 && theme.style == .notch
            state.topClearance = notched ? screen.safeAreaInsets.top : 32
            if notched, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
                state.collapsedWidth = max(190, right.minX - left.maxX + 32)
            } else if store.configuration.simulateNotch || theme.style == .simulated { state.collapsedWidth = 220 }
            let panel = HaloPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.hidesOnDeactivate = false
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isMovableByWindowBackground = theme.style == .detached
            panel.contentView = NSHostingView(rootView: SurfaceView(store: store, state: state, workspace: store.workspace, theme: theme, layoutOverride: override?.layout))
            let frameFor: (Bool) -> NSRect = { expanded in
                let requested = theme.style == .menuBar ? screen.visibleFrame.width - 24 : (theme.style == .shelf && expanded ? min(900, screen.visibleFrame.width - 24) : (expanded ? theme.width : state.collapsedWidth))
                let width = Geometry.width(screenWidth: screen.frame.width, requested: requested)
                let height: CGFloat = min(screen.visibleFrame.height - 16, expanded ? appearance.expandedHeight + state.topClearance : state.topClearance + 8)
                let top = theme.style == .pill || !notched ? screen.visibleFrame.maxY - 8 : screen.frame.maxY
                var x = screen.frame.midX - width / 2
                var y = top - height
                switch theme.style {
                case .left: x = screen.visibleFrame.minX + 8; y = screen.visibleFrame.midY - height / 2
                case .right: x = screen.visibleFrame.maxX - width - 8; y = screen.visibleFrame.midY - height / 2
                case .bottom: y = screen.visibleFrame.minY + 8
                case .detached: y = screen.visibleFrame.midY - height / 2
                default: break
                }
                return NSRect(x: x, y: y, width: width, height: height)
            }
            panel.setFrame(frameFor(state.expanded), display: true)
            state.$expanded.dropFirst().receive(on: RunLoop.main).sink { [weak panel] expanded in
                guard let panel else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = theme.animations && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? appearance.animation.duration : 0
                    panel.animator().setFrame(frameFor(expanded), display: true)
                }
            }.store(in: &layouts)
            panel.orderFrontRegardless()
            panels.append(panel); states.append(state)
            displayIDs.append(id)
        }
    }
}
