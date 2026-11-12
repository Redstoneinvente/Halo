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

/// Hardware classification must not depend on MultitouchSupport's OpaqueSurface flag.
enum TouchpadDeviceClassifier {
    static func isTrackpad(product: String) -> Bool {
        let name = product.lowercased()
        return name.contains("trackpad") || name.contains("touchpad")
    }
}

/// Records only fresh, continuous single-finger input, independently of activation settings.
struct TouchpadSpotRecorder {
    struct Spot: Equatable {
        let device: UInt64
        let x: Double
        let y: Double
    }
    private var waitingForRelease: Set<UInt64>
    private var candidate: (device: UInt64, contact: Int32, x: Double, y: Double, began: Double, last: Double)?

    init(touchingDevices: Set<UInt64> = []) {
        waitingForRelease = touchingDevices
    }

    mutating func update(device: UInt64, contacts: [TouchpadNotchRecognizer.Contact], time: Double) -> Spot? {
        guard time.isFinite else { candidate = nil; return nil }
        if !waitingForRelease.isEmpty {
            if contacts.isEmpty { waitingForRelease.remove(device) }
            return nil
        }
        // Empty frames from another connected trackpad cannot cancel this hold.
        if let candidate, candidate.device != device, contacts.isEmpty { return nil }
        guard contacts.count == 1, let contact = contacts.first,
              (0...1).contains(contact.x), (0...1).contains(contact.y) else {
            candidate = nil
            return nil
        }
        if let previous = candidate, previous.device == device, previous.contact == contact.id,
           time >= previous.last, time - previous.last <= 0.25,
           hypot(contact.x - previous.x, contact.y - previous.y) < 0.025 {
            candidate?.last = time
            if time - previous.began >= 1 {
                candidate = nil
                return Spot(device: device, x: contact.x, y: contact.y)
            }
        } else {
            candidate = (device, contact.id, contact.x, contact.y, time, time)
        }
        return nil
    }
}
