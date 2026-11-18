import Foundation

struct TouchpadNotchSettings: Codable, Equatable {
    enum Destination: String, Codable, CaseIterable {
        case notch, touchpadCI, playPause, nextTrack, previousTrack, mute, volumeDown, volumeUp

        var title: String {
            switch self {
            case .notch: return "Halo notch"
            case .touchpadCI: return "Touchpad CI"
            case .playPause: return "Play / pause"
            case .nextTrack: return "Next track"
            case .previousTrack: return "Previous track"
            case .mute: return "Mute / unmute output"
            case .volumeDown: return "Volume down"
            case .volumeUp: return "Volume up"
            }
        }

        var togglesSurface: Bool { self == .notch || self == .touchpadCI }

        var mediaCommand: String? {
            switch self {
            case .playPause: return "playpause"
            case .nextTrack: return "next track"
            case .previousTrack: return "previous track"
            default: return nil
            }
        }
    }
    var enabled = false
    var x = 0.5
    var y = 0.9
    var radius = 0.08
    var deviceID: UInt64?
    var hasSpot = false
    var openHold = 0.5
    var closeHold = 0.5
    var minimumPressure = 0.0
    var pressureReference: Double?
    var haptics = true
    var destination: Destination = .notch
    // Optional so existing saved spots decode without migration.
    var quickGestures: Bool?
    var usesQuickGestures: Bool { quickGestures ?? true }

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
        result.pressureReference = pressureReference.flatMap { $0.isFinite && $0 >= 1 && $0 <= 65535 ? $0 : nil }
        return result
    }
}

