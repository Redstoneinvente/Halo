import Foundation
#if HALO_DIRECT
import Darwin

// System-framework ABI only; no package-provided native code is loaded. This private API
// is excluded from App Store builds. Keep density/size separate from real force events.
private struct MTPoint { var x: Float; var y: Float }
private struct MTVector { var position: MTPoint; var velocity: MTPoint }
private struct MTContact {
    var frame: Int32
    var timestamp: Double
    var identifier: Int32
    var state: Int32
    var fingerID: Int32
    var handID: Int32
    var normalized: MTVector
    var size: Float
    var unused1: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var absolute: MTVector
    var unused2: Int32
    var unused3: Int32
    var density: Float
}
private typealias MTCallback = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
private let touchpadFrameCallback: MTCallback = { device, data, count, _, _ in
    guard let device, count >= 0, count <= 32, count == 0 || data != nil else { return 0 }
    let buffer = data?.assumingMemoryBound(to: MTContact.self)
    var contacts: [TouchpadNotchRecognizer.Contact] = []
    for index in 0..<Int(count) {
        guard let value = buffer?[index], value.state == 4 else { continue }
        contacts.append(.init(id: value.identifier, x: Double(value.normalized.position.x), y: Double(value.normalized.position.y)))
    }
    TouchpadInput.delivery.send(device: UInt(bitPattern: device), contacts: contacts)
    return 0
}

/// Serializes the callback lifetime and copies only bounded coordinates across threads.
private final class TouchpadDelivery: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: (@Sendable (UInt, [TouchpadNotchRecognizer.Contact], Double) -> Void)?
    func set(_ handler: (@Sendable (UInt, [TouchpadNotchRecognizer.Contact], Double) -> Void)?) {
        lock.lock(); defer { lock.unlock() }; self.handler = handler
    }
    func send(device: UInt, contacts: [TouchpadNotchRecognizer.Contact]) {
        lock.lock(); let handler = handler; lock.unlock()
        handler?(device, contacts, ProcessInfo.processInfo.systemUptime)
    }
}
#endif

@MainActor
final class TouchpadInput {
#if HALO_DIRECT
    nonisolated fileprivate static let delivery = TouchpadDelivery()
    private typealias Create = @convention(c) () -> Unmanaged<CFArray>?
    private typealias Register = @convention(c) (UnsafeMutableRawPointer, MTCallback) -> Void
    private typealias Start = @convention(c) (UnsafeMutableRawPointer, Int32) -> Int32
    private typealias Stop = @convention(c) (UnsafeMutableRawPointer) -> Int32
    private typealias DeviceID = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<UInt64>) -> Int32
    private typealias Opaque = @convention(c) (UnsafeMutableRawPointer) -> Bool
    private var library: UnsafeMutableRawPointer?
    private var deviceList: CFArray?
    private var devices: [UnsafeMutableRawPointer] = []
    private var unregister: Register?
    private var stopDevice: Stop?
    private var generation = UUID()
#endif
    func start(_ handler: @escaping @MainActor (UInt64, [TouchpadNotchRecognizer.Contact], Double) -> Void) -> String? {
#if HALO_DIRECT
        stop()
        guard MemoryLayout<MTContact>.stride == 96 else { return "Unsupported touchpad data format." }
        // Retain the system library for the process lifetime: late OS callbacks must never
        // jump into an unloaded framework after monitoring stops.
        if library == nil { library = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW | RTLD_LOCAL) }
        guard let library else { return "Touchpad monitoring is unavailable on this Mac." }
        func symbol<T>(_ name: String, _: T.Type) -> T? {
            guard let value = dlsym(library, name) else { return nil }
            return unsafeBitCast(value, to: T.self)
        }
        guard let create = symbol("MTDeviceCreateList", Create.self),
              let register = symbol("MTRegisterContactFrameCallback", Register.self),
              let unregister = symbol("MTUnregisterContactFrameCallback", Register.self),
              let start = symbol("MTDeviceStart", Start.self),
              let stop = symbol("MTDeviceStop", Stop.self),
              let deviceID = symbol("MTDeviceGetDeviceID", DeviceID.self),
              let opaque = symbol("MTDeviceIsOpaqueSurface", Opaque.self),
              let list = create()?.takeRetainedValue() else { return "This macOS version does not support touchpad monitoring." }
        self.unregister = unregister
        stopDevice = stop
        deviceList = list
        var ids: [UInt: UInt64] = [:]
        for index in 0..<CFArrayGetCount(list) {
            guard let raw = CFArrayGetValueAtIndex(list, index) else { continue }
            let device = UnsafeMutableRawPointer(mutating: raw)
            var id: UInt64 = 0
            guard opaque(device), deviceID(device, &id) == 0 else { continue }
            devices.append(device)
            ids[UInt(bitPattern: device)] = id
        }
        guard !devices.isEmpty else { deviceList = nil; return "No supported touchpad found. Connect one, then retry." }
        let token = generation
        let deviceIDs = ids
        Self.delivery.set { [weak self] device, contacts, time in
            Task { @MainActor in
                guard let self, self.generation == token, let id = deviceIDs[device] else { return }
                handler(id, contacts, time)
            }
        }
        for device in devices { register(device, touchpadFrameCallback); _ = start(device, 0) }
        return nil
#else
        return "Touchpad Notch requires the direct-download edition of Halo."
#endif
    }

    func stop() {
#if HALO_DIRECT
        generation = UUID()
        Self.delivery.set(nil)
        for device in devices { _ = stopDevice?(device); unregister?(device, touchpadFrameCallback) }
        devices.removeAll()
        deviceList = nil
#endif
    }
}
