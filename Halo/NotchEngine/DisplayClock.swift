import AppKit
import SwiftUI
import QuartzCore

@MainActor
private protocol HaloGlobalDropTarget: AnyObject {
    var dragStateHandler: ((Bool, Int) -> Void)? { get }
}

extension HaloDropHostingView: HaloGlobalDropTarget {}

/// Watches the system drag pasteboard so Drop CI can be summoned as soon as a
/// file drag starts, rather than waiting for the pointer to reach Halo itself.
/// The existing HaloDropHostingView callback remains the single source of truth
/// for opening/closing Drop CI and validating whether the feature is enabled.
@MainActor
private final class HaloGlobalFileDragMonitor {
    static let shared = HaloGlobalFileDragMonitor()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var keepAliveTimer: Timer?
    private weak var activeTarget: (any HaloGlobalDropTarget)?
    private var activeItemCount = 0
    private var lastCompletedPasteboardChangeCount: Int?

    private init() {}

    func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }

        let mask: NSEvent.EventTypeMask = [.leftMouseDragged, .leftMouseUp]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            let isMouseUp = event.type == .leftMouseUp
            DispatchQueue.main.async { [weak self] in
                if isMouseUp { self?.finishDrag() }
                else { self?.handleDraggedMouse() }
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            let isMouseUp = event.type == .leftMouseUp
            DispatchQueue.main.async { [weak self] in
                if isMouseUp { self?.finishDrag() }
                else { self?.handleDraggedMouse() }
            }
            return event
        }
    }

    private func handleDraggedMouse() {
        let pasteboard = NSPasteboard(name: .drag)
        let count = pasteboard.pasteboardItems?.reduce(into: 0) { result, item in
            if item.availableType(from: [.fileURL]) != nil { result += 1 }
        } ?? 0
        guard count > 0 else { return }

        // The drag pasteboard can retain its previous contents briefly after a
        // session ends. Requiring a new changeCount prevents a later ordinary
        // mouse drag from accidentally reopening Drop CI with stale file data.
        if activeTarget == nil,
           let lastCompletedPasteboardChangeCount,
           pasteboard.changeCount == lastCompletedPasteboardChangeCount {
            return
        }

        activeItemCount = count
        activateTarget(at: NSEvent.mouseLocation, count: count)
        startKeepAliveTimerIfNeeded()
    }

    private func startKeepAliveTimerIfNeeded() {
        guard keepAliveTimer == nil else { return }
        let timer = Timer(timeInterval: 0.10, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.keepDragAlive() }
        }
        timer.tolerance = 0.02
        keepAliveTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func keepDragAlive() {
        guard activeTarget != nil else {
            stopKeepAliveTimer()
            return
        }
        guard NSEvent.pressedMouseButtons & 1 != 0 else {
            finishDrag()
            return
        }

        // Reasserting the existing callback cancels Halo's short drag-exit
        // collapse task. That keeps Drop CI open even when the pointer is
        // stationary somewhere away from the notch.
        activateTarget(at: NSEvent.mouseLocation, count: activeItemCount)
    }

    private func activateTarget(at point: NSPoint, count: Int) {
        guard let target = targetForDrag(at: point) else { return }
        if let activeTarget, activeTarget !== target {
            activeTarget.dragStateHandler?(false, 0)
        }
        activeTarget = target
        target.dragStateHandler?(true, max(1, count))
    }

    private func targetForDrag(at point: NSPoint) -> (any HaloGlobalDropTarget)? {
        let haloPanels = NSApp.windows.compactMap { $0 as? HaloPanel }
        if let panel = haloPanels.first(where: { panel in
            guard let screen = panel.screen else { return false }
            return screen.frame.contains(point)
        }), let target = panel.contentView as? any HaloGlobalDropTarget {
            return target
        }

        // When Halo is configured for only one display, still summon that Drop
        // CI if the drag begins on another display rather than doing nothing.
        return haloPanels.compactMap { $0.contentView as? any HaloGlobalDropTarget }.first
    }

    private func finishDrag() {
        guard activeTarget != nil || keepAliveTimer != nil else { return }
        activeTarget?.dragStateHandler?(false, 0)
        activeTarget = nil
        activeItemCount = 0
        lastCompletedPasteboardChangeCount = NSPasteboard(name: .drag).changeCount
        stopKeepAliveTimer()
    }

    private func stopKeepAliveTimer() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
    }
}

/// Active animation only. AppKit tracks the view's display, including display moves.
@MainActor final class DisplayClock: NSObject {
    private var nativeLink: AnyObject?
    private var fallback: Timer?
    private var tick: ((CFTimeInterval) -> Void)?
    private var requestedRate = 0

    override init() {
        super.init()
        HaloGlobalFileDragMonitor.shared.start()
    }

    func start(view: NSView, tick: @escaping (CFTimeInterval) -> Void) {
        stop(); self.tick = tick
        requestedRate = FrameRatePolicy.target(maximum: view.window?.screen?.maximumFramesPerSecond ?? 60,
                                               lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled)
        if #available(macOS 14.0, *) {
            let link = view.displayLink(target: self, selector: #selector(displayTick(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: Float(min(60, requestedRate)),
                                                           maximum: Float(requestedRate), preferred: Float(requestedRate))
            nativeLink = link
            link.add(to: .main, forMode: .common)
        } else {
            let timer = Timer(timeInterval: 1 / Double(requestedRate), repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.tick?(CACurrentMediaTime()) }
            }
            timer.tolerance = 0
            fallback = timer; RunLoop.main.add(timer, forMode: .common)
        }
    }
    @available(macOS 14.0, *)
    @objc private func displayTick(_ link: CADisplayLink) { tick?(link.targetTimestamp) }
    func stop() {
        if #available(macOS 14.0, *), let link = nativeLink as? CADisplayLink { link.invalidate() }
        nativeLink = nil; fallback?.invalidate(); fallback = nil; tick = nil
    }
}

struct RefreshTimeline<Content: View>: View {
    let active: Bool
    @ViewBuilder var content: (CFTimeInterval) -> Content
    @State private var time = CACurrentMediaTime()
    var body: some View {
        content(time).background {
            RefreshPulse(active: active) { time = $0 }.allowsHitTesting(false).accessibilityHidden(true)
        }
    }
}
private struct RefreshPulse: NSViewRepresentable {
    let active: Bool
    let tick: (CFTimeInterval) -> Void
    final class PulseView: NSView {
        let clock = DisplayClock()
        var active = false
        var running = false
        var tick: ((CFTimeInterval) -> Void)?
        var screenObserver: NSObjectProtocol?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
            screenObserver = nil
            if let window {
                screenObserver = NotificationCenter.default.addObserver(forName: NSWindow.didChangeScreenNotification, object: window, queue: .main) { [weak self] _ in
                    Task { @MainActor [weak self] in self?.restart() }
                }
            }
            restart()
        }
        override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); restart() }
        func restart() { clock.stop(); running = false; update() }
        func update() {
            let shouldRun = active && window != nil
            guard shouldRun != running else { return }; running = shouldRun
            if shouldRun { clock.start(view: self) { [weak self] in self?.tick?($0) } }
            else { clock.stop() }
        }
    }
    func makeNSView(context: Context) -> PulseView { PulseView() }
    func updateNSView(_ view: PulseView, context: Context) {
        view.tick = tick; view.active = active; view.update()
    }
    static func dismantleNSView(_ view: PulseView, coordinator: ()) {
        view.clock.stop(); view.tick = nil
        if let observer = view.screenObserver { NotificationCenter.default.removeObserver(observer) }; view.screenObserver = nil
    }
}
