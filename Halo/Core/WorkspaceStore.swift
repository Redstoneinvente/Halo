import AppKit
import ApplicationServices
import Combine
import UserNotifications
import CoreAudio
import Darwin

@MainActor
final class WorkspaceStore: ObservableObject, LiveActivityProvider {
    static let systemAudioSource = "com.redstoneinvente.halo.system-audio"

    @Published var settings: WorkspaceSettings { didSet {
        schedulePersistence()

        let hotkeyChanged = oldValue.hotkeyEnabled != settings.hotkeyEnabled ||
            oldValue.hotkeyCode != settings.hotkeyCode ||
            oldValue.hotkeyModifiers != settings.hotkeyModifiers
        if hotkeyChanged { updateHotkey() }

        let mediaSourceChanged = oldValue.mediaApp != settings.mediaApp || oldValue.automaticMedia != settings.automaticMedia
        if mediaSourceChanged { media.disconnect() }

        let baseArtworkInputsChanged = oldValue.layout.contextMusic != settings.layout.contextMusic ||
            oldValue.layout.hud != settings.layout.hud ||
            oldValue.layout.closedNotch != settings.layout.closedNotch ||
            oldValue.layout.enabled != settings.layout.enabled ||
            oldValue.displays != settings.displays || mediaSourceChanged
        let activeProfileArtworkInputsChanged: Bool = {
            guard let id = scheduledProfileID else { return false }
            let oldLayout = oldValue.profiles.first(where: { $0.id == id })?.layout
            let newLayout = settings.profiles.first(where: { $0.id == id })?.layout
            return oldLayout?.contextMusic != newLayout?.contextMusic ||
                oldLayout?.hud != newLayout?.hud ||
                oldLayout?.closedNotch != newLayout?.closedNotch ||
                oldLayout?.enabled != newLayout?.enabled
        }()
        let displayProfileInputsChanged: Bool = {
            let ids = Set(settings.displays.compactMap(\.profileID))
            return ids.contains { id in
                oldValue.profiles.first(where: { $0.id == id })?.layout != settings.profiles.first(where: { $0.id == id })?.layout
            }
        }()
        if baseArtworkInputsChanged || activeProfileArtworkInputsChanged || displayProfileInputsChanged { updateArtworkPreference() }

        let activeProfileHUDChanged: Bool = {
            guard let id = scheduledProfileID else { return false }
            return oldValue.profiles.first(where: { $0.id == id })?.layout.hud != settings.profiles.first(where: { $0.id == id })?.layout.hud
        }()
        if oldValue.layout.hud != settings.layout.hud || oldValue.displays != settings.displays || activeProfileHUDChanged || displayProfileInputsChanged {
            hudEngine?.configurationDidChange()
        }

        queueScheduleEvaluation()
    } }
    @Published private(set) var scheduledProfileID: UUID?
    var effectiveLayout: WorkspaceLayout { settings.profiles.first { $0.id == scheduledProfileID }?.layout ?? settings.layout }
    var scheduledTheme: Theme? { settings.profiles.first { $0.id == scheduledProfileID }?.theme }
    private var suppressedOccurrence: String?
    private var scheduleEvaluationQueued = false
    private var lastScheduleMinute: Int?
    @Published var activities: [LiveActivity] = []

    var primaryLiveActivity: LiveActivity? {
        LiveActivitySelection.primary(in: activities)
    }

