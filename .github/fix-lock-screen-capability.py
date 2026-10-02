from pathlib import Path
import re

settings_path = Path('Halo/Views/WorkspaceSettingsView.swift')
settings = settings_path.read_text()

old_subtitle = 'section == "Lock Screen" ? "How Halo behaves when your Mac is locked"'
new_subtitle = 'section == "Lock Screen" ? "Customize locking, unlocking, and the after-unlock summary"'
if settings.count(old_subtitle) != 1:
    raise SystemExit(f'Lock Screen subtitle anchor count: {settings.count(old_subtitle)}')
settings = settings.replace(old_subtitle, new_subtitle, 1)

section_pattern = re.compile(
    r'            Section\("Lock Screen Presence"\) \{.*?\n            Section\("When locking"\) \{',
    re.S,
)
section_replacement = '''            Section("After Unlock Summary") {
                Toggle("Show a Halo summary after unlocking", isOn: $presenceEnabled)
                    .onChange(of: presenceEnabled) { enabled in
                        if enabled { workspace.enableNotifications() }
                    }

                if presenceEnabled {
                    Picker("Priority", selection: $presencePriority) {
                        Text("Music first").tag("music")
                        Text("Timer first").tag("timer")
                        Text("Live Activities first").tag("activity")
                        Text("Stopwatch first").tag("stopwatch")
                    }

                    Toggle("Now Playing", isOn: $presenceMusic)
                    if presenceMusic {
                        Picker("Media privacy", selection: $presenceMediaPrivacy) {
                            Text("Full details").tag("details")
                            Text("Track title only").tag("title")
                            Text("Hide track details").tag("hidden")
                        }
                        Toggle("Album artwork", isOn: $presenceArtwork)
                    }

                    Toggle("Active timer", isOn: $presenceTimer)
                    Toggle("Stopwatch", isOn: $presenceStopwatch)
                    Toggle("Live Activities", isOn: $presenceActivities)

                    Button("Preview summary notification") {
                        workspace.enableNotifications()
                        NotificationCenter.default.post(name: .init("HaloPreviewLockScreenPresence"), object: nil)
                    }
                }

                Text("macOS keeps the secure Lock Screen system-owned, so Halo cannot place custom notch UI there. Instead, Halo can surface the most relevant music, timer, stopwatch, or Live Activity context immediately after you unlock.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("When locking") {'''
settings, count = section_pattern.subn(section_replacement, settings, count=1)
if count != 1:
    raise SystemExit(f'Lock Screen presence section replacement count: {count}')
settings_path.write_text(settings)

runtime_path = Path('Halo/NotchEngine/WindowManager.swift')
runtime = runtime_path.read_text()

ready_state = '    private var lockScreenPresenceReadyAt = Date.distantPast\n'
if runtime.count(ready_state) != 1:
    raise SystemExit(f'presence ready state count: {runtime.count(ready_state)}')
runtime = runtime.replace(ready_state, '', 1)

handoff_pattern = re.compile(
    r'        // Keep every notification refresh out of the desktop -> secure-session handoff\.\n'
    r'        // The notification daemon can then present it after the Lock Screen is actually visible\.\n'
    r'        lockScreenPresenceReadyAt = Date\(\)\.addingTimeInterval\(1\.0\)\n'
)
runtime, count = handoff_pattern.subn('', runtime, count=1)
if count != 1:
    raise SystemExit(f'secure-session handoff removal count: {count}')

lock_refresh = '        refreshLockScreenPresenceIfNeeded(force: true)\n'
if runtime.count(lock_refresh) != 1:
    raise SystemExit(f'lock refresh anchor count: {runtime.count(lock_refresh)}')
runtime = runtime.replace(lock_refresh, '', 1)

active_ready = '        lockScreenPresenceReadyAt = .distantPast\n'
if runtime.count(active_ready) != 1:
    raise SystemExit(f'active ready anchor count: {runtime.count(active_ready)}')
runtime = runtime.replace(active_ready, '', 1)

