import AppKit
import CoreGraphics
import SwiftUI
import Combine
import QuartzCore

@MainActor
final class SurfaceViewport: ObservableObject {
    @Published var size = CGSize(width: 190, height: 40)
}

enum HaloSurfaceOpenDestination: String {
    case normal
    case music
}

@MainActor
enum HaloHoverHaptics {
    private static var lastPulseByID: [String: TimeInterval] = [:]
    private static var sequenceGenerationByID: [String: Int] = [:]

    static func pulse(
        id: String,
        strength: Int,
        pattern: HaloHoverHapticPattern = .automatic,
        minimumInterval: TimeInterval = 0.16
    ) {
        let strength = min(6, max(0, strength))

        if strength == 0 {
            sequenceGenerationByID[id] = (sequenceGenerationByID[id] ?? 0) + 1
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        if let lastPulse = lastPulseByID[id],
           now - lastPulse < minimumInterval {
            return
        }

        let generation = (sequenceGenerationByID[id] ?? 0) + 1
        sequenceGenerationByID[id] = generation
        lastPulseByID[id] = now

        if pattern == .automatic {
            performAutomatic(
                strength: strength,
                id: id,
                generation: generation
            )
            return
        }

        let primary = feedbackPattern(for: strength)
        switch pattern {
        case .automatic:
            break
        case .single:
            perform(primary)
        case .doubleTap:
            perform(primary)
            schedule(primary, after: 0.075, id: id, generation: generation)
        case .tripleTap:
            perform(primary)
            schedule(primary, after: 0.065, id: id, generation: generation)
            schedule(primary, after: 0.130, id: id, generation: generation)
        case .heartbeat:
            perform(primary)
            schedule(.levelChange, after: 0.072, id: id, generation: generation)
            schedule(.generic, after: 0.215, id: id, generation: generation)
        case .rapidBurst:
            perform(primary)
            schedule(primary, after: 0.036, id: id, generation: generation)
            schedule(primary, after: 0.072, id: id, generation: generation)
            schedule(.generic, after: 0.108, id: id, generation: generation)
        case .echo:
            perform(primary)
            schedule(.levelChange, after: 0.105, id: id, generation: generation)
            schedule(.alignment, after: 0.205, id: id, generation: generation)
        }
    }

    private static func performAutomatic(
        strength: Int,
        id: String,
        generation: Int
    ) {
        switch strength {
        case 1:
            perform(.alignment)
        case 2:
            perform(.levelChange)
        case 3:
            perform(.generic)
        case 4:
            perform(.generic)
            schedule(.generic, after: 0.055, id: id, generation: generation)
        case 5:
            perform(.generic)
            schedule(.levelChange, after: 0.045, id: id, generation: generation)
            schedule(.generic, after: 0.095, id: id, generation: generation)
        default:
            perform(.generic)
            schedule(.generic, after: 0.038, id: id, generation: generation)
            schedule(.levelChange, after: 0.078, id: id, generation: generation)
            schedule(.generic, after: 0.122, id: id, generation: generation)
        }
    }

    private static func feedbackPattern(
        for strength: Int
    ) -> NSHapticFeedbackManager.FeedbackPattern {
        switch strength {
        case 1:
            return .alignment
        case 2:
            return .levelChange
        default:
            return .generic
        }
    }

    private static func perform(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        NSHapticFeedbackManager.defaultPerformer.perform(
            pattern,
            performanceTime: .now
        )
    }

    private static func schedule(
        _ pattern: NSHapticFeedbackManager.FeedbackPattern,
        after delay: TimeInterval,
        id: String,
        generation: Int
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard sequenceGenerationByID[id] == generation else { return }
            perform(pattern)
        }
    }
}

@MainActor
final class SurfaceState: ObservableObject {
    @Published var expanded = false {
        didSet {
            if expanded { beginExpandedPresentation() }
        }
    }
    /// Rendering stays expanded until the physical close animation completes.
    /// This decouples the logical destination from the presentation lifecycle so
    /// SwiftUI does not tear down open content while the panel is still retracting.
    @Published private(set) var presentationExpanded = false
    /// Pixel Pal may request a dedicated boot-down presentation before/through retract.
    /// Normal surface closes must never enter this filtered presentation.
    @Published private(set) var pixelPalCloseGateActive = false
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
    @Published var displayID: String = ""
    /// The winner selected by SurfaceView's existing CI arbiter. AppKit drag delivery reads this
    /// value but never chooses surface ownership itself.
    @Published var activeCIIdentifier: String?
    /// Explicit user navigation target. While non-nil, SurfaceView honors this destination
    /// instead of letting an unrelated Context Interface win the opening.
    @Published var explicitOpenDestination: HaloSurfaceOpenDestination?
    @Published var theme = Theme()
    @Published var activationSurfaceOptions = SurfaceOptions()
    @Published var layoutOverride: WorkspaceLayout?
    @Published var contextPreferredSize: CGSize?
    @Published var contextPreferredCompactWidth: CGFloat?
    @Published var contextPreferredCompactHeight: CGFloat?
    /// Temporary compact-size boost while an app bundle is being dragged toward the notch.
    @Published var appShortcutDragActive = false
    /// Non-CI compact-height request used by the review nudge. Keep this separate from
    /// contextPreferredCompactHeight because Simple mode deliberately clears CI sizing.
    @Published var reviewPromptPreferredCompactHeight: CGFloat?
    /// Original compact height captured before the review nudge grows the panel. This belongs
    /// to the surface state, not SwiftUI @State, so a child-view rebuild cannot orphan the panel.
    var reviewPromptBaseCompactHeight: CGFloat?
    @Published var contextMinimumExpandedWidth: CGFloat?
    /// Per-surface drag metadata comes from Halo's shared file-drag source. Drop CI is merely one
    /// consumer of this state; partner integrations receive the same event independently.
    @Published var dropTargeted = false
    @Published var dropItemCount = 0
    private(set) var dropOpenedSurfaceAutomatically = false
    var collapseTask: Task<Void, Never>?
    var hoverExpandTask: Task<Void, Never>?
    var dropExitTask: Task<Void, Never>?
    var editingGeometry = false
    var appShortcutDragStateDidChange: ((Bool) -> Void)?

    func setAppShortcutDragActive(_ active: Bool) {
        guard appShortcutDragActive != active else { return }
        appShortcutDragActive = active
        appShortcutDragStateDidChange?(active)
    }

    func beginExpandedPresentation() {
        if pixelPalCloseGateActive { pixelPalCloseGateActive = false }
        if !presentationExpanded { presentationExpanded = true }
    }

    func openExplicitly(_ destination: HaloSurfaceOpenDestination) {
        collapseTask?.cancel()
        hoverExpandTask?.cancel()
        contextPreferredSize = nil
        contextPreferredCompactWidth = nil
        contextPreferredCompactHeight = nil
        contextMinimumExpandedWidth = nil
        explicitOpenDestination = destination
        expanded = true
    }

    func clearExplicitOpenDestination() {
        if explicitOpenDestination != nil { explicitOpenDestination = nil }
    }

    func setPixelPalCloseGateActive(_ active: Bool) {
        if pixelPalCloseGateActive != active { pixelPalCloseGateActive = active }
    }

    func completeCollapsedPresentation() {
        if pixelPalCloseGateActive { pixelPalCloseGateActive = false }
        if presentationExpanded { presentationExpanded = false }
        clearExplicitOpenDestination()
    }

    // Hover expansion can briefly emit an exit while the NSPanel is resizing from
    // compact to open geometry. Track only that in-flight opening so the false exit
    // cannot reverse the animation midway. This is not a normal hover-close delay.
    private var hoverInside = false
    private var hoverExpansionRequested = false
    private var hoverOpeningGuardActive = false
    private var hoverExitPendingDuringOpening = false
    private var hoverCloseDelay: Double = 0
    private var externalInteractionHeld = false

    /// Keeps Halo expanded while the user is interacting with a child window/popover
    /// that lives outside the physical NSPanel hover bounds.
    func setExternalInteractionHeld(_ held: Bool) {
        guard externalInteractionHeld != held else { return }
        externalInteractionHeld = held

        if held {
            collapseTask?.cancel()
            collapseTask = nil
            hoverExpandTask?.cancel()
            hoverExpandTask = nil
            if !expanded { expanded = true }
            return
        }

        // Once the external interaction ends, normal hover policy resumes. If the
        // pointer is already back over Halo, the next hover event will keep it open.
        if !hoverInside && !pinned && !editingGeometry && !dropTargeted {
            scheduleHoverCollapse(after: hoverCloseDelay)
        }
    }

    func cancelFileDrop() {
        dropExitTask?.cancel()
        dropExitTask = nil
        if dropTargeted { dropTargeted = false }
        if dropItemCount != 0 { dropItemCount = 0 }
        dropOpenedSurfaceAutomatically = false
    }

    /// Records a Halo-owned drag event for the surface. This intentionally does not expand Halo:
    /// expansion is allowed only after SurfaceView's normal priority arbiter grants ownership.
    func beginFileDrop(count: Int) {
        dropExitTask?.cancel()
        let nextCount = max(1, count)
        if dropItemCount != nextCount { dropItemCount = nextCount }
        if !dropTargeted { dropTargeted = true }
    }

    func activateDropOwnership() {
        guard dropTargeted, !expanded, !pinned else { return }
        dropOpenedSurfaceAutomatically = true
        collapseTask?.cancel()
        expanded = true
    }

    func endFileDrop() {
        dropExitTask?.cancel()
        dropExitTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled, let self else { return }

            // Only retract Halo if Drop CI was the thing that expanded it. If Halo was
            // already open (manual open, hover, pin, another owner), leave that state alone.
            let shouldCollapse = self.dropOpenedSurfaceAutomatically
            self.dropTargeted = false
            self.dropItemCount = 0
            self.dropOpenedSurfaceAutomatically = false

            guard shouldCollapse, !self.pinned, !self.editingGeometry else { return }
            self.collapseTask?.cancel()
            self.collapseTask = nil
            self.expanded = false
        }
    }

    func completeFileDrop(collapseSurface: Bool) {
        dropExitTask?.cancel()
        dropTargeted = false
        dropItemCount = 0
        let shouldCollapse = collapseSurface && dropOpenedSurfaceAutomatically
        dropOpenedSurfaceAutomatically = false
        guard shouldCollapse, !pinned, !editingGeometry else { return }
        collapseTask?.cancel()
        collapseTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled, let self, !self.pinned, !self.editingGeometry, !self.dropTargeted else { return }
            self.expanded = false
        }
    }

    func consumeHoverExpansionRequest() -> Bool {
        let requested = hoverExpansionRequested
        hoverExpansionRequested = false
        return requested
    }

    func beginHoverOpeningGuard() {
        hoverOpeningGuardActive = true
        hoverExitPendingDuringOpening = false
    }

    func completeHoverOpeningGuard(cursorInsidePanel: Bool) {
        guard hoverOpeningGuardActive else { return }
        hoverOpeningGuardActive = false

        let shouldCollapse =
            hoverExitPendingDuringOpening &&
            !hoverInside &&
            !cursorInsidePanel &&
            !pinned &&
            !editingGeometry &&
            !dropTargeted &&
            !externalInteractionHeld

        hoverExitPendingDuringOpening = false
        if shouldCollapse && expanded {
            scheduleHoverCollapse(after: hoverCloseDelay)
        }
    }

    private func scheduleHoverCollapse(after delay: Double) {
        collapseTask?.cancel()
        collapseTask = nil
        guard !externalInteractionHeld else { return }
        let delay = min(10, max(0, delay))

        guard delay > 0.001 else {
            collapseTask = nil
            if !hoverInside && !pinned && !editingGeometry && !dropTargeted && !externalInteractionHeld {
                expanded = false
            }
            return
        }

        collapseTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled,
                  let self,
                  !self.hoverInside,
                  !self.pinned,
                  !self.editingGeometry,
                  !self.dropTargeted,
                  !self.externalInteractionHeld else { return }
            self.collapseTask = nil
            self.expanded = false
        }
    }

    func cancelHoverOpeningGuard() {
        hoverOpeningGuardActive = false
        hoverExitPendingDuringOpening = false
        hoverExpansionRequested = false
    }

    func hover(_ inside: Bool, enabled: Bool, openDelay: Double = 0, closeDelay: Double = 0) {
        hoverInside = inside
        hoverCloseDelay = min(10, max(0, closeDelay))
        if inside {
            hoverExitPendingDuringOpening = false
        }

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
                hoverExpansionRequested = true
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
                self.hoverExpansionRequested = true
                self.expanded = true
            }
        } else if !pinned {
            if externalInteractionHeld {
                collapseTask?.cancel()
                collapseTask = nil
                return
            }
            if hoverOpeningGuardActive {
                // A resize can temporarily move SwiftUI's hover boundary underneath
                // the stationary cursor. Finish opening first, then verify the actual
                // cursor position before deciding whether to retract.
                hoverExitPendingDuringOpening = true
                return
            }

            // Once the opening transition is complete, honor the user's hover-close grace
            // period. Re-entering Halo cancels this task at the top of hover(_:enabled:...).
            // Pixel Pal's optional boot-down gate is applied later by WindowManager.
            scheduleHoverCollapse(after: hoverCloseDelay)
        }
    }
}

final class HaloPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class HaloDropHostingView<Content: View>: NSHostingView<Content> {
    /// Returns true when the surface-wide CI system has at least one eligible drag consumer.
    /// The callback receives URLs only at the privileged AppKit boundary; URLs are immediately
    /// moved into TriggerPayloadStore before any Custom CI/public context can observe them.
    var dragStateHandler: ((Bool, [URL]) -> Bool)?
    var dragLocationHandler: ((CGPoint?) -> Void)?
    var dropHandler: (([URL]) -> Bool)?
    var appShortcutDropHandler: (([URL], CGPoint, Bool) -> Bool)?
    var appShortcutDragStateHandler: ((Bool) -> Void)?
    private var appShortcutDragURLs: [URL]?

    private func finishAppShortcutDrag() {
        guard appShortcutDragURLs != nil else { return }
        appShortcutDragURLs = nil
        appShortcutDragStateHandler?(false)
    }

    /// The normal Halo runtime remains the outer boundary for Halo's surface-wide drag source.
    /// Edition-specific drag restrictions, if any, belong in HaloFeatureAccess later.
    var surfaceRuntimeAllowed: (() -> Bool)? {
        didSet { refreshDropRegistration() }
    }