    @Published var plugins: [PluginManifest] = []
    @Published var error: String?
    @Published var runningApps: [NSRunningApplication] = []
    @Published private(set) var openedNotchVisible = false
    private var openedNotchVisibilityTokens = Set<UUID>()
    let calendar = CalendarService()
    let clipboard = ClipboardService()
    let system = SystemService()
    let audio = AudioService()
    let media = MediaService()
    let capture = CaptureService()
    let bluetooth = BluetoothStateService.shared
    @Published var stopwatchStart: Date?
    @Published var stopwatchElapsed: TimeInterval = 0
    @Published var stopwatchLaps: [TimeInterval] = []
    func setOpenedNotchVisible(_ visible: Bool, token: UUID) {
        if visible { openedNotchVisibilityTokens.insert(token) } else { openedNotchVisibilityTokens.remove(token) }
        let next = !openedNotchVisibilityTokens.isEmpty
        guard next != openedNotchVisible else { return }
        openedNotchVisible = next
        media.setOpenedDetailEnabled(next)
        if next { system.refresh(detailed: true); audio.refresh() }
    }
    func toggleStopwatch() {
        if let start = stopwatchStart { stopwatchElapsed += Date().timeIntervalSince(start); stopwatchStart = nil }
        else { stopwatchStart = Date() }
    }
    func lapStopwatch() {
        guard let start = stopwatchStart else { return }
        let total = stopwatchElapsed + Date().timeIntervalSince(start)
        let previous = stopwatchLaps.reduce(0, +)
        let lap = max(0, total - previous)
        guard lap > 0.01 else { return }
        stopwatchLaps.append(lap)
        if stopwatchLaps.count > 50 { stopwatchLaps.removeFirst(stopwatchLaps.count - 50) }
    }
    func resetStopwatch() {
        stopwatchStart = nil
        stopwatchElapsed = 0
        stopwatchLaps = []
    }
    private let hotkey = HotkeyService()
    private let retroGameHotkey = HotkeyService(identifierID: 2, notificationName: .init("HaloRetroGameToggle"))
    private let clipboardCIHotkey = HotkeyService(identifierID: 3, notificationName: .init("HaloClipboardCIToggle"))
    private let defaults: UserDefaults
    private var ticker: AnyCancellable?
    private var subscriptions = Set<AnyCancellable>()
    private var matchedRules = Set<UUID>()
    private var tick = 0
    private var installedHotkey = ""
    private var installedRetroGameHotkey = ""
    private var installedClipboardCIHotkey = ""
    private var pendingSave: DispatchWorkItem?
    private var hudEngine: HaloHUDEngine?
    private var systemAudioFallback: SystemAudioMediaFallback?
    private var systemLiveActivitySource: SystemLiveActivitySource?
    var applyTheme: ((Theme) -> Void)?
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "workspace.v1"), let saved = try? JSONDecoder().decode(WorkspaceSettings.self, from: data), saved.version == 1 {
            settings = saved
        } else { settings = WorkspaceSettings() }
        if let data = defaults.data(forKey: "plugins.v1"), let saved = try? JSONDecoder().decode([PluginManifest].self, from: data) {
            plugins = saved.compactMap { try? $0.validated() }
        }
    }
    private func updateArtworkPreference() {
        let displayLayouts = settings.displays.compactMap { item -> WorkspaceLayout? in
            guard item.enabled else { return nil }
            if let profileID = item.profileID, let profile = settings.profiles.first(where: { $0.id == profileID }) { return profile.layout }
            return item.layout
        }
        let layouts = [effectiveLayout] + displayLayouts
        media.setArtworkEnabled(layouts.contains { layout in
            let context = layout.contextMusic
            let contextNeedsArtwork = context?.enabled == true && (
                context?.showArtwork == true || context?.usesArtworkBackground == true
            )
            let contextNeedsPalette = context?.enabled == true && (
                context?.usesSongTextColors == true ||
                context?.usesSongControlColors == true ||
                context?.usesSongVisualizerColors == true ||
                context?.usesSongBackgroundColors == true ||
                context?.background == .gradient
            )
            let hudNeedsPalette = layout.hud?.enabled == true && HaloHUDEventKind.allCases.contains { kind in
                let configuration = layout.hud?.configuration(for: kind)
                return configuration?.appearance.primary.source == .albumArtwork ||
                       configuration?.appearance.progress.source == .albumArtwork
            }
            return contextNeedsArtwork || contextNeedsPalette || hudNeedsPalette ||
                layout.closedNotch?.visualizer?.dynamicColors == true ||
                layout.closedNotch?.albumTextColor == true ||
                layout.closedNotch?.albumBackgroundColor == true
        })
    }
    private var isAutomaticMediaSource: Bool { settings.automaticMedia ?? true }
    private var isSystemAudioOnly: Bool { !isAutomaticMediaSource && settings.mediaApp == Self.systemAudioSource }
    private var wantsSystemAudioFallback: Bool {
        if isSystemAudioOnly { return true }
        guard isAutomaticMediaSource else { return false }
        let layout = effectiveLayout
        let contextUsesMedia = layout.contextMusic?.enabled == true
        let moduleUsesMedia = layout.enabled.contains(.media)
        let closed = layout.closedNotch
        let closedUsesMedia = closed?.left == .media || closed?.left == .visualizer ||
            closed?.right == .media || closed?.right == .visualizer ||
            closed?.artworkOptions?.enabled == true || closed?.reactiveBackground?.enabled == true
        return contextUsesMedia || moduleUsesMedia || closedUsesMedia
    }
    func refreshMediaSource() {
        media.disconnect()
        pollMedia()
    }
    private func pollMedia() {
        if systemAudioFallback == nil { systemAudioFallback = SystemAudioMediaFallback(media: media) }
        systemAudioFallback?.setEnabled(wantsSystemAudioFallback)

        if isSystemAudioOnly {
            systemAudioFallback?.refresh()
            return
        }

        let preferred = settings.mediaApp == Self.systemAudioSource ? "com.apple.Music" : settings.mediaApp
        media.poll(app: preferred, automatic: isAutomaticMediaSource)
        systemAudioFallback?.refresh()
    }
    private func disableLegacyHUDRenderer() {
        if defaults.object(forKey: HaloHUDKeys.enabled) as? Bool != false {
            defaults.set(false, forKey: HaloHUDKeys.enabled)
        }
    }
    func start() {
        disableLegacyHUDRenderer()
        updateArtworkPreference()
        if hudEngine == nil { hudEngine = HaloHUDEngine(workspace: self); hudEngine?.start() }
        evaluateSchedules(); system.refresh(); audio.refresh(); refreshApps(); updateHotkey(); updateRetroGameHotkey(); updateClipboardCIHotkey()
        HaloCustomCIRuntimeStore.shared.attach(to: self)
        IntegrationCIRuntime.shared.start()
        IntegrationShortcutManager.shared.start()
        pollMedia()
        if systemLiveActivitySource == nil {
            systemLiveActivitySource = SystemLiveActivitySource(workspace: self, defaults: defaults)
        }
        systemLiveActivitySource?.start()

        bluetooth.$lastEvent
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                self?.publishBluetoothClosedNotchEvent(event)
            }
            .store(in: &subscriptions)
        bluetooth.start()

        ticker = Timer.publish(every: 2, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self else { return }
            self.tick += 1
            self.pollMedia()
            self.pruneLiveActivities()
            let minute = Int(Date().timeIntervalSince1970 / 60)
            if self.lastScheduleMinute != minute { self.lastScheduleMinute = minute; self.evaluateSchedules() }
            self.clipboard.poll(enabled: self.settings.clipboardEnabled, excluded: self.settings.clipboardExcludedApps)
            if self.openedNotchVisible { self.system.refresh(detailed: true) }
            else if self.tick % 5 == 0 { self.system.refresh() }
            if self.tick % 5 == 0 { self.evaluateRules() }
            if self.tick % 30 == 0, self.settings.layout.enabled.contains(.calendar) { self.calendar.refresh() }
        }
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: defaults)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.disableLegacyHUDRenderer()
                self?.updateRetroGameHotkey()
                self?.updateClipboardCIHotkey()
            }
            .store(in: &subscriptions)
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification, NSWorkspace.didWakeNotification] {
            NSWorkspace.shared.notificationCenter.publisher(for: name).receive(on: RunLoop.main).sink { [weak self] notification in
                self?.refreshApps(); self?.evaluateRules(); self?.evaluateSchedules(); self?.hudEngine?.configurationDidChange()
                self?.pollMedia(); self?.bluetooth.refresh()
                if notification.name == NSWorkspace.didWakeNotification {
                    IntegrationCIRuntime.shared.cleanupForSleepOrWake()
                    IntegrationCIRuntime.shared.refresh()
                    IntegrationShortcutManager.shared.sync()
                }
            }.store(in: &subscriptions)
        }
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)
            .receive(on: RunLoop.main)
            .sink { _ in
                IntegrationCIRuntime.shared.cleanupForSleepOrWake()
            }
            .store(in: &subscriptions)
        for name in ["com.apple.Music.playerInfo", "com.spotify.client.PlaybackStateChanged"] {
            DistributedNotificationCenter.default().publisher(for: Notification.Name(name))
                .debounce(for: .milliseconds(120), scheduler: DispatchQueue.main)
                .sink { [weak self] _ in self?.pollMedia() }.store(in: &subscriptions)
        }
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main).sink { [weak self] _ in self?.evaluateRules(); self?.hudEngine?.configurationDidChange() }.store(in: &subscriptions)
    }
    func stop() { HaloCustomCIRuntimeStore.shared.detach(); IntegrationShortcutManager.shared.stop(); IntegrationCIRuntime.shared.stop(); systemLiveActivitySource?.stop(); systemLiveActivitySource = nil; pendingSave?.cancel(); persist(); ticker?.cancel(); subscriptions.removeAll(); bluetooth.stop(); systemAudioFallback?.stop(); systemAudioFallback = nil; hudEngine?.stop(); hudEngine = nil; hotkey.stop(); retroGameHotkey.stop(); clipboardCIHotkey.stop(); clipboard.reset(); media.disconnect() }
    private func schedulePersistence() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.persist() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
    private func persist() {
        do { defaults.set(try JSONEncoder().encode(settings), forKey: "workspace.v1") }
        catch { self.error = error.localizedDescription }
    }
    private func updateHotkey() {
        let key = "\(settings.hotkeyEnabled)-\(settings.hotkeyCode)-\(settings.hotkeyModifiers)"
        guard key != installedHotkey else { return }; installedHotkey = key
        hotkey.stop()
        if settings.hotkeyEnabled, !hotkey.register(code: settings.hotkeyCode, modifiers: settings.hotkeyModifiers) {
            DispatchQueue.main.async { [weak self] in self?.error = "The global shortcut is unavailable or already used. Choose another shortcut." }
        }
    }
    private func updateRetroGameHotkey() {
        let ciEnabled = defaults.object(forKey: "HaloContextRetroEnabled") as? Bool ?? false
        let shortcutEnabled = defaults.object(forKey: "HaloContextRetroShortcutEnabled") as? Bool ?? true
        let code = defaults.object(forKey: "HaloContextRetroShortcutCode") == nil ? 5 : defaults.integer(forKey: "HaloContextRetroShortcutCode")
        let modifiers = defaults.object(forKey: "HaloContextRetroShortcutModifiers") == nil ? 2304 : defaults.integer(forKey: "HaloContextRetroShortcutModifiers")
        let key = "\(ciEnabled)-\(shortcutEnabled)-\(code)-\(modifiers)"
        guard key != installedRetroGameHotkey else { return }
        installedRetroGameHotkey = key
        retroGameHotkey.stop()
        guard ciEnabled, shortcutEnabled else { return }
        if !retroGameHotkey.register(code: UInt32(max(0, code)), modifiers: UInt32(max(0, modifiers))) {
            DispatchQueue.main.async { [weak self] in
                self?.error = "The Retro Game CI shortcut is unavailable or already used. Choose another shortcut."
            }
        }
    }
    private func updateClipboardCIHotkey() {
        let ciEnabled = defaults.object(forKey: "HaloContextClipboardEnabled") as? Bool ?? true
        let shortcutEnabled = defaults.object(forKey: "HaloContextClipboardShortcutEnabled") as? Bool ?? true
        let code = defaults.object(forKey: "HaloContextClipboardShortcutCode") == nil ? 9 : defaults.integer(forKey: "HaloContextClipboardShortcutCode")
        let modifiers = defaults.object(forKey: "HaloContextClipboardShortcutModifiers") == nil ? 6144 : defaults.integer(forKey: "HaloContextClipboardShortcutModifiers")
        let key = "\(ciEnabled)-\(shortcutEnabled)-\(code)-\(modifiers)"
        guard key != installedClipboardCIHotkey else { return }
        installedClipboardCIHotkey = key
        clipboardCIHotkey.stop()
        guard ciEnabled, shortcutEnabled else { return }
        if !clipboardCIHotkey.register(code: UInt32(max(0, code)), modifiers: UInt32(max(0, modifiers))) {
            DispatchQueue.main.async { [weak self] in
                self?.error = "The Clipboard CI shortcut is unavailable or already used. Choose another shortcut."
            }
        }
    }
    private func scheduleWinner(at date: Date) -> (UUID, String)? {
        for entry in settings.profileSchedules ?? [] where entry.enabled {
            guard settings.profiles.contains(where: { $0.id == entry.profileID }),
                  let day = entry.window.occurrence(at: date) else { continue }
            return (entry.profileID, entry.id.uuidString + ":" + String(day.timeIntervalSince1970))
        }
        return nil
    }
    private func queueScheduleEvaluation() {
        guard !scheduleEvaluationQueued else { return }; scheduleEvaluationQueued = true
        DispatchQueue.main.async { [weak self] in
            self?.scheduleEvaluationQueued = false; self?.evaluateSchedules()
        }
    }
    func evaluateSchedules() {
        let winner = scheduleWinner(at: Date())
        let selected = winner?.1 == suppressedOccurrence ? nil : winner?.0
        if scheduledProfileID != selected { scheduledProfileID = selected; updateArtworkPreference(); hudEngine?.configurationDidChange() }
    }
    func resumeSchedules() { suppressedOccurrence = nil; evaluateSchedules() }
    func apply(_ profile: Profile) {
        suppressedOccurrence = scheduleWinner(at: Date())?.1
        scheduledProfileID = nil
        settings.layout = profile.layout; applyTheme?(profile.theme)
    }
    func saveProfile(name: String, theme: Theme) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        settings.profiles.append(Profile(name: name, theme: theme, layout: settings.layout))
    }
    func deleteProfile(_ id: UUID) {
        settings.profiles.removeAll { $0.id == id }; settings.rules.removeAll { $0.profileID == id }; settings.profileSchedules?.removeAll { $0.profileID == id }
    }
    func renameProfile(_ id: UUID, to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = settings.profiles.firstIndex(where: { $0.id == id }) else { return }
        settings.profiles[index].name = String(name.prefix(80))
    }
    func moveModule(_ module: ModuleID, by delta: Int) {
        var order = settings.layout.normalizedOrder()
        guard let index = order.firstIndex(of: module), order.indices.contains(index + delta) else { return }
        order.swapAt(index, index + delta); settings.layout.order = order
    }
    func evaluateRules() {
        var current = Set<UUID>()
        var selected: Profile?
        for rule in settings.rules where rule.matches(app: NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "", battery: system.battery, charging: system.charging, displays: NSScreen.screens.count, hour: Calendar.current.component(.hour, from: Date())) {
            current.insert(rule.id)
            if !matchedRules.contains(rule.id), selected == nil { selected = settings.profiles.first { $0.id == rule.profileID } }
        }
        matchedRules = current
        if let selected { apply(selected) }
    }
    private func bluetoothClosedNotchEventEnabled(_ kind: BluetoothConnectionEventKind) -> Bool {
        guard defaults.object(forKey: "HaloBluetoothClosedNotchEvents") as? Bool ?? true else { return false }
        let key: String
        switch kind {
        case .connected: key = "HaloBluetoothClosedNotchConnected"
        case .disconnected: key = "HaloBluetoothClosedNotchDisconnected"
        case .poweredOn: key = "HaloBluetoothClosedNotchPoweredOn"
        case .poweredOff: key = "HaloBluetoothClosedNotchPoweredOff"
        }
        return defaults.object(forKey: key) as? Bool ?? true
    }
    private func publishBluetoothClosedNotchEvent(_ event: BluetoothConnectionEvent) {
        guard bluetoothClosedNotchEventEnabled(event.kind) else { return }
        let configured = (defaults.object(forKey: "HaloBluetoothClosedNotchDuration") as? NSNumber)?.doubleValue ?? 10
        let duration = min(20, max(2, configured))
        let activity = LiveActivity(
            bluetoothDeviceVisual: event.deviceVisual,
            externalID: "bluetooth.\(event.id.uuidString)",
            sourceBundleIdentifier: "com.apple.systempreferences",
            sourceName: "Bluetooth",
            kind: .bluetooth,
            state: .active,
            symbolName: "wave.3.right",
            title: event.title,
            detail: event.detail,
            progress: nil,
            updatedAt: Date(),
            expiresAt: Date().addingTimeInterval(duration),
            priority: 46,
            persistent: false
        )
        upsertLiveActivity(activity)
    }

    func publish(_ title: String, detail: String = "", progress: Double? = nil) {
        let activity = LiveActivity(
            kind: progress == nil ? .generic : .progress,
            state: .active,
            title: title,
            detail: detail,
            progress: progress.map { min(1, max(0, $0)) },
            updatedAt: Date(),
            expiresAt: progress == nil ? Date().addingTimeInterval(12) : nil,
            priority: progress == nil ? 50 : 58,
            persistent: progress != nil
        )
        upsertLiveActivity(activity)
    }

    func upsertLiveActivity(_ incoming: LiveActivity) {
        var activity = incoming
        activity.progress = activity.progress.map { min(1, max(0, $0)) }
        activity.updatedAt = Date()

        if let externalID = activity.externalID,
           let index = activities.firstIndex(where: { $0.externalID == externalID }) {
            let previous = activities[index]
            activity.id = previous.id
            activity.created = previous.created
            if activity.startedAt == nil { activity.startedAt = previous.startedAt }
            activities.remove(at: index)
        }

        activities.insert(activity, at: 0)
        if activities.count > 40 { activities.removeLast(activities.count - 40) }
        pruneLiveActivities()
    }

    func endLiveActivity(externalID: String, detail: String? = nil, linger: TimeInterval = 3) {
        guard let index = activities.firstIndex(where: { $0.externalID == externalID }) else { return }
        var activity = activities[index]
        activity.state = .ended
        if let detail { activity.detail = detail }
        activity.updatedAt = Date()
        activity.expiresAt = Date().addingTimeInterval(max(0, linger))
        activity.persistent = false
        activities[index] = activity
    }

    func dismissLiveActivity(id: UUID) {
        activities.removeAll { $0.id == id }
    }

    func pruneLiveActivities(now: Date = Date()) {
        activities.removeAll { activity in
            if let expiresAt = activity.expiresAt, expiresAt <= now { return true }
            if !activity.isPersistent, activity.progress == nil, activity.created.addingTimeInterval(90) <= now { return true }
            if let progress = activity.progress, progress >= 1,
               activity.resolvedUpdatedAt.addingTimeInterval(4) <= now { return true }
            return false
        }
    }
    func enableNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] _, error in
            if let error { Task { @MainActor in self?.error = error.localizedDescription } }
        }
    }
    func notify(_ title: String) {
        UNUserNotificationCenter.current().getNotificationSettings { status in
            guard status.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent(); content.title = title; content.sound = .default
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
    func refreshApps() {
        let updated = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
        if runningApps.map(\.processIdentifier) != updated.map(\.processIdentifier) { runningApps = updated }
    }
    func chooseBackground() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.image, .movie]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.layout.appearance.assetPath = url.path
        settings.layout.appearance.background = ["mp4", "mov", "m4v"].contains(url.pathExtension.lowercased()) ? .video : .image
    }
    func importPlugin() {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) < 100_000 else { throw CocoaError(.fileReadTooLarge) }
            let manifest = try JSONDecoder().decode(PluginManifest.self, from: Data(contentsOf: url)).validated()
            let alert = NSAlert(); alert.messageText = "Install \(manifest.name)?"
            alert.informativeText = "This plugin adds \(manifest.commands.count) commands. Each URL is shown for confirmation before opening. No executable code is loaded."
            alert.addButton(withTitle: "Install"); alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            plugins.removeAll { $0.id == manifest.id }; plugins.append(manifest); savePlugins()
        } catch { self.error = "Plugin rejected: \(error.localizedDescription)" }
    }
    func removePlugin(_ id: String) { plugins.removeAll { $0.id == id }; savePlugins() }
    private func savePlugins() {
        do { defaults.set(try JSONEncoder().encode(plugins), forKey: "plugins.v1") }
        catch { self.error = error.localizedDescription }
    }
    func run(_ command: PluginCommand) {
        guard let url = URL(string: command.url) else { return }
        let alert = NSAlert(); alert.messageText = command.title
        alert.informativeText = "Open this URL? Shortcuts may perform actions configured in the Shortcuts app.\n\n\(command.url)"
        alert.addButton(withTitle: "Open"); alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(url) }
    }
}

@MainActor
final class SystemLiveActivitySource {
    private weak var workspace: WorkspaceStore?
    private let defaults: UserDefaults
    private var timer: Timer?
    private var didSeedNotificationFingerprints = false
    private var notificationFingerprints = Set<String>()
    private var activeFaceTimeExternalID: String?