schedule_pattern = re.compile(
    r'    private func scheduleLockScreenPresenceRefresh\(\) \{.*?\n    \}\n\n'
    r'    private func refreshLockScreenPresenceIfNeeded\(force: Bool = false, preview: Bool = false\) \{.*?\n    \}\n\n'
    r'    private func deliverLockScreenPresence\(',
    re.S,
)
helper_replacement = '''    private func scheduleLockScreenPresenceRefresh() {
        // The secure Lock Screen is system-owned. Context changes while locked are
        // intentionally sampled only once Halo regains the session after unlock.
        lockScreenPresenceRefreshWork?.cancel()
        lockScreenPresenceRefreshWork = nil
    }

    private func refreshLockScreenPresenceIfNeeded(
        force: Bool = false,
        preview: Bool = false,
        allowUnlocked: Bool = false
    ) {
        let preferences = LockScreenPresencePreferences.current()
        guard preferences.enabled else {
            clearLockScreenPresence()
            return
        }
        guard preview || allowUnlocked else { return }

        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            guard authorized else { return }
            Task { @MainActor [weak self] in
                self?.deliverLockScreenPresence(
                    preferences: preferences,
                    force: force,
                    preview: preview,
                    deliveryDelay: 0
                )
            }
        }
    }

    private func deliverLockScreenPresence('''
runtime, count = schedule_pattern.subn(helper_replacement, runtime, count=1)
if count != 1:
    raise SystemExit(f'presence helper replacement count: {count}')

unlock_anchor = '''        let shouldRunActivation = preferences.runActivationSequence || pendingWakeActivation
        pendingWakeActivation = false
        lockScreenExpandedSnapshot.removeAll()
        guard shouldRunActivation else { return }
'''
unlock_replacement = '''        let shouldRunActivation = preferences.runActivationSequence || pendingWakeActivation
        pendingWakeActivation = false
        lockScreenExpandedSnapshot.removeAll()

        let summaryDelay = max(0.25, preferences.unlockDuration + 0.1)
        DispatchQueue.main.asyncAfter(deadline: .now() + summaryDelay) { [weak self] in
            self?.refreshLockScreenPresenceIfNeeded(force: true, allowUnlocked: true)
        }

        guard shouldRunActivation else { return }
'''
if runtime.count(unlock_anchor) != 1:
    raise SystemExit(f'unlock summary anchor count: {runtime.count(unlock_anchor)}')
runtime = runtime.replace(unlock_anchor, unlock_replacement, 1)

preview_old = '''        return LockScreenPresenceCard(
            kind: "preview",
            title: "Halo Lock Screen",
            subtitle: "Contextual presence",
            body: "Start music, a timer, a stopwatch, or a Live Activity and Halo will surface the highest-priority context here.",
            artwork: nil
        )'''
preview_new = '''        return LockScreenPresenceCard(
            kind: "preview",
            title: "Halo Summary",
            subtitle: "After Unlock",
            body: "Start music, a timer, a stopwatch, or a Live Activity and Halo will surface the highest-priority context after you unlock.",
            artwork: nil
        )'''
if runtime.count(preview_old) != 1:
    raise SystemExit(f'preview copy anchor count: {runtime.count(preview_old)}')
runtime = runtime.replace(preview_old, preview_new, 1)

thread_old = 'content.threadIdentifier = "halo.lock-screen-presence"'
thread_new = 'content.threadIdentifier = "halo.after-unlock-summary"'
if runtime.count(thread_old) != 1:
    raise SystemExit(f'thread identifier count: {runtime.count(thread_old)}')
runtime = runtime.replace(thread_old, thread_new, 1)

category_old = 'content.categoryIdentifier = "HALO_LOCK_SCREEN_PRESENCE"'
category_new = 'content.categoryIdentifier = "HALO_AFTER_UNLOCK_SUMMARY"'
if runtime.count(category_old) != 1:
    raise SystemExit(f'category identifier count: {runtime.count(category_old)}')
runtime = runtime.replace(category_old, category_new, 1)

runtime_path.write_text(runtime)

# Semantic guards
settings = settings_path.read_text()
runtime = runtime_path.read_text()
assert 'Section("Lock Screen Presence")' not in settings
assert 'Toggle("Show Halo status on the Lock Screen"' not in settings
assert 'Section("After Unlock Summary")' in settings
assert 'Toggle("Show a Halo summary after unlocking"' in settings
assert 'allowUnlocked: Bool = false' in runtime
assert 'allowUnlocked: true' in runtime
assert 'settings.lockScreenSetting' not in runtime
assert 'lockScreenPresenceReadyAt' not in runtime
