import AppKit
import SwiftUI
import QuartzCore

@MainActor
private protocol HaloGlobalDropTarget: AnyObject {
    var dragStateHandler: ((Bool, Int) -> Void)? { get }
}

extension HaloDropHostingView: HaloGlobalDropTarget {}

/// Summons Drop CI as soon as a system file drag begins instead of waiting for
/// the pointer to physically enter Halo's NSDraggingDestination.
@MainActor
private final class HaloGlobalFileDragMonitor {
    static let shared = HaloGlobalFileDragMonitor()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var pollTimer: Timer?
    private weak var activeTarget: (any HaloGlobalDropTarget)?
    private var activeItemCount = 0
    private var lastCompletedPasteboardChangeCount: Int?
    private var sawMouseDrag = false

    private init() {}

    func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }

        let mask: NSEvent.EventTypeMask = [.leftMouseDragged, .leftMouseUp]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            let type = event.type
            DispatchQueue.main.async { [weak self] in
                self?.handleMouseEvent(type)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            let type = event.type
            DispatchQueue.main.async { [weak self] in
                self?.handleMouseEvent(type)
            }
            return event
        }

        // Polling is intentional. During drags from Finder/macOS, the system drag
        // pasteboard can become readable slightly before/after the global NSEvent
        // callback. Sampling while the left button is held removes that race.
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.pollDragSession() }
        }
        timer.tolerance = 0.01
        pollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func handleMouseEvent(_ type: NSEvent.EventType) {
        switch type {
        case .leftMouseDragged:
            sawMouseDrag = true
            inspectDragPasteboard()

            // Finder owns Desktop/file drags. macOS does not guarantee that the
            // drag pasteboard payload is already visible at the very first mouse-
            // dragged event, so optimistically summon Drop CI for Finder here.
            // The normal NSDraggingDestination still validates the actual drop.
            if activeTarget == nil, isLikelyFinderFileDrag {
                activeItemCount = max(1, dragPasteboardFileCount())
                activateTarget(at: NSEvent.mouseLocation, count: activeItemCount)
            }

        case .leftMouseUp:
            finishDrag()
        default:
            break
        }
    }

    private func pollDragSession() {
        let leftButtonDown = (NSEvent.pressedMouseButtons & 1) != 0
        guard leftButtonDown else {
            if activeTarget != nil || sawMouseDrag { finishDrag() }
            return
        }

        guard sawMouseDrag || activeTarget != nil else { return }
        inspectDragPasteboard()

        // Once Drop CI has been summoned, keep feeding the existing drag-state
        // callback. This cancels SurfaceState's short drag-exit collapse task when
        // the pointer is sitting away from Halo or temporarily crosses windows.
        if activeTarget != nil {
            activateTarget(at: NSEvent.mouseLocation, count: max(1, activeItemCount))
        }
    }

    private func inspectDragPasteboard() {
        let pasteboard = NSPasteboard(name: .drag)
        let count = dragPasteboardFileCount(pasteboard)
        guard count > 0 else { return }

        // The drag pasteboard can briefly retain the previous session's data.
        // Only use it to start a new session when its generation changed.
        if activeTarget == nil,
           let lastCompletedPasteboardChangeCount,
           pasteboard.changeCount == lastCompletedPasteboardChangeCount {
            return
        }

        activeItemCount = count
        activateTarget(at: NSEvent.mouseLocation, count: count)
    }

    private func dragPasteboardFileCount(_ pasteboard: NSPasteboard = NSPasteboard(name: .drag)) -> Int {
        pasteboard.pasteboardItems?.reduce(into: 0) { result, item in
            if item.availableType(from: [.fileURL]) != nil { result += 1 }
        } ?? 0
    }

    private var isLikelyFinderFileDrag: Bool {
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder" else {
            return false
        }

        // Exclude the upper chrome of an on-screen Finder window so dragging the
        // title/toolbar doesn't summon Drop CI. Desktop drags have no Finder
        // content window beneath the pointer and therefore pass through.
        let point = NSEvent.mouseLocation
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else {
            return true
        }

        for info in windows {
            guard (info[kCGWindowOwnerName as String] as? String) == "Finder",
                  let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.contains(point) else { continue }

            // Quartz window bounds use a top-left global coordinate system while
            // NSEvent.mouseLocation is bottom-left. Convert against the union of
            // visible screen frames before checking the toolbar exclusion band.
            let desktopTop = NSScreen.screens.map(\.frame.maxY).max() ?? 0
            let pointFromTop = desktopTop - point.y
            let distanceFromWindowTop = pointFromTop - bounds.minY
            return distanceFromWindowTop > 72
        }
        return true
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

        // If Halo is configured for one display only, still make that surface the
        // drop destination when the user starts dragging on another display.
        return haloPanels.compactMap { $0.contentView as? any HaloGlobalDropTarget }.first
    }

    private func finishDrag() {
        guard activeTarget != nil || sawMouseDrag else { return }
        activeTarget?.dragStateHandler?(false, 0)
        activeTarget = nil
        activeItemCount = 0
        sawMouseDrag = false
        lastCompletedPasteboardChangeCount = NSPasteboard(name: .drag).changeCount
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
