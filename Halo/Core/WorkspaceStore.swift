import AppKit
import SwiftUI
import Combine
import UserNotifications
import Darwin

@MainActor
final class WorkspaceStore: ObservableObject, LiveActivityProvider {
    static let systemAudioSource = "com.redstoneinvente.halo.system-audio"

    @Published var settings: WorkspaceSettings { didSet {
        schedulePersistence()
        updateHotkey()
        if oldValue.mediaApp != settings.mediaApp || oldValue.automaticMedia != settings.automaticMedia { media.disconnect() }
        updateArtworkPreference()
        hudEngine?.configurationDidChange()
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
    @Published var stopwatchStart: Date?
    @Published var stopwatchElapsed: TimeInterval = 0
    func toggleStopwatch() {
        if let start = stopwatchStart { stopwatchElapsed += Date().timeIntervalSince(start); stopwatchStart = nil }
        else { stopwatchStart = Date() }
    }
    private let hotkey = HotkeyService()
    private let defaults: UserDefaults
    private var ticker: AnyCancellable?
    private var subscriptions = Set<AnyCancellable>()
    private var matchedRules = Set<UUID>()
    private var tick = 0
    private var installedHotkey = ""
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
        if DemoMarketingStudio.shared.isEnabled {
            systemAudioFallback?.setEnabled(false)
            DemoMarketingStudio.shared.apply(to: self)
            return
        }
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
        evaluateSchedules(); system.refresh(); audio.refresh(); refreshApps(); updateHotkey()
        pollMedia()
        DemoMarketingStudio.shared.attach(workspace: self)
        ticker = Timer.publish(every: 2, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self else { return }
            self.tick += 1
            self.pollMedia()
            let minute = Int(Date().timeIntervalSince1970 / 60)
            if self.lastScheduleMinute != minute { self.lastScheduleMinute = minute; self.evaluateSchedules() }
            self.clipboard.poll(enabled: self.settings.clipboardEnabled, excluded: self.settings.clipboardExcludedApps)
            if self.tick % 5 == 0 {
                if DemoMarketingStudio.shared.isEnabled { DemoMarketingStudio.shared.apply(to: self) }
                else { self.system.refresh() }
                self.evaluateRules()
            }
            if self.tick % 30 == 0, self.settings.layout.enabled.contains(.calendar) { self.calendar.refresh() }
        }
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: defaults)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.disableLegacyHUDRenderer() }
            .store(in: &subscriptions)
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification, NSWorkspace.didWakeNotification] {
            NSWorkspace.shared.notificationCenter.publisher(for: name).receive(on: RunLoop.main).sink { [weak self] _ in
                self?.refreshApps(); self?.evaluateRules(); self?.evaluateSchedules(); self?.hudEngine?.configurationDidChange()
                self?.pollMedia()
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
    func stop() { pendingSave?.cancel(); persist(); ticker?.cancel(); subscriptions.removeAll(); systemAudioFallback?.stop(); systemAudioFallback = nil; hudEngine?.stop(); hudEngine = nil; hotkey.stop(); clipboard.reset(); media.disconnect() }
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
                let audio = AudioSpectrumService.shared.snapshot()
                media.isPlaying = snapshot.playing || (audio.available && audio.overall > 0.045)
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

@MainActor
final class DemoMarketingStudio {
    static let shared = DemoMarketingStudio()

    static let enabledKey = "HaloMarketingDemoEnabled"
    static let titleKey = "HaloMarketingDemoTitle"
    static let artistKey = "HaloMarketingDemoArtist"
    static let playingKey = "HaloMarketingDemoPlaying"
    static let batteryKey = "HaloMarketingDemoBattery"
    static let chargingKey = "HaloMarketingDemoCharging"
    static let onBatteryKey = "HaloMarketingDemoOnBattery"
    static let lowPowerKey = "HaloMarketingDemoLowPower"

    private weak var workspace: WorkspaceStore?
    private var window: NSWindow?

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }

    private init() {
        UserDefaults.standard.register(defaults: [
            Self.enabledKey: false,
            Self.titleKey: "Neon Afterglow",
            Self.artistKey: "Luma Vale",
            Self.playingKey: true,
            Self.batteryKey: 78.0,
            Self.chargingKey: true,
            Self.onBatteryKey: false,
            Self.lowPowerKey: false
        ])
    }

    func attach(workspace: WorkspaceStore) {
        self.workspace = workspace
        show()
        if isEnabled { apply(to: workspace) }
    }

    func show() {
        guard let workspace else { return }
        if window == nil {
            let panel = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 430, height: 720),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            panel.title = "Halo · Marketing Demo Studio"
            panel.contentMinSize = NSSize(width: 390, height: 560)
            panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView: DemoMarketingView(workspace: workspace))
            panel.center()
            window = panel
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func apply(to workspace: WorkspaceStore) {
        guard isEnabled else { return }
        let defaults = UserDefaults.standard
        workspace.media.title = defaults.string(forKey: Self.titleKey) ?? "Neon Afterglow"
        workspace.media.artist = defaults.string(forKey: Self.artistKey) ?? "Luma Vale"
        workspace.media.isPlaying = defaults.bool(forKey: Self.playingKey)
        workspace.media.error = nil

        workspace.system.battery = Int(defaults.double(forKey: Self.batteryKey).rounded())
        workspace.system.charging = defaults.bool(forKey: Self.chargingKey)
        workspace.system.onBattery = defaults.bool(forKey: Self.onBatteryKey)
        workspace.system.lowPower = defaults.bool(forKey: Self.lowPowerKey)
    }

    func clear(from workspace: WorkspaceStore) {
        workspace.media.disconnect()
        workspace.system.refresh()
    }
}

@MainActor
private struct DemoMarketingView: View {
    @ObservedObject var workspace: WorkspaceStore

    @AppStorage(DemoMarketingStudio.enabledKey) private var enabled = false
    @AppStorage(DemoMarketingStudio.titleKey) private var title = "Neon Afterglow"
    @AppStorage(DemoMarketingStudio.artistKey) private var artist = "Luma Vale"
    @AppStorage(DemoMarketingStudio.playingKey) private var playing = true
    @AppStorage(DemoMarketingStudio.batteryKey) private var battery = 78.0
    @AppStorage(DemoMarketingStudio.chargingKey) private var charging = true
    @AppStorage(DemoMarketingStudio.onBatteryKey) private var onBattery = false
    @AppStorage(DemoMarketingStudio.lowPowerKey) private var lowPower = false

    @State private var activityTitle = "Focus Session"
    @State private var activityDetail = "Deep work · 18 min remaining"
    @State private var activityProgress = 0.64
    @State private var hudValue = 0.72

    var body: some View {
        Form {
            Section("Marketing Demo") {
                Toggle("Enable dummy data", isOn: $enabled)
                    .onChange(of: enabled) { value in
                        if value { apply() }
                        else { DemoMarketingStudio.shared.clear(from: workspace) }
                    }
                Text("This panel exists only on the Demo branch. It freezes selected app data so you can compose repeatable screenshots without depending on live services.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Music") {
                TextField("Track title", text: $title)
                TextField("Artist", text: $artist)
                Toggle("Playing", isOn: $playing)
                HStack {
                    Button("Hero preset") {
                        title = "Neon Afterglow"
                        artist = "Luma Vale"
                        playing = true
                        apply()
                    }
                    Button("Ambient preset") {
                        title = "Glass Horizon"
                        artist = "Aster & Co."
                        playing = true
                        apply()
                    }
                    Button("Paused") {
                        playing = false
                        apply()
                    }
                }
                Button("Apply music data") { apply() }
            }

            Section("System") {
                HStack {
                    Text("Battery")
                    Spacer()
                    Text("\(Int(battery.rounded()))%").monospacedDigit().foregroundStyle(.secondary)
                }
                SwiftUI.Slider(value: $battery, in: 1...100, step: 1)
                    .onChange(of: battery) { _ in apply() }
                Toggle("Charging", isOn: $charging).onChange(of: charging) { _ in apply() }
                Toggle("On battery power", isOn: $onBattery).onChange(of: onBattery) { _ in apply() }
                Toggle("Low Power Mode", isOn: $lowPower).onChange(of: lowPower) { _ in apply() }
                HStack {
                    Button("Charging 78%") {
                        battery = 78; charging = true; onBattery = false; lowPower = false; apply()
                    }
                    Button("Low battery 18%") {
                        battery = 18; charging = false; onBattery = true; lowPower = true; apply()
                    }
                }
            }

            Section("Live Activity") {
                TextField("Title", text: $activityTitle)
                TextField("Detail", text: $activityDetail)
                HStack {
                    Text("Progress")
                    Spacer()
                    Text("\(Int(activityProgress * 100))%").monospacedDigit().foregroundStyle(.secondary)
                }
                SwiftUI.Slider(value: $activityProgress, in: 0...1)
                HStack {
                    Button("Show activity") {
                        workspace.publish(activityTitle, detail: activityDetail, progress: activityProgress)
                    }
                    Button("Clear") { workspace.activities = [] }
                }
            }

            Section("HUD shots") {
                HStack {
                    Text("Preview value")
                    Spacer()
                    Text("\(Int(hudValue * 100))%").monospacedDigit().foregroundStyle(.secondary)
                }
                SwiftUI.Slider(value: $hudValue, in: 0...1)
                HStack {
                    Button("Volume") { previewHUD("volume") }
                    Button("Brightness") { previewHUD("displayBrightness") }
                    Button("Keyboard") { previewHUD("keyboardBrightness") }
                }
                HStack {
                    Button("Battery") { previewHUD("batteryStatus") }
                    Button("Charging") { previewHUD("chargingState") }
                    Button("Media") { previewHUD("mediaChanged") }
                }
            }

            Section("Capture controls") {
                HStack {
                    Button("Toggle Halo") {
                        NotificationCenter.default.post(name: .init("HaloToggle"), object: nil)
                    }
                    Button("Open Settings") {
                        NotificationCenter.default.post(name: .init("HaloOpenSettings"), object: nil)
                    }
                }
                Button("Apply everything now") { apply() }
                    .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 390, minHeight: 560)
        .onAppear { if enabled { apply() } }
        .onChange(of: title) { _ in if enabled { apply() } }
        .onChange(of: artist) { _ in if enabled { apply() } }
        .onChange(of: playing) { _ in if enabled { apply() } }
    }

    private func apply() {
        guard enabled else { return }
        DemoMarketingStudio.shared.apply(to: workspace)
    }

    private func previewHUD(_ kind: String) {
        NotificationCenter.default.post(
            name: .init("HaloHUDPreview"),
            object: nil,
            userInfo: ["kind": kind, "value": hudValue]
        )
    }
}