/// Input-only recognition. The consumer owns surface policy and CI arbitration.
struct TouchpadNotchRecognizer {
    struct Contact: Equatable, Sendable {
        let id: Int32
        let x: Double
        let y: Double
        var force: Double? = nil
    }
    private var contactID: Int32?
    private var beganAt: Double?
    private var lastTimestamp: Double?
    private var fired = false
    private var blockedUntilRelease = false
    private var targetWasOpen: Bool?
    private var pressureQualified = false

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
              hypot(contact.x - config.x, contact.y - config.y) <= config.radius
        else { beganAt = nil; contactID = nil; pressureQualified = false; return false }
        if let lastTimestamp, timestamp < lastTimestamp || timestamp - lastTimestamp > 0.25 {
            beganAt = nil; contactID = nil; pressureQualified = false
        }
        if contactID != contact.id { pressureQualified = false }
        if config.minimumPressure > 0 {
            // A small release band avoids restarting a hold for sensor jitter around
            // the threshold. Missing force never counts as sustained pressure.
            let releaseBand = min(0.03, config.minimumPressure * 0.1)
            let threshold = pressureQualified ? config.minimumPressure - releaseBand : config.minimumPressure
            guard let pressure, pressure.isFinite, pressure >= threshold else {
                beganAt = nil; pressureQualified = false; return false
            }
            pressureQualified = true
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


/// Per-contact force processing; contact area and capacitance are never substituted.
struct TouchpadPressureFilter {
    private var contactID: Int32?
    private var lastTime: Double?
    private var smoothed: Double?

    mutating func reset() { self = Self() }

    mutating func update(force: Double?, contact: Int32?, time: Double, reference: Double?) -> Double? {
        guard let force, force.isFinite, force >= 0, force <= 65535,
              let contact, time.isFinite else { reset(); return nil }
        let scale = reference.flatMap { $0.isFinite && $0 >= 1 && $0 <= 65535 ? $0 : nil } ?? 255
        let normalized = min(1, force / scale)
        if normalized == 0 || contactID != contact || lastTime == nil || time < lastTime! || time - lastTime! > 0.25 {
            smoothed = normalized
        } else {
            let alpha = 1 - exp(-(time - lastTime!) / 0.04)
            smoothed = (smoothed ?? normalized) + alpha * (normalized - (smoothed ?? normalized))
        }
        contactID = contact; lastTime = time
        return smoothed
    }
}

struct TouchpadPressureLearner {
    static let holdDuration = 3.0
    private var anchorForce: Double?
    private var waitingForRelease: Bool
    private var contactID: Int32?
    private var began: Double?
    private var lastTime: Double?
    private var samples: [Double] = []
    private(set) var progress = 0.0

    init(waitingForRelease: Bool = false) { self.waitingForRelease = waitingForRelease }

    mutating func update(force: Double?, contact: Int32?, time: Double) -> Double? {
        if waitingForRelease {
            if contact == nil { waitingForRelease = false }
            return nil
        }
        guard let force, force.isFinite, force >= 1, force <= 65535,
              let contact, time.isFinite else { clear(); return nil }
        if contactID != contact || lastTime == nil || time < lastTime! || time - lastTime! > 0.25 { clear() }
        if let anchorForce, abs(force - anchorForce) > max(3, anchorForce * 0.2) { clear() }
        anchorForce = anchorForce ?? force
        contactID = contact
        began = began ?? time
        lastTime = time
        samples.append(force)
        if samples.count > 512 { samples.removeFirst() }
        progress = min(1, (time - began!) / Self.holdDuration)
        guard progress >= 1, samples.count >= 36 else { return nil }
        // Use a lower percentile of the stable press, so small variation does not
        // make the learned level harder to reproduce than the user's own press.
        let sorted = samples.sorted()
        return max(1, sorted[Int(Double(sorted.count - 1) * 0.2)])
    }

    private mutating func clear() {
        anchorForce = nil; contactID = nil; began = nil; lastTime = nil; samples.removeAll(); progress = 0
    }
}

/// Quick controls start at the saved spot; dragging into it never arms a control.
struct TouchpadQuickGestureRecognizer {
    private var origin: TouchpadNotchRecognizer.Contact?
    private var began = 0.0
    private var lastTime: Double?
    private var blocked = false
    private var moved = false
    private var qualified = false
    private var lastY = 0.0

    mutating func reset() { self = Self() }
    mutating func requireRelease() { reset(); blocked = true }

    mutating func update(contacts: [TouchpadNotchRecognizer.Contact], pressure: Double?,
                         timestamp: Double, settings: TouchpadNotchSettings) -> TouchpadNotchSettings.Destination? {
        guard settings.enabled, settings.hasSpot, !settings.destination.togglesSurface,
              timestamp.isFinite else { reset(); return nil }
        let action = settings.destination
        if contacts.isEmpty {
            let tap = !blocked && !moved && qualified && origin != nil && timestamp >= began
                && timestamp - began >= 0.04 && timestamp - began <= 0.45
                && (action == .playPause || action == .mute)
            reset()
            return tap ? action : nil
        }
        guard !blocked, contacts.count == 1, let finger = contacts.first,
              (0...1).contains(finger.x), (0...1).contains(finger.y) else { blocked = true; return nil }
        if let lastTime, timestamp < lastTime || timestamp - lastTime > 0.25 { blocked = true; return nil }
        lastTime = timestamp
        if origin == nil {
            guard hypot(finger.x - settings.x, finger.y - settings.y) <= settings.radius else { blocked = true; return nil }
            origin = finger; began = timestamp; lastY = finger.y
        }
        guard let origin, origin.id == finger.id else { blocked = true; return nil }
        qualified = qualified || settings.minimumPressure == 0
            || (pressure.map { $0.isFinite && $0 >= settings.minimumPressure } ?? false)
        guard qualified else { return nil }
        let dx = finger.x - origin.x, dy = finger.y - origin.y
        if hypot(dx, dy) > 0.025 { moved = true }
        switch action {
        case .nextTrack, .previousTrack:
            guard abs(dx) >= 0.08, abs(dx) > abs(dy) * 1.5 else { return nil }
            blocked = true
            return dx > 0 ? .nextTrack : .previousTrack
        case .volumeUp, .volumeDown:
            guard abs(dy) > abs(dx) * 1.5, abs(finger.y - lastY) >= 0.035 else { return nil }
            let result: TouchpadNotchSettings.Destination = finger.y > lastY ? .volumeUp : .volumeDown
            lastY = finger.y
            return result
        default: return nil
        }
    }
}