    private let notificationCenterBundleID = "com.apple.notificationcenterui"
    private let faceTimeBundleID = "com.apple.FaceTime"

    private let knownApps: [String: String] = [
        "Messages": "com.apple.MobileSMS",
        "Mail": "com.apple.mail",
        "FaceTime": "com.apple.FaceTime",
        "WhatsApp": "net.whatsapp.WhatsApp",
        "Telegram": "ru.keepcoder.Telegram",
        "Signal": "org.whispersystems.signal-desktop",
        "Discord": "com.hnc.Discord",
        "Slack": "com.tinyspeck.slackmacgap",
        "Microsoft Teams": "com.microsoft.teams2",
        "Messenger": "com.facebook.archon"
    ]

    init(workspace: WorkspaceStore, defaults: UserDefaults = .standard) {
        self.workspace = workspace
        self.defaults = defaults
    }

    var accessibilityTrusted: Bool { AXIsProcessTrusted() }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.45, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.scan() }
        }
        timer.tolerance = 0.10
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        scan()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        finishFaceTimeIfNeeded()
        notificationFingerprints.removeAll()
        didSeedNotificationFingerprints = false
    }

    func refreshNow() { scan() }

    private var captureEnabled: Bool {
        defaults.object(forKey: "HaloLiveActivitiesCaptureSystem") as? Bool ?? false
    }
    private var captureMessages: Bool {
        defaults.object(forKey: "HaloLiveActivitiesCaptureMessages") as? Bool ?? true
    }
    private var captureCalls: Bool {
        defaults.object(forKey: "HaloLiveActivitiesCaptureCalls") as? Bool ?? true
    }
    private var captureNotifications: Bool {
        defaults.object(forKey: "HaloLiveActivitiesCaptureNotifications") as? Bool ?? true
    }

    private func scan() {
        guard captureEnabled, AXIsProcessTrusted() else {
            finishFaceTimeIfNeeded()
            notificationFingerprints.removeAll()
            didSeedNotificationFingerprints = false
            return
        }
        scanNotificationCenter()
        scanFaceTime()
    }

    private func scanNotificationCenter() {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: notificationCenterBundleID).first else {
            // Treat "Notification Center is not currently exposing an AX app" as a valid
            // empty baseline. Otherwise the first real banner that launches/exposes the
            // process becomes the seed pass and is silently swallowed.
            didSeedNotificationFingerprints = true
            return
        }

        let root = AXUIElementCreateApplication(app.processIdentifier)

        // AXWindows is recommended for application elements, not guaranteed. Notification
        // banners can be exposed as top-level/visible children instead, depending on macOS
        // version and presentation state. Scan all cheap top-level entry points and dedupe
        // by the normalized content fingerprint.
        var candidateRoots = axElements(root, attribute: kAXWindowsAttribute as CFString)
        candidateRoots.append(contentsOf: axElements(root, attribute: kAXVisibleChildrenAttribute as CFString))
        candidateRoots.append(contentsOf: axElements(root, attribute: kAXChildrenAttribute as CFString))
        if candidateRoots.isEmpty {
            candidateRoots = [root]
        }

        var current = Set<String>()
        var candidates: [(fingerprint: String, strings: [String])] = []
        var seenCandidates = Set<String>()

        for candidateRoot in candidateRoots.prefix(32) {
            let snapshot = snapshot(of: candidateRoot)
            let strings = normalizedNotificationStrings(snapshot.strings)
            guard (2...24).contains(strings.count) else { continue }

            let fingerprint = stableFingerprint(strings.joined(separator: "\u{1F}"))
            guard seenCandidates.insert(fingerprint).inserted else { continue }

            current.insert(fingerprint)
            candidates.append((fingerprint, strings))
        }

        if !didSeedNotificationFingerprints {
            notificationFingerprints = current
            didSeedNotificationFingerprints = true
            return
        }

        for candidate in candidates where !notificationFingerprints.contains(candidate.fingerprint) {
            publishNotification(strings: candidate.strings, fingerprint: candidate.fingerprint)
        }

        notificationFingerprints = current
    }

    private func publishNotification(strings: [String], fingerprint: String) {
        guard let workspace else { return }

        let source = inferSourceName(in: strings)
        let bundleID = bundleIdentifier(for: source)
        let content = strings.filter { value in
            guard let source else { return true }
            return value.caseInsensitiveCompare(source) != .orderedSame
        }

        guard let title = content.first ?? strings.first else { return }
        let detail = content.dropFirst().prefix(2).joined(separator: " · ")
        let kind = LiveActivityClassifier.kind(sourceName: source, title: title, detail: detail)

        switch kind {
        case .message where !captureMessages: return
        case .call where !captureCalls: return
        case .notification where !captureNotifications: return
        default: break
        }

        let now = Date()
        let duration: TimeInterval = kind == .call ? 24 : kind == .message ? 18 : 14
        let priority: Double = kind == .call ? 100 : kind == .message ? 78 : 66
        let activity = LiveActivity(
            externalID: "system.notification.\(fingerprint)",
            sourceBundleIdentifier: bundleID,
            sourceName: source,
            kind: kind,
            state: kind == .call ? .incoming : .active,
            symbolName: symbol(for: kind),
            title: title,
            detail: detail,
            progress: nil,
            updatedAt: now,
            expiresAt: now.addingTimeInterval(duration),
            priority: priority,
            persistent: false
        )
        workspace.upsertLiveActivity(activity)
    }

    private func scanFaceTime() {
        guard captureCalls else {
            finishFaceTimeIfNeeded()
            return
        }
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: faceTimeBundleID).first else {
            finishFaceTimeIfNeeded()
            return
        }

        let root = AXUIElementCreateApplication(app.processIdentifier)
        let windows = axElements(root, attribute: kAXWindowsAttribute as CFString)
        var detected: (caller: String, state: LiveActivityState, detail: String)?

        for window in windows.prefix(8) {
            let snap = snapshot(of: window)
            let buttons = snap.buttons.map(normalize)
            let text = snap.strings.map(normalize).filter { !$0.isEmpty }
            let incoming = buttons.contains(where: { ["accept", "answer", "decline"].contains($0.lowercased()) }) ||
                text.contains(where: { $0.localizedCaseInsensitiveContains("incoming") && $0.localizedCaseInsensitiveContains("call") })
            let active = buttons.contains(where: {
                let lower = $0.lowercased()
                return lower.contains("end") || lower.contains("hang up") || lower == "mute"
            })

            guard incoming || active else { continue }
            let caller = text.first(where: { value in
                let lower = value.lowercased()
                return !lower.contains("facetime") &&
                    !lower.contains("incoming") &&
                    !lower.contains("call") &&
                    !["accept", "answer", "decline", "mute", "end"].contains(lower)
            }) ?? "FaceTime call"
            detected = (caller, incoming ? .incoming : .active, incoming ? "Incoming FaceTime call" : "FaceTime call in progress")
            break
        }

        guard let detected else {
            finishFaceTimeIfNeeded()
            return
        }

        let externalID = "system.call.facetime." + stableFingerprint(normalize(detected.caller))
        if let old = activeFaceTimeExternalID, old != externalID {
            workspace?.endLiveActivity(externalID: old, detail: "Call ended", linger: 3)
        }
        activeFaceTimeExternalID = externalID

        let previous = workspace?.activities.first(where: { $0.externalID == externalID })
        let now = Date()
        let activity = LiveActivity(
            externalID: externalID,
            sourceBundleIdentifier: faceTimeBundleID,
            sourceName: "FaceTime",
            kind: .call,
            state: detected.state,
            symbolName: detected.state == .incoming ? "phone.arrow.down.left.fill" : "phone.fill",
            title: detected.caller,
            detail: detected.detail,
            progress: nil,
            startedAt: detected.state == .active ? (previous?.startedAt ?? now) : previous?.startedAt,
            updatedAt: now,
            expiresAt: nil,
            priority: detected.state == .incoming ? 100 : 92,
            persistent: true
        )
        workspace?.upsertLiveActivity(activity)
    }

    private func finishFaceTimeIfNeeded() {
        guard let externalID = activeFaceTimeExternalID else { return }
        workspace?.endLiveActivity(externalID: externalID, detail: "Call ended", linger: 4)
        activeFaceTimeExternalID = nil
    }

    private func symbol(for kind: LiveActivityKind) -> String {
        switch kind {
        case .message: return "message.fill"
        case .call: return "phone.fill"
        default: return "bell.fill"
        }
    }

    private func inferSourceName(in strings: [String]) -> String? {
        for known in knownApps.keys {
            if strings.contains(where: { $0.caseInsensitiveCompare(known) == .orderedSame }) { return known }
        }
        return strings.first(where: { value in
            let lower = value.lowercased()
            return value.count <= 48 &&
                !lower.contains("notification center") &&
                !["close", "show", "options", "clear", "reply"].contains(lower)
        })
    }

    private func bundleIdentifier(for source: String?) -> String? {
        guard let source else { return nil }
        if let known = knownApps.first(where: { source.caseInsensitiveCompare($0.key) == .orderedSame })?.value {
            return known
        }
        return NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName?.caseInsensitiveCompare(source) == .orderedSame
        })?.bundleIdentifier
    }

    private struct AXSnapshot {
        var strings: [String] = []
        var buttons: [String] = []
    }

    private func snapshot(of root: AXUIElement) -> AXSnapshot {
        var result = AXSnapshot()
        var visited = 0

        func visit(_ element: AXUIElement, depth: Int) {
            guard depth <= 7, visited < 220 else { return }
            visited += 1

            let role = axString(element, attribute: kAXRoleAttribute as CFString) ?? ""
            let values = [
                axString(element, attribute: kAXTitleAttribute as CFString),
                axString(element, attribute: kAXValueAttribute as CFString),
                axString(element, attribute: kAXDescriptionAttribute as CFString)
            ].compactMap { $0 }

            for value in values {
                let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalized.isEmpty, normalized.count <= 600 else { continue }
                if !result.strings.contains(normalized) { result.strings.append(normalized) }
                if role == "AXButton", !result.buttons.contains(normalized) {
                    result.buttons.append(normalized)
                }
            }

            for child in axElements(element, attribute: kAXChildrenAttribute as CFString).prefix(48) {
                visit(child, depth: depth + 1)
            }
        }

        visit(root, depth: 0)
        return result
    }

    private func normalizedNotificationStrings(_ raw: [String]) -> [String] {
        let ignored = Set([
            "notification center", "close", "show", "options", "clear", "reply",
            "more", "less", "actions", "dismiss"
        ])
        var seen = Set<String>()
        return raw.compactMap { value -> String? in
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty, clean.count <= 420 else { return nil }
            let lower = clean.lowercased()
            guard !ignored.contains(lower), !lower.hasPrefix("notification center,") else { return nil }
            guard seen.insert(clean).inserted else { return nil }
            return clean
        }
    }

    private func axElements(_ element: AXUIElement, attribute: CFString) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value else { return [] }
        return value as? [AXUIElement] ?? []
    }

    private func axString(_ element: AXUIElement, attribute: CFString) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value else { return nil }
        if let string = value as? String { return string }
        if let attributed = value as? NSAttributedString { return attributed.string }
        return nil
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stableFingerprint(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}

@available(macOS 14.2, *)
private enum SafariAudioProcessDetector {
    private static let safariBundleID = "com.apple.Safari"
    private static let safariWebContentBundleID = "com.apple.WebKit.WebContent"

    static func isProducingOutput() -> Bool {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: safariBundleID).isEmpty else { return false }

