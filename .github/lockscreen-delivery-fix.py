from pathlib import Path

path = Path('Halo/NotchEngine/WindowManager.swift')
text = path.read_text()

old = '''        refreshLockScreenPresenceIfNeeded(force: true)\n\n        for host in hosts.values {'''
new = '''        // Defer the first Lock Screen card to the notification daemon. An immediate\n        // request can be delivered during the desktop -> secure-session handoff, before\n        // the Lock Screen is actually presenting notifications.\n        refreshLockScreenPresenceIfNeeded(force: true, deliveryDelay: 1.0)\n\n        for host in hosts.values {'''
if old not in text:
    raise SystemExit('initial delivery anchor not found')
text = text.replace(old, new, 1)

old = '''    private func refreshLockScreenPresenceIfNeeded(force: Bool = false, preview: Bool = false) {\n        let preferences = LockScreenPresencePreferences.current()\n        guard preferences.enabled else {\n            clearLockScreenPresence()\n            return\n        }\n        guard preview || lockScreenSessionSuspended else { return }\n\n        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in\n            let authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional\n            guard authorized else { return }\n            Task { @MainActor [weak self] in\n                self?.deliverLockScreenPresence(preferences: preferences, force: force, preview: preview)\n            }\n        }\n    }\n\n    private func deliverLockScreenPresence(\n        preferences: LockScreenPresencePreferences,\n        force: Bool,\n        preview: Bool\n    ) {'''
new = '''    private func refreshLockScreenPresenceIfNeeded(\n        force: Bool = false,\n        preview: Bool = false,\n        deliveryDelay: TimeInterval = 0\n    ) {\n        let preferences = LockScreenPresencePreferences.current()\n        guard preferences.enabled else {\n            clearLockScreenPresence()\n            return\n        }\n        guard preview || lockScreenSessionSuspended else { return }\n\n        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in\n            let authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional\n            let lockScreenAllowed = settings.lockScreenSetting == .enabled\n            guard authorized, preview || lockScreenAllowed else { return }\n            Task { @MainActor [weak self] in\n                self?.deliverLockScreenPresence(\n                    preferences: preferences,\n                    force: force,\n                    preview: preview,\n                    deliveryDelay: deliveryDelay\n                )\n            }\n        }\n    }\n\n    private func deliverLockScreenPresence(\n        preferences: LockScreenPresencePreferences,\n        force: Bool,\n        preview: Bool,\n        deliveryDelay: TimeInterval\n    ) {'''
if old not in text:
    raise SystemExit('delivery function anchor not found')
text = text.replace(old, new, 1)

old = '''        center.add(UNNotificationRequest(\n            identifier: Self.lockScreenPresenceNotificationID,\n            content: content,\n            trigger: nil\n        ))'''
new = '''        let trigger: UNNotificationTrigger?\n        if deliveryDelay > 0 {\n            trigger = UNTimeIntervalNotificationTrigger(\n                timeInterval: max(0.1, deliveryDelay),\n                repeats: false\n            )\n        } else {\n            trigger = nil\n        }\n        center.add(UNNotificationRequest(\n            identifier: Self.lockScreenPresenceNotificationID,\n            content: content,\n            trigger: trigger\n        ))'''
if old not in text:
    raise SystemExit('notification request anchor not found')
text = text.replace(old, new, 1)

path.write_text(text)
