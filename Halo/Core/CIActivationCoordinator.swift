import Foundation

struct CIActivationSession: Identifiable, Hashable, Sendable {
    var id: UUID
    var ciID: String
    var displayID: String
    var triggerEventID: UUID
    var triggerID: String
    var eligibleActionIDs: Set<String>
    var payloadHandle: TriggerPayloadHandle?
    var activatedAt: Date
    var committed: Bool
    /// For drag activations, the action card that accepted the committed payload.
    /// Once set, the payload cannot be retargeted to a different partner action.
    var committedActionID: String?
    var dismissed: Bool
    var openedSurfaceAutomatically: Bool
    var userOverrodeSurface: Bool
}

struct CIActivationDecision: Hashable, Sendable {
    var session: CIActivationSession
    var shouldOpenSurface: Bool
}

/// Owns activation lifetime only. It never discovers integrations, evaluates trigger compatibility,
/// arbitrates CI priority, renders UI, touches NSPanel, or delivers partner actions.
final class CIActivationCoordinator {
    private var sessionsByDisplay: [String: CIActivationSession] = [:]
    private let lock = NSLock()

    func activate(
        candidate: CIEligibleCandidate,
        surfaceWasExpanded: Bool,
        pinned: Bool,
        autoOpen: Bool,
        now: Date = Date()
    ) -> CIActivationDecision {
        lock.lock(); defer { lock.unlock() }
        if let current = sessionsByDisplay[candidate.event.displayID],
           current.ciID == candidate.registration.id,
           current.triggerEventID == candidate.event.id,
           !current.dismissed {
            return CIActivationDecision(session: current, shouldOpenSurface: false)
        }

        let shouldOpen = autoOpen && !surfaceWasExpanded && !pinned
        let session = CIActivationSession(
            id: UUID(),
            ciID: candidate.registration.id,
            displayID: candidate.event.displayID,
            triggerEventID: candidate.event.id,
            triggerID: candidate.triggerID,
            eligibleActionIDs: candidate.actionIDs,
            payloadHandle: candidate.event.payloadHandle,
            activatedAt: now,
            committed: false,
            committedActionID: nil,
            dismissed: false,
            openedSurfaceAutomatically: shouldOpen,
            userOverrodeSurface: false
        )
        sessionsByDisplay[candidate.event.displayID] = session
        return CIActivationDecision(session: session, shouldOpenSurface: shouldOpen)
    }

    func currentSession(displayID: String) -> CIActivationSession? {
        lock.lock(); defer { lock.unlock() }
        return sessionsByDisplay[displayID]
    }

    func session(id: UUID) -> CIActivationSession? {
        lock.lock(); defer { lock.unlock() }
        return sessionsByDisplay.values.first(where: { $0.id == id && !$0.dismissed })
    }

    func isCurrent(sessionID: UUID, ciID: String, displayID: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let value = sessionsByDisplay[displayID] else { return false }
        return value.id == sessionID && value.ciID == ciID && !value.dismissed
    }

    @discardableResult
    func markCommitted(sessionID: UUID, actionID: String) -> CIActivationSession? {
        lock.lock(); defer { lock.unlock() }
        guard let entry = sessionsByDisplay.first(where: { $0.value.id == sessionID }),
              entry.value.eligibleActionIDs.contains(actionID) else { return nil }
        var session = entry.value
        if let committedActionID = session.committedActionID,
           committedActionID != actionID {
            return nil
        }
        session.committed = true
        session.committedActionID = actionID
        sessionsByDisplay[entry.key] = session
        return session
    }

    func noteUserSurfaceOverride(displayID: String) {
        lock.lock(); defer { lock.unlock() }
        guard var session = sessionsByDisplay[displayID], session.openedSurfaceAutomatically else { return }
        session.userOverrodeSurface = true
        sessionsByDisplay[displayID] = session
    }

    func cancelUncommitted(displayID: String, pinned: Bool) -> (session: CIActivationSession?, shouldCollapse: Bool) {
        lock.lock(); defer { lock.unlock() }
        guard var session = sessionsByDisplay[displayID], !session.committed else { return (nil, false) }
        session.dismissed = true
        sessionsByDisplay.removeValue(forKey: displayID)
        let shouldCollapse = session.openedSurfaceAutomatically && !session.userOverrodeSurface && !pinned
        return (session, shouldCollapse)
    }

    func finish(sessionID: UUID, pinned: Bool) -> (session: CIActivationSession?, shouldCollapse: Bool) {
        lock.lock(); defer { lock.unlock() }
        guard let entry = sessionsByDisplay.first(where: { $0.value.id == sessionID }) else { return (nil, false) }
        var session = entry.value
        session.dismissed = true
        sessionsByDisplay.removeValue(forKey: entry.key)
        let shouldCollapse = session.openedSurfaceAutomatically && !session.userOverrodeSurface && !pinned
        return (session, shouldCollapse)
    }

    func relinquish(displayID: String) -> CIActivationSession? {
        lock.lock(); defer { lock.unlock() }
        guard var session = sessionsByDisplay.removeValue(forKey: displayID) else { return nil }
        session.dismissed = true
        return session
    }

    func cleanupForSleepOrWake() -> [CIActivationSession] {
        lock.lock(); defer { lock.unlock() }
        let sessions = sessionsByDisplay.values.map { value -> CIActivationSession in
            var copy = value
            copy.dismissed = true
            return copy
        }
        sessionsByDisplay.removeAll()
        return sessions
    }
}