        var listAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let system = AudioObjectID(kAudioObjectSystemObject)
        var byteCount: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &listAddress, 0, nil, &byteCount) == noErr, byteCount > 0 else { return false }

        var processObjects = [AudioObjectID](
            repeating: kAudioObjectUnknown,
            count: Int(byteCount) / MemoryLayout<AudioObjectID>.size
        )
        guard !processObjects.isEmpty,
              AudioObjectGetPropertyData(system, &listAddress, 0, nil, &byteCount, &processObjects) == noErr else { return false }

        for object in processObjects {
            guard readUInt32(object, selector: kAudioProcessPropertyIsRunningOutput) != 0 else { continue }
            let bundleID = readString(object, selector: kAudioProcessPropertyBundleID) ?? ""
            let pid = readPID(object)
            if belongsToSafari(pid: pid, bundleID: bundleID) { return true }
        }
        return false
    }

    private static func readUInt32(_ object: AudioObjectID, selector: AudioObjectPropertySelector) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return 0 }
        return value
    }

    private static func readPID(_ object: AudioObjectID) -> pid_t {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyPID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: pid_t = 0
        var size = UInt32(MemoryLayout<pid_t>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return 0 }
        return value
    }

    private static func readString(_ object: AudioObjectID, selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return nil }
        let string = value as String
        return string.isEmpty ? nil : string
    }

    private static func belongsToSafari(pid: pid_t, bundleID: String) -> Bool {
        if bundleID == safariBundleID { return true }
        guard bundleID == safariWebContentBundleID || bundleID.hasPrefix("com.apple.WebKit.") else { return false }

        // Safari hands actual web media output to WebKit helper processes. Walk the normal
        // parent chain first so we can attribute a helper to Safari without guessing.
        var current = pid
        var visited = Set<pid_t>()
        for _ in 0..<8 {
            guard current > 0, visited.insert(current).inserted else { break }
            if NSRunningApplication(processIdentifier: current)?.bundleIdentifier == safariBundleID { return true }
            guard let parent = parentPID(of: current), parent > 0, parent != current else { break }
            current = parent
        }

        // WebKit helpers can be re-parented through launchd/XPC. If Safari itself is running,
        // an active Apple WebKit WebContent output process is still a strong Safari signal.
        return !NSRunningApplication.runningApplications(withBundleIdentifier: safariBundleID).isEmpty
    }

    private static func parentPID(of pid: pid_t) -> pid_t? {
        var info = proc_bsdinfo()
        let expected = Int32(MemoryLayout<proc_bsdinfo>.stride)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, expected) == expected else { return nil }
        return pid_t(info.pbi_ppid)
    }
}

private struct MediaRemoteNowPlayingSnapshot {
    let title: String
    let artist: String
    let album: String
    let playing: Bool
    let duration: Double?
    let elapsed: Double?
    let artworkData: Data?
    let artworkURL: String?
    let bundleIdentifier: String?
    let applicationName: String?
    let playbackRate: Double
    let sampledAt: Date

    var currentElapsed: Double? {
        guard let elapsed else { return nil }
        guard playing, playbackRate > 0 else { return elapsed }
        let advanced = elapsed + max(0, Date().timeIntervalSince(sampledAt)) * playbackRate
        if let duration, duration > 0 { return min(duration, advanced) }
        return advanced
    }
}

/// Reads the actual macOS Now Playing session through MediaRemoteAdapter. Since macOS 15.4,
/// direct MediaRemote calls from normal third-party processes can be denied by mediaremoted;
/// the adapter runs the private framework inside Apple's entitled /usr/bin/perl process and
/// streams the same metadata Control Center sees, including Safari/WebKit title and artwork.
@MainActor
private final class MediaRemoteNowPlayingReader {
    static let shared = MediaRemoteNowPlayingReader()

    private typealias InfoCallback = @convention(block) (CFDictionary?) -> Void
    private typealias GetInfoFunction = @convention(c) (DispatchQueue, InfoCallback) -> Void

    private let controller = MediaController()
    private var cached: MediaRemoteNowPlayingSnapshot?
    private var cachedAt = Date.distantPast
    private var oneShotInFlight = false
    private var pending: [((MediaRemoteNowPlayingSnapshot?) -> Void)] = []
    private var artworkEnrichmentInFlight = false
    private var lastArtworkEnrichmentKey = ""
    private var lastArtworkEnrichmentAt = Date.distantPast

    // Legacy direct reader remains only as a fallback for older systems or adapter failures.
    private let legacyHandle: UnsafeMutableRawPointer?
    private let legacyGetInfo: GetInfoFunction?

    private init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
        legacyHandle = handle
        if let handle, let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            legacyGetInfo = unsafeBitCast(symbol, to: GetInfoFunction.self)
        } else {
            legacyGetInfo = nil
        }

        controller.onTrackInfoReceived = { [weak self] info in
            guard let self else { return }
            if let snapshot = self.snapshot(from: info) {
                let merged = self.mergingArtwork(into: snapshot, from: self.cached)
                self.cached = merged
                self.cachedAt = Date()
                self.enrichArtworkIfNeeded(merged)
            } else {
                self.cached = nil
                self.cachedAt = .distantPast
            }
        }
        controller.onListenerTerminated = { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                self?.controller.startListening()
            }
        }
        controller.startListening()
    }

    deinit {
        controller.stopListening()
        if let legacyHandle { dlclose(legacyHandle) }
    }

    func fetch(_ completion: @escaping (MediaRemoteNowPlayingSnapshot?) -> Void) {
        // The streaming adapter is the authoritative source. Reuse its latest event so Halo does
        // not spawn a helper process on every media poll.
        if let cached, Date().timeIntervalSince(cachedAt) < 15 {
            enrichArtworkIfNeeded(cached)
            completion(cached)
            return
        }

        pending.append(completion)
        guard !oneShotInFlight else { return }
        oneShotInFlight = true
        controller.getTrackInfo { [weak self] info in
            guard let self else { return }
            self.oneShotInFlight = false
            let callbacks = self.pending
            self.pending.removeAll()

            if let snapshot = self.snapshot(from: info) {
                let merged = self.mergingArtwork(into: snapshot, from: self.cached)
                self.cached = merged
                self.cachedAt = Date()
                self.enrichArtworkIfNeeded(merged)
                callbacks.forEach { $0(merged) }
            } else {
                self.fetchLegacy { snapshot in
                    callbacks.forEach { $0(snapshot) }
                }
            }
        }
    }

    @discardableResult
    fileprivate func performTransportCommand(_ command: String) -> Bool {
        switch command {
        case "playpause":
            controller.togglePlayPause()
            if let current = cached {
                let nextPlaying = !current.playing
                cached = MediaRemoteNowPlayingSnapshot(
                    title: current.title, artist: current.artist, album: current.album,
                    playing: nextPlaying, duration: current.duration,
                    elapsed: current.currentElapsed ?? current.elapsed,
                    artworkData: current.artworkData, artworkURL: current.artworkURL,
                    bundleIdentifier: current.bundleIdentifier, applicationName: current.applicationName,
                    playbackRate: nextPlaying ? max(1, current.playbackRate) : 0, sampledAt: Date()
                )
                cachedAt = Date()
            }
        case "next track":
            controller.nextTrack()
        case "previous track":
            controller.previousTrack()
        default:
            return false
        }
        return true
    }

    @discardableResult
    fileprivate func seekTransport(to seconds: Double) -> Bool {
        guard seconds.isFinite, seconds >= 0 else { return false }
        let target: Double
        if let duration = cached?.duration, duration > 0 { target = min(duration, seconds) }
        else { target = seconds }
        controller.setTime(seconds: target)
        if let current = cached {
            cached = MediaRemoteNowPlayingSnapshot(
                title: current.title, artist: current.artist, album: current.album,
                playing: current.playing, duration: current.duration, elapsed: target,
                artworkData: current.artworkData, artworkURL: current.artworkURL,
                bundleIdentifier: current.bundleIdentifier, applicationName: current.applicationName,
                playbackRate: current.playbackRate, sampledAt: Date()
            )
            cachedAt = Date()
        }
        return true
    }

    private func snapshot(from info: TrackInfo?) -> MediaRemoteNowPlayingSnapshot? {
        guard let payload = info?.payload,
              let rawTitle = payload.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawTitle.isEmpty else { return nil }

        let artworkData = payload.artworkDataBase64.flatMap { Foundation.Data(base64Encoded: $0) }
        let duration = payload.durationMicros.flatMap { value -> Double? in
            let seconds = value / 1_000_000
            return seconds.isFinite && seconds > 0 ? seconds : nil
        }
        let rawElapsed = payload.currentElapsedTime ?? payload.elapsedTimeMicros.map { $0 / 1_000_000 }
        let elapsed = rawElapsed.flatMap { value in value.isFinite && value >= 0 ? value : nil }
        let rawRate = payload.playbackRate
        let playing = payload.isPlaying ?? ((rawRate ?? 0) > 0.001)
        let playbackRate = rawRate.flatMap { $0.isFinite ? max(0, $0) : nil } ?? (playing ? 1.0 : 0.0)

        return MediaRemoteNowPlayingSnapshot(
            title: rawTitle,
            artist: payload.artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            album: payload.album?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            playing: playing,
            duration: duration,
            elapsed: elapsed,
            artworkData: artworkData,
            artworkURL: nil,
            bundleIdentifier: payload.bundleIdentifier,
            applicationName: payload.applicationName,
            playbackRate: playbackRate,
            sampledAt: Date()
        )
    }

    private func normalizedTrackIdentity(_ snapshot: MediaRemoteNowPlayingSnapshot) -> String {
        [snapshot.title, snapshot.artist, snapshot.album]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .joined(separator: "|")
    }

    private func sameTrack(_ lhs: MediaRemoteNowPlayingSnapshot, _ rhs: MediaRemoteNowPlayingSnapshot) -> Bool {
        normalizedTrackIdentity(lhs) == normalizedTrackIdentity(rhs)
    }

    private func mergingArtwork(into snapshot: MediaRemoteNowPlayingSnapshot,
                                from fallback: MediaRemoteNowPlayingSnapshot?) -> MediaRemoteNowPlayingSnapshot {
        guard let fallback, sameTrack(snapshot, fallback) else { return snapshot }
        return MediaRemoteNowPlayingSnapshot(
            title: snapshot.title,
            artist: snapshot.artist,
            album: snapshot.album,
            playing: snapshot.playing,
            duration: snapshot.duration,
            elapsed: snapshot.elapsed,
            artworkData: snapshot.artworkData ?? fallback.artworkData,
            artworkURL: snapshot.artworkURL ?? fallback.artworkURL,
            bundleIdentifier: snapshot.bundleIdentifier,
            applicationName: snapshot.applicationName,
            playbackRate: snapshot.playbackRate,
            sampledAt: snapshot.sampledAt
        )
    }

    private func enrichArtworkIfNeeded(_ snapshot: MediaRemoteNowPlayingSnapshot) {
        guard snapshot.artworkData == nil, snapshot.artworkURL == nil, legacyGetInfo != nil else { return }
        let key = normalizedTrackIdentity(snapshot)
        guard !key.isEmpty else { return }
        let now = Date()
        if artworkEnrichmentInFlight { return }
        if key == lastArtworkEnrichmentKey, now.timeIntervalSince(lastArtworkEnrichmentAt) < 4 { return }

        artworkEnrichmentInFlight = true
        lastArtworkEnrichmentKey = key
        lastArtworkEnrichmentAt = now
        fetchLegacy { [weak self] legacy in
            DispatchQueue.main.async {
                guard let self else { return }
                self.artworkEnrichmentInFlight = false
                guard let legacy, let current = self.cached, self.sameTrack(current, legacy) else { return }
                self.cached = self.mergingArtwork(into: current, from: legacy)
            }
        }
    }

    private func fetchLegacy(_ completion: @escaping (MediaRemoteNowPlayingSnapshot?) -> Void) {
        guard let legacyGetInfo else { completion(nil); return }
        let callback: InfoCallback = { dictionary in
            guard let dictionary else { completion(nil); return }
            let info = dictionary as NSDictionary

            func firstString(_ keys: [String]) -> String? {
                for key in keys {
                    if let value = info[key] as? String,
                       !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return value }
                }
                return nil
            }
            func firstDouble(_ keys: [String]) -> Double? {
                for key in keys {
                    if let value = info[key] as? NSNumber { return value.doubleValue }
                    if let value = info[key] as? Double { return value }
                }
                return nil
            }
            func firstData(_ keys: [String]) -> Data? {
                for key in keys {
                    if let value = info[key] as? Data, !value.isEmpty { return value }
                    if let value = info[key] as? NSData, value.length > 0 { return value as Data }
                }
                return nil
            }
            func firstHTTPSURL(_ keys: [String]) -> String? {
                for key in keys {
                    let raw: String?
                    if let value = info[key] as? URL { raw = value.absoluteString }
                    else if let value = info[key] as? NSURL { raw = value.absoluteString }
                    else { raw = info[key] as? String }
                    if let raw, URL(string: raw)?.scheme == "https" { return raw }
                }
                return nil
            }

            guard let title = firstString(["kMRMediaRemoteNowPlayingInfoTitle", "title"]) else {
                completion(nil)
                return
            }
            let artist = firstString(["kMRMediaRemoteNowPlayingInfoArtist", "artist"]) ?? ""
            let album = firstString(["kMRMediaRemoteNowPlayingInfoAlbum", "album"]) ?? ""
            let duration = firstDouble(["kMRMediaRemoteNowPlayingInfoDuration", "duration"])
            let elapsed = firstDouble(["kMRMediaRemoteNowPlayingInfoElapsedTime", "elapsedTime"])
            let rate = firstDouble(["kMRMediaRemoteNowPlayingInfoPlaybackRate", "playbackRate"])
            let playbackRate = rate.flatMap { $0.isFinite ? max(0, $0) : nil } ?? 0
            let playing = playbackRate > 0.001
            let artworkData = firstData(["kMRMediaRemoteNowPlayingInfoArtworkData", "artworkData"])
            let artworkURL = firstHTTPSURL(["kMRMediaRemoteNowPlayingInfoArtworkURL", "artworkURL",
                                            "kMRMediaRemoteNowPlayingInfoArtworkIdentifier", "artworkIdentifier"])
            completion(MediaRemoteNowPlayingSnapshot(title: title, artist: artist, album: album,
                                                     playing: playing,
                                                     duration: duration, elapsed: elapsed,
                                                     artworkData: artworkData, artworkURL: artworkURL,
                                                     bundleIdentifier: nil, applicationName: nil,
                                                     playbackRate: playbackRate, sampledAt: Date()))
        }
        legacyGetInfo(DispatchQueue.global(qos: .utility), callback)
    }
}

