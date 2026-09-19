import AppKit
import Combine
import CoreGraphics
import Foundation

/// Halo-owned keyboard shortcut registration for partner CIs. Partner manifests can request the
/// trigger, but only user-selected chords from CIConfigurationStore are ever registered.
@MainActor
final class IntegrationShortcutManager: ObservableObject {
    static let shared = IntegrationShortcutManager()

    @Published private(set) var conflicts: [String: String] = [:]

    private let runtime: IntegrationCIRuntime
    private var services: [String: HotkeyService] = [:]
    private var observers: [NSObjectProtocol] = []
    private var subscriptions = Set<AnyCancellable>()
    private var started = false

    init(runtime: IntegrationCIRuntime = .shared) {
        self.runtime = runtime
    }

    func start() {
        guard !started else { return }
        started = true
        for name in ["HaloIntegrationRegistrationsChanged", "HaloIntegrationConfigurationChanged"] {
            NotificationCenter.default.publisher(for: .init(name))
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.sync() }
                .store(in: &subscriptions)
        }
        sync()
    }

    func stop() {
        started = false
        subscriptions.removeAll()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        services.values.forEach { $0.stop() }
        services.removeAll()
        conflicts = [:]
    }

    func sync() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        services.values.forEach { $0.stop() }
        services.removeAll()

        var requests: [CIShortcutRequest] = []
        for registration in runtime.registrations {
            let config = runtime.configuration(for: registration)
            guard config.enabled else { continue }
            for trigger in registration.supportedTriggers where trigger.type == .keyboardShortcut && config.triggerEnabled(trigger.id) {
                guard let shortcut = config.triggers[trigger.id]?.keyboardShortcut,
                      let keyCode = shortcut.keyCode,
                      let modifiers = shortcut.modifiers else { continue }
                requests.append(
                    CIShortcutRequest(
                        ciID: registration.id,
                        triggerID: trigger.id,
                        chord: CIShortcutChord(keyCode: keyCode, modifiers: modifiers)
                    )
                )
            }
        }

        let plan = CIShortcutPlanner.plan(requests: requests)
        var nextConflicts = plan.conflicts
        for (index, request) in plan.accepted.enumerated() {
            let notification = Notification.Name("HaloIntegrationShortcut.\(request.id)")
            let service = HotkeyService(identifierID: UInt32(1000 + index), notificationName: notification)
            guard service.register(code: request.chord.keyCode, modifiers: request.chord.modifiers) else {
                nextConflicts[request.id] = "Shortcut is unavailable or already registered by another app/Halo feature."
                continue
            }
            services[request.id] = service
            let token = NotificationCenter.default.addObserver(forName: notification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.runtime.keyboardShortcutActivate(
                        ciID: request.ciID,
                        triggerID: request.triggerID,
                        displayID: Self.activeDisplayID()
                    )
                }
            }
            observers.append(token)
        }
        conflicts = nextConflicts
    }

    private static func activeDisplayID() -> String {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen,
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else {
            return screen?.localizedName ?? "main"
        }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
