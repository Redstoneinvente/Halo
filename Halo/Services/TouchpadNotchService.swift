import AppKit
import Combine

@MainActor
final class TouchpadNotchService: ObservableObject {
    static let shared = TouchpadNotchService()
    static let packageID = "com.halo.touchpad"
    @Published var settings: TouchpadNotchSettings {
        didSet {
            let normalized = settings.normalized()
            if settings != normalized { settings = normalized; return }
            if let data = try? JSONEncoder().encode(settings) { UserDefaults.standard.set(data, forKey: Self.key) }
            recognizer.reset()
            if settings.enabled != oldValue.enabled { sync() }
        }
    }
    @Published private(set) var recording = false
    @Published private(set) var inputAvailable = false
    @Published private(set) var status = "Touchpad Notch is off."
    @Published private(set) var liveX = 0.5
    @Published private(set) var liveY = 0.5
    @Published private(set) var pressure: Double?
    var notchIsOpen: (() -> Bool)?
    var toggleNotch: (() -> Void)?
    private static let key = "HaloTouchpadNotch.v1"
    private let input = TouchpadInput()
    private var recognizer = TouchpadNotchRecognizer()
    private var subscriptions = Set<AnyCancellable>()
    private var observers: [NSObjectProtocol] = []
    private var monitors: [Any] = []
    private var selectedContactID: Int32?
    private var lastFrameTime = 0.0
    private var touchingDevices = Set<UInt64>()
    private var spotRecorder = TouchpadSpotRecorder()
    private var recordingTimeout: Task<Void, Never>?
    private var asleep = false

    private init() {
        settings = (UserDefaults.standard.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(TouchpadNotchSettings.self, from: $0) } ?? .init()).normalized()
    }

    func start() {
        guard subscriptions.isEmpty else { return }
        HaloRuntimeGate.shared.$isReady.sink { [weak self] _ in
            Task { @MainActor in self?.sync() }
        }.store(in: &subscriptions)
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.asleep = true; self?.cancelRecording(); self?.sync() }
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.asleep = false; self?.sync() }
            })
        }
        sync()
    }

    func stop() {
        cancelRecording()
        input.stop()
        inputAvailable = false
        touchingDevices.removeAll()
        removeMonitors()
        subscriptions.removeAll()
        observers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        observers.removeAll()
    }

    func recordSpot() {
        guard settings.enabled, HaloRuntimeGate.shared.isReady, !asleep, inputAvailable else { return }
        recording = true
        spotRecorder = TouchpadSpotRecorder(touchingDevices: touchingDevices)
        recognizer.reset()
        status = "Lift all fingers, then hold one finger on the desired spot for one second."
        recordingTimeout?.cancel()
        recordingTimeout = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            guard !Task.isCancelled, let self else { return }
            self.cancelRecording()
            self.status = "Recording timed out. Check the touchpad connection and try again."
        }
    }

    func cancelRecording() {
        recordingTimeout?.cancel()
        recordingTimeout = nil
        recording = false
        spotRecorder = TouchpadSpotRecorder()
        recognizer.reset()
    }

    func sync() {
        cancelRecording()
        inputAvailable = false
        touchingDevices.removeAll()
        input.stop()
        removeMonitors()
        recognizer.reset()
        pressure = nil
        selectedContactID = nil
        guard settings.enabled, HaloRuntimeGate.shared.isReady, !asleep else {
            cancelRecording()
            status = settings.enabled ? "Touchpad monitoring is paused." : "Touchpad Notch is off."
            return
        }
        if let error = input.start({ [weak self] device, contacts, time in self?.frame(device: device, contacts: contacts, time: time) }) {
            status = error
            cancelRecording()
            return
        }
        inputAvailable = true
        let mask: NSEvent.EventTypeMask = [.pressure, .leftMouseUp, .rightMouseUp]
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            Task { @MainActor in self?.receivePressure(event) }
        }) { monitors.append(monitor) }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.receivePressure(event); return event
        }) { monitors.append(monitor) }
        status = settings.hasSpot ? "Ready. Touch and hold your saved spot." : "Record a spot to get started."
    }

    private func removeMonitors() { monitors.forEach(NSEvent.removeMonitor); monitors.removeAll() }
    private func receivePressure(_ event: NSEvent) {
        guard selectedContactID != nil else { pressure = nil; return }
        pressure = event.type == .pressure && event.stage == 1 ? Double(event.pressure) : nil
    }

    private func frame(device: UInt64, contacts: [TouchpadNotchRecognizer.Contact], time: Double) {
        guard settings.enabled, HaloRuntimeGate.shared.isReady, !asleep else { return }
        // Reject a backlog delivered after the app was busy; it must never trigger later.
        guard ProcessInfo.processInfo.systemUptime - time < 0.25 else { recognizer.reset(); return }
        if contacts.isEmpty { touchingDevices.remove(device) } else { touchingDevices.insert(device) }
        if recording {
            if contacts.count == 1, let contact = contacts.first {
                liveX = contact.x; liveY = contact.y
            }
            if let spot = spotRecorder.update(device: device, contacts: contacts, time: time) {
                cancelRecording()
                settings.x = spot.x; settings.y = spot.y
                settings.deviceID = spot.device; settings.hasSpot = true
                // Require a fresh touch after recording.
                _ = recognizer.update(contacts: contacts + contacts, pressure: nil, timestamp: time, isOpen: false, settings: settings)
                status = "Spot saved. Lift your finger before trying it."
                feedback()
            }
            return
        }
        guard device == settings.deviceID else { return }
        let nextContactID = contacts.count == 1 ? contacts.first?.id : nil
        if nextContactID != selectedContactID || time - lastFrameTime > 0.25 { pressure = nil }
        selectedContactID = nextContactID
        lastFrameTime = time
        let currentPressure = pressure
        let ci = HaloCustomCIRuntimeStore.shared
        let isOpen = settings.destination == .notch ? (notchIsOpen?() ?? false) : ci.manualActivationID == Self.packageID
        guard recognizer.update(contacts: contacts, pressure: currentPressure, timestamp: time, isOpen: isOpen, settings: settings) else { return }
        switch settings.destination {
        case .notch:
            toggleNotch?()
            feedback()
        case .touchpadCI:
            guard HaloFeatureAccess.shared.allows(.customCI), !UserDefaults.standard.bool(forKey: "HaloDisableCustomCI"),
                  ci.package(id: Self.packageID) != nil, ci.isEnabled(Self.packageID) else {
                status = "Install and enable Touchpad CI in these settings. It requires Halo Full and Custom CI enabled."
                return
            }
            if isOpen { ci.dismiss(Self.packageID) } else { ci.requestManualActivation(Self.packageID) }
            // The existing arbiter can decline the request; acknowledge only accepted state.
            if isOpen || ci.manualActivationID == Self.packageID { feedback() }
        }
    }

    private func feedback() {
        if settings.haptics { HaloHoverHaptics.pulse(id: "touchpad.notch", strength: 3, pattern: .single) }
    }

    func installCI() {
        guard let url = Bundle.main.url(forResource: "Touchpad", withExtension: "haloCI") else {
            status = "Touchpad CI is missing from this build."; return
        }
        HaloCustomCIRuntimeStore.shared.importPackage(from: url)
    }
}
