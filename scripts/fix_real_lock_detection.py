from pathlib import Path

path = Path('Halo/NotchEngine/WindowManager.swift')
s = path.read_text()

# 1) Add a notification delegate that explicitly presents Halo's after-unlock summary
# even when Halo is the foreground app after unlocking.
anchor = '''@MainActor
final class WindowManager {
'''
delegate = '''private final class HaloAfterUnlockNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = HaloAfterUnlockNotificationDelegate()
    private let summaryIdentifier = "com.redstoneinvente.halo.lock-screen-presence"

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.identifier == summaryIdentifier {
            completionHandler([.banner, .list])
        } else {
            completionHandler([])
        }
    }
}

@MainActor
final class WindowManager {
'''
if s.count(anchor) != 1:
    raise SystemExit(f'WindowManager anchor count: {s.count(anchor)}')
s = s.replace(anchor, delegate, 1)

# 2) Retain Direct-build distributed notification observer tokens.
state_anchor = '''    private var lockScreenPresenceRefreshWork: DispatchWorkItem?
'''
state_replacement = '''    private var lockScreenPresenceRefreshWork: DispatchWorkItem?
#if HALO_DIRECT
    private var lockScreenDistributedObservers: [NSObjectProtocol] = []
#endif
'''
if s.count(state_anchor) != 1:
    raise SystemExit(f'lockScreenPresenceRefreshWork anchor count: {s.count(state_anchor)}')
s = s.replace(state_anchor, state_replacement, 1)

# 3) Install notification presentation delegate when WindowManager starts.
start_anchor = '''    func start() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
'''
start_replacement = '''    func start() {
        UNUserNotificationCenter.current().delegate = HaloAfterUnlockNotificationDelegate.shared

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
'''
if s.count(start_anchor) != 1:
    raise SystemExit(f'start anchor count: {s.count(start_anchor)}')
s = s.replace(start_anchor, start_replacement, 1)

# 4) Replace the old session-only lock detection wiring with layered detection.
old = '''        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.sessionDidResignActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.handleLockScreenSessionResigned() }
            .store(in: &subscriptions)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.sessionDidBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.handleLockScreenSessionBecameActive() }
            .store(in: &subscriptions)
'''
new = '''        // Public session-switch notifications remain useful for Fast User Switching.
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.sessionDidResignActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.handleLockScreenSessionResigned(source: "session-resigned") }
            .store(in: &subscriptions)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.sessionDidBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.handleLockScreenSessionBecameActive(source: "session-active") }
            .store(in: &subscriptions)

        // Public sleep/wake fallback works in both distributions.
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.handleLockScreenSessionResigned(source: "sleep") }
            .store(in: &subscriptions)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.handleLockScreenSessionBecameActive(source: "wake") }
            .store(in: &subscriptions)

#if HALO_DIRECT
        // macOS does not expose a documented NSWorkspace notification for a manual Lock Screen.
        // Direct Halo can observe the long-established distributed screen lock notifications.
        // Keep this out of HALO_APPSTORE builds.
        let distributed = DistributedNotificationCenter.default()
        lockScreenDistributedObservers.append(
            distributed.addObserver(
                forName: Notification.Name("com.apple.screenIsLocked"),
                object: nil,
                suspensionBehavior: .deliverImmediately,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleLockScreenSessionResigned(source: "screen-locked")
                }
            }
        )
        lockScreenDistributedObservers.append(
            distributed.addObserver(
                forName: Notification.Name("com.apple.screenIsUnlocked"),
                object: nil,
                suspensionBehavior: .deliverImmediately,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleLockScreenSessionBecameActive(source: "screen-unlocked")
                }
            }
        )
#endif
'''
if s.count(old) != 1:
    raise SystemExit(f'old lock subscriptions count: {s.count(old)}')
s = s.replace(old, new, 1)

# 5) Add source-aware diagnostics to lock/unlock handlers.
s = s.replace(
    '    private func handleLockScreenSessionResigned() {\n        guard !lockScreenSessionSuspended else { return }\n',
    '    private func handleLockScreenSessionResigned(source: String = "unknown") {\n        guard !lockScreenSessionSuspended else { return }\n        NSLog("[Halo Lock] lock detected via %@", source)\n',
    1,
)
s = s.replace(
    '    private func handleLockScreenSessionBecameActive() {\n        guard lockScreenSessionSuspended else { return }\n',
    '    private func handleLockScreenSessionBecameActive(source: String = "unknown") {\n        guard lockScreenSessionSuspended else { return }\n        NSLog("[Halo Lock] unlock detected via %@", source)\n',
    1,
)

# 6) Report authorization state instead of silently returning.
auth_old = '''            let authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            guard authorized else { return }
'''
auth_new = '''            let authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            guard authorized else {
                NSLog("[Halo Lock] summary skipped: notification authorization status = %ld", settings.authorizationStatus.rawValue)
                return
            }
'''
if s.count(auth_old) != 1:
    raise SystemExit(f'authorization anchor count: {s.count(auth_old)}')
s = s.replace(auth_old, auth_new, 1)

# 7) Capture UNUserNotificationCenter.add errors and success.
add_old = '''        center.add(UNNotificationRequest(
            identifier: Self.lockScreenPresenceNotificationID,
            content: content,
            trigger: trigger
        ))
'''
add_new = '''        let request = UNNotificationRequest(
            identifier: Self.lockScreenPresenceNotificationID,
            content: content,
            trigger: trigger
        )
        center.add(request) { error in
            if let error {
                NSLog("[Halo Lock] summary notification failed: %@", error.localizedDescription)
            } else {
                NSLog("[Halo Lock] summary notification accepted (%@)", card.kind)
            }
        }
'''
if s.count(add_old) != 1:
    raise SystemExit(f'notification add anchor count: {s.count(add_old)}')
s = s.replace(add_old, add_new, 1)

path.write_text(s)

# Sanity assertions
out = path.read_text()
assert 'com.apple.screenIsLocked' in out
assert 'com.apple.screenIsUnlocked' in out
assert '#if HALO_DIRECT' in out
assert 'HaloAfterUnlockNotificationDelegate.shared' in out
assert 'summary notification failed' in out
assert 'lock detected via' in out