    /// Drop Zone Studio is a presentation owned by Drop CI, not by the shared drag source.
    /// This closure is evaluated after the normal SurfaceView arbiter has selected a winner.
    var dropZoneOverlayAllowed: (() -> Bool)?

    var permitsGlobalFileDrag: Bool { hasSurfaceRuntimeAccess }
    var permitsDropZoneOverlay: Bool {
        hasSurfaceRuntimeAccess && (dropZoneOverlayAllowed?() ?? false)
    }

    private var fileDragRegistered = false
    private var surfaceDragActive = false

    required init(rootView: Content) {
        super.init(rootView: rootView)
        refreshDropRegistration()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var hasSurfaceRuntimeAccess: Bool { surfaceRuntimeAllowed?() ?? false }

    /// Prevent SwiftUI descendants from registering drag handlers before Halo's surface
    /// runtime is ready. Lite/Full capability rules are intentionally handled elsewhere.
    override func registerForDraggedTypes(_ newTypes: [NSPasteboard.PasteboardType]) {
        guard hasSurfaceRuntimeAccess else { return }
        super.registerForDraggedTypes(newTypes)
    }

    /// Halo owns one surface-wide file-drag source. Registration is intentionally independent of
    /// the Drop CI preference: Drop CI and partner CIs are consumers of the same source.
    func refreshDropRegistration() {
        guard hasSurfaceRuntimeAccess else {
            unregisterDraggedTypes()
            fileDragRegistered = false
            rejectSurfaceDrag()
            finishAppShortcutDrag()
            return
        }
        guard !fileDragRegistered else { return }
        super.registerForDraggedTypes([.fileURL])
        fileDragRegistered = true
    }

    private func rejectSurfaceDrag() {
        dragLocationHandler?(nil)
        if surfaceDragActive {
            dragLocationHandler?(nil)
            _ = dragStateHandler?(false, [])
            surfaceDragActive = false
        }
    }

    private func dragScreenPoint(_ sender: NSDraggingInfo) -> CGPoint? {
        guard let window else { return nil }
        return window.convertPoint(toScreen: sender.draggingLocation)
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
        guard hasSurfaceRuntimeAccess else { rejectSurfaceDrag(); return [] }
        let urls = fileURLs(sender)
        guard !urls.isEmpty else { return super.draggingEntered(sender) }
        if !urls.isEmpty && urls.allSatisfy({ $0.pathExtension.lowercased() == "app" }) {
            appShortcutDragURLs = urls
            appShortcutDragStateHandler?(true)
            if let point = dragScreenPoint(sender),
               appShortcutDropHandler?(urls, point, false) == true {
                return .copy
            }
            return .copy
        }

        // Classification/payload capture happens once on enter. draggingUpdated never rebuilds it.
        let claimed = dragStateHandler?(true, urls) ?? false
        surfaceDragActive = claimed
        if claimed {
            dragLocationHandler?(dragScreenPoint(sender))
        }
        return claimed ? .copy : super.draggingEntered(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard hasSurfaceRuntimeAccess else { rejectSurfaceDrag(); finishAppShortcutDrag(); return [] }
        if appShortcutDragURLs != nil {
            if let point = dragScreenPoint(sender),
               appShortcutDropHandler?(appShortcutDragURLs ?? [], point, false) == true {
                return .copy
            }
            return .copy
        }
        let candidateURLs = fileURLs(sender)
        if !candidateURLs.isEmpty && candidateURLs.allSatisfy({ $0.pathExtension.lowercased() == "app" }) {
            if surfaceDragActive {
                dragLocationHandler?(nil)
                _ = dragStateHandler?(false, [])
                surfaceDragActive = false
            }
            appShortcutDragURLs = candidateURLs
            appShortcutDragStateHandler?(true)
            if let point = dragScreenPoint(sender) {
                _ = appShortcutDropHandler?(candidateURLs, point, false)
            }
            return .copy
        }
        if surfaceDragActive {
            dragLocationHandler?(dragScreenPoint(sender))
            return .copy
        }
        return super.draggingUpdated(sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        guard hasSurfaceRuntimeAccess else { rejectSurfaceDrag(); finishAppShortcutDrag(); return }
        if appShortcutDragURLs != nil { finishAppShortcutDrag(); return }
        if surfaceDragActive {
            dragLocationHandler?(nil)
            _ = dragStateHandler?(false, [])
            surfaceDragActive = false
        } else {
            super.draggingExited(sender)
        }
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard hasSurfaceRuntimeAccess else { rejectSurfaceDrag(); finishAppShortcutDrag(); return false }
        if let urls = appShortcutDragURLs {
            defer { finishAppShortcutDrag() }
            guard let point = dragScreenPoint(sender) else { return false }
            return appShortcutDropHandler?(urls, point, true) ?? false
        }
        guard surfaceDragActive else { return super.performDragOperation(sender) }
        let urls = fileURLs(sender)
        guard !urls.isEmpty else {
            rejectSurfaceDrag()
            return false
        }
        // Publish the exact release point before resolving the action target.
        dragLocationHandler?(dragScreenPoint(sender))
        return dropHandler?(urls) ?? false
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        guard hasSurfaceRuntimeAccess else { rejectSurfaceDrag(); finishAppShortcutDrag(); return }
        if appShortcutDragURLs != nil { finishAppShortcutDrag(); return }
        if surfaceDragActive {
            dragLocationHandler?(nil)
            _ = dragStateHandler?(false, [])
            surfaceDragActive = false
        } else {
            super.concludeDragOperation(sender)
        }
    }
}

@MainActor
enum HaloMotionFeedback {
    private static var lastSoundTime: TimeInterval = 0

    static var physicsEnabled: Bool {
        UserDefaults.standard.bool(forKey: "HaloPhysicsAnimationsEnabled")
    }

    static var soundEnabled: Bool {
        UserDefaults.standard.bool(forKey: "HaloPhysicsAnimationSoundsEnabled")
    }

    static func settle(opening: Bool) {
        guard physicsEnabled, soundEnabled else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastSoundTime > 0.12 else { return }
        lastSoundTime = now

        // Keep motion audio deliberately quiet. It should register as tactility, not a notification.
        let preferredNames = opening ? ["Tink", "Pop"] : ["Pop", "Tink"]
        guard let sound = preferredNames.lazy.compactMap({ NSSound(named: NSSound.Name($0)) }).first else { return }
        sound.volume = opening ? 0.055 : 0.04
        sound.play()
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
              synchronizeClosedGeometry: Bool = false, closedCameraFrame: CGRect? = nil,
              completion: (() -> Void)? = nil) {
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
            completion?()
            return
        }
        let initial = panel.frame
        let initialAlpha = panel.alphaValue
        let start = CACurrentMediaTime()
        let duration = opening ? options.resolvedOpeningDuration : options.resolvedClosingDuration
        let directionalDamping = opening ? options.resolvedOpeningDamping : options.resolvedClosingDamping
        let usePhysics = HaloMotionFeedback.physicsEnabled
        // A restrained under-damped response gives the notch a small amount of physical
        // overshoot while remaining controlled. The display-link animator keeps this on
        // the actual NSPanel geometry instead of applying a decorative SwiftUI transform.
        let physicsDamping = min(0.94, max(0.72, directionalDamping))
        let physicsOmega = 10.5 / max(0.16, duration)
        guard let view = panel.contentView else {
            if synchronizeClosedGeometry {
                syncClosedGeometry(state: state, frame: target, cameraFrame: closedCameraFrame)
            } else {
                state.viewport.size = target.size
            }
            panel.setFrame(target, display: false)
            publishGeometry(panel: panel, frame: target)
            completion?()
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
            let elapsed = max(0, timestamp - start)
            let t = min(1, elapsed / max(0.01, duration))
            let p: Double
            if usePhysics {
                // Analytic second-order step response. Unlike an easing curve, this models
                // inertia + damping and can overshoot naturally without an arbitrary keyframe.
                let zeta = physicsDamping
                let wd = physicsOmega * sqrt(max(0.0001, 1 - zeta * zeta))
                let envelope = exp(-zeta * physicsOmega * elapsed)
                let response = 1 - envelope * (cos(wd * elapsed) + (zeta / sqrt(max(0.0001, 1 - zeta * zeta))) * sin(wd * elapsed))
                p = min(1.035, max(0, response))
            } else {
                p = SurfaceMotion.progress(t, transition: transition, preset: preset, damping: directionalDamping)
            }
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

            if t >= 1 {
                self.clock.stop()
                HaloMotionFeedback.settle(opening: opening)
                completion?()
            }
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
        // Track only the explicit left/right Closed Notch widget selections.
        // This lets a widget swap get its own playful resize without affecting
        // media, Live Activity, power, or other dynamic width changes.
        var closedWidgetLeft: ClosedNotchItem?
        var closedWidgetRight: ClosedNotchItem?
        var subscription: AnyCancellable?
        var contextSizeSubscription: AnyCancellable?
        var ciOwnershipSubscription: AnyCancellable?
        var contextCompactSizeSubscription: AnyCancellable?
        var contextCompactHeightSubscription: AnyCancellable?
        var reviewPromptCompactHeightSubscription: AnyCancellable?
        var appShortcutDragSubscription: AnyCancellable?
        var appShortcutDragBaseTarget: CGRect?
        var refreshDropCIRegistration: (() -> Void)?
        var pixelPalCollapseWork: DispatchWorkItem?
        var hoverOpeningCompletionWork: DispatchWorkItem?
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
            subscription?.cancel(); contextSizeSubscription?.cancel(); ciOwnershipSubscription?.cancel(); contextCompactSizeSubscription?.cancel(); contextCompactHeightSubscription?.cancel(); reviewPromptCompactHeightSubscription?.cancel()
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
    private let bubbleManager: NotchBubbleManager
    private let startupActivationContext: ActivationLaunchContext
    private var surfaceRuntimeEnabled = false
    private var initialActivationPending = false
    private var hosts: [String: Host] = [:]
    private var subscriptions = Set<AnyCancellable>()
    private var appAutomationHiddenDisplayIDs = Set<String>()
    private var settingsSurfacePreviewExpanded: Bool?
    private var settingsSurfacePreviewDisplayID: String?
    private var settingsSurfacePreviewPreviousExpanded: [String: Bool] = [:]
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
        self.bubbleManager = NotchBubbleManager(store: store)
        self.startupActivationContext = startupActivationContext
    }

    private var dropCISettingEnabled: Bool {
        guard HaloFeatureAccess.shared.allows(.contextInterfaces) else { return false }
        let defaults = UserDefaults.standard
        return defaults.object(forKey: "HaloContextDropEnabled") == nil
            ? true
            : defaults.bool(forKey: "HaloContextDropEnabled")
    }

    func setSurfaceRuntimeEnabled(_ granted: Bool) {
        guard surfaceRuntimeEnabled != granted else { return }
        surfaceRuntimeEnabled = granted
        bubbleManager.setSurfaceRuntimeEnabled(granted)

        hosts.values.forEach { host in
            host.refreshDropCIRegistration?()
            if !granted {
                host.state.cancelFileDrop()
                IntegrationCIRuntime.shared.cleanupForSleepOrWake()
            }
        }
    }

    func start() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main).sink { [weak self] _ in self?.reconcile() }.store(in: &subscriptions)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshAppAutomationVisibilityIfNeeded() }
            .store(in: &subscriptions)
        Timer.publish(every: 0.75, on: .main, in: .common)
            .autoconnect()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshAppAutomationVisibilityIfNeeded() }
            .store(in: &subscriptions)
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
                    host.refreshDropCIRegistration?()
                }
                // Closed-notch event and placement preferences also live in AppStorage/UserDefaults.
                // Re-measure immediately so the panel geometry cannot lag behind SwiftUI.
                self.refreshDynamicWidths()
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
        HaloFeatureAccess.shared.$accessLevel
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                if level == .lite {
                    let session = SurfaceGeometryEditingSession.shared
                    if session.isEnabled {
                        session.cancelTransaction()
                        session.previewSnapshot = nil
                        session.isEnabled = false
                        session.displayID = nil
                    }
                }
                self?.reconcile()
                self?.refreshGeometryEditorPanels()
            }
            .store(in: &subscriptions)
        NotchAmbientStore.shared.$settings.dropFirst().removeDuplicates()
            .debounce(for: .milliseconds(45), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.reconcile() }.store(in: &subscriptions)
        // Workspace settings are the source of truth for both the legacy layout and
        // Visual Workspace. Do not reduce this stream to a legacy-only fingerprint:
        // displays/profile-backed surfaces render through state.layoutOverride, which
        // is a snapshot refreshed by reconcile(). If openNotch/grid/appearance changes
        // are omitted here, Settings can persist them while the live notch keeps using
        // the stale snapshot and appears completely unresponsive.
        store.workspace.$settings
            .dropFirst()
            .throttle(for: .milliseconds(33), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.reconcile()
            }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: .init("HaloSettingsSurfacePreview"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let self else { return }
                let active = (note.userInfo?["active"] as? Bool) ?? false
                if active {
                    let expanded = (note.userInfo?["expanded"] as? Bool) ?? true
                    let display = note.userInfo?["display"] as? String
                    self.beginSettingsSurfacePreview(expanded: expanded, displayID: display)
                } else {
                    self.endSettingsSurfacePreview()
                }
            }
            .store(in: &subscriptions)

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
                    // Preserve the HUD's requested body width even in vertical mode. Vertical
                    // presentation changes height, but it must still widen the closed surface
                    // when needed rather than compressing or clipping the HUD horizontally.
                    let reservedWidth = notch.width + max(12, notch.horizontalPadding * 2) + abs(notch.horizontalOffset)
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
        store.workspace.calendar.objectWillChange.receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard self?.store.workspace.settings.resolvedNotchMode == .simple else { return }
                self?.refreshDynamicWidths()
            }.store(in: &subscriptions)

        // Closed-notch clock width can change when a 12-hour clock crosses between
        // one- and two-digit hours. Re-measure periodically so the surface hugs the
        // rendered clock instead of permanently reserving room for "12".
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshDynamicWidths() }
            .store(in: &subscriptions)

        // Review prompt ownership belongs here, at the panel/host layer. SurfaceView does
        // not own the transient panel height.
        HaloReviewPromptCoordinator.shared.$isPresented
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] presented in
                self?.synchronizeReviewPromptPresentation(presented: presented)
            }
            .store(in: &subscriptions)

        let shouldHideInitialFrame =
            store.workspace.settings.resolvedNotchMode == .advanced &&
            ActivationSequenceCoordinator.shared.shouldPlay(startupActivationContext)
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

    private var closedNotchActivityPreferences: ClosedNotchActivityPreferences {
        let defaults = UserDefaults.standard
        func bool(_ key: String, fallback: Bool) -> Bool {
            defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
        }
        return ClosedNotchActivityPreferences(
            autoPresent: bool("HaloLiveActivitiesClosedAutoPresent", fallback: true),
            bluetoothEvents: bool("HaloBluetoothClosedNotchEvents", fallback: true),
            bluetoothConnected: bool("HaloBluetoothClosedNotchConnected", fallback: true),
            bluetoothDisconnected: bool("HaloBluetoothClosedNotchDisconnected", fallback: true),
            bluetoothPoweredOn: bool("HaloBluetoothClosedNotchPoweredOn", fallback: true),
            bluetoothPoweredOff: bool("HaloBluetoothClosedNotchPoweredOff", fallback: true),
            bluetoothPreferredSide: defaults.string(forKey: "HaloBluetoothClosedNotchSide") ?? "automatic"
        )
    }

    private var activeClosedActivity: LiveActivity? {
        ClosedNotchContentResolver.primaryActivity(
            in: store.workspace.activities,
            preferences: closedNotchActivityPreferences
        )
    }

    private func closedItemIsVisible(_ item: ClosedNotchItem) -> Bool {
        switch item {
        case .none: return false
        case .media, .visualizer: return store.workspace.media.hasNowPlayingPresentation
        case .activity: return activeClosedActivity != nil
        default: return true
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
        let items = resolvedClosedItems(closed)
        let leftBusy = closedItemIsVisible(items.left)
        let rightBusy = closedItemIsVisible(items.right)
        if !rightBusy { return .right }
        if !leftBusy { return .left }
        return .right
    }

    private func hudNotchOccupied(_ side: HaloHUDNotchSide) -> Bool {
        let closed = store.workspace.effectiveLayout.closedNotch ?? ClosedNotchOptions()
        let items = resolvedClosedItems(closed)
        switch side {
        case .left: return closedItemIsVisible(items.left)
        case .right: return closedItemIsVisible(items.right)
        case .full: return closedItemIsVisible(items.left) || closedItemIsVisible(items.right)
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
        let width = notch.width + outwardOffset
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
        let resolved = ClosedNotchContentResolver.resolve(
            options: options,
            activities: store.workspace.activities,
            mediaVisible: store.workspace.media.hasNowPlayingPresentation,
            preferences: closedNotchActivityPreferences
        )
        return (resolved.left, resolved.right)
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

        let mediaVisible = store.workspace.media.hasNowPlayingPresentation
        let mediaPlaying = store.workspace.media.isPlaying
        let side: DynamicSide
        switch settings.side {
        case .left: side = .left
        case .right: side = .right
        case .automatic:
            let rightFree = items.right == .none || ((items.right == .media || items.right == .visualizer) && !mediaVisible)
            let leftFree = items.left == .none || ((items.left == .media || items.left == .visualizer) && !mediaVisible)
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
            case .media, .visualizer: return mediaVisible
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
            guard mediaVisible, artwork.enabled, artwork.mode != .none, artwork.mode != .background else { return false }
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
            (targetDecoration?.isVisible(playing: mediaPlaying) ?? false) || hasArtworkSibling
        let extraSpace = settings.expandForEvent && !hasSibling ? settings.resolvedExtraEventSpace : 0
        let cameraInset = settings.notchMargin.map { min(48, max(0, $0)) } ?? metrics.normalCameraInset
        return (side, badgeWidth, cameraInset, extraSpace)
    }

    private func configureSimpleDynamicWidth(_ host: Host, geometry: SurfaceGeometry) {
        let configuredSimple = store.workspace.settings.resolvedSimpleNotch
        let attached = geometry.attachedToNotch && geometry.physicalNotchWidth > 0
        // The preset is a preference, never permission to undercut the real camera housing.
        let physicalWidth = attached ? max(16, geometry.physicalNotchWidth) : 0
        let physicalHeight = attached ? max(16, geometry.safeAreaTop) : 0
        // Auxiliary safe-area APIs describe the camera gap, but the visible black notch
        // includes rounded shoulders. Give real hardware a guard band so Halo never
        // reads as narrower than the notch it is extending.
        let hardwareShellWidth = attached ? physicalWidth + 24 : 0
        let hardwareShellHeight = attached ? physicalHeight + 2 : 0
        let availableOpenWidth = max(1, geometry.visible.width - 32)

        // Fit the current display at runtime without mutating the saved Simple layout.
        // A layout configured on a wide display must still be intact when Halo later
        // returns to that display; overflow widgets are temporarily omitted, not deleted.
        let simple = SimpleNotchMetrics.fittingSettings(
            settings: configuredSimple,
            availableWidth: availableOpenWidth,
            hardwareWidth: hardwareShellWidth
        )

        let calendarActive = store.workspace.calendar.upcomingEvents.contains { $0.endDate > Date() }
        let active = simple.activeClosedWidgets(
            timerActive: store.deadline != nil || store.pausedSeconds > 0 || store.finished,
            stopwatchActive: store.workspace.stopwatchStart != nil || store.workspace.stopwatchElapsed > 0,
            mediaActive: store.workspace.media.hasNowPlayingPresentation,
            calendarActive: calendarActive
        )

        let size = simple.resolvedSize
        let presetClosedWidth = SimpleNotchMetrics.closedPillWidth(size)
        let presetClosedHeight = SimpleNotchMetrics.closedHeight(size)
        let baseWidth = attached ? hardwareShellWidth : presetClosedWidth

        if attached {
            // On a real notched Mac, Simple size presets affect only the opened surface.
            // With no live closed widgets, the collapsed Halo shell must match the physical
            // notch instead of growing to Standard / Medium / Big dimensions.
            host.geometry?.activeCompactHeight = active.isEmpty
                ? hardwareShellHeight
                : max(hardwareShellHeight, presetClosedHeight)

            let extent = SimpleNotchMetrics.closedSlotWidth(size) + SimpleNotchMetrics.closedSlotGap(size)
            switch active.count {
            case 0:
                host.geometry?.activeCompactWidth = hardwareShellWidth
                host.geometry?.activeCompactCenterOffset = 0
            case 1:
                // A single live slot grows from the right shoulder, keeping the physical
                // camera notch visually anchored instead of creating an empty opposite wing.
                host.geometry?.activeCompactWidth = min(geometry.visible.width, hardwareShellWidth + extent)
                host.geometry?.activeCompactCenterOffset = extent / 2
            default:
                host.geometry?.activeCompactWidth = min(geometry.visible.width, hardwareShellWidth + extent * 2)
                host.geometry?.activeCompactCenterOffset = 0
            }
        } else {
            host.geometry?.activeCompactHeight = presetClosedHeight
            let contentWidth: Double
            if active.isEmpty {
                contentWidth = SimpleNotchMetrics.closedPillWidth(size)
            } else {
                contentWidth =
                    Double(active.count) * SimpleNotchMetrics.closedSlotWidth(size) +
                    Double(max(0, active.count - 1)) * SimpleNotchMetrics.closedSlotGap(size) +
                    SimpleNotchMetrics.horizontalPadding(size) * 2
            }
            host.geometry?.activeCompactWidth = min(
                geometry.visible.width,
                max(baseWidth, contentWidth)
            )
            host.geometry?.activeCompactCenterOffset = nil
        }

        let arrangement = SimpleNotchMetrics.arrangement(
            settings: simple,
            availableWidth: availableOpenWidth,
            hardwareWidth: hardwareShellWidth
        )
        host.geometry?.expandedWidth = arrangement.width
        host.geometry?.appearance.expandedHeight = arrangement.height
    }

    private func configureDynamicWidth(_ host: Host) {
        guard host.geometry != nil else { return }
        host.geometry?.activeCompactHeight = nil
        guard let geometry = host.geometry else { return }

        if store.workspace.settings.resolvedNotchMode == .simple {
            configureSimpleDynamicWidth(host, geometry: geometry)
            return
        }

        let layout = host.state.layoutOverride ?? store.workspace.effectiveLayout
        let options = layout.closedNotch ?? ClosedNotchOptions()
        let expansion = options.expansion ?? ClosedExpansionOptions()
        let items = resolvedClosedItems(options)

        let attached = geometry.attachedToNotch && geometry.physicalNotchWidth > 0
        let baseCompactHeight = max(16, geometry.appearance.surface.compactHeight)
        let hardwareMinimumHeight = attached
            ? max(baseCompactHeight, max(16, geometry.safeAreaTop + 2))
            : baseCompactHeight

        func itemIsRendered(_ item: ClosedNotchItem) -> Bool {
            switch item {
            case .none:
                return false
            case .media, .visualizer:
                return store.workspace.media.hasNowPlayingPresentation
            case .activity:
                return activeClosedActivity != nil
            default:
                return true
            }
        }

        func preferredContentHeight(_ item: ClosedNotchItem) -> Double {
            guard itemIsRendered(item) else { return 0 }
            let style = options.widgetStyle(for: item)
            let textSize = min(30, max(8, style.fontSize ?? options.fontSize))
            func lineHeight(_ pointSize: Double) -> Double {
                max(1, pointSize * 1.18)
            }

            let base: Double
            switch item {
            case .clock:
                var clock = layout.widgetStyle(for: .clock).clock
                if !style.useClockWidgetSettings {
                    clock.twentyFourHour = style.clockTwentyFourHour
                    clock.showSeconds = style.clockShowSeconds
                    clock.showDate = style.clockShowDate
                }
                clock.automaticTypography = false
                if let visualStyle = style.clockVisualStyle { clock.visualStyle = visualStyle }

                let primarySize = clock.usesAutomaticTypography
                    ? max(18, textSize * 1.15 * clock.resolvedTimeScale)
                    : max(12, textSize * 1.55 * clock.resolvedTimeScale)
                switch clock.resolvedVisualStyle {
                case .analog:
                    base = max(36, min(54, textSize * 2.2))
                case .flip:
                    base = max(30, min(52, primarySize * 1.18))
                case .stacked:
                    base = max(40, min(62, primarySize * 1.72))
                case .editorial:
                    base = max(34, min(58, primarySize * 1.42))
                case .split:
                    base = max(30, min(52, primarySize * 1.22))
                case .terminal:
                    base = max(30, min(54, primarySize * 1.15))
                case .lcd, .dotMatrix, .outline:
                    base = max(34, min(58, primarySize * 1.28))
                case .oversizedTypography:
                    base = max(34, min(62, primarySize * 1.28))
                case .digital, .minimal:
                    base = max(24, min(54, lineHeight(primarySize)))
                }

            case .date:
                switch style.resolvedCalendarPresentation {
                case .compact:
                    base = max(18, lineHeight(textSize))
                case .dayTile:
                    let month = max(7, textSize * 0.52)
                    let day = max(13, textSize * 1.15)
                    base = lineHeight(month) + lineHeight(day) + 2
                case .weekdayStack:
                    let weekday = max(7, textSize * 0.54)
                    let date = max(10, textSize * 0.90)
                    base = lineHeight(weekday) + lineHeight(date)
                case .weekStrip:
                    base = 24
                case .numericBadge:
                    base = max(24, textSize * 1.8)
                }

            case .timer:
                switch style.resolvedTimerPresentation {
                case .digital:
                    base = max(18, lineHeight(textSize))
                case .segmented:
                    base = lineHeight(max(9, textSize * 0.80)) + lineHeight(5.5) + 3
                case .stacked:
                    base = lineHeight(max(10, textSize * 0.92)) + lineHeight(6.5)
                case .progressRing:
                    base = 31
                case .badge:
                    base = max(
                        lineHeight(max(8, textSize * 0.66)),
                        lineHeight(max(9, textSize * 0.78))
                    ) + 6
                }

            case .battery:
                switch style.resolvedBatteryPresentation {
                case .ring:
                    base = 30
                case .gauge:
                    base = max(18, lineHeight(max(8, textSize * 0.68)))
                case .iconPercent, .percent, .bar:
                    base = max(18, lineHeight(textSize))
                }

            case .mirror:
                switch style.resolvedMirrorPresentation {
                case .circle, .square:
                    base = max(30, min(54, style.width ?? 36))
                case .rounded, .pill, .cinematic:
                    base = 32
                }

            case .files:
                switch style.resolvedFilesPresentation {
                case .trayLabel:
                    base = lineHeight(max(10, textSize * 0.90)) + lineHeight(5.5)
                case .folderBadge:
                    base = max(
                        lineHeight(max(11, textSize)),
                        lineHeight(max(8, textSize * 0.72)) + 2
                    )
                case .documentStack:
                    base = max(lineHeight(textSize), lineHeight(max(9, textSize * 0.78)))
                case .iconCount, .count:
                    base = max(18, lineHeight(max(textSize, textSize * 1.05)))
                }

            case .visualizer:
                base = min(42, max(16, (options.visualizer ?? VisualizerOptions()).height))

            case .topMusic:
                let music = style.topMusic ?? TopMusicOptions()
                let contentHeight = music.presentationHeight(fontSize: textSize, rich: false)
                base = style.layout == .stacked || style.layout == .stackedReversed ? contentHeight + (style.iconSize ?? textSize) + (style.spacing ?? 2) : contentHeight

            case .media:
                base = max(20, lineHeight(textSize))

            case .activity:
                base = max(22, lineHeight(textSize))

            case .none:
                base = 0
            }

            return base + style.verticalPadding * 2
        }


        let widgetContentDemand = max(
            preferredContentHeight(items.left),
            preferredContentHeight(items.right)
        )
        let adaptiveCompactHeight = min(
            84,
            max(
                hardwareMinimumHeight,
                widgetContentDemand + options.contentPaddingY * 2
            )
        )
        if adaptiveCompactHeight > baseCompactHeight + 0.5 {
            host.geometry?.activeCompactHeight = adaptiveCompactHeight
        }

        let sizingHeight = max(baseCompactHeight, host.geometry?.activeCompactHeight ?? baseCompactHeight)
        let closedMetrics = ClosedNotchLayoutMetrics(options: options, height: sizingHeight)
        let power = powerReaction(options: options, items: items, compactHeight: sizingHeight)
        let sides = fittedClosedSides(
            host: host,
            layout: layout,
            items: items,
            power: power,
            compactHeight: sizingHeight
        )
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

        let notchLike = attached || geometry.style == .notch || geometry.style == .simulated
        let camera = attached ? geometry.physicalNotchWidth : 0
        let baseWidth = max(16, geometry.appearance.compactWidth)
        let verticalHUD = hudNotchExpansion.flatMap { $0.screenFrame.equalTo(geometry.screen) && $0.vertical ? $0 : nil }

        guard !host.state.editingGeometry else {
            host.geometry?.activeCompactWidth = nil
            host.geometry?.activeCompactHeight = nil
            host.geometry?.activeCompactCenterOffset = nil
            return
        }

        if notchLike {
            // Content fit is a safety floor, not an optional behavior. Even with Auto-size off,
            // the closed surface must grow enough to contain every visible widget. The setting
            // can influence preferred/tight sizing, but it may never permit clipping.
            var leftDemand = sides.left
            var rightDemand = sides.right

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

            // Exact-fit window widths are fragile at zero/very-small margins because SwiftUI
            // glyphs, shadows and animations can draw fractionally outside their nominal bounds.
            // Grow the surface, not the configured content margin.
            if leftDemand > 0 { leftDemand += closedMetrics.renderingAllowance }
            if rightDemand > 0 { rightDemand += closedMetrics.renderingAllowance }

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
            let body = sides.left + sides.right
            if body > 0 {
                requested = max(requested, body + closedMetrics.renderingAllowance * 2)
            }
            if expansion.enabled && (leftExpansionLive || rightExpansionLive) { requested = max(requested, expansion.width) }
            host.geometry?.activeCompactWidth = min(geometry.visible.width, requested)
            host.geometry?.activeCompactCenterOffset = nil
        }

        if let verticalHUD {
            let baseHeight = max(16, geometry.appearance.surface.compactHeight)
            let currentAdaptiveHeight = host.geometry?.activeCompactHeight ?? baseHeight
            host.geometry?.activeCompactHeight = min(
                220,
                max(currentAdaptiveHeight, verticalHUD.height)
            )

            let hudWidth = verticalHUD.width + closedMetrics.outerInset * 2 + closedMetrics.renderingAllowance * 2
            let currentCompactWidth = host.geometry?.activeCompactWidth ?? baseWidth
            host.geometry?.activeCompactWidth = min(
                geometry.visible.width,
                max(currentCompactWidth, hudWidth)
            )
        }
    }

    private func fittedClosedSides(host: Host, layout: WorkspaceLayout,
                                   items: (left: ClosedNotchItem, right: ClosedNotchItem),
                                   power: (side: DynamicSide, badgeWidth: Double, notchMargin: Double, extraSpace: Double)?,
                                   compactHeight: Double) ->
        (left: Double, right: Double, decorationLeft: Double, decorationRight: Double) {
        guard let geometry = host.geometry else { return (0, 0, 0, 0) }
        let options = layout.closedNotch ?? ClosedNotchOptions()
        let mediaVisible = store.workspace.media.hasNowPlayingPresentation
        let mediaPlaying = store.workspace.media.isPlaying
        let activity = activeClosedActivity
        let baseCompactHeight = max(16, compactHeight)
        let metrics = ClosedNotchLayoutMetrics(options: options, height: baseCompactHeight)
        let innerHeight = metrics.contentHeight
        let size = min(options.fontSize, innerHeight / 1.25)
        let font = NSFont.systemFont(ofSize: size)
        let digitFont = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .regular)
        let elementGap = metrics.elementSpacing

        func closedStyle(_ item: ClosedNotchItem) -> ClosedNotchWidgetStyle {
            options.widgetStyle(for: item)
        }

        func nsWeight(_ weight: WidgetFontWeight?) -> NSFont.Weight {
            switch weight ?? .regular {
            case .light: return .light
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            }
        }

        func itemTextSize(_ item: ClosedNotchItem) -> Double {
            min(closedStyle(item).fontSize ?? options.fontSize, innerHeight / 1.25)
        }

        func itemFont(_ item: ClosedNotchItem, digits: Bool = false) -> NSFont {
            let style = closedStyle(item)
            let pointSize = itemTextSize(item)
            let weight = nsWeight(style.fontWeight)
            return digits
                ? NSFont.monospacedDigitSystemFont(ofSize: pointSize, weight: weight)
                : NSFont.systemFont(ofSize: pointSize, weight: weight)
        }

        func itemGap(_ item: ClosedNotchItem) -> Double {
            closedStyle(item).spacing ?? elementGap
        }

        func itemIconWidth(_ item: ClosedNotchItem) -> Double {
            let style = closedStyle(item)
            let iconSize = min(max(8, style.iconSize ?? itemTextSize(item)), max(8, innerHeight))
            let containerPadding: Double = style.resolvedIconStyle == .plain ? 0 : style.resolvedIconPadding * 2
            let capsuleExtra: Double = style.resolvedIconStyle == .capsule ? 4 : 0
            return max(12, iconSize + 2 + containerPadding + capsuleExtra)
        }

        func composedWidth(_ item: ClosedNotchItem, textWidth: Double, automaticShowsIcon: Bool) -> Double {
            let style = closedStyle(item)
            let icon = itemIconWidth(item)
            let gap = itemGap(item)
            switch style.layout {
            case .automatic:
                if automaticShowsIcon {
                    return textWidth > 0 ? icon + gap + textWidth : icon
                }
                return textWidth
            case .iconAndText, .textAndIcon:
                return textWidth > 0 ? icon + gap + textWidth : icon
            case .stacked, .stackedReversed:
                return max(icon, textWidth)
            case .textOnly:
                return textWidth
            case .iconOnly:
                return icon
            }
        }

        func styledItemWidth(_ item: ClosedNotchItem, body: Double) -> Double {
            guard body > 0 else { return 0 }
            return body + closedStyle(item).horizontalPadding * 2
        }

        var artwork = options.artworkOptions ?? ClosedArtworkOptions()
        if options.artworkOptions == nil, let legacy = options.mediaOptions, legacy.artwork != .none {
            artwork.enabled = true; artwork.mode = legacy.artwork; artwork.size = legacy.artworkSize
            artwork.vinylRPM = legacy.vinylRPM; artwork.backgroundOpacity = legacy.backgroundOpacity
        }

        let artworkTarget: DynamicSide? = {
            guard mediaVisible, artwork.enabled, artwork.mode != .none, artwork.mode != .background else { return nil }
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
            guard mediaVisible else { return 0 }
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
            let widgetStyle = closedStyle(.activity)
            let activityFont = itemFont(.activity)
            let activitySize = itemTextSize(.activity)
            let activityGap = itemGap(.activity)
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
            let iconSize = min(max(8, configuredIcon), max(8, activitySize * 1.8))
            let iconContainerPadding: Double = widgetStyle.resolvedIconStyle == .plain ? 0 : widgetStyle.resolvedIconPadding * 2
            let iconWidth = showIcon ? max(12, iconSize + 2 + iconContainerPadding) : 0
            let labelWidth = showLabel ? textWidth(label, font: activityFont) : 0
            let detailFont = NSFont.systemFont(ofSize: max(8, activitySize * 0.76), weight: nsWeight(widgetStyle.fontWeight))
            let detailWidth = showDevice && !activity.detail.isEmpty
                ? textWidth(String(activity.detail.prefix(80)), font: detailFont) : 0

            func inlineTextWidth() -> Double {
                let parts = [labelWidth, detailWidth].filter { $0 > 0 }
                guard !parts.isEmpty else { return 0 }
                return parts.reduce(0, +) + Double(max(0, parts.count - 1)) * activityGap
            }
            let stackedText = max(labelWidth, detailWidth)

            switch layout {
            case .iconOnly:
                return iconWidth
            case .textOnly:
                return stackedText
            case .inline:
                let text = inlineTextWidth()
                if iconWidth > 0 && text > 0 { return iconWidth + activityGap + text }
                return max(iconWidth, text)
            case .stacked:
                if iconWidth > 0 && stackedText > 0 { return iconWidth + activityGap + stackedText }
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
                let closedClockStyle = closedStyle(.clock)
                var style = layout.widgetStyle(for: .clock)
                if let weight = closedClockStyle.fontWeight {
                    style.weight = weight
                }
                style.clock.automaticTypography = false
                if !closedClockStyle.useClockWidgetSettings {
                    style.clock.twentyFourHour = closedClockStyle.clockTwentyFourHour
                    style.clock.showSeconds = closedClockStyle.clockShowSeconds
                    style.clock.showDate = closedClockStyle.clockShowDate
                }
                if let visualStyle = closedClockStyle.clockVisualStyle {
                    style.clock.visualStyle = visualStyle
                }

                let clock = style.clock
                let widgetHeight = max(1, innerHeight - closedClockStyle.verticalPadding * 2)
                let widthScale: Double
                switch clock.resolvedFontWidth {
                case .compressed: widthScale = 0.86
                case .condensed: widthScale = 0.93
                case .standard: widthScale = 1.0
                case .expanded: widthScale = 1.14
                }

                func clockFont(_ pointSize: Double, weight: NSFont.Weight = .medium, digits: Bool = false) -> NSFont {
                    if style.fontFamily == .custom {
                        return NSFont(name: style.customFont, size: pointSize)
                            ?? NSFont.systemFont(ofSize: pointSize, weight: weight)
                    }
                    if digits && clock.usesMonospacedDigits {
                        return NSFont.monospacedDigitSystemFont(ofSize: pointSize, weight: weight)
                    }
                    return NSFont.systemFont(ofSize: pointSize, weight: weight)
                }

                func glyphWidth(
                    _ text: String,
                    font: NSFont,
                    tracking: Double = 0,
                    appliesClockWidth: Bool = true
                ) -> Double {
                    let base = ceil((text as NSString).size(withAttributes: [.font: font]).width)
                    let tracked = base + max(0, tracking) * Double(max(0, text.count - 1))
                    return tracked * (appliesClockWidth ? widthScale : 1)
                }

                let desiredTimeSize: Double
                if clock.usesAutomaticTypography {
                    desiredTimeSize = max(18, widgetHeight * 0.46 * clock.resolvedTimeScale)
                } else {
                    desiredTimeSize = max(8, itemTextSize(.clock) * 1.55 * clock.resolvedTimeScale)
                }
                let timeSize = min(desiredTimeSize, max(12, widgetHeight * 0.72))

                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: clock.timeZone) ?? .current
                let now = Date()
                let hour24 = calendar.component(.hour, from: now)
                let displayHour = clock.twentyFourHour
                    ? hour24
                    : (hour24 % 12 == 0 ? 12 : hour24 % 12)
                let hour = clock.resolvedLeadingZero
                    ? String(format: "%02d", displayHour)
                    : String(displayHour)
                let minute = String(format: "%02d", calendar.component(.minute, from: now))
                let second = String(format: "%02d", calendar.component(.second, from: now))
                let ampm = hour24 < 12 ? "AM" : "PM"

                func rawTime(includeSeconds: Bool, includeAMPM: Bool) -> String {
                    var value = hour + clock.resolvedSeparator.glyph + minute
                    if includeSeconds {
                        value += clock.resolvedSeparator.glyph + second
                    }
                    if includeAMPM {
                        value += " " + ampm
                    }
                    return value
                }

                func digitalWidth(includeSeconds: Bool, includeAMPM: Bool) -> Double {
                    let digitSpacing = max(0, clock.resolvedDigitSpacing)
                    let tracking = clock.resolvedTracking
                    var pieces: [Double] = [
                        glyphWidth(hour, font: clockFont(timeSize * clock.resolvedHourEmphasis, digits: true), tracking: tracking),
                        glyphWidth(clock.resolvedSeparator.glyph, font: clockFont(timeSize * 0.86, weight: .regular)),
                        glyphWidth(minute, font: clockFont(timeSize * clock.resolvedMinuteEmphasis, digits: true), tracking: tracking)
                    ]
                    if includeSeconds {
                        pieces.append(glyphWidth(clock.resolvedSeparator.glyph, font: clockFont(timeSize * 0.54, weight: .regular)))
                        pieces.append(glyphWidth(second, font: clockFont(timeSize * clock.resolvedSecondsEmphasis, digits: true), tracking: tracking))
                    }
                    if includeAMPM {
                        pieces.append(
                            glyphWidth(ampm, font: clockFont(max(8, timeSize * 0.23), weight: .semibold))
                            + max(1, timeSize * 0.02)
                        )
                    }
                    return pieces.reduce(0, +) + digitSpacing * Double(max(0, pieces.count - 1))
                }

                let primaryWidth: Double
                switch clock.resolvedVisualStyle {
                case .digital:
                    primaryWidth = digitalWidth(
                        includeSeconds: clock.showSeconds,
                        includeAMPM: !clock.twentyFourHour && clock.resolvedShowAMPM
                    )

                case .minimal:
                    primaryWidth = digitalWidth(includeSeconds: false, includeAMPM: false)

                case .analog:
                    primaryWidth = max(24, widgetHeight * 0.82)

                case .flip:
                    let cellHeight = min(
                        max(18, widgetHeight * 0.56),
                        max(18, widgetHeight * 0.78)
                    )
                    func pairWidth(_ value: String, height: Double) -> Double {
                        let count = max(1, value.count)
                        return Double(count) * height * 0.54
                            + Double(max(0, count - 1)) * max(2, height * 0.035)
                    }
                    let gap = max(5, cellHeight * 0.10)
                    var parts: [Double] = [
                        pairWidth(hour, height: cellHeight),
                        glyphWidth(
                            clock.resolvedSeparator.glyph,
                            font: NSFont.systemFont(ofSize: cellHeight * 0.48, weight: .medium),
                            appliesClockWidth: false
                        ),
                        pairWidth(minute, height: cellHeight)
                    ]
                    if clock.showSeconds {
                        parts.append(
                            glyphWidth(
                                clock.resolvedSeparator.glyph,
                                font: NSFont.systemFont(ofSize: cellHeight * 0.34, weight: .regular),
                                appliesClockWidth: false
                            )
                        )
                        parts.append(pairWidth(second, height: cellHeight * 0.72))
                    }
                    primaryWidth = parts.reduce(0, +) + gap * Double(max(0, parts.count - 1))

                case .editorial:
                    let time = glyphWidth(
                        hour + clock.resolvedSeparator.glyph + minute,
                        font: clockFont(timeSize * 1.02, weight: .medium)
                    )
                    let compactDateFormatter = DateFormatter()
                    compactDateFormatter.locale = .autoupdatingCurrent
                    compactDateFormatter.timeZone = calendar.timeZone
                    compactDateFormatter.setLocalizedDateFormatFromTemplate("EEE MMMd")
                    let internalDateSize = max(9, min(24, timeSize / clock.resolvedTimeDateRatio * clock.resolvedDateScale) * 0.86)
                    let internalDate = glyphWidth(
                        compactDateFormatter.string(from: now).uppercased(),
                        font: clockFont(internalDateSize, weight: .semibold)
                    )
                    primaryWidth = max(time, internalDate)

                case .stacked:
                    let natural = max(12, widgetHeight * 0.22) * clock.resolvedTimeScale
                    let stackedSize = min(natural, max(12, widgetHeight * 0.36))
                    let primary = max(
                        glyphWidth(hour, font: clockFont(stackedSize * clock.resolvedHourEmphasis, digits: true)),
                        glyphWidth(minute, font: clockFont(stackedSize * clock.resolvedMinuteEmphasis, digits: true))
                    )
                    let secondsWidth = clock.showSeconds
                        ? glyphWidth(second, font: clockFont(stackedSize * 0.42 * clock.resolvedSecondsEmphasis, digits: true))
                        : 0
                    primaryWidth = max(primary, max(secondsWidth, stackedSize * 1.3))

                case .split:
                    func splitCellWidth(_ value: String) -> Double {
                        let text = glyphWidth(value, font: clockFont(timeSize * 0.86, weight: .semibold, digits: true))
                        return text + max(8, timeSize * 0.18) * 2
                    }
                    primaryWidth = splitCellWidth(hour) + 8 + splitCellWidth(minute)

                case .terminal:
                    let terminalSize = timeSize * 0.86
                    let prompt = glyphWidth(
                        "›",
                        font: NSFont.monospacedSystemFont(ofSize: terminalSize * 0.68, weight: .bold),
                        appliesClockWidth: false
                    )
                    let value = glyphWidth(
                        rawTime(
                            includeSeconds: clock.showSeconds,
                            includeAMPM: !clock.twentyFourHour && clock.resolvedShowAMPM
                        ),
                        font: NSFont.monospacedSystemFont(ofSize: terminalSize, weight: .medium),
                        tracking: max(0, clock.resolvedTracking),
                        appliesClockWidth: false
                    )
                    primaryWidth = prompt + 6 + value

                case .lcd:
                    let lcdSize = timeSize * 0.88
                    let value = glyphWidth(
                        rawTime(
                            includeSeconds: clock.showSeconds,
                            includeAMPM: !clock.twentyFourHour && clock.resolvedShowAMPM
                        ),
                        font: NSFont.monospacedSystemFont(ofSize: lcdSize, weight: .medium),
                        tracking: max(1, clock.resolvedTracking),
                        appliesClockWidth: false
                    )
                    primaryWidth = value + max(10, lcdSize * 0.18) * 2

                case .dotMatrix:
                    let matrixSize = timeSize * 0.82
                    let value = glyphWidth(
                        rawTime(
                            includeSeconds: clock.showSeconds,
                            includeAMPM: !clock.twentyFourHour && clock.resolvedShowAMPM
                        ),
                        font: NSFont.monospacedSystemFont(ofSize: matrixSize, weight: .medium),
                        tracking: max(2, clock.resolvedTracking + 2),
                        appliesClockWidth: false
                    )
                    primaryWidth = value + max(10, matrixSize * 0.16) * 2

                case .outline:
                    let outlineSize = timeSize * 0.90
                    let value = glyphWidth(
                        rawTime(
                            includeSeconds: clock.showSeconds,
                            includeAMPM: !clock.twentyFourHour && clock.resolvedShowAMPM
                        ),
                        font: clockFont(outlineSize, weight: .medium),
                        tracking: clock.resolvedTracking
                    )
                    primaryWidth = value + max(12, outlineSize * 0.22) * 2

                case .oversizedTypography:
                    let desired = max(14, widgetHeight * 0.58 * clock.resolvedTimeScale)
                    let oversizedSize = min(desired, max(14, widgetHeight * 0.72))
                    primaryWidth = glyphWidth(
                        rawTime(
                            includeSeconds: clock.showSeconds,
                            includeAMPM: !clock.twentyFourHour && clock.resolvedShowAMPM
                        ),
                        font: clockFont(oversizedSize, weight: .bold)
                    )
                }

                var bodyWidth = primaryWidth
                if clock.showDate {
                    let dateBase = timeSize / clock.resolvedTimeDateRatio * clock.resolvedDateScale
                    let dateSize = min(24, max(9, dateBase))
                    let secondarySize = min(18, max(8, dateSize * 0.88 * clock.resolvedSecondaryScale))
                    let formatter = DateFormatter()
                    formatter.locale = .autoupdatingCurrent
                    formatter.timeZone = calendar.timeZone
                    formatter.setLocalizedDateFormatFromTemplate("EEE MMMd")
                    let dateWidth = glyphWidth(
                        formatter.string(from: now),
                        font: clockFont(secondarySize, weight: .medium)
                    )
                    bodyWidth += max(6, style.resolvedContent.spacing * 0.50) + dateWidth
                }

                // Keep a small cushion for SwiftUI's glyph bearings and transitions. The
                // surface adds a second rendering allowance outside this widget width.
                return styledItemWidth(.clock, body: bodyWidth + 6)

            case .date:
                let dateStyle = closedStyle(.date)
                let now = Date()
                func formatted(_ template: String) -> String {
                    let formatter = DateFormatter()
                    formatter.locale = .autoupdatingCurrent
                    formatter.timeZone = .autoupdatingCurrent
                    formatter.setLocalizedDateFormatFromTemplate(template)
                    return formatter.string(from: now)
                }
                let width: Double
                switch dateStyle.resolvedCalendarPresentation {
                case .compact:
                    width = textWidth(dateStyle.dateStyle.formatted(now), font: itemFont(.date))
                case .dayTile:
                    let monthFont = NSFont.systemFont(ofSize: max(7, itemTextSize(.date) * 0.52), weight: .semibold)
                    let dayFont = NSFont.systemFont(ofSize: max(13, itemTextSize(.date) * 1.15), weight: .bold)
                    width = max(
                        textWidth(formatted("MMM").uppercased(), font: monthFont),
                        textWidth(formatted("d"), font: dayFont)
                    ) + 10
                case .weekdayStack:
                    let weekdayFont = NSFont.systemFont(ofSize: max(7, itemTextSize(.date) * 0.54), weight: .bold)
                    let dateFont = NSFont.systemFont(ofSize: max(10, itemTextSize(.date) * 0.90), weight: .semibold)
                    width = max(
                        textWidth(formatted("EEEE").uppercased(), font: weekdayFont),
                        textWidth("\(formatted("MMM")) \(formatted("d"))", font: dateFont)
                    )
                case .weekStrip:
                    width = 88
                case .numericBadge:
                    let badge = max(24, itemTextSize(.date) * 1.8)
                    let monthFont = NSFont.systemFont(ofSize: max(7, itemTextSize(.date) * 0.52), weight: .bold)
                    let weekdayFont = NSFont.systemFont(ofSize: max(7, itemTextSize(.date) * 0.48), weight: .medium)
                    let labels = max(
                        textWidth(formatted("MMM").uppercased(), font: monthFont),
                        textWidth(formatted("EEEEE"), font: weekdayFont)
                    )
                    width = badge + 5 + labels
                }
                return styledItemWidth(.date, body: width)

            case .timer:
                let timerStyle = closedStyle(.timer)
                let remaining: TimeInterval = {
                    if let deadline = store.deadline { return max(0, deadline.timeIntervalSince(Date())) }
                    return max(0, store.pausedSeconds)
                }()
                let total = max(0, Int(remaining.rounded(.down)))
                let hours = total / 3600
                let minutes = (total % 3600) / 60
                let seconds = total % 60
                let timerValue = hours > 0
                    ? String(format: "%02d:%02d:%02d", hours, minutes, seconds)
                    : String(format: "%02d:%02d", minutes, seconds)
                let width: Double
                switch timerStyle.resolvedTimerPresentation {
                case .digital:
                    width = textWidth(timerValue, font: itemFont(.timer, digits: true))
                case .segmented:
                    let digitFont = NSFont.monospacedDigitSystemFont(
                        ofSize: max(9, itemTextSize(.timer) * 0.80),
                        weight: .bold
                    )
                    let labelFont = NSFont.systemFont(ofSize: 5.5, weight: .semibold)
                    let partWidth = max(
                        textWidth("88", font: digitFont),
                        textWidth("M", font: labelFont)
                    ) + 6
                    width = partWidth * 3 + 4
                case .stacked:
                    let valueFont = NSFont.monospacedDigitSystemFont(
                        ofSize: max(10, itemTextSize(.timer) * 0.92),
                        weight: .bold
                    )
                    let statusFont = NSFont.systemFont(ofSize: 6.5, weight: .semibold)
                    width = max(
                        textWidth(timerValue, font: valueFont),
                        textWidth("REMAINING", font: statusFont)
                    )
                case .progressRing:
                    width = 31
                case .badge:
                    let icon = max(10, itemTextSize(.timer) * 0.66 + 2)
                    let valueFont = NSFont.monospacedDigitSystemFont(
                        ofSize: max(9, itemTextSize(.timer) * 0.78),
                        weight: .semibold
                    )
                    width = icon + 4 + textWidth(timerValue, font: valueFont) + 14
                }
                return styledItemWidth(.timer, body: width)

            case .battery:
                let batteryStyle = closedStyle(.battery)
                let level = store.workspace.system.battery ?? 100
                let percent = "\(level)%"
                let width: Double
                switch batteryStyle.resolvedBatteryPresentation {
                case .iconPercent:
                    width = max(12, itemTextSize(.battery) + 2)
                        + 4
                        + textWidth(percent, font: itemFont(.battery, digits: true))
                case .percent:
                    let percentFont = NSFont.systemFont(ofSize: max(10, itemTextSize(.battery)), weight: .bold)
                    width = textWidth(percent, font: percentFont)
                case .bar:
                    let percentFont = NSFont.systemFont(
                        ofSize: max(8, itemTextSize(.battery) * 0.68),
                        weight: .semibold
                    )
                    width = 44 + 5 + textWidth(percent, font: percentFont)
                case .ring:
                    width = 30
                case .gauge:
                    let trailing: Double
                    if store.workspace.system.charging {
                        trailing = 9
                    } else {
                        trailing = textWidth(
                            percent,
                            font: NSFont.systemFont(ofSize: 8, weight: .semibold)
                        )
                    }
                    width = 34 + 2 + 8 + trailing
                }
                return styledItemWidth(.battery, body: width)

            case .topMusic:
                return styledItemWidth(.topMusic, body: closedStyle(.topMusic).width ?? 180)

            case .media:
                return mediaWidth()

            case .visualizer:
                return mediaVisible ? (options.visualizer ?? VisualizerOptions()).width : 0

            case .mirror:
                let mirrorStyle = closedStyle(.mirror)
                let defaultWidth: Double
                switch mirrorStyle.resolvedMirrorPresentation {
                case .rounded: defaultWidth = 112
                case .circle, .square: defaultWidth = innerHeight
                case .pill: defaultWidth = 92
                case .cinematic: defaultWidth = 144
                }
                let requested = mirrorStyle.width ?? defaultWidth
                let measuredWidth: Double
                switch mirrorStyle.resolvedMirrorPresentation {
                case .circle, .square:
                    measuredWidth = min(requested, innerHeight)
                default:
                    measuredWidth = requested
                }
                return styledItemWidth(.mirror, body: max(24, measuredWidth))

            case .files:
                let filesStyle = closedStyle(.files)
                let count = String(store.files.count)
                let width: Double
                switch filesStyle.resolvedFilesPresentation {
                case .iconCount:
                    width = max(12, itemTextSize(.files) + 2)
                        + 4
                        + textWidth(count, font: itemFont(.files, digits: true))
                case .count:
                    let countFont = NSFont.systemFont(
                        ofSize: max(11, itemTextSize(.files) * 1.05),
                        weight: .bold
                    )
                    width = textWidth(count, font: countFont)
                case .folderBadge:
                    let icon = max(13, itemTextSize(.files) + 2)
                    let countFont = NSFont.systemFont(
                        ofSize: max(8, itemTextSize(.files) * 0.72),
                        weight: .bold
                    )
                    width = icon + 4 + textWidth(count, font: countFont) + 10
                case .documentStack:
                    let countFont = NSFont.systemFont(
                        ofSize: max(9, itemTextSize(.files) * 0.78),
                        weight: .bold
                    )
                    width = 24 + 6 + textWidth(count, font: countFont)
                case .trayLabel:
                    let countFont = NSFont.systemFont(
                        ofSize: max(10, itemTextSize(.files) * 0.90),
                        weight: .bold
                    )
                    let labelFont = NSFont.systemFont(ofSize: 5.5, weight: .semibold)
                    width = max(
                        textWidth(count, font: countFont),
                        textWidth(store.files.count == 1 ? "FILE" : "FILES", font: labelFont)
                    )
                }
                return styledItemWidth(.files, body: width)

            case .activity:
                guard let activity else { return 0 }
                let activityStyle = closedStyle(.activity)
                let rawWidth: Double
                if let bluetooth = bluetoothActivityWidth(activity) {
                    rawWidth = min(240, max(0, bluetooth))
                } else {
                    let title = textWidth(String(activity.title.prefix(80)), font: itemFont(.activity))
                    let detailFont = NSFont.systemFont(
                        ofSize: max(8, itemTextSize(.activity) * 0.76),
                        weight: nsWeight(activityStyle.fontWeight)
                    )
                    let detail = activityStyle.showSecondaryText && !activity.detail.isEmpty
                        ? textWidth(String(activity.detail.prefix(80)), font: detailFont)
                        : 0
                    var textBlock = max(title, detail)
                    if activityStyle.showProgress, activity.progress != nil {
                        textBlock += itemGap(.activity) + 38
                    }
                    rawWidth = composedWidth(
                        .activity,
                        textWidth: textBlock,
                        automaticShowsIcon: true
                    )
                }
                let capped = activityStyle.width.map { min(rawWidth, max(32, $0)) } ?? rawWidth
                return styledItemWidth(.activity, body: min(320, max(0, capped)))
            }
        }

        func decorationWidth(_ decoration: SideDecoration?) -> Double {
            decoration.flatMap {
                $0.isVisible(playing: mediaPlaying) ? min($0.size, innerHeight) : nil
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
        let now = Date()
        if let next = ClosedNotchContentResolver.nextExpiry(
            in: store.workspace.activities,
            preferences: closedNotchActivityPreferences,
            now: now
        ) {
            let work = DispatchWorkItem { [weak self] in self?.refreshDynamicWidths() }
            activityExpiry = work
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0.01, next.timeIntervalSince(now)), execute: work)
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

            guard !host.state.expanded && !host.state.presentationExpanded else {
                host.state.compactWidth = newWidth
                host.state.compactHeight = newHeight
                host.state.closedOcclusion = geometry.closedCameraOcclusion
                continue
            }

            let hasTransientCompactOverride =
                host.state.contextPreferredCompactWidth != nil ||
                host.state.contextPreferredCompactHeight != nil ||
                host.state.reviewPromptPreferredCompactHeight != nil
            var target = hasTransientCompactOverride
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
        endSettingsSurfacePreview()
        activityExpiry?.cancel()
        hudNotchHideWork?.cancel(); hudNotchHideWork = nil
        if let hudMonitor { NSEvent.removeMonitor(hudMonitor); self.hudMonitor = nil }
        hosts.values.forEach {
            $0.pixelPalCollapseWork?.cancel()
            $0.hoverOpeningCompletionWork?.cancel()
            $0.stop()
        }
        hosts.removeAll()
        subscriptions.removeAll()
    }

    private func beginSettingsSurfacePreview(expanded: Bool, displayID: String?) {
        settingsSurfacePreviewExpanded = expanded
        settingsSurfacePreviewDisplayID = displayID

        for (id, host) in hosts {
            guard displayID == nil || displayID == id else { continue }
            if settingsSurfacePreviewPreviousExpanded[id] == nil {
                settingsSurfacePreviewPreviousExpanded[id] = host.state.expanded
            }
            host.state.collapseTask?.cancel()
            host.state.collapseTask = nil
            host.state.hoverExpandTask?.cancel()
            host.state.hoverExpandTask = nil
            if host.state.expanded != expanded {
                host.state.expanded = expanded
            } else {
                applyExpandedState(expanded, to: host)
            }
        }
    }

    private func endSettingsSurfacePreview() {
        let previous = settingsSurfacePreviewPreviousExpanded
        settingsSurfacePreviewExpanded = nil
        settingsSurfacePreviewDisplayID = nil
        settingsSurfacePreviewPreviousExpanded.removeAll()

        for (id, wasExpanded) in previous {
            guard let host = hosts[id] else { continue }
            host.state.collapseTask?.cancel()
            host.state.collapseTask = nil
            host.state.hoverExpandTask?.cancel()
            host.state.hoverExpandTask = nil
            if host.state.expanded != wasExpanded {
                host.state.expanded = wasExpanded
            } else {
                applyExpandedState(wasExpanded, to: host)
            }
        }
    }

    private func settingsPreviewTarget(for displayID: String) -> Bool? {
        guard let expanded = settingsSurfacePreviewExpanded else { return nil }
        guard settingsSurfacePreviewDisplayID == nil || settingsSurfacePreviewDisplayID == displayID else { return nil }
        return expanded
    }

    func toggleAll() {
        let expand = !hosts.values.contains { $0.state.expanded }
        hosts.values.forEach { $0.state.collapseTask?.cancel(); $0.state.expanded = expand }
    }

    /// Opens the existing Halo surfaces without toggling any already-open surface closed.
    /// Used by activation affordances such as copying a license key while Halo is locked.
    func expandAll() {
        hosts.values.forEach { host in
            host.state.collapseTask?.cancel()
            if !host.state.expanded {
                host.state.expanded = true
            }
        }
    }

    private func activeExpandedContextRequest(for host: Host) -> CGSize? {
        // Context sizing is valid only while a CI actually owns the surface.
        // A late measurement from a dismissed CI must never override the normal
        // workspace's configured width/height.
        guard host.state.activeCIIdentifier != nil else { return nil }
        return host.state.contextPreferredSize
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
        let closedHeightRequest: CGFloat? = {
            if let review = host.state.reviewPromptPreferredCompactHeight { return review }
            return host.state.contextPreferredCompactHeight
        }()
        return expanded
            ? adjustedExpandedFrame(host: host, requested: activeExpandedContextRequest(for: host))
            : adjustedClosedFrame(host: host, requestedWidth: host.state.contextPreferredCompactWidth,
                                  requestedHeight: closedHeightRequest)
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
        if store.workspace.settings.resolvedNotchMode == .simple {
            return store.workspace.settings.resolvedSimpleNotch.widgets.contains(.pet)
        }
        let layout = host.state.layoutOverride ?? store.workspace.effectiveLayout
        guard layout.resolvedUsesCustomOpenNotchWorkspace else { return false }
        return layout.resolvedOpenNotchLayout.resolvedGridItems.contains {
            $0.module == .pet && !$0.hidden
        }
    }

    private func hoverOpeningAnimationDuration(for host: Host) -> TimeInterval {
        guard let geometry = host.geometry else { return 0 }

        let options = geometry.appearance.surface
        let animationsEnabled =
            host.state.theme.animations &&
            !host.state.editingGeometry &&
            !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion &&
            geometry.appearance.animation != .none &&
            options.opening != .instant

        guard animationsEnabled else { return 0 }
        return max(0.01, options.duration)
    }

    private func armHoverOpeningGuardIfNeeded(for host: Host) {
        host.hoverOpeningCompletionWork?.cancel()
        host.hoverOpeningCompletionWork = nil

        guard host.state.consumeHoverExpansionRequest() else {
            host.state.cancelHoverOpeningGuard()
            return
        }

        let duration = hoverOpeningAnimationDuration(for: host)
        guard duration > 0.001 else {
            host.state.cancelHoverOpeningGuard()
            return
        }

        host.state.beginHoverOpeningGuard()

        let work = DispatchWorkItem { [weak host] in
            guard let host else { return }
            host.hoverOpeningCompletionWork = nil

            let cursorInsidePanel = NSMouseInRect(
                NSEvent.mouseLocation,
                host.panel.frame,
                false
            )
            host.state.completeHoverOpeningGuard(
                cursorInsidePanel: cursorInsidePanel
            )
        }
        host.hoverOpeningCompletionWork = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + duration,
            execute: work
        )
    }

    private func applyExpandedState(_ expanded: Bool, to host: Host) {
        guard let geometry = host.geometry else { return }
        if expanded { host.state.beginExpandedPresentation() }

        var target = targetFrame(host: host, expanded: expanded)
        if geometry.style == .detached {
            let oldOffset = geometry.offset(expanded: !expanded)
            let newOffset = geometry.offset(expanded: expanded)
            target.origin.x = host.panel.frame.midX - target.width / 2 + newOffset.width - oldOffset.width
            target.origin.y = host.panel.frame.maxY - target.height + newOffset.height - oldOffset.height
        }

        if expanded {
            let baseWidth = geometry.frame(expanded: true).width
            let contentWidth = activeExpandedContextRequest(for: host) != nil ? target.width : baseWidth
            if host.state.dashboardWidth != contentWidth { host.state.dashboardWidth = contentWidth }
        }
        host.targetFrame = target
        let completion: (() -> Void)? = expanded ? nil : { [weak host] in
            guard let host, !host.state.expanded else { return }
            host.state.completeCollapsedPresentation()
        }
        var motion = geometry.appearance.surface
        var motionPreset = geometry.appearance.animation

        if store.workspace.settings.resolvedNotchMode == .simple {
            // Simple Mode is meant to feel like the native notch itself stretching,
            // not a dashboard bouncing into place. Use a monotonic resize and make
            // retraction slightly quicker than expansion.
            motion.opening = .resize
            motion.closing = .resize
            motion.duration = expanded ? 0.26 : 0.22
            motion.damping = 1
            motionPreset = .smooth
        }

        host.animator.move(
            panel: host.panel,
            state: host.state,
            target: target,
            options: motion,
            preset: motionPreset,
            animations: host.state.theme.animations && !host.state.editingGeometry,
            opening: expanded,
            style: geometry.style,
            completion: completion
        )
    }

    private func schedulePixelPalGatedCollapse(for host: Host) -> Bool {
        guard HaloFeatureAccess.shared.allows(.pixelPal) else {
            host.state.setPixelPalCloseGateActive(false)
            return false
        }

        // Hold the physical notch fully open while Pixel Pal performs its shutdown.
        // Once the animation reaches .off, Pixel Pal is completely transparent, then
        // the notch begins its normal retract animation.
        let containsPixelPal = layoutContainsVisualWorkspacePixelPal(host)
        guard HaloPixelPalCloseGatePolicy.shouldDelayCollapse(
            layoutContainsPixelPal: containsPixelPal,
            activeCIIdentifier: host.state.activeCIIdentifier
        ) else {
            host.state.setPixelPalCloseGateActive(false)
            return false
        }

        let preferences = HaloPixelPalStore.shared.preferences
        guard preferences.bootDownAnimation != .none else {
            host.state.setPixelPalCloseGateActive(false)
            return false
        }

        let delay = HaloPixelPalPowerAnimationTiming.closeGateDelay(
            style: preferences.bootDownAnimation,
            speed: preferences.powerAnimationSpeed
        )
        guard delay > 0.001 else {
            host.state.setPixelPalCloseGateActive(false)
            return false
        }

        host.pixelPalCollapseWork?.cancel()
        host.state.setPixelPalCloseGateActive(true)

        let work = DispatchWorkItem { [weak self, weak host] in
            guard let self, let host, !host.state.expanded else { return }
            host.pixelPalCollapseWork = nil
            self.applyExpandedState(false, to: host)
        }
        host.pixelPalCollapseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        return true
    }

    private struct ForegroundWindowCoverage {
        let bundleIdentifier: String
        var maximizedDisplayIDs: Set<String>
        var fullScreenDisplayIDs: Set<String>
    }

    private func refreshAppAutomationVisibilityIfNeeded() {
        guard store.workspace.settings.resolvedAppNotchHideRules.contains(where: {
            $0.enabled && !$0.bundleIdentifier.isEmpty
        }) else {
            if !appAutomationHiddenDisplayIDs.isEmpty {
                appAutomationHiddenDisplayIDs.removeAll()
                reconcile()
            }
            return
        }

        let screens = store.configuration.allDisplays ? NSScreen.screens : Array(NSScreen.screens.prefix(1))
        let next = resolvedAppAutomationHiddenDisplayIDs(for: screens)
        guard next != appAutomationHiddenDisplayIDs else { return }
        appAutomationHiddenDisplayIDs = next
        reconcile()
    }

    private func resolvedAppAutomationHiddenDisplayIDs(for screens: [NSScreen]) -> Set<String> {
        let rules = store.workspace.settings.resolvedAppNotchHideRules.filter {
            $0.enabled && !$0.bundleIdentifier.isEmpty
        }
        guard !rules.isEmpty,
              let coverage = foregroundWindowCoverage(for: screens) else {
            return []
        }

        var hidden = Set<String>()

        for rule in rules where rule.bundleIdentifier == coverage.bundleIdentifier {
            for screen in screens {
                let displayID = Self.displayID(screen)
                guard rule.targets(displayID: displayID) else { continue }

                let matches: Bool
                switch rule.condition {
                case .foreground:
                    matches = true
                case .maximized:
                    matches = coverage.maximizedDisplayIDs.contains(displayID)
                case .fullScreen:
                    matches = coverage.fullScreenDisplayIDs.contains(displayID)
                case .maximizedOrFullScreen:
                    matches = coverage.maximizedDisplayIDs.contains(displayID) ||
                        coverage.fullScreenDisplayIDs.contains(displayID)
                }

                if matches {
                    hidden.insert(displayID)
                }
            }
        }

        return hidden
    }

    private func foregroundWindowCoverage(for screens: [NSScreen]) -> ForegroundWindowCoverage? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleIdentifier = app.bundleIdentifier,
              !bundleIdentifier.isEmpty else {
            return nil
        }

        var result = ForegroundWindowCoverage(
            bundleIdentifier: bundleIdentifier,
            maximizedDisplayIDs: [],
            fullScreenDisplayIDs: []
        )

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return result
        }

        let primaryTop = NSScreen.screens.first?.frame.maxY ?? 0
        let pid = app.processIdentifier

        for windowInfo in windows {
            guard (windowInfo[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
                  (windowInfo[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  ((windowInfo[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1) > 0.01,
                  let bounds = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let x = (bounds["X"] as? NSNumber)?.doubleValue,
                  let y = (bounds["Y"] as? NSNumber)?.doubleValue,
                  let width = (bounds["Width"] as? NSNumber)?.doubleValue,
                  let height = (bounds["Height"] as? NSNumber)?.doubleValue,
                  width >= 160,
                  height >= 100 else {
                continue
            }

            let windowFrame = CGRect(
                x: x,
                y: Double(primaryTop) - y - height,
                width: width,
                height: height
            )

            guard let screen = bestScreen(for: windowFrame, screens: screens) else { continue }
            let displayID = Self.displayID(screen)

            if window(windowFrame, effectivelyCovers: screen.frame, minimumCoverage: 0.96, edgeTolerance: 18) {
                result.fullScreenDisplayIDs.insert(displayID)
                continue
            }

            if window(windowFrame, effectivelyCovers: screen.visibleFrame, minimumCoverage: 0.90, edgeTolerance: 40) {
                result.maximizedDisplayIDs.insert(displayID)
            }
        }

        return result
    }

    private func bestScreen(for windowFrame: CGRect, screens: [NSScreen]) -> NSScreen? {
        screens.max { lhs, rhs in
            intersectionArea(windowFrame, lhs.frame) < intersectionArea(windowFrame, rhs.frame)
        }.flatMap { screen in
            intersectionArea(windowFrame, screen.frame) > 1 ? screen : nil
        }
    }

    private func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull, !intersection.isEmpty else { return 0 }
        return max(0, intersection.width) * max(0, intersection.height)
    }

    private func window(
        _ windowFrame: CGRect,
        effectivelyCovers target: CGRect,
        minimumCoverage: CGFloat,
        edgeTolerance: CGFloat
    ) -> Bool {
        guard target.width > 0, target.height > 0 else { return false }

        let targetArea = target.width * target.height
        let coverage = intersectionArea(windowFrame, target) / targetArea
        guard coverage >= minimumCoverage else { return false }

        let reachesLeft = windowFrame.minX <= target.minX + edgeTolerance
        let reachesRight = windowFrame.maxX >= target.maxX - edgeTolerance
        let reachesBottom = windowFrame.minY <= target.minY + edgeTolerance
        let reachesTop = windowFrame.maxY >= target.maxY - edgeTolerance
        return reachesLeft && reachesRight && reachesBottom && reachesTop
    }

    private func reviewPromptTargetHostID() -> String? {
        if let main = NSScreen.main {
            let mainID = Self.displayID(main)
            if hosts[mainID] != nil { return mainID }
        }

        for screen in NSScreen.screens {
            let id = Self.displayID(screen)
            if hosts[id] != nil { return id }
        }

        return hosts.keys.first
    }

    private func synchronizeReviewPromptPresentation(presented: Bool? = nil) {
        let shouldPresent = presented ?? HaloReviewPromptCoordinator.shared.isPresented
        let targetID = shouldPresent ? reviewPromptTargetHostID() : nil
        let extraHeight: CGFloat = 54

        for (id, host) in hosts {
            guard let geometry = host.geometry else { continue }
            let ownsPrompt = shouldPresent && id == targetID

            if ownsPrompt {
                let base = host.state.reviewPromptBaseCompactHeight ?? geometry.compactHeight
                host.state.reviewPromptBaseCompactHeight = base
                let requested = min(
                    220,
                    max(base + extraHeight, host.state.physicalNotchHeight + extraHeight)
                )
                if host.state.reviewPromptPreferredCompactHeight != requested {
                    host.state.reviewPromptPreferredCompactHeight = requested
                }
            } else {
                if host.state.reviewPromptPreferredCompactHeight != nil {
                    host.state.reviewPromptPreferredCompactHeight = nil
                }
                host.state.reviewPromptBaseCompactHeight = nil
            }
        }
    }

    private func reconcile() {
        let simpleMode = store.workspace.settings.resolvedNotchMode == .simple
        if simpleMode {
            let session = SurfaceGeometryEditingSession.shared
            if session.isEnabled {
                session.cancelTransaction()
                session.previewSnapshot = nil
                session.isEnabled = false
                session.displayID = nil
            }
        }

        let screens = store.configuration.allDisplays ? NSScreen.screens : Array(NSScreen.screens.prefix(1))
        let hiddenDisplayIDs = resolvedAppAutomationHiddenDisplayIDs(for: screens)
        appAutomationHiddenDisplayIDs = hiddenDisplayIDs
        var active = Set<String>()
        for screen in screens {
            let access = HaloFeatureAccess.shared
            let id = Self.displayID(screen)
            let override = store.workspace.settings.displays.first { $0.id == id }
            guard override?.enabled != false else { continue }
            guard !hiddenDisplayIDs.contains(id) else { continue }

            let usesDisplayCustomization = access.allows(.multiDisplayCustomization)
            let displayProfile = usesDisplayCustomization
                ? override?.profileID.flatMap { profileID in
                    store.workspace.settings.profiles.first { $0.id == profileID }
                }
                : nil

            active.insert(id)
            let existing = hosts[id]
            let host = existing ?? Host()

            if simpleMode {
                if host.state.pinned { host.state.pinned = false }
                if host.state.activeCIIdentifier != nil { host.state.activeCIIdentifier = nil }
                host.state.contextPreferredSize = nil
                host.state.contextPreferredCompactWidth = nil
                host.state.contextPreferredCompactHeight = nil
                host.state.contextMinimumExpandedWidth = nil
                host.state.editingGeometry = false
                host.state.cancelFileDrop()
            }

            let savedTheme: Theme = usesDisplayCustomization
                ? (displayProfile?.theme ?? override?.theme ?? store.workspace.scheduledTheme ?? store.configuration.theme)
                : (store.workspace.scheduledTheme ?? store.configuration.theme)
            var theme = access.effectiveTheme(savedTheme)
            if store.configuration.simulateNotch && theme.style == .notch { theme.style = .simulated }

            let displayLayout = usesDisplayCustomization ? (displayProfile?.layout ?? override?.layout) : nil
            let effectiveLayout = access.effectiveLayout(displayLayout ?? store.workspace.effectiveLayout)
            var appearance = effectiveLayout.appearance
            // Preserve the old horizontal-height behavior only for legacy Default layouts
            // saved before the explicit opened-notch content mode existed. Visual Workspace
            // has its own content mode and must always honor Appearance.expandedHeight;
            // migrated layouts can still carry horizontalWidgets = true, which previously
            // overwrote the live opened-height slider on every reconcile.
            if !effectiveLayout.resolvedUsesCustomOpenNotchWorkspace,
               effectiveLayout.openNotchContentMode == nil,
               effectiveLayout.horizontalWidgets ?? false {
                let requested = effectiveLayout.horizontalHeight ?? 260
                appearance.expandedHeight = requested.isFinite ? min(1100, max(200, requested)) : 260
            }

            if store.workspace.settings.resolvedNotchMode == .simple {
                let simple = store.workspace.settings.resolvedSimpleNotch
                let physicalWidth: Double = {
                    if let left = screen.auxiliaryTopLeftArea,
                       let right = screen.auxiliaryTopRightArea {
                        return max(0, Double(right.minX - left.maxX))
                    }
                    return screen.safeAreaInsets.top > 0 ? 190 : 0
                }()
                let hasPhysicalNotch = screen.safeAreaInsets.top > 0 && physicalWidth > 0

                let size = simple.resolvedSize
                let physicalHeight = hasPhysicalNotch ? max(16, Double(screen.safeAreaInsets.top)) : 0
                let hardwareShellWidth = hasPhysicalNotch ? physicalWidth + 24 : 0
                let hardwareShellHeight = hasPhysicalNotch ? physicalHeight + 2 : 0
                let presetClosedWidth = SimpleNotchMetrics.closedPillWidth(size)
                let presetClosedHeight = SimpleNotchMetrics.closedHeight(size)

                theme.style = hasPhysicalNotch ? .notch : .pill
                let arrangement = SimpleNotchMetrics.arrangement(
                    settings: simple, availableWidth: Double(screen.visibleFrame.width) - 32,
                    hardwareWidth: hardwareShellWidth
                )
                theme.width = arrangement.width
                theme.cornerRadius = hasPhysicalNotch ? 18 : 22

                appearance.background = .solid
                appearance.solidColor = WidgetColor(red: 0, green: 0, blue: 0)
                appearance.gradientStartColor = WidgetColor(red: 0, green: 0, blue: 0)
                appearance.gradientEndColor = WidgetColor(red: 0, green: 0, blue: 0)
                appearance.assetPath = ""
                appearance.blur = 0
                appearance.saturation = 1
                appearance.brightness = 0
                appearance.skin = NotchSkinOptions()
                // Closed Simple Mode hugs real notch hardware. The selected Simple size
                // controls the opened surface; closed widgets may expand the compact frame later
                // in configureSimpleDynamicWidth(_:geometry:).
                appearance.compactWidth = hasPhysicalNotch ? hardwareShellWidth : presetClosedWidth
                appearance.expandedHeight = arrangement.height
                appearance.spacing = SimpleNotchMetrics.widgetSpacing(size)
                appearance.animation = .smooth

                appearance.surface.useStyleContour = true
                appearance.surface.shape = hasPhysicalNotch ? .scoop : .capsule
                appearance.surface.compactHeight = hasPhysicalNotch ? hardwareShellHeight : presetClosedHeight
                appearance.surface.opening = .resize
                appearance.surface.closing = .resize
                appearance.surface.duration = 0.26
                appearance.surface.damping = 1.0
                appearance.surface.shoulder = hasPhysicalNotch ? 22 : 0
                appearance.surface.offsets = SurfaceOffsets()
            }
            appearance.surface = (try? appearance.surface.validated()) ?? SurfaceOptions()
            if host.state.activationSurfaceOptions != appearance.surface {
                host.state.activationSurfaceOptions = appearance.surface
            }
            let previousOffset = host.geometry?.offset(expanded: host.state.expanded) ?? .zero
            let previousClosedWidth = host.geometry?.compactWidth
            let previousClosedCenterOffset = host.geometry?.activeCompactCenterOffset ?? 0

            let closedOptions = effectiveLayout.closedNotch ?? ClosedNotchOptions()
            let closedWidgetSelectionChanged =
                existing != nil &&
                host.closedWidgetLeft != nil &&
                host.closedWidgetRight != nil &&
                (host.closedWidgetLeft != closedOptions.left || host.closedWidgetRight != closedOptions.right)
            host.closedWidgetLeft = closedOptions.left
            host.closedWidgetRight = closedOptions.right

            host.geometry = Self.geometry(screen: screen, theme: theme, appearance: appearance)
            if host.state.screenFrame != screen.frame { host.state.screenFrame = screen.frame }
            if host.state.displayID != id { host.state.displayID = id }
            let ambientPhysicalWidth = host.geometry!.physicalNotchWidth > 0 ? host.geometry!.physicalNotchWidth : min(190, host.geometry!.compactWidth)
            let ambientPhysicalHeight = host.geometry!.safeAreaTop > 0 ? host.geometry!.safeAreaTop : min(34, host.geometry!.compactHeight)
            if host.state.physicalNotchWidth != ambientPhysicalWidth { host.state.physicalNotchWidth = ambientPhysicalWidth }
            if host.state.physicalNotchHeight != ambientPhysicalHeight { host.state.physicalNotchHeight = ambientPhysicalHeight }
            updateAmbientPanelFrame(host: host, geometry: host.geometry!)
            if host.state.theme != theme { host.state.theme = theme }
            // SurfaceView should always render from the exact layout used to build
            // this host's geometry. Keeping only displayLayout here left global and
            // scheduled layouts on a separate fallback path and made live geometry
            // edits vulnerable to stale/competing configuration.
            if host.state.layoutOverride != effectiveLayout {
                host.state.layoutOverride = effectiveLayout
            }

            // Visual Workspace draws its own contour/chrome. The native NSPanel shadow
            // is rectangular/window-level and can bleed through the transparent surface,
            // which reads as a muddy inner shadow around bright workspaces. Disable the
            // native shadow there; Default workspace keeps the normal macOS panel shadow.
            host.panel.hasShadow = simpleMode ? false : !effectiveLayout.resolvedUsesCustomOpenNotchWorkspace

            configureDynamicWidth(host)
            let baseDashboardWidth = host.geometry!.frame(expanded: true).width
            if activeExpandedContextRequest(for: host) == nil &&
                host.state.dashboardWidth != baseDashboardWidth {
                host.state.dashboardWidth = baseDashboardWidth
            }
            let animateClosedWidgetResize =
                closedWidgetSelectionChanged &&
                !host.state.expanded &&
                !host.state.presentationExpanded

            // During the widget-swap resize, SurfaceAnimator publishes the intermediate
            // closed geometry frame-by-frame. Publishing the final size here first would
            // make SwiftUI jump to the destination before the panel has moved.
            if !animateClosedWidgetResize {
                if host.state.compactHeight != host.geometry!.compactHeight { host.state.compactHeight = host.geometry!.compactHeight }
                if host.state.compactWidth != host.geometry!.compactWidth { host.state.compactWidth = host.geometry!.compactWidth }
                if host.state.closedOcclusion != host.geometry!.closedCameraOcclusion { host.state.closedOcclusion = host.geometry!.closedCameraOcclusion }
            }
            host.panel.isMovableByWindowBackground = theme.style == .detached
            var target = targetFrame(host: host, expanded: host.state.expanded)
            if existing != nil && theme.style == .detached {
                let delta = host.geometry!.offset(expanded: host.state.expanded)
                target.origin.x = host.panel.frame.midX - target.width / 2 + delta.width - previousOffset.width
                target.origin.y = host.panel.frame.maxY - target.height + delta.height - previousOffset.height
            }
            if host.targetFrame != target {
                host.targetFrame = target

                if animateClosedWidgetResize {
                    let newClosedWidth = host.geometry!.compactWidth
                    let newClosedCenterOffset = host.geometry!.activeCompactCenterOffset ?? 0
                    let oldLogicalWidth = previousClosedWidth ?? newClosedWidth
                    let oldLeft = previousClosedCenterOffset - oldLogicalWidth / 2
                    let oldRight = previousClosedCenterOffset + oldLogicalWidth / 2
                    let newLeft = newClosedCenterOffset - newClosedWidth / 2
                    let newRight = newClosedCenterOffset + newClosedWidth / 2
                    let leftDelta = abs(newLeft - oldLeft)
                    let rightDelta = abs(newRight - oldRight)
                    let fixedEdge: CGRectEdge? = {
                        let tolerance = 0.75
                        if leftDelta <= tolerance && rightDelta > tolerance { return .minXEdge }
                        if rightDelta <= tolerance && leftDelta > tolerance { return .maxXEdge }
                        return nil
                    }()

                    var motion = host.geometry!.appearance.surface
                    motion.opening = .spring
                    motion.closing = .spring
                    motion.duration = min(0.38, max(0.24, motion.duration))
                    motion.damping = min(0.80, max(0.62, motion.damping))

                    host.animator.move(
                        panel: host.panel,
                        state: host.state,
                        target: target,
                        options: motion,
                        preset: .elastic,
                        animations: host.state.theme.animations && !host.state.editingGeometry,
                        opening: true,
                        style: host.geometry!.style,
                        liveViewportResize: true,
                        fixedHorizontalEdge: fixedEdge,
                        synchronizeClosedGeometry: true,
                        closedCameraFrame: physicalCameraFrame(for: host.geometry!)
                    )
                } else {
                    host.animator.cancel()
                    if host.state.viewport.size != target.size { host.state.viewport.size = target.size }
                    host.panel.alphaValue = 1
                    if host.panel.frame != target { host.panel.setFrame(target, display: false) }
                    NotificationCenter.default.post(name: .init("HaloPanelGeometryChanged"), object: host.panel,
                                                    userInfo: ["frame": target, "screen": id])
                }
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
                view.surfaceRuntimeAllowed = { [weak self] in
                    self?.surfaceRuntimeEnabled ?? false
                }
                view.dropZoneOverlayAllowed = { [weak self, weak host] in
                    guard let self, let host else { return false }
                    return self.dropCISettingEnabled && host.state.activeCIIdentifier == "builtin.drop"
                }
                host.refreshDropCIRegistration = { [weak view] in
                    view?.refreshDropRegistration()
                }
                view.dragStateHandler = { [weak self, weak host] active, urls in
                    guard let self, let host else { return false }
                    guard self.surfaceRuntimeEnabled else {
                        host.state.cancelFileDrop()
                        return false
                    }

                    let runtime = IntegrationCIRuntime.shared
                    if active {
                        ActivationSequenceCoordinator.shared.cancelForInteraction()
                        host.state.beginFileDrop(count: urls.count)
                        let integrationsAllowed = HaloFeatureAccess.shared.allows(.integrations)
                        let partnerEligible = integrationsAllowed
                            ? runtime.fileDragEntered(files: urls, displayID: id)
                            : false
                        let claimed = self.dropCISettingEnabled || partnerEligible
                        if !claimed {
                            host.state.cancelFileDrop()
                            _ = runtime.fileDragExited(displayID: id, pinned: host.state.pinned)
                        }
                        return claimed
                    }

                    host.state.endFileDrop()
                    let shouldCollapse = HaloFeatureAccess.shared.allows(.integrations)
                        ? runtime.fileDragExited(displayID: id, pinned: host.state.pinned)
                        : false
                    if shouldCollapse && !host.state.pinned { host.state.expanded = false }
                    return false
                }
                view.dragLocationHandler = { [weak host] screenPoint in
                    guard host != nil,
                          HaloFeatureAccess.shared.allows(.integrations) else { return }
                    _ = IntegrationCIRuntime.shared.updateFileDragLocation(
                        displayID: id,
                        screenPoint: screenPoint
                    )
                }
                view.dropHandler = { [weak self, weak host] urls in
                    guard let self, let host, self.surfaceRuntimeEnabled else { return false }
                    let runtime = IntegrationCIRuntime.shared

                    if HaloFeatureAccess.shared.allows(.integrations),
                       let winner = runtime.currentWinnerCIID(displayID: id),
                       host.state.activeCIIdentifier == winner {
                        guard let commit = runtime.commitFileDragAtHoveredAction(displayID: id) else {
                            return false
                        }

                        if commit.shouldExecuteImmediately {
                            Task { @MainActor [weak host] in
                                guard let host else { return }
                                do {
                                    let shouldCollapse = try await runtime.executeAction(
                                        ciID: commit.ciID,
                                        actionID: commit.actionID,
                                        activationSessionID: commit.activationSessionID,
                                        options: [:],
                                        parentWindow: host.panel,
                                        pinned: host.state.pinned
                                    )
                                    if shouldCollapse && !host.state.pinned {
                                        host.state.expanded = false
                                    }
                                } catch {
                                    // IntegrationCIRuntime publishes the broker/transport error.
                                }
                            }
                        }
                        return true
                    }

                    if host.state.activeCIIdentifier == "builtin.drop", self.dropCISettingEnabled {
                        self.store.addFiles(urls)
                        host.state.completeFileDrop(collapseSurface: true)
                        _ = runtime.fileDragExited(displayID: id, pinned: host.state.pinned)
                        return true
                    }

                    return false
                }
                host.state.appShortcutDragStateDidChange = { [weak self, weak host] active in
                    guard let host else { return }
                    host.state.appShortcutDragActive = active
                    if !active, let target = host.appShortcutDragBaseTarget, let geometry = host.geometry {
                        host.appShortcutDragBaseTarget = nil
                        host.targetFrame = target
                        var motion = geometry.appearance.surface
                        motion.opening = .resize
                        motion.closing = .resize
                        motion.duration = min(0.28, max(0.12, motion.duration))
                        host.animator.move(panel: host.panel, state: host.state, target: target, options: motion,
                                           preset: .smooth,
                                           animations: host.state.theme.animations && !host.state.editingGeometry,
                                           opening: false, style: geometry.style, liveViewportResize: true,
                                           synchronizeClosedGeometry: true,
                                           closedCameraFrame: self?.physicalCameraFrame(for: geometry))
                    }
                }
                view.appShortcutDragStateHandler = { [weak host] active in
                    host?.state.setAppShortcutDragActive(active)
                }
                view.appShortcutDropHandler = { [weak host] urls, point, commit in
                    guard let host, let geometry = host.geometry else { return false }
                    let settingsStore = NotchBubbleSettingsStore.shared
                    var settings = settingsStore.settings.normalized()
                    let closedTarget = host.state.appShortcutDragActive
                        ? self.adjustedClosedFrame(
                            host: host,
                            requestedWidth: max(geometry.frame(expanded: false).width, host.state.contextPreferredCompactWidth ?? 0) + min(48, max(28, geometry.frame(expanded: false).width * 0.16)),
                            requestedHeight: max(geometry.frame(expanded: false).height, host.state.reviewPromptPreferredCompactHeight ?? host.state.contextPreferredCompactHeight ?? 0) + 10
                        )
                        : geometry.frame(expanded: false)
                    guard closedTarget.insetBy(dx: -20, dy: -12).contains(point) else { return false }
                    let shortcuts = urls.compactMap { url -> NotchAppShortcut? in
                        guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else { return nil }
                        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                            ?? url.deletingPathExtension().lastPathComponent
                        return NotchAppShortcut(bundleIdentifier: bundleID, appName: name, applicationPath: url.path)
                    }
                    guard shortcuts.count == urls.count, !shortcuts.isEmpty else { return false }
                    guard commit else { return true }
                    var saved = settings.resolvedAppShortcuts
                    for shortcut in shortcuts where !saved.contains(where: { $0.bundleIdentifier == shortcut.bundleIdentifier }) {
                        saved.append(shortcut)
                    }
                    settings.enabled = true
                    settings.appShortcutsEnabled = true
                    settings.appShortcuts = saved
                    settingsStore.settings = settings.normalized()
                    return true
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

                    if let forced = self.settingsPreviewTarget(for: id), expanded != forced {
                        host.state.collapseTask?.cancel()
                        host.state.collapseTask = nil
                        host.state.hoverExpandTask?.cancel()
                        host.state.hoverExpandTask = nil
                        host.state.expanded = forced
                        return
                    }

                    host.pixelPalCollapseWork?.cancel()
                    host.pixelPalCollapseWork = nil
                    if expanded {
                        host.state.setPixelPalCloseGateActive(false)

                        ActivationSequenceCoordinator.shared.cancelForInteraction()
                        self.armHoverOpeningGuardIfNeeded(for: host)
                        self.applyExpandedState(true, to: host)
                    } else {
                        host.hoverOpeningCompletionWork?.cancel()
                        host.hoverOpeningCompletionWork = nil
                        host.state.cancelHoverOpeningGuard()

                        if !self.schedulePixelPalGatedCollapse(for: host) {
                            self.applyExpandedState(false, to: host)
                        }
                    }
                }
                host.contextSizeSubscription = host.state.$contextPreferredSize.dropFirst().removeDuplicates(by: { lhs, rhs in
                    switch (lhs, rhs) {
                    case (nil, nil): return true
                    case let (a?, b?): return abs(a.width - b.width) < 1 && abs(a.height - b.height) < 1
                    default: return false
                    }
                }).receive(on: DispatchQueue.main).sink { [weak self, weak host] _ in
                    guard let self, let host, let geometry = host.geometry,
                          host.state.expanded,
                          host.state.activeCIIdentifier != nil else { return }
                    let target = self.targetFrame(host: host, expanded: true)
                    guard host.targetFrame != target || abs(host.state.dashboardWidth - target.width) >= 1 else { return }
                    if host.state.dashboardWidth != target.width { host.state.dashboardWidth = target.width }
                    host.targetFrame = target
                    var motion = geometry.appearance.surface
                    motion.opening = .resize
                    motion.closing = .resize
                    motion.duration = min(0.32, max(0.16, motion.duration))
                    host.animator.move(
                        panel: host.panel,
                        state: host.state,
                        target: target,
                        options: motion,
                        preset: .smooth,
                        animations: host.state.theme.animations && !host.state.editingGeometry,
                        opening: true,
                        style: geometry.style
                    )
                }

                host.ciOwnershipSubscription = host.state.$activeCIIdentifier
                    .dropFirst()
                    .removeDuplicates()
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self, weak host] owner in
                        guard let self, let host else { return }
                        guard owner == nil else { return }

                        // Tear down all CI sizing as soon as ownership ends. This also
                        // invalidates late measurements that arrive after dismissal.
                        host.state.contextPreferredSize = nil
                        host.state.contextPreferredCompactWidth = nil
                        host.state.contextPreferredCompactHeight = nil
                        host.state.contextMinimumExpandedWidth = nil

                        guard host.state.expanded, let geometry = host.geometry else { return }
                        let target = self.targetFrame(host: host, expanded: true)
                        let baseWidth = geometry.frame(expanded: true).width
                        if host.state.dashboardWidth != baseWidth {
                            host.state.dashboardWidth = baseWidth
                        }
                        guard host.targetFrame != target else { return }

                        host.targetFrame = target
                        var motion = geometry.appearance.surface
                        motion.opening = .resize
                        motion.closing = .resize
                        motion.duration = min(0.30, max(0.14, motion.duration))
                        host.animator.move(
                            panel: host.panel,
                            state: host.state,
                            target: target,
                            options: motion,
                            preset: .smooth,
                            animations: host.state.theme.animations && !host.state.editingGeometry,
                            opening: true,
                            style: geometry.style
                        )
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
                    guard let self, let host, let geometry = host.geometry,
                          !host.state.expanded, !host.state.presentationExpanded else { return }
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
                    guard let self, let host, let geometry = host.geometry,
                          !host.state.expanded, !host.state.presentationExpanded else { return }
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

                host.appShortcutDragSubscription = host.state.$appShortcutDragActive
                    .removeDuplicates()
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self, weak host] active in
                        guard let self, let host, let geometry = host.geometry,
                              !host.state.expanded, !host.state.presentationExpanded else { return }
                        let base = geometry.frame(expanded: false)
                        if active { host.appShortcutDragBaseTarget = self.targetFrame(host: host, expanded: false) }
                        let widthBoost: CGFloat = min(48, max(28, base.width * 0.16))
                        let heightBoost: CGFloat = 10
                        let existingWidth = max(base.width, host.state.contextPreferredCompactWidth ?? 0)
                        let existingHeight = max(
                            base.height,
                            host.state.reviewPromptPreferredCompactHeight ?? host.state.contextPreferredCompactHeight ?? 0
                        )
                        let requestedWidth = active ? existingWidth + widthBoost : host.state.contextPreferredCompactWidth
                        let requestedHeight = active ? existingHeight + heightBoost : (host.state.reviewPromptPreferredCompactHeight ?? host.state.contextPreferredCompactHeight)
                        let target = active
                            ? self.adjustedClosedFrame(host: host, requestedWidth: requestedWidth, requestedHeight: requestedHeight)
                            : (host.appShortcutDragBaseTarget ?? self.targetFrame(host: host, expanded: false))
                        guard host.targetFrame != target else { return }
                        host.targetFrame = target
                        var motion = geometry.appearance.surface
                        motion.opening = .resize
                        motion.closing = .resize
                        motion.duration = min(0.28, max(0.12, motion.duration))
                        host.animator.move(
                            panel: host.panel,
                            state: host.state,
                            target: target,
                            options: motion,
                            preset: .smooth,
                            animations: host.state.theme.animations && !host.state.editingGeometry,
                            opening: active,
                            style: geometry.style,
                            liveViewportResize: true,
                            synchronizeClosedGeometry: true,
                            closedCameraFrame: self.physicalCameraFrame(for: geometry)
                        )
                    }

                host.reviewPromptCompactHeightSubscription = host.state.$reviewPromptPreferredCompactHeight.dropFirst().removeDuplicates(by: { lhs, rhs in
                    switch (lhs, rhs) {
                    case (nil, nil): return true
                    case let (a?, b?): return abs(a - b) < 1
                    default: return false
                    }
                }).receive(on: DispatchQueue.main).sink { [weak self, weak host] _ in
                    guard let self, let host, let geometry = host.geometry,
                          !host.state.expanded, !host.state.presentationExpanded else { return }
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
                                       opening: true,
                                       style: geometry.style,
                                       liveViewportResize: true,
                                       synchronizeClosedGeometry: true,
                                       closedCameraFrame: self.physicalCameraFrame(for: geometry))
                }
                host.panel.orderFrontRegardless()
                host.ambientPanel.order(.below, relativeTo: host.panel.windowNumber)
                hosts[id] = host
                if let forced = settingsPreviewTarget(for: id) {
                    if settingsSurfacePreviewPreviousExpanded[id] == nil {
                        settingsSurfacePreviewPreviousExpanded[id] = host.state.expanded
                    }
                    host.state.collapseTask?.cancel()
                    host.state.collapseTask = nil
                    host.state.hoverExpandTask?.cancel()
                    host.state.hoverExpandTask = nil
                    if host.state.expanded != forced {
                        host.state.expanded = forced
                    }
                }
                if SurfaceGeometryEditingSession.shared.isEnabled {
                    refreshGeometryEditorPanels()
                }
            }
            if !simpleMode && access.allows(.notchAmbient) {
                host.ambientPanel.order(.below, relativeTo: host.panel.windowNumber)
            } else if host.ambientPanel.isVisible {
                host.ambientPanel.orderOut(nil)
            }

            if simpleMode {
                bubbleManager.unregister(displayID: id)
            } else {
                bubbleManager.register(
                    displayID: id,
                    screen: screen,
                    surfacePanel: host.panel,
                    state: host.state
                )
            }
        }
        for id in Array(hosts.keys) where !active.contains(id) {
            bubbleManager.unregister(displayID: id)
            hosts.removeValue(forKey: id)?.stop()
        }

        // Reassert the prompt after any geometry/profile/display reconciliation so the
        // temporary review height remains stable while the reminder is visible.
        synchronizeReviewPromptPresentation()
        refreshGeometryEditorPanels()
    }
}