/// Shared command path for browser/system Now Playing sessions. Metadata and commands deliberately
/// use the same MediaController so Safari/WebKit controls target the session shown by Control Center.
@MainActor
enum SystemMediaTransport {
    @discardableResult
    static func perform(_ command: String) -> Bool {
        MediaRemoteNowPlayingReader.shared.performTransportCommand(command)
    }

    @discardableResult
    static func seek(to seconds: Double) -> Bool {
        MediaRemoteNowPlayingReader.shared.seekTransport(to: seconds)
    }
}

@MainActor
private final class SystemAudioMediaFallback {
    private weak var media: MediaService?
    private var enabled = false
    private var ownsFallback = false
    private var lastHeard = Date.distantPast
    private var lastSafariOutput = Date.distantPast
    private var lastRemoteMetadata = Date.distantPast
    private var remoteRequestInFlight = false
    private var safariAudibleSince: Date?
    private var recognitionInFlight = false
    private var lastRecognitionAttempt = Date.distantPast
    private var fastRefreshTask: Task<Void, Never>?

    init(media: MediaService) { self.media = media }

    func setEnabled(_ enabled: Bool) {
        guard self.enabled != enabled else { return }
        self.enabled = enabled
        AudioSpectrumService.shared.setActive(enabled)
        if !enabled {
            fastRefreshTask?.cancel()
            fastRefreshTask = nil
            AudioSpectrumService.shared.cancelRecognition()
            recognitionInFlight = false
            safariAudibleSince = nil
            clearIfOwned()
        }
    }

    func refresh() {
        guard enabled, let media else { return }

        // A genuinely playing rich provider still wins. Paused/stopped Apple Music or Spotify
        // must not block Safari/system audio from claiming the surface.
        if media.connectedApp != nil && media.isPlaying {
            ownsFallback = false
            return
        }

        let now = Date()
        let safariRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").isEmpty
        let safariOutputActive: Bool
        if #available(macOS 14.2, *) {
            safariOutputActive = SafariAudioProcessDetector.isProducingOutput()
        } else {
            safariOutputActive = false
        }
        let audioSnapshot = AudioSpectrumService.shared.snapshot()
        let pcmAudible = isPCMAudible(audioSnapshot, safariHint: safariRunning || safariOutputActive)
        // CoreAudio's process-output flag means Safari/WebKit owns a running output stream; it
        // does NOT guarantee non-silent samples. Use it only to attribute PCM to Safari. Actual
        // liveness comes from captured PCM so a paused/silent WebKit stream cannot pin Audio CI.
        let audibleNow = pcmAudible
        let safariLikely = safariOutputActive || (safariRunning && pcmAudible)
        if safariOutputActive && pcmAudible { lastSafariOutput = now }
        if audibleNow { lastHeard = now }
        if safariLikely && audibleNow {
            if safariAudibleSince == nil { safariAudibleSince = now }
        } else if now.timeIntervalSince(lastHeard) > 4.5 {
            safariAudibleSince = nil
        }

        // If a stale paused rich provider is still attached, release it as soon as real system
        // output is observed. This is the main failure mode when Safari plays while Music/Spotify
        // happens to be open in the background.
        if audibleNow, media.connectedApp != nil, !media.isPlaying { media.disconnect() }

        requestMediaRemoteMetadata()

        let safariRecentlyActive = now.timeIntervalSince(lastSafariOutput) < 0.9
        let releaseWindow = (safariRunning || safariRecentlyActive) ? 1.25 : 0.85
        let withinReleaseWindow = now.timeIntervalSince(lastHeard) < releaseWindow
        let remoteMetadataFresh = now.timeIntervalSince(lastRemoteMetadata) < 5.0
        let systemAudioPlaying = audibleNow || (ownsFallback && withinReleaseWindow)

        if systemAudioPlaying {
            if media.connectedApp == nil {
                if !remoteMetadataFresh {
                    if safariOutputActive || safariRecentlyActive {
                        media.title = "Safari Audio"
                        media.artist = "Playing from Safari"
                    } else {
                        media.title = "System Audio"
                        media.artist = "Playing from your Mac"
                    }
                }
                media.isPlaying = true
                media.error = nil
                ownsFallback = true
            }
            requestRecognitionIfNeeded(media: media, safariLikely: safariLikely, audibleNow: audibleNow, now: now)
            scheduleFastRefresh()
            return
        }

        // Keep fresh MediaRemote metadata visible while paused, but do not mark the source as playing.
        if ownsFallback && remoteMetadataFresh && media.connectedApp == nil {
            media.isPlaying = false
            return
        }

        clearIfOwned()
    }

    func stop() {
        enabled = false
        fastRefreshTask?.cancel()
        fastRefreshTask = nil
        AudioSpectrumService.shared.cancelRecognition()
        recognitionInFlight = false
        safariAudibleSince = nil
        AudioSpectrumService.shared.setActive(false)
        clearIfOwned()
    }

    private func scheduleFastRefresh() {
        guard enabled, ownsFallback else { return }
        fastRefreshTask?.cancel()
        fastRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self, self.enabled, self.ownsFallback else { return }
                self.refresh()
            }
        }
    }

    private func requestMediaRemoteMetadata() {
        guard !remoteRequestInFlight else { return }
        remoteRequestInFlight = true
        MediaRemoteNowPlayingReader.shared.fetch { [weak self] snapshot in
            Task { @MainActor in
                guard let self else { return }
                self.remoteRequestInFlight = false
                guard self.enabled, let media = self.media, media.connectedApp == nil, let snapshot else { return }

                let audioSnapshot = AudioSpectrumService.shared.snapshot()
                let safariRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").isEmpty
                let safariOutput: Bool
                if #available(macOS 14.2, *) { safariOutput = SafariAudioProcessDetector.isProducingOutput() }
                else { safariOutput = false }
                let pcmAudible = self.isPCMAudible(audioSnapshot, safariHint: safariRunning || safariOutput)
                let safariLikely = safariOutput || (safariRunning && pcmAudible)
                let audibleNow = pcmAudible
                let now = Date()
                if safariOutput && pcmAudible { self.lastSafariOutput = now }
                // MediaRemote snapshots may be cached for many seconds. Never let a stale
                // `playing = true` sample keep pushing lastHeard forward after output stopped.
                // Actual PCM/process output owns the release timer; MediaRemote can only seed
                // presentation briefly when its playback sample itself is fresh.
                if audibleNow { self.lastHeard = now }
                let remotePlaybackFresh = snapshot.playing && now.timeIntervalSince(snapshot.sampledAt) < 1.0
                let safariRecentlyActive = now.timeIntervalSince(self.lastSafariOutput) < 0.9
                let releaseWindow = (safariRunning || safariRecentlyActive) ? 1.25 : 0.85
                let withinReleaseWindow = now.timeIntervalSince(self.lastHeard) < releaseWindow
                let shouldPresentPlaying = remotePlaybackFresh || audibleNow || (self.ownsFallback && withinReleaseWindow)

                let sourceBundle = snapshot.bundleIdentifier?.lowercased() ?? ""
                let sourceName = snapshot.applicationName?.lowercased() ?? ""
                let snapshotIsSafari = sourceBundle == "com.apple.safari" || sourceBundle.contains("webkit") || sourceName.contains("safari")

                // The adapter tells us which app actually owns Now Playing. Only reject a paused
                // non-Safari item when Safari is demonstrably making sound; this prevents stale
                // Music/Spotify metadata from covering a live browser session.
                guard snapshot.playing || !safariLikely || snapshotIsSafari else {
                    // Do not retract Audio CI from one detector dip. The normal refresh loop owns
                    // the transition to stopped after its release window has genuinely expired.
                    if shouldPresentPlaying { media.isPlaying = true }
                    return
                }

                self.lastRemoteMetadata = now
                self.ownsFallback = true
                let fallbackArtist = snapshotIsSafari ? "Playing from Safari" : (snapshot.applicationName ?? "System Audio")
                let displayArtist = !snapshot.artist.isEmpty ? snapshot.artist : (!snapshot.album.isEmpty ? snapshot.album : fallbackArtist)
                let sourceKey = [snapshot.bundleIdentifier ?? "", snapshot.title, snapshot.artist, snapshot.album]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .joined(separator: "|")
                media.acceptExternalMedia(title: snapshot.title,
                                          artist: displayArtist,
                                          album: snapshot.album,
                                          duration: snapshot.duration,
                                          position: snapshot.currentElapsed,
                                          playing: shouldPresentPlaying,
                                          artworkData: snapshot.artworkData,
                                          artworkURL: snapshot.artworkURL,
                                          sourceKey: sourceKey)
            }
        }
    }

    private func requestRecognitionIfNeeded(media: MediaService, safariLikely: Bool, audibleNow: Bool, now: Date) {
        guard safariLikely, audibleNow, !recognitionInFlight,
              let since = safariAudibleSince, now.timeIntervalSince(since) >= 2.4,
              now.timeIntervalSince(lastRecognitionAttempt) >= 15 else { return }

        let generic = isGenericExternalMetadata(title: media.title, artist: media.artist)
        guard generic || media.artworkImage == nil else { return }

        recognitionInFlight = true
        lastRecognitionAttempt = now
        AudioSpectrumService.shared.recognizeCurrentAudio(timeout: 8) { [weak self] match in
            Task { @MainActor in
                guard let self else { return }
                self.recognitionInFlight = false
                guard self.enabled, let media = self.media, let match else { return }

                let keepExistingMetadata = !self.isGenericExternalMetadata(title: media.title, artist: media.artist)
                let title = keepExistingMetadata ? media.title : match.title
                let artist = keepExistingMetadata ? media.artist : match.artist
                let sourceKey = [title, artist, media.album]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .joined(separator: "|")
                media.acceptExternalMedia(title: title,
                                          artist: artist,
                                          album: media.album,
                                          duration: media.duration > 0 ? media.duration : nil,
                                          position: media.position >= 0 ? media.position : nil,
                                          playing: media.isPlaying,
                                          artworkURL: match.artworkURL?.absoluteString,
                                          sourceKey: sourceKey)
            }
        }
    }

    private func isGenericExternalMetadata(title: String, artist: String) -> Bool {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let artist = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return title.isEmpty || title == "system audio" || title == "safari audio" || title == "connect a player" ||
            artist.isEmpty || artist == "system audio" || artist == "playing from safari" || artist == "playing from your mac"
    }

    private func isPCMAudible(_ snapshot: AudioSpectrumSnapshot, safariHint: Bool) -> Bool {
        guard snapshot.available else { return false }
        // Use instantaneous (unsmoothed) energy for liveness. The displayed spectrum keeps its
        // smooth release, but Audio CI must disappear as soon as real PCM falls silent.
        return snapshot.liveness > (safariHint ? 0.016 : 0.040)
    }

    private func clearIfOwned() {
        guard ownsFallback, let media else { ownsFallback = false; return }
        if media.connectedApp == nil {
            media.isPlaying = false
            media.title = "System Audio"
            media.artist = "Waiting for audio from your Mac"
        }
        ownsFallback = false
    }
}

