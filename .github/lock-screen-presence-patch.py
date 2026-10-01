from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Missing patch anchor: {label}")
    return text.replace(old, new, 1)

wm_path = Path("Halo/NotchEngine/WindowManager.swift")
wm = wm_path.read_text()

if "import UserNotifications" not in wm:
    wm = replace_once(wm, "import QuartzCore\n", "import QuartzCore\nimport UserNotifications\n", "UserNotifications import")

if "lockScreenPresenceRefreshWork" not in wm:
    wm = replace_once(
        wm,
        "    private var pendingWakeActivation = false\n",
        "    private var pendingWakeActivation = false\n    private var lockScreenPresenceRefreshWork: DispatchWorkItem?\n    private var lastLockScreenPresenceSignature = \"\"\n",
        "presence runtime properties",
    )

if "HaloPreviewLockScreenPresence" not in wm:
    old = '''        NotificationCenter.default.publisher(for: .init("HaloPreviewLockScreenTransition"))
            .receive(on: RunLoop.main)
            .sink { [weak self] note in self?.previewLockScreenTransition(note) }
            .store(in: &subscriptions)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
'''
    new = '''        NotificationCenter.default.publisher(for: .init("HaloPreviewLockScreenTransition"))
            .receive(on: RunLoop.main)
            .sink { [weak self] note in self?.previewLockScreenTransition(note) }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: .init("HaloPreviewLockScreenPresence"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshLockScreenPresenceIfNeeded(force: true, preview: true) }
            .store(in: &subscriptions)
        store.workspace.media.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.scheduleLockScreenPresenceRefresh() }
            }
            .store(in: &subscriptions)
        store.$deadline
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.scheduleLockScreenPresenceRefresh() }
            .store(in: &subscriptions)
        store.$pausedSeconds
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.scheduleLockScreenPresenceRefresh() }
            .store(in: &subscriptions)
        store.workspace.$stopwatchStart
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.scheduleLockScreenPresenceRefresh() }
            .store(in: &subscriptions)
        store.workspace.$stopwatchElapsed
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.scheduleLockScreenPresenceRefresh() }
            .store(in: &subscriptions)
        store.workspace.$activities
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.scheduleLockScreenPresenceRefresh() }
            .store(in: &subscriptions)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
'''
    wm = replace_once(wm, old, new, "presence observers")

if "self.refreshLockScreenPresenceIfNeeded()" not in wm:
    old = '''                self.hosts.values.forEach { host in
                    host.refreshDropCIRegistration?()
                }
                // Closed-notch event and placement preferences also live in AppStorage/UserDefaults.
'''
    new = '''                self.hosts.values.forEach { host in
                    host.refreshDropCIRegistration?()
                }
                self.refreshLockScreenPresenceIfNeeded()
                // Closed-notch event and placement preferences also live in AppStorage/UserDefaults.
'''
    wm = replace_once(wm, old, new, "presence settings refresh")

if "refreshLockScreenPresenceIfNeeded(force: true)" not in wm:
    old = '''        playLockScreenFeedback(
            sound: preferences.lockSound,
            haptic: preferences.lockHaptic,
            id: "lockScreen.lock"
        )

        for host in hosts.values {
'''
    new = '''        playLockScreenFeedback(
            sound: preferences.lockSound,
            haptic: preferences.lockHaptic,
            id: "lockScreen.lock"
        )
        refreshLockScreenPresenceIfNeeded(force: true)

        for host in hosts.values {
'''
    wm = replace_once(wm, old, new, "presence on lock")

if "clearLockScreenPresence()\n        lockScreenUnlockWork?.cancel()" not in wm:
    old = '''        guard lockScreenSessionSuspended else { return }
        lockScreenSessionSuspended = false
        lockScreenUnlockWork?.cancel()
'''
    new = '''        guard lockScreenSessionSuspended else { return }
        lockScreenSessionSuspended = false
        clearLockScreenPresence()
        lockScreenUnlockWork?.cancel()
'''
    wm = replace_once(wm, old, new, "clear presence on unlock")

