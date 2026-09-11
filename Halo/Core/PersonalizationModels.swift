import Foundation
import IOBluetooth

struct DailyWindow: Codable, Equatable {
    var startMinute = 9 * 60
    var endMinute = 17 * 60
    var weekdays: Set<Int> = [1, 2, 3, 4, 5, 6, 7] // Calendar: Sunday = 1
    func occurrence(at date: Date, calendar: Calendar = .current) -> Date? {
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let start = min(1439, max(0, startMinute)), end = min(1439, max(0, endMinute))
        var day = calendar.startOfDay(for: date)
        if start < end {
            guard minute >= start && minute < end else { return nil }
        } else if start > end {
            if minute < end { day = calendar.date(byAdding: .day, value: -1, to: day) ?? day }
            else if minute < start { return nil }
        }
        return weekdays.contains(calendar.component(.weekday, from: day)) ? day : nil
    }
}
struct ProfileSchedule: Codable, Identifiable, Equatable {
    var id = UUID()
    var enabled = true
    var window = DailyWindow()
    var profileID: UUID
}
struct GrainOptions: Codable, Equatable {
    var enabled = false
    var amount = 0.18
    var size = 1.0
    var warmth = 0.3
    func validated() throws -> GrainOptions {
        guard [amount, size, warmth].allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
        v.amount = min(0.6, max(0, amount)); v.size = min(3, max(0.5, size)); v.warmth = min(1, max(0, warmth))
        return v
    }
}
struct TimedBackground: Codable, Identifiable, Equatable {
    var id = UUID()
    var enabled = true
    var window = DailyWindow()
    var kind: BackgroundKind = .gradient
    var assetPath = ""
    var blur = 0.0
    var grain = GrainOptions()
}
extension Appearance {
    func resolved(at date: Date, calendar: Calendar = .current) -> Appearance {
        guard let entry = backgroundSchedule?.first(where: { $0.enabled && $0.window.occurrence(at: date, calendar: calendar) != nil }) else { return self }
        var result = self
        result.background = entry.kind; result.assetPath = entry.assetPath
        result.blur = entry.blur; result.grain = entry.grain
        return result
    }
}
enum DecorationVisibility: String, Codable, CaseIterable { case disabled, always, playing }
enum DecorationKind: String, Codable, CaseIterable { case symbol, image }
struct SideDecoration: Codable, Equatable {
    var visibility: DecorationVisibility = .disabled
    var kind: DecorationKind = .symbol
    var symbol = "sparkles"
    var assetPath = ""
    var size = 22.0
    var color = WidgetColor.white
    func isVisible(playing: Bool) -> Bool { visibility == .always || (visibility == .playing && playing) }
    func validatedForImport() throws -> SideDecoration {
        guard size.isFinite else { throw CocoaError(.fileReadCorruptFile) }
        var v = self; v.size = min(64, max(12, size)); v.color = try color.validated()
        v.symbol = String(symbol.prefix(120)); v.assetPath = ""
        if kind == .image { v.visibility = .disabled }
        return v
    }
}

struct PlayerSnapshot: Equatable {
    var app: String
    var title = "Nothing playing"
    var artist = ""
    var playing = false
    var trackID = ""
}
enum PlayerSelection {
    static func choose(_ snapshots: [PlayerSnapshot], current: String?, preferred: String) -> PlayerSnapshot? {
        let playing = snapshots.filter(\.playing)
        let candidates = playing.isEmpty ? snapshots : playing
        return candidates.first { $0.app == current } ?? candidates.first { $0.app == preferred } ?? candidates.first
    }
}

// MARK: - Bluetooth context state

struct BluetoothDeviceSnapshot: Identifiable, Equatable {
    let id: String
    let name: String
    let address: String
    let connected: Bool
}

enum BluetoothConnectionEventKind: Equatable {
    case connected
    case disconnected
    case poweredOn
    case poweredOff
}

struct BluetoothConnectionEvent: Identifiable, Equatable {
    let id = UUID()
    let kind: BluetoothConnectionEventKind
    let deviceName: String?
    let date = Date()

    var title: String {
        switch kind {
        case .connected: return "Bluetooth connected"
        case .disconnected: return "Bluetooth disconnected"
        case .poweredOn: return "Bluetooth on"
        case .poweredOff: return "Bluetooth off"
        }
    }

    var detail: String {
        switch kind {
        case .connected, .disconnected: return deviceName ?? "Bluetooth device"
        case .poweredOn: return "Ready for devices"
        case .poweredOff: return "Connections unavailable"
        }
    }

    var symbol: String {
        switch kind {
        case .connected: return "wave.3.right.circle.fill"
        case .disconnected: return "wave.3.right.circle"
        case .poweredOn: return "wave.3.right"
        case .poweredOff: return "wave.3.right.slash"
        }
    }
}

@MainActor
final class BluetoothStateService: ObservableObject {
    static let shared = BluetoothStateService()

    @Published private(set) var poweredOn = false
    @Published private(set) var devices: [BluetoothDeviceSnapshot] = []
    @Published private(set) var lastEvent: BluetoothConnectionEvent?

    var connectedDevices: [BluetoothDeviceSnapshot] { devices.filter(\.connected) }
    var pairedDevices: [BluetoothDeviceSnapshot] { devices }

    private var timer: Timer?
    private var primed = false
    private var clearEventWork: DispatchWorkItem?

    private init() {}

    func start() {
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        clearEventWork?.cancel()
        clearEventWork = nil
    }

    func refresh() {
        let nextPoweredOn = (IOBluetoothHostController.default()?.powerState.rawValue ?? 0) == 1
        let raw = (IOBluetoothDevice.pairedDevices() ?? []).compactMap { $0 as? IOBluetoothDevice }
        let nextDevices = raw.map { device -> BluetoothDeviceSnapshot in
            let address = device.addressString ?? ""
            let name = device.name ?? device.nameOrAddress ?? (address.isEmpty ? "Bluetooth device" : address)
            return BluetoothDeviceSnapshot(id: address.isEmpty ? name : address,
                                           name: name,
                                           address: address,
                                           connected: device.isConnected())
        }.sorted {
            if $0.connected != $1.connected { return $0.connected && !$1.connected }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        guard primed else {
            poweredOn = nextPoweredOn
            devices = nextDevices
            primed = true
            return
        }

        let previousByID = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })
        let nextByID = Dictionary(uniqueKeysWithValues: nextDevices.map { ($0.id, $0) })

        if poweredOn != nextPoweredOn {
            emit(BluetoothConnectionEvent(kind: nextPoweredOn ? .poweredOn : .poweredOff, deviceName: nil))
        }

        let newlyConnected = nextDevices.first { device in
            device.connected && previousByID[device.id]?.connected != true
        }
        let newlyDisconnected = devices.first { device in
            device.connected && nextByID[device.id]?.connected != true
        }

        if let newlyConnected {
            emit(BluetoothConnectionEvent(kind: .connected, deviceName: newlyConnected.name))
        } else if let newlyDisconnected {
            emit(BluetoothConnectionEvent(kind: .disconnected, deviceName: newlyDisconnected.name))
        }

        poweredOn = nextPoweredOn
        devices = nextDevices
    }

    private func emit(_ event: BluetoothConnectionEvent) {
        lastEvent = event
        clearEventWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard self?.lastEvent?.id == event.id else { return }
            self?.lastEvent = nil
        }
        clearEventWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: work)
    }
}
