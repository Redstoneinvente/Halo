import Foundation
import SwiftUI
import AppKit
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
        let nextPoweredOn = IOBluetoothHostController.default()?.powerState == kBluetoothHCIPowerStateON
        let raw = (IOBluetoothDevice.pairedDevices() ?? []).compactMap { $0 as? IOBluetoothDevice }

        // IOBluetooth can occasionally return duplicate paired-device objects for the same
        // physical address. Build the snapshot set through a merge dictionary so duplicate
        // addresses never reach SwiftUI IDs or Dictionary(uniqueKeysWithValues:).
        var mergedByID: [String: BluetoothDeviceSnapshot] = [:]
        for (index, device) in raw.enumerated() {
            let rawAddress = (device.addressString ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedAddress = rawAddress.lowercased()
            let rawName = (device.name ?? device.nameOrAddress ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let name = rawName.isEmpty ? (rawAddress.isEmpty ? "Bluetooth device" : rawAddress) : rawName
            let fallbackName = name.lowercased()
            let id = normalizedAddress.isEmpty ? "name:\(fallbackName.isEmpty ? String(index) : fallbackName)" : normalizedAddress
            let snapshot = BluetoothDeviceSnapshot(id: id,
                                                   name: name,
                                                   address: rawAddress,
                                                   connected: device.isConnected())

            if let existing = mergedByID[id] {
                let existingLooksLikeAddress = !existing.address.isEmpty && existing.name.caseInsensitiveCompare(existing.address) == .orderedSame
                let preferIncomingName = existing.name == "Bluetooth device" || (existingLooksLikeAddress && name.caseInsensitiveCompare(rawAddress) != .orderedSame)
                mergedByID[id] = BluetoothDeviceSnapshot(id: id,
                                                         name: preferIncomingName ? name : existing.name,
                                                         address: existing.address.isEmpty ? rawAddress : existing.address,
                                                         connected: existing.connected || snapshot.connected)
            } else {
                mergedByID[id] = snapshot
            }
        }

        let nextDevices = Array(mergedByID.values).sorted {
            if $0.connected != $1.connected { return $0.connected && !$1.connected }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        guard primed else {
            poweredOn = nextPoweredOn
            devices = nextDevices
            primed = true
            return
        }

        // Keep these dictionaries tolerant too. The service now publishes unique IDs, but this
        // also protects state restored from an older in-memory snapshot if a duplicate slipped in.
        let previousByID = Dictionary(devices.map { ($0.id, $0) }, uniquingKeysWith: mergeSnapshots)
        let nextByID = Dictionary(nextDevices.map { ($0.id, $0) }, uniquingKeysWith: mergeSnapshots)

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

    private func mergeSnapshots(_ current: BluetoothDeviceSnapshot, _ incoming: BluetoothDeviceSnapshot) -> BluetoothDeviceSnapshot {
        let currentLooksLikeAddress = !current.address.isEmpty && current.name.caseInsensitiveCompare(current.address) == .orderedSame
        let incomingHasBetterName = current.name == "Bluetooth device" || (currentLooksLikeAddress && incoming.name.caseInsensitiveCompare(incoming.address) != .orderedSame)
        return BluetoothDeviceSnapshot(id: current.id,
                                       name: incomingHasBetterName ? incoming.name : current.name,
                                       address: current.address.isEmpty ? incoming.address : current.address,
                                       connected: current.connected || incoming.connected)
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

// MARK: - Bluetooth CI settings UI

struct BluetoothContextInterfaceCard: View {
    let enabled: Bool
    let action: () -> Void
    @ObservedObject private var bluetooth = BluetoothStateService.shared
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [Color.blue.opacity(0.34), Color.black.opacity(0.96)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.blue.opacity(0.20))
                            .frame(width: 62, height: 62)
                            .overlay(Image(systemName: bluetooth.poweredOn ? "wave.3.right" : "wave.3.right.slash")
                                .font(.title2.weight(.semibold)).foregroundStyle(.white))
                        VStack(alignment: .leading, spacing: 6) {
                            Text(bluetooth.poweredOn ? "Bluetooth On" : "Bluetooth Off")
                                .font(.headline).foregroundStyle(.white)
                            Text(bluetooth.poweredOn ? connectedSummary : "Connections unavailable")
                                .font(.caption).foregroundStyle(.white.opacity(0.64))
                            HStack(spacing: 5) {
                                ForEach(Array(bluetooth.connectedDevices.prefix(3))) { device in
                                    Circle().fill(Color.green).frame(width: 6, height: 6)
                                        .help(device.name)
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }.padding(16)
                }
                .frame(height: 112)

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Bluetooth CI").font(.headline)
                        Text("Devices & connections").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(enabled ? "Enabled" : "Available")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background((enabled ? Color.green : Color.secondary).opacity(0.12), in: Capsule())
                        .foregroundStyle(enabled ? Color.green : Color.secondary)
                }

                Text("Shows connected and paired devices, Bluetooth power state, and recent connection or disconnection changes.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)

                HStack {
                    Label(bluetooth.poweredOn ? connectedSummary : "Off", systemImage: "wave.3.right")
                        .font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Label("Edit", systemImage: "chevron.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(hovered ? 0.075 : 0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(hovered ? Color.accentColor.opacity(0.42) : Color.primary.opacity(0.08), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.14), value: hovered)
        .onAppear { bluetooth.start() }
    }

    private var connectedSummary: String {
        let count = bluetooth.connectedDevices.count
        return count == 1 ? "1 connected" : "\(count) connected"
    }
}

struct ContextBluetoothSettings: View {
    @ObservedObject private var bluetooth = BluetoothStateService.shared
    @AppStorage("HaloContextBluetoothEnabled") private var enabled = false
    @AppStorage("HaloContextBluetoothShowWhileConnected") private var showWhileConnected = true
    @AppStorage("HaloContextBluetoothShowOnChanges") private var showOnChanges = true
    @AppStorage("HaloContextBluetoothShowPaired") private var showPaired = true
    @AppStorage("HaloContextBluetoothShowAddresses") private var showAddresses = false
    @AppStorage("HaloContextBluetoothUseFullNotchArea") private var useFullNotchArea = false
    @AppStorage("HaloContextBluetoothKeepClosedNotchContents") private var keepClosedNotchContents = false
    @AppStorage("HaloBluetoothClosedNotchEvents") private var closedNotchEvents = true

    var body: some View {
        Section("Bluetooth Context Interface") {
            Toggle("Enable Bluetooth CI", isOn: $enabled)
            Toggle("Show CI while a Bluetooth device is connected", isOn: $showWhileConnected)
                .disabled(!enabled)
            Toggle("Show CI for connection changes", isOn: $showOnChanges)
                .disabled(!enabled)
            Text("A recent connect, disconnect, Bluetooth-on or Bluetooth-off event temporarily takes CI priority. Otherwise Music CI keeps priority while music is playing, and Bluetooth CI can take over when connected devices remain.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("CI surface") {
            Toggle("Use full notch area", isOn: $useFullNotchArea)
            Toggle("Keep closed-notch contents visible", isOn: $keepClosedNotchContents)
            Text(useFullNotchArea ? "Bluetooth CI can use the entire expanded Halo surface." : "Bluetooth CI starts below the normal notch/top strip.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("Device list") {
            Toggle("Show paired devices that are disconnected", isOn: $showPaired)
            Toggle("Show Bluetooth addresses", isOn: $showAddresses)
            Text("Connected devices are always shown first. Addresses are hidden by default to keep the interface clean.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("Closed Notch states") {
            Toggle("Show Bluetooth connection states", isOn: $closedNotchEvents)
            Text("When enabled, connect, disconnect, Bluetooth-on and Bluetooth-off changes appear as temporary Closed Notch activity states without replacing your saved left/right layout.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("Live status") {
            Label(bluetooth.poweredOn ? "Bluetooth is on" : "Bluetooth is off",
                  systemImage: bluetooth.poweredOn ? "wave.3.right" : "wave.3.right.slash")
                .foregroundStyle(bluetooth.poweredOn ? Color.primary : Color.secondary)
            Text(statusSummary).font(.caption).foregroundStyle(.secondary)
            ForEach(bluetooth.connectedDevices) { device in
                HStack {
                    Circle().fill(Color.green).frame(width: 7, height: 7)
                    Text(device.name)
                    Spacer()
                    Text("Connected").font(.caption).foregroundStyle(.secondary)
                }
            }
            if let event = bluetooth.lastEvent {
                Label("\(event.title): \(event.detail)", systemImage: event.symbol)
                    .font(.caption).foregroundStyle(.blue)
            }
            HStack {
                Button("Refresh") { bluetooth.refresh() }
                Button("Open Bluetooth Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") { NSWorkspace.shared.open(url) }
                }
            }
        }
        .onAppear { bluetooth.start(); bluetooth.refresh() }
    }

    private var statusSummary: String {
        guard bluetooth.poweredOn else { return "Turn Bluetooth on to track device connections." }
        let connected = bluetooth.connectedDevices.count
        let paired = bluetooth.pairedDevices.count
        return "\(connected) connected · \(paired) paired"
    }
}