methods_anchor = "    private var closedNotchActivityPreferences: ClosedNotchActivityPreferences {\n"
if "private struct LockScreenPresencePreferences" not in wm:
    methods = r'''    private struct LockScreenPresencePreferences {
        var enabled: Bool
        var priority: String
        var showMusic: Bool
        var showTimer: Bool
        var showStopwatch: Bool
        var showActivities: Bool
        var showArtwork: Bool
        var mediaPrivacy: String

        static func current() -> LockScreenPresencePreferences {
            let defaults = UserDefaults.standard
            func bool(_ key: String, fallback: Bool) -> Bool {
                defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
            }
            return LockScreenPresencePreferences(
                enabled: bool("HaloLockScreenPresenceEnabled", fallback: false),
                priority: defaults.string(forKey: "HaloLockScreenPresencePriority") ?? "music",
                showMusic: bool("HaloLockScreenPresenceMusic", fallback: true),
                showTimer: bool("HaloLockScreenPresenceTimer", fallback: true),
                showStopwatch: bool("HaloLockScreenPresenceStopwatch", fallback: true),
                showActivities: bool("HaloLockScreenPresenceActivities", fallback: false),
                showArtwork: bool("HaloLockScreenPresenceArtwork", fallback: true),
                mediaPrivacy: defaults.string(forKey: "HaloLockScreenPresenceMediaPrivacy") ?? "details"
            )
        }
    }

    private struct LockScreenPresenceCard {
        var kind: String
        var title: String
        var subtitle: String
        var body: String
        var artwork: NSImage?

        var signature: String {
            [kind, title, subtitle, body, artwork == nil ? "no-art" : "art"].joined(separator: "|")
        }
    }

    private static let lockScreenPresenceNotificationID = "com.redstoneinvente.halo.lock-screen-presence"

    private func scheduleLockScreenPresenceRefresh() {
        guard lockScreenSessionSuspended else { return }
        lockScreenPresenceRefreshWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.refreshLockScreenPresenceIfNeeded()
        }
        lockScreenPresenceRefreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func refreshLockScreenPresenceIfNeeded(force: Bool = false, preview: Bool = false) {
        let preferences = LockScreenPresencePreferences.current()
        guard preferences.enabled else {
            clearLockScreenPresence()
            return
        }
        guard preview || lockScreenSessionSuspended else { return }

        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            guard authorized else { return }
            Task { @MainActor [weak self] in
                self?.deliverLockScreenPresence(preferences: preferences, force: force, preview: preview)
            }
        }
    }

    private func deliverLockScreenPresence(
        preferences: LockScreenPresencePreferences,
        force: Bool,
        preview: Bool
    ) {
        guard let card = lockScreenPresenceCard(preferences: preferences, preview: preview) else {
            clearLockScreenPresence()
            return
        }
        guard force || card.signature != lastLockScreenPresenceSignature else { return }
        lastLockScreenPresenceSignature = card.signature

        let content = UNMutableNotificationContent()
        content.title = card.title
        content.subtitle = card.subtitle
        content.body = card.body
        content.threadIdentifier = "halo.lock-screen-presence"
        content.categoryIdentifier = "HALO_LOCK_SCREEN_PRESENCE"
        if preferences.showArtwork, let artwork = card.artwork,
           let attachment = lockScreenPresenceArtworkAttachment(artwork) {
            content.attachments = [attachment]
        }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.lockScreenPresenceNotificationID])
        center.removeDeliveredNotifications(withIdentifiers: [Self.lockScreenPresenceNotificationID])
        center.add(UNNotificationRequest(
            identifier: Self.lockScreenPresenceNotificationID,
            content: content,
            trigger: nil
        ))
    }

    private func clearLockScreenPresence() {
        lockScreenPresenceRefreshWork?.cancel()
        lockScreenPresenceRefreshWork = nil
        lastLockScreenPresenceSignature = ""
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.lockScreenPresenceNotificationID])
        center.removeDeliveredNotifications(withIdentifiers: [Self.lockScreenPresenceNotificationID])
    }

    private func lockScreenPresenceCard(
        preferences: LockScreenPresencePreferences,
        preview: Bool
    ) -> LockScreenPresenceCard? {
        let music = lockScreenMusicCard(preferences)
        let timer = lockScreenTimerCard(preferences)
        let stopwatch = lockScreenStopwatchCard(preferences)
        let activity = lockScreenActivityCard(preferences)
        let cards: [String: LockScreenPresenceCard?] = [
            "music": music,
            "timer": timer,
            "stopwatch": stopwatch,
            "activity": activity
        ]
        let order: [String]
        switch preferences.priority {
        case "timer": order = ["timer", "music", "activity", "stopwatch"]
        case "activity": order = ["activity", "music", "timer", "stopwatch"]
        case "stopwatch": order = ["stopwatch", "music", "timer", "activity"]
        default: order = ["music", "timer", "activity", "stopwatch"]
        }
        for key in order {
            if let card = cards[key] ?? nil { return card }
        }
        guard preview else { return nil }
        return LockScreenPresenceCard(
            kind: "preview",
            title: "Halo Lock Screen",
            subtitle: "Contextual presence",
            body: "Start music, a timer, a stopwatch, or a Live Activity and Halo will surface the highest-priority context here.",
            artwork: nil
        )
    }

    private func lockScreenMusicCard(_ preferences: LockScreenPresencePreferences) -> LockScreenPresenceCard? {
        let media = store.workspace.media
        guard preferences.showMusic, media.isPlaying else { return nil }
        let track = media.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !track.isEmpty else { return nil }
        let artist = media.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let album = media.album.trimmingCharacters(in: .whitespacesAndNewlines)

        switch preferences.mediaPrivacy {
        case "hidden":
            return LockScreenPresenceCard(
                kind: "music-private",
                title: "Media playing",
                subtitle: "Halo",
                body: "Playback is active. Track details are hidden while your Mac is locked.",
                artwork: nil
            )
        case "title":
            return LockScreenPresenceCard(
                kind: "music-title",
                title: track,
                subtitle: "Now Playing",
                body: "Track details are limited on the Lock Screen.",
                artwork: preferences.showArtwork ? media.artworkImage : nil
            )
        default:
            return LockScreenPresenceCard(
                kind: "music",
                title: track,
                subtitle: artist.isEmpty ? "Now Playing" : artist,
                body: album.isEmpty ? "Playing now" : album,
                artwork: preferences.showArtwork ? media.artworkImage : nil
            )
        }
    }

    private func lockScreenTimerCard(_ preferences: LockScreenPresencePreferences) -> LockScreenPresenceCard? {
        guard preferences.showTimer else { return nil }
        if let deadline = store.deadline {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return LockScreenPresenceCard(
                kind: "timer-running",
                title: "Timer running",
                subtitle: "Halo Timer",
                body: "Ends at \(formatter.string(from: deadline))",
                artwork: nil
            )
        }
        if store.pausedSeconds > 0 {
            return LockScreenPresenceCard(
                kind: "timer-paused",
                title: "Timer paused",
                subtitle: "Halo Timer",
                body: "\(lockScreenDurationString(store.pausedSeconds)) remaining",
                artwork: nil
            )
        }
        return nil
    }

    private func lockScreenStopwatchCard(_ preferences: LockScreenPresencePreferences) -> LockScreenPresenceCard? {
        guard preferences.showStopwatch else { return nil }
        let workspace = store.workspace
        if let start = workspace.stopwatchStart {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return LockScreenPresenceCard(
                kind: "stopwatch-running",
                title: "Stopwatch running",
                subtitle: "Halo Stopwatch",
                body: "Started at \(formatter.string(from: start))",
                artwork: nil
            )
        }
        guard workspace.stopwatchElapsed > 0 else { return nil }
        return LockScreenPresenceCard(
            kind: "stopwatch-paused",
            title: "Stopwatch paused",
            subtitle: "Halo Stopwatch",
            body: lockScreenDurationString(workspace.stopwatchElapsed),
            artwork: nil
        )
    }

    private func lockScreenActivityCard(_ preferences: LockScreenPresencePreferences) -> LockScreenPresenceCard? {
        guard preferences.showActivities,
              let activity = store.workspace.primaryLiveActivity else { return nil }
        let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = activity.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        return LockScreenPresenceCard(
            kind: "activity",
            title: title.isEmpty ? "Live Activity" : title,
            subtitle: "Halo Live Activity",
            body: detail.isEmpty ? "An activity is active in Halo." : detail,
            artwork: nil
        )
    }

    private func lockScreenDurationString(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, seconds) }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func lockScreenPresenceArtworkAttachment(_ image: NSImage) -> UNNotificationAttachment? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.82]) else {
            return nil
        }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HaloLockScreenPresence", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("artwork.jpg")
            try data.write(to: url, options: .atomic)
            return try UNNotificationAttachment(identifier: "artwork", url: url, options: nil)
        } catch {
            return nil
        }
    }

'''
    wm = replace_once(wm, methods_anchor, methods + methods_anchor, "presence runtime methods")

