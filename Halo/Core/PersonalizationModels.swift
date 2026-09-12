import Foundation
import SwiftUI
import AppKit
import IOBluetooth
import Combine

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

enum BluetoothConnectionEventKind: String, Codable, CaseIterable, Equatable {
    case connected
    case disconnected
    case poweredOn
    case poweredOff
}

enum BluetoothClosedNotchSide: String, CaseIterable, Identifiable {
    case automatic, left, right
    var id: String { rawValue }
    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .left: return "Left"
        case .right: return "Right"
        }
    }
}

enum BluetoothClosedNotchLayout: String, CaseIterable, Identifiable {
    case inline, stacked, iconOnly, textOnly
    var id: String { rawValue }
    var title: String {
        switch self {
        case .inline: return "Inline"
        case .stacked: return "Stacked"
        case .iconOnly: return "Icon only"
        case .textOnly: return "Text only"
        }
    }
}

enum BluetoothClosedNotchAccent: String, CaseIterable, Identifiable {
    case inherit, blue, green, accent, white
    var id: String { rawValue }
    var title: String {
        switch self {
        case .inherit: return "Closed Notch color"
        case .blue: return "Bluetooth blue"
        case .green: return "Connected green"
        case .accent: return "Halo accent"
        case .white: return "White"
        }
    }
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
    @Published private(set) var pendingDeviceIDs: Set<String> = []
    @Published var connectionError: String?

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
        pendingDeviceIDs.removeAll()
    }

    func isChangingConnection(for device: BluetoothDeviceSnapshot) -> Bool {
        pendingDeviceIDs.contains(device.id)
    }

    func toggleConnection(for device: BluetoothDeviceSnapshot) {
        setConnected(!device.connected, for: device)
    }

    func setConnected(_ shouldConnect: Bool, for device: BluetoothDeviceSnapshot) {
        guard poweredOn else {
            connectionError = "Bluetooth is turned off."
            return
        }
        guard !pendingDeviceIDs.contains(device.id) else { return }
        pendingDeviceIDs.insert(device.id)
        connectionError = nil

        let deviceID = device.id
        DispatchQueue.global(qos: .userInitiated).async {
            let status = Self.performConnectionChange(deviceID: deviceID, shouldConnect: shouldConnect)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pendingDeviceIDs.remove(deviceID)
                self.refresh()
                if status != kIOReturnSuccess {
                    self.connectionError = shouldConnect
                        ? "Could not connect to \(device.name) (Bluetooth error \(status))."
                        : "Could not disconnect \(device.name) (Bluetooth error \(status))."
                }
            }
        }
    }

    nonisolated private static func performConnectionChange(deviceID: String, shouldConnect: Bool) -> IOReturn {
        let raw = (IOBluetoothDevice.pairedDevices() ?? []).compactMap { $0 as? IOBluetoothDevice }
        guard let device = raw.first(where: { matches($0, id: deviceID) }) else { return kIOReturnNotFound }
        if shouldConnect {
            if device.isConnected() { return kIOReturnSuccess }
            return device.openConnection()
        }
        if !device.isConnected() { return kIOReturnSuccess }
        return device.closeConnection()
    }

    nonisolated private static func matches(_ device: IOBluetoothDevice, id: String) -> Bool {
        let address = (device.addressString ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !address.isEmpty { return address == id }
        let name = (device.name ?? device.nameOrAddress ?? "Bluetooth device")
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "name:\(name)" == id
    }

    func refresh() {
        let nextPoweredOn = IOBluetoothHostController.default()?.powerState == kBluetoothHCIPowerStateON
        let raw = (IOBluetoothDevice.pairedDevices() ?? []).compactMap { $0 as? IOBluetoothDevice }

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
    }
}

// MARK: - Bluetooth CI settings UI

struct BluetoothContextInterfaceCard: View {
    let enabled: Bool
    let action: () -> Void
    @ObservedObject private var bluetooth = BluetoothStateService.shared
    @AppStorage("HaloContextBluetoothPriority") private var priority = 50.0
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
                    Text("Priority \(Int(priority))")
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
    @AppStorage("HaloContextBluetoothPriority") private var priority = 50.0

