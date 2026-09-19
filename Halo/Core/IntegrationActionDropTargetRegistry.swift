import AppKit
import Combine
import Foundation

/// Main-actor registry of Halo-owned integration action hit regions.
/// It contains geometry and stable IDs only. Sensitive drag payloads remain in TriggerPayloadStore.
@MainActor
final class IntegrationActionDropTargetRegistry: ObservableObject {
    static let shared = IntegrationActionDropTargetRegistry()

    struct Target {
        var displayID: String
        var ciID: String
        var sessionID: UUID
        var actionID: String
        var screenFrame: CGRect
    }

    @Published private(set) var hoveredActionByDisplay: [String: String] = [:]

    private var targetsBySession: [UUID: [String: Target]] = [:]

    func register(
        displayID: String,
        ciID: String,
        sessionID: UUID,
        actionID: String,
        screenFrame: CGRect
    ) {
        guard screenFrame.width > 1, screenFrame.height > 1 else { return }
        var sessionTargets = targetsBySession[sessionID] ?? [:]
        sessionTargets[actionID] = Target(
            displayID: displayID,
            ciID: ciID,
            sessionID: sessionID,
            actionID: actionID,
            screenFrame: screenFrame
        )
        targetsBySession[sessionID] = sessionTargets
    }

    func unregister(sessionID: UUID, actionID: String) {
        guard var sessionTargets = targetsBySession[sessionID] else { return }
        sessionTargets.removeValue(forKey: actionID)
        if sessionTargets.isEmpty {
            targetsBySession.removeValue(forKey: sessionID)
        } else {
            targetsBySession[sessionID] = sessionTargets
        }
    }

    func clear(sessionID: UUID) {
        let removed = targetsBySession.removeValue(forKey: sessionID) ?? [:]
        guard !removed.isEmpty else { return }
        let affectedDisplays = Set(removed.values.map(\.displayID))
        for displayID in affectedDisplays {
            hoveredActionByDisplay.removeValue(forKey: displayID)
        }
    }

    func clear(displayID: String) {
        for (sessionID, targets) in targetsBySession {
            let remaining = targets.filter { $0.value.displayID != displayID }
            if remaining.isEmpty {
                targetsBySession.removeValue(forKey: sessionID)
            } else {
                targetsBySession[sessionID] = remaining
            }
        }
        hoveredActionByDisplay.removeValue(forKey: displayID)
    }

    func clearAll() {
        targetsBySession.removeAll()
        hoveredActionByDisplay.removeAll()
    }

    func actionID(
        at screenPoint: CGPoint,
        displayID: String,
        ciID: String,
        sessionID: UUID
    ) -> String? {
        guard let targets = targetsBySession[sessionID]?.values else { return nil }
        return targets
            .filter {
                $0.displayID == displayID &&
                $0.ciID == ciID &&
                $0.screenFrame.contains(screenPoint)
            }
            .sorted {
                let lhsArea = $0.screenFrame.width * $0.screenFrame.height
                let rhsArea = $1.screenFrame.width * $1.screenFrame.height
                if lhsArea != rhsArea { return lhsArea < rhsArea }
                return $0.actionID < $1.actionID
            }
            .first?
            .actionID
    }

    @discardableResult
    func updateHover(
        screenPoint: CGPoint?,
        displayID: String,
        ciID: String,
        sessionID: UUID
    ) -> String? {
        guard let screenPoint else {
            hoveredActionByDisplay.removeValue(forKey: displayID)
            return nil
        }
        let actionID = actionID(
            at: screenPoint,
            displayID: displayID,
            ciID: ciID,
            sessionID: sessionID
        )
        if let actionID {
            hoveredActionByDisplay[displayID] = actionID
        } else {
            hoveredActionByDisplay.removeValue(forKey: displayID)
        }
        return actionID
    }

    func hoveredActionID(displayID: String) -> String? {
        hoveredActionByDisplay[displayID]
    }
}
