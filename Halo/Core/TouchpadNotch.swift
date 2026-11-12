import Foundation

struct TouchpadNotchSettings: Codable, Equatable {
    enum Destination: String, Codable, CaseIterable { case notch, touchpadCI }
    var enabled = false
    var x = 0.5
    var y = 0.9
    var radius = 0.08
    var deviceID: UInt64?
    var hasSpot = false
    var openHold = 0.5
    var closeHold = 0.5
    var minimumPressure = 0.0
    var haptics = true
    var destination: Destination = .notch

    func normalized() -> Self {
        var result = self
        func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
            value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
        }
        result.x = clamp(x, 0...1, 0.5)
        result.y = clamp(y, 0...1, 0.9)
        result.radius = clamp(radius, 0.02...0.25, 0.08)
        result.openHold = clamp(openHold, 0.1...5, 0.5)
        result.closeHold = clamp(closeHold, 0.1...5, 0.5)
        result.minimumPressure = clamp(minimumPressure, 0...1, 0)
        return result
    }
}

/// Input-only recognition. The consumer owns surface policy and CI arbitration.
struct TouchpadNotchRecognizer {
    struct Contact: Equatable, Sendable {
        let id: Int32
        let x: Double
        let y: Double
    }
    private var contactID: Int32?
    private var beganAt: Double?
    private var lastTimestamp: Double?
    private var fired = false
    private var blockedUntilRelease = false
    private var targetWasOpen: Bool?

    mutating func reset() { self = Self() }

    mutating func update(contacts: [Contact], pressure: Double?, timestamp: Double,
                         isOpen: Bool, settings: TouchpadNotchSettings) -> Bool {
        guard settings.enabled, settings.hasSpot, timestamp.isFinite else { reset(); return false }
        // A continuous contact cannot toggle twice. Multi-finger gestures must end completely.
        guard !contacts.isEmpty else { reset(); return false }
        guard contacts.count == 1 else { blockedUntilRelease = true; beganAt = nil; return false }
        guard !blockedUntilRelease, !fired else { return false }
        let contact = contacts[0]
        let config = settings.normalized()
        guard (0...1).contains(contact.x), (0...1).contains(contact.y),
              hypot(contact.x - config.x, contact.y - config.y) <= config.radius,
              config.minimumPressure == 0 || (pressure.map { $0.isFinite && $0 >= config.minimumPressure } ?? false)
        else { beganAt = nil; contactID = nil; return false }
        if let lastTimestamp, timestamp < lastTimestamp || timestamp - lastTimestamp > 0.25 {
            beganAt = nil; contactID = nil
        }
        lastTimestamp = timestamp
        if contactID != contact.id || targetWasOpen != isOpen || beganAt == nil {
            contactID = contact.id
            targetWasOpen = isOpen
            beganAt = timestamp
        }
        guard timestamp - (beganAt ?? timestamp) >= (isOpen ? config.closeHold : config.openHold) else { return false }
        fired = true
        return true
    }
}
