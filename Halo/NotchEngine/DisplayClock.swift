import AppKit
import SwiftUI
import QuartzCore

/// Active animation only. AppKit tracks the view's display, including display moves.
@MainActor final class DisplayClock: NSObject {
    private var nativeLink: AnyObject?
    private var fallback: Timer?
    private var tick: ((CFTimeInterval) -> Void)?
    private var requestedRate = 0
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
