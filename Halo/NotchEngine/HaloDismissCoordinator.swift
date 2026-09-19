import AppKit
import Foundation

enum HaloDismissHoldReason: String, Hashable, Sendable {
    case mouseDown
    case dragging
    case scrolling
    case textEditing
    case popover
    case menu
    case ciInteraction
    case keyboardInteraction
    case externalHaloSurface
}

enum HaloDismissDestination: String, Hashable, Sendable {
    case compact
    case closed
}

/// Per-surface authority for automatic Halo dismissal.
///
/// Views report interaction intent; this coordinator owns the single pending dismissal task,
/// hold-open tokens, pointer return cancellation and final revalidation before collapse.
@MainActor
final class HaloDismissCoordinator {
    typealias DismissHandler = (HaloDismissReason, HaloDismissDestination) -> Void

    var behaviorProvider: () -> HaloCloseBehavior = { .smart }
    var customDelayProvider: () -> Double = { HaloDismissTimingPolicy.smartBaselineMilliseconds }
    var canDismiss: () -> Bool = { true }
    var pointerInsideInteractionEnvironment: () -> Bool = { false }
    var pointerInsideForgivenessRegion: () -> Bool = { false }
    var onDismiss: DismissHandler?

    private(set) var ciBehavior: CIDismissBehavior = .standard
    private(set) var pointerInsideMainSurface = false
    private(set) var pendingReason: HaloDismissReason?

    private var pendingTask: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var holds: [UUID: HaloDismissHoldReason] = [:]
    private var transientHoldTasks: [HaloDismissHoldReason: Task<Void, Never>] = [:]
    private var transientHoldTokens: [HaloDismissHoldReason: UUID] = [:]

    func setCIBehavior(_ behavior: CIDismissBehavior) {
        guard ciBehavior != behavior else { return }
        ciBehavior = behavior
        if !pointerInsideMainSurface, holds.isEmpty {
            requestDismissal(reason: .pointerExit)
        }
    }

    func pointerEntered() {
        pointerInsideMainSurface = true
        cancelPendingDismissal()
        debugLog("Dismiss cancelled: pointer returned")
    }

    func pointerExited() {
        pointerInsideMainSurface = false
        requestDismissal(reason: .pointerExit)
    }

    func requestDismissal(
        reason: HaloDismissReason,
        destination: HaloDismissDestination = .compact
    ) {
        let explicit = reason == .escapeKey || reason == .explicit || reason == .ciCompleted

        if !explicit {
            guard canDismiss() else {
                cancelPendingDismissal()
                debugLog("Dismiss blocked: surface state")
                return
            }
            guard holds.isEmpty else {
                cancelPendingDismissal()
                debugLog("Dismiss blocked: holds=\(holds.values.map(\.rawValue).sorted())")
                return
            }
            if reason == .pointerExit {
                guard !pointerInsideMainSurface else {
                    cancelPendingDismissal()
                    return
                }
                guard !pointerInsideInteractionEnvironment() else {
                    cancelPendingDismissal()
                    debugLog("Dismiss blocked: pointer inside Halo environment")
                    return
                }
            }
        } else {
            guard canDismiss() else { return }
        }

        guard var delay = HaloDismissTimingPolicy.delay(
            behavior: behaviorProvider(),
            customMilliseconds: customDelayProvider(),
            ciBehavior: ciBehavior,
            reason: reason
        ) else {
            cancelPendingDismissal()
            debugLog("Dismiss ignored: \(reason.rawValue)")
            return
        }

        if reason == .pointerExit, pointerInsideForgivenessRegion() {
            // The cursor only just crossed Halo's visible edge. Give it a little extra time
            // to return without creating a polling loop or a second close authority.
            delay += 0.16
        }

        cancelPendingDismissal()
        pendingReason = reason
        generation &+= 1
        let requestGeneration = generation

        guard delay > 0.001 else {
            commitIfStillEligible(
                generation: requestGeneration,
                reason: reason,
                destination: destination,
                explicit: explicit
            )
            return
        }

        debugLog("Dismiss delayed: \(Int((delay * 1_000).rounded())) ms (\(reason.rawValue), \(ciBehavior.rawValue))")
        pendingTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.commitIfStillEligible(
                generation: requestGeneration,
                reason: reason,
                destination: destination,
                explicit: explicit
            )
        }
    }

    func cancelPendingDismissal() {
        generation &+= 1
        pendingTask?.cancel()
        pendingTask = nil
        pendingReason = nil
    }

    @discardableResult
    func acquireHold(_ reason: HaloDismissHoldReason) -> UUID {
        let token = UUID()
        holds[token] = reason
        cancelPendingDismissal()
        debugLog("Dismiss hold acquired: \(reason.rawValue)")
        return token
    }

    func releaseHold(_ token: UUID) {
        guard let reason = holds.removeValue(forKey: token) else { return }
        debugLog("Dismiss hold released: \(reason.rawValue)")
        resumePointerDismissalIfNeeded()
    }

    func releaseAllHolds() {
        guard !holds.isEmpty || !transientHoldTasks.isEmpty else { return }
        transientHoldTasks.values.forEach { $0.cancel() }
        transientHoldTasks.removeAll()
        transientHoldTokens.removeAll()
        holds.removeAll()
        resumePointerDismissalIfNeeded()
    }

    /// Renews a short-lived hold without creating racing release callbacks.
    /// Used for event streams such as scrolling and keyboard navigation.
    func pulseHold(_ reason: HaloDismissHoldReason, duration: TimeInterval) {
        transientHoldTasks[reason]?.cancel()
        if let old = transientHoldTokens[reason] {
            holds.removeValue(forKey: old)
        }

        let token = acquireHold(reason)
        transientHoldTokens[reason] = token
        let boundedDuration = min(2, max(0.05, duration))
        transientHoldTasks[reason] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(boundedDuration * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.transientHoldTasks.removeValue(forKey: reason)
            self.transientHoldTokens.removeValue(forKey: reason)
            self.releaseHold(token)
        }
    }

    func reset() {
        cancelPendingDismissal()
        transientHoldTasks.values.forEach { $0.cancel() }
        transientHoldTasks.removeAll()
        transientHoldTokens.removeAll()
        holds.removeAll()
        pointerInsideMainSurface = false
        ciBehavior = .standard
    }

    var hasActiveHolds: Bool {
        !holds.isEmpty
    }

    private func resumePointerDismissalIfNeeded() {
        guard holds.isEmpty,
              !pointerInsideMainSurface,
              !pointerInsideInteractionEnvironment() else {
            return
        }
        requestDismissal(reason: .pointerExit)
    }

    private func commitIfStillEligible(
        generation requestGeneration: UInt64,
        reason: HaloDismissReason,
        destination: HaloDismissDestination,
        explicit: Bool
    ) {
        guard requestGeneration == generation else { return }

        if !explicit {
            guard canDismiss(), holds.isEmpty else {
                pendingTask = nil
                pendingReason = nil
                return
            }
            if reason == .pointerExit {
                guard !pointerInsideMainSurface,
                      !pointerInsideInteractionEnvironment() else {
                    pendingTask = nil
                    pendingReason = nil
                    return
                }
            }
        } else {
            guard canDismiss() else {
                pendingTask = nil
                pendingReason = nil
                return
            }
        }

        pendingTask = nil
        pendingReason = nil
        debugLog("Dismiss committed: \(reason.rawValue)")
        onDismiss?(reason, destination)
    }

    private func debugLog(_ message: @autoclosure () -> String) {
#if DEBUG
        print("[HaloDismiss] \(message())")
#endif
    }
}