// MARK: - Custom CI runtime

struct HaloCustomCIInvalidPackage: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let issues: [HaloCIValidationIssue]
}

struct HaloCustomCICandidate {
    let package: HaloCIParsedPackage
    let registration: CIRegistration
    let priority: Double
    let manual: Bool
}

private struct HaloCustomCIStoredState: Codable {
    var boolValues: [String: Bool] = [:]
    var numberValues: [String: Double] = [:]
}

private struct HaloCustomCIPackagePreferences: Codable {
    var enabled = true
    var priority = 50.0
    var grantedPermissions: Set<String> = []
    var state = HaloCustomCIStoredState()
}

/// Marker written only by the pre-v3 app-integration package generator.
/// v3 app integrations are runtime registrations and must never enter Custom CI validation.
private struct HaloLegacyGeneratedIntegrationMarker: Decodable {
    let generatorVersion: Int
    let bundleIdentifier: String
    let packageID: String
    let sourceFingerprint: String
}

@MainActor
final class HaloCustomCIRuntimeStore: ObservableObject {
    static let shared = HaloCustomCIRuntimeStore()

    @Published private(set) var packages: [HaloCIParsedPackage] = []
    @Published private(set) var invalidPackages: [HaloCustomCIInvalidPackage] = []
    @Published private(set) var manualActivationID: String?
    @Published private(set) var contextRevision = 0
    @Published var notice: String?
    @Published var errorMessage: String?

    private let defaults = UserDefaults.standard
    private let preferencesKey = "HaloCustomCI.packagePreferences.v1"
    private var preferences: [String: HaloCustomCIPackagePreferences] = [:]
    private var suppressedPackageIDs = Set<String>()
    private var subscriptions = Set<AnyCancellable>()
    private weak var workspace: WorkspaceStore?

    private init() {
        if let data = defaults.data(forKey: preferencesKey),
           let saved = try? JSONDecoder().decode([String: HaloCustomCIPackagePreferences].self, from: data) {
            preferences = saved
        }
        reload()
    }

    private var installRoot: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("Halo", isDirectory: true).appendingPathComponent("CustomCI", isDirectory: true)
    }

    func attach(to workspace: WorkspaceStore) {
        if self.workspace === workspace, !subscriptions.isEmpty { return }
        self.workspace = workspace
        subscriptions.removeAll()

        workspace.media.$isPlaying.receive(on: RunLoop.main).sink { [weak self] _ in self?.contextDidChange() }.store(in: &subscriptions)
        workspace.system.$battery.receive(on: RunLoop.main).sink { [weak self] _ in self?.contextDidChange() }.store(in: &subscriptions)
        workspace.system.$charging.receive(on: RunLoop.main).sink { [weak self] _ in self?.contextDidChange() }.store(in: &subscriptions)
        workspace.$runningApps.receive(on: RunLoop.main).sink { [weak self] _ in self?.contextDidChange() }.store(in: &subscriptions)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: RunLoop.main).sink { [weak self] _ in self?.contextDidChange() }.store(in: &subscriptions)
        Timer.publish(every: 60, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.contextDidChange() }.store(in: &subscriptions)
    }

    func detach() {
        subscriptions.removeAll()
        workspace = nil
        manualActivationID = nil
        suppressedPackageIDs.removeAll()
    }

    func reload() {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: installRoot, withIntermediateDirectories: true)

            let migration = migrateLegacyGeneratedIntegrationPackages(fileManager: fm)
            if !migration.removedPackageIDs.isEmpty {
                for packageID in migration.removedPackageIDs {
                    preferences.removeValue(forKey: packageID)
                    suppressedPackageIDs.remove(packageID)
                    if manualActivationID == packageID { manualActivationID = nil }
                }
                persistPreferences()
                notice = migration.removedPackageIDs.count == 1
                    ? "Removed an obsolete generated app-integration CI. App integrations now register directly at runtime."
                    : "Removed \(migration.removedPackageIDs.count) obsolete generated app-integration CIs. App integrations now register directly at runtime."
            }
            if !migration.errors.isEmpty {
                errorMessage = migration.errors.joined(separator: "\n")
            }

            let urls = try fm.contentsOfDirectory(
                at: installRoot,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            .filter { $0.pathExtension.lowercased() == "haloci" }
            .filter { !isLegacyGeneratedIntegrationPackage(at: $0) }

            var valid: [HaloCIParsedPackage] = []
            var invalid: [HaloCustomCIInvalidPackage] = []
            for url in urls {
                let report = HaloCIPackageValidator.validatePackage(at: url)
                if let package = report.package {
                    valid.append(package)
                } else {
                    invalid.append(
                        HaloCustomCIInvalidPackage(
                            name: url.deletingPathExtension().lastPathComponent,
                            url: url,
                            issues: report.issues
                        )
                    )
                }
            }
            packages = valid.sorted { lhs, rhs in
                if lhs.manifest.name.localizedCaseInsensitiveCompare(rhs.manifest.name) == .orderedSame {
                    return lhs.manifest.id < rhs.manifest.id
                }
                return lhs.manifest.name.localizedCaseInsensitiveCompare(rhs.manifest.name) == .orderedAscending
            }
            invalidPackages = invalid.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            if let manualActivationID,
               !packages.contains(where: { $0.manifest.id == manualActivationID }) {
                self.manualActivationID = nil
            }
            contextDidChange()
        } catch {
            errorMessage = "Could not load Custom CI packages: \(error.localizedDescription)"
        }
    }

    private struct LegacyIntegrationMigrationResult {
        var removedPackageIDs: [String] = []
        var errors: [String] = []
    }

    private func migrateLegacyGeneratedIntegrationPackages(
        fileManager fm: FileManager
    ) -> LegacyIntegrationMigrationResult {
        var result = LegacyIntegrationMigrationResult()
        let urls = (try? fm.contentsOfDirectory(
            at: installRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        for url in urls where url.pathExtension.lowercased() == "haloci" {
            guard let marker = legacyGeneratedIntegrationMarker(at: url) else { continue }
            do {
                try fm.removeItem(at: url)
                result.removedPackageIDs.append(marker.packageID)
            } catch {
                result.errors.append(
                    "Could not remove obsolete generated integration \(url.lastPathComponent): \(error.localizedDescription)"
                )
            }
        }
        return result
    }

    private func isLegacyGeneratedIntegrationPackage(at url: URL) -> Bool {
        legacyGeneratedIntegrationMarker(at: url) != nil
    }

    private func legacyGeneratedIntegrationMarker(
        at packageURL: URL
    ) -> HaloLegacyGeneratedIntegrationMarker? {
        let markerURL = packageURL.appendingPathComponent(".halo-generated-integration.json")
        guard let data = try? Data(contentsOf: markerURL),
              let marker = try? JSONDecoder().decode(HaloLegacyGeneratedIntegrationMarker.self, from: data),
              marker.generatorVersion > 0,
              !marker.bundleIdentifier.isEmpty,
              !marker.sourceFingerprint.isEmpty,
              marker.packageID == packageURL.deletingPathExtension().lastPathComponent,
              marker.packageID.hasPrefix("com.redstoneinvente.halo.integration.") else {
            return nil
        }
        return marker
    }

    func chooseAndImportPackage() {
        let panel = NSOpenPanel()
        panel.title = "Import Custom CI"
        panel.message = "Choose an unpacked .haloCI package directory. Halo validates it before installation."
        panel.prompt = "Import"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importPackage(from: url)
    }

    func importPackage(from source: URL) {
        notice = nil; errorMessage = nil
        let sourceReport = HaloCIPackageValidator.validatePackage(at: source)
        guard let sourcePackage = sourceReport.package else {
            errorMessage = validationMessage(prefix: "Custom CI validation failed", issues: sourceReport.issues)
            return
        }

        let fm = FileManager.default
        do {
            try fm.createDirectory(at: installRoot, withIntermediateDirectories: true)
            let destination = installRoot.appendingPathComponent(sourcePackage.manifest.id).appendingPathExtension("haloCI")
            if source.standardizedFileURL == destination.standardizedFileURL { reload(); return }

            let staging = installRoot.appendingPathComponent(".staging-\(UUID().uuidString)").appendingPathExtension("haloCI")
            let backup = installRoot.appendingPathComponent(".backup-\(UUID().uuidString)")
            defer { try? fm.removeItem(at: staging); try? fm.removeItem(at: backup) }
            try fm.copyItem(at: source, to: staging)
            let stagedReport = HaloCIPackageValidator.validatePackage(at: staging)
            guard stagedReport.package != nil else { throw HaloCustomCIImportError.invalid(validationMessage(prefix: "Staged package validation failed", issues: stagedReport.issues)) }

            if fm.fileExists(atPath: destination.path) { try fm.moveItem(at: destination, to: backup) }
            do {
                try fm.moveItem(at: staging, to: destination)
                if fm.fileExists(atPath: backup.path) { try? fm.removeItem(at: backup) }
            } catch {
                if fm.fileExists(atPath: backup.path), !fm.fileExists(atPath: destination.path) { try? fm.moveItem(at: backup, to: destination) }
                throw error
            }

            reload()
            notice = "Installed \(sourcePackage.manifest.name) \(sourcePackage.manifest.version). Permissions remain user-controlled."
        } catch let error as HaloCustomCIImportError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Could not install Custom CI: \(error.localizedDescription)"
        }
    }

    func removePackage(_ id: String) {
        guard let package = package(id: id) else { return }
        do {
            try FileManager.default.removeItem(at: package.rootURL)
            preferences.removeValue(forKey: id)
            suppressedPackageIDs.remove(id)
            if manualActivationID == id { manualActivationID = nil }
            persistPreferences()
            reload()
        } catch { errorMessage = "Could not remove \(package.manifest.name): \(error.localizedDescription)" }
    }

    func package(id: String) -> HaloCIParsedPackage? { packages.first { $0.manifest.id == id } }
    func isEnabled(_ id: String) -> Bool { preferences[id]?.enabled ?? true }
    func priority(_ id: String) -> Double { min(100, max(0, preferences[id]?.priority ?? 50)) }
    func grantedPermissions(_ id: String) -> Set<String> { preferences[id]?.grantedPermissions ?? [] }
    func requestedPermissions(_ package: HaloCIParsedPackage) -> [String] {
        Array(Set(package.manifest.permissions)).sorted()
    }
    func hasPermission(_ id: String, _ permission: String) -> Bool { grantedPermissions(id).contains(permission) }

    func setEnabled(_ enabled: Bool, packageID: String) {
        mutatePreferences(packageID) { $0.enabled = enabled }
        if !enabled {
            if manualActivationID == packageID { manualActivationID = nil }
            suppressedPackageIDs.remove(packageID)
        }
        contextDidChange()
    }

    func setPriority(_ priority: Double, packageID: String) {
        mutatePreferences(packageID) { $0.priority = min(100, max(0, priority)) }
        contextDidChange()
    }

    func setPermission(_ permission: String, granted: Bool, packageID: String) {
        guard let package = package(id: packageID), requestedPermissions(package).contains(permission), HaloCISDK.supportedPermissions.contains(permission) else { return }
        mutatePreferences(packageID) { prefs in
            if granted { prefs.grantedPermissions.insert(permission) } else { prefs.grantedPermissions.remove(permission) }
        }
        contextDidChange()
    }

    func requestManualActivation(_ id: String) {
        guard package(id: id) != nil, isEnabled(id) else { return }
        suppressedPackageIDs.remove(id)
        manualActivationID = id
        contextRevision &+= 1
        NotificationCenter.default.post(name: .init("HaloCustomCIOpenRequested"), object: id)
    }

    func clearManualActivation() {
        guard manualActivationID != nil else { return }
        manualActivationID = nil
        contextRevision &+= 1
    }

    func dismiss(_ id: String) {
        if manualActivationID == id { manualActivationID = nil }
        suppressedPackageIDs.insert(id)
        contextRevision &+= 1
        NotificationCenter.default.post(name: .init("HaloCustomCICloseRequested"), object: id)
    }

    func activeCandidate(workspace: WorkspaceStore, globalDisabled: Bool,
                         blockingPriority: Double? = nil) -> HaloCustomCICandidate? {
        guard !globalDisabled else { return nil }
        let floor = blockingPriority ?? -Double.infinity
        let snapshot = triggerSnapshot(workspace: workspace)
        let ordered = packages.filter { package in
            let id = package.manifest.id
            return isEnabled(id) && priority(id) >= floor &&
                (!suppressedPackageIDs.contains(id) || manualActivationID == id)
        }.sorted { lhs, rhs in
            let lp = priority(lhs.manifest.id), rp = priority(rhs.manifest.id)
            if lp != rp { return lp > rp }
            let lm = manualActivationID == lhs.manifest.id, rm = manualActivationID == rhs.manifest.id
            if lm != rm { return lm }
            return lhs.manifest.id < rhs.manifest.id
        }

        // Arbitration happens before trigger evaluation. Once a higher-priority package
        // claims the surface, lower-priority packages are not evaluated at all.
        for package in ordered {
            let id = package.manifest.id
            if manualActivationID == id {
                return HaloCustomCICandidate(package: package, registration: CustomCIFactory.makeRegistration(from: package), priority: priority(id), manual: true)
            }
            if HaloCITriggerEvaluator.matches(package.triggers, snapshot: snapshot,
                                              grantedPermissions: grantedPermissions(id)) {
                return HaloCustomCICandidate(package: package, registration: CustomCIFactory.makeRegistration(from: package), priority: priority(id), manual: false)
            }
        }
        return nil
    }

    func dataBus(for package: HaloCIParsedPackage, workspace: WorkspaceStore, expanded: Bool) -> [String: String] {
        let grants = grantedPermissions(package.manifest.id)
        var data: [String: String] = [
            "halo.surface.state": expanded ? "expanded" : "closed",
            "halo.surface.isExpanded": expanded ? "true" : "false",
            "system.battery.isCharging": workspace.system.charging ? "true" : "false",
            "system.lowPowerMode": workspace.system.lowPower ? "true" : "false",
            "system.cpu.usedPercent": format(workspace.system.cpuUsage),
            "system.memory.usedPercent": format(workspace.system.memoryUsage),
            "system.storage.usedPercent": format(workspace.system.diskUsage)
        ]
        if let battery = workspace.system.battery { data["system.battery.level"] = String(battery) }
        if grants.contains("Media.ReadState") {
            data["media.isPlaying"] = workspace.media.isPlaying ? "true" : "false"
            data["media.title"] = workspace.media.title
            data["media.artist"] = workspace.media.artist
            data["media.album"] = workspace.media.album
        }
        if grants.contains("Applications.Observe") {
            let app = NSWorkspace.shared.frontmostApplication
            data["apps.active.bundleID"] = app?.bundleIdentifier ?? ""
            data["apps.active.name"] = app?.localizedName ?? ""
        }
        return data
    }

    func boolState(packageID: String, key: String, default defaultValue: Bool) -> Bool {
        preferences[packageID]?.state.boolValues[key] ?? defaultValue
    }
    func setBoolState(_ value: Bool, packageID: String, key: String) {
        mutateState(packageID) { $0.boolValues[key] = value }
    }
    func numberState(packageID: String, key: String, default defaultValue: Double) -> Double {
        preferences[packageID]?.state.numberValues[key] ?? defaultValue
    }
    func setNumberState(_ value: Double, packageID: String, key: String) {
        guard value.isFinite else { return }
        mutateState(packageID) { $0.numberValues[key] = value }
    }

    func assetURL(packageID: String, source: String) -> URL? {
        guard source.hasPrefix("asset:"), let package = package(id: packageID) else { return nil }
        let relative = String(source.dropFirst("asset:".count))
        guard !relative.hasPrefix("/"), !relative.contains("..") else { return nil }
        let url = package.rootURL.appendingPathComponent(relative).standardizedFileURL
        guard url.path.hasPrefix(package.rootURL.standardizedFileURL.path + "/"), FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    func perform(_ action: HaloCIActionDescriptor, package: HaloCIParsedPackage, workspace: WorkspaceStore, data: [String: String]) {
        let id = package.manifest.id
        if let permission = HaloCISDK.permissionForAction(action.id), !hasPermission(id, permission) {
            errorMessage = "\(package.manifest.name) needs \(permission) before it can perform \(action.id)."
            return
        }
        let value = HaloCIBindingResolver.resolve(action.value ?? action.arguments?["value"] ?? action.arguments?["url"] ?? "", data: data)
        switch action.id {
        case "halo.ci.close": dismiss(id)
        case "clipboard.copy":
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
        case "url.open":
            guard let url = URL(string: value), let scheme = url.scheme?.lowercased(), ["https", "http", "mailto"].contains(scheme) else {
                errorMessage = "Custom CI tried to open an unsupported URL."; return
            }
            let alert = NSAlert()
            alert.messageText = "Allow \(package.manifest.name) to open this URL?"
            alert.informativeText = url.absoluteString
            alert.addButton(withTitle: "Open")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(url) }
        case "media.playPause": workspace.media.perform("playpause", app: workspace.settings.mediaApp)
        case "media.next": workspace.media.perform("next track", app: workspace.settings.mediaApp)
        case "media.previous": workspace.media.perform("previous track", app: workspace.settings.mediaApp)
        default: errorMessage = "Unsupported Custom CI action: \(action.id)"
        }
    }

    private func contextDidChange() {
        if let workspace, !suppressedPackageIDs.isEmpty {
            let snapshot = triggerSnapshot(workspace: workspace)
            let removable = suppressedPackageIDs.filter { id in
                guard let package = package(id: id) else { return true }
                return !HaloCITriggerEvaluator.matches(package.triggers, snapshot: snapshot, grantedPermissions: grantedPermissions(id))
            }
            suppressedPackageIDs.subtract(removable)
        }
        contextRevision &+= 1
    }

    private func triggerSnapshot(workspace: WorkspaceStore) -> HaloCITriggerSnapshot {
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: Date())
        return HaloCITriggerSnapshot(
            mediaIsPlaying: workspace.media.isPlaying,
            activeApplicationBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "",
            batteryLevel: workspace.system.battery.map(Double.init),
            charging: workspace.system.charging,
            minuteOfDay: (components.hour ?? 0) * 60 + (components.minute ?? 0)
        )
    }

    private func mutatePreferences(_ id: String, _ body: (inout HaloCustomCIPackagePreferences) -> Void) {
        var value = preferences[id] ?? HaloCustomCIPackagePreferences()
        body(&value)
        preferences[id] = value
        persistPreferences()
        objectWillChange.send()
    }

    private func mutateState(_ id: String, _ body: (inout HaloCustomCIStoredState) -> Void) {
        var prefs = preferences[id] ?? HaloCustomCIPackagePreferences()
        let previous = prefs.state
        body(&prefs.state)
        let totalKeys = prefs.state.boolValues.count + prefs.state.numberValues.count
        guard totalKeys <= 64, let encoded = try? JSONEncoder().encode(prefs.state), encoded.count <= 32_768 else {
            prefs.state = previous
            errorMessage = "Custom CI state quota exceeded (64 keys / 32 KB)."
            return
        }
        preferences[id] = prefs
        persistPreferences()
        objectWillChange.send()
    }

    private func persistPreferences() {
        if let data = try? JSONEncoder().encode(preferences) { defaults.set(data, forKey: preferencesKey) }
    }

    private func validationMessage(prefix: String, issues: [HaloCIValidationIssue]) -> String {
        let details = issues.filter { $0.severity == .error }.prefix(4).map { "\($0.path): \($0.message)" }.joined(separator: "\n")
        return details.isEmpty ? prefix : prefix + "\n" + details
    }
    private func format(_ value: Double) -> String { String(format: "%.2f", value) }
}

