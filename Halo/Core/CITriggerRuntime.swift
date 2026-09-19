import Foundation

struct TriggerPayloadHandle: Codable, Hashable, Sendable, CustomStringConvertible {
    fileprivate let rawValue: UUID
    init() { rawValue = UUID() }
    var description: String { rawValue.uuidString }
}

struct CIFileDragMetadata: Codable, Hashable, Sendable {
    var itemCount: Int
    var fileExtensions: Set<String>
    var containsDirectory: Bool
}

struct TriggerEvent: Identifiable, Hashable, Sendable {
    var id: UUID
    var kind: CITriggerKind
    var displayID: String
    var targetedCIID: String?
    var targetedTriggerID: String?
    var payloadHandle: TriggerPayloadHandle?
    var fileDrag: CIFileDragMetadata?
    var partnerEventName: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        kind: CITriggerKind,
        displayID: String,
        targetedCIID: String? = nil,
        targetedTriggerID: String? = nil,
        payloadHandle: TriggerPayloadHandle? = nil,
        fileDrag: CIFileDragMetadata? = nil,
        partnerEventName: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.displayID = displayID
        self.targetedCIID = targetedCIID
        self.targetedTriggerID = targetedTriggerID
        self.payloadHandle = payloadHandle
        self.fileDrag = fileDrag
        self.partnerEventName = partnerEventName
        self.createdAt = createdAt
    }
}

struct CIEligibleCandidate: Hashable, Sendable {
    var registration: CIRegistration
    var event: TriggerEvent
    var triggerID: String
    var actionIDs: Set<String>
    var priority: Double
}

/// Privileged storage for sensitive trigger payloads. The public trigger event contains only
/// an opaque handle. Actual file URLs are released only to the action broker for the currently
/// bound activation session.
final class TriggerPayloadStore {
    private struct Record {
        var eventID: UUID
        var displayID: String
        var files: [URL]
        var committed: Bool
        var boundSessionID: UUID?
        var boundCIID: String?
    }

    private var records: [TriggerPayloadHandle: Record] = [:]
    private let lock = NSLock()

    func storeFileDrag(eventID: UUID, displayID: String, files: [URL]) -> TriggerPayloadHandle? {
        let safe = files.filter(\.isFileURL)
        guard !safe.isEmpty else { return nil }
        let handle = TriggerPayloadHandle()
        lock.lock()
        records[handle] = Record(
            eventID: eventID,
            displayID: displayID,
            files: safe,
            committed: false,
            boundSessionID: nil,
            boundCIID: nil
        )
        lock.unlock()
        return handle
    }

    func bind(_ handle: TriggerPayloadHandle, to sessionID: UUID, ciID: String, eventID: UUID) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard var record = records[handle], record.eventID == eventID else { return false }
        if let boundSessionID = record.boundSessionID, boundSessionID != sessionID { return false }
        if let boundCIID = record.boundCIID, boundCIID != ciID { return false }
        record.boundSessionID = sessionID
        record.boundCIID = ciID
        records[handle] = record
        return true
    }

    func releaseBinding(_ handle: TriggerPayloadHandle, sessionID: UUID) {
        lock.lock(); defer { lock.unlock() }
        guard var record = records[handle], record.boundSessionID == sessionID, !record.committed else { return }
        record.boundSessionID = nil
        record.boundCIID = nil
        records[handle] = record
    }

    func commit(_ handle: TriggerPayloadHandle, sessionID: UUID, ciID: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard var record = records[handle],
              record.boundSessionID == sessionID,
              record.boundCIID == ciID else { return false }
        record.committed = true
        records[handle] = record
        return true
    }

    func resolve(
        _ handle: TriggerPayloadHandle,
        activationSessionID: UUID,
        ciID: String,
        requireCommitted: Bool
    ) -> [URL]? {
        lock.lock(); defer { lock.unlock() }
        guard let record = records[handle],
              record.boundSessionID == activationSessionID,
              record.boundCIID == ciID,
              !requireCommitted || record.committed else { return nil }
        return record.files
    }

    func isCommitted(_ handle: TriggerPayloadHandle, activationSessionID: UUID, ciID: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let record = records[handle] else { return false }
        return record.boundSessionID == activationSessionID && record.boundCIID == ciID && record.committed
    }

    func remove(_ handle: TriggerPayloadHandle) {
        lock.lock(); records.removeValue(forKey: handle); lock.unlock()
    }

    func removeUncommitted(displayID: String) {
        lock.lock()
        records = records.filter { _, record in record.displayID != displayID || record.committed }
        lock.unlock()
    }

    func clear() {
        lock.lock(); records.removeAll(); lock.unlock()
    }

    #if DEBUG
    var debugRecordCount: Int { lock.lock(); defer { lock.unlock() }; return records.count }
    #endif
}

