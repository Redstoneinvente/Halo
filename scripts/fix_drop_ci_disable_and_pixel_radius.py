from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one match, found {count}")
    return text.replace(old, new, 1)


path = Path("Halo/NotchEngine/WindowManager.swift")
text = path.read_text()

text = replace_once(
    text,
    "        refreshLockScreenPresenceIfNeeded(force: true)\n",
    "        // Schedule the initial card after macOS has completed the desktop -> secure-session handoff.\n        // UNUserNotificationCenter owns the delayed request even if Halo is suspended meanwhile.\n        refreshLockScreenPresenceIfNeeded(force: true, deliveryDelay: 1.0)\n",
    "initial Lock Screen Presence delivery",
)

text = replace_once(
    text,
    '''    private func refreshLockScreenPresenceIfNeeded(force: Bool = false, preview: Bool = false) {\n        let preferences = LockScreenPresencePreferences.current()\n        guard preferences.enabled else {\n            clearLockScreenPresence()\n            return\n        }\n        guard preview || lockScreenSessionSuspended else { return }\n\n        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in\n            let authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional\n            guard authorized else { return }\n            Task { @MainActor [weak self] in\n                self?.deliverLockScreenPresence(preferences: preferences, force: force, preview: preview)\n            }\n        }\n    }\n\n    private func deliverLockScreenPresence(\n        preferences: LockScreenPresencePreferences,\n        force: Bool,\n        preview: Bool\n    ) {''',
    '''    private func refreshLockScreenPresenceIfNeeded(\n        force: Bool = false,\n        preview: Bool = false,\n        deliveryDelay: TimeInterval = 0\n    ) {\n        let preferences = LockScreenPresencePreferences.current()\n        guard preferences.enabled else {\n            clearLockScreenPresence()\n            return\n        }\n        guard preview || lockScreenSessionSuspended else { return }\n\n        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in\n            let authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional\n            let lockScreenAllowed = settings.lockScreenSetting == .enabled\n            guard authorized, preview || lockScreenAllowed else { return }\n            Task { @MainActor [weak self] in\n                self?.deliverLockScreenPresence(\n                    preferences: preferences,\n                    force: force,\n                    preview: preview,\n                    deliveryDelay: deliveryDelay\n                )\n            }\n        }\n    }\n\n    private func deliverLockScreenPresence(\n        preferences: LockScreenPresencePreferences,\n        force: Bool,\n        preview: Bool,\n        deliveryDelay: TimeInterval\n    ) {''',
    "Lock Screen Presence permission and delay flow",
)

text = replace_once(
    text,
    '''        center.add(UNNotificationRequest(\n            identifier: Self.lockScreenPresenceNotificationID,\n            content: content,\n            trigger: nil\n        ))''',
    '''        let trigger: UNNotificationTrigger?\n        if deliveryDelay > 0 {\n            trigger = UNTimeIntervalNotificationTrigger(\n                timeInterval: max(0.1, deliveryDelay),\n                repeats: false\n            )\n        } else {\n            trigger = nil\n        }\n        center.add(UNNotificationRequest(\n            identifier: Self.lockScreenPresenceNotificationID,\n            content: content,\n            trigger: trigger\n        ))''',
    "Lock Screen Presence notification trigger",
)

path.write_text(text)
print("Patched Lock Screen Presence delivery timing and Lock Screen permission handling")
