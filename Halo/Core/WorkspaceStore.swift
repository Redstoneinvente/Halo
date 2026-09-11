import AppKit
import Combine
import UserNotifications
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
        if baseArtworkInputsChanged || activeProfileArtworkInputsChanged { updateArtworkPreference() }

        let activeProfileHUDChanged: Bool = {
            guard let id = scheduledProfileID else { return false }
            return oldValue.profiles.first(where: { $0.id == id })?.layout.hud != settings.profiles.first(where: { $0.id == id })?.layout.hud
        }()
        if oldValue.layout.hud != settings.layout.hud || oldValue.displays != settings.displays || activeProfileHUDChanged {
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
    @Published var plugins: [PluginManifest] = []
    @Published var error: String?
    @Published var runningApps: [NSRunningApplication] = []
    let calendar = CalendarService()
    let clipboard = ClipboardService()
    let system = SystemService()
    let audio = AudioService()
    let media = MediaService()
    let capture = CaptureService()
    let bluetooth = BluetoothStateService.shared
    @Published var stopwatchStart: Date?
    @Published var stopwatchElapsed: TimeInterval = 0
    func toggleStopwatch() {
        if let start = stopwatchStart { stopwatchElapsed += Date().timeIntervalSince(start); stopwatchStart = nil }
        else { stopwatchStart = Date() }
    }
    private let hotkey = HotkeyService()
    private let retroGameHotkey = HotkeyService(identifierID: 2, notificationName: .init("HaloRetroGameToggle"))
    private let defaults: UserDefaults
    private var ticker: AnyCancellable?
    private var subscriptions = Set<AnyCancellable>()
    private var matchedRules = Set<UUID>()
    private var tick = 0
    private var installedHotkey = ""
    private var installedRetroGameHotkey = ""
    private var pendingSave: DispatchWorkItem?
    private var hudEngine: HaloHUDEngine?
    private var systemAudioFallback: SystemAudioMediaFallback?
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
        let layouts = [effectiveLayout] + settings.displays.compactMap { $0.enabled ? $0.layout : nil }
        media.setArtworkEnabled(layouts.contains { layout in
            let context = layout.contextMusic
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
            return contextNeedsPalette || hudNeedsPalette ||
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
        evaluateSchedules(); system.refresh(); audio.refresh(); refreshApps(); updateHotkey(); updateRetroGameHotkey()
        pollMedia()

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
            let minute = Int(Date().timeIntervalSince1970 / 60)
            if self.lastScheduleMinute != minute { self.lastScheduleMinute = minute; self.evaluateSchedules() }
            self.clipboard.poll(enabled: self.settings.clipboardEnabled, excluded: self.settings.clipboardExcludedApps)
            if self.tick % 5 == 0 { self.system.refresh(); self.evaluateRules() }
            if self.tick % 30 == 0, self.settings.layout.enabled.contains(.calendar) { self.calendar.refresh() }
        }
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: defaults)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.disableLegacyHUDRenderer()
                self?.updateRetroGameHotkey()
            }
            .store(in: &subscriptions)
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification, NSWorkspace.didWakeNotification] {
            NSWorkspace.shared.notificationCenter.publisher(for: name).receive(on: RunLoop.main).sink { [weak self] _ in
                self?.refreshApps(); self?.evaluateRules(); self?.evaluateSchedules(); self?.hudEngine?.configurationDidChange()
                self?.pollMedia(); self?.bluetooth.refresh()
            }.store(in: &subscriptions)
        }
        for name in ["com.apple.Music.playerInfo", "com.spotify.client.PlaybackStateChanged"] {
            DistributedNotificationCenter.default().publisher(for: Notification.Name(name))
                .debounce(for: .milliseconds(120), scheduler: DispatchQueue.main)
                .sink { [weak self] _ in self?.pollMedia() }.store(in: &subscriptions)
        }
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main).sink { [weak self] _ in self?.evaluateRules(); self?.hudEngine?.configurationDidChange() }.store(in: &subscriptions)
    }
    func stop() { pendingSave?.cancel(); persist(); ticker?.cancel(); subscriptions.removeAll(); bluetooth.stop(); systemAudioFallback?.stop(); systemAudioFallback = nil; hudEngine?.stop(); hudEngine = nil; hotkey.stop(); retroGameHotkey.stop(); clipboard.reset(); media.disconnect() }
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
        let activity = LiveActivity(title: event.title, detail: event.detail, progress: nil)
        activities = [activity] + Array(activities.prefix(19))

        let configured = (defaults.object(forKey: "HaloBluetoothClosedNotchDuration") as? NSNumber)?.doubleValue ?? 10
        let duration = min(20, max(2, configured))
        let activityID = activity.id
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.activities.removeAll { $0.id == activityID }
        }
    }
    func publish(_ title: String, detail: String = "", progress: Double? = nil) {
        let activity = LiveActivity(title: title, detail: detail, progress: progress.map { min(1, max(0, $0)) })
        activities = [activity] + Array(activities.prefix(19))
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

private struct MediaRemoteNowPlayingSnapshot {
    let title: String
    let artist: String
    let album: String
    let playing: Bool
    let duration: Double?
    let elapsed: Double?
}

private final class MediaRemoteNowPlayingReader {
    static let shared = MediaRemoteNowPlayingReader()

    private typealias InfoCallback = @convention(block) (CFDictionary?) -> Void
    private typealias GetInfoFunction = @convention(c) (DispatchQueue, InfoCallback) -> Void

    private let handle: UnsafeMutableRawPointer?
    private let getInfo: GetInfoFunction?

    private init() {
        handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
        if let handle, let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            getInfo = unsafeBitCast(symbol, to: GetInfoFunction.self)
        } else {
            getInfo = nil
        }
    }

    deinit {
        if let handle { dlclose(handle) }
    }

    func fetch(_ completion: @escaping (MediaRemoteNowPlayingSnapshot?) -> Void) {
        guard let getInfo else { completion(nil); return }
        let callback: InfoCallback = { dictionary in
            guard let dictionary else { completion(nil); return }
            let info = dictionary as NSDictionary

            func firstString(_ keys: [String]) -> String? {
                for key in keys {
                    if let value = info[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return value }
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

            guard let title = firstString(["kMRMediaRemoteNowPlayingInfoTitle", "title"]) else {
                completion(nil)
                return
            }
            let artist = firstString(["kMRMediaRemoteNowPlayingInfoArtist", "artist"]) ?? ""
            let album = firstString(["kMRMediaRemoteNowPlayingInfoAlbum", "album"]) ?? ""
            let duration = firstDouble(["kMRMediaRemoteNowPlayingInfoDuration", "duration"])
            let elapsed = firstDouble(["kMRMediaRemoteNowPlayingInfoElapsedTime", "elapsedTime"])
            let rate = firstDouble(["kMRMediaRemoteNowPlayingInfoPlaybackRate", "playbackRate"])
            completion(MediaRemoteNowPlayingSnapshot(title: title, artist: artist, album: album,
                                                     playing: (rate ?? 0) > 0.001,
                                                     duration: duration, elapsed: elapsed))
        }
        getInfo(DispatchQueue.global(qos: .utility), callback)
    }
}

@MainActor
private final class SystemAudioMediaFallback {
    private weak var media: MediaService?
    private var enabled = false
    private var ownsFallback = false
    private var lastHeard = Date.distantPast
    private var lastRemoteMetadata = Date.distantPast
    private var remoteRequestInFlight = false

    init(media: MediaService) { self.media = media }

    func setEnabled(_ enabled: Bool) {
        guard self.enabled != enabled else { return }
        self.enabled = enabled
        AudioSpectrumService.shared.setActive(enabled)
        if !enabled { clearIfOwned() }
    }

    func refresh() {
        guard enabled, let media else { return }

        // Rich Apple Music / Spotify metadata wins in Automatic mode. MediaRemote is used only
        // when Halo is on the System Audio path (or when no rich provider is actively playing).
        if media.connectedApp != nil && media.isPlaying {
            ownsFallback = false
            return
        }

        requestMediaRemoteMetadata()

        let audioSnapshot = AudioSpectrumService.shared.snapshot()
        let audibleNow = audioSnapshot.available && audioSnapshot.overall > 0.045
        if audibleNow { lastHeard = Date() }
        let withinReleaseWindow = Date().timeIntervalSince(lastHeard) < 2.75
        let remoteMetadataFresh = Date().timeIntervalSince(lastRemoteMetadata) < 5.0
        let systemAudioPlaying = audibleNow || (ownsFallback && withinReleaseWindow)

        if systemAudioPlaying {
            if media.connectedApp == nil {
                if !remoteMetadataFresh {
                    media.title = "System Audio"
                    media.artist = "Playing from your Mac"
                }
                media.isPlaying = true
                media.error = nil
                ownsFallback = true
            }
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
        AudioSpectrumService.shared.setActive(false)
        clearIfOwned()
    }

    private func requestMediaRemoteMetadata() {
        guard !remoteRequestInFlight else { return }
        remoteRequestInFlight = true
        MediaRemoteNowPlayingReader.shared.fetch { [weak self] snapshot in
            Task { @MainActor in
                guard let self else { return }
                self.remoteRequestInFlight = false
                guard self.enabled, let media = self.media, media.connectedApp == nil, let snapshot else { return }

                self.lastRemoteMetadata = Date()
                self.ownsFallback = true
                media.title = snapshot.title
                if !snapshot.artist.isEmpty {
                    media.artist = snapshot.artist
                } else if !snapshot.album.isEmpty {
                    media.artist = snapshot.album
                } else {
                    media.artist = "System Audio"
                }
                let audibleNow = AudioSpectrumService.shared.snapshot().available && AudioSpectrumService.shared.snapshot().overall > 0.045
                media.isPlaying = snapshot.playing || audibleNow
                media.error = nil
            }
        }
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