    var body: some View {
        Section("Bluetooth Context Interface") {
            Toggle("Enable Bluetooth CI", isOn: $enabled)
            Toggle("Show CI while a Bluetooth device is connected", isOn: $showWhileConnected)
                .disabled(!enabled)
            Toggle("Show CI for connection changes", isOn: $showOnChanges)
                .disabled(!enabled)
        }

        Section("CI priority") {
            Slider(value: $priority, in: 0...100, step: 1) { Text("Bluetooth CI priority") }
            Text("When multiple Context Interfaces are eligible, Halo gives the surface to the eligible CI with the highest priority.")
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
            Text("Connected devices are always shown first. You can connect or disconnect paired devices directly from Bluetooth CI.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("Closed Notch Bluetooth states") {
            Label("Configure Bluetooth connect/disconnect and power-state events under Settings → Closed notch → Bluetooth events.",
                  systemImage: "rectangle.topthird.inset.filled")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("Live status") {
            Label(bluetooth.poweredOn ? "Bluetooth is on" : "Bluetooth is off",
                  systemImage: bluetooth.poweredOn ? "wave.3.right" : "wave.3.right.slash")
                .foregroundStyle(bluetooth.poweredOn ? Color.primary : Color.secondary)
            Text(statusSummary).font(.caption).foregroundStyle(.secondary)
            ForEach(bluetooth.pairedDevices) { device in
                HStack(spacing: 8) {
                    Circle().fill(device.connected ? Color.green : Color.secondary.opacity(0.6)).frame(width: 7, height: 7)
                    Text(device.name).lineLimit(1)
                    Spacer()
                    if bluetooth.isChangingConnection(for: device) {
                        ProgressView().controlSize(.small)
                    } else {
                        Button(device.connected ? "Disconnect" : "Connect") {
                            bluetooth.toggleConnection(for: device)
                        }
                        .disabled(!bluetooth.poweredOn)
                    }
                }
            }
            if let error = bluetooth.connectionError {
                Text(error).font(.caption).foregroundStyle(.orange)
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

// MARK: - Retro Game CI

enum RetroGameKind: String, CaseIterable, Identifiable {
    case snake = "Snake"
    case pong = "Pong"
    var id: String { rawValue }
}

enum RetroGamePalette: String, CaseIterable, Identifiable {
    case phosphor = "Phosphor"
    case amber = "Amber"
    case ice = "Ice"
    var id: String { rawValue }

    var foreground: Color {
        switch self {
        case .phosphor: return Color(red: 0.48, green: 1.0, blue: 0.56)
        case .amber: return Color(red: 1.0, green: 0.72, blue: 0.24)
        case .ice: return Color(red: 0.48, green: 0.88, blue: 1.0)
        }
    }
    var background: Color {
        switch self {
        case .phosphor: return Color(red: 0.015, green: 0.055, blue: 0.025)
        case .amber: return Color(red: 0.055, green: 0.035, blue: 0.01)
        case .ice: return Color(red: 0.012, green: 0.035, blue: 0.055)
        }
    }
}

struct RetroGameContextInterfaceCard: View {
    let enabled: Bool
    let action: () -> Void
    @AppStorage("HaloContextRetroPriority") private var priority = 80.0
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.black)
                    VStack(spacing: 7) {
                        Text("HALO // ARCADE")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.green)
                        HStack(spacing: 4) {
                            ForEach(0..<12, id: \.self) { index in
                                Rectangle()
                                    .fill([1, 2, 3, 7, 8, 9].contains(index) ? Color.green : Color.green.opacity(0.16))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        Text("8-BIT READY")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.green.opacity(0.72))
                    }
                    .padding(14)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                }
                .frame(height: 112)

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Retro Game CI").font(.headline)
                        Text("Pixel arcade").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(enabled ? "Enabled" : "Available")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background((enabled ? Color.green : Color.secondary).opacity(0.12), in: Capsule())
                        .foregroundStyle(enabled ? Color.green : Color.secondary)
                }

                Text("Turns the expanded notch into a tiny pixel display with playable 8-bit games and a summon shortcut.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)

                HStack {
                    Label("Snake + Pong", systemImage: "gamecontroller")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text("Priority \(Int(priority))")
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
    }
}

struct ContextRetroGameSettings: View {
    @AppStorage("HaloContextRetroEnabled") private var enabled = false
    @AppStorage("HaloContextRetroPriority") private var priority = 80.0
    @AppStorage("HaloContextRetroUseFullNotchArea") private var useFullNotchArea = false
    @AppStorage("HaloContextRetroKeepClosedNotchContents") private var keepClosedNotchContents = false
    @AppStorage("HaloContextRetroShortcutEnabled") private var shortcutEnabled = true
    @AppStorage("HaloContextRetroShortcutCode") private var shortcutCode = 5
    @AppStorage("HaloContextRetroShortcutModifiers") private var shortcutModifiers = 2304
    @AppStorage("HaloContextRetroGame") private var gameRaw = RetroGameKind.snake.rawValue
    @AppStorage("HaloContextRetroPalette") private var paletteRaw = RetroGamePalette.phosphor.rawValue
    @AppStorage("HaloContextRetroScanlines") private var scanlines = true
    @AppStorage("HaloContextRetroShowInactivePixels") private var showInactivePixels = false
    @AppStorage("HaloContextRetroCompanionMascot") private var showCompanionMascot = true

    var body: some View {
        Section("Retro Game Context Interface") {
            Toggle("Enable Retro Game CI", isOn: $enabled)
            Picker("Default game", selection: $gameRaw) {
                ForEach(RetroGameKind.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
            Picker("Pixel palette", selection: $paletteRaw) {
                ForEach(RetroGamePalette.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
            Toggle("Show inactive pixel cells", isOn: $showInactivePixels)
            Toggle("CRT scanlines", isOn: $scanlines)
            Toggle("Show EI companion mascot", isOn: $showCompanionMascot)
            Text(showInactivePixels ? "Unlit cells remain faintly visible, like a physical dot-matrix/LCD panel." : "Only illuminated game pixels are visible.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Open / close Retro Game CI") {
                NotificationCenter.default.post(name: .init("HaloRetroGameToggle"), object: nil)
            }
            .disabled(!enabled)
        }

        Section("CI priority") {
            Slider(value: $priority, in: 0...100, step: 1) { Text("Retro Game CI priority") }
            Text("The Retro Game CI is eligible only while it has been summoned. If another active CI has a higher priority, that CI keeps ownership.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("CI surface") {
            Toggle("Use full notch area", isOn: $useFullNotchArea)
            Toggle("Keep closed-notch contents visible", isOn: $keepClosedNotchContents)
            Text(useFullNotchArea ? "The pixel display can use the entire expanded Halo surface." : "The arcade starts below the normal notch/top strip.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("Keyboard shortcut") {
            Toggle("Enable summon shortcut", isOn: $shortcutEnabled)
            Picker("Key", selection: $shortcutCode) {
                Text("G").tag(5)
                Text("R").tag(15)
                Text("Space").tag(49)
            }
            .disabled(!shortcutEnabled || !enabled)
            Picker("Modifiers", selection: $shortcutModifiers) {
                Text("Option + Command").tag(2304)
                Text("Control + Option").tag(6144)
                Text("Control + Shift").tag(4608)
            }
            .disabled(!shortcutEnabled || !enabled)
            Text("Current shortcut: \(shortcutDescription). Press it again to dismiss the arcade.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("Controls") {
            Label("Snake: arrow keys or WASD", systemImage: "arrowkeys")
            Label("Pong: W/S or ↑/↓", systemImage: "gamecontroller")
            Text("Halo listens locally while it has focus and also uses a global key monitor while another app owns focus. macOS may require Input Monitoring for the global path. On-screen controls remain available.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var shortcutDescription: String {
        let modifiers: String
        switch shortcutModifiers {
        case 6144: modifiers = "⌃⌥"
        case 4608: modifiers = "⌃⇧"
        default: modifiers = "⌥⌘"
        }
        let key: String
        switch shortcutCode {
        case 15: key = "R"
        case 49: key = "Space"
        default: key = "G"
        }
        return modifiers + key
    }
}

private struct RetroPixelCell: Hashable {
    var x: Int
    var y: Int
}

private enum RetroSnakeDirection {
    case up, down, left, right
}

struct RetroGameContextView: View {
    @ObservedObject var surfaceState: SurfaceState
    @ObservedObject private var eiSettings = EISettingsStore.shared
    @AppStorage("HaloContextRetroUseFullNotchArea") private var usesFullNotchArea = false
    @AppStorage("HaloContextRetroKeepClosedNotchContents") private var keepsClosedNotchContents = false
    @AppStorage("HaloContextRetroPriority") private var priority = 80.0
    @AppStorage("HaloContextRetroGame") private var gameRaw = RetroGameKind.snake.rawValue
    @AppStorage("HaloContextRetroPalette") private var paletteRaw = RetroGamePalette.phosphor.rawValue
    @AppStorage("HaloContextRetroScanlines") private var scanlines = true
    @AppStorage("HaloContextRetroShowInactivePixels") private var showInactivePixels = false
    @AppStorage("HaloContextRetroCompanionMascot") private var showCompanionMascot = true

    @State private var snake = [RetroPixelCell(x: 8, y: 6), RetroPixelCell(x: 7, y: 6), RetroPixelCell(x: 6, y: 6)]
    @State private var snakeDirection: RetroSnakeDirection = .right
    @State private var pendingSnakeDirection: RetroSnakeDirection = .right
    @State private var food = RetroPixelCell(x: 18, y: 6)
    @State private var snakeScore = 0
    @State private var snakeHighScore = 0

    @State private var pongBall = CGPoint(x: 0.5, y: 0.5)
    @State private var pongVelocity = CGVector(dx: 0.012, dy: 0.010)
    @State private var pongPlayerY: CGFloat = 0.5
    @State private var pongCPUY: CGFloat = 0.5
    @State private var pongPlayerScore = 0
    @State private var pongCPUScore = 0

    @State private var tickCount = 0
    @State private var keyMonitor: Any?
    @State private var globalKeyMonitor: Any?

    private let snakeColumns = 28
    private let snakeRows = 12
    private var game: RetroGameKind { RetroGameKind(rawValue: gameRaw) ?? .snake }
    private var palette: RetroGamePalette { RetroGamePalette(rawValue: paletteRaw) ?? .phosphor }
    private var topInset: CGFloat {
        if usesFullNotchArea && keepsClosedNotchContents { return max(16, surfaceState.compactHeight + 10) }
        if usesFullNotchArea { return max(14, surfaceState.compactHeight * 0.64) }
        return 14
    }

    var body: some View {
        ZStack {
            Color.black
            LinearGradient(colors: [palette.background.opacity(0.95), Color.black], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 10) {
                header
                gameScreen
                controls
            }
            .padding(.horizontal, 16)
            .padding(.top, topInset)
            .padding(.bottom, 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: usesFullNotchArea ? 0 : 16, style: .continuous))
        .onReceive(Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()) { _ in tick() }
        .onAppear {
            publishPreferredSize()
            installKeyMonitors()
        }
        .onChange(of: usesFullNotchArea) { _ in publishPreferredSize() }
        .onChange(of: keepsClosedNotchContents) { _ in publishPreferredSize() }
        .onChange(of: gameRaw) { _ in resetCurrentGame() }
        .onDisappear {
            removeKeyMonitors()
            surfaceState.contextPreferredSize = nil
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("HALO // ARCADE")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(palette.foreground)
                Text(game == .snake ? "SNAKE_8" : "PONG_8")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.foreground.opacity(0.58))
            }
            Spacer()
            Text("P\(Int(priority))")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.foreground.opacity(0.62))
            Menu {
                ForEach(RetroGameKind.allCases) { game in
                    Button(game.rawValue) { gameRaw = game.rawValue }
                }
                Divider()
                Button("Reset game") { resetCurrentGame() }
            } label: {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(palette.foreground)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
            Button {
                NotificationCenter.default.post(name: .init("HaloRetroGameToggle"), object: nil)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(palette.foreground)
            }
            .buttonStyle(.plain)
            .help("Close Retro Game CI")
        }
    }

    private var gameScreen: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(palette.background)
                Canvas { context, size in
                    if showInactivePixels { drawInactivePixels(context: context, size: size) }
                    switch game {
                    case .snake: drawSnake(context: context, size: size)
                    case .pong: drawPong(context: context, size: size)
                    }
                    if scanlines {
                        var y: CGFloat = 2
                        while y < size.height {
                            var line = Path()
                            line.addRect(CGRect(x: 0, y: y, width: size.width, height: 1))
                            context.fill(line, with: .color(Color.black.opacity(0.22)))
                            y += 4
                        }
                    }
                }
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(palette.foreground.opacity(0.42), lineWidth: 2)
                VStack {
                    HStack {
                        Text(scoreText)
                        Spacer()
                        Text("\(game.rawValue.uppercased())")
                    }
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.foreground.opacity(0.72))
                    .padding(8)
                    Spacer()
                }
                if showCompanionMascot {
                    HaloCompanionSprite(
                        kind: eiSettings.settings.petKind,
                        style: .pixel,
                        size: 48,
                        primary: palette.foreground,
                        accent: eiSettings.settings.petAccentColor.color,
                        motion: game == .pong ? .look : .walk,
                        facingRight: false,
                        displayPreset: .clean,
                        pixelGrid: false,
                        pixelGlow: false,
                        scanlines: false,
                        ghosting: false,
                        brightnessVariation: false
                    )
                    .frame(width: 50, height: 38)
                    .opacity(0.70)
                    .padding(8)
                    .allowsHitTesting(false)
                }
            }
        }
        .frame(minHeight: 150, idealHeight: 178, maxHeight: 190)
        .shadow(color: palette.foreground.opacity(0.10), radius: 10)
    }

    @ViewBuilder private var controls: some View {
        HStack(spacing: 10) {
            if game == .snake {
                pixelButton("←") { setSnakeDirection(.left) }
                pixelButton("↑") { setSnakeDirection(.up) }
                pixelButton("↓") { setSnakeDirection(.down) }
                pixelButton("→") { setSnakeDirection(.right) }
                Spacer()
                Text("ARROWS / WASD")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.foreground.opacity(0.52))
            } else {
                pixelButton("▲") { movePongPlayer(-0.09) }
                pixelButton("▼") { movePongPlayer(0.09) }
                Spacer()
                Text("W/S  ·  ↑/↓")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.foreground.opacity(0.52))
            }
            pixelButton("RST") { resetCurrentGame() }
        }
    }

    private func pixelButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(palette.foreground)
                .padding(.horizontal, 9)
                .frame(height: 25)
                .background(palette.foreground.opacity(0.08))
                .overlay(Rectangle().stroke(palette.foreground.opacity(0.38), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var scoreText: String {
        switch game {
        case .snake: return "SCORE \(String(format: "%03d", snakeScore))  HI \(String(format: "%03d", snakeHighScore))"
        case .pong: return "YOU \(pongPlayerScore) : \(pongCPUScore) CPU"
        }
    }

    private func drawInactivePixels(context: GraphicsContext, size: CGSize) {
        let columns = game == .snake ? snakeColumns : 48
        let rows = game == .snake ? snakeRows : 20
        let cell = floor(min(size.width / CGFloat(columns), size.height / CGFloat(rows)))
        guard cell >= 2 else { return }
        let boardWidth = cell * CGFloat(columns)
        let boardHeight = cell * CGFloat(rows)
        let originX = floor((size.width - boardWidth) / 2)
        let originY = floor((size.height - boardHeight) / 2)
        let inset = max(0.55, cell * 0.12)
        for y in 0..<rows {
            for x in 0..<columns {
                var path = Path()
                path.addRect(CGRect(x: originX + CGFloat(x) * cell + inset,
                                    y: originY + CGFloat(y) * cell + inset,
                                    width: max(0.8, cell - inset * 2),
                                    height: max(0.8, cell - inset * 2)))
                context.fill(path, with: .color(palette.foreground.opacity(0.055)))
            }
        }
    }

    private func drawSnake(context: GraphicsContext, size: CGSize) {
        let cell = floor(min(size.width / CGFloat(snakeColumns), size.height / CGFloat(snakeRows)))
        let boardWidth = cell * CGFloat(snakeColumns)
        let boardHeight = cell * CGFloat(snakeRows)
        let originX = floor((size.width - boardWidth) / 2)
        let originY = floor((size.height - boardHeight) / 2)
        for (index, segment) in snake.enumerated() {
            let rect = CGRect(x: originX + CGFloat(segment.x) * cell + 1,
                              y: originY + CGFloat(segment.y) * cell + 1,
                              width: max(1, cell - 2), height: max(1, cell - 2))
            var path = Path()
            path.addRect(rect)
            context.fill(path, with: .color(palette.foreground.opacity(index == 0 ? 1 : 0.78)))
        }
        let foodRect = CGRect(x: originX + CGFloat(food.x) * cell + 1,
                              y: originY + CGFloat(food.y) * cell + 1,
                              width: max(1, cell - 2), height: max(1, cell - 2))
        var foodPath = Path()
        foodPath.addRect(foodRect)
        context.fill(foodPath, with: .color(palette.foreground))
        let center = CGPoint(x: foodRect.midX, y: foodRect.midY)
        var glint = Path()
        glint.addEllipse(in: CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4))
        context.fill(glint, with: .color(.white.opacity(0.65)))
    }

    private func drawPong(context: GraphicsContext, size: CGSize) {
        let fg = palette.foreground
        let paddleWidth = max(4, floor(size.width * 0.012))
        let paddleHeight = max(28, floor(size.height * 0.26))
        let player = CGRect(x: floor(size.width * 0.07), y: floor(pongPlayerY * size.height - paddleHeight / 2), width: paddleWidth, height: paddleHeight)
        let cpu = CGRect(x: floor(size.width * 0.93 - paddleWidth), y: floor(pongCPUY * size.height - paddleHeight / 2), width: paddleWidth, height: paddleHeight)
        let ballSize = max(5, floor(min(size.width, size.height) * 0.035))
        let ball = CGRect(x: floor(pongBall.x * size.width - ballSize / 2), y: floor(pongBall.y * size.height - ballSize / 2), width: ballSize, height: ballSize)
        var playerPath = Path(); playerPath.addRect(player)
        var cpuPath = Path(); cpuPath.addRect(cpu)
        var ballPath = Path(); ballPath.addRect(ball)
        context.fill(playerPath, with: .color(fg))
        context.fill(cpuPath, with: .color(fg))
        context.fill(ballPath, with: .color(fg))
        var y: CGFloat = 12
        while y < size.height - 8 {
            var divider = Path()
            divider.addRect(CGRect(x: floor(size.width / 2), y: y, width: 2, height: 8))
            context.fill(divider, with: .color(fg.opacity(0.28)))
            y += 15
        }
    }

    private func tick() {
        tickCount &+= 1
        switch game {
        case .snake:
            if tickCount % 4 == 0 { stepSnake() }
        case .pong:
            stepPong()
        }
    }

    private func stepSnake() {
        snakeDirection = pendingSnakeDirection
        guard let head = snake.first else { resetSnake(); return }
        var next = head
        switch snakeDirection {
        case .up: next.y -= 1
        case .down: next.y += 1
        case .left: next.x -= 1
        case .right: next.x += 1
        }

        // The current tail is removed on a normal movement tick. Moving into that outgoing tail
        // cell is legal; checking the entire snake made that look like a random game restart.
        let occupiedAfterTailMoves = snake.dropLast()
        guard next.x >= 0, next.x < snakeColumns,
              next.y >= 0, next.y < snakeRows,
              !occupiedAfterTailMoves.contains(next) else {
            snakeHighScore = max(snakeHighScore, snakeScore)
            resetSnake()
            return
        }
        snake.insert(next, at: 0)
        if next == food {
            snakeScore += 1
            placeFood()
        } else {
            snake.removeLast()
        }
    }

    private func setSnakeDirection(_ next: RetroSnakeDirection) {
        let opposite = (snakeDirection == .up && next == .down) ||
            (snakeDirection == .down && next == .up) ||
            (snakeDirection == .left && next == .right) ||
            (snakeDirection == .right && next == .left)
        if !opposite { pendingSnakeDirection = next }
    }

    private func placeFood() {
        for _ in 0..<80 {
            let candidate = RetroPixelCell(x: Int.random(in: 1..<(snakeColumns - 1)), y: Int.random(in: 1..<(snakeRows - 1)))
            if !snake.contains(candidate) { food = candidate; return }
        }
        food = RetroPixelCell(x: snakeColumns - 3, y: snakeRows / 2)
    }

    private func resetSnake() {
        snake = [RetroPixelCell(x: 8, y: 6), RetroPixelCell(x: 7, y: 6), RetroPixelCell(x: 6, y: 6)]
        snakeDirection = .right
        pendingSnakeDirection = .right
        snakeScore = 0
        placeFood()
    }

    private func stepPong() {
        pongBall.x += pongVelocity.dx
        pongBall.y += pongVelocity.dy
        if pongBall.y <= 0.05 && pongVelocity.dy < 0 { pongBall.y = 0.05; pongVelocity.dy *= -1 }
        if pongBall.y >= 0.95 && pongVelocity.dy > 0 { pongBall.y = 0.95; pongVelocity.dy *= -1 }
        pongCPUY += (pongBall.y - pongCPUY) * 0.075
        pongCPUY = min(0.86, max(0.14, pongCPUY))

        if pongBall.x <= 0.105 && pongVelocity.dx < 0 && abs(pongBall.y - pongPlayerY) < 0.16 {
            pongBall.x = 0.105
            pongVelocity.dx = abs(pongVelocity.dx) * 1.015
            pongVelocity.dy += (pongBall.y - pongPlayerY) * 0.012
        }
        if pongBall.x >= 0.895 && pongVelocity.dx > 0 && abs(pongBall.y - pongCPUY) < 0.16 {
            pongBall.x = 0.895
            pongVelocity.dx = -abs(pongVelocity.dx) * 1.012
            pongVelocity.dy += (pongBall.y - pongCPUY) * 0.010
        }
        if pongBall.x < -0.02 { pongCPUScore += 1; resetPongBall(towardPlayer: false) }
        if pongBall.x > 1.02 { pongPlayerScore += 1; resetPongBall(towardPlayer: true) }
    }

    private func movePongPlayer(_ amount: CGFloat) {
        pongPlayerY = min(0.86, max(0.14, pongPlayerY + amount))
    }

    private func resetPongBall(towardPlayer: Bool) {
        pongBall = CGPoint(x: 0.5, y: 0.5)
        pongVelocity = CGVector(dx: towardPlayer ? -0.012 : 0.012, dy: Bool.random() ? 0.010 : -0.010)
    }

    private func resetPong() {
        pongPlayerY = 0.5
        pongCPUY = 0.5
        pongPlayerScore = 0
        pongCPUScore = 0
        resetPongBall(towardPlayer: Bool.random())
    }

    private func resetCurrentGame() {
        tickCount = 0
        switch game {
        case .snake: resetSnake()
        case .pong: resetPong()
        }
    }

    private func installKeyMonitors() {
        if keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                handleKey(event.keyCode) ? nil : event
            }
        }
        if globalKeyMonitor == nil {
            globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
                let code = event.keyCode
                Task { @MainActor in _ = handleKey(code) }
            }
        }
    }

    private func removeKeyMonitors() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor); self.keyMonitor = nil }
        if let globalKeyMonitor { NSEvent.removeMonitor(globalKeyMonitor); self.globalKeyMonitor = nil }
    }

    @discardableResult
    private func handleKey(_ code: UInt16) -> Bool {
        switch game {
        case .snake:
            switch code {
            case 126, 13: setSnakeDirection(.up)
            case 125, 1: setSnakeDirection(.down)
            case 123, 0: setSnakeDirection(.left)
            case 124, 2: setSnakeDirection(.right)
            case 15: resetSnake()
            default: return false
            }
        case .pong:
            switch code {
            case 126, 13: movePongPlayer(-0.08)
            case 125, 1: movePongPlayer(0.08)
            case 15: resetPong()
            default: return false
            }
        }
        return true
    }

    private func publishPreferredSize() {
        let next = CGSize(width: 560, height: 330)
        DispatchQueue.main.async { [surfaceState] in
            if let current = surfaceState.contextPreferredSize,
               abs(current.width - next.width) < 1, abs(current.height - next.height) < 1 { return }
            surfaceState.contextPreferredSize = next
        }
    }
}