private enum HaloCustomCIImportError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { switch self { case .invalid(let message): return message } }
}

// MARK: - Embedded MediaRemote bridge

public struct TrackInfo: Codable {
    public let payload: Payload

    public init(payload: Payload) {
        self.payload = payload
    }

    public enum ShuffleMode: Int, Codable {
        case off = 0
        case songs = 1
        case albums = 2
    }

    public enum RepeatMode: Int, Codable {
        case off = 0
        case one = 1
        case all = 2
    }

    public struct Payload: Codable {
        public let title: String?
        public let artist: String?
        public let album: String?
        public let isPlaying: Bool?
        public let durationMicros: Double?
        public let elapsedTimeMicros: Double?
        public let applicationName: String?
        public let bundleIdentifier: String?
        public let artworkDataBase64: String?
        public let artworkMimeType: String?
        public let timestampEpochMicros: Double?
        public let PID: pid_t?
        public let shuffleMode: ShuffleMode?
        public let repeatMode: RepeatMode?
        public let playbackRate: Double?

        public let artwork: NSImage?

        public var uniqueIdentifier: String {
            return "\(title ?? "")-\(artist ?? "")-\(album ?? "")"
        }

        public var currentElapsedTime: TimeInterval? {
            guard let elapsedMicros = elapsedTimeMicros,
                  let timestampMicros = timestampEpochMicros else {
                return nil
            }

            let elapsedSeconds = elapsedMicros / 1_000_000

            if isPlaying != true {
                return elapsedSeconds
            }

            let timestampSeconds = timestampMicros / 1_000_000
            let rate = playbackRate ?? 0.0

            let now = Date().timeIntervalSince1970
            let timeSinceUpdate = now - timestampSeconds

            return elapsedSeconds + (timeSinceUpdate * rate)
        }

        enum CodingKeys: String, CodingKey {
            case title, artist, album, isPlaying, durationMicros, elapsedTimeMicros, applicationName, bundleIdentifier, artworkDataBase64, artworkMimeType, timestampEpochMicros, PID, shuffleMode, repeatMode, playbackRate
        }

        public init(
            title: String? = nil,
            artist: String? = nil,
            album: String? = nil,
            isPlaying: Bool? = nil,
            durationMicros: Double? = nil,
            elapsedTimeMicros: Double? = nil,
            applicationName: String? = nil,
            bundleIdentifier: String? = nil,
            artworkDataBase64: String? = nil,
            artworkMimeType: String? = nil,
            timestampEpochMicros: Double? = nil,
            PID: pid_t? = nil,
            shuffleMode: ShuffleMode? = nil,
            repeatMode: RepeatMode? = nil,
            playbackRate: Double? = nil,
            artwork: NSImage? = nil
        ) {
            self.title = title
            self.artist = artist
            self.album = album
            self.isPlaying = isPlaying
            self.durationMicros = durationMicros
            self.elapsedTimeMicros = elapsedTimeMicros
            self.applicationName = applicationName
            self.bundleIdentifier = bundleIdentifier
            self.artworkDataBase64 = artworkDataBase64
            self.artworkMimeType = artworkMimeType
            self.timestampEpochMicros = timestampEpochMicros
            self.PID = PID
            self.shuffleMode = shuffleMode
            self.repeatMode = repeatMode
            self.playbackRate = playbackRate
            self.artwork = artwork
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.title = try container.decodeIfPresent(String.self, forKey: .title)
            self.artist = try container.decodeIfPresent(String.self, forKey: .artist)
            self.album = try container.decodeIfPresent(String.self, forKey: .album)
            self.durationMicros = try container.decodeIfPresent(Double.self, forKey: .durationMicros)
            self.elapsedTimeMicros = try container.decodeIfPresent(Double.self, forKey: .elapsedTimeMicros)
            self.applicationName = try container.decodeIfPresent(String.self, forKey: .applicationName)
            self.bundleIdentifier = try container.decodeIfPresent(String.self, forKey: .bundleIdentifier)
            self.artworkDataBase64 = try container.decodeIfPresent(String.self, forKey: .artworkDataBase64)
            self.artworkMimeType = try container.decodeIfPresent(String.self, forKey: .artworkMimeType)
            self.timestampEpochMicros = try container.decodeIfPresent(Double.self, forKey: .timestampEpochMicros)

            if let pidNumber = try? container.decodeIfPresent(Int32.self, forKey: .PID) {
                self.PID = pid_t(pidNumber)
            } else if let pidString = try? container.decodeIfPresent(String.self, forKey: .PID),
                      let pidNumber = Int32(pidString) {
                self.PID = pid_t(pidNumber)
            } else {
                self.PID = nil
            }

            self.shuffleMode = try? container.decodeIfPresent(ShuffleMode.self, forKey: .shuffleMode)
            self.repeatMode = try? container.decodeIfPresent(RepeatMode.self, forKey: .repeatMode)
            self.playbackRate = try container.decodeIfPresent(Double.self, forKey: .playbackRate)

            if let boolValue = try? container.decode(Bool.self, forKey: .isPlaying) {
                self.isPlaying = boolValue
            } else if let intValue = try? container.decode(Int.self, forKey: .isPlaying) {
                self.isPlaying = (intValue == 1)
            } else {
                self.isPlaying = nil
            }

            if let base64String = self.artworkDataBase64,
               let data = Foundation.Data(base64Encoded: base64String) {
                self.artwork = NSImage(data: data)
            } else {
                self.artwork = nil
            }
        }
    }
}