enum CIEligibilityEngine {
    static func evaluate(
        registration: CIRegistration,
        event: TriggerEvent,
        configuration: CIConfiguration
    ) -> CIEligibleCandidate? {
        guard configuration.enabled else { return nil }
        if let targetedCIID = event.targetedCIID, targetedCIID != registration.id { return nil }

        let actionsByID = Dictionary(uniqueKeysWithValues: registration.supportedActions.map { ($0.id, $0) })
        var matchingActions = Set<String>()
        var matchedTriggerID: String?

        for trigger in registration.supportedTriggers {
            guard trigger.type == event.kind,
                  configuration.triggerEnabled(trigger.id),
                  trigger.requiredPermissions.isSubset(of: configuration.grantedPermissions) else { continue }
            if let targetedTriggerID = event.targetedTriggerID, targetedTriggerID != trigger.id { continue }
            if trigger.type == .partnerEvent, trigger.eventName != event.partnerEventName { continue }

            let referenced = trigger.actionIDs.isEmpty ? registration.supportedActions.map(\.id) : trigger.actionIDs
            let compatible = referenced.compactMap { actionID -> String? in
                guard let action = actionsByID[actionID],
                      configuration.actionEnabled(actionID),
                      inputCompatible(action.input, event: event) else { return nil }
                if event.kind == .fileDrag,
                   !action.requiredPermissions.isSubset(of: configuration.grantedPermissions) { return nil }
                return actionID
            }
            guard !compatible.isEmpty || trigger.type == .manual else { continue }
            if matchedTriggerID == nil { matchedTriggerID = trigger.id }
            matchingActions.formUnion(compatible)
        }

        guard let triggerID = matchedTriggerID else { return nil }
        return CIEligibleCandidate(
            registration: registration,
            event: event,
            triggerID: triggerID,
            actionIDs: matchingActions,
            priority: min(100, max(0, configuration.priority))
        )
    }

    static func inputCompatible(_ input: CIActionInputDefinition, event: TriggerEvent) -> Bool {
        switch input.type {
        case .none:
            return event.kind != .fileDrag
        case .files:
            guard event.kind == .fileDrag else { return true }
            guard let metadata = event.fileDrag, !metadata.containsDirectory else { return false }
            guard input.multiple || metadata.itemCount == 1 else { return false }
            let supported = Set(input.extensions.map(normalizeExtension))
            if supported.isEmpty { return false }
            if supported.contains("*") { return true }
            return !metadata.fileExtensions.isEmpty && metadata.fileExtensions.isSubset(of: supported)
        }
    }

    static func filesCompatible(_ files: [URL], with input: CIActionInputDefinition) -> Bool {
        guard input.type == .files, !files.isEmpty,
              files.allSatisfy({ $0.isFileURL && !$0.hasDirectoryPath }),
              input.multiple || files.count == 1 else { return false }
        let supported = Set(input.extensions.map(normalizeExtension))
        guard !supported.isEmpty else { return false }
        if supported.contains("*") { return true }
        return files.allSatisfy { url in
            let ext = normalizeExtension(url.pathExtension)
            return !ext.isEmpty && supported.contains(ext)
        }
    }

    private static func normalizeExtension(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
}

/// Generic event-to-eligibility router. It does not resize Halo, pick a winner, render a view,
/// resolve sensitive payloads or execute actions.
final class TriggerRouter {
    func route(
        _ event: TriggerEvent,
        registrations: [CIRegistration],
        configuration: (CIRegistration) -> CIConfiguration
    ) -> [CIEligibleCandidate] {
        registrations.compactMap { registration in
            CIEligibilityEngine.evaluate(
                registration: registration,
                event: event,
                configuration: configuration(registration)
            )
        }
        .sorted {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            return $0.registration.id < $1.registration.id
        }
    }
}

enum FileDragClassifier {
    static func classify(_ files: [URL]) -> CIFileDragMetadata? {
        let urls = files.filter(\.isFileURL)
        guard !urls.isEmpty else { return nil }
        var extensions = Set<String>()
        var containsDirectory = false
        for url in urls {
            if url.hasDirectoryPath { containsDirectory = true; continue }
            let ext = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !ext.isEmpty { extensions.insert(ext) }
        }
        return CIFileDragMetadata(itemCount: urls.count, fileExtensions: extensions, containsDirectory: containsDirectory)
    }
}