wm_path.write_text(wm)

settings_path = Path("Halo/Views/WorkspaceSettingsView.swift")
settings = settings_path.read_text()

if 'case "Lock Screen": LockScreenSettingsPane(store: store, workspace: workspace)' not in settings:
    settings = replace_once(
        settings,
        'case "Lock Screen": LockScreenSettingsPane()\n',
        'case "Lock Screen": LockScreenSettingsPane(store: store, workspace: workspace)\n',
        "Lock Screen pane route",
    )

if "HaloLockScreenPresenceEnabled" not in settings:
    settings = replace_once(
        settings,
        "private struct LockScreenSettingsPane: View {\n",
        "private struct LockScreenSettingsPane: View {\n    @ObservedObject var store: AppStore\n    @ObservedObject var workspace: WorkspaceStore\n",
        "Lock Screen pane store",
    )
    settings = replace_once(
        settings,
        '    @AppStorage("HaloLockScreenRunActivationSequence") private var runActivationSequence = false\n',
        '    @AppStorage("HaloLockScreenRunActivationSequence") private var runActivationSequence = false\n    @AppStorage("HaloLockScreenPresenceEnabled") private var presenceEnabled = false\n    @AppStorage("HaloLockScreenPresencePriority") private var presencePriority = "music"\n    @AppStorage("HaloLockScreenPresenceMusic") private var presenceMusic = true\n    @AppStorage("HaloLockScreenPresenceTimer") private var presenceTimer = true\n    @AppStorage("HaloLockScreenPresenceStopwatch") private var presenceStopwatch = true\n    @AppStorage("HaloLockScreenPresenceActivities") private var presenceActivities = false\n    @AppStorage("HaloLockScreenPresenceArtwork") private var presenceArtwork = true\n    @AppStorage("HaloLockScreenPresenceMediaPrivacy") private var presenceMediaPrivacy = "details"\n',
        "presence settings storage",
    )

    presence_section = r'''            Section("Lock Screen Presence") {
                Toggle("Show Halo status on the Lock Screen", isOn: $presenceEnabled)
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
                            .disabled(presenceMediaPrivacy == "hidden")
                    }

                    Toggle("Active timer", isOn: $presenceTimer)
                    Toggle("Stopwatch", isOn: $presenceStopwatch)
                    Toggle("Live Activities", isOn: $presenceActivities)

                    Button("Preview Lock Screen card") {
                        workspace.enableNotifications()
                        NotificationCenter.default.post(name: .init("HaloPreviewLockScreenPresence"), object: nil)
                    }
                }

                Text("Halo uses a silent macOS notification for this card. macOS still controls whether Halo notifications are allowed to appear on the Lock Screen in System Settings. The card disappears when you unlock.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

'''
    settings = replace_once(
        settings,
        '            Section("Lock Screen customization") {\n',
        presence_section + '            Section("Lock Screen customization") {\n',
        "presence settings section",
    )

    settings = replace_once(
        settings,
        '''                Button("Reset Lock Screen customization") {
                    effectsEnabled = true
''',
        '''                Button("Reset Lock Screen customization") {
                    presenceEnabled = false
                    presencePriority = "music"
                    presenceMusic = true
                    presenceTimer = true
                    presenceStopwatch = true
                    presenceActivities = false
                    presenceArtwork = true
                    presenceMediaPrivacy = "details"
                    effectsEnabled = true
''',
        "presence reset defaults",
    )

settings_path.write_text(settings)
print("Lock Screen Presence patch applied")