public class MediaController {

    private var perlScriptPath: String? {
        guard let path = Bundle.main.path(forResource: "run", ofType: "pl") else {
            assertionFailure("run.pl script not found in Halo resources.")
            return nil
        }
        return path
    }

    private var listeningProcess: Process?
    private var listeningInputPipe: Pipe?
    private var dataBuffer = Foundation.Data()
    private var dataBufferSearchStart = 0
    private var lastTrackInfo: TrackInfo?
    private var eventCount = 0
    private let bufferLock = NSLock()
    private let restartThreshold = 100
    private let commandQueue = DispatchQueue(label: "mediaremote-adapter.commands")
    private static let sigpipeIgnored: Void = {
        signal(SIGPIPE, SIG_IGN)
    }()

    public var onTrackInfoReceived: ((TrackInfo?) -> Void)?
    public var onListenerTerminated: (() -> Void)?
    public var onDecodingError: ((Error, Foundation.Data) -> Void)?

    public init() {
        _ = MediaController.sigpipeIgnored
    }

    private var libraryPath: String? {
        guard let frameworksURL = Bundle.main.privateFrameworksURL else {
            assertionFailure("Could not locate Halo's Frameworks directory.")
            return nil
        }
        let url = frameworksURL.appendingPathComponent("libHaloMediaRemoteBridge.dylib")
        guard FileManager.default.fileExists(atPath: url.path) else {
            assertionFailure("Halo MediaRemote bridge dylib is missing at \(url.path).")
            return nil
        }
        return url.path
    }
    @discardableResult
    private func runPerlCommand(arguments: [String]) -> (output: String?, error: String?, terminationStatus: Int32) {
        guard let scriptPath = perlScriptPath else {
            return (nil, "Perl script not found.", -1)
        }
        guard let libraryPath = libraryPath else {
            return (nil, "Dynamic library path not found.", -1)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptPath, libraryPath] + arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        let errorPipe = Pipe()
        process.standardError = errorPipe

        var outputBuffer = Foundation.Data()
        var errorBuffer = Foundation.Data()
        let lock = NSLock()

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            lock.lock()
            outputBuffer.append(data)
            lock.unlock()
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            lock.lock()
            errorBuffer.append(data)
            lock.unlock()
        }

        do {
            try process.run()
            process.waitUntilExit()

            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil

            lock.lock()
            outputBuffer.append(outputPipe.fileHandleForReading.readDataToEndOfFile())
            errorBuffer.append(errorPipe.fileHandleForReading.readDataToEndOfFile())
            lock.unlock()

            let output = String(data: outputBuffer, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let errorOutput = String(data: errorBuffer, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

            return (output, errorOutput, process.terminationStatus)
        } catch {
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            return (nil, error.localizedDescription, -1)
        }
    }

    public func getTrackInfo(_ onReceive: @escaping (TrackInfo?) -> Void) {
        guard let scriptPath = perlScriptPath else {
            onReceive(nil)
            return
        }
        guard let libraryPath = libraryPath else {
            onReceive(nil)
            return
        }

        let getProcess = Process()
        getProcess.executableURL = URL(fileURLWithPath: "/usr/bin/perl")

        var getDataBuffer = Foundation.Data()
        var getDataBufferSearchStart = 0
        var callbackExecuted = false

        getProcess.arguments = [scriptPath, libraryPath, "get"]

        let outputPipe = Pipe()
        getProcess.standardOutput = outputPipe

        outputPipe.fileHandleForReading.readabilityHandler = { fileHandle in
            let incomingData = fileHandle.availableData
            if incomingData.isEmpty {
                fileHandle.readabilityHandler = nil
                return
            }

            getDataBuffer.append(incomingData)

            guard let newlineData = "\n".data(using: .utf8),
                  let range = getDataBuffer.firstRange(of: newlineData, in: getDataBufferSearchStart..<getDataBuffer.count),
                  range.lowerBound <= getDataBuffer.count else {
                getDataBufferSearchStart = getDataBuffer.count
                return
            }

            let lineData = getDataBuffer.subdata(in: 0..<range.lowerBound)
            getDataBuffer.removeSubrange(0..<range.upperBound)
            getDataBufferSearchStart = 0

            if !lineData.isEmpty && !callbackExecuted {
                callbackExecuted = true
                if lineData == "NIL".data(using: .utf8) {
                    DispatchQueue.main.async { onReceive(nil) }
                    return
                }
                do {
                    let trackInfo = try JSONDecoder().decode(TrackInfo.self, from: lineData)
                    DispatchQueue.main.async { onReceive(trackInfo) }
                } catch {
                    DispatchQueue.main.async { onReceive(nil) }
                }
            }
        }

        getProcess.terminationHandler = { _ in
            if !callbackExecuted {
                DispatchQueue.main.async { onReceive(nil) }
            }
        }

        do {
            try getProcess.run()
        } catch {
            onReceive(nil)
        }
    }

    public func startListening() {
        guard listeningProcess == nil else {
            return
        }

        eventCount = 0
        startListeningInternal()
    }

    private func startListeningInternal() {
        guard let scriptPath = perlScriptPath else {
            return
        }
        guard let libraryPath = libraryPath else {
            return
        }

        listeningProcess = Process()
        listeningProcess?.executableURL = URL(fileURLWithPath: "/usr/bin/perl")

        listeningProcess?.arguments = [scriptPath, libraryPath, "loop"]

        let inputPipe = Pipe()
        listeningProcess?.standardInput = inputPipe
        self.listeningInputPipe = inputPipe

        let outputPipe = Pipe()
        listeningProcess?.standardOutput = outputPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            guard let self = self else { return }

            let incomingData = fileHandle.availableData
            if incomingData.isEmpty {
                fileHandle.readabilityHandler = nil
                return
            }
            
            self.bufferLock.lock()
            defer { self.bufferLock.unlock() }

            self.dataBuffer.append(incomingData)

            guard let newlineData = "\n".data(using: .utf8) else { return }
            while let range = self.dataBuffer.firstRange(of: newlineData, in: self.dataBufferSearchStart..<self.dataBuffer.count) {
                guard range.lowerBound <= self.dataBuffer.count else {
                    break
                }

                let lineData = self.dataBuffer.subdata(in: 0..<range.lowerBound)

                self.dataBuffer.removeSubrange(0..<range.upperBound)
                self.dataBufferSearchStart = 0

                if lineData == "NIL".data(using: .utf8) {
                    DispatchQueue.main.async {
                        self.onTrackInfoReceived?(nil)
                    }
                    continue
                }

                if !lineData.isEmpty {
                    self.eventCount += 1

                    do {
                        let trackInfo = try JSONDecoder().decode(TrackInfo.self, from: lineData)
                        DispatchQueue.main.async {
                            let emitted = self.preservingArtworkIfDowngrade(trackInfo)
                            self.lastTrackInfo = emitted
                            self.onTrackInfoReceived?(emitted)

                            if self.eventCount >= self.restartThreshold {
                                self.restartListeningProcess()
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.onDecodingError?(error, lineData)
                        }
                    }
                }
            }

            self.dataBufferSearchStart = self.dataBuffer.count
        }

        listeningProcess?.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.listeningProcess = nil
                self?.listeningInputPipe = nil
                if self?.eventCount != 0 {
                    self?.onListenerTerminated?()
                }
            }
        }

        do {
            try listeningProcess?.run()
        } catch {
            print("Failed to start listening process: \(error)")
            listeningProcess = nil
        }
    }

    public func stopListening() {
        (listeningProcess?.standardOutput as? Pipe)?.fileHandleForReading.readabilityHandler = nil
        listeningProcess?.terminate()
        listeningProcess = nil
        listeningInputPipe = nil
        
        bufferLock.lock()
        defer { bufferLock.unlock() }
        dataBuffer.removeAll()
        dataBufferSearchStart = 0
    }

    private func sendCommand(_ arguments: [String]) {
        guard !arguments.isEmpty else { return }
        let line = arguments.joined(separator: " ") + "\n"
        guard let data = line.data(using: .utf8) else { return }

        commandQueue.async { [weak self] in
            guard let self = self else { return }
            if let process = self.listeningProcess,
               process.isRunning,
               let pipe = self.listeningInputPipe {
                let handle = pipe.fileHandleForWriting
                do {
                    if #available(macOS 10.15.4, *) {
                        try handle.write(contentsOf: data)
                    } else {
                        handle.write(data)
                    }
                    return
                } catch {
                    // Pipe closed under us; fall through to spawn.
                }
            }
            _ = self.runPerlCommand(arguments: arguments)
        }
    }

    public func play() { sendCommand(["play"]) }

    public func pause() { sendCommand(["pause"]) }

    public func togglePlayPause() { sendCommand(["toggle_play_pause"]) }

    public func nextTrack() { sendCommand(["next_track"]) }

    public func previousTrack() { sendCommand(["previous_track"]) }

    public func stop() { sendCommand(["stop"]) }

    public func setTime(seconds: Double) { sendCommand(["set_time", String(seconds)]) }

    public func toggleShuffle() { sendCommand(["toggle_shuffle"]) }

    public func toggleRepeat() { sendCommand(["toggle_repeat"]) }

    public func startForwardSeek() { sendCommand(["start_forward_seek"]) }

    public func endForwardSeek() { sendCommand(["end_forward_seek"]) }

    public func startBackwardSeek() { sendCommand(["start_backward_seek"]) }

    public func endBackwardSeek() { sendCommand(["end_backward_seek"]) }

    public func goBackFifteenSeconds() { sendCommand(["go_back_fifteen_seconds"]) }

    public func skipFifteenSeconds() { sendCommand(["skip_fifteen_seconds"]) }

    public func likeTrack() { sendCommand(["like_track"]) }

    public func banTrack() { sendCommand(["ban_track"]) }

    public func addToWishList() { sendCommand(["add_to_wish_list"]) }

    public func removeFromWishList() { sendCommand(["remove_from_wish_list"]) }

    public func setShuffleMode(_ mode: TrackInfo.ShuffleMode) {
        sendCommand(["set_shuffle_mode", String(mode.rawValue)])
    }

    public func setRepeatMode(_ mode: TrackInfo.RepeatMode) {
        sendCommand(["set_repeat_mode", String(mode.rawValue)])
    }

    private func isSameTrack(_ a: TrackInfo.Payload, _ b: TrackInfo.Payload) -> Bool {
        guard a.title == b.title, a.artist == b.artist else { return false }
        let aAlbum = a.album ?? ""
        let bAlbum = b.album ?? ""
        return aAlbum == bAlbum || aAlbum.isEmpty || bAlbum.isEmpty
    }

    private func preservingArtworkIfDowngrade(_ incoming: TrackInfo) -> TrackInfo {
        guard let previous = lastTrackInfo,
              isSameTrack(previous.payload, incoming.payload) else {
            return incoming
        }

        let previousLen = previous.payload.artworkDataBase64?.count ?? 0
        let incomingLen = incoming.payload.artworkDataBase64?.count ?? 0
        guard incomingLen < previousLen else {
            return incoming
        }

        let p = incoming.payload
        let merged = TrackInfo.Payload(
            title: p.title,
            artist: p.artist,
            album: p.album,
            isPlaying: p.isPlaying,
            durationMicros: p.durationMicros,
            elapsedTimeMicros: p.elapsedTimeMicros,
            applicationName: p.applicationName,
            bundleIdentifier: p.bundleIdentifier,
            artworkDataBase64: previous.payload.artworkDataBase64,
            artworkMimeType: previous.payload.artworkMimeType,
            timestampEpochMicros: p.timestampEpochMicros,
            PID: p.PID,
            shuffleMode: p.shuffleMode,
            repeatMode: p.repeatMode,
            playbackRate: p.playbackRate,
            artwork: previous.payload.artwork
        )
        return TrackInfo(payload: merged)
    }

    private func restartListeningProcess() {
        (listeningProcess?.standardOutput as? Pipe)?.fileHandleForReading.readabilityHandler = nil
        listeningProcess?.terminate()
        listeningProcess = nil
        listeningInputPipe = nil
        
        bufferLock.lock()
        defer { bufferLock.unlock() }
        dataBuffer.removeAll()
        dataBufferSearchStart = 0
        eventCount = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.startListeningInternal()
        }
    }
}
