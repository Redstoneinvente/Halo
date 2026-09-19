import Foundation

struct CIShortcutChord: Codable, Hashable, Sendable {
    var keyCode: UInt32
    var modifiers: UInt32
}

struct CIShortcutRequest: Hashable, Sendable {
    var ciID: String
    var triggerID: String
    var chord: CIShortcutChord

    var id: String { ciID + "::" + triggerID }
}

struct CIShortcutPlan: Sendable {
    var accepted: [CIShortcutRequest]
    var conflicts: [String: String]
}

enum CIShortcutPlanner {
    static func plan(requests: [CIShortcutRequest], reserved: Set<CIShortcutChord> = []) -> CIShortcutPlan {
        var accepted: [CIShortcutRequest] = []
        var conflicts: [String: String] = [:]
        var owners: [CIShortcutChord: CIShortcutRequest] = [:]
        for request in requests.sorted(by: { $0.id < $1.id }) {
            if reserved.contains(request.chord) {
                conflicts[request.id] = "Shortcut is already reserved by Halo."
                continue
            }
            if let existing = owners[request.chord] {
                conflicts[request.id] = "Shortcut conflicts with \(existing.ciID)."
                continue
            }
            owners[request.chord] = request
            accepted.append(request)
        }
        return CIShortcutPlan(accepted: accepted, conflicts: conflicts)
    }
}
